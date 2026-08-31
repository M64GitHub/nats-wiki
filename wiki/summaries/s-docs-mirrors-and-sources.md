---
title: "docs.nats.io — Mirrors and sources"
type: summary
area: [jetstream, topology]
source-url: https://docs.nats.io/learn/jetstream/mirrors-and-sources.md
source-path: raw/nats-docs/learn/jetstream/mirrors-and-sources.md
author: NATS documentation (Synadia Communications, Inc.)
article: Mirrors and sources
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [mirror, sources, lag, subject_transforms, filter_subject, external, 10060]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Mirrors and sources

The two ways to build one stream from another, the table that separates them, and the four
configuration mistakes — one of which fails **silently**.

## Key claims

**A mirror is an exact, read-only copy of one stream.**

- "The copy is exact. A message in the mirror keeps the **same sequence number, the same timestamp,
  and the same subject** it had upstream."
- "A mirror is read-only. You can't publish to it directly, because **it listens on no subjects of
  its own**."
- "A mirror keeps its **own retention**" — the upstream may keep seven days while the mirror keeps
  forever.
- "**Its configuration is fixed at creation.** You can't point a mirror at a different upstream or
  add a filter later; to change any of that you delete it and create it again."

**Sources are the inverse: many upstreams merged into one stream.**

- "Messages from one upstream keep their own order, but **across upstreams there's no ordering
  guarantee**, and the aggregate gives them **fresh sequence numbers** as they arrive."
- "A sourced stream can also listen on its own subjects" and accept direct publishes.
- "Sources can also change after creation. You add an upstream, drop one, or adjust a filter by
  updating the stream config — no need to delete and recreate."

**The comparison table, verbatim:**

| | Mirror | Source |
|---|---|---|
| Upstreams | exactly one | one or many |
| Sequence numbers | kept from the upstream | fresh, interleaved across sources |
| Own subjects, direct publishes | no — read-only | yes, optional |
| Change the config later | no — delete and recreate | yes — add, drop, or edit sources |

**Creating them:**

```
nats stream add ORDERS-ARCHIVE --mirror ORDERS
nats stream add ALL-ORDERS --source ORDERS-US --source ORDERS-EU --source ORDERS-APAC
nats stream info ORDERS-ARCHIVE     # Mirror Information: Stream Name, Lag, Last Seen
```

`nats stream info` on a sourced stream carries a **Source Information** block **per upstream**, each
with its own `Lag` and `Last Seen`, "because each source replicates on its own".

**Four pitfalls, stated as such:**

1. **"Treating a mirror as writable."** A publish lands "in the origin `ORDERS` stream that owns that
   subject — never in `ORDERS-ARCHIVE`". Forcing it with a `Nats-Expected-Stream: ORDERS-ARCHIVE`
   header is rejected with **`expected stream does not match` (error `10060`)**.
2. **"Treating mirror contents as real-time."** "A mirror is eventually consistent … During a burst
   of writes, its `Lag` climbs above `0` until it catches up … treat a lag that climbs and stays high
   as a sign the mirror can't keep pace."
3. **"Combining a filter with a transform on one source."** "On a single source or mirror entry, you
   can set `filter_subject` **or** `subject_transforms`, **but not both**: the server rejects a
   config that sets both." A transform "filters and renames in one step".
4. **"Cross-domain config that fails silently."** Reaching another account or domain needs the
   `external` block plus matching exports and imports, and **each of the three subjects has a
   required export type**: the consumer API and flow-control subjects are **service** exports
   ("because they work as request and reply"); the delivery subject is a **stream** export ("because
   the messages flow one way"). "Get a type wrong and replication doesn't fail with an error; **the
   mirror never catches up**."

**The full field set** — `filter_subject`, `subject_transforms`, `opt_start_seq`, `external` — is in
the generated stream-configuration reference; ADR-59 is named as the authoritative spec.

## Practical takeaways

- **"Fixed at creation" is the design constraint that matters.** A mirror's upstream, filter and
  transform are chosen once. The docs note this is cheap to redo — "the upstream still holds the
  data" — but it is a delete-and-recreate, not an edit.
- **`Lag` is the number to alert on**, and the sourced-stream case needs one alert per upstream, not
  one per stream.
- **The silent failure is the export *type*, not the subject.** A wrong `stream`/`service` choice
  produces a mirror that simply never catches up, with no error anywhere — the same failure shape as
  a missing `allow_direct` in [[s-docs-get-direct]].

## Notable quotes

> "Get a type wrong and replication doesn't fail with an error; the mirror never catches up."

## Relevance to the wiki

The whole of [[mirrors-and-sources]]; the DR reading is [[s-docs-mirrors-as-dr]] and the
`mirror_direct` interaction is in [[s-adr-31-direct-get]].

## Questions it answers

Groundwork for Q45 (multi-region availability) and Q76 (KV mirror performance); neither is closed by
this page alone.

## Pages touched

[[mirrors-and-sources]] · [[stream]] · [[direct-get]] · [[error-codes]] · [[replicas]] ·
[[key-value]] · [[message-ttl]]
