---
title: "ADR-8 — JetStream based Key-Value Stores"
type: summary
area: [kv, jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-8.md
source-path: raw/adr/ADR-8.md
author: "@ripienaar"
article: "ADR-8: JetStream based Key-Value Stores"
date: 2021-06-30          # ADR date; revision 13 dated 2026-02-02
version: "2.6.0+"         # KV features land in 2.6.0; later revisions require 2.10 and 2.11
tags: [kv, bucket, stream-mapping, watch, tombstone]
aliases: [ADR-8]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-8 — JetStream based Key-Value Stores

Status **Implemented**; 13 revisions, the latest 2026-02-02. **Skipped for this wiki:** the Go
`KV`, `Entry`, `Status` and `KeyValueManager` interfaces, the client-API naming discussion and the
Consul/etcd prior-art survey — per-language client API is out of scope here. What follows is the
part an operator can see: **a KV bucket is a stream, and this ADR says exactly which stream.**

## Key claims

### A bucket is a stream with fixed properties

| property | value the ADR mandates |
|---|---|
| stream name | **`KV_<Bucket Name>`** |
| ingest subjects | **`$KV.<Bucket Name>.>`** |
| history per key | `max_msgs_per_subject` — **maximum 64, minimum 1**; use 1 when the user supplies no value |
| `discard` | **always `new`** |
| `rollup_hdrs` | **always `true`** (safe key purges that delete history require it) |
| `deny_delete` | **always `true`** |
| `allow_direct` | **always `true`** — modifiable out-of-band only, never through a KV bucket update |
| storage | write replicas are **file** backed, R value may vary |
| overall key TTL | the stream's `max_age` |
| value size cap | `max_msg_size` |
| bucket size cap | `max_bytes` |
| compression | set `compression: "s2"` if requested |
| placement, republish, metadata | allowed |
| **maximum number of keys** | **cannot currently be limited** |

### The `max_age` / `duplicate_window` rule

If a key TTL is supplied (`max_age` > 0), the client must set `duplicate_window` so that:

1. `max_age` **greater than** 2 minutes → `duplicate_window` must be **2 minutes**;
2. `max_age` **≤** 2 minutes → `duplicate_window` must equal `max_age`.

If no key TTL is supplied, `duplicate_window` may be left unset — **"The server will set it to
2 minutes if not supplied."** A later note adds that when `duplicate_window` is simply omitted the
server applies rule 2 itself, so no client code is needed.

### Consistency

> "We do not provide read-after-write consistency. Reads are performed directly to any replica,
> including out of date ones. If those replicas do not catch up multiple reads of the same key can
> give different values between reads."

A healthy, well-performing cluster will *mostly* return consistent values, "but this should not be
relied on to be true." Read-after-write was supported historically and is **deprecated**.

### Reads, writes, deletes

- **Write** — a plain JetStream publish. Key `auth.username` in bucket `CONFIGURATION` is a request
  to **`$KV.CONFIGURATION.auth.username`**.
- **Compare-and-set** uses the **`Nats-Expected-Last-Subject-Sequence`** header. The special value
  `0` means "only accept if this is the first message on the subject", and it is **purge-aware**.
- **Read** — via the direct API **`$JS.API.DIRECT.GET.<STREAM>.<SUBJECT>`**, which "should be used
  for performing all gets on a bucket if direct is enabled". The non-direct path
  (`stream_msg_get_request` with `last_by_subj`) is explicitly marked as supported **for legacy
  buckets only**: "we do not support disabling direct get on any buckets".
- **Delete** — publishes a **new message** with a nil body and the header **`KV-Operation: DEL`**.
  History is preserved.
- **Purge** — publishes **`KV-Operation: PURGE`** *plus* **`Nats-Rollup: sub`**, which instructs the
  server to place the purge message and then **delete all messages for that key up to before it**.
  An optional TTL on the purge adds **`Nats-TTL`**.
- Deleted data carries `KV-Operation` set to `DEL` or `PURGE`; a basic get turns that into a
  *key not found* error, while watchers and history surface it as an entry with the operation set.

### Watch, history and key listing

- **Watch** — an **ephemeral ordered consumer** started at **`last_per_subject`**, so it opens with
  the latest value for every matching key. Watching multiple keys is done with **multiple filter
  subjects**. Options: `IncludeHistory`, `IgnoreDeletes`, `MetaOnly`, `UpdatesOnly`. Default with no
  options: all `last_per_subject` values **including delete and purge operations**.
- **End of initial data** — signalled the first time any message has `Pending == 0`. It **must
  always be sent**, including when the bucket is empty.
- **History** — an ephemeral consumer filtered by subject reading with `deliver_all`; the latest
  value has `Pending == 0`.
- **Keys** — "done using a **headers-only** Consumer set to deliver **last per subject**", parsing
  the key out of the subject and skipping delete/purge operations. **No values are transferred.**
- Deleting a bucket removes the stream entirely.

### Limit markers (2.11+)

With marker TTLs enabled, clients receive a **`Nats-Marker-Reason`** header:

| value | client behaviour |
|---|---|
| `MaxAge` | treat as `PURGE` |
| `Purge` | treat as `PURGE` |
| `Remove` | treat as `DEL` |

Enabling them requires `allow_msg_ttl: true` and a `subject_delete_marker_ttl` **longer than a
second**, and **NATS Server with API level 1 or newer (2.11+)** — which clients should assert with
`$JS.API.INFO`, **not** with the connected server's version string.

### Version history that matters

| server | what arrived |
|---|---|
| **2.6.0** | the JetStream features KV is built on |
| **2.10.0** | sourced buckets, read-replica mirror buckets, compression, metadata |
| **2.11.0** | max-age limit markers; per-key TTL via per-message TTL ([[s-adr-43-per-message-ttl]]) |

## Relevance to the wiki

The whole operator view of KV: what to look for in `nats stream info KV_<bucket>`, why a delete
*adds* a message, why `nats kv` reads can be stale, and which server version each capability needs.

## Questions it answers

Q70 (counting keys without fetching values — a headers-only, last-per-subject consumer), Q71
(per-key TTL, and that it needs 2.11), Q72 (why delete/purge do not immediately reclaim space).
Q69 in part (watching many keys = multiple filter subjects; the "misses updates" half needs the
linked thread).

## Pages touched

[[key-value]] · [[stream]] · [[consumer]] · [[message-ttl]] · [[direct-get]]
