---
title: "nats-server 2.14.6 — every -ERR a client can be sent, the two slow-consumer branches, and the expiry timer"
type: summary
area: [core, security, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/client-errors-v2.14.6.md
author: nats-io
article: "nats-server at tag v2.14.6 — the 58 client-protocol -ERR call sites, ClosedState, sendErr, the four credential paths, handleWriteTimeout and the max_pending branch, markConnAsClosed, setExpiration, Account.expiredTimeout, handshake_first's parser"
date: 2026-09-04
version: "nats-server 2.14.6"
tags: [-ERR, ClosedState, slow-consumer, write_deadline, max_pending, authorization-violation, user-authentication-expired, handshake_first, connz]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats-server 2.14.6 — every `-ERR` a client can be sent, the two slow-consumer branches, and the expiry timer

The server side of the two client-fault gotchas, and the authority against which
[[s-docs-system-errors]] swept the documented error tables. Extract:
`raw/nats-server-src/client-errors-v2.14.6.md` — a generated table of every call site plus 15
verbatim ranges with their real line numbers at v2.14.6. The behaviour is run in
[[s-nats-server-client-faults-observed]].

## Key claims

### An `-ERR` reaches a client through exactly three functions

`errProto = "-ERR '%s'" + _CRLF_` (`client.go:94`) is the only wire form, and it is written by
`sendErr` (`:2720–2731`), which enqueues it **only** for a `CLIENT`-kind connection. `sendErrAndErr`
and `sendErrAndDebug` (`:2485–2493`) wrap it with a rate-limited log line at error or debug level.
Sweeping those three across `server/*.go` (tests excluded) gives **58 call sites** at v2.14.6 —
the complete list of strings a connection can be sent. (The `sendErr(<code>, <text>)` closure in
`consumer.go` is a different function; it writes a JetStream pull-request status header, not an
`-ERR`.)

### The credential paths send four distinct strings; everything else collapses into one

| server function | string sent | `ClosedState` |
|---|---|---|
| `authTimeout()` (`:2495–2498`) | `Authentication Timeout` | `AuthenticationTimeout` |
| `authExpired()` (`:2500–2503`) | `User Authentication Expired` | `AuthenticationExpired` |
| `accountAuthExpired()` (`:2505–2508`) | `Account Authentication Expired` | `AuthenticationExpired` |
| `Account.checkUserRevoked` path (`accounts.go:3991`, `:4006`, `:4012`) | `User Authentication Revoked` | — |
| `authViolation()` (`:2510–2533`) | `Authorization Violation` | from `getAuthErrClosedState(authErr)` |

`authViolation` is explicit that the wire string does not vary with the internal error:

```go
	} else {
		// Send this to client, regardless of the authErr override.
		c.sendErr("Authorization Violation")
	}
```

So a wrong password, a bad signature, an unknown account and an expired-at-CONNECT JWT are one
string to the client; only the *closed reason* on `/connz` distinguishes them.

### `ClosedState` has 37 values, and they are what `/connz` reports

`type ClosedState int` with `ClientClosed = ClosedState(iota + 1)` (`client.go:188–228`), in order:
`ClientClosed`, `AuthenticationTimeout`, `AuthenticationViolation`, `TLSHandshakeError`,
`SlowConsumerPendingBytes`, `SlowConsumerWriteDeadline`, `WriteError`, `ReadError`, `ParseError`,
`StaleConnection`, `ProtocolViolation`, `BadClientProtocolVersion`, `WrongPort`,
`MaxAccountConnectionsExceeded`, `MaxConnectionsExceeded`, `MaxPayloadExceeded`,
`MaxControlLineExceeded`, `MaxSubscriptionsExceeded`, `DuplicateRoute`, `RouteRemoved`,
`ServerShutdown`, `AuthenticationExpired`, `WrongGateway`, `MissingAccount`, `Revocation`,
`InternalClient`, `MsgHeaderViolation`, `NoRespondersRequiresHeaders`, `ClusterNameConflict`,
`DuplicateRemoteLeafnodeConnection`, `DuplicateClientID`, `DuplicateServerName`,
`MinimumVersionRequired`, `ClusterNamesIdentical`, `Kicked`, `ProxyNotTrusted`, `ProxyRequired`.

These are the `reason` strings on `/connz?state=closed`, rendered by `monitor.go`'s `String()`
(e.g. `Slow Consumer (Pending Bytes)`, `Protocol Violation`, `Duplicate Route`). **They are not
`-ERR` strings**, and several of them are only ever these — nothing sends them on the wire.

### The server's slow consumer has two branches, and neither sends anything

**Write deadline** (`handleWriteTimeout`, `client.go:1950–2005`): increments `srv.slowConsumers`
and the per-kind `scStats`, logs
`Slow Consumer %s: WriteDeadline of %v exceeded with %d chunks of %d total bytes.` where `%s` is
`Detected` the first time and `State` afterwards, and — for a `CLIENT`, always —
`markConnAsClosed(SlowConsumerWriteDeadline)`.

**Pending bytes** (`queueOutbound`, `:2596–2625`): when `c.out.pb > c.out.mp` it logs
`Slow Consumer Detected: MaxPending of %d Exceeded` and calls
`markConnAsClosed(SlowConsumerPendingBytes)`. The same function creates the **stall gate** at 75 %
of `max_pending` (`c.out.pb > c.out.mp/4*3`), which is the backpressure that precedes the cut.

`markConnAsClosed` (`:2014–2035`) sets `skipFlushOnClose` for
`ReadError, WriteError, SlowConsumerPendingBytes, SlowConsumerWriteDeadline, TLSHandshakeError` —
so **no pending bytes and no `-ERR` are flushed**. A cut slow consumer sees EOF and nothing else,
which is exactly what the run observed ([[s-nats-server-client-faults-observed]] A6).

The relevant defaults, from `const.go:100–124`: `MAX_PENDING_SIZE = 64 * 1024 * 1024`,
`TLS_TIMEOUT = 2s`, `DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY = 50ms`, `AUTH_TIMEOUT = 2s`,
`DEFAULT_PING_INTERVAL = 2m`, `DEFAULT_PING_MAX_OUT = 2`, `DEFAULT_MAX_CONNECTIONS = 64 * 1024`.

### An already-expired JWT is accepted and then expired at once

`setExpiration(claims, validFor)` (`client.go:1335–1354`):

```go
	expiresAt := time.Duration(0)
	tn := time.Now().Unix()
	if claims.Expires > tn {
		expiresAt = time.Duration(claims.Expires-tn) * time.Second
	}
	…
		c.setExpirationTimer(expiresAt)
```

and `setExpirationTimerUnlocked` (`:5980–5985`) does `c.atmr = time.AfterFunc(d, c.authExpired)`.
When `claims.Expires <= tn`, `d` is **zero**, so the timer fires immediately and the connection —
already authenticated — is closed with `User Authentication Expired`. Since `jwt/v2`'s own check is
`now > c.Expires` at one-second resolution, a CONNECT landing *inside* the expiry second takes this
path; one second later the JWT fails validation and the answer becomes `Authorization Violation`
instead. Observed both ways in [[s-nats-server-client-faults-observed]] (B3, B6).

The **account** expiry is a separate timer on the account object:
`Account.checkExpiration` (`accounts.go:3316–3333`) arms `expiredTimeout`, which walks
`a.getClients()` and calls `accountAuthExpired()` on each non-internal one (`:3272–3284`) — one
account JWT expiring closes every connection in that account at once.

### `handshake_first` takes five values, not two

`parseTLS` (`opts.go:5309–5333`) accepts the key under three names — `handshake_first`, `first`,
`immediate` — and its value as a **bool**, or as one of the strings `true` / `on` / `false` / `off`
/ `auto` / `auto_fallback`, or as **any duration**:

```go
				case "auto", "auto_fallback":
					tc.HandshakeFirst = true
					tc.FallbackDelay = DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY
				default:
					// Check to see if this is a duration.
					if dur, err := time.ParseDuration(mv); err == nil {
						tc.HandshakeFirst = true
						tc.FallbackDelay = dur
```

`createClient` (`server.go:3316–3348`) skips the plaintext `INFO` only when `tlsFirst`, and takes
the fallback from `TLSHandshakeFirstFallback` — with an in-process connection always given the 50 ms
default. The startup warning is gated on there being **no** fallback (`server.go:2801–2814`):

```go
		tlsHandshakeFirstOnly := opts.TLSHandshakeFirst && opts.TLSHandshakeFirstFallback == 0
		…
		if tlsHandshakeFirstOnly {
			s.Warnf("Clients that are not using \"TLS Handshake First\" option will fail to connect")
		}
```

so `handshake_first: "auto"` logs nothing and breaks nothing — which is what makes it the migration
setting.

### Permissions violations are per subscription and do not close

`client.go:6140–6155` sends
`Permissions Violation for Subscription to %q using queue %q (sid %q)` (or without the queue) and
leaves the connection open. See [[subject-permissions]].

## Practical takeaways

- Do not expect the server to *tell* a client it was cut as a slow consumer; look at the server log
  and `/connz?state=closed`, not the client's error string.
- `Authorization Violation` is deliberately uninformative on the wire. The reason lives in the
  server's log and in `/connz`'s `reason`.
- `handshake_first: "auto"` (or a duration) is how you turn TLS-first on without a flag day.
- A JWT that expires while connected is a different code path from one that is expired at connect,
  and they send different strings.

## Relevance to the wiki

Behind [[slow-consumer-in-the-client]], [[slow-consumer-detected]],
[[connection-closed-after-auth-error]], [[tls-in-nats]] and the `-ERR` rows of
[[advisories]]; it is also the authority for the error-table sweep in
[[s-docs-system-errors]].

## Questions it answers

180, 181, 182; supports 175–179.

## Pages touched

[[slow-consumer-in-the-client]], [[connection-closed-after-auth-error]], [[slow-consumer-detected]],
[[tls-in-nats]], [[operator-mode]], [[subject-permissions]], [[monitoring-endpoints]],
[[client-connection-lifecycle]], [[defaults-and-limits]]
