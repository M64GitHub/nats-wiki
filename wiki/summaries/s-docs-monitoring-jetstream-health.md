---
title: "docs — Monitoring: JetStream health"
type: summary
area: [monitoring, jetstream]
source-url: https://docs.nats.io/learn/monitoring/jetstream-health.md
source-path: raw/nats-docs/learn/monitoring/jetstream-health.md
author: nats-io docs
article: "learn/monitoring/jetstream-health.md"
date: 2026-09-01
version: ""
tags: [lag, num_pending, num_ack_pending, num_redelivered, num_waiting, ack_floor, last_seq]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — Monitoring: JetStream health

The page that defines **lag** as an arithmetic expression and then spends its pitfalls separating it
from the two numbers people confuse it with.

## Key claims

**Lag has a formula:**

```
lag = stream.last_seq − consumer.delivered.stream_seq
```

and "a pull consumer also reports this same value directly as **Unprocessed Messages**
(`num_pending`), so most of the time you read it off `nats consumer info` rather than subtracting by
hand. Computing it from the two source fields yourself is worth doing once, to see exactly what
`num_pending` measures."

**Three numbers describe a consumer's health**, and they move for different reasons:

| number | field | means |
|---|---|---|
| **lag** | `num_pending` | orders waiting, never delivered |
| **in-flight** | `num_ack_pending` | delivered, not yet acked |
| **redelivered** | `num_redelivered` | currently tracked as delivered more than once |

"A healthy consumer keeps lag near zero and `num_redelivered` near zero."

**`num_redelivered` is not a lifetime tally.** "When one of those orders is finally acked the server
stops tracking it and the count drops back down."

**`ack_floor.stream_seq` is the sequence below which every message has been acked**, which is what
separates the never-delivered group from the delivered-but-unacked one.

**Three pitfalls, each a number that misleads alone:**

- **Crashed workers look like a healthy backlog.** "The server updates [`num_pending`] on every new
  matching order, whether or not any client is fetching. So a high `num_pending` on its own is
  ambiguous." The signature is the **combination**: "lag rising while **Waiting Pulls**
  (`num_waiting`) sits at `0` and `delivered.stream_seq` stops advancing."
- **In-flight is not lag.** "A handler that fetches orders and then hangs shows a steady, non-zero
  in-flight count while lag quietly grows behind it… rising in-flight means a stuck handler, rising
  lag means not enough handlers."
- **A filtered consumer's lag counts only its subjects.** "An empty pending on a filtered consumer
  doesn't mean the `ORDERS` stream is empty; it means nothing on *that filter* is waiting… Compare it
  against the stream's per-subject counts, not against `last_seq`."

**Stream state fields named**: `messages`, `bytes`, `first_seq`, `last_seq`, `num_subjects`. "Only the
state half moves."

## Practical takeaways

- The three-field crashed-worker signature (`num_pending` up, `num_waiting` 0, `delivered.stream_seq`
  flat) is the most directly actionable diagnostic on the page, and it is not obvious from any single
  field.
- `num_ack_pending` and `num_pending` answer different questions and a dashboard that shows one
  "behind" number hides a stuck handler.

## Notable quotes

> "Rising in-flight means a stuck handler, rising lag means not enough handlers."

> "Naming which number moved is the first step every time."

## Relevance to the wiki

[[stream-has-high-message-lag]] is built from the server's warning threshold and a GitHub thread; it
had no statement of what lag *is* as a number, nor the crashed-worker signature. Both land there.

## Questions it answers

None in the bank directly; supports [[stream-has-high-message-lag]] and [[monitoring-endpoints]].

## Pages touched

[[stream-has-high-message-lag]] · [[monitoring-endpoints]] · [[consumer]]

## Sources

`raw/nats-docs/learn/monitoring/jetstream-health.md`
