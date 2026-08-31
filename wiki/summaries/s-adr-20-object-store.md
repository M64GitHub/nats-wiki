---
title: "ADR-20 — JetStream based Object Stores"
type: summary
area: [objectstore, jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-20.md
source-path: raw/adr/ADR-20.md
author: "@scottf"
article: "ADR-20: JetStream based Object Stores"
date: 2021-11-03          # ADR date; revision 3 dated 2024-02-05
version: "2.10+ for compression"
tags: [objectstore, chunks, stream-mapping, digest]
aliases: [ADR-20]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-20 — JetStream based Object Stores

Status **Implemented**. **Skipped for this wiki:** the Go `ObjectStore` interface, the per-method
client contract and the future-features list. Kept: **the stream an object-store bucket actually
is**, because that is what an operator sees and sizes.

## Key claims

### The stream shape

| component | template |
|---|---|
| stream name | **`OBJ_<bucket>`** |
| chunk stream subject | **`$O.<bucket>.C.>`** |
| meta stream subject | **`$O.<bucket>.M.>`** |
| chunk message subject | `$O.<bucket>.C.<object-nuid>` |
| meta message subject | `$O.<bucket>.M.<name-encoded>` |

The example stream config in the ADR sets `rollup_hdrs: true`, `allow_direct: true`,
`discard: "new"`, `storage: "file"`, `num_replicas: 1`, `max_age: 0`, `max_bytes: -1`, and
`compression: "s2"` when compression is requested.

**A bucket therefore holds two subject spaces in one stream**: object *chunks* and object *info*.
The Object Info subject is **always rolled up per subject**, which is how the newest info for an
object replaces the old one.

### How an object is stored

- An object is **split into chunks**, each chunk the payload of one message on the chunk subject.
- **Default chunk size is 128k (`128 * 1024`)**, tunable per object.
- Object Info is stored as **JSON in the payload** of a message on the meta subject, and carries
  the object's **`chunks`** count and its **`digest`**.
- **`SHA-256` is the only supported digest**, written uppercase per RFC-6234, in the form
  `SHA-256=IdgP4UYMGt47rgecOqFoLrd24AXukHf5-SVzqQ5Psg8=`.
- **Modified time is never stored.** On put, the client fills `ModTime` with the current UTC time;
  on get, with the message time from the server.
- Bucket names are `restricted-term` — one or more of `A-Z a-z 0-9 - _`. Object *names* are
  unrestricted and **base64-encoded** to form the subject token. Object ids are NUIDs.

### The config maps onto stream fields

`ObjectStoreConfig` maps `TTL → max_age`, `MaxBytes → max_bytes`, `Storage → storage`,
`Replicas → num_replicas`, `Placement → placement`, `Description`/`Metadata` onto the stream's, and
a `Compression` **boolean** onto `compression: "s2"` — the object store deliberately does not
expose the stream's compression enum.

### Operations worth knowing

- **Delete** — no-op on an already-deleted object is acceptable; deleting an object that does not
  exist is an **error**.
- **List** — "filter those objects that have been deleted"; including them is an opt-in.
- **Seal** — seals the bucket; no further modifications allowed.
- **Watch** — receives *meta information* updates, not chunk traffic.
- **UpdateMeta** — updates some metadata; **it is an error to update metadata for a deleted
  object**.

## Notable

- **Compression arrived for NATS Server 2.10** (revision 3, 2024-02-05); metadata in revision 2
  (2023-06-14).
- The ADR's "possible future features" list — event notifications, locking, archiving/tiered
  storage, search/indexing, versioning, per-chunk content-encoding, reading an individual chunk —
  is explicitly **not implemented**. Anyone planning around per-chunk reads or object versioning is
  planning around something that does not exist.

## Relevance to the wiki

Gives [[object-store]] its operator content: the two subject spaces in one stream, the 128k chunk
default that drives message counts, and the fact that a large object is *N* messages, not one — the
thing that makes object-store buckets behave unlike their size suggests.

## Questions it answers

Q75 in part (why listing a bucket is slow while uploads run — this ADR explains that a list reads
the *meta* subject space while chunk traffic shares the same stream, but it does not diagnose the
timeout; the linked thread is still needed).

## Pages touched

[[object-store]] · [[stream]] · [[key-value]]
