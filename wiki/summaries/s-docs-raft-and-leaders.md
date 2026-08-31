---
title: "docs.nats.io — Raft and leaders"
type: summary
area: [topology, jetstream]
source-url: https://docs.nats.io/learn/clustering/raft-and-leaders.md
source-path: raw/nats-docs/learn/clustering/raft-and-leaders.md
author: NATS documentation (Synadia Communications, Inc.)
article: Raft and leaders
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [raft, election, meta-group, stepdown, quorum]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Raft and leaders

RAFT groups and leader elections in `nats-server`: the layering (meta group vs per-asset groups),
the election timings, and the stepdown commands.

## Key claims

- A **RAFT group** is a fixed set of servers (its **peers**) maintaining one shared log by
  consensus. One peer is the **leader** — the only peer that accepts new entries — and the rest
  are **followers**.
- A cluster runs **many RAFT groups at once, layered**:
  - The **meta group**: one cluster-wide group whose peers are the servers themselves. Its log
    holds the cluster's *assignments*, not your data — which streams exist, how many replicas
    each has, which servers hold them. Its leader, the **meta leader**, decides where new streams
    and consumers are placed. Every server in the cluster is a peer of the meta group.
  - **Per-asset groups**: every replicated stream gets its own group, and so does every
    replicated consumer. A stream's leader is the **stream leader**.
  - The two are **independent**: the meta leader and a stream leader may be the same server or
    different servers, and a change to one does not move the other.
- **Heartbeat**: the leader sends one to its followers by default about **once a second**.
- **Election timer**: a follower's timer fires **between four and nine seconds after the last
  heartbeat**, deliberately staggered so two followers do not become candidates at the same
  instant.
- **Term**: a number counting elections that only ever goes up. Every entry and every vote is
  stamped with a term, so a leader from an older term is obsolete the moment a newer term exists.
- **Election sequence**: a follower whose timer fires becomes a **candidate**, increments the term
  above any it has seen, votes for itself and requests votes. A peer grants its vote if it has
  **not already voted in this term** and the candidate's log is **at least as up to date** as its
  own. One vote per peer per term is what stops two leaders emerging.
- A candidate becomes leader on collecting a **quorum** of votes: a majority of the group's peers,
  **`(N+1)/2`**. For a three-peer group that is two.
- **The quorum rule is why a majority must survive.** A three-peer group keeps a leader while two
  peers are up; lose two and the survivor cannot reach a majority, so the group goes leaderless
  until a peer returns. This is the consensus reason behind the odd-server-count advice — an even
  count buys no extra majority.
- **An election takes seconds, not milliseconds.** Expect a short window after a leader dies where
  `nats stream info` shows an empty `Leader:` line and writes are refused. That is RAFT working as
  designed; clients should retry rather than treat a brief "no leader" as fatal.
- **A stepdown moves leadership but the election still picks the successor.**
  `nats stream cluster step-down --preferred <server>` (**nats-server 2.11+**) is a *request*, not
  a guarantee — the quorum election can still land elsewhere. Read `nats stream info` afterwards
  to learn who actually won.

## What you can observe

```
nats server report jetstream          # RAFT Meta Group Information table names the meta leader
nats stream info ORDERS               # Cluster Information block names the stream leader
nats stream info ORDERS --server nats://127.0.0.1:4223
nats stream cluster step-down ORDERS
nats server cluster step-down         # moves the meta leader
```

```
Cluster Information:
           Name: east
         Leader: n1-east
        Replica: n2-east, current, seen 0.05s ago
        Replica: n3-east, current, seen 0.07s ago
```

The `/raftz` monitoring endpoint gives a live view of a group's RAFT state (current term, who the
leader is, each peer's status), plus log compaction, snapshot timing and the `$NRG.*` subjects
peers vote over.

## Relevance to the wiki

The primary source for [[raft-in-nats]]. The 4–9 second election window and the meta-leader /
stream-leader distinction are the two facts that explain most "the cluster went leaderless" and
"the leader is down, is my stream gone?" reports.

## Questions it answers

Q36 in part (why a cluster reports no quorum and stalls — the mechanism; the symptom-first triage
is still open).

## Pages touched

[[raft-in-nats]] · [[replicas]] · [[stream-placement]]
