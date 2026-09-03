---
title: Replicas
type: concept
area: [jetstream, topology]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [replicas, r3, r5, durability, quorum, sync_interval]
aliases: [replication, R1, R3, R5, num_replicas, replica count]
sources: [s-docs-single-server, s-docs-disaster-recovery, s-docs-surviving-node-loss, s-docs-replication-and-r3, s-docs-stream-config, s-docs-raft-and-leaders, s-docs-sizing-and-resources, s-adr-31-direct-get, s-docs-mirrors-as-dr, s-docs-jetstream-in-a-cluster, s-k8s-760-jetstream-pvc-per-replica, s-docs-mqtt-auth-and-clustering, s-nats-server-mqtt-websocket-observed, s-docs-get-direct, s-docs-kubernetes, s-docs-mirrors-and-sources, s-docs-placement, s-docs-rolling-upgrades, s-docs-scaling-and-peers, s-docs-upgrade-to-2.12, s-docs-worker-pool, s-docs-your-first-cluster, s-gh-4342-memory-stream-backup, s-gh-6490-high-message-lag, s-gh-7831-standalone-to-cluster, s-gh-7982-no-suitable-peers, s-nats-server-jetstream-resources, s-natscli-backup-restore, s-nats-server-jetstream-cluster, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.15-preview, s-relnotes-2.10, s-nats-server-stream-consumer-config, s-nats-server-config-mutability-observed]
created: 2026-08-31
updated: 2026-09-03
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
- **Replication is not a backup, and this is the most expensive misunderstanding on the page.** R3
  protects against a node dying. An accidental `purge`, a bad migration or a logic bug replicates to
  all three copies at once — "R3 is availability, not a backup". The copies that survive a *mistake*
  are a snapshot ([[backup-and-restore-jetstream]]) and, partially, a mirror
  ([[mirrors-and-sources]]); the choice between them is [[disaster-recovery]]
  (source: [[s-docs-disaster-recovery]]).
- **On a single server, R>1 is refused rather than degraded.** `nats stream add … --replicas 3`
  on a non-clustered server answers `replicas > 1 not supported in non-clustered mode`
  (error **10074**, [[error-codes]]) — redundancy is a cluster's job, so the fix is
  [[build-a-3-node-cluster]], not a flag (source: [[s-docs-single-server]]). What that cluster has to
  be — a `cluster {}` block, seed routes on each server, and peers that discover the rest of the mesh
  from whoever they reach first — is [[build-a-3-node-cluster]]'s subject
  (source: [[s-docs-your-first-cluster]]).
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
([[worker-pool]]) — a single stream feeding a pool of pull consumers scales by adding workers, not
copies (source: [[s-docs-worker-pool]]) — or split subjects across streams.

**A replica is not a mirror.** Replicas are one Raft group holding one log: every copy has the same
sequence numbers and a write is not acked until a quorum holds it. A [[mirrors-and-sources|mirror]]
is a *second stream* that copies asynchronously, keeps its own retention, and reports its distance as
`Lag` in `nats stream info` — with no consensus and no guarantee it is current
(source: [[s-docs-mirrors-and-sources]]). Where each one helps is
[[disaster-recovery]].

**The independence is a storage property too.** R3 only buys what it costs while the three copies can
fail separately, which is why the Helm chart gives each replica its own PersistentVolumeClaim rather
than one shared volume: "In the cloud ideally 3 replicas will run in 3 different availability zones,
and each replica has exclusive access to a fast block based disk in its availability zone", and
"JetStream needs fast block based storage. Should not use NFS or other slow file based storage with
it" (source: [[s-k8s-760-jetstream-pvc-per-replica]]). Three replicas cost three disks and there is
no supported way to collapse them — see [[kubernetes-storage]].

## Replicas cost account quota, not just disk

A node's disk is not the only ceiling. **On an un-tiered account an R3 stream counts as
`replicas × bytes` against the account's `MaxStore`** — a 10 GiB stream at R3 spends 30 GiB of the
account's storage limit, because the limit measures total bytes stored across all replicas. **On a
tiered account replication is baked into the tier**: the bytes reported are usable bytes, so a
10 GiB tier holds a 10 GiB R3 stream (source: [[s-docs-sizing-and-resources]]).

That rule is three lines in the server, not a docs simplification: `accountReservation`
(`jetstream.go:2511–2519`, nats-server 2.14.6) counts `replicas × bytes` on an untiered account, a
tiered limit "already bakes in replication" and counts once, and **the per-server footprint is always
a single replica's worth** (source: [[s-nats-server-jetstream-resources]]).

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

