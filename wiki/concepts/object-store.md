---
title: Object Store
type: concept
area: [objectstore, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [objectstore, chunks, digest, OBJ_, Nats-Rollup, soft-delete, links, chunk-size]
aliases: [object store, OBJ_, "$O.", object bucket, OBJ_ stream]
sources: [s-adr-20-object-store, s-docs-stream-config, s-docs-kv-ttl-and-limits, s-docs-object-store-under-the-hood, s-docs-object-store-chunking, s-docs-object-store-your-first-object, s-docs-object-store-metadata-and-links, s-docs-object-store-watching-and-listing, s-nats-server-object-store-observed, s-gh-6836-object-store-list-slow, s-nats-server-object-store-leafnode, s-nats-server-leafnode-js-domains]
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
for. The docs print the same config (source: [[s-docs-object-store-under-the-hood]]), and
`nats stream info OBJ_INVOICES --json` on **nats-server 2.14.6** returned it field for field, plus
two fields neither source shows: **`duplicate_window` is 2m** — the stream default is not suppressed
for object buckets — and `max_msgs_per_subject` is `-1`, because the rollup rather than a per-subject
limit is what keeps one metadata message per object (source:
[[s-nats-server-object-store-observed]]).

**`discard: new` is the consequential one.** A full object bucket **rejects new puts**; it does not
age out old objects to make room. The docs give the reason: the policy "is set to `new` so the stream
rejects writes when full rather than dropping old chunks" — dropping the oldest message would silently
gut a live object rather than remove a whole one (source: [[s-docs-object-store-under-the-hood]]).

**All chunks of one put share a single subject.** `$O.<bucket>.C.<nuid>` is one subject per *put*, not
per chunk: a six-chunk object showed a count of 6 on one subject in `nats stream subjects`. The
metadata subject is the object name in **padded** base64url —
`$O.INVOICES.M.aW52b2ljZS1vcmRfOXgzbS5wZGY=` decodes to `invoice-ord_9x3m.pdf` (source:
[[s-nats-server-object-store-observed]]).

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

The last three were read out of a real metadata message on **2.14.6**, which is worth quoting because
it settles all of them at once (source: [[s-nats-server-object-store-observed]]):

```
Headers:
  Nats-Rollup: sub

{"name":"invoice-ord_9x3m.pdf","options":{"max_chunk_size":524288},"bucket":"INVOICES",
 "nuid":"2YrBblmFpoTLsXRGbLyeZo","size":3145728,"mtime":"0001-01-01T00:00:00Z","chunks":6,
 "digest":"SHA-256=gjJlkc6IUi_HXQeYNBCoMH_S1O7w2K6qTcHk8-gupUY="}
```

`mtime` is the **zero time** — the observable proof that it is never persisted, with the
`Modification Time` the CLI prints coming from the message timestamp. `options.max_chunk_size` is
stored **per object**, which is why nothing can change an object's chunk size after the fact. And the
digest is stored as `SHA-256=<base64url>` while `nats object info` renders it as
`SHA-256 <hex>` — the same value in two presentations, which matters when comparing them by eye.

### The write ordering, and why a failed put is safe

Put writes **the chunks first and the metadata message last**; get reads the metadata, then the
chunks, then verifies. "That ordering is what lets get know how many pieces to expect and what digest
to check them against" (source: [[s-docs-object-store-your-first-object]]). Three consequences the
operator sees:

- **An interrupted put leaves no gettable object at all** — with no metadata record, a get reports
  the name as not found rather than returning a truncated file. The contract the docs state:
  *"what you get is byte-for-byte what you put, or you get an error."*
- **A digest mismatch is a different failure** from a missing object: it means the object was stored
  whole and its bytes were lost or corrupted afterwards. Clients raise `ErrDigestMismatch`; a missing
  name raises `ErrObjectNotFound` (source: [[s-docs-object-store-your-first-object]]).
- **A re-put never merges into old bytes.** Every put gets a fresh NUID, so the second put's chunks
  cannot overlap the first's, and the old chunks fall away when the new metadata lands (source:
  [[s-docs-object-store-chunking]]).

**The one silent leak: orphan chunks.** A client that survives a failed put purges the partial chunks
it wrote. A client **killed** mid-put runs no cleanup, so "the chunks it had already written stay in
the stream as orphans: invisible to get, because no metadata points at them, but still holding storage
until the bucket's limits or age reclaim them" (source: [[s-docs-object-store-chunking]]). No source
offers a way to find or reclaim them short of the bucket's own limits.

