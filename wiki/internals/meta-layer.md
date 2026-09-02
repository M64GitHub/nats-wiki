---
title: The meta layer
type: internals
area: [jetstream, topology, monitoring]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [meta-layer, meta-group, meta-leader, raft, quorum, orphan, peer-remove, election, 10008, healthz, jsz, meta_compact, extension_hint, observer, snapshot]
aliases: [meta group, meta leader, metadata controller, metalayer, meta-layer, "_meta_", JetStream meta layer, metadata leader, meta controller]
sources: [s-nats-server-jetstream-cluster, s-docs-jetstream-in-a-cluster, s-docs-raft-and-leaders, s-adr-61-meta-quorum-rescue, s-gh-7831-standalone-to-cluster, s-nats-server-leafnode-js-domains, s-docs-scaling-and-peers, s-gh-7438-multi-region-availability, s-gh-7533-quorum-loss-mqtt, s-gh-6892-evict-a-sick-node, s-nats-server-raftz]
created: 2026-09-01
updated: 2026-09-01
---

# The meta layer

The **meta layer** is the one Raft group a JetStream cluster runs *about itself*: its log records
which streams and consumers exist, with which configuration, on which servers. Every
JetStream-enabled server is a peer of it, one of them is the **meta leader**, and every create,
update, delete, stepdown and peer-remove is a write to that log. Stream data never passes through it
— which is why losing the meta leader stalls *changes* and not traffic, and why a stream with no
record in it is deleted.

## What the server does

### One group, and every server is in it

The group is called `_meta_` and lives in the **system account's** JetStream store at
`<store_dir>/jetstream/$SYS/_js_/_meta_/` — a small filestore (1 MB blocks) holding `msgs/*.blk`
(the log), `snapshots/`, `peers.idx` (the configured peer set) and `tav.idx` (term and vote). A
standalone server has no such directory at all (source: [[s-nats-server-jetstream-cluster]]).

**It has no replica count.** Where a stream has `num_replicas`, the meta group's peers are simply
every JetStream-enabled server the cluster knows: at first start the peer set is every node the
server has heard of that is not marked offline, and the *expected* size is the larger of 2 and the
number of `routes` plus configured gateway URLs. Quorum is always `size/2 + 1`. In mixed mode (some
servers without JetStream) the leader trims the size to the JetStream-enabled count, which is why a
non-JetStream server neither votes nor blocks (source: [[s-nats-server-jetstream-cluster]]; the docs
state the membership rule in prose — "Every JetStream-enabled server in the cluster belongs to it" —
source: [[s-docs-jetstream-in-a-cluster]]).

Because gateway URLs count toward the expected size, **a super-cluster is one meta group across
the WAN**, and every assignment needs a majority of all its servers. That is the "global quorum"
[[choosing-a-topology]] and [[multi-region-jetstream]] warn about, now read from the source rather
than inferred from a thread (source: [[s-gh-7438-multi-region-availability]] for the question,
[[s-nats-server-jetstream-cluster]] for the mechanism). A JetStream **domain** is the boundary of
one meta group — [[jetstream-domain]].

### It stores assignments, not messages

Every server holds the same map, `account → stream → assignment`. A **stream assignment** carries
the config, the requesting client, the creation time, a **group** (its Raft group name, its peer
list, storage, cluster, a preferred leader) and the stream's consumers, each with its own
assignment and group. The log's operations are *assign stream*, *assign consumer*, *remove
stream*, *remove consumer* and *update stream*; peer membership changes are Raft-level add-peer and
remove-peer entries in the same log. A snapshot is the whole list of assignments
(source: [[s-nats-server-jetstream-cluster]]).

That map is the only thing that makes a stream *exist* to a cluster. The maintainers' description
in the standalone-to-cluster thread — a clustered setup "stores on which servers those
streams/consumers are hosted separately", a single server "doesn't have/need that" — is this map
(source: [[s-gh-7831-standalone-to-cluster]]).

