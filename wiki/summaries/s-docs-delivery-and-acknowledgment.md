---
title: "docs.nats.io — Delivery and acknowledgment"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/delivery-and-acknowledgment.md
source-path: raw/nats-docs/learn/jetstream/delivery-and-acknowledgment.md
author: NATS documentation (Synadia Communications, Inc.)
article: Delivery and acknowledgment
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"           # the docs.nats.io latest tree documents nats-server 2.14
tags: [ack, redelivery, max_ack_pending]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Delivery and acknowledgment

The JetStream learn chapter's page on what an acknowledgment does and what happens to a message
that is delivered but never acked. Source of the ack/redeliver loop for [[ack-and-redelivery]].

## Key claims

- **At-least-once** delivery in JetStream comes from two halves: the durable stream, and the
  consumer's ack/redeliver loop. A message stays available and is redelivered until a reader
  confirms it.
- A message on a consumer moves through three states: **delivered / in flight** (the consumer's
  *acknowledgment floor* has not moved past it), **acked** (the floor advances past it), and
  **redelivered** (no ack arrived within **Ack Wait**, so the server assumes the reader failed).
- **Ack Wait defaults to 30 seconds.**
- Consumers have **independent cursors**. The stream holds one shared copy of every message and
  serves each consumer from where that consumer left off; one consumer catching up never moves
  another's position.
- The **delivery count rides on the message** — the CLI prints it as `tries: 1` on a first
  delivery, `tries: 2` on a redelivery — so a reader never needs a `nats consumer info` call to
  know how many times it has seen a message.
- `nats consumer info` reports the gap as three fields: `Last Delivered`, `Acknowledgment Floor`
  and `Outstanding Acks`. Delivered-minus-acked is the in-flight set.
- A **plain ack is fire-and-forget**: the client sends it and moves on. If the ack is lost in
  flight the server never advances the floor, Ack Wait elapses, and the message is redelivered
  to a reader that already handled it.
- A **double ack** sends the ack as a request and waits for the server to confirm it landed. It
  costs a round trip per message, so it is a deliberate choice for work where reprocessing is
  harmful and the handler cannot be made idempotent (the docs' example is a payment capture).
  There is no CLI flag; it is a client-library call, named `DoubleAck` (Go), `ackAck`
  (JavaScript), `ack_sync` (Python), `ackSync` (Java), `AckAsync` with the double-ack option
  (.NET) and `double_ack` (Rust).
- **Redelivery is in delivery order, not stream order.** A consumer normally has several messages
  in flight, so a redelivered message can arrive *after* messages with higher stream sequences.
- **MaxAckPending** is the cap on how many messages a consumer delivers before they are acked;
  the CLI prints it as `Max Ack Pending: 1,000`, and the docs state the default is 1000.
- Setting **MaxAckPending to 1** makes a consumer deliver one message at a time and refuse to move
  past it until it is acked, so a redelivery always comes back before anything new. That is the
  only way to get strict in-order processing, and it costs throughput (no overlap between
  handlers).

## Practical takeaways

- The default consumer configuration (`--ack explicit`, Ack Wait 30s, unlimited deliveries) will
  redeliver a message **forever** if a handler processes it but forgets to ack. A handler that
  never acks is indistinguishable from a crashed reader.
- Do not assume redeliveries arrive in sequence order. Code that assumes ordering needs
  `max_ack_pending: 1` and should accept the throughput cost knowingly.
- Acking the same message twice does nothing useful. Go and Python reject the second ack locally
  with *"message was already acknowledged"*; other clients ignore or resend it, and the server
  ignores the duplicate either way.

## Commands the page uses

```
nats consumer add ORDERS shipping --pull --ack explicit --defaults
nats consumer next ORDERS shipping --ack
nats consumer next ORDERS shipping --no-ack
```

## Relevance to the wiki

The primary source for [[ack-and-redelivery]] and for the delivery half of [[consumer]]. It
supplies the Ack Wait default, the MaxAckPending default, the ack-floor model, and the
out-of-order-redelivery behaviour that explains the most common JetStream support question.

## Questions it answers

Q14 (redelivery of acked messages), Q15 (what `max_ack_pending` does), Q24 (ordering guarantees,
partially — the consumer half).

## Pages touched

[[ack-and-redelivery]] · [[consumer]] · [[stream]]