Two failure paths that are **not** leaks, checked on 2.14.6: a chunk size above `max_payload` is
rejected by the **client** before anything is published — `nats: error: nats: maximum payload
exceeded`, the previously stored object intact and **zero orphan chunks** in the stream (source:
[[s-nats-server-object-store-observed]]). The docs attribute that rejection to the server, which on
this path it is not — the practical outcome, a put that fails having written nothing, is the same.

### Choosing a chunk size

The ADR says only that clients may tune it. The docs give the guidance and both bounds (source:
[[s-docs-object-store-chunking]]):

| | what goes wrong |
|---|---|
| **too small** | "a single file becomes thousands of tiny messages… very small chunks waste storage on per-message overhead and slow puts and gets down" |
| **too large** | the chunk exceeds `max_payload` (**1 MB by default**) — or a smaller `max_msg_size` set on the backing stream — and the put fails outright |

The advice is to leave it alone: *"Don't tune the chunk size to chase a benchmark; the 128 KB default
fits almost every file and stays well under the default payload limit."*

The docs never put a **number** on that per-message overhead — the one page in the whole docs tree
that raises the subject does not quantify it. Measured at the default, it is small: a 200 MiB object
occupied 204,912 KB on disk, about **2.4 % overhead**, because 128 KiB chunks mean only 1,601 messages
carry it. Halving the chunk size doubles the message count and doubles that overhead;
[[filestore-layout]] has the per-message arithmetic (source: [[s-nats-server-object-store-observed]]).

### The message-count consequence

At the 128k default, a 1 GiB object is **8,192 chunk messages** plus one info message. Size an
object-store bucket by *messages* as well as bytes — the per-message costs on [[jetstream-sizing]]
apply to every chunk, and `max_msgs` on the underlying stream counts chunks, not objects.

Confirmed on 2.14.6 at two scales: a 3 MiB file landed **exactly 24 chunks** (3145728 / 24 = 131072,
so the default is 128 **KiB** precisely, not "roughly"), and a 200 MiB object landed **1,600 chunks
plus one metadata message**. `--chunk-size 65536` on the same 3 MiB file gave 48 chunks;
`--chunk-size 524288` gave 6 (source: [[s-nats-server-object-store-observed]]).

## Naming rules

- **Bucket name** is `restricted-term`: one or more of `A-Z a-z 0-9 - _`. The docs put it as "letters,
  digits, underscores, and dashes only" — the same rule as a stream name (source:
  [[s-docs-object-store-your-first-object]]). On 2.14.6 `has.dot`, `has space` and `has>gt` were each
  rejected with `nats: error: nats: invalid object-store name`, **client-side** — no `err_code`, so
  the request never reaches the server (source: [[s-nats-server-object-store-observed]]).
- **Object name** is unrestricted and **base64-encoded** to form the subject token — so subjects
  stay legal whatever the object is called.
- **Object ids** are NUIDs.

**A CLI trap in the object name.** `nats object put` stores the object under **the path you typed,
cleaned — not the basename**: putting `./invoices/invoice-ord_8w2k.pdf` stores the object as
`invoices/invoice-ord_8w2k.pdf`. Run from the file's directory or pass `--name`. Piping from stdin
*requires* `--name`, and `nats object get --output` will not create parent directories (source:
[[s-docs-object-store-your-first-object]]).

## Operations worth knowing

| operation | behaviour |
|---|---|
| **Delete** | a no-op on an already-deleted object is acceptable; deleting an object that **does not exist is an error** |
| **List** | filters out deleted objects by default; including them is an opt-in |
| **Seal** | seals the bucket — no further modifications allowed |
| **Watch** | receives **meta information** updates, not chunk traffic |
| **UpdateMeta** | updates some metadata; **updating metadata of a deleted object is an error** |

### Delete is a rollup, and what it costs

There is no hard delete. A delete "writes one more metadata message, a **soft delete**, that marks the
object `Deleted=true`, sets `Size` and `Chunks` to zero, and clears the digest", and then the object's
chunks are purged; the surviving marker is what lets a watcher see that an object disappeared (source:
[[s-docs-object-store-under-the-hood]]). The tombstone, read off 2.14.6 — note the `digest` field is
**absent**, not emptied:

```
{"name":"invoice-ord_9x3m.pdf","options":{"max_chunk_size":524288},"bucket":"INVOICES",
 "nuid":"2YrBblmFpoTLsXRGbLyeZo","size":0,"mtime":"0001-01-01T00:00:00Z","chunks":0,"deleted":true}
```

**The `nats` CLI cannot show you a tombstone.** Reading it needs a client's show-deleted option
(`GetObjectInfoShowDeleted` / `ListObjectsShowDeleted` in Go), "which the `nats` CLI doesn't expose"
(source: [[s-docs-object-store-under-the-hood]]). Via the CLI the only route is
`nats stream get OBJ_<bucket> --last-for '$O.<bucket>.M.<base64url(name)>'`.

