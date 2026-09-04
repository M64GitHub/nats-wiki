---
title: Event sourcing on JetStream
type: operation
kind: pattern
area: [jetstream, deploy, interop]
since: [2.11]   # the per-pattern expectation header, without which a multi-subject aggregate has no OCC, is 2.11.0
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [event-sourcing, cqrs, aggregate, optimistic-concurrency, "Nats-Expected-Last-Subject-Sequence", "Nats-Expected-Last-Subject-Sequence-Subject", projection, snapshot, tiered-storage, cold-storage, archiving-consumer, time-sharding, ha-assets, kafka-partition]
aliases: [event sourcing, event store, CQRS, aggregate stream, subject per aggregate, DDD on NATS, tiered storage, cold storage, offload to S3]
sources: [s-gh-3772-jetstream-as-an-event-store, s-synadia-expected-sequence-headers, s-gh-3871-tiered-storage-planned, s-gh-6478-s3-offload-and-query, s-nats-server-stream-topology-observed, s-gh-4170-subject-indexing-internals, s-gh-3405-consumer-filtering-performance, s-gh-8333-high-cardinality-subjects, s-gh-5202-max-unique-subjects, s-synadia-how-many-subjects, s-gh-7032-max-msgs-known-good, s-adr-8-key-value-store, s-docs-advanced-publishing]
created: 2026-09-04
updated: 2026-09-04
---

# Event sourcing on JetStream

**Yes, and the design is one stream with a subject per aggregate** — every piece of it is an ordinary
JetStream feature, and the only thing NATS does not give you is a cold tier. This page is the shape,
what it costs at a million aggregates, and the one dead end, from the most-supported design thread in
the discussions index (source: [[s-gh-3772-jetstream-as-an-event-store]], 10 upvotes, chosen answer by
@bruth, **2023-01-08** — a date that matters, because the header set has grown since).

## The problem

An event-sourced system needs four things from its store: an **append-only log per entity**, a
**concurrency check** so two writers cannot both append version 7, **replay** of one entity's history
without reading everything else, and a **total order** for the projections that build read models. Then
it needs to still work at year three, when the entity count is in the millions and most of them are
dead.

## The design

### One stream, a subject per aggregate

> "A stream in NATS (JetStream) is very well suited for event sourcing since every event can be
> published/appended to a subject that represents **an aggregate/entity/consistency boundary of your
> choosing**." — @bruth (source: [[s-gh-3772-jetstream-as-an-event-store]])

```
nats stream add EVENTS --subjects 'events.>' --storage=file --replicas=3 --retention=limits
```

The subject carries the boundary, so the boundary is what a filter can address later:
`events.<aggregate-type>.<id>` for one subject per aggregate, or
`events.<aggregate-type>.<id>.<event-type>` when projections need to select by event type. Which
tokens and in what order is [[subject-design]]; the two rules that bind here are that a token you do not
put in cannot be filtered on afterwards, and that the id must be **bounded by your entity count**, never
per-message.

**Retention is `limits`, and for a true event store, with no limits at all.** Asked for the largest
safe `max_msgs` on a keep-everything stream, the maintainer's answer was that there is none: leave the
limits off, expect disk and the per-subject index to be what eventually bounds it, and **shard by time**
when they do — one stream per year or decade — rather than discard (source:
[[s-gh-7032-max-msgs-known-good]]; [[retention-policies]], *Choosing retention*).

### Appending: optimistic concurrency, and the header most designs get wrong

The check is a header on the publish, and the mechanics — all five headers, the single counter behind
them, and the six rejection codes — are on [[publishing]]. What matters here is **which one an
aggregate needs**:

| the aggregate is… | header(s) | what it protects |
|---|---|---|
| one subject, e.g. `events.order.1` | `Nats-Expected-Last-Subject-Sequence: <n>` | that entity's last append |
| **several subjects**, e.g. `events.order.1.created` and `…shipped` | `Nats-Expected-Last-Subject-Sequence: <n>` **plus** `Nats-Expected-Last-Subject-Sequence-Subject: events.order.1.*` | the entity as a whole |
| the whole stream (rare, and it serialises everything) | `Nats-Expected-Last-Sequence: <n>` | global order |

