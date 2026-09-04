---
title: Worker pool
type: operation
kind: pattern
area: [jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [worker-pool, max_ack_pending, ack_wait, scaling, queue-group, redelivery, idempotency]
aliases: [worker pool, worker-pool, shared consumer, competing consumers]
sources: [s-docs-worker-pool, s-docs-pull-consumers, s-docs-acknowledgment, s-docs-filtering, s-gh-4972-nak-with-delay-blocks, s-nats-server-nak-backoff-observed, s-relnotes-2.10, s-prometheus-nats-exporter-metrics-observed, s-nats-server-request-reply-observed, s-docs-core-nats-queue-groups, s-docs-resilient-clients-drain-and-shutdown]
created: 2026-08-31
updated: 2026-09-04
---

# Worker pool

**Point several processes at one durable [[consumer]] and the server splits the stored messages
between them** — each message to exactly one worker. It is how you scale processing of a stream
without touching the stream or the consumer (source: [[s-docs-worker-pool]]).

## The problem

Messages arrive faster than one process can handle them, and the backlog grows. You need more
throughput without duplicating work, without losing a message when a worker dies, and without
reconfiguring anything each time you scale.

## The design

Every worker runs the same pull loop against the **same durable consumer name**. Nothing is
per-worker: the consumer holds one position, and the server hands each message to whichever worker is
currently asking.

```
# one worker; run this in as many processes as you need
while true; do
  nats consumer next ORDERS shipping --count 1 --ack
done
```

Three properties follow from that, and they are the whole pattern:

- **Distribution follows demand, not assignment.** "A worker only takes a turn while it's actually
  asking. One that's still shipping an order has no pull request open, so the server skips it and
  gives the order to the next worker in line." A faster worker simply pulls more often. You do not
  choose which worker gets what — if you need that, use [[priority-groups]].
- **The position belongs to the consumer, not the worker.** The acknowledgement floor advances the
  same whether one process pulls or ten. There is no per-worker state to create, migrate or clean up.
- **The workers share a position, not the messages.** An ack advances the floor; it does not delete
  the message. Other consumers on the same [[stream]] still see every message — unless the stream's
  retention says otherwise ([[retention-policies]]).

**This is not a queue group.** The distinction matters when a worker is offline:

| | core NATS queue group | workers on one consumer |
|---|---|---|
| splits | **live** messages as they arrive | **stored** messages against the stream |
| storage behind it | none | the stream |
| worker offline when the message arrives | "misses it for good" | "just leaves its share for the others" |

> "Only the stream-backed split survives a worker dropping out or a restart."

## The configuration that implements it

Two consumer settings decide how the pool behaves. Both are described field-by-field on
[[ack-and-redelivery]]; here is what they mean for a *pool*.

**`max_ack_pending` — the concurrency ceiling, shared across the whole consumer.**

```
nats consumer edit ORDERS shipping --max-pending 1000
```

Default **1000**. "The cap is shared across the whole consumer, not per worker: five workers get 1000
between them, not 1000 each." Set it to **at least your worker count, with room to spare** — set it
to 3 and ten workers leave seven idle no matter how much is stored.

**`ack_wait` — how long a failure stays invisible.** Default **30s**. "The server can't tell a crash
from slow work; it only knows the ack hasn't come." Until the timer expires, a dead worker's message
goes to nobody. Set it to your normal processing time: "too short redelivers while a healthy worker
is still working, too long leaves real failures stuck."

**Verify the pool with the consumer, not the workers:**

```
nats consumer info ORDERS shipping
```

```
State:
  Last Delivered Message: Consumer sequence: ... Stream sequence: ...
     Acknowledgment Floor: Consumer sequence: ... Stream sequence: ...
         Outstanding Acks: 0 out of maximum 1,000
```

The two `Acknowledgment Floor` numbers advance together as workers ack; `Outstanding Acks` against
its maximum is the pool's live concurrency against its ceiling. If outstanding sits at the maximum
while workers are idle, `max_ack_pending` is your bottleneck.

## Trade-offs and costs

- **At-least-once, spread across the pool.** When a worker crashes mid-message the server redelivers
  after `ack_wait` — to a *different* worker. "If the dead worker had already shipped the order before
  crashing, it ships twice." **Key side effects by an idempotency key**; the delivery count on the
  message tells a consumer it is a redelivery.
- **The two settings pull against each other.** A high `max_ack_pending` gives throughput and a large
  in-flight set; if many workers die together, that whole set redelivers at once. A low one is safe
  and starves the pool.
- **No control over placement.** Demand-based distribution is the point, and the cost is that you
  cannot pin work to a worker.

## Retries come out of the same budget as concurrency

The pool's ceiling is `max_ack_pending`, and **a message nak'd with a delay keeps its slot for the
whole delay** — it is still pending, because "max pending is used to manage ordering"
(source: [[s-gh-4972-nak-with-delay-blocks]], and see [[ack-and-redelivery]]). So a pool that retries
with delays is spending one budget on two things.

The reporter of that thread ran a pool with `max_ack_pending: 10` and nak'd each message with a
one-minute delay: **the tenth nak stopped the pool dead**, 10 messages handled out of 100 published.
Nothing crashed and nothing logged; `Outstanding Acks` simply sat at its maximum with every worker
idle until the first delay expired. That is the shape to recognise — it looks exactly like a stuck
handler, and `nats consumer info` alone does not tell the two apart.

Two things follow for sizing a pool:

- **The cap must cover workers *plus* the sleeping retry set**, roughly *R × D* extra slots at a nak
  rate of *R* per second and a delay of *D* seconds (arithmetic from the constraint; no source states
  a number). A pool of 10 workers retrying 50 messages a second at a 60-second delay needs a cap in
  the thousands, not tens.
- **Extra consume loops buy nothing.** Running ten `Consume` callbacks against one consumer does not
  give ten workers' worth of slots — the cap is one number per consumer, across goroutines and across
  processes alike. In that thread the apparent improvement came only from dropping `MaxAckPending`
  out of the config, which restored the default of 1000.

When the delay is long, the retry is really a scheduled publish and does not belong on the ack loop
at all — a maintainer recommends the message scheduler over a delayed nak for that work
([[message-scheduling]], [[s-gh-7628-scheduler-vs-nak]]).


### Confirmed on 2.14.6, not inherited from a 2024 thread

The maintainers' "working as designed" is from January 2024, and the same thread has a maintainer
arguing it should change, with no fix version named anywhere. So it was re-run on the current
release: a consumer with `max_ack_pending: 2`, both delivered messages nak'd with a **30-second**
delay, and then another pull — which came back **`408 Request Timeout`** with no message, while two
more sat unprocessed in the stream (source: [[s-nats-server-nak-backoff-observed]], nats-server
v2.14.6, 2026-09-01).

**A stalled pool looks like an idle one.** The pull expires normally, no error mentions the cap, and
nothing is logged. `nats consumer info` is the only place it shows: `Outstanding Acks` pinned at its
maximum with `Unprocessed Messages` above zero.


## When *not* to use it

- **When order matters.** A pool processes messages concurrently; the consumer's order is not the
  workers' completion order. For per-key ordering, partition by subject and give each partition its
  own consumer, or use the client-side partitioned consumer groups in [[orbit]].
- **When you want a specific worker to take everything, with a standby.** That is
  [[priority-groups]] (`pinned_client` or `overflow`), not a pool.
- **When the work is a point read of current state.** If a worker only needs the latest value, it
  does not need a consumer at all — see [[direct-get]].
- **When consumer count, not worker count, is the problem.** Adding workers to one consumer is cheap;
  adding consumers is not ([[jetstream-slows-as-consumers-grow]]).

## Not a queue group, and not several consumers

Two things a worker pool is regularly confused with, and the distinction is the same one either way —
**where the load is shared.**

- **A core NATS queue group** splits one *subject's live traffic* across subscribers. Nothing is
  stored and nothing is replayed.
- **Several consumers on one stream** do not share load at all: "each consumer gets its own full view
  of the stored stream, filtered to what it asked for", so two consumers matching the same subject
  each receive their own copy (source: [[s-docs-filtering]]). That is a fan-out, and on `limits` and
  `interest` streams it is free of interference — see [[consumer]].
- **A worker pool** shares load *within one consumer*, which is why the whole pool shares one
  `max_ack_pending`.

The exception that proves it: on a **`workqueue`** stream the server refuses overlapping consumers
outright, because there the first ack removes the message for everyone ([[retention-policies]]).

## The core queue group, measured

The comparison above rests on what a queue group is: a random pick per message over the members
that are subscribed at that instant — not round-robin, not demand-based, not readiness-aware. Two
members of one group, one running `sleep 1` before every reply, split 20 concurrent requests 12 / 8
and then 8 / 12 on 2.14.6; the slow member answered its share one per second while the fast one sat
idle (run C, source: [[s-nats-server-request-reply-observed]]; the docs' own statement of the rule:
[[s-docs-core-nats-queue-groups]]). A consumer shared by workers is the opposite shape — each worker
pulls when it has capacity — which is why a slow worker here only slows itself. The whole of the core
side, including what a cluster and a leafnode do to the split, is on [[queue-groups]].


## Retiring a worker without losing its in-flight batch

The same rule applies whether the pool is a JetStream consumer or a core [[queue-groups|queue
group]]: stop the server sending *this* worker new work, let it finish what it holds, then exit. That
is a **per-subscription drain**, not a connection close (source:
[[s-docs-resilient-clients-drain-and-shutdown]]).

For a pull worker there are two halves, and only the first is the connection's business:

- **the subscription** — drain it (`Subscription.Drain()` in Go, `sub.drain()` in Python and
  JavaScript, `drain(Duration)` in Java, `Subscriber::drain()` in Rust; **C# has none**) so no new
  fetch is issued and the buffered messages reach the handler;
- **the acks** — a core drain "does not ack JetStream messages". Anything the worker holds un-acked
  when it exits is redelivered to another worker after `ack_wait`, which is correct but is *at least
  once*: the handler must be idempotent, exactly as [[ack-and-redelivery]] says.

In Go, remember that a connection `Drain()` returns before the drain finishes; a worker that exits on
that return abandons the batch it was draining. [[client-connection-lifecycle]] has the phases, the
30 s `DrainTimeout` and the hardcoded 5 s publish flush inside it.


## Version notes

Three 2.10 fixes on WorkQueue streams that a pool depends on (source: [[s-relnotes-2.10]]):
2.10.14 handled "concurrent creation of workqueue consumers that could result in overlapping
interest" (#5295); 2.10.19 fixed a "retention issue that could cause messages to be incorrectly
removed on a WorkQueuePolicy stream when consumers did not cover the entire subject space" (#5697);
2.10.22 fixed consumers that "get stuck with workqueue streams and max messages per subject limits"
(#6003). Below 2.10.22, a lost or stuck work item may be the server's fault before the workers'.


## The series to watch

Four series on [[metrics]] describe a pool from outside (exporter v0.20.2 names, `-jsz=all`):
`jetstream_consumer_num_pending{is_consumer_leader="true"}` is the backlog — the leader's copy only,
the replicas print 0; `jetstream_consumer_num_ack_pending` against the configured `max_ack_pending`
says how close the pool is to the shared ceiling above; `jetstream_consumer_num_waiting == 0` for a
pull consumer means **nobody is fetching**, which is what a stalled pool looks like from the server;
`jetstream_consumer_num_redelivered` counts messages currently outstanding on a second or later
delivery — a level, not a rate, and the max-deliveries drop itself has no series (source:
[[s-prometheus-nats-exporter-metrics-observed]]).


## Related

[[consumer]] · [[ack-and-redelivery]] · [[stream]] · [[retention-policies]] · [[priority-groups]] ·
[[direct-get]] · [[jetstream-slows-as-consumers-grow]] · [[orbit]] · [[replicas]]

## Sources

[[s-docs-worker-pool]] · [[s-docs-pull-consumers]] · [[s-docs-acknowledgment]] ·
[[s-docs-filtering]] · [[s-gh-4972-nak-with-delay-blocks]] · [[s-nats-server-nak-backoff-observed]] · [[s-relnotes-2.10]] · [[s-prometheus-nats-exporter-metrics-observed]] · [[s-nats-server-request-reply-observed]] · [[s-docs-core-nats-queue-groups]] · [[s-docs-resilient-clients-drain-and-shutdown]]