### Every change is a proposal by the meta leader

A clustered `STREAM.CREATE` is handled only by the meta leader: it validates, picks peers
([[stream-placement]]), and **proposes** the assignment to the group. The assigned servers create
the stream when the entry is applied, and the reply to the client comes from that path — not from
the API handler. The same create sent again with an **identical** config is answered from the
existing assignment; a different config is refused with *stream name already in use*.

Every meta-handled request runs the same two checks first. If the server believes the group has
**no leader**, it answers **`10008 JetStream system temporarily unavailable`**. If it is simply
**not the leader**, it does not answer at all — the request is the leader's to answer, and if there
is no leader yet the client sees only its own timeout ([[nats-timeout]]). Creates, updates,
deletes, consumer creates, `$JS.API.META.LEADER.STEPDOWN`, `$JS.API.SERVER.REMOVE`, account purge
and stream moves all go this way; so does `STREAM.INFO` on a **work-queue or interest** stream,
which the meta leader answers because it must know the consumers (source:
[[s-nats-server-jetstream-cluster]]).

Reads and writes of a stream do **not**: they go to the stream's own group ([[raft-in-nats]]).

### Losing the meta leader

What happens depends on *how* it was lost, measured on 2.14.6 (source:
[[s-nats-server-jetstream-cluster]]):

| event | new leader after | while it lasted |
|---|---|---|
| first start of an empty cluster | **0.28 s** | bootstrap campaigns immediately |
| all three servers restarted | **5.3 s** | the election timer, 4–9 s from the last heartbeat; each node logs `Healthcheck failed: "JetStream has not established contact with a meta leader"` once a second |
| `nats server cluster step-down` | **0.5 s** | a leadership *transfer* to a peer heard from within 3 s; no election timer |
| meta leader `kill -9` | **3.5 s** | creates time out, then resume; an R3 stream kept accepting publishes throughout; `/healthz` said `JetStream is not current with the meta leader` |
| a follower restarted | **0.55 s** to learn the leader | no election at all |
| two of three servers `kill -9` | never | the survivor **kept reporting itself leader for 10 s** — `/healthz` ok, `/jsz` naming itself — then logged `JetStream cluster no metadata leader`; only from then do creates get `10008` instead of a timeout |

The 10 s comes from two constants: the leader checks for lost quorum every 10 s, and a peer counts
as present while heard from within 10 s, so the worst case is about 20 s. **Heartbeat 1 s, election
timer 4–9 s, lost-quorum 10 s, peer-remove timeout 5 min — none of these has a config key.** They
are package variables in `raft.go`; the only meta-layer keys are `meta_compact`,
`meta_compact_size`, `meta_compact_sync` and `extension_hint` (source:
[[s-nats-server-jetstream-cluster]]).

**A request that timed out is not necessarily lost.** A proposal the old leader accepted sits in
its log; it is committed later if that server wins the next election and discarded if another does.
Observed both ways: two creates that had timed out existed after quorum returned (same server
re-won), one did not (a different server won), and two publishes that returned `nats: timeout` were
both stored. So after a timeout, check (`nats stream info`) before retrying with anything but the
identical request — a create with the same config is idempotent, a publish needs `Nats-Msg-Id`
([[replicas]] has the durability side).

### Orphans: what the missing record does

Thirty seconds after a server finishes replaying the meta log — and only if a meta leader exists and
this server is current with it — it compares every stream and consumer it **recovered from disk**
against the assignment map. Anything on disk with no assignment is an orphan and is **deleted**,
with one warning line:

```
[WRN] Detected orphaned stream '$G > ORPHAN', will cleanup
```

The code comment says what the check is for: recovered assets that "the meta layer's mappings
should clean up, but under crash scenarios there could be orphans". The same check is what deletes
a standalone server's streams when it is restarted as a cluster member: the streams are restored
from disk first (`Restored 3 messages for stream …`), the server joins the group, and 30.0 s later
they are gone. There is no flag and no prompt (source: [[s-nats-server-jetstream-cluster]], observed;
[[streams-deleted-when-clustering-a-standalone-server]] is the gotcha).

