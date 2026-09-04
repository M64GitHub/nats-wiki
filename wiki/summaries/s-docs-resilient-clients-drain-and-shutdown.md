---
title: "docs — Resilient Clients: drain and shutdown"
type: summary
area: [clients, core]
source-url: https://docs.nats.io/learn/resilient-clients/drain-and-shutdown.md
source-path: raw/nats-docs/learn/resilient-clients/drain-and-shutdown.md
author: nats-io docs
article: learn/resilient-clients/drain-and-shutdown.md
date: 2026-08-31
version: ""
tags: [drain, close, DRAINING_SUBS, DRAINING_PUBS, drain-timeout, ErrDrainTimeout, ErrConnectionDraining, subscription-drain, queue-group, flush, rtt, lame-duck, ldm, sigterm]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — Resilient Clients: drain and shutdown

The clean exit: what `Close()` throws away, what `Drain()` finishes instead, the timeout that bounds
it, the per-subscription form used to rotate a queue-group member out, flush as a server-receipt
barrier, and lame duck seen from the client's side. **Unversioned by design**
(`where-next.md:20`); the Go values are re-pinned at v1.53.1 in [[s-nats-go-connection]] and the
behaviour measured on 2.14.6 in [[s-nats-server-client-lifecycle-observed]].

## Key claims

### Close drops in-flight work (L12–18)

- `Close()` "shuts the TCP socket right away, sends no UNSUB, and doesn't wait for in-flight work.
  It flushes whatever is already in the write buffer on its way out, but it stops delivering buffered
  inbound messages to your handlers and **drops the reconnect buffer**." `SIGKILL` "is harsher still:
  it loses the write buffer too."
- Two kinds of in-flight work are distinguished: a **delivered but unhandled message** sitting in the
  subscription buffer, and a **pending publish** still in the write buffer. Close drops the first and
  usually still sends the second.

### Drain finishes it, in two phases (L22–30)

- "In nats.go and nats.py the connection reports each phase as a state — **DRAINING_SUBS**, then
  **DRAINING_PUBS** — while the other clients keep the phases internal." First an UNSUB for every
  subscription, then the handlers finish what is buffered, then every pending publish is flushed,
  then the close.
- C# is the exception: it drains on dispose only with **`DrainSubscriptionsOnDispose`** (L24).
- **Completion differs by client** (L45): "In JavaScript and Python `await nc.drain()` resolves only
  once the drain is done. In Go `Drain()` returns immediately and drains in the background, so you
  register a closed handler (`nats.ClosedHandler`) and wait on it — returning from `Drain()` is not
  the signal that draining finished, and a process that exits on that return loses the very work
  drain was meant to save."
- **The CLI is that pitfall in practice** (L47): `nats sub` on Ctrl-C "just exits, abandoning
  in-flight messages"; `nats reply` "installs an interrupt handler that calls `Drain()` on Ctrl-C —
  the right place for the call. It exits as soon as `Drain()` returns, though, without waiting for
  the background drain to complete, so it shows where the drain belongs rather than a finished
  drain."
- A publish issued after `Drain()` **races the phase change** (L121): accepted during DRAINING_SUBS
  "deliberately, so a handler can send its reply as it finishes", refused during DRAINING_PUBS with
  a draining error (`ErrConnectionDraining` in nats.go). "That race, not a guaranteed error, is why
  drain is the last thing your shutdown does."

### The drain timeout (L125–127)

- "In nats.go and nats.py it's the deadline for the subscription phase: if the in-flight handlers
  don't finish within it, drain stops waiting, **discards the messages that are left**, and moves on
  to the final flush and close anyway."
- "**The pending-publish flush has its own short bound — five seconds, hardcoded, in nats.go.** In
  nats.java the timeout you pass to `drain()` covers the final flush too."
- The error is **`ErrDrainTimeout`**; the **default is 30 seconds in nats.go** (L127), and the page's
  advice is to size it to the slowest handler rather than to a round number. nats.c's
  `natsConnection_DrainTimeout(conn, 10000)` defaults to 30 s and surfaces `NATS_TIMEOUT`
  (L174–186).
