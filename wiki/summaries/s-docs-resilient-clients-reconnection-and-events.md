---
title: "docs — Resilient Clients: reconnection, and the connection events"
type: summary
area: [clients, core, monitoring]
source-url: https://docs.nats.io/learn/resilient-clients/reconnection.md
source-path: raw/nats-docs/learn/resilient-clients/reconnection.md
author: nats-io docs
article: "learn/resilient-clients/reconnection.md and connection-events.md; where-next.md read and folded"
date: 2026-08-31
version: ""
tags: [reconnect, backoff, jitter, MaxReconnect, reconnect-buffer, ErrReconnectBufExceeded, keepalive, ping, MaxPingsOut, stale-connection, connection-events, closed, readiness, force-reconnect, StatusChanged, lame-duck]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — Resilient Clients: reconnection, and the connection events

The two pages that own the CONNECTED → RECONNECTING → CONNECTED loop and everything that watches
it: backoff and jitter, the per-server `MaxReconnect` budget, the reconnect buffer, the keepalive
that catches a wedged link, and then the six events a client reports plus the readiness check they
add up to. `where-next.md`'s production checklist is folded in, because it restates the same values
as action items.

**Unversioned by design** (`where-next.md:20`). Every Go value below is re-pinned at nats.go v1.53.1
in [[s-nats-go-connection]] and every CLI value at natscli 0.4.0 in [[s-nats-cli-reconnect]]; the
behaviour is measured on 2.14.6 in [[s-nats-server-client-lifecycle-observed]].

## Key claims

### The disconnect, and RECONNECTING (`reconnection.md`)

- A disconnect is "the moment the client notices the link is gone" — the read loop sees the socket
  close, **or a keepalive PING goes unanswered** (L12). The client "fires a disconnect callback so
  the application can log it, but it doesn't close": it moves to RECONNECTING and walks the pool.
- Reconnect is **on by default in every client**: Go `AllowReconnect`, Python `allow_reconnect`,
  JavaScript `reconnect`, Java's `noReconnect()` to turn it off; "Rust and C# have no switch — they
  reconnect until a retry cap (`max_reconnects`, `MaxReconnectRetry`) runs out, unlimited by
  default" (L24).

### Retrying the *first* connect (L32–39)

Most clients try each URL once and return an error; the failure the page names is not a bad address
but **ordering** — "after a deploy, `order-svc`'s container restarts faster than `n1`/`n2`/`n3` come
back, and a fail-fast client crash-loops until the pool exists".

- Go `RetryOnFailedConnect(true)` — `Connect` returns at once in RECONNECTING, and `ConnectHandler`
  is how you learn it came up. JavaScript `waitOnFirstConnect: true`. Python needs no option
  (`await nc.connect()` already retries and raises `NoServersError` only when every server has spent
  its budget). Java uses different entry points, `Nats.connectReconnectOnConnect(options)` and
  `Nats.connectAsynchronously(options, true)`. Rust `retry_on_initial_connect()`. C#
  `RetryOnInitialConnect = true`. **The CLI has no equivalent** (L39).
- The cost is stated: with the opt-in on, "a misconfigured server URL no longer fails loudly at
  startup" and the service "sits in RECONNECTING forever" (L319).

### Backoff, jitter and the attempt budget (L43–59)

- The pause happens **after the client has tried every URL once**, not between individual dials
  (L43).