### Peers: remove, return, rejoin

- `nats server cluster peer-remove <server>` sends `$JS.API.SERVER.REMOVE` on the **system
  account** to the meta leader, which looks the name up among its peers (`10044 server is not a
  member of the cluster` if absent), refuses a second change while one is in flight
  (`10202`), and **replies only once a quorum holds the removal**. One change at a time is also the
  docs' rule (source: [[s-docs-scaling-and-peers]]).
- The removed server logs `[ERR] JetStream being DISABLED, our server was removed from the
  cluster`, publishes `$JS.EVENT.ADVISORY.SERVER.REMOVED` ([[advisories]]) and shuts its JetStream
  down — it keeps serving core NATS, `/healthz?js-enabled-only=true` answers `503 … (10076)`. The
  leader re-places every stream that had the peer.
- **A removed server that stays running and configured is re-added after five minutes.** Observed:
  restarted 88 s after removal it followed the group and reported `/healthz` ok without being a
  member; six minutes after the removal it was back in the leader's peer list, with no log line on
  either side. Peer-remove a server you are *retiring*, and stop it or take the cluster block out of
  its config inside that window (source: [[s-nats-server-jetstream-cluster]]).
- **Quorum counts configured peers, not live ones**, and a peer-remove is itself a write to the
  log — so a group that has lost its majority cannot shrink its way out. That failure and its exits
  (bring the peers back under their old names; `$JS.API.META.RESCUE` in 2.15) are on
  [[disaster-recovery]] (source: [[s-adr-61-meta-quorum-rescue]]). With no leader the CLI's
  peer-remove message is misleading: `did not receive a response from the meta leader, ensure the
  account used has system privileges …` — the credentials are fine, the leader is missing.
- A returning peer is folded back into every stream that is missing peers. On shutdown a meta
  leader transfers leadership first and waits up to 2 s; a server that trips its resource limits
  steps down as meta leader on its own (source: [[s-nats-server-jetstream-cluster]]).

### Snapshots and compaction

The meta log is snapshotted on a one-minute ticker, after applying more than 8 MB when 30 s have
passed since the last snapshot, and always after a membership change or on becoming leader.
`jetstream { meta_compact: <entries>, meta_compact_size: <bytes> }` (2.12+, reloadable) turn the
check into a threshold; **both default to 0, which means "snapshot whenever checked"**, so
setting one makes snapshots rarer, not more frequent. Snapshots are asynchronous unless
`meta_compact_sync: true`; above ten times the size threshold (80 MB when unset) the server falls
back to a blocking one and warns `JetStream cluster metalayer log size has exceeded async
threshold`. A slow one is logged as `Metalayer async snapshot took …` or `Metalayer blocking
snapshot took …`. Stream groups compact on a 2-minute ticker at 8 MB or 65,536 entries; consumer
groups at 64 KB or 1,024 (source: [[s-nats-server-jetstream-cluster]]).

### Observer mode and `meta.Reset()` — the leafnode cases

A server that **solicits** a leafnode connection sharing the system account starts its meta node as
an **observer**: it follows the hub's meta group and never campaigns (its election timer is 48 h),
because it is extending that domain rather than forming its own. It logs how to turn this off —
`extension_hint: no_extend` — and remembers in `peers.idx` whether the previous run extended, so a
restart does not wait for contact again. A *standalone* server never extends unless told to with
`extension_hint: will_extend`. When a leaf actually starts extending the hub, `meta.Reset()`
discards its own meta state: leadership, every queued entry, **the whole snapshots directory**, the
log, the peer set (to itself alone) and the term (sources: [[s-nats-server-jetstream-cluster]],
[[s-nats-server-leafnode-js-domains]]; [[jetstream-domain]], [[leafnode]]).

