---
title: RAFT in nats-server
type: internals
area: [topology, jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [raft, quorum, election, term, meta-group, commit, apply, stepdown]
aliases: [raft, RAFT, consensus, leader election, meta group, quorum]
sources: [s-nats-server-jetstream-log-warnings, s-docs-rolling-upgrades, s-docs-raft-and-leaders, s-docs-replication-and-r3, s-docs-surviving-node-loss, s-docs-upgrade-to-2.14, s-relnotes-2.14.0, s-docs-upgrade-to-2.12, s-adr-61-meta-quorum-rescue, s-docs-placement, s-docs-monitoring-advisories-and-events, s-docs-monitoring-endpoints, s-docs-disaster-recovery, s-docs-forming-a-cluster, s-docs-jetstream-in-a-cluster, s-docs-scaling-and-peers, s-docs-your-first-cluster, s-gh-6490-high-message-lag, s-gh-7438-multi-region-availability, s-gh-7463-jetstream-corruption, s-nats-server-lame-duck, s-synadia-jetstream-memory-patterns, s-nats-server-jetstream-resources, s-nats-server-jetstream-cluster, s-gh-7533-quorum-loss-mqtt, s-nats-server-raftz, s-docs-monitor-raftz, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.15-preview, s-nats-surveyor-metrics-observed]
created: 2026-08-31
updated: 2026-09-03
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

**Three elections, not one.** "Each consumer gets its own Raft group and leader — chosen
independently of the stream's", so a stream leader, a consumer leader and the meta leader are three
separate outcomes on possibly three different servers. `nats stream info` names the stream's group in
its `Cluster Group` field — "its own Raft group, separate from the meta group. Each stream gets one".
And the separation people get wrong, stated plainly: "The meta leader decides where a stream lives,
but it doesn't handle its messages" — a cluster on its own does not make JetStream highly available;
`num_replicas` does (source: [[s-docs-jetstream-in-a-cluster]]; [[replicas]]).

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

**A draining node takes itself out of the running.** Lame duck calls `transferRaftLeaders()`, which
issues `StepDown()` on **every** Raft node the server holds, and its groups then become
**observers** — so it cannot win an election on the way out. All of that happens *before* the
`lame_duck_duration` timer starts, which governs client disconnects and nothing else (source:
[[s-nats-server-lame-duck]], nats-server 2.14.6; [[upgrade-a-cluster]]).

**A peer added to a live group votes before it holds anything.** Raising a stream's replica count
makes the meta leader assign a new peer, and "adding the peer changes the quorum right away: an
`R=4` group commits once **three** peers hold a write, not two". The empty peer cannot win an
election — "it stays an observer until the leader's first entries reach it" — but it does count
against the majority, which is why membership changes are made **one at a time** and gated on
`current` (source: [[s-docs-scaling-and-peers]]).

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
vote over the `$NRG.*` subjects. The docs say log compaction, snapshot timing and the append-entry
batching and heartbeat parameters are "documented with `/raftz`" (source: [[s-docs-raft-and-leaders]]);
**they are not** — that reference page lists two request options and no response fields (source:
[[s-docs-monitor-raftz]]), and the parameters are constants in the server with no key to set them, all
quoted in *What the meta layer adds* below and in the `/raftz` section that follows it.

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

**The meta group has its own view**: `/jsz` always carries `meta_cluster.leader` and
`meta_cluster.cluster_size` (there is no `meta` query parameter; `?meta=1` is accepted and ignored — [[meta-layer]]), which is how you confirm a meta leader exists at all before blaming
anything downstream on the group layer (source: [[s-docs-monitoring-endpoints]]). A JetStream
operation that hangs while `/jsz` shows no `meta_cluster.leader` is waiting on the meta layer, not on the
stream's own group — the server says so directly in the log,
`JetStream has not established contact with a meta leader`.

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

**The RAFT log lines worth recognising**, from a real 2.9.8 incident (source:
[[s-gh-7463-jetstream-corruption]]). They come as a family, and reading the family rather than one
line is the diagnosis:

```
[WRN] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Wrong index, ae is &{leader:VNsg0pXW term:7 commit:3258048 ...}, index stored was 3258025, n.pindex is 3258048
[ERR] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Critical write error: malformed or corrupt message
[WRN] JetStream cluster stream '$G > IDX_TRADE_P005' has NO quorum, stalled
[WRN] RAFT [... ] Expected first catchup entry to be a snapshot and peerstate, will retry
[WRN] RAFT [... ] Error storing entry to WAL: raft: could not store entry to WAL
```

The bracketed pair is `<server id> - <group name>`, so the group name (`C-R3F-…`) is what ties a
line to a stream. Two readings that save time:

- **`JetStream out of resources, will be DISABLED` in this company is not a capacity message.** It is
  the out-of-space handler being called from the Raft write-error path — the incident above had 6–7%
  of 200 GB used (source: [[s-nats-server-jetstream-resources]]). [[malformed-or-corrupt-message]]
  separates it from [[jetstream-out-of-disk]].
- **`Restored N messages for stream '<account> > <stream>'` at INFO on startup is the positive
  signal**, and its *absence* for a stream that used to print it is the cheapest corruption check
  there is.

**Watch the counters, not the route count.** `nats server list`'s `Routes` column counts
*connections*, not peers: each link to a peer is a small pool (`cluster.pool_size`, default **3**)
plus a dedicated system-account route, so a three-server cluster shows **8** and reading that as a
peer count produces false alarms (sources: [[s-docs-forming-a-cluster]],
[[s-docs-your-first-cluster]]). The usable checks are `nats server report jetstream` for the meta
group and `nats server check stream --stream=ORDERS --peer-expect=3`, which exits non-zero when a
stream is under-replicated (source: [[s-docs-jetstream-in-a-cluster]]).

**A lag warning is about this layer, not about consumers.** `JetStream cluster stream … has high
message lag` fires when proposals accepted from publishers outrun what has been committed and
applied on the **stream leader**; the threshold is a constant, **10,000** at v2.14.6, and the line is
rate-limited so its frequency is not a severity measure (sources: [[s-gh-6490-high-message-lag]],
[[s-nats-server-jetstream-log-warnings]]; [[stream-has-high-message-lag]]).

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

**A super-cluster is one meta group over the WAN, and that is a design decision, not a detail.**
Quorum there is decided by the **total** server count across regions, so an unequal deployment lets a
dominant region hold the meta group hostage, and every metadata operation pays WAN latency. The
alternative shape — a hub with leafnodes — is a *separate* meta group per JetStream domain, which is
why domains are the tool for regional independence (source: [[s-gh-7438-multi-region-availability]];
[[multi-region-jetstream]], [[jetstream-domain]]).

**Leadership is where the memory goes.** Measured across a JetStream cluster, the nodes holding
stream, consumer and **meta** leadership sat far above their peers, because a meta leader coordinates
and holds state for the cluster. An asymmetric memory profile is therefore expected rather than
suspicious, and the mitigation is architectural: keep meta leadership off the nodes carrying
high-volume streams (source: [[s-synadia-jetstream-memory-patterns]]; [[jetstream-sizing]]).

**Disaster recovery runs through this layer.** Every `stream rm` and `stream edit` in a promotion
goes through the JetStream metadata group, so that group must have quorum before any of it works —
and the promoted stream "must live where that quorum survives", which is why a DR mirror is normally
placed in its own JetStream domain or its own cluster (source: [[s-docs-disaster-recovery]];
[[disaster-recovery]]).

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


## What the meta layer adds

Read from `jetstream_cluster.go` and `raft.go` at v2.14.6 and then run on a three-node cluster
(source: [[s-nats-server-jetstream-cluster]]); the full account is [[meta-layer]].

- **The meta group has no replica count.** Its peers are every JetStream-enabled server the cluster
  knows — including servers behind gateways, whose URLs count toward the expected size at bootstrap —
  and quorum is `size/2 + 1`. Nothing relates it to a stream's `num_replicas`.
- **The timing is constants, not configuration.** Heartbeat `1s`, election timer `4–9s`, lost-quorum
  interval and check `10s` each, peer-remove timeout `5m`. Measured: bootstrap elected a meta leader in
  0.28 s, a full-cluster restart in 5.3 s, a SIGKILLed leader was replaced in 3.5 s, a stepdown took
  0.5 s because it is a *transfer* to a peer heard from within 3 s rather than an election.
- **A leader that loses its followers keeps claiming leadership for ~10 s, up to ~20 s** — the
  lost-quorum check runs on a 10-second ticker. Until it steps down, `/healthz` says `ok`, `/jsz` names
  it, and a request it accepts cannot commit, so the client times out instead of hearing `10008`.
- **A proposal that timed out on the client is still in the old leader's log.** It is committed if that
  server wins the next election and discarded if another does — observed both ways for creates, and two
  publishes that returned `nats: timeout` were both stored. Check before retrying differently.


## `/raftz`, read and run — and the numbers the docs said it documents

`/raftz?acc=<account>&group=<group>` (the account filter is `acc`, and it defaults to the system
account, so a bare `/raftz` shows only `_meta_`) prints, per group, `state`, `term`, `leader`,
`leader_since`, `committed` / `applied`, `size` / `quorum_needed`, the four internal queue lengths,
the `wal` state, and — omitted when false — **`overrun`**, `overrun_count`, `catching_up`,
`observer`, `paused`, plus `peers` with `known`, `last_seen` and (on the leader) `last_replicated_index`.
A climbing `term` is the flap counter; `overrun: true` is the 2.14 stepdown about to happen; a growing
`ipq_apply_len` is a node that cannot keep up (source: [[s-nats-server-raftz]]; the full table is on
[[monitoring-endpoints]]).

The parameters the docs say live there are **constants at v2.14.6, with no config key**
(source: [[s-nats-server-jetstream-cluster]], [[s-nats-server-raftz]]):

| what | value |
|---|---|
| heartbeat | `1s` |
| election timer | `4s`–`9s` after the last heartbeat |
| lost-quorum interval, and the leader's check ticker | `10s` each |
| append-entry batch | up to **256 KB or 512 entries** per append |
| meta-group snapshot | 1-minute ticker, or > 8 MB applied and 30 s since the last; forced on membership changes and on becoming leader; `meta_compact` / `meta_compact_size` (2.12, reloadable) turn the check into a threshold, default 0 = every check |
| stream-group snapshot | 2-minute ticker (+ jitter), or 8 MB / 65,536 entries |
| consumer-group snapshot | 2-minute ticker, or 64 KB / 1,024 entries |
| peer-remove timeout (a removed peer may rejoin after) | `5m` |
| observer election timer | `48h` |

## Version notes

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch the Raft layer from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- `--preferred` on `nats stream cluster step-down` requires **nats-server 2.11 or newer**
  (source: [[s-docs-raft-and-leaders]], [[s-docs-placement]]). See [[nats-server-2.11]].
- **2.12** — async stream flushing for replicated streams; better protection against leader
  elections based on empty state ([[nats-server-2.12]]).
- **2.14** — Raft overrun protection with leader stepdown; a node refuses to start on a corrupt or
  misaligned snapshot; async stream state snapshots; consistent Raft group rename when moving to or
  off R1 ([[nats-server-2.14]]).

### The 2.10 line

The Raft layer was reworked across 2.10.23's "improvements to Raft append entry handling and log
consistency (#5661, #5689, #5714, #5957, #6027, #6073)", stepdown (#5666, #5344, #5717), elections
(#5671, #6056), terms (#5684, #5792, #5975, #5848, #6060), catch-ups (#5987, #6038, #6072) and
snapshots (#6053, #6055) (source: [[s-relnotes-2.10]]). Individually dated: `/raftz` — 2.10.17
(#5530); file-backed groups share the filestore's sync interval, including `sync: always` — 2.10.23
(#6041); entries not certainly applied during a shutdown are no longer reported applied — 2.10.23
(#6087, #6133); groups no longer snapshot too often — 2.10.25 (#6277), and no longer report current
while paused with pending commits (#6317); proposals dropped after a peer remove, causing a desync —
fixed in 2.10.26 (#6456); peer-set changes on a stream or consumer peer-remove go through the Raft
layer — 2.10.28 (#6720, #6727); a preferred node that fails to become leader is reported to the upper
layer, "fixing some issues where multiple assets can believe they are the leader after a scale-up" —
2.10.29 (#6851).


### The 2.11 line

- **2.11.0**: a new leader "only starts responding to read/write requests once it's initially
  up-to-date with its Raft log" (#6194, #6485, #6518); acks on clustered interest and WorkQueue
  streams are proposed through Raft (#6140) (source: [[s-relnotes-2.11]]).
- **2.11.5**: **monotonic time** for heartbeats and quorum, "resilient against wall-clock drifts or
  adjustments from NTP" (#6999); partitioned nodes no longer accept catch-ups from a lower term
  (#6951). **2.11.7**: recovery and snapshot handling before campaigning, "fixing a situation where a
  node could continue with an outdated stream" (#7040); no log compaction until a snapshot is written
  (#7043); truncation back to a snapshot instead of a log reset when applies were behind (#7095).
- **2.11.8**: step-down on a higher term during catch-up; late entries from cancelled catch-ups
  ignored (#7151). **2.11.9**: delayed entries from an old leader rejected (#7209, #7239); the leader
  bounds its cached in-memory entries (#7233). **2.11.10**: non-leaders cannot send append entries
  (#7297); a stream snapshot timeout no longer resets clustered state (#7293).
- **2.11.11**: leadership reported only after a no-op entry on recovery (#7460); peer activity
  reported consistently after leader changes (#7402); no truncation from unexpected catch-up entries
  once a catch-up is complete (#7424).
- **2.11.12, the membership batch**: no concurrent membership changes (#7565, #7609); removed peers
  not counted towards quorum (#7589); the implicit leader ack counted only while a member (#7600);
  peer state written immediately on peer-remove "to ensure the removed peers cannot unexpectedly
  reappear after a restart" (#7602); the last remaining peer cannot be removed (#7610); add-peer
  cannot produce disjoint majorities (#7632); no re-admission on a heartbeat between removal and
  leadership transfer (#7649); single-node elections reach the leader state (#7642); no repeat vote
  for a term after a step-down (#7698).


### The 2.12 line

- **2.12.0**: "empty log protection" — empty votes for "nodes that have lost their stable storage and
  attempt to rejoin the cluster regardless" (#7038); no success replies to catch-up messages when
  not leader (#6944); no append entries in a known non-leader state (#7297); **async flush** on
  replicated streams, writes still persisted in the Raft log first (#7018, #7163) (source:
  [[s-relnotes-2.12]]).
- **2.12.5**: forwarded proposals accepted "only if caught up as the new leader, limiting potentially
  unbounded log growth" (#7809); concurrent membership changes refused when forwarded (#7809); the
  cluster size no longer restored to 1 at startup, "which could result in an isolated node
  incorrectly winning a single-node election" (#7850); the last snapshot-applied sequence no longer
  reverted when truncating after a catch-up snapshot (#7849); the election timeout set when leaving
  observer mode (#7793).
- **2.12.6**: the vote reset on becoming candidate (#7956); **entries from previous terms are no
  longer committed** (#7955). **2.12.8**: commit-index reset on term mismatch (#8023); a legacy
  zero-index snapshot no longer panics (#8039). **2.12.9**: temporary snapshots ignored after a
  crash (#8101); append-entry caches invalidated on truncation and snapshot install (#8149); no
  proposals to remove unknown peers (#8154); in-flight checkpoints cancelled on reset (#8180, #8202).
- **2.12.12**: **nodes no longer vote or campaign after write errors** (#8290); checkpoints abort on a
  closed node (#8296); `ApplyCommit` handles the post-snapshot index (#8321); uncommitted membership
  changes reverted on truncation or snapshot (#8332); peer-state decoding bounded (#8310).
  **2.12.14**: elections ignore votes from removed peers (#8353); the transport layer decoupled
  (#8181, "does not change server behaviour").


## To verify

- ~~The exact heartbeat interval and the 4–9 second election-timer range~~ **Settled 2026-09-01** from
  `raft.go` at v2.14.6: `hbInterval` 1 s, election timer 4–9 s, lost-quorum interval and check 10 s
  each — package variables with **no config key**; see *What the meta layer adds* above (source:
  [[s-nats-server-jetstream-cluster]]).
- ~~`/raftz`'s field set is still not ingested~~ **Settled 2026-09-01**: read from `monitor.go` and
  run — the field table is on [[monitoring-endpoints]], the compaction and snapshot numbers are in the
  `/raftz` section above. The docs page that was supposed to hold them is empty (docs issue #47).

## The election as an observable: the leader-elected advisory

An election is not only a log line. JetStream publishes a **leader-elected advisory** whenever the
leader of a replicated stream or consumer changes, on
`$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.<stream>` and
`$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED.<stream>.<consumer>`, with `…QUORUM_LOST.…` alongside them
([[advisories]] has the full constant list).

**A flapping leader shows up here first**, and repeated advisories for one stream are the cheapest
signal that a cluster is unstable. But the docs are careful about what the advisory is worth: it
"reports a flap, not its cause… Don't try to diagnose the election from the advisory body alone"
(source: [[s-docs-monitoring-advisories-and-events]]). The advisory tells you *that* leadership moved;
this page is *why* it can.

Because advisories are published once and stored nowhere, catching a flap that happened overnight
means a stream was already capturing `$JS.EVENT.ADVISORY.>` — not that someone was watching.

What a flap looks like from the *application* side is on record too: an MQTT deployment on 2.12.1
saw `10071` session-persist failures, then `10008`, then 5-second publish timeouts, then a consumer
`NO quorum, stalled` — the meta group, a stream group and a consumer group losing quorum in that
order — and nobody answered the thread (source: [[s-gh-7533-quorum-loss-mqtt]]). The causes, ranked,
are on [[stream-leader-keeps-moving]].

### The 2.14 line

- **2.14.0**: **"Raft nodes will step down if overrun"** (#7853) — the body's whole statement of
  overrun protection; **a node will no longer start if its snapshot is missing, corrupt or misaligned
  with the log** (#7566, #7580, #7620); consistent group rename moving to or off R1 (#7802)
  (source: [[s-relnotes-2.14]]).
- **2.14.1**: temporary snapshots ignored on recovery after a crash (#8101); append-entry caches
  invalidated on WAL truncation and snapshot install (#8149); no proposals to remove unknown peers
  (#8154); in-flight checkpoints cancelled on reset (#8180, #8202). **2.14.2**: peers tracked after
  an inactivity stall during catch-up (#8226); quorum computed correctly when bootstrapping with
  gateway URLs that resolve to several IPs (#8238); peer-set drift after peer-removing an online
  node (#8258).
- **2.14.3**: **no voting or candidacy after write errors** (#8290); checkpoints abort on a closed
  node (#8296); `ApplyCommit` handles the post-snapshot index (#8321); uncommitted membership changes
  reverted on truncation or snapshot (#8332); peer-state decoding bounded (#8310). **2.14.4**:
  elections ignore votes from removed peers (#8353); **proposals carry the term from JetStream, so a
  stale proposal from a previous term cannot land after a fast election** (#8370); the append-entry
  iterator's end handled (#8372); the transport layer decoupled without behaviour change (#8181).
- **2.14.6**: a signalling issue that could stall catch-ups fixed; the pending append-entry cache
  bounded by size as well as count; **a stale snapshot from a previous Raft group no longer replayed
  when the group name was unchanged** (#8501).
- **2.15 preview**: `$JS.API.META.RESCUE` verified at the preview tag as a system-account broadcast
  "every online server evaluates and responds to … independently"; the evacuate subjects
  (source: [[s-relnotes-2.15-preview]]).


## The Raft numbers as series

`prometheus-nats-exporter` exports nothing of `/raftz`; `nats-surveyor` v0.9.11 fills the gap in two
ways (source: [[s-nats-surveyor-metrics-observed]]). From the meta block every `STATSZ` carries:
`nats_core_jetstream_cluster_raft_group_leader` (1 on the meta leader), `_size`, `_replicas` and, from
the leader only, one sample per peer of `_replica_peer_current`, `_replica_peer_offline` and
`_replica_peer_active` (nanoseconds since last contact — "very large values may imply raft is
stalled"). With `--raftz`, the meta group's `nats_core_raftz_meta_committed`, `_applied` and `_pindex`
— whose `cluster_name` and `server_id` labels are shifted at v0.9.11 (read them by `server_name`).
Nothing exports a stream's or consumer's own group; `/raftz?acc=…&group=…` on [[monitoring-endpoints]]
remains the way. Names on [[metrics]].


## Related

[[replicas]] · [[stream-placement]] · [[stream]] · [[consumer]] · [[monitoring-endpoints]] ·
[[stream-leader-keeps-moving]] · [[meta-layer]] · [[upgrade-a-cluster]] · [[rebalance-streams]] ·
[[build-a-3-node-cluster]] ·
[[malformed-or-corrupt-message]] · [[stream-has-high-message-lag]] · [[disaster-recovery]] ·
[[multi-region-jetstream]] · [[jetstream-domain]] · [[jetstream-sizing]] ·
[[jetstream-out-of-disk]] · [[advisories]]

## Sources

[[s-docs-raft-and-leaders]] · [[s-docs-replication-and-r3]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-placement]] · [[s-docs-upgrade-to-2.14]] · [[s-relnotes-2.14.0]] ·
[[s-docs-upgrade-to-2.12]] · [[s-nats-server-jetstream-log-warnings]] · [[s-adr-61-meta-quorum-rescue]] ·
[[s-docs-rolling-upgrades]] ·
[[s-docs-monitoring-advisories-and-events]] · [[s-docs-monitoring-endpoints]] ·
[[s-docs-disaster-recovery]] · [[s-docs-forming-a-cluster]] · [[s-docs-jetstream-in-a-cluster]] ·
[[s-docs-scaling-and-peers]] · [[s-docs-your-first-cluster]] · [[s-gh-6490-high-message-lag]] ·
[[s-gh-7438-multi-region-availability]] · [[s-gh-7463-jetstream-corruption]] ·
[[s-nats-server-lame-duck]] · [[s-synadia-jetstream-memory-patterns]] ·
[[s-nats-server-jetstream-resources]] · [[s-nats-server-jetstream-cluster]] · [[s-gh-7533-quorum-loss-mqtt]] · [[s-nats-server-raftz]] · [[s-docs-monitor-raftz]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]] · [[s-nats-surveyor-metrics-observed]]
