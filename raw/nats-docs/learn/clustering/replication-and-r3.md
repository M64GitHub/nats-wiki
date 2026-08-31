<!-- source: https://docs.nats.io/learn/clustering/replication-and-r3.md · fetched 2026-08-31 · section: replication-and-r3 -->
# Replication and R=3

The last page elected leaders, so the cluster now has a meta leader and, once you create a stream, a leader for that stream's RAFT group. This page uses those leaders: it follows a single order from `order-svc` into the `ORDERS` stream and shows exactly when that write becomes safe to lose a server over.

The [surviving node loss](/learn/jetstream/surviving-node-loss.md) page in the JetStream chapter gave you the one-line version: `R=3` keeps three copies, so the loss of one server costs nothing. This page explains the mechanism behind that guarantee. It introduces two ideas: **quorum commit**, how the leader turns one write into a committed entry across the group, and the **consistency** you get back from it. It also covers a narrower gap worth knowing before you rely on either: what quorum commit does, and doesn't, guarantee once the write reaches disk.

## R=3 means three peers in one RAFT group

A stream's replica count is the number of copies the cluster keeps. `R=3` keeps three. Each copy lives on a different server, and the three servers holding the copies form a single RAFT group, the same kind of consensus group the last page elected a leader for.

You set the count when you create the stream. On the `east` cluster, one flag turns the single-server `ORDERS` of the JetStream chapter into a three-peer stream. (If you ran the election exercise on [Raft and leaders](/learn/clustering/raft-and-leaders.md), `ORDERS` already runs at `R=3`; restart any server you stopped there, and read this as the create that stood it up.)

#### CLI

```
#!/bin/bash

# Create the ORDERS stream as an R=3 stream on the `east` cluster, then publish

# one order and read back which server leads the stream and which servers hold

# the copies.

#

# This assumes the three `east` servers from the Topologies chapter are running,

# each with JetStream enabled:

#   nats-server -c n1-east.conf

#   nats-server -c n2-east.conf

#   nats-server -c n3-east.conf

#

# Point the CLI at any server in the cluster. The cluster routes the request to

# the stream leader wherever it currently lives.

export NATS_URL="nats://127.0.0.1:4222,nats://127.0.0.1:4223,nats://127.0.0.1:4224"



# Create ORDERS with three replicas. --replicas=3 is the only line that differs

# from the single-server create in the JetStream chapter. If ORDERS already

# exists at R=1, raise it instead: nats stream edit ORDERS --replicas=3

nats stream add ORDERS \

  --subjects "orders.>" \

  --replicas=3 \

  --defaults



# Publish one order as order-svc would. --jetstream makes this a JetStream

# publish that waits for a PubAck; the PubAck returns only after the leader

# has the write committed to a quorum (itself plus one follower). Plain

# `nats pub` is a core publish and would not wait for one.

nats pub --jetstream orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Confirm the replica count and the cluster layout that R=3 produced.

nats stream info ORDERS



# Expected Cluster Information section:

#

# Cluster Information:

#

#                  Name: east

#         Cluster Group: S-R3F-xK2p9aLm

#                Leader: n1-east

#               Replica: n2-east, current, seen 0.00s ago

#               Replica: n3-east, current, seen 0.00s ago
```

#### C

```
// Create ORDERS with three replicas. Replicas=3 is the only line

// that differs from the single-server create in the JetStream

// chapter. If ORDERS already exists at R=1, raise it in place with

// js_UpdateStream instead.

jsStreamConfig  cfg;

const char      *subjects[] = {"orders.>"};

jsPubAck        *pa         = NULL;



jsStreamConfig_Init(&cfg);

cfg.Name        = "ORDERS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;

cfg.Replicas    = 3;



s = js_AddStream(NULL, js, &cfg, NULL, &jerr);

if (jerr == JSStreamNameExistErr)

    s = js_UpdateStream(NULL, js, &cfg, NULL, &jerr);



// Publish one order as order-svc would. A JetStream publish waits

// for a PubAck; the PubAck returns only after the leader has the

// write committed to a quorum (itself plus one follower). A core

// publish (natsConnection_Publish) would not wait for one.

const char *order =

    "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";



if (s == NATS_OK)

    s = js_Publish(&pa, js, "orders.created",

                   order, (int) strlen(order), NULL, &jerr);

if (s == NATS_OK)

{

    printf("Stored in %s, sequence %" PRIu64 "\n",

           pa->Stream, pa->Sequence);

    jsPubAck_Destroy(pa);

}



// Confirm the replica count and the cluster layout that R=3

// produced: one leader and two follower replicas, each on its own

// server of the east cluster.

if (s == NATS_OK)

    s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if ((s == NATS_OK) && (si->Cluster != NULL))

{

    printf("Cluster: %s, leader: %s\n",

           si->Cluster->Name, si->Cluster->Leader);

    for (i = 0; i < si->Cluster->ReplicasLen; i++)

    {

        jsPeerInfo *peer = si->Cluster->Replicas[i];



        printf("Replica: %s, %s, seen %.2fs ago\n",

               peer->Name,

               peer->Current ? "current" : "outdated",

               (double) peer->Active / 1E9);

    }

}
```