## Where it lives

`server/jetstream_cluster.go` at v2.14.6 — `setupMetaGroup`, `monitorCluster`, `applyMetaEntries`,
`checkForOrphans`, `processAddPeer` / `processRemovePeer`, `processLeaderChange`; the timing
constants and `Reset` in `server/raft.go`; the API gates in `server/jetstream_api.go`; `/healthz`
and `MetaClusterInfo` in `server/monitor.go`. Ranges with line numbers:
`raw/nats-server-src/jetstream-cluster-v2.14.6.md`; the run:
`raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md`. The docs describe it in
`learn/topologies/jetstream-in-a-cluster.md` and `learn/clustering/raft-and-leaders.md`
([[s-docs-jetstream-in-a-cluster]], [[s-docs-raft-and-leaders]]).

## What you can observe

**Log lines** (INFO unless marked):

```
Creating JetStream metadata controller
JetStream cluster bootstrapping                       # no peers.idx on disk: first start
JetStream cluster recovering state                    # peers.idx found
Self is new JetStream cluster metadata leader
JetStream cluster new metadata leader: n3/east        # <server>/<cluster>
JetStream cluster no metadata leader
[WRN] JetStream has not established contact with a meta leader
[WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"   # once a second at startup
[WRN] Detected orphaned stream '$G > ORPHAN', will cleanup
[ERR] JetStream being DISABLED, our server was removed from the cluster
[WRN] JetStream cluster stream '$G > ORDERS' has NO quorum, stalled                    # the stream's group, not meta
```

