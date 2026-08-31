---
title: "docs — JetStream: Subject mapping and transforms"
type: summary
area: [jetstream, core]
source-url: https://docs.nats.io/learn/jetstream/subject-mapping.md
source-path: raw/nats-docs/learn/jetstream/subject-mapping.md
author: nats-io docs
article: "learn/jetstream/subject-mapping.md"
date: 2026-08-31
version: ""
tags: [subject_transform, republish, wildcard, partition, split, Nats-Stream, Nats-Last-Sequence, Nats-Msg-Size, 10052, ADR-30, ADR-36, ADR-28]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Subject mapping and transforms

A whole mechanism the wiki had no page for: rewriting the subject a message is stored under, and
re-emitting stored messages onto a live subject. Prose and CLI only.

## Key claims

**Three places JetStream rewrites a subject:** a stream's **subject transform** (on the way in),
**republish** (on the way out), and a per-source or per-mirror transform (while copying, see
[[mirrors-and-sources]]). "All three use the same small transform language."

### The transform language

A `source → destination` pair; the source is a subject filter with `*` and `>`, the destination a
template:

| token | meaning |
|---|---|
| `{{wildcard(1)}}` | the token the first `*` matched (`$1` is the older spelling of the same thing) |
| `{{partition(n, 1)}}` | hash the first `*` token into one of `n` buckets, `0`…`n-1`; "the same value always lands in the same bucket" |
| trailing `>` | carries across to a `>` in the destination unchanged |
| `{{split(1, -)}}`, `{{splitfromleft(1, 3)}}` | reshape one matched token — split at a bare delimiter (**not `.`**, which already separates tokens) or cut at a character position |

Also `splitfromright`, `slicefromleft`, `slicefromright`. "ADR-30 has the complete list."

**A transform can be tried with no stream at all:**

```
nats server mappings "orders.*" "orders.{{wildcard(1)}}.archived" orders.created
orders.created.archived
```

### Stream subject transform

"A message whose subject matches the transform's source is stored under the rewritten subject, and
any other message is stored under its original subject. **A transform rewrites subjects; it never
drops a message.**" The stream keeps listening on all its configured subjects — the listen set and
the stored subject are separate things.

```
nats stream add ORDERS-SHARDED --subjects "ingest.*" \
  --transform-source "ingest.*" \
  --transform-destination "orders.{{partition(3,1)}}.{{wildcard(1)}}" --defaults
```

```
Subject         │ Count
orders.1.acme   │ 1
orders.1.globex │ 1
orders.2.wayne  │ 1
```

Edit with `nats stream edit --transform-source/--transform-destination`, clear with
`--no-transform`.

### Republish

"Re-emits every message a stream stores onto a second subject, in real time. Core subscribers listen
on that subject and see the data flow by **without creating a consumer**."

```
nats stream edit ORDERS --republish-source "orders.>" --republish-destination "dash.orders.>"
```

Each republished message carries **five headers**: `Nats-Stream`, `Nats-Subject` (the original stored
subject), `Nats-Sequence`, `Nats-Time-Stamp`, and **`Nats-Last-Sequence`** — "the stream sequence of
the previous message *on the same subject*, or `0` if there wasn't one, so a subscriber following one
subject can tell it missed something." Publisher headers are carried through.

`--republish-headers` "sends the headers without the bodies… each message then also carries a
`Nats-Msg-Size` header with the omitted body's byte count." Clear with `--no-republish`.

## The five pitfalls, each a distinct failure

1. **A transform that drops a token a consumer filters on.** "A destination template keeps only the
   tokens you name."
2. **Republish is not a consumer.** "Fire-and-forget, no storage, no acks, no replay. A subscriber
   that's down misses whatever was republished while it was away, and nothing redelivers it."
3. **A republish destination that loops back.** "The destination can't overlap the stream's own
   subjects… the server rejects it as a cycle (**error `10052`**). Send republished messages to a
   separate subject space… and watch for loops that span two streams in one account, **which the
   server can't always catch**."
4. **Editing a transform doesn't rewrite what's already stored.** "To re-namespace existing data, copy
   it into a new stream that sources from the old one with the transform applied."
5. **A partition count is fixed once consumers depend on it.** "Change `partition(3, …)` to
   `partition(4, …)` later and the same customer can hash to a different bucket, so a consumer's
   filter quietly starts covering a different set."

**Not the same as account subject mapping**, "configured on the server, not on a stream", which
"reroutes *core* subjects before they're ever published into a stream".

## Practical takeaways

- `{{partition(n,1)}}` is the supported way to shard a stream deterministically, and the bucket count
  is effectively permanent once consumers filter on it.
- Republish is the cheap way to feed a dashboard off a stream — and it is core NATS, so it is not a
  delivery guarantee.
- `nats server mappings` tests a transform before you commit it to a stream.

## Relevance to the wiki

The source for the new [[subject-transforms]] page. Also gives [[error-codes]] a second, concrete
`10052` case (the republish cycle) alongside the TTL one, and gives [[mirrors-and-sources]] the
pointer to per-source transforms.

## Questions it answers

No bank row directly. Supports **Q24**: `Nats-Last-Sequence` on a republished message is the
per-subject ordering signal a core subscriber gets.

## Pages touched

[[subject-transforms]] · [[mirrors-and-sources]] · [[error-codes]] · [[stream]] · [[nats-cli]]

## Sources

The doc page, which cites
[ADR-30](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-30.md) (transform
functions), [ADR-36](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-36.md)
(where a transform attaches) and
[ADR-28](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-28.md) (republish
headers and loop prevention). **None of the three has been read**; the page states only what the doc
page states.