**How much disk comes back, and when.** The docs warn that the space "is reclaimed as the stream
cleans up, **not synchronously at the call**" and that you should not "delete a large object and
immediately assert the disk is smaller". Measured, that is directionally right and quantitatively
alarmist. Deleting one 200 MiB object on 2.14.6 (source: [[s-nats-server-object-store-observed]]):

| moment | stream directory on disk | stream state |
|---|---|---|
| after the put | 204,912 KB | 1601 msgs |
| delete + 0 s | **3,212 KB** | 1 msg / 260 bytes |
| delete + 2 / 10 / 30 / 60 s | 3,212 KB | 1 msg / 260 bytes |

**98.4 % of the bytes come back with the call.** What lingers is one trailing block — a single
3.2 MB `.blk` — not a slow drain of the object, and it is collected later ([[filestore-layout]] has
the block mechanics). Size for one block of residue, not for the object.

**A re-put after a delete is a new object**, not a restored one: "it creates a brand-new object that
happens to share the name" (source: [[s-docs-object-store-under-the-hood]]).

### Metadata you set, and links

Beyond the fields the store computes, three are the caller's: a **description**, HTTP-style
**headers**, and a free-form **metadata** map. All three ride in the one trailing metadata message, so
reading them costs no extra storage and no extra read — the docs call it "a low-cost index over the
bucket" (source: [[s-docs-object-store-metadata-and-links]]).

A **link** is an object whose target is another object; a get on the link returns the target's bytes.
It stores no chunks, only the target's bucket and name. A **bucket link** points at a whole bucket
(empty target name) and a get on it returns an error — `ErrCantGetBucket` in Go — rather than bytes.
Two rules the store enforces: **no link to a deleted object, and no link to another link.**

Three behaviours that bite, all from [[s-docs-object-store-metadata-and-links]]:

- **A link is a snapshot, not a live reference.** It does not keep the target alive and it does not
  follow a rename. Delete or rename the target and the link dangles, failing with
  `ErrObjectNotFound`. Re-create the link after either.
- **`UpdateMeta` silently discards two fields.** It changes the name, description, headers and
  metadata. Hand it a new **chunk size** or a new **link target** and "those fields are discarded
  without error or notification: the call succeeds, but neither is stored." To change either, delete
  and re-create. (The observed `options.max_chunk_size` above is why: the chunk size is fixed when the
  bytes are written.)
- **Renaming onto a live name fails** with `ErrObjectAlreadyExists`; renaming onto a **deleted** name
  succeeds and reclaims it.

**Links are client-library only.** `nats object` offers `add, edit, put, del, get, info, ls, seal,
watch` and no `link` subcommand at CLI 0.4.0 — the docs say so themselves, and it was confirmed on the
binary (sources: [[s-docs-object-store-metadata-and-links]], [[s-nats-server-object-store-observed]]).

### List and watch

**List is a one-time snapshot** of the live objects — metadata only, never chunks, soft-deleted
objects filtered out. An empty bucket is an **empty result, not an error**: clients surface
`ErrNoObjectsFound` and `nats object ls` prints `No entries found` and exits **0**, while a missing
object's `get` or `info` exits **1** with `nats: error: nats: object not found` (sources:
[[s-docs-object-store-watching-and-listing]], [[s-nats-server-object-store-observed]]).

**Watch is the live counterpart** — ordered, one update per put, re-put or delete, and it carries
**`ObjectInfo` only, never the bytes**. That is the deliberate difference from a KV watch, which
delivers each key's value directly because values are small: "an object can be gigabytes, so the watch
delivers only the metadata and leaves the data fetch to you". The pattern is two steps — watch to
learn *what* changed, get the bytes you actually need. When the watch has caught up it delivers a
**nil sentinel** marking the snapshot/live boundary; the CLI consumes it for you, client code must
handle it — the same end-of-initial-data trap the KV chapter calls the most common watch bug
([[key-value]], source: [[s-docs-object-store-watching-and-listing]]).

**A list is not free while the bucket is being written.** It is four `$JS.API` calls including an
ephemeral `last_per_subject` consumer created and destroyed per call, and under a concurrent upload
its latency runs 2–7× the idle figure. The only public report of this
([[s-gh-6836-object-store-list-slow]] ·
[[s-nats-server-object-store-leafnode]] · [[s-nats-server-leafnode-js-domains]]) has been open and unanswered since 2025-04-25, so the wiki's
answer is measured rather than cited: [[object-store-list-is-slow]].

