---
title: Object Store
type: concept
area: [objectstore, jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [objectstore, chunks, digest, OBJ_]
aliases: [object store, OBJ_, "$O."]
sources: [s-adr-20-object-store, s-docs-stream-config]
created: 2026-08-31
updated: 2026-08-31
---

# Object Store

An object-store bucket **is a [[stream]]** holding two subject spaces at once: object **chunks** and
object **info**. A large object is not one message — it is *N* messages of one chunk each, which is
why an object-store bucket's message count and behaviour look nothing like its byte size suggests
(source: [[s-adr-20-object-store]]).

## The stream a bucket actually is

| component | template |
|---|---|
| stream name | **`OBJ_<bucket>`** |
| chunk subject space | **`$O.<bucket>.C.>`** |
| meta subject space | **`$O.<bucket>.M.>`** |
| one chunk | `$O.<bucket>.C.<object-nuid>` |
| one object's info | `$O.<bucket>.M.<name-encoded>` |

The ADR's example config sets `rollup_hdrs: true`, `allow_direct: true`, `discard: "new"`,
`storage: "file"`, `max_age: 0`, `max_bytes: -1`, and `compression: "s2"` when compression is asked
for.

**The Object Info subject is always rolled up per subject** — that is how the newest info for an
object replaces the previous one rather than accumulating.

`ObjectStoreConfig` maps onto stream fields directly: `TTL → max_age`, `MaxBytes → max_bytes`,
`Storage → storage`, `Replicas → num_replicas`, `Placement → placement`, plus the stream's
description and metadata. `Compression` is a **boolean** here — the object store deliberately does
not expose the stream's compression enum, and sets `s2` when true.

## How an object is stored

- The object is **split into chunks**, each chunk one message's payload on the chunk subject.
- **Default chunk size is 128k (`128 * 1024`)**, tunable per object.
- Object Info is **JSON in the payload** of a message on the meta subject, carrying the object's
  `chunks` count and its `digest`.
- **`SHA-256` is the only supported digest**, written uppercase per RFC-6234, in the form
  `SHA-256=IdgP4UYMGt47rgecOqFoLrd24AXukHf5-SVzqQ5Psg8=`.
- **Modified time is never stored.** On put the client fills it with the current UTC time; on get,
  with the server's message timestamp. So `ModTime` is derived, not persisted.

### The message-count consequence

At the 128k default, a 1 GiB object is **8,192 chunk messages** plus one info message. Size an
object-store bucket by *messages* as well as bytes — the per-message costs on [[jetstream-sizing]]
apply to every chunk, and `max_msgs` on the underlying stream counts chunks, not objects.

## Naming rules

- **Bucket name** is `restricted-term`: one or more of `A-Z a-z 0-9 - _`.
- **Object name** is unrestricted and **base64-encoded** to form the subject token — so subjects
  stay legal whatever the object is called.
- **Object ids** are NUIDs.

## Operations worth knowing

| operation | behaviour |
|---|---|
| **Delete** | a no-op on an already-deleted object is acceptable; deleting an object that **does not exist is an error** |
| **List** | filters out deleted objects by default; including them is an opt-in |
| **Seal** | seals the bucket — no further modifications allowed |
| **Watch** | receives **meta information** updates, not chunk traffic |
| **UpdateMeta** | updates some metadata; **updating metadata of a deleted object is an error** |

## What the spec says does not exist

The ADR lists these as *possible future features*, i.e. **not implemented**: event notifications,
locking, archiving / tiered storage, searching and indexing, **versioning and revisions**,
overriding the digest algorithm, capturing a content type, per-chunk content-encoding, and
**reading an individual chunk**.

A design that assumes object versioning or single-chunk reads is assuming something that is not
there.

## Version notes

- **Metadata** arrived in revision 2 (2023-06-14).
- **Compression** arrived for **NATS Server 2.10** (revision 3, 2024-02-05).

## To verify

- **Why listing a bucket is slow or times out while uploads run** (question-bank Q75) is not
  answered here. The structural fact — a list reads the meta subject space while chunk traffic
  shares the same stream — is a candidate explanation, but the linked thread has not been read and
  no source ingested confirms the mechanism.
- The ADR gives no guidance on **choosing a chunk size** beyond "clients may tune this as
  appropriate".

## Related

[[stream]] · [[key-value]] · [[jetstream-sizing]] · [[replicas]] · [[direct-get]]

## Sources

[[s-adr-20-object-store]] · [[s-docs-stream-config]]