- **`ReconnectWait` default two seconds** (L45; the sentence names no client — it is Go's option
  name and, by the page's own later sentences, holds for Go, Java, JavaScript and Python).
- **Jitter**: "up to 100ms on a plaintext link and up to 1s on a TLS link" in Go, Java and
  JavaScript; **C# adds up to 100 ms whether or not the link uses TLS**; **Python and Rust add
  none** — Python waits its fixed `reconnect_time_wait`, Rust grows the delay instead (L45).
- Custom delay callbacks: Go `CustomReconnectDelay` (given the number of full sweeps), Java
  `reconnectDelayHandler` (total tries), JavaScript `reconnectDelayHandler` (no arguments, returns
  ms), Python `reconnect_to_server_handler` (given the pool, returns the next server *and* the wait).
  "In Go and JavaScript the returned value is the entire sleep — the client adds no jitter on top"
  (L47).
- **The `nats` CLI is exactly this pattern**: `MaxReconnects(-1)` plus a `CustomReconnectDelay`
  whose "wait starts at 500 ms and grows to a 20-second cap, each step randomized between half and
  one-and-a-half times its value" (L47–57).
- **`MaxReconnect` is a budget per server, not per outage** (L59): each server in the pool carries
  its own count, "a server that uses its count up is dropped from the pool, and the connection gives
  up once no servers are left"; Go and Python reset the count on a successful connect. Defaults:
  **60 in Go, Java and Python; 10 in JavaScript; unlimited in Rust and C#**. A negative value means
  unlimited, and the page's advice for a long-lived service is `-1`.

### The reconnect buffer (L186–195)

- It "holds outbound publishes during RECONNECTING and flushes them, in order, the moment the
  connection is back". **Default 8 MB in Go (`ReconnectBufSize`) and Java (`reconnectBufferSize`),
  2 MB in Python; Rust instead applies backpressure on a bounded queue** (L189).
- "Flush is not a delivery guarantee": on reconnect the client restores subscriptions first, then
  re-sends the buffered publishes in order, "each one still a plain core publish, carrying the same
  at-most-once guarantee" (L191).
- On overflow, **Go, Java and Python fail the publish** (Go with `ErrReconnectBufExceeded`) and
  **Rust blocks** (L193).
- What the buffer does *not* do: restore a JetStream consumer's position — "where it was up to … is
  the JetStream layer's bookkeeping, not the connection's" (L195).

### The keepalive, and the stale link (L325)

- The client "declares the link stale once the outstanding pings exceed `MaxPingsOut`, so with the
  defaults — a two-minute ping interval (one minute in Rust) and two allowed outstanding pings —
  **detection waits for the third unanswered ping, up to about six minutes** (three in Rust)".
- **Whether inbound traffic resets the timer differs by client**: the Go client "sends its keepalive
  PING on the interval no matter how busy the link is — only a PONG clears the outstanding count —
  while the Rust client resets its ping interval every time it receives anything from the server".
  Rust "fixes the ping budget at two".

### The six connection events (`connection-events.md`)

- Per client (L37–44): Go `DisconnectErrHandler`, `ReconnectHandler`, `ReconnectErrHandler`,
  `ClosedHandler`, `DiscoveredServersHandler`, `LameDuckModeHandler`; Python `disconnected_cb`,
  `reconnected_cb`, `closed_cb`, `discovered_server_cb`, `lame_duck_mode_cb`; Java one
  `connectionListener(...)` with `DISCONNECTED, RECONNECTED, RESUBSCRIBED, DISCOVERED_SERVERS,
  LAME_DUCK, CONNECTED, CLOSED`; JavaScript an async iterator `nc.status()` yielding `disconnect,
  reconnect, reconnecting, update, ldm, close`; Rust `event_callback(...)` with `Connected,
  Disconnected, LameDuckMode, Draining, Closed`; C# `ConnectionDisconnected`, `ConnectionOpened`,
  `ReconnectFailed`, `LameDuckModeActivated`. **Rust and C# report no discovered-servers event, and
  C# has no closed event at all** — you read `ConnectionState` instead (L46).
- **The one branch that changes behaviour is disconnected versus closed** (L236–240). "Closed is
  final. The client has stopped trying: no further events arrive, no publish succeeds, and nothing
  inside the client will change that."
- CLOSED can arrive even with unlimited retries: an application `Close()`, a finished drain, or "in
  Go … receiving the same authentication error twice aborts reconnecting regardless of the reconnect
  policy, unless you opt out with `IgnoreAuthErrorAbort`" (L244).
- **Status polling** (L252–257): Go `Status()` over the seven states plus `IsConnected()`,
  `IsReconnecting()`, `IsClosed()`; Python four `is_*` properties; Java `getStatus()` over five;
  Rust `connection_state()` over three (`Pending, Connected, Disconnected`); C# `ConnectionState`
  over five (`Closed, Open, Connecting, Reconnecting, Failed`); **JavaScript has no state getter**
  beyond `isClosed()` and `isDraining()`.
- "A poll is a snapshot, and a snapshot races the state machine… Poll to report state; react through
  events" (L259). Go also offers `StatusChanged()`, a channel defaulting to `CONNECTED,
  RECONNECTING, DISCONNECTED, CLOSED` (L261).
- **The readiness rule** (L268): ready on CONNECTED, **not ready but alive on RECONNECTING**, dead on
  CLOSED — and "killing the process over it throws away the reconnect buffer".
- **Force reconnect** (L393–400): Go `ForceReconnect()` (non-blocking; if already reconnecting it
  skips the current backoff), Java `forceReconnect()` with `ForceReconnectOptions`, Python
  `force_reconnect()`, Rust `force_reconnect()`, C# `ReconnectAsync()`, JavaScript `reconnect()`
  (experimental, rejects if closed or draining) and `setServers()`. It "is a real disconnect with the
  same buffer limits, and must be staggered across a fleet".
- The CLI's outside-in health check is `nats server check connection` (L271, L300–312): connect
  time, RTT and a full publish/subscribe round trip, Nagios exit codes 0/1/2/3, `--format` ∈
  `nagios, json, prometheus, text`, defaults `--connect-warn 500ms --connect-critical 1s
  --rtt-warn 500ms --rtt-critical 1s`. `nats rtt` runs five round trips per server (L318–320).
- **Connection events and async errors are different signals** (L508): Go `ErrorHandler`, Python
  `error_cb`, Java `ErrorListener` keep them apart; "JavaScript and Rust carry both kinds on one
  stream".

## Practical takeaways

- On a long-lived service set `MaxReconnect` to `-1` in Go, Java, Python and JavaScript. The bounded
  default is the one setting that turns a long outage into a permanently dead connection.
- Wire a closed observer even with unlimited retries — an auth error still closes the connection,
  and without the observer a permanent close looks like a disconnect followed by silence.
- Readiness should follow the state machine, not ping the server: RECONNECTING is *not ready and
  still alive*, and restarting the process there throws away the reconnect buffer.
- The keepalive defaults are minutes, not seconds. A wedged (rather than dropped) link is the case
  they cover, and it is the one that hurts.

## Notable quotes

- "Closed is final. The client has stopped trying: no further events arrive, no publish succeeds,
  and nothing inside the client will change that." (`connection-events.md:240`)
- "Poll to report state; react through events." (`connection-events.md:259`)

## Relevance to the wiki

The backbone of [[client-connection-lifecycle]] and of every per-client column in
[[client-defaults]]. The keepalive paragraph is the second witness — with nats.go itself — against
ADR-40's "two consecutive PONGs" reading, recorded as docs issue #90 and corrected on
[[upgrade-a-cluster]] and [[s-adr-40-nats-connection]].

## Questions it answers

Bank rows 177 (what a client does while its server is away, and what it loses), 178 (how long a
client takes to notice a server that is up but not answering) and 82 (the readiness signal a
platform should probe).

## Pages touched

[[client-connection-lifecycle]] · [[client-defaults]] · [[how-clients-reach-a-cluster]] ·
[[upgrade-a-cluster]] · [[evict-a-sick-server]] · [[run-nats-behind-a-proxy]] · [[nats-go]] ·
[[nats-cli]] · [[nats-timeout]]