- The CLI has **no drain-timeout flag**; the example uses the global `--timeout 30s` (L168).

### Draining one subscription (L213–215)

- The canonical use is rotating one **queue-group member** out: drain that member's subscription and
  "it finishes the orders it holds while the server keeps delivering new orders to the remaining
  members".
- `Subscription.Drain()` in Go, `sub.drain()` in JavaScript and Python, `drain(Duration)` on Java's
  `Subscription` and `Dispatcher` (returning a future), `Subscriber::drain()` in Rust.
- **C# has none**: disposing a subscription drops messages still on their way. Its only drain is the
  connection-level `DrainSubscriptionsOnDispose`, default `false`, whose PING/PONG is bounded by
  `DrainPingTimeout`, five seconds by default (L215).

### Flush (L307–315)

- A flush "sends a PING to the server and waits for the PONG. The server processes what a connection
  sends in order, so when the PONG comes back, the server has also received everything the client
  wrote before the PING."
- "Flush confirms receipt by the server and stops there: it doesn't tell you any subscriber saw the
  message, and it isn't an acknowledgment that a message was stored."
- **Go `Flush()` has a fixed ten-second timeout**, `FlushTimeout()` takes your own (L311); Python
  `nc.flush()`, Java `flush(Duration)`, JavaScript `await nc.flush()`. **C# has no flush call** —
  `PingAsync()` is the same round trip. **Rust's `client.flush()` resolves once the writes reach the
  socket, without waiting for the PONG.**
- The same round trip timed is the latency probe: Go `RTT()`, Python `rtt()`, Java `RTT()`,
  JavaScript `rtt()`, C# `PingAsync()`; **Rust has neither** (L315). The CLI's is `nats rtt`, five
  round trips per reachable server (L338).

### When the server drains first (L379–383)

- "A server entering a graceful shutdown signals **lame duck**: its INFO message carries a flag
  (`ldm`) telling connected clients it's about to go away."
- "That INFO also updates the server list a reconnecting client picks from: the departing server
  sends `connect_urls` holding only the *other* servers, with its own address removed, so a
  reconnecting client won't pick the server that's leaving."

### Pitfalls (L389, L483, L485)

- Drain last: "Drain can't be reversed."
- "A drain timeout shorter than the slowest handler discards the remainder every deploy."
- **"A core drain does not ack JetStream messages"** — unacked in-flight work is redelivered.

## Practical takeaways

- In Go, `Drain()` is a *start*, not a *finish*. Anything that exits on its return has written the
  bug the page describes; `nats reply` is the demonstration, and the measurement in
  [[s-nats-server-client-lifecycle-observed]] (run C4) counts the requests it loses.
- Size the drain timeout from the handler, and remember the publish flush has its own hardcoded 5 s
  in nats.go — a long tail of buffered publishes is not covered by a large `DrainTimeout`.
- A per-subscription drain, not a connection drain, is the tool for rolling one queue-group member.
- Lame duck is a *hint the client may act on*, and only a client with the callback wired acts on it.

## Notable quotes

- "Returning from `Drain()` is not the signal that draining finished, and a process that exits on
  that return loses the very work drain was meant to save." (L45)
- "Flush confirms receipt by the server and stops there." (L309)

## Relevance to the wiki

The drain half of [[client-connection-lifecycle]], the `DrainTimeout` / flush rows of
[[client-defaults]], the *What bites you* entries on [[nats-go]] and [[nats-cli]], and the
per-subscription rotation sentence on [[worker-pool]]. The lame-duck section is what
[[upgrade-a-cluster]] promises from the client's side.

## Questions it answers

Bank row 179 (how to stop a client without losing in-flight work) and the drain half of row 82.

## Pages touched

[[client-connection-lifecycle]] · [[client-defaults]] · [[nats-go]] · [[nats-cli]] ·
[[worker-pool]] · [[upgrade-a-cluster]] · [[queue-groups]] · [[publishing]]
