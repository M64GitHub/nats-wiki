---
title: Rebalance streams across a cluster
type: operation
kind: runbook
area: [jetstream, topology, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [peer-remove, replicas, catchup, lag, current, quorum, 10075, 10202, retire-a-node]
aliases: [rebalance, "peer-remove", "peer remove", "move a stream", "retire a node", "add a node", "scale a cluster"]
sources: [s-docs-scaling-and-peers, s-docs-placement, s-docs-rolling-upgrades, s-docs-surviving-node-loss]
created: 2026-08-31
updated: 2026-08-31
---

# Rebalance streams across a cluster

Adding a node to a cluster does **not** move any existing stream onto it. Streams are placed when
they are created, and their peer set only changes when you change it. This runbook grows a stream's
peer set, moves a replica off a server you want to retire, and — the part that actually keeps the
cluster up — makes **one change at a time** (source: [[s-docs-scaling-and-peers]]).

## Goal

A stream's replicas on the servers you intend, with a named leader and every peer `current`, at no
point below quorum.

## Preconditions

- The new server is **already a member of the cluster** — same `cluster.name`, routes formed, visible
  in `nats server list` ([[build-a-3-node-cluster]]).
- The stream you are moving has **a named leader and every existing replica `current` with zero
  lag**. Starting from a degraded group is how one change becomes an outage.
- You know whether placement (`server_tags`, cluster/tag constraints) even allows the destination —
  [[stream-placement]], [[no-suitable-peers-for-placement]].
- System-account credentials, for the `nats server` half ([[account]]).

## The two operations people confuse

> "`peer-remove` moves a replica between servers; `--replicas` sets how many replicas there are."

| you want | command | what it does |
|---|---|---|
| more (or fewer) copies | `nats stream edit ORDERS --replicas=N` | changes the replica **count**; the meta leader picks where the new one lands |
| the same copies, elsewhere | `nats stream cluster peer-remove ORDERS <server>` | evicts **one** replica from a named server; the meta leader re-places it, count unchanged |
| a server out of the **meta** group | `nats server cluster peer-remove <server>` | removes the server from JetStream's own Raft group — **one change at a time** |

## Steps

### Grow a stream's peer set

```
nats stream info ORDERS                                  # leader? all replicas current?
nats stream edit ORDERS --replicas=4
```

You do **not** name the server: the meta leader assigns the extra replica to one that qualifies under
the stream's placement, records the new peer set, and the stream's group picks it up.

**Quorum moves before the data does.** An `R=4` group commits once **three** peers hold a write, not
two — the instant the assignment lands, while the new peer is still empty. So the window right after
a grow is the *least* redundant the group has been. The new peer cannot win an election while its log
is empty, but it is counted.

### Watch the catchup

```
nats stream info ORDERS
```

```
Cluster Information:
                Name: east
              Leader: n1-east
             Replica: n2-east, current, seen 0.12s ago
             Replica: n3-east, current, seen 0.20s ago
             Replica: n4-east, outdated, seen 0.18s ago, 14,231 operations behind
```

`outdated` plus an operations-behind count **is** catchup in progress: the leader is feeding the peer
the log from where it is short. **Do not treat the new peer as a working replica until it reads
`current` with zero lag** — until then only the peers that already hold the data can serve it.

### Move a replica off a server

```
nats stream cluster peer-remove ORDERS n4-east
nats stream info ORDERS          # verify before anything else
```

The meta leader picks a replacement server, updates the assignment, and the evicted server drops its
Raft subscriptions for that group. If the evicted peer held leadership, the group elects a new leader
first, so leadership lands on a peer that stays.

**If no other server qualifies, an R>1 stream still loses the peer.** The server evicts it and
returns

```
peer remap failed
```

— error **10075** `JSPeerRemapErr` (503, [[error-codes]]) — leaving the group **a replica short**.
The error is about the replacement, not the removal: the removal already happened.

### Retire a server completely

1. Move every stream's replica off it, one `peer-remove` at a time, verifying between each.
2. Then remove it from the meta group:

```
nats server cluster peer-remove n4-east
```

That command allows **only one change at a time** — ask for a second while one is in flight and it
answers `cluster member change is in progress`, error **10202**
`JSClusterServerMemberChangeInflightErr` (400).

3. Then stop the server ([[upgrade-a-cluster]]'s drain applies: `systemctl stop` on the shipped unit
   is a lame-duck drain).

## Verify

After **every single change**, re-read the group and confirm three things:

```
nats stream info ORDERS
```

- the server you evicted is **gone** from the `Replicas` list;
- there is still a **named `Leader`**;
- the replacement is catching up, and **reaches lag 0**.

> "If that second `stream info` shows `no leader`, stop. You've lost quorum, and the fix is to
> restore a peer, not make another change."

Cluster-wide, `nats server report jetstream` shows where assets sit per server — the view to use when
rebalancing more than one stream.

## Rollback

**There is no undo for a `peer-remove`** — there is only another change, and another change is
exactly what you must not make while the group is short. The recovery for a group left a replica
short by `peer remap failed` is to **fix placement first** (add a qualifying server, or correct
`server_tags`), then re-add the replica with `--replicas`.

A stream that has lost quorum cannot be repaired by peer commands at all; that is a restore
([[backup-and-restore-jetstream]]) or a meta-layer recovery question.

## Pitfalls

**Adding a node rebalances nothing.** New streams may land on it, according to placement; existing
ones stay where they are. If the reason you added the node was load, you must move the load.

**Do not stack membership changes.** A `peer-remove` evicts a healthy replica and its replacement
starts empty. Fire a second change before that replacement is `current` and you can drop the peers
that actually hold the data below the majority the group needs — and it stops committing.

**A freshly added peer is not a working replica.** Kill another server mid-catchup and you can stall
the group even though the peer *count* looks right.

**`--force` on the last peer does not move the data.** The CLI refuses without it —
`removing the only peer on a stream will result in data loss` — and even forced, there is nowhere to
re-place the replica, so the server answers `peer remap failed` rather than brick the stream. Change
the replica *count* with `nats stream edit --replicas` instead.

**Do not rebalance during a rolling upgrade or a config reload.** All three are cluster-state
changes; run them one at a time ([[upgrade-a-cluster]], [[reload-server-config]]).

**Consumers have their own replica rules.** Moving a stream's peers is not the whole story for what
your consumers do afterwards — [[consumer]], [[replicas]].

## Related

[[build-a-3-node-cluster]] · [[upgrade-a-cluster]] · [[reload-server-config]] · [[replicas]] ·
[[raft-in-nats]] · [[stream-placement]] · [[no-suitable-peers-for-placement]] · [[error-codes]] ·
[[jetstream-sizing]] · [[backup-and-restore-jetstream]] · [[nats-cli]]

## Sources

[[s-docs-scaling-and-peers]] · [[s-docs-placement]] · [[s-docs-rolling-upgrades]] ·
[[s-docs-surviving-node-loss]]
