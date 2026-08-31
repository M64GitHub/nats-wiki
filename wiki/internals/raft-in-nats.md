---
title: RAFT in nats-server
type: internals
area: [topology, jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [raft, quorum, election, term, meta-group, commit, apply, stepdown]
aliases: [raft, RAFT, consensus, leader election, meta group, quorum]
sources: [s-nats-server-jetstream-log-warnings, s-docs-rolling-upgrades, s-docs-raft-and-leaders, s-docs-replication-and-r3, s-docs-surviving-node-loss, s-docs-upgrade-to-2.14, s-relnotes-2.14.0, s-docs-upgrade-to-2.12, s-adr-61-meta-quorum-rescue]
created: 2026-08-31
updated: 2026-08-31
---

# RAFT in nats-server

JetStream reaches agreement with **RAFT**. This page covers only the parts that surface in an
operator's day: how the groups are layered, how long an election takes, what "committed" means, and
where each of those shows up in CLI output and monitoring.

## What the server does

### The groups are layered, and independent

A cluster runs **many RAFT groups at once** (source: [[s-docs-raft-and-leaders]]):

- The **meta group** — one cluster-wide group whose peers are the servers themselves. Its log holds
  the cluster's *assignments*, not your data: which streams exist, how many replicas each has,
  which servers hold them. Its leader, the **meta leader**, decides where new streams and consumers
  are placed. Every server in the cluster is a peer.
- **Per-asset groups** — every replicated stream gets its own group, and so does every replicated
  consumer. A stream's leader, the **stream leader**, accepts writes to that stream and replicates
  them.

**They are independent.** The meta leader and a stream leader may be the same server or different
servers, and a change to one does not move the other. A three-server cluster holding one replicated
stream is already running at least two groups.

### Elections

- The leader sends a **heartbeat** to its followers **by default about once a second**.
- Each follower runs an **election timer**. It fires **between four and nine seconds after the last
  heartbeat**, deliberately staggered so two followers do not become candidates at the same instant.
- A **term** is a number counting elections that only ever goes up. Every entry and every vote is
  stamped with one, so a leader from an older term is obsolete the moment a newer term exists.
- A follower whose timer fires becomes a **candidate**: it increments the term above any it has
  seen, votes for itself, and asks every other peer for a vote. A peer grants its vote if it has
  **not already voted in this term** *and* the candidate's log is **at least as up to date** as its
  own. One vote per peer per term is what stops two leaders emerging.
- The candidate becomes leader on collecting a **quorum**: a majority of the group's peers,
  **`(N+1)/2`**. For a three-peer group that is two — its own vote plus one.

**The quorum rule is why a majority must survive.** A three-peer group keeps a leader while two
peers are up; lose two and the survivor cannot reach a majority, so the group goes **leaderless**
until a peer returns. This is the consensus reason behind the odd-count advice in [[replicas]]: an
even count buys no extra majority.

### The write path: append → commit → apply

For one write into an R=3 stream (source: [[s-docs-replication-and-r3]]):

1. The leader **appends** the entry to its own log. Local only; not yet durable across the group.
2. It sends an **append entry** to each follower, which writes it to its own log and **acks**.
3. The entry is **committed** the instant a **quorum holds it** — for R=3, the leader plus one
   follower. The third peer is not on the critical path. **`PubAck` is returned at this point.**
4. The leader tracks a **commit index**, carried on the next append entry or heartbeat. Followers
   **apply** committed entries into their own stream store, **in the same order the leader did**.

A follower can lag the leader by a few entries, but it never reorders them and never skips one — so
all copies converge on an identical log.

### Overrun protection (2.14)

Before 2.14, entries could be written to the Raft write-ahead log **faster than they could be
committed and applied**, growing memory and disk without bound in an overloaded cluster. Since 2.14
the server recognises the condition and bounds the memory and disk it will use, and — the
observable part — **a leader that detects it is falling behind steps down so a healthier peer can
take over** (source: [[s-docs-upgrade-to-2.14]], [[s-relnotes-2.14.0]]).

**If a majority of peers are equally overloaded, the system stays in that degraded state.** The
docs are explicit that this is "a safety net for transient overload, not a substitute for adequate
capacity". A cluster whose leaders keep stepping down under load is telling you it is undersized —
see [[jetstream-sizing]] and [[stream-leader-keeps-moving]].

### A node refuses to start on a bad snapshot (2.14)

Since 2.14, **a Raft node will not start if its snapshot is missing or corrupt, or if the snapshot
does not align with the remaining log on disk** — deliberately, "avoiding potential data loss"
(source: [[s-relnotes-2.14.0]]). A peer that fails to rejoin after an unclean shutdown may be doing
exactly this. It is a safety behaviour, not a crash.

### Commit is not fsync

Applying a committed entry writes it out, but JetStream **does not `fsync` every write
immediately**: it batches disk syncs on `sync_interval`, default `2m`. The full consequence — the
narrow multi-fault sequence in which a group can lose an acked write, and the `sync_interval:
always` mitigation — is on [[replicas]].

Since **2.12**, replicated streams also **flush to the underlying store asynchronously**, which the
upgrade guide calls "a significant improvement in performance" with **no consistency downside**:
writes are still persisted synchronously in the Raft log before being committed
(source: [[s-docs-upgrade-to-2.12]]). Since **2.14**, stream state snapshots for replicated streams
are taken and written **without pausing stream processing**, which mostly shows up as better tail
latency on streams with many interior deletes (source: [[s-docs-upgrade-to-2.14]]).

## Where it lives

RAFT internals surface in the docs at `learn/clustering/raft-and-leaders.md` and
`learn/clustering/replication-and-r3.md`; the monitoring surface is the `/raftz` endpoint. Peers
vote over the `$NRG.*` subjects. Log compaction, snapshot timing and the append-entry batching and
heartbeat parameters are documented with `/raftz` (source: [[s-docs-raft-and-leaders]]) — this wiki
has not ingested that page yet; see [[monitoring-endpoints]].

## What you can observe

```
nats server report jetstream          # RAFT Meta Group Information table — names the meta leader
nats stream info ORDERS               # Cluster Information block — names the stream leader
nats stream cluster step-down ORDERS  # move one stream's leader
nats server cluster step-down         # move the meta leader
```

```
Cluster Information:
           Name: east
         Leader: n1-east
        Replica: n2-east, current, seen 0.05s ago
        Replica: n3-east, current, seen 0.07s ago
```

- `Leader` is the **stream** leader; `Replica` lines are its followers.
- `current` means the follower has applied every committed entry; `outdated, seen 0.12s ago,
  4,512 operations behind` means it has not. A persistent lag points at a slow disk or a saturated
  route between peers.
- During an election the `Leader:` line is **briefly empty**.

`/raftz` gives a live view of a group's RAFT state: the current term, who the leader is, and each
peer's status. It takes `account` and `group` query parameters — see [[monitoring-endpoints]].

**When an entry cannot be applied, the server tries to rebuild the group itself.** The apply loop
calls `resetClusteredState` (`jetstream_cluster.go:3912`), which steps the node down and either stops
or deletes the Raft state, logging

```
Resetting stream cluster state for '<account> > <stream>'
```

Messages are **preserved** unless the error is `errFirstSequenceMismatch`, which is the one case that
deletes them (`jetstream_cluster.go:3974`). It declines in four cases, each with its own warning —
the stream is closed, the group was already replaced, or **server / account resources are exceeded**.
The last two mean a capacity problem is blocking the repair; fix that and the reset proceeds
(source: [[s-nats-server-jetstream-log-warnings]]). A `Critical write error` with **no** subsequent
`Resetting stream cluster state` is a group that did not heal — see
[[malformed-or-corrupt-message]].

Two advisories make leadership changes observable without polling ([[advisories]]):
`$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED` and `$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST`, with
`CONSUMER.` equivalents. **Quorum-lost is the one to alert on**; leader-elected is normal and
belongs in a log.

## Why an operator cares

Three observable behaviours come straight out of the mechanics above.

**Which election you are waiting out decides the blast radius.** A *stream's* election blocks writes to
that stream; a **meta** election blocks stream and consumer *operations* — create, update, leadership
moves — cluster-wide, for about **5 to 10 seconds** if the leader was killed outright, or **roughly a
second** if it drained first and handed leadership off. That difference is the whole reason
[[upgrade-a-cluster]] takes the meta-leader last and drains it (source: [[s-docs-rolling-upgrades]]).

**An election takes seconds, not milliseconds.** Kill a leader and expect a window of roughly four
to nine seconds — the election timer — plus the election itself, in which `nats stream info` shows
no leader and writes are refused. That is RAFT working as designed, not a fault. **A client should
retry rather than treat a brief "no leader" as fatal**, and an alert that fires on a single
missed write will fire on every planned restart.

**"The leader is down" is ambiguous.** Losing the meta leader does not lose a stream leader, and
vice versa — separate groups, separate elections. Check the right one: `nats server report
jetstream` for the meta leader, `nats stream info <stream>` for the stream leader. Mistaking one for
the other is the common panic (source: [[s-docs-raft-and-leaders]]).

**A stepdown moves leadership, but the election still picks the successor.**
`nats stream cluster step-down --preferred <server>` (**nats-server 2.11+**) is a *request*, not a
lock: the quorum election can still land elsewhere. Run the stepdown to move leadership *off* the
current server, then read `nats stream info` to learn who actually won. Placement cannot name a
leader at all — see [[stream-placement]].

## The configured peer set, not the live one

The single most consequential property of the meta group for an operator: **quorum is computed from
the configured peer set, not from the peers that are currently up** (source:
[[s-adr-61-meta-quorum-rescue]]). A server that is switched off and never `peer-remove`d still counts
towards the majority it is no longer able to provide.

The failure this produces is ordinary, not exotic: grow a 3-node cluster to 5, switch the two extras
off without removing them, and the meta group still needs **3 of 5**. Lose one of the three
survivors and there is no meta leader — and because a peer-remove is itself a meta-group write,
there is no way to shrink the peer set back either. The meta layer stalls until enough of the
configured peers return.

On **2.14 the only supported exit** is to bring every configured peer back under its original server
name, let an election happen, then `nats server cluster peer-remove` the dead ones. **2.15** (preview
only as of 2026-08-31) adds `$JS.API.META.RESCUE`, which temporarily lowers the effective quorum on
each survivor for 5 minutes — see [[disaster-recovery]]. Neither is a substitute for removing a peer
when you retire it.


## Version notes

- `--preferred` on `nats stream cluster step-down` requires **nats-server 2.11 or newer**
  (source: [[s-docs-raft-and-leaders]], [[s-docs-placement]]). See [[nats-server-2.11]].
- **2.12** — async stream flushing for replicated streams; better protection against leader
  elections based on empty state ([[nats-server-2.12]]).
- **2.14** — Raft overrun protection with leader stepdown; a node refuses to start on a corrupt or
  misaligned snapshot; async stream state snapshots; consistent Raft group rename when moving to or
  off R1 ([[nats-server-2.14]]).

## To verify

- The exact heartbeat interval ("by default about once a second") and the 4–9 second election-timer
  range are as the docs state them in prose; no source ingested so far names the config keys that
  set them, if any are exposed.
- `/raftz`'s **field set** is still not ingested — [[monitoring-endpoints]] now records the
  endpoint and its `account` and `group` query parameters, but not what it returns. Log compaction
  and snapshot timing are documented with it and likewise unread.

## Related

[[replicas]] · [[stream-placement]] · [[stream]] · [[consumer]] · [[monitoring-endpoints]] ·
[[stream-leader-keeps-moving]] · [[meta-layer]] · [[upgrade-a-cluster]] · [[rebalance-streams]] ·
[[build-a-3-node-cluster]] ·
[[malformed-or-corrupt-message]] · [[stream-has-high-message-lag]]

## Sources

[[s-docs-raft-and-leaders]] · [[s-docs-replication-and-r3]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-placement]] · [[s-docs-upgrade-to-2.14]] · [[s-relnotes-2.14.0]] ·
[[s-docs-upgrade-to-2.12]] · [[s-nats-server-jetstream-log-warnings]] · [[s-adr-61-meta-quorum-rescue]]
