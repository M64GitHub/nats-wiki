---
title: Client connection lifecycle
type: concept
area: [clients, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [connection, state-machine, reconnect, backoff, jitter, MaxReconnect, reconnect-buffer, ErrReconnectBufExceeded, keepalive, ping, MaxPingsOut, stale-connection, drain, DrainTimeout, flush, lame-duck, ldm, discovery, connect_urls, readiness, force-reconnect]
aliases: [connection lifecycle, client reconnect, reconnect, reconnection, reconnect buffer, drain, "Drain()", DRAINING_SUBS, DRAINING_PUBS, "stale connection", "nats: stale connection", "Stale Connection", keepalive, ping interval, MaxPingsOut, RECONNECTING, ClosedHandler, lame duck client, ldm, "connection events", readiness probe, ForceReconnect, flush, RTT]
sources: [s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown, s-nats-go-connection, s-nats-cli-reconnect, s-nats-server-client-lifecycle-observed, s-adr-40-nats-connection, s-docs-core-nats-publish-subscribe, s-nats-go-subscription, s-nats-server-client-errors, s-nats-server-client-faults-observed, s-docs-resilient-clients-slow-consumers-and-request-reply, s-docs-resilient-clients-tls-and-auth, s-docs-protocol-client, s-nats-server-wire-protocol, s-docs-services-scaling]
created: 2026-09-04
updated: 2026-09-04
---

# Client connection lifecycle

**A NATS client connection is a state machine, and every fault an operator cares about is one edge of
it.** A server dying is CONNECTED → RECONNECTING → CONNECTED. A SIGTERM is CONNECTED → DRAINING →
CLOSED. A server that is up but not answering is caught six minutes later by the keepalive. This page
is what your application experiences while [[upgrade-a-cluster|the cluster does something]] — the
values, the ordering, and what is lost at each edge.

The numbers here are **nats.go v1.53.1**'s unless another client is named, because the documentation
chapter they come from is unversioned by design and names no client version anywhere (source:
[[s-docs-resilient-clients-connecting]]). Per-client values are in [[client-defaults]].

## The states

`DISCONNECTED · CONNECTING · CONNECTED · RECONNECTING · DRAINING · CLOSED` — the model the docs
teach (source: [[s-docs-resilient-clients-reconnection-and-events]]). nats.go exposes seven, because
it splits draining in two: `DISCONNECTED, CONNECTED, CLOSED, RECONNECTING, CONNECTING,
DRAINING_SUBS, DRAINING_PUBS` (`nats.go:188–216`, source: [[s-nats-go-connection]]). Java reports
five, Rust three (`Pending, Connected, Disconnected`), C# five, and JavaScript has no state getter at
all beyond `isClosed()` and `isDraining()`.

The one branch that changes what an application does is **disconnected versus closed**. A disconnect
is recoverable and the client is already working on it. "Closed is final. The client has stopped
trying: no further events arrive, no publish succeeds, and nothing inside the client will change
that" (source: [[s-docs-resilient-clients-reconnection-and-events]]).

## Connecting

Three options are fixed at connect time and cannot be changed later: the **connection name** (without
it `nats server report connections` and the server log cannot tell your service from anything else),
the **server pool**, and the **connect timeout** — 2 s in most clients, 5 s in Rust, 20 s in
JavaScript. The pool is **randomised before the client dials**, so a fleet restarting together does
not land on one server; the opt-out is a `NoRandomize` variant (`dont_randomize` in Python,
`retain_servers_order` in Rust).

The handshake is four steps: TCP dial (bounded by the connect timeout) → the server's `INFO` →
the client's `CONNECT` and a `PING` → `PONG`, or `-ERR` and a close. `+OK` appears only in verbose
mode, which clients turn off.

**Discovery is what actually gives most deployments their failover.** The server's `INFO` carries
`connect_urls`, and a new `INFO` is sent whenever the set changes. In a run on 2.14.6, a publisher
configured with **one** URL survived that server being stopped and finished on a peer it had never
been told about (source: [[s-nats-server-client-lifecycle-observed]], run A2). That is also the
trap: `no_advertise` in the `cluster` block empties `connect_urls`, and the same client then has no
failover at all. [[how-clients-reach-a-cluster]] has the three designs and when each is right.

Only some clients let you turn discovery off (Go `IgnoreDiscoveredServers`, Java
`ignoreDiscoveredServers()`, Rust `ignore_discovered_servers`, JavaScript `ignoreClusterUpdates`) and
only some report it (Go `DiscoveredServersCB`, Python `discovered_server_cb`, Java
`DISCOVERED_SERVERS`, JavaScript's `update` status). **Python and C# have neither.**

One protocol detail matters when reading a raw capture: the server sends asynchronous `INFO` updates
only to clients that have completed the **first PING/PONG** (`firstPongSent`, `route.go:1026–1028`).
A hand-written client that sends `CONNECT` and stops never learns the pool changed, and never learns
its server is leaving (source: [[s-nats-server-client-lifecycle-observed]], run B5).

## Reconnecting

On a disconnect the client fires a disconnect callback and enters RECONNECTING; **it does not
close**. It walks the pool, and **sleeps only after a whole sweep** — `doSleep = i+1 >=
len(nc.srvPool)` (`nats.go:3395`). With three servers known, the first two attempts have no wait at
all, which is why a measured reconnect gap can be sub-millisecond.

| knob | nats.go v1.53.1 | note |
|---|---|---|
| `ReconnectWait` | `2s` | the wait between sweeps, not between dials |
| `ReconnectJitter` | `100ms` | plaintext |
| `ReconnectJitterTLS` | `1s` | chosen **once for the whole pool**, by `Opts.Secure \|\| TLSConfig != nil` |
| `MaxReconnect` | `60` | **per server**; a server that spends it is removed from the pool |
| `ReconnectBufSize` | `8MB` | publishes held during the gap |
| `AllowReconnect` | `true` | |

**`MaxReconnect` is the setting most worth changing.** It is a budget per server, and
`selectNextServer` drops a server from the pool when it is spent; when the pool empties,
`doReconnect` calls `close(CLOSED)` and the connection is gone for good (`nats.go:2071–2091`,
`:3544–3550`). Set it to `-1` on any long-lived service in Go, Java, Python and JavaScript. Rust and
C# already retry forever.

A custom delay callback **replaces the wait and the jitter both** — `st = crd(wlf)`
(`nats.go:3424–3427`) — so a callback that returns a bare fixed number has removed the jitter that
stops a fleet retrying in lockstep. The `nats` CLI is the canonical example, with a 44-step table
from 500 ms to 20 s, each step randomised to between half and one and a half times its value
(source: [[s-nats-cli-reconnect]]).

### What is lost in the gap

Subscriptions are re-sent automatically, then buffered publishes are flushed in order
(`resendSubscriptions()` then `flushReconnectPendingItems()`, `nats.go:3495–3498`). Neither makes a
core publish safe: **messages published to a subject while your subscriber is between servers are
gone**, exactly as [[core-nats-delivery]] says.

Measured on 2.14.6 (source: [[s-nats-server-client-lifecycle-observed]]): with a subscriber pinned to
the node that was stopped, at **89 msg/s** nothing was lost; at **25,800 msg/s** the same shape lost
**ten messages, one contiguous run** — a gap about **0.39 ms** wide. Read the gap as a rate, not a
duration.

The **reconnect buffer** holds outbound publishes through the gap: 8 MB in Go and Java, 2 MB in
Python; Rust applies backpressure on a bounded queue instead. On overflow Go, Java and Python fail
the publish — Go with `ErrReconnectBufExceeded` (`nats: outbound buffer limit exceeded`) — and Rust
blocks. It is in memory only: `Close()` drops it, killing a RECONNECTING process drops it, and so
does a `Drain()` issued while reconnecting (below).

What the reconnect does **not** restore is a JetStream consumer's position — that is
[[ack-and-redelivery]]'s bookkeeping, not the connection's.

## The keepalive: a link that is wedged, not dropped

A dropped socket is instant. A server that is alive but not reading is caught only by the keepalive,
and the defaults are minutes:

```go
	nc.pout++
	if nc.pout > nc.Opts.MaxPingsOut { … ErrStaleConnection … }
	nc.sendPing(nil)
	nc.ptmr.Reset(nc.Opts.PingInterval)
```
(`nats.go:5899–5921`, source: [[s-nats-go-connection]])

With `PingInterval = 2m` and `MaxPingsOut = 2`, two pings go unanswered and the **third interval**
closes the connection: **six minutes**. Measured against a `SIGSTOP`ped server on 2.14.6, nats.go
printed `>>> Disconnected due to: nats: stale connection` at **exactly six minutes** after the
connect (source: [[s-nats-server-client-lifecycle-observed]], run D3). Rust pings every minute, so
about three; Rust also resets its interval on any inbound byte, while **nats.go pings on the interval
no matter how busy the link is — only a PONG clears the count**.

**The sources disagree, and the server settles it.** [[nats-architecture-and-design|ADR-40]] says
"if two consecutive PONGs are missed, connection is marked as lost", which would be four minutes; the
chapter, the nats.go source and the run all say the third ping. The wiki carries the run's reading;
the disagreement is recorded as docs issue #90 (source: [[s-adr-40-nats-connection]]).

**The server enforces the same shape in the other direction.** With `ping_interval: "5s"` and
`ping_max: 2`, a client that never answered got `PING` at t=2.19 and t=7.19 and then, where the third
would have gone, **`-ERR 'Stale Connection'`** and a closed socket at t=12.19 — and the server
**logged nothing** at default level. Under heavy load, lower `ping_interval` on both ends so a wedged
link is found in seconds; see [[run-nats-behind-a-proxy]] for the proxy timeouts that interact with
this, and [[config-keys]] for the server-side keys.

## Events, and the readiness signal

Six events: disconnect, reconnect, reconnect error, **closed**, discovered servers, lame duck. Their
names per client are in [[client-defaults]]. Two rules:

- **Wire the closed observer on every long-lived service**, even with unlimited retries. Without it a
  permanent close looks like a disconnect followed by silence, while the process still reports
  healthy.
- **Poll to report state; react through events.** A status poll races the state machine.

The readiness rule follows directly: **ready** on CONNECTED, **not ready and still alive** on
RECONNECTING, **dead** on CLOSED. Restarting a process because it is RECONNECTING throws away its
reconnect buffer. The outside-in equivalent is `nats server check connection` — connect time, RTT and
a full publish/subscribe round trip, Nagios exit codes, `--format nagios|json|prometheus|text` — but
it probes the pool, not your process's connection.

`ForceReconnect()` (Go; `forceReconnect()` in Java, `force_reconnect()` in Python and Rust,
`ReconnectAsync()` in C#, the experimental `reconnect()` in JavaScript) is a real disconnect with the
same buffer limits, so stagger it across a fleet.

## Draining, and closing

`Close()` shuts the socket at once, sends no `UNSUB`, stops delivering buffered inbound messages and
**drops the reconnect buffer**. It does flush the write buffer on the way out; `SIGKILL` loses that
too.

`Drain()` finishes the work instead, in two phases:

1. **DRAINING_SUBS** — an `UNSUB` for every subscription, then wait for the handlers, polling every
   10 ms until `DrainTimeout` (**30 s** in nats.go). On expiry the remaining messages are
   **discarded** and `ErrDrainTimeout` is pushed to the **async error callback** — it is not returned
   by `Drain()`, so a service with no error callback never learns its shutdown was cut short.
2. **DRAINING_PUBS** — every pending publish is flushed with a **hardcoded 5 s** `FlushTimeout`
   (`nats.go:6291`), then `Close()`.

Three things bite here:

- **In Go, `Drain()` returns immediately.** It flips the state and starts a goroutine. Waiting for
  the drain means waiting on `ClosedHandler`. A process that exits on `Drain()`'s return "loses the
  very work drain was meant to save" — measured: `nats reply` does exactly that, and with one second
  of handler latency **four of eight in-flight requests were answered and four were abandoned**
  (source: [[s-nats-server-client-lifecycle-observed]], run C4; the CLI's code is in
  [[s-nats-cli-reconnect]]).
- **A drain issued while the connection is CONNECTING or RECONNECTING calls `Close()`**
  (`nats.go:6211–6215`, `:6310–6314`) and returns `ErrConnectionReconnecting`. Draining through an
  outage therefore discards the reconnect buffer rather than flushing it. The documentation does not
  say so.
- **A publish after `Drain()` races the phase change** — accepted during DRAINING_SUBS so a handler
  can still reply, refused during DRAINING_PUBS with `ErrConnectionDraining`. Drain last.

**Per-subscription drain** is the tool for rotating one queue-group member out without dropping its
in-flight work: `Subscription.Drain()` in Go, `sub.drain()` in JavaScript and Python,
`drain(Duration)` in Java, `Subscriber::drain()` in Rust. **C# has none** — disposing a subscription
drops what is in flight, and its only drain is the connection-level `DrainSubscriptionsOnDispose`
(default `false`). See [[queue-groups]] and [[worker-pool]].

A **core drain does not ack JetStream messages.** Un-acked in-flight work is redelivered; that is
[[ack-and-redelivery]]'s business.

## Flush is a receipt, not a delivery

A flush is a `PING`/`PONG` barrier. Because the server processes a connection's bytes in order, a
returned `PONG` proves the server received everything written before the `PING`. It proves nothing
about subscribers and nothing about storage — that is [[publishing]]'s `PubAck`. Go's `Flush()` is
`FlushTimeout(10 * time.Second)`; **Rust's `flush()` resolves when the bytes reach the socket,
without waiting for the PONG**, and **C# has no flush** (`PingAsync()` is the same round trip).

## Lame duck, as the client sees it

When a server enters lame duck it sends its clients an asynchronous `INFO` with **`"ldm":true`** and
a `connect_urls` list with **its own address removed**, so a reconnecting client will not pick it.
Then it waits `lame_duck_grace_period` — **10 s** by default — before it starts closing anything, and
spreads the closes over `lame_duck_duration` (2 m by default). Observed on 2.14.6 (source:
[[s-nats-server-client-lifecycle-observed]], runs B1–B4):

- the `ldm` INFO reached the client **about a second after the notice**, carrying `connect_urls`
  `["127.0.0.1:4292","127.0.0.1:4293"]` and `"ldm":true`. The second is in the code, not the
  network: `lameDuckMode` transfers Raft leadership and waits a second, shuts JetStream down, and
  only then calls `sendLDMToClients` (`server.go:4463–4529`);
- clients were closed **10.0 s after that INFO** — 11.0 s after the notice. The grace period is
  timed from the INFO, so on a JetStream node the clients' warning is the full 10 s and the
  operator's is a second less;
- a client on a **peer** received an `INFO` at the same instant with the same shortened
  `connect_urls` and **no `ldm` key**: peers learn the pool changed, not that a server is leaving;
- nothing was lost in either direction at 89 msg/s.

Ten seconds is what lame duck buys a client, and only a client with the callback wired spends them
(`LameDuckModeHandler` in Go, `lame_duck_mode_cb` in Python, the `LAME_DUCK` event in Java, `ldm` in
JavaScript's status stream, `Event::LameDuckMode` in Rust, `LameDuckModeActivated` in C#). Everything
else is simply disconnected at the end of the grace period. [[upgrade-a-cluster]] is the operator's
side of the same event.

## What a JetStream client sees when a leader moves

A pull consumer fetching one message at a time across its consumer leader's node being stopped lost
**one fetch out of 120**, with `nats: no responders available for request` in 17 ms; the next fetch
succeeded (source: [[s-nats-server-client-lifecycle-observed]], run E8). The `$JS.API` request that
lands in the leadership window gets **no responders, not a timeout** — the distinction
[[nats-timeout]] exists to draw.

Messages already delivered and un-acked when the leader moved were **not** lost: 35 s later the new
leader still showed `ack_pending 10`, and the next fetch returned those stream sequences with
`tries: 2` (run E9).

## The two faults that do not disconnect you, and the one that ends the connection

The reconnect loop above handles faults that come from outside: a node stops, a link goes stale, a
server enters lame duck. Three more arrive on a *healthy* connection, and each takes a different
path through the client.

**A subscription's pending buffer overflows.** Nothing about the connection changes: the arriving
message is dropped, the subscription stays valid, the status stays CONNECTED, and the async error
callback gets `ErrSlowConsumer` — once per transition into the state, and the state clears on the
next message that fits (source: [[s-nats-go-subscription]]). The server is not involved and never
learns of it. Full page: [[slow-consumer-in-the-client]].

**The server refuses a subject.** A permissions violation is *transient* in nats.go: it goes through
`processTransientError`, which fires the callback and records the failure on the matching
subscription, leaving the connection up (source: [[s-nats-go-subscription]]). See
[[subject-permissions]].

**A credential expires or is rejected.** This is the one failure the reconnect loop deliberately
stops retrying. `processErr` recognises four auth strings — `authorization violation`,
`user authentication expired`, `user authentication revoked`, `account authentication expired` —
and hands them to `processAuthError`, which aborts when **the same error arrives from the same
server twice in a row**, unless `IgnoreAuthErrorAbort` is set. The abort ignores the retry budget:
unlimited reconnects do not override it (source: [[s-docs-resilient-clients-tls-and-auth]]).
CLOSED is then terminal — only the closed handler can tell the application. Full page:
[[connection-closed-after-auth-error]].

Everything `processErr` does **not** recognise closes the connection outright
(source: [[s-nats-go-subscription]]), which is worth knowing before adding a custom `-ERR` on the
server side.

## Where credentials enter the handshake

`UserCredentials(path)` is not a parsed file held in memory: it stores two callbacks, and the JWT
one calls `os.ReadFile` (source: [[s-nats-go-subscription]]). `connectProto` runs both on **every**
connect and reconnect attempt, signing the *current* `INFO`'s nonce — so a rotated file on disk is
picked up at the next connection cycle with no code, and a half-written file at that instant fails
before any `CONNECT` is sent. nats.java and nats.py behave the same way; nats.js, nats.rs and
nats.net load once and need a credential callback for a rotation to reach a reconnect at all
(source: [[s-docs-resilient-clients-tls-and-auth]]). See [[operator-mode]] for where the file comes
from.

The same function decides one more thing: `no_responders` is sent only when the server's `INFO`
advertised `headers`, because both fields come from the same value (source:
[[s-nats-go-subscription]]). See [[request-reply]].


## The server's side of the keepalive, timed

The client's own stale detection is above; this is what the *server* does, and the two rules are the
same shape. `processPingTimer` closes a connection when `ping.out + 1 > maxPingsOut` — that is, on
the timer **after** the last allowed unanswered ping, so the wall-clock budget is
**`(ping_max + 1) × ping_interval`**. With the defaults (`ping_interval: 2m`, `ping_max: 2`) that is
**six minutes**, the same number nats.go measures from the other end.

Observed on 2.14.6 with `ping_interval: 2s, ping_max: 2` and a client that never answers
(source: [[s-nats-server-wire-protocol]]):

```
[     1.6 ms] >> CONNECT {"verbose":false}
[  2137.9 ms] << PING
[  4138.6 ms] << PING
[  6139.9 ms] << -ERR 'Stale Connection'
[  6140.0 ms] -- socket closed by the server
```

Two PINGs go unanswered and the connection survives. The server logs nothing at default level.

**Only a client gets the traffic proxy.** `processPingTimer` sends unconditionally for `ROUTER`,
`GATEWAY` and a spoke `LEAF` (`client.go:5846–5857`); for a client, inbound data within the interval
counts as a PONG, which is what `reference/protocols/client.md:363` describes. The first ping is also
different: `firstClientPingInterval = 2s` for a client and `firstPingInterval = 1s` for everything
else, plus up to 20 % random offset (`client.go:6994–7029`).

**`Stale Connection` is the one `-ERR` that does not go through `sendErr`** — it is written straight
with `enqueueProto` (`client.go:5867`, `:5908`), which is why it survives paths where other errors do
not. The full inventory is [[wire-protocol]].

### `CONNECT {}` is a verbose connection

Nothing in a `CONNECT` is required, and three fields default to **`true`** when omitted:
`var defaultOpts = ClientOpts{Verbose: true, Pedantic: true, Echo: true}` (`client.go:706`). A
hand-written client or a `telnet` session that sends `CONNECT {}` gets an `+OK` for every op and must
read them — observed (source: [[s-docs-protocol-client]]). Every library sends `"verbose":false`
explicitly; the CLI's own line is on [[wire-protocol]].


## Draining a service is two steps, not one

A [[services-framework]] service adds a drain of its own above the connection drain this page
describes, and they are not interchangeable. `Stop()` drains the endpoint subscriptions and the `$SRV`
discovery subscriptions, so the server routes no new requests to this instance; it returns before
in-flight handlers finish. The connection drain is what waits for them (source:
[[s-docs-services-scaling]]).

So a graceful shutdown is: `Stop()`, then drain or wait on the framework's done callback, then close.
The docs' scaling page says it plainly — "don't exit the process the moment it returns". Skipping the
second step drops exactly the work the first step was protecting; see [[services-on-core-nats]].


## Related

[[core-nats-delivery]] · [[client-defaults]] · [[how-clients-reach-a-cluster]] ·
[[upgrade-a-cluster]] · [[nats-timeout]] · [[slow-consumer-detected]] · [[ack-and-redelivery]] ·
[[queue-groups]] · [[worker-pool]] · [[publishing]] · [[nats-go]] · [[nats-cli]] ·
[[run-nats-behind-a-proxy]] · [[evict-a-sick-server]]

## Sources

- [[s-docs-resilient-clients-connecting]] — the state machine, connect options, discovery, the
  handshake.
- [[s-docs-resilient-clients-reconnection-and-events]] — backoff, jitter, `MaxReconnect`, the
  reconnect buffer, the keepalive, the six events, readiness.
- [[s-docs-resilient-clients-drain-and-shutdown]] — close vs drain, the timeout, per-subscription
  drain, flush, lame duck.
- [[s-nats-go-connection]] — nats.go v1.53.1: every default and every rule quoted above.
- [[s-nats-cli-reconnect]] — natscli 0.4.0: the policy the CLI substitutes, and `nats reply`'s exit.
- [[s-nats-server-client-lifecycle-observed]] — the runs on 2.14.6 behind every measured number.
- [[s-adr-40-nats-connection]] — ADR-40, and the keepalive disagreement it is one side of.
- [[s-docs-core-nats-publish-subscribe]] — the at-most-once promise the reconnect gap is an instance
  of. · [[s-nats-go-subscription]] · [[s-nats-server-client-errors]] · [[s-nats-server-client-faults-observed]] · [[s-docs-resilient-clients-slow-consumers-and-request-reply]] · [[s-docs-resilient-clients-tls-and-auth]] · [[s-docs-protocol-client]] · [[s-nats-server-wire-protocol]] · [[s-docs-services-scaling]]
