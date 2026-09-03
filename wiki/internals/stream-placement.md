---
title: Stream placement
type: internals
area: [topology, jetstream, deploy]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [placement, server_tags, no-suitable-peers, 10005, meta-leader]
aliases: [placement, server_tags, tags, "no suitable peers for placement"]
sources: [s-docs-placement, s-docs-raft-and-leaders, s-docs-replication-and-r3, s-gh-7982-no-suitable-peers, s-adr-7-server-error-codes, s-docs-scaling-and-peers, s-natscli-backup-restore, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.14, s-relnotes-2.15-preview, s-nats-server-stream-consumer-config]
created: 2026-08-31
updated: 2026-09-03
---

# Stream placement

**Placement** is a rule attached to a [[stream]] that limits which servers may hold its replicas.
Without one the meta leader puts the copies on any servers with capacity; with one the meta leader
must honour the constraint **or refuse to create the stream**. It is the mechanism behind the error
`no suitable peers for placement`.

## What the server does

The **meta leader** — the leader of the cluster-wide meta group, see [[raft-in-nats]] — owns
assignment: it decides which servers hold a stream's replicas. Placement is the operator's input to
that decision, and it has exactly **two levers** (source: [[s-docs-placement]]):

- **A cluster name.** Every replica must live in that cluster. Inside a single cluster this is a
  no-op; it matters across clusters, where a stream is pinned to one region.
- **Tags.** A **tag** is freeform label text attached to a server with **`server_tags`** in its
  config; the server advertises its tags to the rest of the cluster.

```
server_name: n1-east
listen: "0.0.0.0:4222"
server_tags: ["region:us-east", "disk:ssd"]
cluster {
  name: east
  listen: "0.0.0.0:6222"
  routes: [ "nats://127.0.0.1:6223", "nats://127.0.0.1:6224" ]
}
jetstream { store_dir: "/data/n1-east" }
```

`server_tags` is documented at `reference/config/server_tags.md` and is marked **reloadable**.

### Tag matching is an intersection

A server qualifies only if it carries **every** tag in the placement list — an intersection, never
an either-or. **Matching folds case** (`disk:ssd`, `disk:SSD` and `disk:Ssd` are the same tag), but
**spelling is exact**: `disk:sdd` matches nothing.

### Placement fails loudly; it never falls back

If the intersection is empty, or if **fewer qualifying servers exist than the replica count asks
for**, the meta leader **refuses the create rather than relaxing the constraint**:

```
nats: error: could not create Stream: no suitable peers for placement, tags not matched ['disk:sdd'] (10005)
```

The message names the tag no server carried, in brackets. Error `10005` is
`JSClusterNoPeersErrF` in `reference/jetstream/errors.md`; see [[error-codes]]. The trailing **`F`**
is not decoration — a constant ending `…ErrF` takes printf-style interpolation, which is why this one
can name your tag at all, and `nats error 10005` looks the whole entry up locally
(source: [[s-adr-7-server-error-codes]]).

**`10005` is a class of failure, not one cause** — an unmatched tag is only the case the message can
describe; storage capacity is another, and the response names at most the tag. The only thing that
says which peers were rejected and why is debug logging, one line per candidate:

```
[DBG] Peer selection: discard ** reason: not target cluster **
```

(source: [[s-gh-7982-no-suitable-peers]], observed on 2.12.5; [[no-suitable-peers-for-placement]]).

### Placement cannot name a leader

Placement constrains *which servers hold the replicas*. It cannot say which of them leads. Setting a
`preferred` server in a stream's placement is rejected outright with `preferred server not permitted
in placement`, and no client library exposes such a field — `Placement` carries only a cluster and
tags (source: [[s-docs-placement]]).

Leadership is moved **after the fact**, with a stepdown request:

```
nats stream cluster step-down ORDERS --preferred n2-east
```

which needs **nats-server 2.11+** and is a request the quorum election can still overrule — see
[[raft-in-nats]].

## Where it lives

`learn/clustering/placement.md` in the docs; the config key is `server_tags`
(`reference/config/server_tags.md`); the placement failure is JetStream error `10005`. Assignment
itself is the meta group's job, so the API surface is under `$JS.API` meta — see
[[js-api-subjects]].

## What you can observe

```
nats server info n1-east                    # the Tags line lists what the server advertises
nats stream info ORDERS                     # the Cluster block shows where the replicas landed
```

`nats server info` queries the **system account** (`$SYS`), so connect with a system user — and
**name the server**, or the command answers for whichever server replies to the `$SYS` ping first.

Placing and re-placing:

```
nats stream add ORDERS --subjects "orders.>" --replicas 3 \
  --cluster east --tag region:us-east --tag disk:ssd --defaults

