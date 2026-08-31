---
title: "docs.nats.io — Replication and R=3"
type: summary
area: [topology, jetstream]
source-url: https://docs.nats.io/learn/clustering/replication-and-r3.md
source-path: raw/nats-docs/learn/clustering/replication-and-r3.md
author: NATS documentation (Synadia Communications, Inc.)
article: Replication and R=3
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [raft, quorum, sync_interval, puback, consistency]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Replication and R=3

One write followed from publisher to committed entry across an R=3 group, and the durability gap
between "committed" and "on disk".

## Key claims

- `R=3` keeps three copies, each on a different server; the three servers form **one RAFT group**.
  A stream supports **at most `R=5`**.
- The write path is **append → append entry → follower ack → commit → apply**:
  1. The leader **appends** the write to its own log (local, not yet durable across the group).
  2. It sends an **append entry** to each follower, which writes it to its own log and acks.
  3. The write is **committed** once a **quorum** — a majority of peers — holds the entry. For
     R=3 that is two of three, and the leader is one of them, so **one follower's ack is enough**.
     The third peer is not on the critical path.
  4. The leader tracks a **commit index**, carried on the next append entry or heartbeat, and
     followers **apply** committed entries to their own stream store **in the same order**.
- **`PubAck` is returned only after commit.** So a `PubAck` means the message already survived the
  loss of a single server before the publisher heard back.
- **Consistency**: reads from the leader are **read-after-write**. Reads from a follower **can
  lag** — a follower applies committed entries slightly after the leader, so a direct read from a
  follower may not yet show the newest message. The data is correct but behind. For
  read-after-write, read from the leader.
- **`PubAck` proves quorum, not full replication.** The third peer may still be catching up. Before
  deliberately taking a server down, verify every replica shows `current` in `nats stream info`.
- **Quorum commit protects against losing a server, not against losing a server's disk.** For file
  storage, applying a committed entry writes it out, but JetStream **does not `fsync` every write
  immediately** — it batches disk syncs on a timer, **`sync_interval`, which defaults to
  `2m`**. Until the next sync an applied write can sit in the OS write cache.
- Two ways that window loses an acked write:
  - multiple peers suffer an OS failure within the same `sync_interval` window before any synced
    it; or
  - a peer that lost unsynced data in an OS crash rejoins and, together with a peer that never
    held the write, forms a new quorum that never saw it.
- **`sync_interval: always` closes the window entirely**: every write syncs to disk before the
  leader returns its `PubAck`. Combined with peers spread across availability zones it is the
  strongest durability available, at the cost of the slowest writes — and it costs performance
  cluster-wide, including for streams that do not need it.
- The full divergence scenario the docs spell out requires, in order: one of three peers already
  offline and never getting the write; a second peer's OS crashing and losing the unsynced write;
  the leader (the third peer, which did have it) going down or being isolated; the offline peer
  reconnecting without reaching the leader; the crashed peer coming back and reaching the
  reconnected peer but not the leader. Two peers are then up, neither holding the write, and
  together they form a new quorum and silently drop what the old leader had acked.
- **Mitigation after an OS crash**: a NATS server rejoins its cluster automatically on restart, so
  the safeguard is *when* you restart it — wait until `nats stream info` shows the remaining peers
  fully caught up. Or remove the crashed peer and let it rejoin wiped and resync over the network
  (safer, but expensive with a lot of data).
- You can scope the cost: run most clusters on the default `sync_interval` and add a separate
  cluster tagged for `sync_interval: always`, then place only the streams that need it there with
  [[stream-placement|placement tags]].

## What you can observe

```
nats pub --jetstream orders.created '{"order_id":"ord_8w2k"}'   # waits for a PubAck; plain `nats pub` does not
nats stream info ORDERS
```

```
Cluster Information:
                 Name: east
        Cluster Group: S-R3F-xK2p9aLm
               Leader: n1-east
              Replica: n2-east, current, seen 0.00s ago
              Replica: n3-east, current, seen 0.00s ago
```

A follower that is catching up reads:

```
              Replica: n3-east, outdated, seen 0.12s ago, 4,512 operations behind
```

`current` means the follower has applied every committed entry. A persistent lag points at a slow
disk or a saturated route between peers.

## Relevance to the wiki

Together with [[s-docs-raft-and-leaders]], the source for [[raft-in-nats]], and the source for the
durability section of [[replicas]]. The `sync_interval` default of `2m` and what it means for a
`PubAck` is the single most consequential fact on this page for an operator.

## Questions it answers

Q39 in part (what can corrupt a JetStream cluster — the divergence mechanism and the
restart-order mitigation).

## Pages touched

[[raft-in-nats]] · [[replicas]] · [[stream-placement]] · [[stream]]
