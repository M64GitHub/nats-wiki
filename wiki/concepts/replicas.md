---
title: Replicas
type: concept
area: [jetstream, topology]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [replicas, r3, r5, durability, quorum, sync_interval]
aliases: [replication, R1, R3, R5, num_replicas, replica count]
sources: [s-docs-surviving-node-loss, s-docs-replication-and-r3, s-docs-stream-config, s-docs-raft-and-leaders, s-docs-sizing-and-resources, s-adr-31-direct-get, s-docs-mirrors-as-dr]
created: 2026-08-31
updated: 2026-08-31
---

# Replicas

A [[stream]]'s `num_replicas` is how many copies of its message log the cluster keeps, each on a
different server. The copies form one RAFT group ([[raft-in-nats]]) with a leader that takes every
write. **Replicas are a durability control, not a throughput one** — that distinction is the single
most useful thing on this page.

## How it behaves

- **R=1** is one copy on one server. There is no second peer, so nothing to commit *to*: lose that
  server's disk and the stream is gone — every message and every consumer's position, with no
  failover and no recovery.
- **R=3 is the production floor.** Two of three is a majority, so the stream keeps serving reads
  and writes through one server failure with no data loss and no manual recovery.
- **R=5 tolerates two simultaneous failures and is the maximum a stream supports**
  (`num_replicas` maximum is `5`; default `1`). Most production streams run R=3; R=5 is for state
  that cannot be re-derived.
- **Use odd counts.** R=2 still has a single point of failure — lose either copy and one server out
  of two cannot form a majority, so writes block. R=4 tolerates only one loss, the same as R=3,
  while paying for a fourth copy.
- Every write goes through the **stream leader**, which assigns the sequence, appends to its log,
  replicates to the followers, and returns the `PubAck` **only after a quorum holds the entry** —
  for R=3, itself plus one follower. The third peer is not on the critical path
  (source: [[s-docs-replication-and-r3]]).
- If the leader's server dies the remaining replicas **elect a new leader automatically**. Writes
  pause for the election window and then resume; no acked message is lost.
- **If no majority remains, the group cannot elect a leader and writes are blocked** until enough
  replicas come back. The stream stops rather than accept writes it cannot safely replicate.

## What a `PubAck` does and does not promise

- **It promises the write survived the loss of one server** before the publisher heard back.
- **It does not promise all copies are identical right now.** The third peer may still be catching
  up. Before deliberately taking a server down, verify every replica shows `current` in
  `nats stream info`.
- **It does not promise the write is on disk.** For file storage, applying a committed entry writes
  it out, but JetStream **does not `fsync` every write immediately** — it batches disk syncs on
  **`sync_interval`, which defaults to `2m`** (source: [[s-docs-replication-and-r3]]; the server
  config reference at `reference/config/jetstream/sync_interval.md` records the same `2m` default
  and marks the key restart-only). Until the next sync an applied write can sit in the OS write
  cache.
- **A publish still in flight when the leader crashes is lost** and never gets a `PubAck` at all.
  The durability promise covers acked messages only; a client that does not receive a `PubAck` must
  treat the publish as failed and resend (source: [[s-docs-surviving-node-loss]]).

### Closing the disk-sync window

`sync_interval: always` makes every write sync to disk before the leader returns its `PubAck`.
Combined with peers spread across availability zones it is the strongest durability available, at
the cost of the slowest writes — and it costs performance **cluster-wide**, including for streams
that do not need it.

**`jetstream.sync_interval` is restart-only** ([[config-keys]]) — which is the practical reason the
documented pattern is a *separate cluster* rather than a per-stream setting.

You do not have to pick one setting for the whole deployment: run most clusters on the default and
add a separate cluster tagged for `sync_interval: always`, then place only the streams that need it
there with [[stream-placement|placement tags]] (source: [[s-docs-replication-and-r3]]).

## What replicas cost

| | effect |
|---|---|
| **survive node loss** | more copies tolerate more failures — this is what you are buying |
| **spread reads** | a consumer's own leader can sit on **any** of the stream's replicas, so delivery spreads across them; a Direct Get ([[direct-get]]) is answered by any replica directly |
| **cost load** | every replica stores the full log and every write is copied to a majority before its `PubAck`. **R=3 is roughly three times the storage and write traffic of R=1** |
| **do not scale writes** | every write still goes through the one leader, so a higher count **lowers** peak write throughput |

**Consumer replicas** behave the same way: they survive node loss (the group elects a new consumer
leader, keeping the read position and pending acks) but do **not** scale delivery — one consumer
leader does all the work and the followers only stand by, adding replication load without
throughput.

When you need more throughput the tool is not a replica: add workers to a consumer
([[worker-pool]]), or split subjects across streams.

## Replicas cost account quota, not just disk

