---
title: "nats.go v1.53.1 — the connection: defaults, reconnect, keepalive, drain, flush"
type: summary
area: [clients, core]
source-url: https://github.com/nats-io/nats.go/blob/v1.53.1/nats.go
source-path: raw/nats-go-src/connection-v1.53.1.md
author: nats-io
article: "nats.go at tag v1.53.1 — the const block, GetDefaultOptions, the Status enum, selectNextServer, doReconnect, publish's buffer check, processAuthError, processPingTimer, drainConnection, Drain, Flush, ForceReconnect, StatusChanged, defaultErrHandler"
date: 2026-09-04
version: "nats.go v1.53.1"
tags: [nats-go, reconnect, MaxReconnect, ReconnectWait, jitter, reconnect-buffer, ErrReconnectBufExceeded, ping, MaxPingsOut, stale-connection, drain, DrainTimeout, flush, IgnoreAuthErrorAbort, defaultErrHandler]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats.go v1.53.1 — the connection: defaults, reconnect, keepalive, drain, flush

The reference client's own values and rules, read at the tag the [[nats-go]] entity is pinned to,
because the `learn/resilient-clients` chapter is unversioned by design and names no client version
anywhere ([[s-docs-resilient-clients-connecting]]). Extract:
`raw/nats-go-src/connection-v1.53.1.md`, verbatim ranges with the real line numbers at v1.53.1.

## Key claims

### Every default in one const block (`nats.go:51–69`)

| constant | value |
|---|---|
| `DefaultURL` | `nats://127.0.0.1:4222` |
| `DefaultMaxReconnect` | `60` |
| `DefaultReconnectWait` | `2 * time.Second` |
| `DefaultReconnectJitter` | `100 * time.Millisecond` |
| `DefaultReconnectJitterTLS` | `time.Second` |
| `DefaultTimeout` (connect) | `2 * time.Second` |
| `DefaultPingInterval` | `2 * time.Minute` |
| `DefaultMaxPingOut` | `2` |
| `DefaultMaxChanLen` | `64 * 1024` |
| `DefaultReconnectBufSize` | `8 * 1024 * 1024` (8 MB) |
| `DefaultDrainTimeout` | `30 * time.Second` |
| `DefaultFlusherTimeout` | `time.Minute` |
| `DefaultSubPendingMsgsLimit` (`:5764`) | `500_000` |
| `DefaultSubPendingBytesLimit` (`:5766`) | `64 * 1024 * 1024` |

`GetDefaultOptions()` (`:163–178`) applies them and sets **`AllowReconnect: true`**. The exact
values matter: the docs' "500,000 messages, 64 MB" is `500_000` and `64 MiB`, not a rounding.

### Seven connection states (`:188–216`)

`DISCONNECTED, CONNECTED, CLOSED, RECONNECTING, CONNECTING, DRAINING_SUBS, DRAINING_PUBS` — the two
draining states the docs say only nats.go and nats.py expose.

### An unset async error callback does **not** discard errors (`:1979–1981`, `:2006–2028`)

```go
	if nc.Opts.AsyncErrorCB == nil {
		nc.Opts.AsyncErrorCB = defaultErrHandler
	}
```

