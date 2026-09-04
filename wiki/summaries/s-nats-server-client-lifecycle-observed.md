---
title: "nats-server 2.14.6 observed — a node stopped, lame duck, a drain under load, a stale link, a consumer leader moving"
type: summary
area: [clients, core, jetstream, topology]
source-url: ""
source-path: raw/nats-server-src/client-lifecycle-observed-v2.14.6.md
author: own runs
article: "runs A1–A3, B1–B5, C1/C4, D1–D3, E1–E9 on nats-server v2.14.6 with nats CLI 0.4.0"
date: 2026-09-04
version: "nats-server 2.14.6"
tags: [reconnect, at-most-once, discovery, connect_urls, lame-duck, ldm, grace-period, drain, stale-connection, ping, keepalive, backoff, pull-consumer, no-responders, redelivery]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats-server 2.14.6 observed — a node stopped, lame duck, a drain under load, a stale link, a consumer leader moving

Five runs, each in two shapes where the two ends of a connection lose different things. The scripts
and the full transcripts are in `raw/nats-server-src/client-lifecycle-observed-v2.14.6.md`; A, B, C
and E ran on the three-node lab of `tools/lab/cluster.sh`, D on standalone servers. Everything here
is nats-server **v2.14.6** with the **nats CLI 0.4.0**, whose own connection policy differs from the
library's ([[s-nats-cli-reconnect]]).

## Key claims

### A — a node stopped with SIGTERM

- **A1** subscriber pinned to n1, publisher on n2 at 89 msg/s. n1 stopped: `>>> Disconnected due to:
  EOF, will attempt reconnect` and `>>> Reconnected to nats://127.0.0.1:4293` **in the same second**,
  and the subscriber received **all 1000** messages, first to last, none missing. It had never been
  configured with n3's URL — the pool grew through the `connect_urls` gossip.
- **A2** the mirror image: a publisher pinned to n1 moved to n2 mid-run, finished all 1000 and
  exited 0; the subscriber on n2 received all 1000. **A one-URL client has failover only because of
  discovery** — which is exactly what `no_advertise` removes.
- **A3** the same as A1 with the publisher flat out at **25,800 msg/s**: **199,990 of 200,000
  received, ten missing, sequences 43891–43900, one contiguous run**. That is the at-most-once gap,
  about **0.39 ms** wide. It is that small because nats.go sleeps only after a whole sweep of the
  pool (`doReconnect`, `nats.go:3395`), so with three servers known the first retry is immediate —
  not because anything protects the messages.

### B — lame duck, and the `INFO` a client actually receives

- **B1/B2** n1 signalled `ldm` under the same load: clients stayed on n1 and were disconnected
  **10.0 s later** — `Closing existing clients` at 01:54:11.210 against `JetStream Shutdown` at
  01:54:01.209 — then reconnected, having lost nothing. The 10 s is
  `DEFAULT_LAME_DUCK_GRACE_PERIOD` (`const.go:200`), and it is timed from the **`ldm` INFO**, which
  the server sends only after the leadership transfer and the JetStream shutdown: in B3 the notice
  was 02:00:26.394 and the clients closed at 02:00:37.405, **11.01 s**.
- **B3** the asynchronous `INFO` on the departing server, **about a second after the notice**:
  `"connect_urls":["127.0.0.1:4292","127.0.0.1:4293"]` — n1's own address removed — and
  **`"ldm":true`**. The second is in the code: `lameDuckMode` transfers Raft leadership and waits a
  second, shuts JetStream down, and only then calls `sendLDMToClients` (`server.go:4463–4529`). The
  10 s grace period is timed from **that INFO**, not from the notice — which is why the clients were
  closed 10.001 s after it and 11.011 s after the notice.
- **B4** a client on **n2** receives an `INFO` at the same instant with the same shortened
  `connect_urls` and **no `ldm` key**. A peer's clients learn the pool changed; only the departing
  server's clients learn a server is leaving.
- **B5** a client that sent `CONNECT` but never a `PING` received **no lame-duck `INFO` at all** and
  was closed 13 s later without warning. `sendAsyncInfoToClients` skips every client that has not
  set `firstPongSent` (`route.go:1026–1028`). Every real client pings at connect; this is a property
  of the protocol worth knowing when reading a raw capture.

### C — a drain under load

- **C1** `nats reply --sleep 1s` under 50 requests, Ctrl-C after 2 s: `Draining...` and `Exiting`
  printed in the **same second**, exit code **1**.
