---
title: "docs.nats.io — Placement"
type: summary
area: [topology, jetstream, deploy]
source-url: https://docs.nats.io/learn/clustering/placement.md
source-path: raw/nats-docs/learn/clustering/placement.md
author: NATS documentation (Synadia Communications, Inc.)
article: Placement
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [placement, server_tags, no-suitable-peers]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Placement

How a stream's replicas are constrained to particular servers, and why the constraint fails loudly
rather than falling back.

## Key claims

- **Placement** is a rule attached to a stream that limits which servers may hold its replicas.
  Without it the meta leader may put the copies on any servers with capacity. With it the meta
  leader must honour the constraint **or refuse to create the stream**.
- Placement has exactly **two levers**: a **cluster** name (every replica must live there — a
  no-op inside a single cluster, useful across clusters) and **tags**.
- A **tag** is freeform label text attached to a server with **`server_tags`** in its config; the
  server advertises its tags to the rest of the cluster. Example:
  `server_tags: ["region:us-east", "disk:ssd"]`.
- **Tag matching is an intersection, not a union.** A server qualifies only if it carries *every*
  tag in the placement list.
- **Matching folds case** (`disk:ssd`, `disk:SSD` and `disk:Ssd` are the same tag) but
  **spelling is exact** — `disk:sdd` matches nothing.
- A placement that matches no server fails with, verbatim:
  `nats: error: could not create Stream: no suitable peers for placement, tags not matched ['disk:sdd'] (10005)`
  — the error names the tag no server carried, in brackets.
- **The same error appears if fewer servers carry the required tags than the replica count asks
  for.** Placement does not relax the constraint to fit the replica count; it fails so you notice.
- **Placement cannot name a leader.** Setting a `preferred` server in a stream's placement is
  rejected with `preferred server not permitted in placement`, and no client library exposes such
  a field — `Placement` carries only a cluster and tags. The meta leader picks the initial leader.
- Leadership is moved **after the fact**, with
  `nats stream cluster step-down --preferred <server>` (**nats-server 2.11+**) — a request the
  quorum election can still overrule.
- `nats stream edit` accepts the same placement flags and makes the meta leader **re-assign the
  replicas** to servers matching the new constraint.

## Practical takeaways

- **Read the tags back before placing against them.** A typo in `server_tags` is silent until a
  placement asks for a tag no server advertises. `nats server info <server>` prints a `Tags` line;
  it queries the system account (`$SYS`), so connect with a system user, and name the server or
  the command answers for whichever server replies to the `$SYS` ping first.
- Do not build an operational assumption like "the leader is always `n1-east`" on where a group
  first landed — the next election is quorum-based and picks from the survivors.

## Commands the page uses

```
nats server info n1-east
nats stream add ORDERS --subjects "orders.>" --replicas 3 --cluster east --tag region:us-east --tag disk:ssd --defaults
nats stream edit ORDERS --cluster east --tag region:us-east --tag disk:ssd
nats stream info ORDERS
```

Server config:

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

## Relevance to the wiki

The primary source for [[stream-placement]]. `no suitable peers for placement` is one of the most
common JetStream errors and this page gives both of its causes (a tag no server carries, and too
few qualifying servers for the replica count) with the verbatim message and error code.

## Questions it answers

Q33 in part (why raising a replica count fails with "no suitable peers for placement" — the
placement-constraint cause; the scale-up path itself is still open), Q35 in part (moving a stream
to a different set of peers, via a placement edit).

## Pages touched

[[stream-placement]] · [[replicas]] · [[raft-in-nats]]
