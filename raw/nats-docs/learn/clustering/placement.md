<!-- source: https://docs.nats.io/learn/clustering/placement.md · fetched 2026-08-31 · section: placement -->
# Placement

By now the `ORDERS` stream runs `R=3` on the `east` cluster, and the meta leader chose which three servers hold it. So far you haven't had a say in that choice: the meta leader picked any three servers with room.

This page lets you control that choice. It constrains *where* a stream's replicas land: onto a named cluster, or onto servers carrying labels you assign. Two concepts do all the work, and nothing here changes the payload `order-svc` publishes or the subjects it uses.

## Placement constrains which servers hold the replicas

**Placement** is a rule attached to a stream that limits which servers may hold its replicas. Without it, the meta leader is free to put the three copies of `ORDERS` on any servers in `east` that have capacity. With it, the meta leader must honor your constraint or refuse to create the stream.

Placement has two levers. The first is the **cluster**: name a cluster and every replica must live there. In a single cluster like `east` this is a no-op, since there's only one cluster to choose. It's useful across clusters, where a stream is pinned to one region; that cross-cluster case is covered in [Super-clusters](/learn/topologies/super-clusters.md), not here.

The second lever is the one that matters inside `east`, namely **tags**.

## Tags label servers; placement matches them

A **tag** is a label you attach to a server in its configuration. The server advertises its tags to the rest of the cluster, and placement uses them to pick servers. A tag is freeform text: a region, a disk class, a hardware tier, whatever distinction you want placement to respect.

You set tags with `server_tags` in each server's config. Give the three production servers a region tag and a disk-class tag:

```
# n1-east.conf — tag this server for placement

server_name: n1-east

listen: "0.0.0.0:4222"



server_tags: ["region:us-east", "disk:ssd"]



cluster {

  name: east

  listen: "0.0.0.0:6222"

  routes: [

    "nats://127.0.0.1:6223"

    "nats://127.0.0.1:6224"

  ]

}



jetstream { store_dir: "/data/n1-east" }
```

Repeat the same `server_tags` line on `n2-east` and `n3-east`, keeping their own `server_name`, ports, and `store_dir`. After a restart, confirm a server actually carries the tags you expect. `nats server info` queries the system account (`$SYS`), so connect with a system user (see [Forming a cluster](/learn/clustering/forming-a-cluster.md)); name the server you mean, or the command answers for whichever server replies to the `$SYS` ping first:

```
nats server info n1-east
```

The `Tags` line in the output lists the server's tags. Read them back rather than assuming the config took. A typo in `server_tags` is silent until a placement asks for a tag no server advertises.

### Placing the stream on tagged servers

With the servers tagged, constrain `ORDERS` to land only on servers carrying both `region:us-east` and `disk:ssd`. The CLI flag is `--tag`, passed once per required tag; the client libraries set `Placement.Tags` to a list. The example also names the cluster with `--cluster east`, a no-op in a single cluster, shown so the syntax is familiar when you place across clusters later:

#### CLI

```
#!/bin/bash



# Place the ORDERS stream on servers carrying specific tags.

#

# This assumes the 3-node "east" cluster is running with JetStream

# enabled, and that n1-east, n2-east, n3-east each advertise the tags

# region:us-east and disk:ssd via server_tags in their config. See the

# server config block on the placement page for the tag setup.



# Create ORDERS at R=3, constrained to servers carrying BOTH tags.

# --tag is passed once per required tag; the match is an intersection,

# so every listed tag must be present on a server for it to qualify.

# Tag matching folds case (ssd == SSD) but spelling is exact.

#

# --cluster names the cluster every replica must live in. In a single

# cluster like "east" it is a no-op (there is only one cluster), but it

# is shown here so the syntax is familiar when you place across clusters

# later. The match is an intersection of cluster AND tags.

nats --server nats://127.0.0.1:4222 stream add ORDERS \

  --subjects "orders.>" \

  --replicas 3 \

  --cluster east \

  --tag region:us-east \

  --tag disk:ssd \

  --defaults



# If ORDERS already exists, change its placement instead of recreating

# it. The same flags apply on edit; the meta leader re-assigns the

# replicas to servers matching the new constraint.

#

#   nats --server nats://127.0.0.1:4222 stream edit ORDERS \

#     --cluster east --tag region:us-east --tag disk:ssd



# Read the result. The Cluster block names the leader and the two other

# peers — every one of them is a server you tagged.

nats --server nats://127.0.0.1:4222 stream info ORDERS



# Publish the canonical order to confirm the placed stream accepts

# writes exactly as before — placement changes where, not what.

nats --server nats://127.0.0.1:4222 pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### C

```
// Create ORDERS at R=3, constrained to servers carrying BOTH tags.

// Placement.Tags is a list and the match is an intersection: every

// listed tag must be present on a server for it to qualify. Tag

// matching folds case (ssd == SSD) but spelling is exact.

//

// Placement.Cluster names the cluster every replica must live in.

// In a single cluster like "east" it is a no-op (there is only one

// cluster), but it is shown here so the syntax is familiar when you

