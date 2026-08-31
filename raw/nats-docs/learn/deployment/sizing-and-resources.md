<!-- source: https://docs.nats.io/learn/deployment/sizing-and-resources.md · fetched 2026-08-31 · section: sizing-and-resources -->
# Sizing & resources

Topologies decided the shape: a three-node cluster called `east` (`n1-east`, `n2-east`, `n3-east`) carrying the R3 `ORDERS` stream. This chapter runs that shape for real, and running it starts with the question of how much of each resource this cluster needs.

A node spends a small, fixed set of resources, the JetStream defaults are knowable numbers, and the account limits the server enforces are readable with one command. This page turns those into a baseline for the ORDERS workload.

You'll learn two things here: the four resources a node spends (and their JetStream defaults), and how account limits count R3 replication against the storage ceiling.

## The four resources a node spends

Every NATS node spends the same four resources. Once you size each one, you've sized the node.

**CPU** handles moving messages. Core NATS routing is cheap; TLS handshakes and JetStream replication are where cycles go. There's no hard CPU limit to set, so the rule is headroom: overprovision CPU by 20–30% above steady state so a node has cycles spare for a rebalance when a peer leaves.

**Memory** holds connections, subscriptions, and (for memory-storage streams) message data. The ORDERS stream uses file storage, so its messages live on disk, not in RAM. The `order-svc` publisher and the `warehouse`, `notifications`, and `analytics` subscribers are light clients; a few hundred connections fit comfortably in a few hundred megabytes. Budget `order-svc` at roughly 128 MiB.

**Disk** holds file-storage streams. This is the resource the ORDERS stream actually spends, and the one most likely to run out. We'll size it below.

**File descriptors (FDs)** are the per-process limit on open files and sockets. Connections, routes, and streams each consume FDs. JetStream spends roughly two FDs per stream. On a small cluster the default per-process limit is plenty; on a large one it isn't, which is why the hardened service unit on the [hardening](/learn/deployment/hardening.md) page raises it to `LimitNOFILE=800000`.

### The JetStream defaults

Left unset, JetStream sizes its limits from the system it's on. **Memory storage** defaults to 75% of system RAM (capped by `GOMEMLIMIT` if set), falling back to **256 MB** only when the server can't read system memory. **File storage** defaults to 75% of the disk space actually available under `store_dir`, falling back to **1 TB** only when the platform can't report disk size (Windows and a few others, or a failed `statfs`). On a Linux container with a 10 GiB volume the file-storage default is therefore about 7.5 GiB, not 1 TB.

Because the default tracks the real disk, the container hazard isn't the default itself — it's setting `max_file_store` *larger* than the volume, or running on a shared or thin-provisioned volume where "available" disk overstates what this stream may safely use. Either way the node accepts writes it can't ultimately store, and the publish that crosses the real boundary fails. Pin `max_file_store` to what the volume can actually hold:

```
# n1-east.conf — pin JetStream storage to the real volume size

jetstream {

  store_dir:      "/var/lib/nats/jetstream"

  max_memory_store: 256MB

  max_file_store:   10GB

}
```

The ORDERS stream is an R3 file stream. At R3 it keeps three copies, one per node, so each node stores the full stream once. A 10 GiB `max_file_store` per node leaves ample room for an ORDERS stream sized to fit the default 10 GiB volume the Kubernetes chapter provisions. The Helm chart already defaults `max_file_store` to the PVC size, so on Kubernetes this pin is usually set for you.

The full set of JetStream limit keys is documented in [Reference → Configuration](/reference/config/jetstream/.md). We only cover `max_memory_store` and `max_file_store` here.

## Account limits and how replication counts

The server config sizes the *node*, while **account limits** size the *tenant*. The ORDERS account has its own ceilings (`MaxMemory`, `MaxStore`, `MaxStreams`, `MaxConsumers`), and the server enforces them no matter how much disk the node has. Read them live before you size:

#### CLI

```
#!/bin/bash

# Read the LIVE account limits for the ORDERS account before you size anything.

# This is the source of truth: it shows the tier and the ceilings the server

# will actually enforce, not what you hope the config says.

#

# Connect as order-svc in the ORDERS account, then ask the server.

nats account info \

  --server tls://nats.acme.internal:4222 \

  --creds /etc/nats/creds/order-svc.creds



# Look for these rows in the output:

#   Memory:    the MaxMemory ceiling for the account

#   Storage:   the MaxStore ceiling (file storage) for the account

#   Streams:   MaxStreams — how many streams the account may create

#   Consumers: MaxConsumers — how many consumers per stream

#

# Sizing rule: on an UN-tiered account an R3 stream counts as

# replicas x bytes against MaxStore, so a 10 GiB ORDERS stream at R3

# spends 30 GiB of the account's storage limit. A tiered account bakes

# replication into the tier, so the number you see is the usable bytes.
```

#### C