**The trap is the middle row.** Subjects are exact: `events.order.1.created` and
`events.order.1.shipped` have completely independent sequence tracking, so a per-subject expectation on
one of them protects nothing about the other. The per-pattern header is what makes an aggregate spanning
several subjects share one check (source: [[s-synadia-expected-sequence-headers]]) — and it **arrived in
2.11.0** (#5281), so on a 2.10 server it is silently ignored rather than refused. Sending it *without*
its companion is refused with `10193` only since **2.12.0**; before that the combination failed quietly.
Those two version boundaries are the reason this page carries `since: [2.11]`.

What the design buys, in the words of the thread: "concurrent appends across subjects without
contention, linearizability on a per-subject basis (entity event stream), while still gaining **a total
order of events across all subjects within a stream** for consumption". And the cost of the check is
claimed to be nil — "Subjects are indexed within a stream, so **the OCC check does not add overhead**"
— which is *nearly* right: the per-subject branch does a `store.LoadLastMsg` for the subject on every
such publish, an indexed point read rather than a scan ([[publishing]]).

**Optimistic concurrency is detection, not prevention.** The loser of a race is rejected with
`10071 wrong last sequence: {seq}` and the application retries; the number in that error is *that
subject's* last sequence for a per-subject check and the *stream's* for a global one, so a retry loop
has to know which header it sent (source: [[s-synadia-expected-sequence-headers]]).

**Several events from one command**, atomically, needs 2.12's atomic batch: the stream opts in with
`allow_atomic`, the publisher marks the messages with `Nats-Batch-Id` / `Nats-Batch-Sequence` /
`Nats-Batch-Commit`, and an expectation header on the **first** message makes the whole batch
conditional. The committing `PubAck` is the only proof it landed — a batch can also be abandoned after
ten silent seconds with **no error reply at all**, only a `stream_batch_abandoned` advisory (source:
[[s-docs-advanced-publishing]]; [[publishing]], [[advisories]]). Client support is the practical
constraint, not the server.

### Reading: replay one aggregate, project many

- **One aggregate's history** is a consumer filtered to its subject, and it is an indexed range scan
  rather than a table scan: "if a consumer is filtered to a specific subject, since the index is
  present, it only performs a **linear scan over the blocks between the earliest and latest events for
  that subject**" (source: [[s-gh-3772-jetstream-as-an-event-store]], and the same claim from a second
  maintainer in [[s-gh-3405-consumer-filtering-performance]]). Measured on 2.14.6: one matching message
  in the middle of 1,000,001 is a **0.9 ms** `CONSUMER.CREATE` with `num_pending` **1** and the message
  in **2.3 ms** (source: [[s-nats-server-stream-topology-observed]]).
- **The current state of one aggregate**, without a consumer at all, is [[direct-get]] — a point read
  answered by any replica or mirror, at the price of possibly trailing the leader.
- **Projections and read models** are "many consumers with optional subject-based filtering". They are
  cheap in the numbers that matter: 1,000 filtered consumers on one stream left the publish rate flat
  and cost 0.2 ms per `CONSUMER.INFO`. The ceilings are elsewhere — ~100,000 consumers, and at `R3`
  each one is an HA asset ([[stream-topology-design]]).
- **A full ordered replay** from sequence 1 is an [[ordered-consumer]]; the stream's total order is what
  makes a rebuilt projection deterministic.

### Snapshots, because replay is not free forever

The thread assumes snapshotting may be in play ("depending on whether snapshotting is being used in
conjunction with event streams") and does not specify it. The JetStream-shaped answer is a **[[key-value]]
bucket keyed by aggregate id**: a bucket is a `limits` stream with `max_msgs_per_subject` set to its
history, so history `1` is exactly last-value-per-key, `discard: new`, with `allow_direct` for the point
read (source: [[s-adr-8-key-value-store]]). Store the snapshot's aggregate version alongside it and
replay only the events after it — the same `Nats-Expected-*` sequence you already have.

## What it costs at a million aggregates

A subject per aggregate means **aggregates are subjects**, so the event store's scale question is the
subject-cardinality question. Measured one axis at a time on 2.14.6 — the same 1,000,000 × 128 B
messages over 10, 10,000 and 1,000,000 distinct subjects (source:
[[s-nats-server-stream-topology-observed]], run E; **one laptop**, so ratios, never capacity):

| | 10 | 10,000 | 1,000,000 |
|---|---|---|---|
| RSS with the stream filled | 50.0 MiB | 78.0 MiB | **294.0 MiB** ⇒ ~**256 B per subject** |
| `index.db` after a clean stop | 738 B | 170,549 B | **17,000,550 B** = `Σ(len(subject) + 4)` + ~550 B |
| `Took … to start JetStream` | 130.8 ms | 178.1 ms | **421.2 ms** (604.9 ms after SIGKILL) |
| fill rate | 179,717/s | 185,289/s | 198,078/s — **the publish path did not move** |
| a consumer filtered on **one** subject | 1.1 ms create, 2.5 ms first msg | 0.9 / 1.5 ms | **1.0 / 3.3 ms** — flat |
| a consumer on the **wildcard** | 1.1 / 0.1 ms | — | **18.6 / 19.2 ms** |
| `nats stream subjects` | 0.01 s | 0.04 s | **5.40 s** |

Four consequences for a design that expects millions of entities:

1. **Budget RAM per distinct subject, not per message** — ~256 B here, "in the order of **100 megs**"
   per million short subjects in a maintainer's estimate (source:
   [[s-gh-8333-high-cardinality-subjects]]), "a few hundred bytes" each and "around 10 million subjects
   may add roughly **3–4 GB**" in Synadia's (source: [[s-synadia-how-many-subjects]]), and ~380 B in
   this wiki's earlier 1.2 M-subject run. **And multiply by replicas**: every replica holds the index.