// place across clusters later. The match is an intersection of

// cluster AND tags.

jsStreamConfig  cfg;

jsPlacement     placement;

const char      *subjects[] = {"orders.>"};

const char      *tags[]     = {"region:us-east", "disk:ssd"};



jsPlacement_Init(&placement);

placement.Cluster = "east";

placement.Tags    = tags;

placement.TagsLen = 2;



jsStreamConfig_Init(&cfg);

cfg.Name        = "ORDERS";

cfg.Subjects    = subjects;

cfg.SubjectsLen = 1;

cfg.Replicas    = 3;

cfg.Placement   = &placement;



s = js_AddStream(&si, js, &cfg, NULL, &jerr);

if (jerr == JSStreamNameExistErr)

{

    // ORDERS already exists: change its placement instead of

    // recreating it. The same config applies on update; the meta

    // leader re-assigns the replicas to servers matching the new

    // constraint.

    s = js_UpdateStream(&si, js, &cfg, NULL, &jerr);

}



// Read the result. The Cluster block names the leader and the two

// other peers — every one of them is a server you tagged.

if ((s == NATS_OK) && (si->Cluster != NULL))

{

    printf("Cluster: %s, leader: %s\n",

           si->Cluster->Name, si->Cluster->Leader);

    for (i = 0; i < si->Cluster->ReplicasLen; i++)

        printf("Replica: %s\n", si->Cluster->Replicas[i]->Name);

}



// Publish the canonical order to confirm the placed stream accepts

// writes exactly as before — placement changes where, not what.

if (s == NATS_OK)

    s = natsConnection_PublishString(conn, "orders.created",

            "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

            "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}");
```

The meta leader now picks three servers that carry *both* tags. Read the result in the `Cluster` block of `nats stream info ORDERS`: the leader and the two other peers are all servers you tagged.

## Tag matching is an intersection

When placement lists more than one tag, a server qualifies only if it carries *every* tag in the list. The match is an intersection, not a union: `region:us-east` **and** `disk:ssd`, never either-or.

The match folds case: `disk:ssd`, `disk:SSD`, and `disk:Ssd` are the same tag. Spelling, though, is exact, so `disk:sdd` matches nothing. The problem to watch for is typos rather than case. Ask for a tag that no server carries (a misspelling, or a tag you meant to add but didn't) and the intersection is empty. No server qualifies, and the meta leader refuses the stream. The error names the tag no server carried, in brackets:

```
nats: error: could not create Stream: no suitable peers for placement, tags not matched ['disk:sdd'] (10005)
```

The same error appears if you ask for three replicas but only two servers carry the required tags. Placement doesn't relax the constraint to fit the replica count; it fails so you notice.

The full set of placement and server-tag options is documented in [Reference](/reference/config/server_tags.md). We only need the cluster constraint and the tag intersection here.

## Asking a chosen server to lead

Placement decides which servers hold the replicas. It does not decide which of them leads. When you create a placed stream, the meta leader picks the initial leader itself, and there's no placement field that names one: set a `preferred` server in a stream's placement and the server rejects the config with `preferred server not permitted in placement`. No client library exposes such a field either — `Placement` carries only a cluster and tags.

What you can do is ask the current leader to hand off to a named peer once the group is running. That's a **stepdown** request with a preferred target:

```
nats stream cluster step-down ORDERS --preferred n2-east
```

The leader yields and the group runs an election that tries to place the new leader on `n2-east`. It's a request, not a lock: the quorum election still decides, so read `nats stream info ORDERS` afterward to see who won. `--preferred` needs NATS Server 2.11 or newer. Its full syntax lives in [Reference](/reference/jetstream/api/stream/.md).

## Pitfalls

Two mistakes are common the first time you place a stream. Both come from treating placement as more forgiving than it is.

**Tags are an intersection; a missing tag fails the placement.** Asking for a tag no server carries leaves the meta leader with nothing to pick: the stream fails with `no suitable peers for placement` rather than falling back to any server. Matching folds case, so `ssd` and `SSD` are the same tag, but spelling is exact — `sdd` matches nothing. Don't guess at tag spelling. Read the tags back from the servers first, then place against exactly what they advertise.

Verify the tags exist before you trust a placement, and watch the placement either succeed or name the missing tag:

#### CLI

```
#!/bin/bash



# Verify server tags BEFORE placing a stream, then place against exactly

# what the servers advertise — so a typo fails loudly instead of silently

# placing nowhere.

#

# This assumes the 3-node "east" cluster is running with JetStream

# enabled. Tag matching folds case (ssd == SSD) but is matched as an exact

# intersection: every requested tag must be present, spelled correctly, on a

# server for it to qualify.



# Read the tags each server actually advertises. Do not assume the config

# took — a typo in server_tags is silent until a placement asks for a tag

# no server carries. The Tags line in the output is the source of truth.

#

# `nats server info` queries the system account ($SYS), so connect with a

# system user. Name the server you want, or the command answers for whichever

# server replies to the $SYS ping first.

nats server info n1-east

nats server info n2-east

nats server info n3-east