`--replicas=3` is the whole change. Starting from the JetStream chapter's `R=1` stream instead, raise it in place with `nats stream edit ORDERS --replicas=3`. The application code doesn't move: `order-svc` publishes the same payload to the same subject whether the stream is `R=1` or `R=3`.

```
{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}
```

What changes is underneath. The stream now has a **leader** (one of the three peers — the meta leader picks which, and an election may have moved it) and two **followers**. Every write goes through the leader. The followers never take writes directly; they receive them from the leader.

Three is the minimum for production, and a stream supports at most `R=5`. The reasoning for *which* odd count to choose belongs to [surviving node loss](/learn/jetstream/surviving-node-loss.md). Here we follow what one write does once the count is three.

## A write commits by quorum

When `order-svc` publishes `orders.created`, the message reaches the stream leader, `n1-east`. The leader does not return success on storing it locally; it runs a short sequence first.

The leader **appends** the write to its own log: an ordered, append-only record of every operation the group has agreed on. Appending is local and not yet durable across the group: only `n1-east` has the entry so far.

The leader then sends an **append entry** to each follower: the replication message that says "add this entry to your log at this position." `n2-east` and `n3-east` receive it, write it to their own logs, and reply with an ack.

The leader counts acks. A write is **committed** once a **quorum**, a majority of the peers, holds the entry. For `R=3`, a quorum is two of three. The leader is itself one of the two, so it needs just one follower's ack to reach quorum. The instant the first follower acks, the entry is committed.

Commit is the point at which durability is reached. A committed entry survives the loss of any single server, because it already lives on a majority. This is what makes the `PubAck` that `order-svc` receives a real guarantee: the leader returns it only after the write commits, so a `PubAck` means the order already survived the chance of a single-node failure before you heard back.

The third peer isn't on the critical path. `n3-east` may ack a moment later, or be briefly behind; the write committed without waiting for it. That's the point of a quorum: the group makes progress as long as a majority is reachable, even if not all peers are.

## Followers apply what the leader commits

Committing records that a quorum *has* the entry. It doesn't yet put the order into each peer's copy of the stream. That last step is **apply**: copying a committed entry from the log into the stream store, where consumers can read it.

The leader tracks a **commit index**, the position up to which entries are committed. It is included on the next append entry or heartbeat, so followers learn "everything up to here is committed; apply it." Each follower then applies those entries to its own stream store in the same order the leader did.

Order is what the group guarantees here. Every peer applies the same entries in the same sequence, so all three copies of `ORDERS` converge on the identical message log. A follower can lag the leader by a few entries, but it never reorders them and never skips one.

Here's one write from `order-svc` moving through that whole sequence (publish, append entry, ack, commit at quorum, apply):

**Message flow — A write commits by quorum (animated):** One write through an R=3 stream group. order-svc publishes orders.created to the leader n1-east, which appends the entry to its own log (write WAL) and sends an AppendEntry to the two followers n2-east and n3-east. Each follower writes the entry and replies with an ack. The write commits the instant a quorum — the leader plus one follower — holds it, so the PubAck can return; the third peer applies the entry a moment later. Every peer applies committed entries in the same order, so all three copies converge on the identical log.

* order-svc → n1-east (leader)
* n1-east (leader) → n1-east (leader) (subject: write WAL)
* n1-east (leader) → n2-east
* n1-east (leader) → n3-east (subject: AppendEntry)

You'll find the full set of RAFT replication parameters (append-entry batching, heartbeat intervals, log compaction) in [Reference](/reference/system/monitor/raftz.md). All you need here is the append → quorum → commit → apply shape.

## The consistency you get

Quorum commit gives a specific, nameable consistency, and you should know its boundaries before you build on it.

Reads from the leader are read-after-write. The leader holds every committed entry and assigns every sequence number, so once a `PubAck` returns, a read from the leader sees that order. There's no window where your own just-acked write is missing.