```
// Read the LIVE account limits for the ORDERS account before you

// size anything. This is the source of truth: the ceilings the

// server will actually enforce, not what you hope the config says.

if (s == NATS_OK)

    s = js_GetAccountInfo(&ai, js, NULL, &jerr);

if (s == NATS_OK)

{

    // Current usage, then the ceilings. A value of -1 means

    // unlimited.

    printf("memory used:    %" PRIu64 " bytes\n", ai->Memory);

    printf("storage used:   %" PRIu64 " bytes\n", ai->Store);

    printf("streams:        %" PRId64 "\n", ai->Streams);

    printf("consumers:      %" PRId64 "\n", ai->Consumers);

    printf("max memory:     %" PRId64 "\n", ai->Limits.MaxMemory);

    printf("max storage:    %" PRId64 "\n", ai->Limits.MaxStore);

    printf("max streams:    %" PRId64 "\n", ai->Limits.MaxStreams);

    printf("max consumers:  %" PRId64 "\n", ai->Limits.MaxConsumers);



    // Sizing rule: on an UN-tiered account an R3 stream counts as

    // replicas x bytes against max storage, so a 10 GiB ORDERS

    // stream at R3 spends 30 GiB of the account's limit. A tiered

    // account bakes replication in, so its number is usable bytes.

    if (ai->TiersLen > 0)

        printf("tiered account: %d tier(s), limits are per tier\n",

               ai->TiersLen);

}
```

One subtlety in that output decides your storage math: how replication counts against `MaxStore`. There are two cases.

On an **un-tiered** account, an R3 stream counts as `replicas × bytes`. A 10 GiB ORDERS stream at R3 spends 30 GiB of the account's `MaxStore`, because the limit measures total bytes stored across all replicas. Forget the multiplier and the third replica fails to place when the account hits its ceiling.

On a **tiered** account, replication is baked into the tier. The bytes the limit reports are the usable bytes: the R3 multiplier is already accounted for, so a 10 GiB tier holds a 10 GiB R3 stream.

The durability R3 buys (surviving the loss of a node) is the JetStream chapter's subject, covered on [Surviving node loss](/learn/jetstream/surviving-node-loss.md). Here you only need the cost: on an un-tiered account, three copies cost three times the bytes.

## Connection, subscription, and payload limits

Three more limits round out the node, and one command reads them all:

#### CLI

```
#!/bin/bash

# Read the LIVE server limits for one node of the east cluster.

# These are per-server ceilings: payload size, connection cap, and the

# JetStream memory/store limits the node was started with.

#

# `nats server info` is a system-account request, so authenticate with the

# system account's creds, not the ORDERS-account user creds.

nats server info n1-east \

  --server tls://nats.acme.internal:4222 \

  --creds /etc/nats/creds/sys.creds



# Look for these in the output:

#   Maximum Payload:     max_payload (default 1.0 MiB) — the largest single message

#   Maximum Connections: max_connections (default 64K, i.e. 65,536)

#   JetStream:           Max Memory and Max Storage configured on this node

#

# Sizing rule: max_payload must be <= max_pending. Keep max_pending at

# >= 10x your peak message size so a burst of large orders does not stall

# the connection. The ORDERS payload is well under 1 KiB, so the 1 MiB

# default has ample headroom here.
```

#### C

```
// Read the LIVE server limits for one node of the east cluster.

// There is no dedicated client API for this: it is a plain

// request on the system account's $SYS.REQ.SERVER.PING.VARZ

// subject, filtered to the n1-east node by name. The VARZ reply

// carries the per-server ceilings: max_payload (default 1 MiB),

// max_connections (default 64K), and the JetStream memory/store

// limits the node was started with.

if (s == NATS_OK)

    s = natsConnection_RequestString(&reply, conn,

            "$SYS.REQ.SERVER.PING.VARZ",

            "{\"server_name\":\"n1-east\"}", 2000);

if (s == NATS_OK)

    printf("%.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));
```