`defaultErrHandler` writes `<err> on connection [<cid>] for subscription on "<subject>"` — or
`<err> on connection [<cid>]` with no subscription — to **`os.Stderr`**. This contradicts
`slow-consumers.md:100` and `where-next.md:99`, which say a Go connection with no callback
"discards these reports" so "dropped messages become invisible" (docs issue #92).

### `MaxReconnect` is a per-server budget, and spending it removes the server (`:2071–2091`)

`selectNextServer` rotates the current server to the end of the pool, **unless**
`maxReconnect >= 0 && s.Reconnects >= maxReconnect`, in which case the server is dropped:
`nc.srvPool = sp[0 : num-1]`. An empty pool returns `ErrNoServers`, and `doReconnect` then calls
`nc.close(CLOSED, true, nil)` (`:3544–3550`). This is the mechanism behind the docs' "a server that
uses its count up is dropped from the pool".

### The reconnect loop (`:3272–3527`)

- The disconnect callback fires first (`DisconnectedErrCB` takes priority over the deprecated
  `DisconnectedCB`); on a *first* connect with `RetryOnFailedConnect` the error goes to
  `ReconnectErrCB` instead (`:3290–3301`).
- **The sleep happens only after a whole sweep**: `doSleep = i+1 >= len(nc.srvPool) &&
  !forceReconnect` (`:3395`). With three servers in the pool the first two attempts have no wait at
  all — which is why the measured gap in [[s-nats-server-client-lifecycle-observed]] (run A3) is
  sub-millisecond.
- **The TLS jitter is chosen once for the whole pool**, by `nc.Opts.Secure || nc.Opts.TLSConfig !=
  nil` (`:3333–3335`), with a `TODO` in the source saying per-URL choice is not possible because the
  sleep is per sweep.
- **`CustomReconnectDelay` replaces the wait *and* the jitter**: `st = crd(wlf)` where `wlf` counts
  full sweeps (`:3424–3427`); the jitter branch is the `else`.
- `cur.Reconnects++` before each attempt (`:3461`); on success `cur.Reconnects = 0` (`:3492`), then
  `resendSubscriptions()` and `flushReconnectPendingItems()` in that order (`:3495`, `:3498`), and
  a final `nc.Flush()` (`:3538`).

### The reconnect buffer check sits inside `publish` (`:4583–4597`)

Order: closed → `isDrainingPubs()` → `ErrConnectionDraining`; then `msgSize > nc.info.MaxPayload` →
`ErrMaxPayload` (**skipped while `initc`**, i.e. during a `RetryOnFailedConnect` first connect);
then `nc.bw.atLimitIfUsingPending()` → **`ErrReconnectBufExceeded`** (`nats: outbound buffer limit
exceeded`, `:129`).

### The keepalive: the *third* ping (`:5899–5921`)

```go
	nc.pout++
	if nc.pout > nc.Opts.MaxPingsOut {
		… processOpErr(ErrStaleConnection, false) …
	}
	nc.sendPing(nil)
	nc.ptmr.Reset(nc.Opts.PingInterval)
```

With `MaxPingsOut = 2`, the timer fires, increments to 1, sends; fires, increments to 2, sends;
fires, increments to 3 → `3 > 2` → stale. **Two pings go unanswered and the third interval closes
the connection**: `2m × 3 = 6 minutes` with the defaults. ADR-40 says "if two consecutive PONGs are
missed, connection is marked as lost", which is the same words for a different number (docs issue
#90); the run in [[s-nats-server-client-lifecycle-observed]] (D3) times it.

### The auth abort is per server, and per repeated error (`:4077–4092`)

```go
	if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort {
		nc.ar = true
	} else {
		nc.current.lastErr = err
	}
```

So the rule is *the same error from the same server twice in a row* — `tls-and-auth.md:206`'s
wording, not `connection-events.md:244`'s bare "twice" (docs issue #93).

### Drain (`:6202–6327`)

- **`Drain()` returns at once**: it flips the status to `DRAINING_SUBS` and starts
  `go nc.drainConnection()` (`:6318–6320`).
- **A drain issued while CONNECTING or RECONNECTING calls `Close()`** and returns
  `ErrConnectionReconnecting` (`:6310–6314`, and again inside `drainConnection` at `:6211–6215`).
  Draining through an outage therefore *discards* the reconnect buffer instead of flushing it. The
  chapter never says so.
- Phase one: `s.Drain()` on every subscription except `respMux` (the request inbox, drained last so
  in-flight replies are not missed), then poll `NumSubscriptions()` every 10 ms until
  `time.Now().Add(drainWait)`; on expiry `pushErr(ErrDrainTimeout)` — **pushed to the async error
  callback, not returned by `Drain()`**.
- Phase two: `changeConnStatus(DRAINING_PUBS)`, then **`FlushTimeout(5 * time.Second)` — hardcoded**
  (`:6291`) — then `nc.Close()`.

### Flush and force reconnect

- `Flush()` is exactly `FlushTimeout(10 * time.Second)` (`:5980–5982`); `RTT()` uses the same call.
- `ForceReconnect()` (`:2589–2624`): if already reconnecting it just closes `nc.rqch` to cut the
  current backoff short; otherwise it clears pending pongs and requests, stops the ping timer,
  flushes, switches the writer to pending, closes the socket and starts `doReconnect(nil, true)`.
- `StatusChanged(statuses ...Status)` returns a **buffered channel of 10**, defaulting to
  `CONNECTED, RECONNECTING, DISCONNECTED, CLOSED` (`:6629–6642`); the registration comment says
  status events are non-blocking and are dropped if nobody is receiving.

## Practical takeaways

- Every "default" an operator reads in the resilient-clients chapter is a Go default; this is where
  it actually lives, and the version it holds for.
- `MaxReconnect: -1` is not paranoia — the default 60 is per server, and a pool of three servers
  under a long outage can genuinely empty and land in CLOSED.
- Two behaviours the chapter omits are worth an operator's attention: a drain during an outage
  closes rather than drains, and `ErrDrainTimeout` arrives on the error callback, so a service
  without one never learns its shutdown was cut short.

## Relevance to the wiki

The authority for [[client-defaults]]'s nats.go column and for every number on
[[client-connection-lifecycle]]. It also settles the ADR-40 disagreement the wiki had been carrying
on [[upgrade-a-cluster]].

## Questions it answers

Bank rows 177, 178 and 179, together with the docs summaries; the exact values for row 82.

## Pages touched

[[client-connection-lifecycle]] · [[client-defaults]] · [[nats-go]] · [[nats-timeout]] ·
[[upgrade-a-cluster]] · [[defaults-and-limits]]
