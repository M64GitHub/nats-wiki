---
title: "docs: Core Concepts → JetStream — the boundary between at-most-once and at-least-once"
type: summary
area: [jetstream, core]
source-url: https://docs.nats.io/concepts/jetstream
source-path: raw/nats-docs/concepts/jetstream.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "concepts/jetstream.md — the Core Concepts primer, 591 lines, seven language tabs"
tags: [jetstream, core-nats, at-most-once, at-least-once, stream, consumer, cursor, temporal-decoupling]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: Core Concepts → JetStream

The docs' own statement of what JetStream adds and what it costs, in the primer tier rather than the
deep dive. Read for step 7 of `inbox/plan-the-client-side-2026-09-03.md` because it is the shortest
place in the tree where both sides of [[core-or-jetstream]]'s decision are named together.

**Unversioned.** The page names no nats-server version and no ADR. Every version on the pages it
feeds comes from elsewhere.

## Key claims

- **The boundary, in one sentence**: "Core NATS delivers messages only to subscribers connected at
  the moment of publication - at most once, never replayed. JetStream adds a persistence layer on top,
  giving you at-least-once delivery - messages survive restarts and can be replayed."
- **What the persistence layer is actually for** — the framing worth stealing: "Core NATS already
  decouples publisher and subscriber from each other, where a publisher does not need to know about
  the subscriber. **JetStream extends that decoupling to time** - the two no longer need to be online
  at the same moment."
- **Three pieces, not one.** "A **stream** is a server-side store of messages, bound to one or more
  subjects. A **consumer** is a server-side, stateful view of a stream - the server tracks how far a
  client has progressed, so applications don't have to. A **client** is an application that connects
  to a consumer to receive messages and acknowledge them."
- **A stream is bound to subject patterns**, and "when a publisher sends a message to a matching
  subject, the server appends it to the stream and assigns it a sequence number" — the publisher is
  not addressing the stream, and nothing in the publish says a stream is there.
- **Consumers are independent cursors**: "Multiple consumers can read the same stream independently,
  each with its own position… one consumer catching up never moves another's position. The stream
  holds a single shared copy of every message and serves each consumer from where it left off."
- **The ack is what makes it at-least-once**: "An acknowledgment advances the consumer's cursor - if a
  message isn't acknowledged in time, the server redelivers it, which is what gives you at-least-once
  delivery."
- **Start positions**: "from the beginning of the stream, from the latest message, from a specific
  sequence number, or from a specific time."
- **KV and the object store are named as built on this**, not as separate systems: "JetStream also
  provides higher-level abstractions built on top of streams and consumers: **Key Value Store** …
  **Object Store**: Store objects larger than a single message, split into chunks."
- The worked example is `nats stream add ORDERS --subjects "orders.>" --storage file --retention
  limits --defaults`, then `nats consumer add ORDERS order-processor --pull --deliver all --ack
  explicit --defaults`, then `nats consumer next ORDERS order-processor --count 3 --ack`, repeated in
  seven languages.

## Practical takeaways

- The page never says a JetStream publish is a request/reply, never mentions the `PubAck`, and never
  mentions the round trip. The cost of the boundary is entirely absent from the primer — it is in
  `learn/jetstream/publishing.md` ([[s-docs-publishing]]) and in [[s-adr-22-publish-retries]].
- "Extends that decoupling to time" is the useful test for an architect: if the two ends of a flow
  must be online together anyway, the stream is buying nothing.
- The consumer-cursor paragraph is the answer to "why not just have several subscribers": in core
  NATS, several subscribers means several *live* subscribers; in JetStream it means several
  independent positions over one stored copy.

## Relevance to the wiki

The primer statement of the boundary [[core-or-jetstream]] is written to make actionable, and the
docs' own words for [[core-nats-delivery]]'s at-most-once and [[stream]]/[[consumer]]'s division of
labour.

## Questions it answers

Row 133 in part (the boundary itself, not the per-flow decision).

## Pages touched

[[core-or-jetstream]] · [[core-nats-delivery]] · [[stream]] · [[consumer]]
