---
title: "nats: slow consumer, messages dropped"
type: gotcha
area: [clients, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6, nats.go v1.53.1, nats CLI 0.4.0
verified-on: 2026-09-04
tags: [slow-consumer, pending-limits, SetPendingLimits, Dropped, async-error-callback, ErrSlowConsumer]
aliases: ["ErrSlowConsumer", "slow consumer, messages dropped", "client-side slow consumer", "SubscriptionSlowConsumer", "MessageDropped"]
sources: [s-docs-resilient-clients-slow-consumers-and-request-reply, s-nats-go-subscription, s-nats-server-client-errors, s-nats-server-client-faults-observed, s-docs-system-errors, s-nats-go-connection, s-nats-cli-reconnect, s-docs-protocol-client]
created: 2026-09-04
updated: 2026-09-04
---

# `nats: slow consumer, messages dropped`

Your application is losing messages while the connection stays up and the server logs nothing.
This is the **client's own** pending buffer overflowing — a different failure from
[[slow-consumer-detected]], which is the server giving up on your connection. The two share a name
and nothing else.

## Symptom

On stderr, from a Go program that never set an error callback:

```
nats: slow consumer, messages dropped on connection [5] for subscription on "orders.>"
```

or the same string arriving on the connection's async error callback, once every so often rather
than once per message. Alongside it:

- `sub.Dropped()` climbing while `sub.IsValid()` stays `true`;
- `nc.Status()` still `CONNECTED`, `nc.LastError()` set to
  `nats: slow consumer, messages dropped`;
- **nothing in the server log**, and `slow_consumers` on `/varz` unchanged
  (source: [[s-nats-server-client-faults-observed]], A1–A4).

In a synchronous subscriber the same event surfaces as `NextMsg` returning `ErrSlowConsumer` once,
then delivering normally again. Other clients name it differently: nats.net raises a
`MessageDropped` event on `NatsConnection`, JavaScript raises a slow-consumer *status* and drops
nothing (source: [[s-docs-resilient-clients-slow-consumers-and-request-reply]]).

## Quick triage

Three questions, in this order.

```
# 1. Is this the client's fault or the server's? Look at the SERVER.
curl -s http://127.0.0.1:8222/varz | jq '.slow_consumers, .slow_consumer_stats'
```

`0` and all-zero means the server has cut nobody: the drops are entirely inside your process, and
this page is the right one. A non-zero count means read [[slow-consumer-detected]] instead.

```
# 2. Did the connection survive? (it should have)
curl -s 'http://127.0.0.1:8222/connz?state=closed' | jq '.connections[] | {name, reason}'
```

Your connection **not** appearing there confirms it is still open.

3. In the application, print the three numbers that make the diagnosis, per subscription:

```go
pm, pb, _  := sub.Pending()        // what is queued right now
lm, lb, _  := sub.PendingLimits()  // the caps
dropped, _ := sub.Dropped()        // how many were lost
```

`Pending()` sitting at `PendingLimits()` with `Dropped()` climbing is this page's fault, exactly.

## Causes, ranked

### 1. Handler latency × subject rate exceeds the buffer — the ordinary case

The pending buffer exists so a *brief* burst does not block the read loop
(source: [[s-docs-resilient-clients-slow-consumers-and-request-reply]]). When the burst is not
brief, the buffer fills and the arriving message is dropped.

**Confirm**: measure the two numbers. A handler taking 20 ms drains 50 msg/s; anything above that
on the subject accumulates. In the run, a 20 ms handler under 5,000 messages published in 234 ms
delivered **111 and dropped 4,889** (source: [[s-nats-server-client-faults-observed]], A1).

**Fix**, in the order that actually helps:

1. **More subscribers, not a bigger buffer.** A [[queue-groups|queue group]] spreads the subject
   across a pool; each member then needs only its share of the rate. This is the answer the docs
   give too — "the real answer is usually not a bigger buffer but more subscribers sharing the
   load".
2. **Get the work out of the handler.** Hand the message to a worker pool and return; see
   [[worker-pool]].
3. **Put a stream in front of it.** If losing messages is unacceptable, core NATS is the wrong
   transport for this subject — see [[core-nats-delivery]] and [[stream]]. A JetStream consumer
   bounds delivery with `max_ack_pending` instead of dropping.
4. Only then, raise the limit — and only if the backlog is genuinely transient.

### 2. The default limits are the wrong size for your workload

Set at subscribe time, before any message arrives, and they are **not one number**
(source: [[s-nats-go-subscription]], confirmed on a running client in
[[s-nats-server-client-faults-observed]] A1/A4):

| nats.go subscription | default message limit | default byte limit |
|---|---|---|
| async (`Subscribe`, a callback) | `DefaultSubPendingMsgsLimit` = **500,000** | **64 MB** |
| sync (`SubscribeSync`) or channel (`ChanSubscribe`) | the channel capacity — `DefaultMaxChanLen` = **65,536** | **64 MB** |

The docs state "500,000 messages and 64 MB in the Go client" without the distinction
(source: [[s-docs-resilient-clients-slow-consumers-and-request-reply]]). Other clients differ again;
the full table is on [[client-defaults]].

**Confirm**: print `sub.PendingLimits()` right after subscribing.

**Fix**: size the limit to *handler latency × peak rate*, with headroom for a normal burst:

```go
sub, _ := nc.Subscribe("orders.>", handler)
// 100 ms of a 2,000 msg/s subject, bytes left unbounded
if err := sub.SetPendingLimits(200, -1); err != nil { … }
```

Two rules the API enforces and the docs do not state: **zero is an error**
(`SetPendingLimits(0, -1)` returns `nats: invalid argument`) and a **negative value means
unlimited**, not zero (source: [[s-nats-go-subscription]], run A3). Too tight drops messages the
handler would have caught up on; too loose holds a backlog it never will.

### 3. One connection carrying a fast and a slow subscription

The buffer is **per subscription**, so a slow handler on one subject does not starve another — but
the *connection's* read loop is shared, and a handler that blocks long enough delays every
subscription's dispatch behind it. Splitting the slow work onto its own connection isolates the
blast radius and makes the `Dropped()` number attributable.

**Confirm**: `Dropped()` non-zero on exactly one subscription while others are clean.

### 4. Nobody was listening for the report

Not a cause of the drops, a cause of not knowing about them. Contrary to
`learn/resilient-clients/slow-consumers.md:100`, **nats.go does not discard the report when you set
no callback**: it installs `defaultErrHandler`, which writes
`<err> on connection [<cid>] for subscription on "<subject>"` to `os.Stderr`
(source: [[s-nats-go-subscription]]; recorded as docs issue #92). The docs' advice is still right
for the wrong reason — stderr is not where anyone looks, and setting your own handler **replaces**
the default rather than adding to it.

The `nats` CLI is the client that really is silent. It registers an error handler twice
(`cli/util.go:280–292` at 0.4.0) and the second, `--trace`-gated one wins, so a client-side slow
consumer under a plain `nats sub` prints nothing at all — the CLI has replaced the stderr fallback
with a handler that logs only under `--trace` (source: [[s-nats-cli-reconnect]]).

## How often the callback actually fires

Once per **transition into** the state, not once per dropped message — and the state is cleared by
**the next message that fits**, not by the handler catching up (`sub.sc = false` on the success
path). So a sustained overflow re-arms and re-fires: **13 callbacks for 4,888 drops** in the run
(source: [[s-nats-server-client-faults-observed]], A2). Alert on the *rate* of these, and read
`Dropped()` for the loss.

## Prevention

- Set pending limits on every subscription that does real per-message work, and set them from
  measurement rather than from the default.
- Export `Dropped()` per subscription to your metrics; it is the only number that says how much was
  lost. There is no server-side equivalent — the server never sees this.
- Watch the async-error rate and the disconnect rate as **two** signals; they have different fixes.
- If the subject must not lose messages, do not tune the buffer — put a [[stream]] behind it.

## Explained by

[[client-connection-lifecycle]] for the connection's states and callbacks;
[[core-nats-delivery]] for why a core subscriber may lose messages at all.

## Why there is nothing on the wire to match on

Worth stating once, because it is the reason this page has to be about client-side counters rather
than about an error string: `reference/protocols/client.md:431` lists

> `Slow Consumer` — The server pending data size for the connection has reached the maximum size
> (default 10MB).

as one of the fifteen `-ERR`s a client can receive. Neither half holds. The default is
`MAX_PENDING_SIZE = 64 MB` (`const.go:102`), and **no `-ERR` is sent at all** — both server-side
branches close with `skipFlushOnClose` set, so the enqueued bytes are discarded and the client reads
EOF (`inbox/docs-issues.md` #102, source: [[s-docs-protocol-client]]).

A client that waits for a string here waits forever. The five reasons a NATS connection dies without
an error — the two slow-consumer branches, a read error, a write error and a TLS handshake timeout —
are listed on [[wire-protocol]], and telling them apart means reading the server's log or
`/connz?state=closed`, not the socket.


## Related

- [[slow-consumer-detected]] — the server's version of this failure, which closes the connection
- [[client-defaults]] — the per-client pending-limit and callback table
- [[queue-groups]], [[worker-pool]] — the fix that scales
- [[nats-go]] — the Go client's own behaviours

## Sources

- [[s-docs-resilient-clients-slow-consumers-and-request-reply]] — the chapter's model of the buffer,
  the signal, and the per-client divergence
- [[s-nats-go-subscription]] — `SetPendingLimits`, the overflow path, `defaultErrHandler`
- [[s-nats-go-connection]] — `DefaultMaxChanLen` and the connection defaults
- [[s-nats-server-client-errors]] — that the server sends nothing on either slow-consumer branch
- [[s-nats-server-client-faults-observed]] — runs A1–A6 on nats-server 2.14.6
- [[s-docs-system-errors]] — the documented error tables, swept
- [[s-nats-cli-reconnect]] — why a plain `nats sub` prints nothing when it drops messages · [[s-docs-protocol-client]]
