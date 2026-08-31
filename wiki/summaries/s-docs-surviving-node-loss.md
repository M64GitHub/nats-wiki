---
title: "docs.nats.io — Surviving node loss"
type: summary
area: [jetstream, topology]
source-url: https://docs.nats.io/learn/jetstream/surviving-node-loss.md
source-path: raw/nats-docs/learn/jetstream/surviving-node-loss.md
author: NATS documentation (Synadia Communications, Inc.)
article: Surviving node loss
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [replicas, r3, storage, durability]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Surviving node loss

The operator-facing page on replica count and storage durability: what R=3 buys, what it costs,
and what it explicitly does not do.

## Key claims

- **R=1 has no fault tolerance.** One copy on one server; lose that server's disk and the stream
  is gone — every message and every consumer's position, with no recovery.
- **R=3 is the production floor.** Three copies across three servers; two of three is a majority,
  so the stream keeps serving reads and writes through one server failure with no data loss and
  no manual recovery.
- **R=5 tolerates two simultaneous failures and is the maximum a stream supports.** Most
  production streams run R=3; R=5 is for state that cannot be re-derived.
- **Use odd counts.** R=2 still has a single point of failure — lose either copy and one server
  out of two cannot form a majority, so writes block. R=4 tolerates only one loss, the same as
  R=3, while paying for a fourth copy.
- Every write goes through the **stream leader**, which assigns the sequence number, stores the
  message, and returns the `PubAck` only once a majority of replicas hold it.
- **A publish still in flight when the leader crashes is lost** and never gets a `PubAck`. The
  durability promise covers acked messages only; a client that does not receive a `PubAck` must
  treat the publish as failed and resend.
- **If no majority remains, the group cannot elect a leader and writes are blocked** until enough
  replicas come back. The stream stops rather than accept writes it cannot safely replicate.
- **Storage type is a property of the whole stream, not of individual replicas.** An R=3 stream is
  all `file` or all `memory`; a disk copy cannot be mixed with two RAM copies. `file` is the
  default and survives a restart; `memory` does not.
- Even file storage **does not sync every write to disk right away** — a write can sit unsynced
  after its `PubAck`. See [[s-docs-replication-and-r3]] for the window.
- **Consumer replicas**: by default a durable consumer takes its stream's replica count. On a
  `limits` stream a consumer may be given **fewer** replicas than its stream when its state is
  cheap to rebuild, but **never more**. On `interest` and `workqueue` streams the consumer's
  replica count **must match** the stream's.
- **Replicas are a durability control, not a throughput one.**
  - Stream replicas spread *reads*: a consumer's own leader can sit on any of the stream's
    replicas, and a Direct Get is answered by any replica directly.
  - They do **not** scale writes — every write still goes through the one leader, so a higher
    count *lowers* peak write throughput.
  - They cost load: **R=3 is roughly three times the storage and write traffic of R=1.**
  - Consumer replicas do not scale delivery either: one consumer leader does all the work and the
    followers only stand by.
- To scale throughput: add workers to a consumer, or split subjects across streams — not replicas.

## Commands the page uses

```
nats stream edit ORDERS --replicas=3
nats stream info ORDERS
nats stream info ORDERS --json | grep '"num_replicas"'
```

`nats stream edit ORDERS --replicas=3` **requires a real cluster of at least three servers**; a
single-node server rejects it.

## Relevance to the wiki

The primary source for [[replicas]] — the replica-count decision, the odd-count rule, the R=5
ceiling, the consumer-replica rules, and the "replicas are not a throughput knob" correction that
sizing questions keep needing.

## Questions it answers

Q40 in part (how a cluster survives hardware failure — the stream-level half; the runbook half is
still open).

## Pages touched

[[replicas]] · [[stream]] · [[consumer]] · [[raft-in-nats]]