### A bucket is not isolated by a JetStream domain

Two servers joined by a leafnode, with **different** JetStream domains and a shared account, deny each
other's JetStream traffic — that is what the `JetStream using domains: local %q, remote %q` log line
means ([[jetstream-domain]], [[leafnode]]). The deny list is
`["$JS.API.>", "$KV.>", "$OBJ.>"]` (`server/jetstream_api.go:323`, v2.14.6, read in
[[s-nats-server-leafnode-js-domains]], which also carries the domain mapping table's
`"$OBJ.>": "$OBJ.>"` entry).

**`$OBJ` is not this store's subject space — `$O.` is** — so object-store traffic is not denied.
Measured on 2.14.6 across such a link (source: [[s-nats-server-object-store-leafnode]]):

| published on the leaf | reached the hub? |
|---|---|
| `$KV.TEST.key1` | no — matches `$KV.>` |
| `$OBJ.TEST.thing` | no — matches `$OBJ.>` |
| **`$O.TEST.C.abc`** and **`$O.TEST.M.abc`** | **yes** |

With a bucket of the **same name in the same account on both sides**, one 600 KiB put on the leaf left
both streams identical — 6 msgs / 615,040 bytes each — and the hub then listed an object nobody put
there, chunks and metadata both. A KV bucket in the same position stayed empty on the hub.

Nothing is logged, and the put looks entirely normal from the leaf. If you run object buckets either
side of a domain boundary, either **do not reuse bucket names** across it, or add an explicit `$O.>`
deny to the leafnode remote ([[subject-permissions]]).

Whether this is a defect or an intended asymmetry is not established — no public source mentions
`$OBJ` against `$O.` at all, which is the documentation gap recorded as issue **#35** in
`inbox/docs-issues.md`.

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

Both items this page listed as unverified are now settled, and neither by the source the plan
expected:

- **Why listing a bucket is slow while uploads run** (question-bank Q75) — the docs page on listing
  says only that "a list is cheap" and never mentions concurrency, and the one public thread is
  unanswered. It was **measured on 2.14.6** instead: [[object-store-list-is-slow]].
- **Choosing a chunk size** — the ADR gives no guidance; `learn/object-store/chunking.md` does. See
  *Choosing a chunk size* above.

## To verify

- **No source states which nats-server version the object store first shipped in.** ADR-20 is dated
  2021-11-03 and marked *Implemented*, but the ADR carries no server version and no release note read
  so far mentions the object store. The `since:` field is deliberately left empty rather than guessed.
  What *is* known: the bucket is a client-side construct over stream features, and it needs
  `allow_rollup_hdrs` and `allow_direct` ([[direct-get]]) on the backing stream; compression arrived
  for 2.10.
- **Nothing here about links or `UpdateMeta` has been run.** The `nats` CLI has no `link` subcommand
  and no `update-meta`, so `ErrCantGetBucket`, the no-link-to-a-link rule and the silent `UpdateMeta`
  discard rest on the docs alone. A client-library test would settle them.
- **`ErrDigestMismatch` has not been observed.** Producing one means corrupting a stored chunk behind
  the server's back.

## When a KV value should have been an object

The KV chapter draws the boundary in one sentence: "key-value values are meant to be small; large
values belong in the Object Store" (source: [[s-docs-kv-ttl-and-limits]]). Mechanically the boundary
is a hard one — a bucket's `--max-value-size` maps to the stream's `max_msg_size`, so a KV value must
fit in **one message**, while an object is chunked across many ([[key-value]]).

The failure mode when the boundary is crossed the wrong way is a rejected write, not a slow one: a KV
bucket is `discard: new`, so an oversized put "is rejected outright… and leaves every existing value
in place".

## Related

[[stream]] · [[key-value]] · [[object-store-list-is-slow]] · [[jetstream-sizing]] ·
[[filestore-layout]] · [[replicas]] · [[direct-get]] · [[subject-permissions]] ·
[[cross-account-sharing]] · [[jetstream-domain]] · [[leafnode]]

## Sources

[[s-adr-20-object-store]] · [[s-docs-stream-config]] · [[s-docs-kv-ttl-and-limits]] ·
[[s-docs-object-store-under-the-hood]] · [[s-docs-object-store-chunking]] ·
[[s-docs-object-store-your-first-object]] · [[s-docs-object-store-metadata-and-links]] ·
[[s-docs-object-store-watching-and-listing]] · [[s-nats-server-object-store-observed]] ·
[[s-gh-6836-object-store-list-slow]] ·
[[s-nats-server-object-store-leafnode]] · [[s-nats-server-leafnode-js-domains]]