# Now place ORDERS against exactly the tags you just read back.

nats --server nats://127.0.0.1:4222 stream add ORDERS \

  --subjects "orders.>" \

  --replicas 3 \

  --tag region:us-east \

  --tag disk:ssd \

  --defaults



# If a requested tag is misspelled or missing on every server, the

# intersection is empty and the create fails — it does NOT fall back to

# any server. The error names the tag no server carried, in brackets:

#

#   nats: error: could not create Stream: no suitable peers for placement, tags not matched ['disk:sdd'] (10005)

#

# Fix the spelling to match what the servers advertise (case does not

# matter) and re-run. Confirm the placement landed where you intended:

nats --server nats://127.0.0.1:4222 stream info ORDERS
```

#### C

```
// Read the tags each server actually advertises. Do not assume the

// config took — a typo in server_tags is silent until a placement

// asks for a tag no server carries. There is no dedicated client

// API for this: it is a plain request on the system account's

// $SYS.REQ.SERVER.PING.VARZ subject, filtered by server name. The

// "tags" field of the reply is the source of truth.

const char *names[] = {"n1-east", "n2-east", "n3-east"};



for (i = 0; (s == NATS_OK) && (i < 3); i++)

{

    natsMsg     *reply = NULL;

    char        req[64];



    snprintf(req, sizeof(req), "{\"server_name\":\"%s\"}", names[i]);

    s = natsConnection_RequestString(&reply, sysConn,

            "$SYS.REQ.SERVER.PING.VARZ", req, 2000);

    if (s == NATS_OK)

    {

        // Print just the "tags" list out of the VARZ reply.

        const char *tags = strstr(natsMsg_GetData(reply), "\"tags\":");

        const char *end  = (tags != NULL) ? strchr(tags, ']') : NULL;



        if (end != NULL)

            printf("%s %.*s]\n", names[i], (int)(end - tags), tags);

        natsMsg_Destroy(reply);

    }

}



// Now place ORDERS against exactly the tags you just read back.

// If a requested tag is misspelled or missing on every server, the

// intersection is empty and the create fails — it does NOT fall

// back to any server. The error names the tag no server carried:

//

//   no suitable peers for placement, tags not matched ['disk:sdd']

//   (error code 10005)

if (s == NATS_OK)

{

    jsStreamConfig  cfg;

    jsPlacement     placement;

    const char      *subjects[] = {"orders.>"};

    const char      *tags[]     = {"region:us-east", "disk:ssd"};



    jsPlacement_Init(&placement);

    placement.Tags    = tags;

    placement.TagsLen = 2;



    jsStreamConfig_Init(&cfg);

    cfg.Name        = "ORDERS";

    cfg.Subjects    = subjects;

    cfg.SubjectsLen = 1;

    cfg.Replicas    = 3;

    cfg.Placement   = &placement;



    s = js_AddStream(&si, js, &cfg, NULL, &jerr);

    if (jerr == JSStreamNameExistErr)

        s = js_UpdateStream(&si, js, &cfg, NULL, &jerr);

}



// Confirm the placement landed where you intended: the leader and

// both replicas are servers that advertised the tags.

if ((s == NATS_OK) && (si->Cluster != NULL))

{

    printf("Leader: %s\n", si->Cluster->Leader);

    for (i = 0; i < si->Cluster->ReplicasLen; i++)

        printf("Replica: %s\n", si->Cluster->Replicas[i]->Name);

}
```

**You can't name a leader at placement time.** Placement constrains which servers hold the replicas; it can't say which one leads, and setting a `preferred` server in placement is rejected outright. Don't build an operational assumption ("the leader is always `n1-east`") on where the group first landed; the moment a leader dies, the next election is quorum-based and picks a leader from the survivors. If you need leadership on a specific server, ask for it explicitly with `nats stream cluster step-down --preferred <server>` (see [Raft and leaders](/learn/clustering/raft-and-leaders.md)), then re-check with `nats stream info` — it's a request the election can still overrule.

## Where you are

The `ORDERS` stream is no longer placed on whichever servers the meta leader chose freely. You tagged `n1-east`, `n2-east`, and `n3-east`, and constrained the stream to servers carrying both `region:us-east` and `disk:ssd`. You know the tag match is an intersection that folds case, that a missing or misspelled tag yields `no suitable peers for placement`, and that placement can't name a leader — you move leadership after the fact with a stepdown request.

The cluster is still three servers. Nothing on this page changed the peer count.

## What's next

Changing the peer count is the next page. **Scaling and peer management** grows the group by raising the replica count, watches a new peer catch up before you lean on it, and moves a replica off a server without ever losing the majority that keeps `ORDERS` writable.

Continue to [Scaling and peer management](/learn/clustering/scaling-and-peers.md).

## See also

* [Reference → Server tags](/reference/config/server_tags.md) — every server-tag and placement option and its syntax.
* [Reference → Meta API](/reference/jetstream/api/meta/.md) — how the meta leader assigns a placed stream to servers.
* [Super-clusters](/learn/topologies/super-clusters.md) — placing replicas across clusters for geo-affinity.