- **C4** the same with eight separate single requests, so each outcome is unambiguous: **four
  answered** (rtt 0.83 s, 0.99 s, 1.21 s, 1.84 s) and **four printed nothing at all** and timed out.
  `Drain()` returns as soon as the background drain starts and `log.Fatalf("Exiting")` kills the
  process on that return, so everything already in the responder's buffer is lost. This is the
  pitfall `drain-and-shutdown.md:45` describes, counted.

### D — the stale link, from both ends

- **D1** the **server's** side with `ping_interval: "5s"`, `ping_max: 2`, and a client that never
  answers: `PING` at t=2.186 and t=7.187, then at **t=12.189** — where the third `PING` would have
  gone — **`-ERR 'Stale Connection'`** and the socket closed. Two pings unanswered, the third
  interval closes it. **The server logged nothing** at default level; only `/varz`'s
  `total_connections` moved.
- **D2** the control answered every `PONG` and was still connected at t=22.4, pinged every 5 s.
- **D3** the **client's** side at nats.go's defaults (2 m interval, 2 outstanding pings) with the
  server `SIGSTOP`ped: `>>> Disconnected due to: nats: stale connection, will attempt reconnect` at
  **exactly six minutes** after the connect (02:02:25 → 02:08:25). This is the third ping interval,
  as `processPingTimer` implies ([[s-nats-go-connection]]) and as the chapter says. **ADR-40's "two
  consecutive PONGs are missed" would be four minutes** — docs issue #90.
- The same transcript prints the CLI's backoff: **640 ms, 800 ms, 2.15 s, 1.979 s, 3.424 s,
  1.873 s**. 2.15 s can only come from `Duration(3)` = 1500 ms jittered into [750, 2250], so the
  callback's first call carries **1**, not 0 — nats.go increments the sweep counter before calling
  it (`nats.go:3424–3426`) — and **the table's first entry, 500 ms, is never used** (docs issue #91).

### E — a JetStream pull consumer while its leader's node stops

- **E1–E7** `consumer next --count 100` finished before the leader's node could be stopped, so it
  showed only that leadership moved (n1 → n3) with `ack_floor` intact and nothing redelivered.
- **E8** the same one message at a time, 120 fetches across the stop: **exactly one failed**, with
  `error: no message received: nats: no responders available for request` in **17 ms**, and the next
  iteration succeeded. The `$JS.API` request that lands in the leadership window gets **no
  responders, not a timeout**, and the window is one request wide.
- **E9** ten messages fetched with `--no-ack`, then the consumer leader's node stopped. 35 s later —
  past the 30 s `ack_wait` — the new leader reported `ack_pending 10`, `ack_floor 119`,
  `num_redelivered 0`; the next fetch returned those ten stream sequences **with `tries: 2`** under
  new consumer sequences 130–139, then continued at `tries: 1`. Nothing was lost, the un-acked work
  came back as a redelivery, and `num_redelivered` had not yet counted it.

## Practical takeaways

- The reconnect gap is real and it is small. Measure it as a rate, not a duration: at 89 msg/s
  nothing was lost, at 25,800 msg/s ten messages were. Nothing about the reconnect makes a core
  publish safe — the gap simply got narrower than the message interval.
- Lame duck buys clients **ten seconds** by default, and only a client with the callback wired uses
  them; everything else just gets disconnected later than it would have.
- A drain you do not wait for is a close. Four of eight requests is what that costs at one second
  per handler.
- Six minutes is the default keepalive detection, on both ends of the connection, and the server
  says nothing in its log when it gives up.
- A JetStream client sees a leadership move as **one** `no responders` error, not as a stall.

## Relevance to the wiki

The behavioural half of [[client-connection-lifecycle]]; the *measured* column of
[[client-defaults]]; the lame-duck client view [[upgrade-a-cluster]] promises; the `no responders`
window on [[nats-timeout]]; the redelivery-after-a-leader-move sentence on [[ack-and-redelivery]].

## Questions it answers

Bank rows 177 (what a client sees when its server restarts or enters lame duck, and what is lost),
178 (how long a client takes to notice a dead server) and 179 (stopping a client without losing
in-flight work).

## Pages touched

[[client-connection-lifecycle]] · [[client-defaults]] · [[upgrade-a-cluster]] · [[nats-timeout]] ·
[[nats-cli]] · [[nats-go]] · [[ack-and-redelivery]] · [[consumer]] ·
[[how-clients-reach-a-cluster]] · [[core-nats-delivery]]