2. **The index does not shrink when an aggregate goes quiet.** It is bounded by *distinct subjects that
   still have messages*, so on a keep-everything stream a dead entity costs its bytes forever. That is
   precisely the shape gh#4170's asker described — "a single AR is only used/appended over a short
   period of time (days)" with millions of new ids per year (source:
   [[s-gh-4170-subject-indexing-internals]]) — and it is the argument for **time-sharding** a stream
   rather than letting one run for a decade.
3. **The per-aggregate read stays cheap and the whole-stream read does not.** A filtered consumer on
   one subject was flat at every cardinality; the wildcard consumer went 170× on create and 190× on
   first message. Projections that read `events.>` are the expensive readers, not the aggregates.
4. **The subject-listing API is paged and slow at that size.** `STREAM.INFO` with `subjects_filter`
   returns at most **100,000** entries per request (`JSMaxSubjectDetails`, `jetstream_api.go:435`) and
   took 372.7 ms per page at a million; `nats stream subjects` took 5.40 s. Operational tooling that
   enumerates aggregates by subject stops being usable long before the store does.

**And above 1,000,000 subjects the periodic `index.db` is no longer written at all**, so an unclean stop
means every block is read at startup ([[jetstream-recovery-is-slow]], [[filestore-layout]]).

The other ceiling is the cluster's, and it is the same unit as everywhere else: "Each stream and
consumer having replicas >1 has an associated raft group… A theoretical upper may be **on the order of
100s of thousands of assets** could likely saturate the network and CPU of the servers within a given
cluster" (source: [[s-gh-3772-jetstream-as-an-event-store]]). So time-sharding buys index size and pays
in assets — [[stream-topology-design]] is that trade.

## The dead end: there is no tiered storage

This is the part of the design that has no NATS answer, and the honest form of it is a date.

- **2023-01-08**, in the event-store thread itself: "Currently, tiered storage support is **not built-in
  as an option to a stream's retention policy**. This has been discussed several times, but needs to be
  prioritized. Depending on whether snapshotting is being used in conjunction with event streams, **a
  separate consumer that is archiving event blocks should be suitable**" (source:
  [[s-gh-3772-jetstream-as-an-event-store]]).
- **2023-02-16**, in the thread opened to ask exactly this: "We have it planned but no schedule yet on
  when we will do this work as of yet." Asked again in **2024-10-31** and **2024-12-07** against Kafka's
  and Pulsar's tiered storage; the maintainer's reply to the first was a question about requirements,
  and there is **no further maintainer comment**. The thread is still open, with no chosen answer, on
  2026-09-04 (source: [[s-gh-3871-tiered-storage-planned]]).
- **The most-upvoted idea in the repository is about this** — 42 upvotes for offloading to S3 with
  Parquet so the history can be queried by third parties — and **no maintainer has commented in it**
  (source: [[s-gh-6478-s3-offload-and-query]]).

**Two workarounds exist in public, and one of them broke.**

- **A block-level offload.** JetStream's store is a directory of sealed ~8 MB blocks, which makes
  "copy the sealed block away and leave a symlink" look easy. One person tried the mount version — an
  rclone S3 backend under `store_dir` with `--vfs-write-back=10m`, so NATS keeps writing locally and
  only untouched sealed blocks migrate — and **it demonstrably worked**, retention deletes included,
  before it began failing with `corrupted on transfer`: "That's where I stopped with this experiment."
  Read the whole thread before copying the screenshots (source: [[s-gh-6478-s3-offload-and-query]]).
  And the reason a native version is not a config key is in the same thread: object stores cannot
  append, charge per operation and punish small files, so a real implementation needs buffering,
  compaction and a cache-back path.
- **An archiving consumer**, which is the maintainer's own suggestion and the only shape that uses
  supported mechanisms: a durable consumer reads the stream and writes elsewhere, and the stream keeps
  a bounded window. It is a client you run and supervise; nothing in the server knows about it.

