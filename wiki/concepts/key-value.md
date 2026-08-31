---
title: Key-Value
type: concept
area: [kv, jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [kv, bucket, tombstone, watch, direct-get]
aliases: [KV, key value, KV bucket, KV_]
sources: [s-adr-8-key-value-store, s-adr-43-per-message-ttl, s-adr-17-ordered-consumer, s-docs-stream-config]
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
| **Watch** | ordered consumer starting at **`last_per_subject`**, so it opens with the newest value of every matching key. Multiple keys = **multiple filter subjects**. |
| **History** | ordered consumer filtered by subject, reading with `deliver_all`. The latest value is the one with `Pending == 0`. |
| **Keys** | a **headers-only** consumer set to **deliver last per subject** — keys are parsed out of the subject and delete/purge operations skipped. **No values cross the wire.** |

That last row is the answer to "how do I count keys without fetching them": key listing already
transfers no values.

**Watch options**: `IncludeHistory`, `IgnoreDeletes`, `MetaOnly`, `UpdatesOnly`. The default with no
options sends every `last_per_subject` value **including delete and purge operations**.

**End of initial data** is signalled the first time a message has `Pending == 0`, and the spec
requires the signal to be sent **always** — including for an empty bucket.

Because watches and key listings create and drop ephemeral consumers, a busy KV workload shows up
as consumer churn; see [[ordered-consumer]] and the memory note on [[jetstream-sizing]].

## Limit markers and per-key TTL

Since **2.11**, KV supports a TTL per key, built on per-message TTL
(source: [[s-adr-43-per-message-ttl]], [[s-adr-8-key-value-store]]). With limit markers enabled,
clients receive a **`Nats-Marker-Reason`** header:

| value | treat as |
|---|---|
| `MaxAge` | `PURGE` |
| `Purge` | `PURGE` |
| `Remove` | `DEL` |

Enabling markers requires `allow_msg_ttl: true` and a `subject_delete_marker_ttl` **longer than a
second**, and a server at **API level 1 or newer (2.11+)**. The spec is specific that clients should
assert this with **`$JS.API.INFO`, not the connected server's version string**.

## Version notes

| server | what arrived |
|---|---|
| **2.6.0** | the JetStream features KV is built on |
| **2.10.0** | sourced buckets, read-replica mirror buckets, compression, bucket metadata |
| **2.11.0** | max-age limit markers, per-key TTL; non-direct gets removed from the spec |

## To verify

- **Why a KV watcher would *miss* updates** (question-bank Q69) is not explained by ADR-8. The
  mechanism it does give — an ordered consumer that rebuilds itself on a detected gap
  ([[ordered-consumer]]) — is a candidate cause but the linked thread has not been read.
- **KV sources and mirrors** are delegated to ADR-57, **key/value codecs** to ADR-54, and
  **per-key TTL detail** to ADR-48. None of the three has been ingested.
- Whether a **mirror on file storage** is materially slower than on memory storage (Q76) is not
  covered.

## Related

[[stream]] · [[consumer]] · [[ordered-consumer]] · [[message-ttl]] · [[direct-get]] ·
[[object-store]] · [[replicas]] · [[kv-watcher-misses-updates]]

## Sources

[[s-adr-8-key-value-store]] · [[s-adr-43-per-message-ttl]] · [[s-adr-17-ordered-consumer]] ·
[[s-docs-stream-config]]
