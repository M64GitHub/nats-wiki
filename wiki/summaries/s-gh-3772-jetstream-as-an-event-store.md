---
title: "gh#3772 — JetStream as an event store"
type: summary
area: [jetstream, interop]
source-url: https://github.com/nats-io/nats-server/discussions/3772
source-path: raw/gh-discussions/gh-3772.md
author: "@cloudcompute (asker); @bruth (maintainer, chosen answer); @shafqatevo, @hpvd"
date: 2023-01-08
version: ""
article: "GitHub discussion 3772, Q&A, chosen answer, 5 comments and 9 replies, 10 upvotes"
tags: [event-sourcing, cqrs, aggregate, optimistic-concurrency, Nats-Expected-Last-Subject-Sequence, tiered-storage, cold-storage, ha-assets, kafka-partition]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#3772 — Using Nats Jetstream as an event store

Ten upvotes, the most-supported design thread in the discussions index, and the public form of
question-bank **row 144**. Chosen answer by @bruth the same day; the thread then runs for two more
years and collects the scale and storage answers the original question did not ask for.

## The question

@cloudcompute, 2023-01-08, three parts: (a) can JetStream be used for event sourcing, storing millions
of events without hurting the application; (b) the docs mention archiving event logs to cold storage —
how, and is it "as powerful as Pulsar's Tiered Storage"; (c) is anyone using it as an event store in
production.

## Key claims

**(a) Yes, and the design is a subject per aggregate.**

- "A stream in NATS (JetStream) is very well suited for event sourcing since every event can be
  published/appended to a subject that represents **an aggregate/entity/consistency boundary of your
  choosing**. For example, a stream called `orders` with subjects `orders.*` bound to it."
- **Optimistic concurrency, at two granularities**: "You can enforce optimistic concurrency on a
  stream-level or a per-subject level within a stream using a message header,
  `Nats-Expected-Last-Sequence` or `Nats-Expected-Last-Subject-Sequence`, respectively, whose value is
  the expected sequence. Of course, if the sequence in the published message does not match what the
  server has for the stream or subject, then the publish will be rejected."
- **What that buys**: "concurrent appends across subjects without contention, linearizability on a
  per-subject basis (entity event stream), while still gaining **a total order of events across all
  subjects within a stream** for consumption."
- **The cost of the check is stated as zero**: "Subjects are indexed within a stream, so **the OCC
  check does not add overhead**, and a stream in general can grow as large as you have resources to
  support it."
- **Replay is a range scan, not a full scan**: "if a consumer is filtered to a specific subject, since
  the index is present, it only performs a **linear scan over the blocks between the earliest and
  latest events for that subject**."
- CQRS read models are "many consumers with optional subject-based filtering".

**(b) No tiered storage — then, and the thread never updates it.**

- "Currently, tiered storage support is **not built-in as an option to a stream's retention policy**.
  This has been discussed several times, but needs to be prioritized. Depending on whether snapshotting
  is being used in conjunction with event streams, **a separate consumer that is archiving event blocks
  should be suitable**."
- A 2025-03-26 comment points at [gh#6478](https://github.com/nats-io/nats-server/discussions/6478)
  ("S3 next level") as the general approach for tiering — not read for this ingest.

**(c) No production list.** "There certainly has been an increasing amount of interest from the
DDD/ES/CQRS community, however I don't have a list of folks using it in production today", with one
named talk and the observation that the features involved are used heavily elsewhere.

**The storage layer, answered later in the thread (2023-01-09):**

- "NATS has it own custom storage layer that supports both in-memory and file-based persistence. It
  combines a traditional append-only log style structure for making writes fast, however it supports
  some traditional 'data store' kind of operations, such as being able to get an individual message or
  mark a message for deletion."
- **The comparison that keeps being got wrong**: "Many people compare a Kafka topic with a NATS stream,
  but this is not correct. It would be more accurate that **a single *partition* is comparable to a
  NATS stream** since it is the unit of total ordering and replication." To emulate a multi-partition
  subject space, use deterministic subject-token partitioning.

**The scale ceiling, answered 2023-03-01 and unquantified anywhere else:**

- "The theoretical upper bound is based on the **raft traffic**. At a steady state, this would be heart
  beats among all the raft groups. **Each stream and consumer having replicas >1 has an associated raft
  group.** So there will be a small amount of traffic overhead per *asset* created. A theoretical upper
  may be **on the order of 100s of thousands of assets** could likely saturate the network and CPU of
  the servers within a given cluster."
- And on cluster size: "since all servers form a full mesh … a cluster can only grow so large before
  saturation occurs."

## Practical takeaways

- The event-store design is not exotic: one stream, one subject per aggregate, `Nats-Expected-*` on
  publish, filtered consumers for projections. Everything in it is an ordinary JetStream feature.
- **Every claim in it is dated 2023-01** and must be re-checked: the header set has since grown a third
  member (`Nats-Expected-Last-Subject-Sequence-Subject`, 2.11.0), and "no tiered storage" is a claim
  about a roadmap, not about a mechanism.
- The scale answer is the same unit [[jetstream-slows-as-consumers-grow]] calls an **HA asset**, from a
  different maintainer two years earlier — Raft groups per replicated stream *and consumer*, hundreds
  of thousands as a theoretical ceiling. It is the number a "how many streams" answer has to respect.
- "A NATS stream is a Kafka partition" is the sentence to hand anyone migrating.

## Notable quotes

> "every event can be published/appended to a subject that represents an aggregate/entity/consistency
> boundary of your choosing" — @bruth, 2023-01-08

> "Subjects are indexed within a stream, so the OCC check does not add overhead" — @bruth, 2023-01-08

> "Currently, tiered storage support is not built-in as an option to a stream's retention policy." —
> @bruth, 2023-01-08

> "It would be more accurate that a single *partition* is comparable to NATS stream since it is the
> unit of total ordering and replication." — @bruth, 2023-01-09

## Relevance to the wiki

Bank row 144's asked form and its whole answer, from a maintainer, with the one dead end (tiering)
named. Also the second public statement of the Raft-asset ceiling, and the Kafka-partition equivalence
that row 136 will need.

## Questions it answers

Row 144; row 112 in part (the two OCC granularities); corroborates rows 108, 111 and 153 on the
asset ceiling.

## Pages touched

[[stream]] · [[publishing]] · [[filestore-layout]] · [[raft-in-nats]]