**You raise a count, you never name a server.** The meta leader assigns the extra replica to a
server that qualifies under the stream's placement, records the new peer set in its assignment log,
and the group picks it up — so growing a group is a placement question, not a hostname one.

**The new peer counts for quorum immediately and holds no data.** Adding one to an R=3 group makes
it R=4, and "an `R=4` group commits once **three** peers hold a write, not two". What the empty peer
*cannot* do is win an election — "it stays an observer until the leader's first entries reach it".
The practical rule that follows is **one membership change at a time**, with `nats stream info` read
until the new peer is `current`; until then the group is easier to stall, not harder
(source: [[s-docs-scaling-and-peers]]).

**Two more ways a replica count changes**, both worth knowing before you need them:

- **On restore.** `nats stream restore --replicas <n>` overrides "how many replicas of the data to
  create", alongside `--cluster` and `--config` — so a restore is a placement decision, not just a
  copy, and is the supported way to land a stream at a different count (source:
  [[s-natscli-backup-restore]], nats CLI 0.4.0; [[backup-and-restore-jetstream]]).
- **Temporarily, as a technique.** Raising a stream to R3, waiting for every replica to read
  `current`, doing the disruptive thing, then lowering it again is a maintainer-suggested pattern for
  surviving a restart on a stream that normally runs R1: "before the restart update the stream's
  configuration to set `replicas=3`, check using `nats stream info` that all the new replicators have
  caught up, restart your server and then update the stream's configuration back to `replicas=1`".
  The blunter version of the same advice: "If it's fault-tolerance you need (unscheduled server
  restart) then you must use `replicas=3`" (source: [[s-gh-4342-memory-stream-backup]]).

**One migration that does not work: standalone → clustered.** Adding a cluster block to a
single-server deployment and restarting, intending to raise R1 streams to R3 afterwards, loses the
data instead — "the existing streams are immediately marked as orphaned and automatically deleted
before I have any opportunity to update their replica counts", because a clustered setup "stores on
which servers those streams/consumers are hosted separately" and a standalone one has no such
record. In-place migration "is not planned at the moment"; back up and restore into the cluster, or
leafnode the standalone server to the cluster, mirror the streams across and promote the mirrors
(source: [[s-gh-7831-standalone-to-cluster]]).

`--replicas=3` **requires a real cluster of at least three servers**; a single-node server rejects
it, which is expected rather than a misconfiguration (source: [[s-docs-surviving-node-loss]]). If
the servers exist but the edit still fails with `no suitable peers for placement` (**10005**), the
cause is a placement constraint — and **placement never relaxes itself to fit a replica count**. It
fails so you notice, including when fewer servers carry the required tags than the count asks for
(source: [[s-docs-placement]]; [[stream-placement]]).

`10005` is a *class* of error rather than one cause — storage capacity is one, an unmatched tag
another — and the response names at most the tag. The only thing that says which peers were rejected
and why is **debug logging**, which prints one line per candidate:

```
[DBG] Peer selection: discard ** reason: not target cluster **
```

(source: [[s-gh-7982-no-suitable-peers]], observed on 2.12.5; [[no-suitable-peers-for-placement]]).

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

**That line is the gate on every rolling operation.** "Every replica must read `current` before you
take the next node down", because "a restarted node isn't done until its `ORDERS` replica has caught
up" and "two nodes down costs the R3 stream its quorum" (source: [[s-docs-rolling-upgrades]];
[[upgrade-a-cluster]] is the runbook, and it also says to upgrade the meta-leader last).

**Readiness does not tell you this.** On Kubernetes "a pod catching its R3 replicas up after a
restart still reports ready and keeps serving clients" — documented behaviour, not a bug — so replica
catch-up belongs in a **startup** probe, and a cluster must be a StatefulSet rather than a
Deployment: "Each node owns a slice of the R3 stream" and has to come back with its own volume rather
than as a fresh replica (source: [[s-docs-kubernetes]]; [[kubernetes-storage]]). Writing a readiness
probe that requires peers deadlocks the cluster, because no node is ready until it can see the
others.

**A `JetStream cluster` lag warning is about replication, not consumers.** It fires when proposals
accepted from publishers outrun what has been committed and applied locally on the **stream leader** —
the two named causes are a core NATS publish into a stream's subject and async JetStream publishes
from many publishers at once, both of which bypass the back-pressure a `PubAck` provides. The log
line is rate-limited, so its frequency is not a measure of severity (source:
[[s-gh-6490-high-message-lag]]; [[stream-has-high-message-lag]]).

**2.12 hardened the empty-replica case.** Scale-up and reset now guard against "leader elections
based on empty state", and replicated in-memory streams became more reliable — "all but one server
can be restarted and the in-memory stream's data can reliably be caught back up". The cost is stated
in the same breath: during that scenario **all servers involved in the stream's replication must be
available, not just enough for quorum** (source: [[s-docs-upgrade-to-2.12]]).