A node's disk is not the only ceiling. **On an un-tiered account an R3 stream counts as
`replicas × bytes` against the account's `MaxStore`** — a 10 GiB stream at R3 spends 30 GiB of the
account's storage limit, because the limit measures total bytes stored across all replicas. **On a
tiered account replication is baked into the tier**: the bytes reported are usable bytes, so a
10 GiB tier holds a 10 GiB R3 stream (source: [[s-docs-sizing-and-resources]]).

Miss the multiplier on an un-tiered account and **the third replica fails to place** when the
account hits its ceiling — the node has disk, the account does not. Read the live ceilings with
`nats account info` before raising a replica count; in operator mode they come from the account
JWT, not from server config. [[jetstream-sizing]] works this through with numbers.

## Consumer replica rules

By default a durable consumer takes its stream's replica count. Beyond that
(source: [[s-docs-surviving-node-loss]]):

- On a **`limits`** stream a consumer may be given **fewer** replicas than its stream when its
  state is cheap to rebuild — but **never more**.
- On **`interest`** and **`workqueue`** streams the consumer's replica count **must match** the
  stream's.

## Storage durability is a separate axis

`num_replicas` sets how many copies exist; `storage` sets whether a copy survives a restart.

- `file` (the default) writes to disk and survives a reboot. `memory` keeps messages in RAM only.
- **Storage is a property of the whole stream, not of individual replicas** — an R=3 stream is all
  file or all memory; you cannot mix a disk copy with two RAM copies.
- R=3 file storage is the durable, fault-tolerant default. **R=3 memory storage survives a single
  server crash through its replicas but loses everything if the whole group restarts at once.**

## How to change it

```
nats stream add ORDERS --subjects "orders.>" --replicas=3 --defaults
nats stream edit ORDERS --replicas=3
nats stream info ORDERS
nats stream info ORDERS --json | grep '"num_replicas"'
```

`--replicas=3` **requires a real cluster of at least three servers**; a single-node server rejects
it, which is expected rather than a misconfiguration (source: [[s-docs-surviving-node-loss]]). If
the servers exist but the edit still fails with `no suitable peers for placement`, the cause is a
placement constraint — see [[stream-placement]].

## What you can observe

```
Cluster Information:
                 Name: east
        Cluster Group: S-R3F-xK2p9aLm
               Leader: n1-east
              Replica: n2-east, current, seen 0.00s ago
              Replica: n3-east, current, seen 0.00s ago
```

`current` means the follower has applied every committed entry. A follower catching up reads
`outdated, seen 0.12s ago, 4,512 operations behind` instead — do not treat it as a current copy,
and a **persistent** lag points at a slow disk or a saturated route between peers
(source: [[s-docs-replication-and-r3]]).

Reads from the **leader** are read-after-write; reads from a follower can be correct but behind.

## To verify

- The docs do not state a **replica count for the meta group** or how it relates to a stream's
  `num_replicas`; see [[meta-layer]] once a source covers it.
- No source ingested so far quantifies the throughput cost of R=3 versus R=1 beyond "roughly three
  times the storage and write traffic", and none gives the **per-message storage overhead** on top
  of the payload bytes — see *What is still unknown* on [[jetstream-sizing]].

## Reads can be served from outside the cluster

Replicas spread reads within a cluster. A **mirror** extends that beyond it: with `mirror_direct` set,
the mirror's peers join the *upstream's* [[direct-get]] responder queue group, so a read addressed to
the upstream stream can be answered by a server in another cluster or region. Because mirrors "need
not be in the same cluster as the upstream", this places read responders near distant clients and
keeps reads available "when the upstream is offline" (source: [[s-adr-31-direct-get]]).

Two limits on that, both easy to miss:

- a mirror **joins the read pool only after it has caught up** to within a small lag window, so a
  freshly created mirror contributes nothing yet;
- `mirror_direct` is **captured at create time and never refreshed**, so toggling the upstream's
  `allow_direct` silently desynchronises every mirror until each is updated in turn.

And the distinction that matters when a whole site fails: **R=3 protects against losing one node, not
one cluster.** "The R3 replication that protects you from losing *one node* does nothing when you lose
the *whole cluster*" — that is what a mirror at a second site is for (source:
[[s-docs-mirrors-as-dr]]). See [[mirrors-and-sources]].


## Related

[[stream]] · [[consumer]] · [[raft-in-nats]] · [[stream-placement]] · [[retention-policies]] ·
[[jetstream-sizing]] · [[stream-leader-keeps-moving]] · [[defaults-and-limits]] · [[config-keys]]

## Sources

[[s-docs-surviving-node-loss]] · [[s-docs-replication-and-r3]] · [[s-docs-stream-config]] ·
[[s-docs-raft-and-leaders]] · [[s-docs-sizing-and-resources]] · [[s-adr-31-direct-get]] · [[s-docs-mirrors-as-dr]]