Reads from a follower can lag. A follower applies committed entries slightly after the leader does, so a direct read from `n2-east` or `n3-east` might not yet show the most recent order, even though that order is already committed and safe. The data is correct but slightly behind. For read-after-write, read from the leader.

This is the trade `R=3` makes on purpose. Rather than promising that every copy is identical at every instant, it promises that every copy *converges*, in order, and that a committed write survives one server loss. When you need to confirm where the copies actually stand, the `Cluster` block of `nats stream info` reports each replica's status and how far behind it is, which is exactly the first trap under Pitfalls, below.

## Syncing data to disk

Quorum commit protects against losing a server, not against losing a server's disk. For file storage, applying a committed entry writes it to disk — but JetStream doesn't `fsync` every write immediately. It batches disk syncs on a timer, `sync_interval`, which defaults to 2 minutes. Until the next sync, an applied write can sit in the OS's write cache without reaching physical disk.

That gap means a `PubAck` only confirms quorum; the disk sync still happens later, on the next timer tick. Two peers can hold a write in memory and still lose it if the underlying hardware fails before either one's next sync:

* Multiple peers suffer an OS failure within the same `sync_interval` window, before any of them synced the write.
* A peer that lost unsynced data in an OS crash rejoins the group and, together with a peer that never held the write, reaches a new quorum — one that never saw it.

A shorter `sync_interval` narrows this window, at the cost of write throughput. Setting it to `always` closes the window entirely: every write syncs to disk before the leader returns its `PubAck`. Combined with peers spread across availability zones, `always` gives you the strongest durability guarantee available, at the cost of the slowest writes.

The 2-minute default balances that risk against performance for a typical production deployment spread across multiple availability zones. Here's how narrow the failure window actually is. Take `ORDERS` at `R=3`, its three peers spread across three zones. For its log to diverge, all of this has to happen, in order:

* One of the three peers is already offline, isolated, or partitioned, and never gets the write.
* A second peer's OS crashes and loses the write: it was one of only two peers holding it, and neither had synced yet.
* The leader — the third peer, the one that did have the write — goes down or gets isolated too.
* The offline peer reconnects, but the leader isn't reachable anymore.
* The crashed peer comes back and reaches the reconnected peer, but not the leader.

Now two peers are up, neither holding the write, and together they form a new quorum. They start accepting new writes, silently dropping some of what the old leader had acked.

This is a real way for a stream's log to diverge, but it takes several independent faults landing in exactly this order, across separate availability zones.

One mitigation: keep the crashed server offline instead of restarting it right away. A NATS server rejoins its cluster automatically on restart, so the safeguard is in when you restart it — wait until `nats stream info` shows the remaining peers are fully caught up before bringing it back. Or remove the crashed peer and let it rejoin as a wiped, empty peer that resyncs over the network — safer, though expensive if there's a lot of data to resync.

If minimizing loss matters more than throughput, use `sync_interval: always`. It costs performance cluster-wide, even for streams that don't need the extra durability, so weigh it against your own durability, cost, and performance requirements before you turn it on everywhere.

You don't have to pick one setting for the whole deployment. Run most clusters on the default `sync_interval`, and add a separate cluster tagged for `sync_interval: always`. Then place only the streams that need the strongest durability there, using [placement tags](/learn/clustering/placement.md).

```
# Configure a cluster that's dedicated to always sync writes.

server_tags: ["sync:always"]



jetstream {

    sync_interval: always

}
```

Create a replicated stream pinned to that cluster, so only the writes that need this level of durability pay for it.

```
nats stream add --replicas 3 --tag sync:always
```

## Pitfalls

These are three common mistakes the first time you trust a replicated stream.

**`R=1` has no copy.** A stream at `R=1` lives on exactly one server. There's no second peer, so there's no quorum and nothing to commit *to* beyond the one log. If that server's disk is lost, the order is lost too, with no failover and no recovery. Only `R≥3` survives a node loss. Don't run real orders at `R=1`; the why-three reasoning is covered on [surviving node loss](/learn/jetstream/surviving-node-loss.md).

**A follower may lag, so a follower read can be stale.** A committed write is safe, but it reaches each follower's stream store slightly after the leader applies it. A direct read aimed at a follower can therefore return data that's correct but not the newest. Don't assume any peer is current just because the write was acked. For read-after-write, read from the leader.

Check the leader and each replica's lag when you need to know how far behind the group's followers are running, not as a way to decide whether a particular read is fresh:

#### CLI