Reads from the **leader** are read-after-write; reads from a follower can be correct but behind. So
`nats stream get` "goes to the leader" and is always current, while a [[direct-get|Direct Get]]
"answers from any replica or mirror, which may trail the leader" — **do not use it for
read-after-write checks**, such as confirming a publish landed (source: [[s-docs-get-direct]]).

## Version notes: the 2.11 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch replicated streams from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- **`cluster_traffic: owner`** — since 2.11.0 an account's `jetstream` block can carry its assets'
  Raft traffic "into the asset account instead of using the system account" (#5466, #5947); the
  choice is reported as `traffic_account` and `system_account` on stream and consumer info and in
  `/jsz` from 2.11.9 (#7193). Documented nowhere in the docs tree — `inbox/docs-issues.md` #56
  (source: [[s-relnotes-2.11]]).
- **2.11.4**: a stream or consumer update is refused while every peer is offline (#6856).
  **2.11.9**: a consumer cannot get more replicas than its stream (#7202). **2.11.11**: scaling up
  from R1 installs a snapshot "allowing recovery after restart if interrupted, avoiding a potential
  desync" (#7509); binary stream snapshots are preferred by default on new route connections (#7479);
  catch-ups use delete ranges for streams with many interior deletes (#7512).
- The ack-through-Raft change of 2.11.0 (#6140) means an R3 `interest` or `workqueue` stream
  replicates its removals as well as its writes — see [[retention-policies]].


### The 2.12 line

- **2.12.0**: a replicated stream can be created "even if some of the replica nodes are offline"
  (#7075); replicated streams flush asynchronously by default (#7018, #7163) (source:
  [[s-relnotes-2.12]]).
- **2.12.5**: replica `lag` and `current` in stream info, consumer info and `/jsz` "are now more
  consistent, no longer reporting incorrect values on follower nodes" (#7885); tiered reservations
  no longer over-count replicated assets (#7880). **2.12.10**: scale-down consistency (#8253); a
  peer-set drift after removing an online node (#8258); quorum calculated correctly when gateway
  URLs resolve to several IPs (#8238). **2.12.12**: a catch-up is no longer skipped over limits
  (#8265). **2.12.14**: a stream recreated while a node was down is not treated as an update by the
  returning node (#8413).


## To verify

- ~~The docs do not state a replica count for the meta group~~ **Settled 2026-09-01**: there is none
  to state. The meta group's peers are every JetStream-enabled server the cluster knows (across
  gateways too), quorum is `size/2 + 1`, and nothing relates it to `num_replicas` — [[meta-layer]]
  (source: [[s-nats-server-jetstream-cluster]]).
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


## Auditing replica counts

Two commands, both from the docs' cluster chapter and neither previously on this page
(source: [[s-docs-jetstream-in-a-cluster]]).

Find every stream that is silently R1 on a cluster — "on a cluster, a single copy means no failover":

```
nats stream find --replicas=1
nats stream edit ORDERS --replicas=3
```

Then assert the count you expect, in a form a health monitor can run. It **exits non-zero** when the
stream is under-replicated:

```
nats server check stream --stream=ORDERS --peer-expect=3
```

```
OK ORDERS OK:3 peers OK:0 sources | sources=0
```

Two constraints to read alongside them:

- **Five is the ceiling.** "A stream keeps at most five copies, so more servers add capacity, not
  more copies of one stream."
- **R3 across one failure domain is not R3.** "Three copies survive one server loss only if the three
  servers can fail independently" — steering that is [[stream-placement]].
- Replicas never leave their cluster. A copy in another region is [[mirrors-and-sources]], not a
  replica count — [[multi-region-jetstream]].


## One replica count nobody sets: MQTT's

[[mqtt]] state lives in five streams the server creates for itself, and their `num_replicas` is
**derived, not defaulted**: with `mqtt.stream_replicas` unset the server counts the addresses in its
own `routes` list and clamps the result to 1–3.

That is the number of routes **written in the config**, not the size of the cluster. Confirmed on
2.14.6: a genuine three-node cluster (`/jsz` reporting `meta_cluster.cluster_size: 3`) whose node listed its
two peers created all five MQTT streams at **R=2** — survivable for one node loss, and not what a
three-node cluster implies. Setting `mqtt { stream_replicas: 3 }` on the same node gave R=3 (sources:
[[s-docs-mqtt-auth-and-clustering]], [[s-nats-server-mqtt-websocket-observed]]).

The server states what it chose, once, at the point the streams are created:

```
[INF] Creating MQTT streams/consumers with replicas 2 for account "$G"
```

Ask for more than the cluster has peers and the streams are never created, which surfaces as MQTT
clients unable to connect — [[no-suitable-peers-for-placement]].

## A publish that timed out may still be stored

The `PubAck` promise is one-directional: an ack means the write is on a quorum; **no ack means
unknown**, not "not stored". Observed on 2.14.6 with two of three servers killed: two publishes that
returned `nats: timeout` were both in the stream once quorum returned, because the leader had appended
them and later re-won its group. Had a different server won, they would have been discarded. Treat a
timeout as unknown and resend with a `Nats-Msg-Id` so the duplicate is dropped — and note that
`nats pub -J` prints `Published …` *before* it waits for the ack, then `nats: error: nats: timeout` on
the next line ([[meta-layer]]; source: [[s-nats-server-jetstream-cluster]]).


### The 2.14 line, and the preview

- **2.14.0**: a Raft node **will not start** on a missing, corrupt or misaligned snapshot (#7566,
  #7580, #7620); an overrun leader steps down (#7853); stream state snapshots on replicated streams
  are asynchronous (#7876) (source: [[s-relnotes-2.14]]). **2.14.1**: storage reservations for
  un-tiered streams consistent between clustered and non-clustered modes (#8170). **2.14.6**: **a
  stream config update with `replicas > 1` is rejected on a non-clustered server** (#8464) — before
  it the update was accepted and could not be honoured; inline compaction honours `sync_interval:
  always` (#8475); consumer tiers distinguished when enforcing limits (#8484).
- **2.15 preview**: on a replicated stream `sync_interval: always` "now sync[s] their WAL entries but
  no longer sync[s] upper stream layer writes" — "dramatically improves performance"; R1 streams
  unchanged (#8447) (source: [[s-relnotes-2.15-preview]]). The durability argument for `always` on
  R3 becomes: the Raft log is synced, the message blocks are not.


## `num_replicas`, after creation

Free on a cluster — 1 → 3 → 1 was accepted on the three-node lab — and refused on a standalone
server for any value above 1 (`replicas > 1 not supported in non-clustered mode`, 10074); the cap is
5 (`StreamMaxReplicas`) and a stream capturing `>` must be R1. A consumer's `num_replicas` may not
exceed its stream's and must equal it on memory and workqueue streams. Tabled on
[[stream-and-consumer-config]] (source: [[s-nats-server-stream-consumer-config]],
[[s-nats-server-config-mutability-observed]]).


## Related

[[stream]] · [[consumer]] · [[raft-in-nats]] · [[stream-placement]] · [[retention-policies]] ·
[[jetstream-sizing]] · [[stream-leader-keeps-moving]] · [[defaults-and-limits]] · [[config-keys]] ·
[[stream-has-high-message-lag]] · [[malformed-or-corrupt-message]] · [[direct-get]] ·
[[worker-pool]] · [[mirrors-and-sources]] · [[disaster-recovery]] · [[upgrade-a-cluster]] ·
[[kubernetes-storage]] · [[no-suitable-peers-for-placement]] · [[backup-and-restore-jetstream]] ·
[[build-a-3-node-cluster]]

## Sources

[[s-docs-surviving-node-loss]] · [[s-docs-replication-and-r3]] · [[s-docs-stream-config]] ·
[[s-docs-raft-and-leaders]] · [[s-docs-sizing-and-resources]] · [[s-adr-31-direct-get]] · [[s-docs-mirrors-as-dr]] · [[s-docs-jetstream-in-a-cluster]] ·
[[s-docs-single-server]] · [[s-docs-disaster-recovery]] · [[s-k8s-760-jetstream-pvc-per-replica]] ·
[[s-docs-mqtt-auth-and-clustering]] · [[s-nats-server-mqtt-websocket-observed]]

[[s-docs-get-direct]] · [[s-docs-kubernetes]] · [[s-docs-mirrors-and-sources]] ·
[[s-docs-placement]] · [[s-docs-rolling-upgrades]] · [[s-docs-scaling-and-peers]] ·
[[s-docs-upgrade-to-2.12]] · [[s-docs-worker-pool]] · [[s-docs-your-first-cluster]] ·
[[s-gh-4342-memory-stream-backup]] · [[s-gh-6490-high-message-lag]] ·
[[s-gh-7831-standalone-to-cluster]] · [[s-gh-7982-no-suitable-peers]] ·
[[s-nats-server-jetstream-resources]] · [[s-natscli-backup-restore]] · [[s-nats-server-jetstream-cluster]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]] · [[s-relnotes-2.10]] · [[s-nats-server-stream-consumer-config]] · [[s-nats-server-config-mutability-observed]]
