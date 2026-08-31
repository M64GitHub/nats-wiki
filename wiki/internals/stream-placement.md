---
title: Stream placement
type: internals
area: [topology, jetstream, deploy]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [placement, server_tags, no-suitable-peers, 10005, meta-leader]
aliases: [placement, server_tags, tags, "no suitable peers for placement"]
sources: [s-docs-placement, s-docs-raft-and-leaders, s-docs-replication-and-r3, s-gh-7982-no-suitable-peers]
created: 2026-08-31
updated: 2026-08-31
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
`JSClusterNoPeersErrF` in `reference/jetstream/errors.md`; see [[error-codes]].

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

- `nats stream cluster step-down --preferred <server>` requires **nats-server 2.11 or newer**.

## To verify

- The docs reference `reference/config/server_tags.md` and a meta API for assignment; neither has
  been ingested, so per-account placement limits and the full placement field set are not stated
  here.
- Cross-cluster placement (pinning a stream to one cluster in a supercluster) is out of scope of the
  ingested source, which covers only the single-cluster tag case.

## Related

[[replicas]] · [[raft-in-nats]] · [[stream]] · [[error-codes]] · [[js-api-subjects]] ·
[[stream-leader-keeps-moving]] · [[no-suitable-peers-for-placement]]

## Sources

[[s-docs-placement]] · [[s-docs-raft-and-leaders]] · [[s-docs-replication-and-r3]] ·
[[s-gh-7982-no-suitable-peers]]