```
#!/bin/bash

# Read the Cluster block of `nats stream info` to check that every copy of

# ORDERS is current before trusting the stream. This is the handling step for

# the "a replica may lag" pitfall: do not assume all three copies hold the same

# data — read the lag and confirm it.

#

# Assumes the `east` cluster is running and ORDERS is an R=3 stream (see

# createR3.sh). Point the CLI at any server in the cluster.

export NATS_URL="nats://127.0.0.1:4222,nats://127.0.0.1:4223,nats://127.0.0.1:4224"



# Ask the cluster who leads ORDERS and how its followers are doing. The Cluster

# Information block names the LEADER (every write lands there) and lists each

# Replica with its status.

nats stream info ORDERS



# Read the Cluster Information section carefully:

#

# Cluster Information:

#

#                  Name: east

#         Cluster Group: S-R3F-xK2p9aLm

#                Leader: n1-east

#               Replica: n2-east, current, seen 0.00s ago

#               Replica: n3-east, current, seen 0.00s ago

#

# "current" means the follower has applied every committed entry — it is up to

# date with the leader. A healthy R=3 stream shows every Replica "current" with

# a small "seen" age.

#

# A follower that is catching up shows "outdated" and a non-zero lag instead:

#

#               Replica: n3-east, outdated, seen 0.12s ago, 4,512 operations behind

#

# If a replica is outdated, do not treat it as a current copy. Read from the

# leader for read-after-write, and wait for "current" before trusting that copy

# to survive a node loss. A persistent lag points at a slow disk or a saturated

# route between peers.
```

#### C

```
// Ask the cluster who leads ORDERS and how its followers are

// doing. The Cluster info names the leader (every write lands

// there) and lists each replica with its status.

s = js_GetStreamInfo(&si, js, "ORDERS", NULL, &jerr);

if ((s == NATS_OK) && (si->Cluster != NULL))

{

    bool allCurrent = true;



    printf("Cluster: %s, leader: %s\n",

           si->Cluster->Name, si->Cluster->Leader);



    for (i = 0; i < si->Cluster->ReplicasLen; i++)

    {

        jsPeerInfo *peer = si->Cluster->Replicas[i];



        // Current means the follower has applied every committed

        // entry — it is up to date with the leader. A follower

        // that is catching up shows Current false and a non-zero

        // Lag (in operations) instead. Active is how long ago the

        // leader last heard from it.

        printf("Replica: %s, %s, seen %.2fs ago",

               peer->Name,

               peer->Current ? "current" : "outdated",

               (double) peer->Active / 1E9);

        if (peer->Lag > 0)

            printf(", %" PRIu64 " operations behind", peer->Lag);

        printf("\n");



        if (!peer->Current)

            allCurrent = false;

    }



    // A healthy R=3 stream shows every replica current with a

    // small seen age. If a replica is outdated, do not treat it as

    // a current copy: read from the leader for read-after-write,

    // and wait for current before trusting that copy to survive a

    // node loss. A persistent lag points at a slow disk or a

    // saturated route between peers.

    if (allCurrent)

        printf("All replicas current\n");

    else

        printf("A replica is catching up — wait before leaning on it\n");

}
```

**A `PubAck` proves quorum, not full replication.** The leader returns the `PubAck` the instant a quorum holds the entry: for `R=3`, the leader plus one follower. The third peer may still be catching up at that moment. That's correct and safe: the write already survives one node loss. But don't read a `PubAck` as "all three copies are identical right now." If you need every copy current (say, before deliberately taking a server down), verify each replica shows `current` in `nats stream info` first.

## Where you are

The `ORDERS` stream now runs `R=3` on the `east` cluster: a leader on one of `n1-east`, `n2-east`, or `n3-east` and followers on the other two, all carrying the same order log.

What changed is your model of a write:

* A write appends to the leader's log, replicates as an append entry to followers, and commits once a quorum holds it: two of three for `R=3`.
* Followers apply committed entries in order, so all three copies converge on the identical log.
* A `PubAck` means the order survived the loss of one server before you heard back.
* Read-after-write comes from the leader; follower reads may lag.

## What's next

The stream is replicated, but the cluster chose *where* its three copies landed. The next page makes that choice yours: placement constrains a stream's replicas to a cluster and to servers carrying matching tags, and lets you ask a chosen server to take leadership.

Continue to [Placement](/learn/clustering/placement.md).

## See also

* [Surviving node loss](/learn/jetstream/surviving-node-loss.md) — the one-page operator intro to `R=3` and storage durability.
* [Reference → Stream Configuration](/reference/jetstream/api/stream/.md) — the full `StreamConfig`, including every replica option.
* [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md) — copying a stream's data on purpose, across clusters and for DR.