nats stream edit ORDERS --cluster east --tag region:us-east --tag disk:ssd
```

`--tag` is passed **once per required tag**. On an edit the meta leader **re-assigns** the replicas
to servers matching the new constraint, which is the supported way to move a stream onto a different
set of peers.

**Two other commands land on the same decision, and confusing them is the usual mistake**
(source: [[s-docs-scaling-and-peers]]):

```
nats stream cluster peer-remove ORDERS n4-east     # move one replica off one server
nats stream edit ORDERS --replicas=4               # change how many replicas there are
```

The docs put it in one line: "`peer-remove` moves a replica between servers; `--replicas` sets how
many replicas there are." A `peer-remove` evicts the replica and the meta leader **re-places it on
another server that qualifies**, so the stream keeps its count — *unless placement leaves nowhere to
put it*, in which case an `R>1` stream still loses the peer, the command returns `peer remap failed`
(**10075** `JSPeerRemapErr`) and the group is left a replica short. Only a single-replica stream is
spared. Removing a *server* from the **meta** group is a third command,
`nats server cluster peer-remove`, and it serialises: a second request while one is in flight answers
`cluster member change is in progress` (**10202** `JSClusterServerMemberChangeInflightErr`).

**A restore is a placement decision too.** `nats stream restore` takes `--cluster`, `--tag` and
`--replicas`, so recovering a snapshot is the third way a stream lands on a chosen set of peers —
and `--replicas` on restore is the documented way to bring a stream back at a different count
(source: [[s-natscli-backup-restore]], nats CLI 0.4.0; [[backup-and-restore-jetstream]]).

## Why an operator cares

**`no suitable peers for placement` has two causes, and the message only points at one.** Either a
requested tag is misspelled or absent from every server (the message names it), or **enough servers
carry the tags but too few for the replica count you asked for**. The second is the one that bites
when raising `--replicas` on a live stream — see [[replicas]] — because nothing about the stream's
config changed, only the number of peers it now needs.

**A typo in `server_tags` is silent until a placement asks for the tag.** Read the tags back from
each server with `nats server info` *before* placing against them; do not assume the config took.

**The only way to see the server's actual reasoning is debug logging.** With debug enabled, peer
selection logs each rejected candidate and why (source: [[s-gh-7982-no-suitable-peers]]):

```
[DBG] Peer selection: discard ** reason: not target cluster **
```

The `10005` response names an unmatched tag at best, and on a live edit often carries no detail at
all — so a placement failure has to be **reproduced with debug on**; you cannot get the reason for a
failure that already happened. See [[no-suitable-peers-for-placement]].

**Do not build an operational assumption on where a group first landed.** "The leader is always
`n1-east`" survives exactly until the next election, which is quorum-based and picks from the
survivors.

**Placement is how you scope an expensive setting.** Because `sync_interval: always` costs
performance cluster-wide, the documented pattern is a separate cluster configured that way, with
only the streams that need the strongest durability placed onto it by tag
(source: [[s-docs-replication-and-r3]]). See [[replicas]].

## Version notes

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch placement from v2.10.11 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- `nats stream cluster step-down --preferred <server>` requires **nats-server 2.11 or newer**.

### The 2.10 line

2.10.11 "improved placement of streams in larger clusters when created in rapid succession" (#5079);
2.10.22 fixed a panic "when calculating asset placement in a JetStream cluster" (#5996); 2.10.23
stops duplicate stream-assignment responses "when the stream is being reassigned due to placement
issues" (#6121); 2.10.29 reports a preferred node that does not become leader, "fixing some issues
where multiple assets can believe they are the leader after a scale-up operation" (#6851) (source:
[[s-relnotes-2.10]]).


### The 2.11 line

"Ability to specify preferred placement tags or clusters using `preferred` when issuing stepdown
requests to the metaleader, streams or consumers" is **2.11.0** (#6282, #6284) — the body behind the
docs' "requires 2.11" (source: [[s-relnotes-2.11]]). 2.11.8: ephemeral consumers "will always select
an online server when created on a replicated stream" (#7165). 2.11.9: "Updating a stream with an
empty placement will no longer incorrectly trigger a stream move" (#7222).


## To verify

- The docs reference `reference/config/server_tags.md` and a meta API for assignment; neither has
  been ingested, so per-account placement limits and the full placement field set are not stated
  here.
- Cross-cluster placement (pinning a stream to one cluster in a supercluster) is out of scope of the
  ingested source, which covers only the single-cluster tag case.

### The 2.14 line, and the preview

**2.14.1**: "stream and consumer assignment errors are now surfaced" (#8208) — before it a placement
that failed inside the meta layer could be silent (source: [[s-relnotes-2.14]]). **2.14.3**:
assignment handling refactored "for more consistent migration and info behavior" (#8262); in-flight
proposal tracking consistent during stream moves (#8261). **2.14.4**: a consumer created immediately
after its clustered stream no longer gets `stream not found` (#8410). **2.15 preview**: the
desired-state metalayer makes changing placement or replicas mid-move, and cancelling a move
(`$JS.API.STREAM.CANCEL_MOVE.<stream>`), "much safer"; `$JS.API.STREAM.PEER.EVACUATE.<stream>` and
`$JS.API.SERVER.EVACUATE` move assets off a peer or a server with "full transfer of data and state
without having to peer-remove first" (source: [[s-relnotes-2.15-preview]]).


## The `placement` field

`{cluster, tags, preferred}` (`jetstream_cluster.go:114–118` at v2.14.6); `preferred` is accepted only
on a leader-stepdown request — in a stream configuration it is refused with `preferred server not
permitted in placement` (`stream.go:2276`). Free to change by update (not exercised by the run). On
[[stream-and-consumer-config]] with the other fields (source: [[s-nats-server-stream-consumer-config]]).


## Related

[[replicas]] · [[raft-in-nats]] · [[stream]] · [[error-codes]] · [[js-api-subjects]] ·
[[stream-leader-keeps-moving]] · [[no-suitable-peers-for-placement]] ·
[[backup-and-restore-jetstream]] · [[rebalance-streams]]

## Sources

[[s-docs-placement]] · [[s-docs-raft-and-leaders]] · [[s-docs-replication-and-r3]] ·
[[s-gh-7982-no-suitable-peers]] · [[s-adr-7-server-error-codes]] · [[s-docs-scaling-and-peers]] ·
[[s-natscli-backup-restore]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]] · [[s-nats-server-stream-consumer-config]]
