---
title: "docs — Key/Value: Watching"
type: summary
area: [kv, jetstream, clients]
source-url: https://docs.nats.io/learn/key-value/watching.md
source-path: raw/nats-docs/learn/key-value/watching.md
author: nats-io docs
article: "learn/key-value/watching.md"
date: 2026-08-31
version: ""
tags: [watch, end-of-initial-data, IncludeHistory, IgnoreDeletes, UpdatesOnly, MetaOnly, ordered-consumer, key-filter, wildcard]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Key/Value: Watching

The page that closes the **KV-watcher gap** [[key-value]] has carried as an open item. A watch is
snapshot-then-live, and the boundary between the two halves is an explicit signal that clients
deliver in five different ways.

## Key claims

**A watch is two things in one call.** "A watch delivers the current value of every matching key as
an initial snapshot, and then streams every later change as it happens." Underneath it is "an
ephemeral ordered consumer on the backing stream, replaying the last value per key and then following
new writes. You don't configure or manage it: opening the watch creates it, and closing the watch
removes it" ([[ordered-consumer]]).

**The end-of-initial-data signal, and how each client spells it:**

> "After the last snapshot entry and before the first live change, the watch delivers one
> end-of-initial-data signal: a single nil entry. It carries no key and no value."

| client | how the boundary arrives |
|---|---|
| Go, Python | a **nil / None entry** in the same stream as real entries |
| JavaScript | an **`isUpdate` flag** on each entry |
| Java | an **`endOfData()` callback** |
| C# | an **`OnNoData` option** |
| **Rust** | **no marker at all** — you choose snapshot-plus-live or live-only when you open the watch |
| `nats` CLI | consumed silently; you never see it |

**And it is "the most common watch bug".** A loop that treats the nil entry as end-of-stream "will
read the snapshot and see the boundary marker, then quit before every live change that was the reason
to watch. The fix is one line: when an entry is nil, skip it and keep looping."

The signal is also usable: "a dashboard can hold its 'loading' state until the nil entry arrives, then
flip to 'live'… A cache-warming job can populate from the snapshot, treat the nil entry as 'warm'."

**A key filter is a subject filter, and that is a naming decision.** "`*` stands for exactly one whole
token, and `>` for one or more tokens at the end." Therefore:

> "The SKU keys here are single tokens: `widget-blue` is one token, and the hyphen is an ordinary
> character, not a separator. So a filter like `widget-*` **is not a wildcard at all** — `*` is only
> special as a whole token — and it matches nothing. To split keys with a wildcard you'd design them
> with dots, such as `widget.blue` and `widget.red`, so that `widget.*` matches both."

The filter applies to **both** halves, "so a filtered watch is a smaller, cheaper view of the bucket
rather than every change for you to filter afterward."

**Four watch options, and the one pair that conflicts:** `IncludeHistory` (replay full history rather
than the current snapshot), `IgnoreDeletes`, `UpdatesOnly` (no snapshot), `MetaOnly` (entries without
values). "You can combine them, with one exception: `IncludeHistory` and `UpdatesOnly` conflict… and
a client rejects the pair." They are client-side options "implemented as settings on the ephemeral
consumer the watch opens".

**A watch is not a point read.** "It exists only while your process holds it open, and it goes away
when the process ends… Don't open a watch, read the first entry, and close it to fake a point read;
you pay for a consumer and a snapshot to get one value get would have handed you directly."

## Practical takeaways

- **Key naming decides whether a subset can ever be watched.** Flat hyphenated keys cannot be
  prefix-filtered; only a dot introduces a token boundary. That is a design decision made once, at
  the time the keys are named.
- Handle the boundary explicitly, and know which of the five forms your client uses — a Rust reader
  gets no marker at all.
- Every fake point read through a watch costs an ephemeral consumer plus a full snapshot; at scale
  that is [[jetstream-slows-as-consumers-grow]] and [[kv-watchers-stall-the-cluster]].

## Relevance to the wiki

Settles the KV-watcher item on [[key-value]]'s *To verify*: what a watcher delivers, where the
snapshot ends, and the one client-side mistake that makes a watcher appear to "miss" updates — it
stopped reading at the boundary.

## Questions it answers

Contributes to **Q69** (watching many keys with one watcher — the filter is a subject filter, so key
naming decides it) and **Q73**.

## Pages touched

[[key-value]] · [[ordered-consumer]] · [[kv-watchers-stall-the-cluster]] · [[subject-transforms]]

## Sources

The doc page.
