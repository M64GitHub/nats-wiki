---
title: "nats-server issue #5106 — Object Store replication from LeafNode to Cluster: nats: no stream matches subject"
type: summary
area: [objectstore, topology, clients]
source-url: https://github.com/nats-io/nats-server/issues/5106
source-path: raw/gh-issues/issue-5106.md
author: "@b3rtram (reported); @Jarema (answered); with raw/gh-issues/client-issues-object-store-mirror.md for nats.go #1874, #1648 and nats.js #155"
article: "nats-server issue 5106 (defect, closed 2024-03-04), plus the three client issues it points at"
date: 2024-02-19
version: "2.10.11 (server), nats CLI 0.1.3; re-run on 2.14.6 / CLI 0.4.0 in s-nats-server-mirrors-observed"
tags: [objectstore, mirror, leafnode, jetstream-domain, subject-transform, nats.go, nats.js, client-bug, no-stream-matches-subject]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# issue #5106 — a mirrored object-store bucket that lists as broken

The one public thread that shows how to mirror an object-store bucket, and why it did not work in
2024. Opened 2024-02-19 against **nats-server v2.10.11** with **nats CLI 0.1.3**, labelled `defect`,
closed by the reporter on 2024-03-04 after two nats.go pull requests.

## The report

A leaf (`server_name: nats-leaf-node`, `jetstream { domain: leafnode }`) and a hub (`domain:
cluster`) joined by a leafnode. Go code on the leaf creates bucket `dms` and puts PDFs into it. On
the hub, interactively: `nats stream add OBJ_dms_mirror --mirror OBJ_dms`, answering *Import mirror
from a different JetStream domain: Yes, Foreign JetStream domain name: leafnode*. The mirror syncs
(270 messages, 34 MiB), `nats object ls` on the hub lists `dms_mirror`, and then:

```
nats --server=localhost:4222 object ls dms_mirror
nats: error: nats: no stream matches subject
```

## The answer

Two reasons, from a maintainer of the clients: "CLI assumes that the subject name where to look for
metadata and chunks is aligned with stream name, which is not the case for mirrors. This one can be
fix with stream subject tranform. However, CLI also sends request to list all streams by subject,
and that does not include mirrors."

The **transform** is `$O.dms.>` → `$O.dms_mirror.>` on the mirror — "So you need to transform from
the `$O.bucket.>` into `$O.mirror_bucket_name.>`. Don't forget about the Object Store prefixes in
names." The reporter's server trace shows the second reason exactly: after `STREAM.INFO` and a
`STREAM.MSG.GET` with `last_by_subj: $O.dms_mirror.M.>`, the client sent

```
$JS.API.STREAM.NAMES  {"subject":"$O.dms_mirror.M.>"}
→ {"type":"io.nats.jetstream.api.v1.stream_names_response","total":0,…,"streams":null}
```

A mirror has no subjects, so a lookup *by subject* can never find it. Fixed on the client side by
**nats.go #1568** (*Bind Object Store bucket stream when getting object*, merged 2024-02-26) and
#1578: bind the bucket by its stream name `OBJ_<bucket>` instead. With those and the transform the
reporter listed and fetched objects through the mirror on 2024-03-04. A maintainer's caveat at the
time: "As concept of subject transforms over Object Store is a new topic, we didn't create a
cross-client test to ensure that it works well across the ecosystem and all libraries."

## Where it stands, from the three client issues (fetched 2026-09-02)

- **nats.go #1874** *Support mirrored ObjectStore* — **open** since 2025-05-15, 8 comments. The ask
  is `Mirror` / `Sources` fields on `ObjectStoreConfig`, because "the manual stream creations works
  great since #5106 was fixed, but first class support would align with KV and streams"; the use
  case is leaf buckets mirrored into the cluster with a longer TTL. The client maintainer's reply:
  "you need to adapt subject names too and use subject transforms. Additionally, **deletes of objects
  will not propagete to mirrors**, as mirrors/sources have different limits than the original stream,
  by design" — and, on making it first-class, "not a good idea in current shape of Object Store …
  When we rethink and rework Object Store (also after server supports features it requires), that
  should be safe for general purpose." The reporter's workaround — the **same stream name on both
  sides** to dodge the transform — drew a server maintainer's warning: "Same stream in multiple
  domains has numerous bugs and issues. You absolutely should not do that … Certain kinds of
  consumers break and can potentially double ack between streams."
- **nats.js #155** *Support mirrored ObjectStore* — closed 2025-07-02: "Clients don't have a strategy
  for supporting this right now, but we are aware of it."
- **nats.go #1648** *Object store publishes chunks without using domain in subject* — open since
  2024-06-14; turned out to be a Java/.NET v1 bug in how the chunk consumer's filter was built
  (fixed in nats.java #1160), with the Go client "might be correct". Relevant only as a reminder that
  the object store across domains was exercised late.

## What 2.14.6 and CLI 0.4.0 do with the same procedure

Re-run on the hub/leaf pair ([[s-nats-server-mirrors-observed]], run C): the `no stream matches
subject` error is gone — the CLI binds by name now — but a mirror **without** the transform lists as
`No entries found` and a `get` says `object not found`, because the client reads `$O.dms_mirror.M.>`
and the mirror holds `$O.dms.M.>` ([[s-nats-go-kv-object-mirror]]). With the transform every
operation works and new objects replicate live. `nats object add` still has no `--mirror` flag;
`nats kv add` has `--mirror` and `--mirror-domain`.

## Practical takeaways

- A mirrored object bucket is a hand-built `OBJ_<name>` stream with `mirror.external.api =
  $JS.<domain>.API` and the transform `$O.<origin>.>` → `$O.<name>.>`. No client or CLI builds it
  for you as of 2026-09-02.
- It is read-only from the mirror side, deletes on the origin do not become deletes on the mirror,
  and the maintainers say it is not general-purpose yet. Use it for what the reporters use it for —
  a longer-lived copy at the hub — and read the origin for anything else.
- Do not reuse the bucket's stream name on both sides of a domain boundary to avoid the transform.

## Questions it answers

- **Q105** — both halves: why the listing failed (a client that looked the stream up by subject,
  fixed 2024-02) and what the mirror gives you (a read-only copy with its own retention, hand-built).

## Pages touched

[[object-store]] · [[mirrors-and-sources]] · [[cross-domain-sourcing]] · [[jetstream-domain]] ·
[[object-store-list-is-slow]] · [[nats-go]] · [[nats-cli]]
