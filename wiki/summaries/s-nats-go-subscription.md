---
title: "nats.go v1.53.1 — the subscription: pending limits, the slow-consumer signal, the auth errors"
type: summary
area: [clients, core, security]
source-url: https://github.com/nats-io/nats.go/blob/v1.53.1/nats.go
source-path: raw/nats-go-src/subscription-v1.53.1.md
author: nats-io
article: "nats.go at tag v1.53.1 — the pending-limit defaults and where they are applied, PendingLimits/SetPendingLimits/Pending/Dropped, the overflow path, NextMsg's validity check, processTransientError, processAuthError, checkAuthError, processErr, UserCredentials, userFromFile, connectProto, Request"
date: 2026-09-04
version: "nats.go v1.53.1"
tags: [nats-go, slow-consumer, SetPendingLimits, ErrSlowConsumer, Dropped, defaultErrHandler, IgnoreAuthErrorAbort, UserCredentials, creds, no_responders]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats.go v1.53.1 — the subscription: pending limits, the slow-consumer signal, the auth errors

The companion to [[s-nats-go-connection]], read at the same tag and for the same reason: the
`learn/resilient-clients` chapter is unversioned by design and names no client version anywhere
([[s-docs-resilient-clients-connecting]]), so every Go claim on the gotcha pages is pinned here.
Extract: `raw/nats-go-src/subscription-v1.53.1.md`, verbatim ranges with the real line numbers at
v1.53.1. The behaviour is run in [[s-nats-server-client-faults-observed]].

## Key claims

### The pending buffer is per subscription, and its default depends on the subscription type

| constant | value | where |
|---|---|---|
| `DefaultSubPendingMsgsLimit` | `500_000` | `nats.go:5765` |
| `DefaultSubPendingBytesLimit` | `64 * 1024 * 1024` | `:5767` |
| `DefaultMaxChanLen` | `64 * 1024` = 65,536 | `:59` (see [[s-nats-go-connection]]) |

Both are applied **at subscribe time**, before any message arrives (`:5048–5054`):

```go
	// Set pending limits.
	if ch != nil {
		sub.pMsgsLimit = cap(ch)
	} else {
		sub.pMsgsLimit = DefaultSubPendingMsgsLimit
	}
	sub.pBytesLimit = DefaultSubPendingBytesLimit
```

So a **channel-backed or sync** subscription starts at the channel's capacity —
`DefaultMaxChanLen`, **65,536** — while an **async** one starts at **500,000**. The bytes limit is
64 MB either way. The docs state "500,000 messages and 64 MB in the Go client" without the
distinction (`slow-consumers.md:16`, [[s-docs-resilient-clients-slow-consumers-and-request-reply]]);
both defaults were read off a running client in [[s-nats-server-client-faults-observed]] (A1, A4).

### `SetPendingLimits`: zero is an error, negative is unlimited

`SetPendingLimits(msgLimit, bytesLimit int) error` (`:5788–5807`) returns `ErrInvalidArg` when
**either** argument is `0`, and otherwise stores both. `PendingLimits()` (`:5770–5786`) reads them
back; its doc comment states the rule outright — "a negative value indicates that the given metric
is not limited". Both calls return `ErrTypeSubscription` on a channel subscription. `Pending()`
(`:5713–5727`) gives the live `pMsgs` / `pBytes`; `MaxPending()` the high-water marks;
`Dropped()` (`:5822–5836`) the running count, with the comment that it "may not be valid" if the
*server* declared the connection a slow consumer — the other failure entirely.

### The overflow path drops the arriving message and fires **once per transition**

```go
slowConsumer:
	sub.dropped++
	sc := !sub.sc
	sub.sc = true
	// Undo stats from above
	if sub.typ != ChanSubscription {
		sub.pMsgs--
		sub.pBytes -= len(m.Data)
	}
	if sc {
		sub.changeSubStatus(SubscriptionSlowConsumer)
		…
		nc.err = ErrSlowConsumer
		if asyncErrorCB := nc.Opts.AsyncErrorCB; asyncErrorCB != nil {
			nc.ach.push(func() { asyncErrorCB(nc, sub, ErrSlowConsumer) })
		}
```

(`:4005–4029`.) Three things follow. The message that would have overflowed is the one dropped, not
the oldest queued one. The subscription is **not closed** — nothing here touches `sub.closed`, and
the connection is untouched. And the callback fires only on the `false → true` edge; `sub.sc` is
cleared again by **the next message that fits** (`sub.sc = false` on the success path, `:3974–3978`),
so a sustained overflow re-arms and re-fires — far fewer times than messages dropped, but not once.
Measured: 12 fires for 4,889 drops ([[s-nats-server-client-faults-observed]] A1).

`ErrSlowConsumer` is `nats: slow consumer, messages dropped` (`:112`).

### A sync subscriber is told twice

`NextMsg`'s validity check (`:5626–5646`) clears the flag and returns the error once:

```go
	if s.sc {
		s.changeSubStatus(SubscriptionActive)
		s.sc = false
		return ErrSlowConsumer
	}
```

That is *in addition to* the connection-level callback, which the overflow path fired already.

### A connection with no callback set does not discard the report

```go
	// Set a default error handler that will print to stderr.
	if nc.Opts.AsyncErrorCB == nil {
		nc.Opts.AsyncErrorCB = defaultErrHandler
	}
```