`max_connections` caps how many clients a node accepts (default 64K, i.e. 65,536; it's reloadable, and overflow disconnects immediately). `max_subscriptions` caps subscriptions per connection (default unlimited). `max_payload` caps a single message at 1 MB by default, and it must stay `≤ max_pending`. The ORDERS payload is well under a kilobyte, so the defaults have room to spare:

```
{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}
```

The full set of connection and payload keys is documented in [Reference → Configuration](/reference/config/max_payload.md). We only name the ones a sizing baseline needs here.

## Pitfalls

A few sizing mistakes only surface in production under load, where they're expensive to fix. Each is scoped to this page's two concepts: the node's resources and the account's limits.

**Setting `max_file_store` beyond the real disk.** A `max_file_store` larger than the mounted volume — or a shared or thin-provisioned volume whose "available" space the default over-reads — lets the node accept writes it can't store. The failure is a publish error mid-stream, not a startup warning. Set `max_file_store` to the volume size, test small with a `10GB` value, and watch the real disk with `df -h`. Don't trust the config number over what the device reports.

**`max_payload` larger than `max_pending`.** If `max_payload` exceeds `max_pending`, the server refuses to start. Keep `max_pending` at `≥ 10× peak message size` so a burst of large messages can't stall a connection. Don't raise `max_payload` in isolation.

**File-descriptor exhaustion on a big cluster.** Each stream costs about two FDs, and routes and gossip add more. On a large cluster the default per-process FD limit runs out, and the symptom is connection refusals that look like a network fault. Raise the limit (`ulimit -n 800000`) before the process starts; the hardened unit on the [hardening](/learn/deployment/hardening.md) page does exactly this.

**JWT account limits change only when the account JWT does.** Operator-mode accounts enforce their limits through the account JWT the resolver holds, not through server config, so raising `MaxStore` or `MaxStreams` means editing and pushing the JWT — a server reload or restart won't move them. Keep the cluster's server versions aligned as you roll upgrades so every node reads the same JWT limit fields (tiered R1/R3 limits, for instance, need servers new enough to understand them). Read the active tier with `nats account info` before you size, so you plan against the limits the cluster actually applies.

The runnable fix for all four is the same first step: read the live limits before you size, so the numbers you plan against are the numbers the server enforces.

#### CLI

```
#!/bin/bash

# Read the LIVE account limits for the ORDERS account before you size anything.

# This is the source of truth: it shows the tier and the ceilings the server

# will actually enforce, not what you hope the config says.

#

# Connect as order-svc in the ORDERS account, then ask the server.

nats account info \

  --server tls://nats.acme.internal:4222 \

  --creds /etc/nats/creds/order-svc.creds



# Look for these rows in the output:

#   Memory:    the MaxMemory ceiling for the account

#   Storage:   the MaxStore ceiling (file storage) for the account

#   Streams:   MaxStreams — how many streams the account may create

#   Consumers: MaxConsumers — how many consumers per stream

#

# Sizing rule: on an UN-tiered account an R3 stream counts as

# replicas x bytes against MaxStore, so a 10 GiB ORDERS stream at R3

# spends 30 GiB of the account's storage limit. A tiered account bakes

# replication into the tier, so the number you see is the usable bytes.
```

#### C

```
// Read the LIVE account limits for the ORDERS account before you

// size anything. This is the source of truth: the ceilings the

// server will actually enforce, not what you hope the config says.

if (s == NATS_OK)

    s = js_GetAccountInfo(&ai, js, NULL, &jerr);

if (s == NATS_OK)

{

    // Current usage, then the ceilings. A value of -1 means

    // unlimited.

    printf("memory used:    %" PRIu64 " bytes\n", ai->Memory);

    printf("storage used:   %" PRIu64 " bytes\n", ai->Store);

    printf("streams:        %" PRId64 "\n", ai->Streams);

    printf("consumers:      %" PRId64 "\n", ai->Consumers);

    printf("max memory:     %" PRId64 "\n", ai->Limits.MaxMemory);

    printf("max storage:    %" PRId64 "\n", ai->Limits.MaxStore);

    printf("max streams:    %" PRId64 "\n", ai->Limits.MaxStreams);

    printf("max consumers:  %" PRId64 "\n", ai->Limits.MaxConsumers);



    // Sizing rule: on an UN-tiered account an R3 stream counts as

    // replicas x bytes against max storage, so a 10 GiB ORDERS

    // stream at R3 spends 30 GiB of the account's limit. A tiered

    // account bakes replication in, so its number is usable bytes.

    if (ai->TiersLen > 0)

        printf("tiered account: %d tier(s), limits are per tier\n",

               ai->TiersLen);

}
```

## Where you are

You now have a sizing baseline for the ORDERS cluster:

* The four resources a node spends: CPU (20–30% headroom), memory (`order-svc` \~128 MiB), disk (`max_file_store` pinned to the volume), and FDs (two per stream).
* The JetStream defaults named (memory and file storage both default to 75% of RAM and disk; 256 MB / 1 TB are only the can't-read fallbacks) and `max_file_store` pinned to the real 10 GiB volume.
* The account limits read live with `nats account info`, and the rule that an un-tiered R3 stream costs `replicas × bytes`.

The ORDERS R3 file stream fits the default 10 GiB volume, and `order-svc` fits in \~128 MiB. That baseline is what the next page deploys.

## What's next

With the resources sized, the next page stands the cluster up: the NATS Helm chart, the StatefulSet that maps `nats-0..2` to `n1-east..n3-east`, and the NACK controller that declares the `ORDERS` stream as a CRD.

Continue to [Kubernetes](/learn/deployment/kubernetes.md).

## See also

* [Reference → Configuration](/reference/config/jetstream/.md) — every JetStream limit key and its default.
* [Reference → max\_payload](/reference/config/max_payload.md) — the payload and pending limits in full.
* [Surviving node loss](/learn/jetstream/surviving-node-loss.md) — what R3 durability buys for the bytes it costs.
