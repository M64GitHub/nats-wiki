---
title: Worker pool
type: operation
kind: pattern
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [worker-pool, max_ack_pending, ack_wait, scaling, queue-group, redelivery, idempotency]
aliases: [worker pool, worker-pool, shared consumer, competing consumers]
sources: [s-docs-worker-pool, s-docs-pull-consumers, s-docs-acknowledgment]
created: 2026-08-31
updated: 2026-08-31
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

## Related

[[consumer]] · [[ack-and-redelivery]] · [[stream]] · [[retention-policies]] · [[priority-groups]] ·
[[direct-get]] · [[jetstream-slows-as-consumers-grow]] · [[orbit]] · [[replicas]]

## Sources

[[s-docs-worker-pool]] · [[s-docs-pull-consumers]] · [[s-docs-acknowledgment]]
