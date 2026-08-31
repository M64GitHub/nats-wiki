---
title: "docs.nats.io — Scaling with a worker pool"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/worker-pool.md
source-path: raw/nats-docs/learn/jetstream/worker-pool.md
author: NATS documentation (Synadia Communications, Inc.)
article: Worker pool
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [worker-pool, max_ack_pending, ack_wait, queue-group, redelivery, scaling]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Scaling with a worker pool

Many processes, one consumer. The page that names what actually caps concurrency
(`MaxAckPending`, shared) and why a stream-backed pool is not a queue group.

## Key claims

**The pattern is: point several processes at the same durable consumer.** "The server hands each
stored order to exactly one worker." Nothing about the stream changes — "Sharing is a property of the
consumer, not the stream: point many workers at one consumer and the server splits the work on any
stream."

**Distribution follows demand, not assignment.** "A worker only takes a turn while it's actually
asking. One that's still shipping an order has no pull request open, so the server skips it and gives
the order to the next worker in line … a faster worker pulls more often and ships more." The server
serves "pull requests in the order they arrived".

**The position belongs to the consumer, not the worker.** "The two `Acknowledgment Floor` numbers
advance together as workers ack … The position belongs to the consumer, not to each worker, so it
advances the same whether one process pulls or three." And: "The workers share a *position*, not the
messages" — an ack advances the position, it does not remove the message, so `billing` and
`analytics` still see every order.

**How it differs from a core NATS queue group** — the docs put this in a section of its own:

| | queue group | workers on one consumer |
|---|---|---|
| splits | **live** messages as they arrive | **stored** messages against the stream |
| storage | none behind it | the stream |
| a subscriber offline when the message arrives | "misses it for good" | "just leaves its share for the others" |

> "Only the stream-backed split survives a worker dropping out or a restart."

**A crash is indistinguishable from slow work.** "The server can't see the crash, only the missing
ack." When `AckWait` expires (**30 seconds by default**) the message goes to another worker. "If the
dead worker had already shipped the order before crashing, it ships twice" — key side effects by an
idempotency key.

**`MaxAckPending` is the concurrency ceiling, and it is shared.** "How many delivered-but-unacked
messages the consumer allows at once, **default 1000** … The cap is **shared across the whole
consumer, not per worker**: five workers get 1000 between them, not 1000 each."

```
nats consumer edit ORDERS shipping --max-pending 1000
```

"Set it too low and workers sit idle waiting for a slot. Set it too high and a slow ack leaves a big
in-progress backlog that all redelivers at once if many workers die together."

**Three pitfalls, stated as such:**

1. **"A redelivered order can arrive at a second worker."** For control over *which* worker gets
   what, the docs point at priority groups: "send everything to one worker until it fails, or keep a
   standby worker idle until the pool falls behind."
2. **"A low `MaxAckPending` starves a large set of workers."** "Set it to 3 and only three messages
   are ever in progress, so ten workers leave seven of them idle no matter how much is stored. Set
   the cap to at least your worker count, with room to spare."
3. **"A crashed worker holds its order until `AckWait`."** "Set `AckWait` to your normal processing
   time: too short redelivers while a healthy worker is still working, too long leaves real failures
   stuck."

## Practical takeaways

- **Two settings, and they pull against each other.** `MaxAckPending` sets how much can be in flight;
  `AckWait` sets how long a failure stays invisible. Sizing a pool means sizing both, against worker
  count and real processing time.
- **"Scale by starting more processes" is literally true** — the consumer is unchanged, so there is
  no reconfiguration step in scaling out, and no per-worker state to clean up when scaling in.
- **The thundering-herd risk is on the redelivery path**, not the delivery path: a high
  `MaxAckPending` plus a correlated failure means everything in flight redelivers at once.

## Notable quotes

> "The workers share a position, not the messages."

> "Only the stream-backed split survives a worker dropping out or a restart."

## Relevance to the wiki

The whole of [[worker-pool]], and the operational reading of `max_ack_pending` that
[[ack-and-redelivery]] and [[consumer]] state as fields.

## Questions it answers

Supports Q15 (what `max_ack_pending` does when reached) with the pool-sizing consequence, and Q22
(what is still pending) with the `Acknowledgment Floor` reading.

## Pages touched

[[worker-pool]] · [[consumer]] · [[ack-and-redelivery]] · [[retention-policies]] ·
[[priority-groups]] · [[replicas]]
