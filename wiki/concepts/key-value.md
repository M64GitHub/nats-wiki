---
title: Key-Value
type: concept
area: [kv, jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [kv, bucket, tombstone, watch, direct-get]
aliases: [KV, key value, KV bucket, KV_]
sources: [s-gh-6746-watch-many-keys, s-gh-5243-kv-watchers-at-scale, s-adr-8-key-value-store, s-adr-43-per-message-ttl, s-adr-17-ordered-consumer, s-docs-stream-config, s-gh-7017-kv-across-accounts, s-gh-5606-cross-account-jetstream, s-adr-48-kv-ttl, s-adr-57-kv-subject-transforms, s-adr-54-kv-codecs, s-nats-server-filestore-layout]
created: 2026-08-31
updated: 2026-08-31
---

# Key-Value

A KV bucket **is a [[stream]]** with a fixed set of properties, a reserved name and a reserved
subject space. Every operator question about KV — why a delete grows the bucket, why a read can be
stale, why key listing is cheap — is answered by that mapping
(source: [[s-adr-8-key-value-store]]).

## The stream a bucket actually is

| property | value, fixed by the KV spec |
|---|---|
| stream name | **`KV_<bucket>`** |
| subjects | **`$KV.<bucket>.>`** |
| history per key | `max_msgs_per_subject` — **min 1, max 64**; clients use `1` when the user gives no value |
| `discard` | **always `new`** |
| `rollup_hdrs` | **always `true`** — safe key purges that delete history require it |
| `deny_delete` | **always `true`** |
| `allow_direct` | **always `true`**; changeable out-of-band only, never through a bucket update |
| storage | write replicas are **file** backed; the replica count may vary |
| key TTL (whole bucket) | the stream's `max_age` |
| value size cap | `max_msg_size` |
| bucket size cap | `max_bytes` |
| compression | `compression: "s2"` when requested |
| **number of keys** | **cannot currently be limited** |

`placement`, `republish` and stream `metadata` are all allowed. Deleting a bucket deletes the
stream.

This means **`nats stream info KV_<bucket>` works and tells you the truth** — a KV bucket is
inspectable, sizable and placeable with everything on [[stream]], [[replicas]] and
[[stream-placement]].

### The `max_age` / `duplicate_window` rule

When a bucket-wide key TTL is set, `duplicate_window` must follow `max_age`
(source: [[s-adr-8-key-value-store]]):

- `max_age` **> 2 minutes** → `duplicate_window` must be **2 minutes**;
- `max_age` **≤ 2 minutes** → `duplicate_window` must equal `max_age`.

If no key TTL is set, leaving `duplicate_window` unset is fine — the ADR states the server applies
this logic itself and defaults to 2 minutes. See *The deduplication window* on [[stream]].

## How it behaves

**Writes are publishes.** Key `auth.username` in bucket `CONFIGURATION` is a JetStream request to
`$KV.CONFIGURATION.auth.username`.

**Compare-and-set is a header.** `Nats-Expected-Last-Subject-Sequence` carries the revision the
write expects; the special value `0` means "only if this is the first message on the subject", and
it is **purge-aware** — after a purge, `0` is accepted again.

**Reads go through Direct Get.** `$JS.API.DIRECT.GET.<STREAM>.<SUBJECT>` "should be used for
performing all gets on a bucket if direct is enabled", and disabling direct get on a bucket is not
supported. The older `stream_msg_get_request` + `last_by_subj` path exists only for legacy buckets.
See [[direct-get]].

### There is no read-after-write consistency

Quoting the spec directly:

> "We do not provide read-after-write consistency. Reads are performed directly to any replica,
> including out of date ones. If those replicas do not catch up multiple reads of the same key can
> give different values between reads."

A healthy cluster will *mostly* return consistent values, "but this should not be relied on to be
true." Read-after-write existed historically and is **deprecated**. This follows directly from
Direct Get being answerable by any replica — see [[replicas]].

## Deletes do not remove data

This is the single most surprising KV behaviour, and it falls straight out of the stream mapping
(source: [[s-adr-8-key-value-store]]):

| operation | what actually happens |
|---|---|
| **Delete** | **publishes a new message** with a nil body and the header **`KV-Operation: DEL`**. History is preserved. The bucket grows. |
| **Purge** | publishes **`KV-Operation: PURGE`** *plus* **`Nats-Rollup: sub`**, which makes the server place the purge message and then delete every message for that key **up to before it**. One message remains. |

So a delete **adds** a message and a purge leaves a tombstone behind. Space comes back when the
stream's own limits (`max_age`, `max_msgs_per_subject`, `max_bytes`) remove the remaining entries —
or, since 2.11, when a TTL expires the tombstone itself. A purge can carry a TTL, which adds
`Nats-TTL` to the purge message. See [[message-ttl]].

Any entry whose `KV-Operation` header is set is deleted data. A plain get turns that into a
*key not found* error; watchers and history surface it as an entry with the operation set.

## Watch, history and listing keys

All three are **ephemeral [[ordered-consumer|ordered consumers]]** under the hood
(source: [[s-adr-8-key-value-store]]):

| operation | how it is built |
|---|---|
| **Watch** | ordered consumer starting at **`last_per_subject`**, so it opens with the newest value of every matching key. Multiple keys = **multiple filter subjects** — one consumer, not one per key (source: [[s-gh-6746-watch-many-keys]]; needs nats-server **2.10+** and a client that exposes it). |
| **History** | ordered consumer filtered by subject, reading with `deliver_all`. The latest value is the one with `Pending == 0`. |
| **Keys** | a **headers-only** consumer set to **deliver last per subject** — keys are parsed out of the subject and delete/purge operations skipped. **No values cross the wire.** |

That last row is the answer to "how do I count keys without fetching them": key listing already
transfers no values.

**Watch options**: `IncludeHistory`, `IgnoreDeletes`, `MetaOnly`, `UpdatesOnly`. The default with no
options sends every `last_per_subject` value **including delete and purge operations**.

**End of initial data** is signalled the first time a message has `Pending == 0`, and the spec
requires the signal to be sent **always** — including for an empty bucket.

Because watches and key listings create and drop ephemeral consumers, a busy KV workload shows up
as consumer churn; see [[ordered-consumer]] and the memory note on [[jetstream-sizing]]. At scale the
churn — not the count — is what breaks: 1000 clients each watching one key in a bucket holding a
single 118-byte message pinned a 3-node cluster at its CPU limit and it did not recover
(source: [[s-gh-5243-kv-watchers-at-scale]]). See [[kv-watchers-stall-the-cluster]].

## Limit markers and per-key TTL

Since **2.11**, KV supports a TTL per key, built on per-message TTL
(source: [[s-adr-43-per-message-ttl]], [[s-adr-8-key-value-store]]). With limit markers enabled,
clients receive a **`Nats-Marker-Reason`** header:

| value | treat as |
|---|---|
| `MaxAge` | `PURGE` |
| `Purge` | `PURGE` |
| `Remove` | `DEL` |

Enabling markers requires `allow_msg_ttl: true` and a `subject_delete_marker_ttl` of **at least one
second**, and a server at **API level 1 or newer (2.11+)**. The spec is specific that clients should
assert this with **`$JS.API.INFO`, not the connected server's version string**.

### What the TTL spec actually allows

Three rules from ADR-48, the refinement that added per-key TTL (source: [[s-adr-48-kv-ttl]]):

- **"Limit Markers" is one setting that writes two stream fields** — `allow_msg_ttl: true` and
  `subject_delete_marker_ttl: <duration>`. So `nats stream info KV_<bucket>` tells you whether a
  bucket has them.
- **The duration must be ≥ 1 second**, and the setting is **one-way**: it can be enabled on a bucket
  that lacks it, and the spec deliberately does not offer disabling it.
- **A TTL is accepted on `Create` and `Purge` only.** Not on `Put`, and the reason is worth knowing:
  "a TTL on `Put()` might mean older revisions could come back from the dead once the TTL expires".
  A `Purge` with a TTL is also the supported replacement for compaction — it removes old subjects
  permanently while still producing something a watcher can see.

## Mirrors and sources of a bucket

A KV bucket is a stream, so it mirrors and sources like one ([[mirrors-and-sources]]) — but a
conforming client writes a specific stream config, and knowing it makes `nats stream info` readable
(source: [[s-adr-57-kv-subject-transforms]], **Proposed**, so verify against the client you use):

- **A KV mirror always gets `mirror_direct` enabled**, and its stream name is `KV_`-prefixed. That is
  what puts a mirrored bucket into the upstream's Direct Get queue group and gives readers the
  nearest copy — subject to the alignment rules on [[mirrors-and-sources]].
- **A KV source gets a subject transform generated for it**: `$KV.<source>.>` → `$KV.<bucket>.>`, so
  keys land in the destination bucket's own subject space. Sourcing `ORDERS` into `NEW_ORDERS` with
  a key filter `NEW.>` produces `{"src": "$KV.ORDERS.NEW.>", "dest": "$KV.NEW_ORDERS.>"}`.
- **Supplying your own transform turns the automation off entirely** — including the `KV_` prefix on
  the source name. That is how an **ordinary stream becomes a KV source**
  (`events.processed.>` → `$KV.EVENT_CACHE.>`, a bucket as a materialised view) and how keys can be
  remapped between buckets (`$KV.INVENTORY.warehouse.*.product.>` → `$KV.PRODUCTS.>` turns
  `warehouse.nyc.product.item123` into `item123`).

## Keys are subjects, and nothing escapes them for you

A key is a subject token path under `$KV.<bucket>.`, so a key containing a space, or a dot meaning
something other than a separator, cannot be stored as written — and **the server offers no
escaping** (source: [[s-adr-54-kv-codecs]], **Proposed**). The proposed answer is entirely
client-side: key and value codecs wrapped around a normal bucket handle, with `Base64Codec`
(`"Acme Inc.contact"` → `"QWNtZSBJbmMuY29udGFjdA=="`) and `PathCodec`
(`user/profile/settings` → `user.profile.settings`) as built-ins.

Two consequences an operator meets before the design does:

- **Encoded keys are what `nats kv ls` shows**, not the application's keys — and a watcher written
  against a raw key matches nothing, because a codec encodes the filter's wildcards too unless it
  deliberately does not.
- **A value codec is client-side encryption**: the server stores ciphertext, so compression and any
  server-side reading of values stop being meaningful. It is not the same thing as JetStream
  encryption at rest.

**Key naming is decided before the first `Put`.** Changing it later is a rewrite of the bucket.


## Sharing a bucket with another account

There is no KV-specific sharing mechanism. Because a bucket **is** the stream `KV_<bucket>`, the two
routes are the JetStream ones, and both are in [[cross-account-sharing]]:

- **import the owning account's JetStream API** as a service export and address it with an API
  prefix — one user then manages assets in the other account;
- **mirror or source `KV_<bucket>`** with an `external` block — the second account gets a *copy*,
  with the mirror's lag, and a write there does not reach the original bucket.

**No docs page covers either**, and the public question — "a single account owns a KV store, and I'd
like to share access to this KV store with other accounts, ideally with some restrictions" — has had
**no reply since 2025-06-29** (source: [[s-gh-7017-kv-across-accounts]]). The only public answer is a
single line from a maintainer on the equivalent stream question: "You should be able to import the
foreign account jetstream API and manage it using the API prefix options in clients and CLI"
(source: [[s-gh-5606-cross-account-jetstream]]).

The restrictions half is the part with no public answer at all. A service export of `$JS.API.>` hands
over the account's whole JetStream control plane, not one bucket; narrowing it to a single
`KV_<bucket>` is not documented and this wiki has not verified it.


## Version notes

| server | what arrived |
|---|---|
| **2.6.0** | the JetStream features KV is built on |
| **2.10.0** | sourced buckets, read-replica mirror buckets, compression, bucket metadata |
| **2.11.0** | max-age limit markers, per-key TTL; non-direct gets removed from the spec |

## To verify

- **Why a KV watcher would *miss* updates** is still unexplained, and now known to be unsourced: the
  thread question-bank Q69 was mined from (gh#6746) asks how to watch **many keys on one watcher**, not
  about missed updates, and a search of `nats-io/nats-server` discussions on 2026-08-31 found nobody
  publicly reporting a missed KV update. The row has been corrected; the mechanism ADR-8 does give —
  an ordered consumer that rebuilds itself on a detected gap ([[ordered-consumer]]) — remains a
  candidate cause with no report behind it. The KV-watcher failure people **do** report is
  [[kv-watchers-stall-the-cluster]].
- Whether a **mirror on file storage** is materially slower than on memory storage (Q76) is not
  covered.

## What a bucket costs on disk

A bucket is a stream with `max_msgs_per_subject` set to its history, and that single fact fixes its
on-disk shape (source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`):

- **Block size is 4MB**, always — `max_msgs_per_subject` takes the `defaultKVBlockSize` branch of
  `autoTuneFileStorageBlockSize` (`stream.go:1412–1443`) regardless of how small the bucket is.
  Budget 4MB of slack per bucket: the newest block is never compacted, so a small idle bucket can
  hold several megabytes on disk while reporting a few hundred kilobytes.
- **Each key costs `len($KV.<bucket>.<key>) + 4` bytes in `index.db`**, the stream's full-state
  snapshot, rewritten every two minutes plus jitter. Measured at 40,000 keys: a 708,987-byte
  `index.db`. A bucket with a million keys is tens of megabytes of `index.db` per replica, rewritten
  on that cadence — this is the cost that scales with **key count**, not with value size.
- **Each revision costs `30 + len(subject)` bytes** beyond the value, and `4 + len(headers)` more
  for the headers KV puts on every entry.

Above **1,000,000** subjects the periodic `index.db` write is skipped entirely
(`highCardinalityThreshold`), so a very large bucket stops getting one.

See [[filestore-layout]] for the mechanism and [[jetstream-sizing]] for sizing a volume from it.


## Related

[[stream]] · [[consumer]] · [[ordered-consumer]] · [[message-ttl]] · [[direct-get]] ·
[[object-store]] · [[replicas]] · [[kv-watchers-stall-the-cluster]] · [[cross-account-sharing]] ·
[[account]] · [[mirrors-and-sources]]

## Sources

[[s-adr-8-key-value-store]] · [[s-adr-43-per-message-ttl]] · [[s-adr-17-ordered-consumer]] ·
[[s-docs-stream-config]] · [[s-gh-7017-kv-across-accounts]] · [[s-gh-5606-cross-account-jetstream]] ·
[[s-gh-6746-watch-many-keys]] · [[s-gh-5243-kv-watchers-at-scale]] · [[s-adr-48-kv-ttl]] · [[s-adr-57-kv-subject-transforms]] · [[s-adr-54-kv-codecs]] · [[s-nats-server-filestore-layout]]
