---
title: Subject transforms and republish
type: concept
area: [jetstream, core]
since: []
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [subject_transform, republish, wildcard, partition, split, Nats-Stream, Nats-Subject, Nats-Sequence, Nats-Last-Sequence, Nats-Msg-Size, 10052, sharding]
aliases: [subject transform, transform, republish, subject mapping, partition, wildcard, sharding, "{{wildcard(1)}}", "{{partition(3,1)}}", nats server mappings]
sources: [s-docs-subject-mapping, s-adr-57-kv-subject-transforms, s-docs-mirrors-and-sources, s-docs-stream-config, s-docs-kv-watching]
created: 2026-08-31
updated: 2026-08-31
---

# Subject transforms and republish

**A filter chooses which stored messages a consumer sees; a transform changes the subject itself.**
Two different mechanisms with one small template language, plus a third that re-emits stored messages
onto a live subject for core subscribers.

## How it behaves

Three places JetStream rewrites a subject (source: [[s-docs-subject-mapping]]):

| where | what it does |
|---|---|
| **stream subject transform** | rewrites the subject a message is **stored under**, on the way in |
| **republish** | re-emits every stored message onto a second subject, on the way out |
| **source / mirror transform** | rewrites subjects while copying between streams — [[mirrors-and-sources]] |

**A transform rewrites subjects; it never drops a message.** The stream keeps listening on all its
configured `subjects`. A message matching the transform's source is stored under the rewritten
subject; anything else is stored under its original subject. The listen set and the stored subject
are separate things.

**This is not account subject mapping.** That is configured on the server, reroutes *core* subjects
before anything reaches a stream, and is a different topic.

## The transform language

A `source → destination` pair. The source is a subject filter with the usual `*` and `>`; the
destination is a template that pulls matched tokens back by position.

| token | meaning |
|---|---|
| `{{wildcard(1)}}` | the token the first `*` matched; `{{wildcard(2)}}` the second, and so on. `$1` is the older spelling of the same thing |
| `{{partition(n, 1)}}` | hash the first `*` token into one of `n` buckets, `0`…`n-1`. **The same value always lands in the same bucket** |
| trailing `>` | carries across to a `>` in the destination unchanged — `orders.>` → `dash.orders.>` |
| `{{split(1, -)}}` | split one matched token wherever a bare delimiter appears. Written **without quotes**, and it cannot be `.`, which already separates tokens |
| `{{splitfromleft(1, 3)}}` | cut one matched token at a character position; `splitfromright`, `slicefromleft` and `slicefromright` are the siblings |

ADR-30 holds the complete list and has not been read here; the table above is what
`learn/jetstream/subject-mapping.md` documents.

**Test a transform with no stream at all:**

```
nats server mappings "orders.*" "orders.{{wildcard(1)}}.archived" orders.created
orders.created.archived
```

## Deterministic sharding, which is the main reason to use one

`{{partition(n, 1)}}` is the supported way to split a subject space into a fixed number of buckets so
consumers can divide the work by bucket:

```
nats stream add ORDERS-SHARDED \
  --subjects "ingest.*" \
  --transform-source "ingest.*" \
  --transform-destination "orders.{{partition(3,1)}}.{{wildcard(1)}}" \
  --defaults
```

```
Subject         │ Count
orders.1.acme   │ 1
orders.1.globex │ 1
orders.2.wayne  │ 1
```

Each customer hashes to the same bucket every time, so a consumer filtered to `orders.1.>` always
reads the same share. Edit with `nats stream edit --transform-source/--transform-destination`, clear
with `--no-transform`.

**The bucket count is effectively permanent.** Change `partition(3, …)` to `partition(4, …)` and the
same key can hash into a different bucket, "so a consumer's filter quietly starts covering a different
set". Choose `n` the way you would for any partitioned system — and note this is the same reason
[[worker-pool]] scales workers within *one* consumer rather than by repartitioning.

## Republish

Re-emits every message the stream stores onto a second subject, **in real time**, so plain core
subscribers can watch a stream without creating a consumer or replaying anything:

```
nats stream edit ORDERS --republish-source "orders.>" --republish-destination "dash.orders.>"
```

```
nats sub "dash.orders.>"

[#1] Received on "dash.orders.created"
Nats-Stream: ORDERS
Nats-Subject: orders.created
Nats-Sequence: 5
Nats-Time-Stamp: 2026-05-22T11:02:00Z
Nats-Last-Sequence: 4
```

**Five headers**, and the fifth is the useful one: `Nats-Last-Sequence` is "the stream sequence of the
previous message *on the same subject*, or `0` if there wasn't one" — so a subscriber following one
subject can tell that it missed something, which a fire-and-forget subscription otherwise cannot.
Headers the publisher set are carried through.

`--republish-headers` sends headers without bodies, for subscribers that only need to know something
changed; each message then carries `Nats-Msg-Size` with the omitted body's byte count. Clear with
`--no-republish`.

## The same rule, one layer up: a KV key filter

A [[key-value]] watch's key filter is matched exactly like a subject filter, which makes key naming a
transform-shaped decision even when no transform is involved: "`widget-blue` is one token, and the
hyphen is an ordinary character, not a separator. So a filter like `widget-*` is not a wildcard at all
… To split keys with a wildcard you'd design them with dots, such as `widget.blue` and `widget.red`"
(source: [[s-docs-kv-watching]]).

The same reason `{{partition(n,1)}}` operates on a whole token is the reason `widget-*` matches
nothing: **`*` is a token, never a prefix.**

## Limits and failure modes

- **Republish is not a consumer.** "Fire-and-forget, no storage, no acks, no replay. A subscriber
  that's down misses whatever was republished while it was away, and nothing redelivers it." Use it
  to watch a stream live; use a [[consumer]] when a reader must catch up.
- **A republish destination that loops back is rejected — but not always.** The destination cannot
  overlap the stream's own subjects; the server refuses it as a cycle with **`10052`**
  ([[error-codes]]). Send to a separate subject space (`dash.orders.>`, not something under
  `orders.>`) — and note the docs' own caveat: loops that span **two streams in one account** are
  ones "the server can't always catch".
- **Editing a transform does not rewrite what is already stored.** Only messages stored after the
  change get the new subject. To re-namespace existing data, copy it into a new stream that sources
  from the old one with the transform applied ([[mirrors-and-sources]]).
- **A destination keeps only the tokens you name.** Rewrite `orders.*` to `orders.archived` without
  `{{wildcard(1)}}` and every order is stored under one subject, where no consumer can filter by
  type. Keep every token a downstream filter needs.
- **A transform changes what `nats stream subjects` shows, not what the stream listens on.** A
  consumer filter must be written against the **stored** subject, not the published one.

## Related

[[stream]] · [[consumer]] · [[mirrors-and-sources]] · [[key-value]] · [[worker-pool]] ·
[[error-codes]] · [[publishing]] · [[jetstream-slows-as-consumers-grow]] · [[nats-cli]]

## Sources

- [[s-docs-subject-mapping]] — the language, the three places, republish and its headers, and the
  five pitfalls.
- [[s-adr-57-kv-subject-transforms]] — subject transforms as KV uses them.
- [[s-docs-mirrors-and-sources]] — the per-source transform, applied while copying.
- [[s-docs-stream-config]] — the `subject_transform`, `republish` and per-source
  `subject_transforms` config fields.
- [[s-docs-kv-watching]] — a KV key filter is a subject filter, so `*` is a whole token there too.