(`:1974–1981`.) `defaultErrHandler` (`:2006–2028`) formats
`<err> on connection [<cid>] for subscription on "<subject>"` — or `<err> on connection [<cid>]`
when no subscription is involved — and writes it to **`os.Stderr`**. Setting your own handler
*replaces* this one rather than adding to it (A2). This is docs issue #92.

### `processErr` sorts the server's `-ERR` into three fates

`processErr(ie string)` (`:4304–4338`) lowercases the string and branches:

| server string (lowercased prefix) | what nats.go does | error surfaced |
|---|---|---|
| `stale connection` | `processOpErr` → disconnect and reconnect | `ErrStaleConnection` |
| `maximum connections exceeded` | `processOpErr` | `ErrMaxConnectionsExceeded` |
| `maximum account active connections exceeded` | `processOpErr` | `ErrMaxAccountConnectionsExceeded` |
| `permissions violation` … | **transient** — callback only, connection stays | `ErrPermissionViolation` wrapping the text |
| `maximum subscriptions exceeded` | **transient** | `ErrMaxSubscriptionsExceeded` |
| the four auth strings below | `processAuthError` | one of `ErrAuthorization`, `ErrAuthExpired`, `ErrAuthRevoked`, `ErrAccountAuthExpired` |
| **anything else** | **closes the connection** | `nats: <the server's text>` |

The last row is the one to notice: an `-ERR` nats.go does not recognise is terminal.

`processTransientError` (`:4036–4070`) additionally parses the subject out of a permissions
violation with `regexp` (`Subscription to "(\S+)"`, and `using queue "(\S+)"`) and records
`sub.permissionsErr` on the matching subscription, so `PermissionErrOnSubscribe` can fail later
calls on that one subscription rather than the connection.

### The four auth strings, and the abort rule

`checkAuthError` (`:4286–4302`) matches four prefixes, defined at `:79–88`:

| server string | nats.go error |
|---|---|
| `authorization violation` | `ErrAuthorization` — `nats: authorization violation` |
| `user authentication expired` | `ErrAuthExpired` — `nats: authentication expired` |
| `user authentication revoked` | `ErrAuthRevoked` — `nats: authentication revoked` |
| `account authentication expired` | `ErrAccountAuthExpired` — `nats: account authentication expired` |

`processAuthError` (`:4072–4092`) then decides:

```go
	if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort {
		nc.ar = true
	} else {
		nc.current.lastErr = err
	}
```

The abort is **the same error object from the same server twice in a row** — `nc.current` is the
pool entry being tried. Two *different* auth errors do not abort, and neither do two identical ones
from two different servers. This is the rule behind docs issue #93, and it is why
the number of reconnect attempts an expiring JWT costs depends on the reconnect delay
([[s-nats-server-client-faults-observed]] B3 vs B6).

### `UserCredentials` is two callbacks, and the file is re-read every attempt

```go
func UserCredentials(userOrChainedFile string, seedFiles ...string) Option {
	userCB := func() (string, error) {
		return userFromFile(userOrChainedFile)
	}
	…
	sigCB := func(nonce []byte) ([]byte, error) {
		return sigHandler(nonce, keyFile)
	}
	return UserJWT(userCB, sigCB)
}
```

(`:1499–1515`.) `userFromFile` (`:6743–6755`) does `os.ReadFile` and
`nkeys.ParseDecoratedJWT`, wiping the buffer afterwards. `connectProto` (`:3068–3106`) calls
`o.UserJWT()` and `o.SignatureCB(nc.info.Nonce)` **on every attempt**, so a rotated file on disk is
picked up at the next connect or reconnect with no code — and a half-written file at that instant
returns an error from `connectProto`, before any `CONNECT` is sent.

`connectProto` also sets `no_responders` from the same value as `headers`
(`hdrs := nc.info.Headers; … hdrs, hdrs`, `:3101–3106`): a client asks for the 503 only if the
server advertised header support, which is why the server's
`no responders requires headers support` guard (`client.go:2462–2467`) is unreachable from nats.go.

### The 503 becomes `ErrNoResponders` in the client

`Request` (`:4766–4781`) checks the reply itself:

```go
	if err == nil && len(m.Data) == 0 && m.Header.Get(statusHdr) == noResponders {
		m, err = nil, ErrNoResponders
	}
```

`ErrNoResponders` is `nats: no responders available for request` (`:151`). See [[request-reply]].

## Practical takeaways

- Size the pending limit per subscription; the default is not one number — 500,000 for an async
  subscription, 65,536 for a sync or channel one, 64 MB either way.
- `SetPendingLimits(n, -1)` is the idiom for "bound the count, leave the bytes alone"; `0` is
  rejected, not "unlimited".
- Do set an error callback, but not because the drops are silent otherwise — they go to stderr.
  Set one because stderr is not where you look.
- Treat "the same auth error twice from the same server" as the abort condition, not "two auth
  errors".
- A `.creds` path is re-read per attempt; rotate by writing to a temp file and renaming.

## Relevance to the wiki

The Go half of [[slow-consumer-in-the-client]] and [[connection-closed-after-auth-error]], the
`nats-go` rows of [[client-defaults]], and the *what bites you* material on [[nats-go]].

## Questions it answers

180, 181; supports 25, 175–179.

## Pages touched

[[slow-consumer-in-the-client]], [[connection-closed-after-auth-error]], [[client-defaults]],
[[nats-go]], [[client-connection-lifecycle]], [[slow-consumer-detected]], [[request-reply]],
[[subject-permissions]], [[operator-mode]]
