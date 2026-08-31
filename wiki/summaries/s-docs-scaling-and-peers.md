---
title: "docs.nats.io — Scaling and peer management"
type: summary
area: [topology, jetstream, deploy]
source-url: https://docs.nats.io/learn/clustering/scaling-and-peers.md
source-path: raw/nats-docs/learn/clustering/scaling-and-peers.md
author: NATS documentation (Synadia Communications, Inc.)
article: Scaling and peer management
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [peer-remove, replicas, catchup, lag, current, outdated, quorum, 10075, 10202]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Scaling and peer management

Changing the membership of a live Raft group: grow it by raising `--replicas`, move a replica off a
server with `peer-remove`, and — the part that matters — make **one change at a time**. The only
source that distinguishes the two operations people confuse.

## Key claims

**Grow a group by raising the replica count. You do not name the server:**

```
nats --server nats://127.0.0.1:4222 stream edit ORDERS --replicas=4
```

> "The meta leader assigns the extra replica to a server that qualifies under the stream's placement
> …, records the new peer set in its assignment log, and the `ORDERS` group picks it up."

**A new peer counts for quorum immediately and holds no data.**

> "Adding the peer changes the quorum right away: an `R=4` group commits once **three** peers hold a
> write, not two. What the new peer can't do while its log is empty is **win an election** — it stays
> an observer until the leader's first entries reach it."

**Catchup is visible in `nats stream info`:**

```
Cluster Information:
                Name: east
              Leader: n1-east
             Replica: n2-east, current, seen 0.12s ago
             Replica: n3-east, current, seen 0.20s ago
             Replica: n4-east, outdated, seen 0.18s ago, 14,231 operations behind
```

> "`outdated` and the operations-behind count are catchup in progress." Lag is "just a count: how
> many entries behind the leader's log the peer still is."

**`peer-remove` moves a replica; it does not shrink the stream.**

```
nats --server nats://127.0.0.1:4222 stream cluster peer-remove ORDERS n4-east
```

> "it evicts the replica from the named server, and the meta leader **re-places it on another server
> that qualifies**, so `ORDERS` stays at its replica count."

**And when there is nowhere to re-place it:**

> "If no other server qualifies — placement leaves nowhere to put the replica — **an R>1 stream still
> loses the peer**: the server evicts it and returns `peer remap failed`, leaving the group a replica
> short. Only a single-replica stream is spared."

(`peer remap failed` is error **10075** `JSPeerRemapErr`, HTTP 503 —
`raw/nats-docs/reference/jetstream/errors.md:30`.)

**The two commands people confuse, in the page's own words:**

> "`peer-remove` moves a replica between servers; `--replicas` sets how many replicas there are."

**A third command exists for the meta group**, and it serialises:

> "Removing a server from the JetStream **meta** group is a different command,
> `nats server cluster peer-remove`, and that one allows only one change at a time: ask for a second
> while one is in flight and it answers `cluster member change is in progress`."

(Error **10202** `JSClusterServerMemberChangeInflightErr`, HTTP 400 — same reference file, line 57.)

**Three pitfalls:**

1. **"Don't stack membership changes before the replacement catches up."** "Fire a second change …
   before that replacement is `current`, and you can drop the number of peers holding the data below
   the majority the group needs, and it stops committing."
   > "If that second `stream info` shows `no leader`, stop. You've lost quorum, and the fix is to
   > restore a peer, not make another change."
2. **"A freshly added peer isn't safe until its lag is zero."** "Kill another server mid-catchup and
   you can drop below the peers that actually hold the data and stall the group."
3. **"Removing the only peer needs `--force`, and forcing it doesn't move the data."** The CLI
   refuses without `--force` (`removing the only peer on a stream will result in data loss`), and
   even forced "the server refuses to drop it and answers `peer remap failed` rather than brick the
   stream".

## Practical takeaways

- **Quorum moves before data does.** Raising `--replicas` changes the majority arithmetic the instant
  the assignment lands, while the new peer is still empty — so the window right after a grow is the
  *least* redundant the group has been, not the most.
- **`current` with zero lag is the only safe gate**, and it is the same gate the rolling-upgrade
  procedure uses ([[s-docs-rolling-upgrades]]). One rule covers both operations.
- **`peer remap failed` is not a refusal.** For an R>1 stream the peer is evicted anyway and the group
  is left short — the error tells you the *replacement* failed, after the removal already happened.
- **Two `peer-remove` commands, two scopes.** `nats stream cluster peer-remove` moves one stream's
  replica; `nats server cluster peer-remove` removes a server from the meta group, one at a time.

## Notable quotes

> "Make one change, wait for a named leader and a caught-up replacement, then the next."

> "`peer-remove` moves a replica between servers; `--replicas` sets how many replicas there are."

## Relevance to the wiki

The whole of [[rebalance-streams]], and the peer-set half of what an operator does after adding a
node in [[build-a-3-node-cluster]].

## Questions it answers

**Q34** (rebalancing streams after adding nodes).

## Pages touched

[[rebalance-streams]] · [[replicas]] · [[raft-in-nats]] · [[stream-placement]] · [[error-codes]] ·
[[upgrade-a-cluster]] · [[build-a-3-node-cluster]]