**The supported way to bound an event store is therefore time**: a stream per period, closed and left
read-only when the period ends, with new events going to the next one (source:
[[s-gh-7032-max-msgs-known-good]]). It bounds RAM, restart time and `index.db` together, and the price
is that a replay spanning periods is a client reading several streams in order.

## Trade-offs and costs

| | JetStream gives you | it costs |
|---|---|---|
| append-only per entity | a subject per aggregate, indexed | ~a few hundred bytes of RAM per distinct subject, per replica, forever while it has messages |
| concurrency control | OCC headers, no locks, no overhead beyond a point read | detection only — the application owns the retry; the multi-subject case needs 2.11+ |
| per-entity replay | an indexed range scan over that subject's blocks | a consumer per reader; wildcard readers pay cardinality |
| total order | one stream is one total order | one stream is also one Raft group and one write path — a NATS stream is **a Kafka *partition***, not a Kafka topic (source: [[s-gh-3772-jetstream-as-an-event-store]]) |
| unbounded history | no message cap and no required limits | disk and the in-memory index; time-sharding when they run out |
| cold storage | **nothing** | an archiving consumer you write, or a bounded window |

## When *not* to use it

- **When you need to query history rather than replay it.** There is no query layer, no SQL, no
  Parquet, and the community thread asking for one has no maintainer in it. Project into something that
  does query.
- **When cold storage is a cost requirement, not a nice-to-have.** "Planned but no schedule" is three
  and a half years old.
- **When entities are unbounded and short-lived.** Millions of new ids a year on a stream that keeps
  everything is a subject index that only grows; either shard by time or accept the RAM.
- **When a command must be atomic across aggregates.** Only the stream-wide expectation gives you
  that, and it serialises every writer — which is the one thing the subject-per-aggregate design was
  bought to avoid. 2.12's atomic batch makes several events land together; it does not make two
  aggregates' invariants one transaction.
- **When you wanted a Kafka topic.** One stream is one partition's worth of ordering and replication;
  the parallelism comes from subjects and consumers, not from partitions ([[subject-transforms]]'s
  `{{partition(n,1)}}` if you need fixed buckets).

## Related

[[stream-topology-design]] · [[subject-design]] · [[publishing]] · [[retention-policies]] ·
[[direct-get]] · [[key-value]] · [[consumer]] · [[ordered-consumer]] · [[stream]] ·
[[filestore-layout]] · [[jetstream-sizing]] · [[jetstream-recovery-is-slow]] ·
[[jetstream-slows-as-consumers-grow]] · [[subject-transforms]] · [[advisories]] ·
[[backup-and-restore-jetstream]]

## Sources

- [[s-gh-3772-jetstream-as-an-event-store]] — the design: a subject per aggregate, the two OCC
  granularities, the indexed range scan, the total order, the asset ceiling, and "tiered storage is not
  built-in".
- [[s-synadia-expected-sequence-headers]] — one counter filtered three ways, the third header for a
  multi-subject aggregate, the version boundaries (2.11.0, 2.12.0) and what a rejection tells you.
- [[s-gh-3871-tiered-storage-planned]] — "planned but no schedule", 2023-02-16, asked twice more and
  never answered; still open.
- [[s-gh-6478-s3-offload-and-query]] — 42 upvotes, no maintainer, the rclone workaround that worked and
  then corrupted, and why object storage is not a filesystem.
- [[s-nats-server-stream-topology-observed]] — run E, the cardinality table; run C1b, the filtered seek.
- [[s-gh-4170-subject-indexing-internals]] — asked *for* an event store: two lookup keys, the subject
  space as the query language, and cardinality as a memory cost.
- [[s-gh-3405-consumer-filtering-performance]] — the second maintainer statement that a filter is not a
  table scan.
- [[s-gh-8333-high-cardinality-subjects]] — ~100 MB of RAM per million short subjects.
- [[s-gh-5202-max-unique-subjects]] — the adaptive radix tree with path compression, and no configured
  maximum: long common prefixes cost little, random suffixes cost most.
- [[s-synadia-how-many-subjects]] — "a few hundred bytes" each, 3–4 GB at ten million, and cardinality
  lengthening recovery.
- [[s-gh-7032-max-msgs-known-good]] — no known-good `max_msgs`: leave the limits off and shard by time.
- [[s-adr-8-key-value-store]] — a bucket is a stream with `max_msgs_per_subject`, which is the snapshot
  store's shape.
- [[s-docs-advanced-publishing]] — atomic batch publishing in 2.12, and the batch that is abandoned
  with no error reply.