**`/jsz`** always carries `meta_cluster`: `name`, `leader`, `peer` (the leader's id),
`cluster_size`, `pending`, `pending_requests`, `pending_infos`, `snapshot{pending_entries,
pending_size, last_time, last_duration}` — and, **on the leader only**, `replicas[]` with each other
peer's `current` and `active` (nanoseconds since last contact). There is no `meta` query parameter;
`/jsz?meta=1` is accepted and ignored. `/jsz?raft=1&streams=1` adds each stream's `raft_group`,
`leader_since` and replicas ([[monitoring-endpoints]]).

**`/healthz?js-meta-only=true`** answers `200 {"status":"ok"}` or `503` with one of:
`JetStream has not established contact with a meta leader` (no leader known — startup, or after
the old leader's term has ended), `JetStream is not current with the meta leader` (a leader is known
but not heard from within 2 s — **this is what a dead leader looks like**), `JetStream is still
recovering meta layer`, `JetStream meta layer is not running`, `JetStream meta layer write error: …`.

**`nats server report jetstream`** (system account) prints the `RAFT Meta Group Information` table —
`Connection Name`, `ID`, `Leader`, `Current`, `Online`, `Active`, `Lag` — and marks the leader `*`
in the summary above it. Without system-account credentials it prints nothing.

```
nats server report jetstream                 # who leads the meta group
nats server cluster step-down                # move meta leadership (--host <server> to choose)
nats server cluster peer-remove <server>     # $JS.API.SERVER.REMOVE — one at a time
curl -s http://127.0.0.1:8222/healthz?js-meta-only=true
curl -s http://127.0.0.1:8222/jsz | jq .meta_cluster
```

**`/raftz`** shows the group itself, as `$SYS` → `_meta_`: `state`, `term`, `leader`, `size` and
`quorum_needed`, `committed` / `applied`, the `wal` state, and `peers` with `known`, `last_seen` and (on
the leader) `last_replicated_index`; `ever_had_leader: false` is a node still in its cold boot. A bare
`/raftz` shows only this group, because the account filter — `acc`, not the docs' `account` — defaults
to the system account (source: [[s-nats-server-raftz]]; field table on [[monitoring-endpoints]]).

**Advisories**: `$JS.EVENT.ADVISORY.SERVER.REMOVED` on a peer-remove;
`$JS.EVENT.ADVISORY.DOMAIN.LEADER_ELECTED` when a meta leader is elected ([[advisories]]).

## Why an operator cares

- **[[streams-deleted-when-clustering-a-standalone-server]]** — the deletion *is* the orphan check:
  no assignment, 30-second timer, one WARN line. The only defence is a backup before the restart.
- **[[replicas]]** — the meta group has no replica count to set; its size is the JetStream server
  count, and a super-cluster's is the total across regions.
- **[[raft-in-nats]]** — the election window and heartbeat are constants; the *meta* election is
  the one that blocks operations cluster-wide, and a surviving leader lies about itself for 10 s.
- **[[no-suitable-peers-for-placement]]** — the "timeout before a meta leader exists" case is the
  silent non-answer above, not a placement failure.
- **[[nats-timeout]]** — a JetStream API request that reaches a non-leader during an election is
  dropped without a reply; `10008` only appears once the server knows it is leaderless.
- **[[disaster-recovery]]** and **[[upgrade-a-cluster]]** — configured-peer quorum, why the meta
  leader goes last and is drained, and the five-minute rejoin after a peer-remove.
- **[[jetstream-domain]]**, **[[choosing-a-topology]]**, **[[multi-region-jetstream]]** — one meta
  group per domain; gateways widen it.
- **[[stream-leader-keeps-moving]]** — the one public report of a quorum loss with nobody's hand on
  it (gh#7533, unanswered) reads as this page's timeline from the outside: `10008` first, then a
  stream group, then a consumer group (source: [[s-gh-7533-quorum-loss-mqtt]]).
- **[[evict-a-sick-server]]** — what a peer-remove does to a running server, and the five-minute
  rejoin, are the half of gh#6892's question that can be answered from here; the thread itself got no
  reply (source: [[s-gh-6892-evict-a-sick-node]]).

## Version notes

- `meta_compact`, `meta_compact_size`, `meta_compact_sync` — **2.12** (source: the config reference,
  via [[config-keys]]).
- `--host` / placement on `nats server cluster step-down` — **2.11** or newer (the CLI warns).
- `$JS.API.META.RESCUE` — **2.15** preview only (source: [[s-adr-61-meta-quorum-rescue]]).
- Everything measured above is **2.14.6**.

## To verify

- The first release in which JetStream clustering — and therefore the meta group — appeared is not
  stated by any source ingested here; no `since:` is claimed.
- The exact moment after a stepdown at which `10008` replaces a timeout was not characterised: one
  create issued right after the `no metadata leader` line still timed out, a consumer create 3 s
  later got `10008`.

## Related

[[raft-in-nats]] · [[replicas]] · [[stream-placement]] · [[stream]] · [[consumer]] ·
[[streams-deleted-when-clustering-a-standalone-server]] · [[no-suitable-peers-for-placement]] ·
[[stream-leader-keeps-moving]] · [[nats-timeout]] · [[disaster-recovery]] · [[upgrade-a-cluster]] ·
[[rebalance-streams]] · [[build-a-3-node-cluster]] · [[jetstream-domain]] · [[leafnode]] ·
[[gateway]] · [[choosing-a-topology]] · [[multi-region-jetstream]] · [[monitoring-endpoints]] ·
[[advisories]] · [[js-api-subjects]] · [[error-codes]] · [[config-keys]]

## Sources

[[s-nats-server-jetstream-cluster]] · [[s-docs-jetstream-in-a-cluster]] ·
[[s-docs-raft-and-leaders]] · [[s-adr-61-meta-quorum-rescue]] ·
[[s-gh-7831-standalone-to-cluster]] · [[s-nats-server-leafnode-js-domains]] ·
[[s-docs-scaling-and-peers]] · [[s-gh-7438-multi-region-availability]] · [[s-gh-7533-quorum-loss-mqtt]] · [[s-gh-6892-evict-a-sick-node]] · [[s-nats-server-raftz]]
