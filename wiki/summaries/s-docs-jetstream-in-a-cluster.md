---
title: "docs.nats.io — JetStream in a cluster"
type: summary
area: [topology, jetstream]
source-url: https://docs.nats.io/learn/topologies/jetstream-in-a-cluster.md
source-path: raw/nats-docs/learn/topologies/jetstream-in-a-cluster.md
author: NATS documentation (Synadia Communications, Inc.)
article: JetStream in a cluster
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [meta-group, meta-leader, raft, replicas, R3, odd-count, failure-domain, stream-find]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — JetStream in a cluster

Where the **meta group** is named and where the "a cluster does not make JetStream HA" pitfall is
stated most plainly. Also the source of two runnable audit commands this wiki had not recorded.

## Key claims

### The meta layer

"The servers elect one **meta leader**, and the meta leader owns every decision about *where* streams
and consumers live: which servers hold a new stream, which server holds each copy, and what happens
when a server disappears."

"The set of servers participating in that coordination is the **meta group**. Every JetStream-enabled
server in the cluster belongs to it."

And the separation people get wrong: "The meta leader decides where a stream lives, but it doesn't
handle the writes to it."

### Odd counts

"Three servers form a clean majority of two. Lose one server and two remain, still a majority…"

"An even count gives you no extra protection here. Two servers have no majority once one is gone, and
four tolerate the same single failure that three do while costing an extra server."

One number worth having: **"a stream keeps at most five copies, so more servers add capacity, not
more copies of one stream."**

### What `nats stream info` shows on a cluster

```
Cluster Information:

                 Name: east
        Cluster Group: S-R3F-xK2p9aLm
               Leader: n1-east
              Replica: n3-east, current, seen 0.00s ago
              Replica: n2-east, current, seen 0.00s ago
```

- `Name: east` — "Replication stays inside one cluster; it's the unit a stream is replicated across."
- `Cluster Group` — "its own Raft group, separate from the meta group. Each stream gets one."
- `Leader` — "One of the three copies takes every write to `ORDERS` first, then sends it to the other
  replicas, and the write is acknowledged only once a majority hold it."
- `current` "means a copy has recently checked in and holds the same data".
- The stream leader is "not necessarily the server coordinating the meta group. The two are chosen
  independently."

### Consumers replicate independently

"Each consumer gets its own Raft group and leader — chosen independently of the stream's, so a
consumer can lead on `n1-east` while its stream leads on `n3-east`."

"By default a consumer takes its stream's replica count… an R1 consumer on an R3 stream is its own
single point of failure: its position lives on one server, so losing that server loses the reader's
place even though the stream survives."

### The three pitfalls, and the audit that goes with them

1. **"An R1 stream on a cluster still has no HA."** "A stream created on a cluster defaults to a
   single replica unless you ask for more."
2. **"An even server count gives you no extra protection."**
3. **"All three replicas in one failure domain defeat R3."** "Spread across one rack or one
   availability zone, a single power or network event takes all three at once."

The runnable audit, which this wiki had not recorded:

```
nats stream find --replicas=1
nats stream edit <stream> --replicas=3
nats server check stream --stream=ORDERS --peer-expect=3
```

```
OK ORDERS OK:3 peers OK:0 sources | sources=0
```

"The check exits non-zero when a stream is under-replicated, so it wires straight into a health
monitor."

## Practical takeaways

- `nats stream find --replicas=1` is the one-line answer to "which of my streams silently has no
  failover", and `nats server check stream --peer-expect=3` is its alerting form.
- The stream leader, the consumer leader and the meta leader are three independent elections. A
  runbook that says "restart the leader" has to say *which* leader.
- Five is the ceiling on replicas. Servers beyond five add placement choice and capacity, not
  durability for any one stream.

## Relevance to the wiki

Confirms and adds to [[raft-in-nats]] and [[replicas]]; the audit commands belong on [[replicas]] and
[[rebalance-streams]]. The "replication stays inside one cluster" line is the constraint that makes
[[multi-region-jetstream]] a mirrors-and-sources problem rather than a replica-count one.

## Questions it answers

- **Q41** in part — why a cluster is the unit of replication, which is why the other two shapes exist.

## Pages touched

[[raft-in-nats]] · [[replicas]] · [[rebalance-streams]] · [[multi-region-jetstream]] ·
[[choosing-a-topology]] · [[nats-cli]]
