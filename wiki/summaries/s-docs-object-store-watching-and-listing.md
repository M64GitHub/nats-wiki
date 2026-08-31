---
title: "docs — Object Store: Watching and listing"
type: summary
area: [objectstore, jetstream]
source-url: https://docs.nats.io/learn/object-store/watching-and-listing.md
source-path: raw/nats-docs/learn/object-store/watching-and-listing.md
author: nats-io docs
article: "learn/object-store/watching-and-listing.md"
date: 2026-08-31
version: ""
tags: [list, watch, nil-sentinel, ObjectInfo, ErrNoObjectsFound]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Object Store: Watching and listing

The page question-bank row **Q75** was expected to be answered by. It describes what list and watch
*do* precisely, and — read for that purpose — it is a **negative result**: it says a list is cheap
and never discusses concurrency, contention or latency at all.

## Key claims

**List is a one-time snapshot of live objects.** "A **list** returns every non-deleted object in the
bucket as a one-time snapshot. It doesn't stay open and it doesn't stream changes." Each entry is
"the object's metadata (name, size, chunk count, description, modification time) but not its bytes".

**The page's own cost claim**: "A list is cheap: it reads metadata, never chunks. You can list a
bucket of thousand-megabyte invoices without moving any of the object data." That is the whole of
what it says about the cost of a list.

**List filters soft-deleted objects.** "When `order-svc` removes an invoice, the object is marked
deleted and its chunks are purged, but a metadata record lingers to mark the deletion. List filters
those out."

**An empty bucket is an empty result, not an error** — "In the client libraries it surfaces as a 'no
objects found' condition you treat as zero results, not as a problem." The chapter's checklist names
the error: "list returns `ErrNoObjectsFound` when there's nothing to list."

**Watch is the live counterpart, ordered, with a nil sentinel.** It "delivers one update each time an
object in the bucket changes, whether that change is a new put, a re-put, or a delete… Updates arrive
in the sequence the bucket recorded them." When caught up it "delivers a single **nil sentinel**: one
empty update that signals 'you're now current; everything after this is a live change.' The CLI
consumes that sentinel for you and keeps printing."

**Watch carries metadata, never bytes — and this is the difference from KV.** "An object's metadata
and its chunks live on two different subjects. A watch subscribes to the metadata side… `analytics`
can watch a bucket of 3 MB invoices and 100 MB media files without any object data crossing the
watch." Against KV: "There, a watch delivers each key's *value* directly, because values are small.
Here, an object can be gigabytes, so the watch delivers only the metadata and leaves the data fetch
to you."

**The pattern is two steps**: "watch to learn *what* changed, then issue a get for the objects whose
bytes you actually need."

**Watch has options the page does not enumerate**: "replaying full history, ignoring deletes, or
skipping the catch-up snapshot to see only new updates", deferred to Reference.

## Practical takeaways

- The nil sentinel is the same end-of-initial-data trap the KV chapter calls "the most common watch
  bug" (see [[s-docs-kv-watching]]); the object-store watch has it too, and the CLI hides it.
- A service that polls `list` in a loop is doing far more work than a watch, and the page says so
  implicitly — watch exists so `analytics` "keeps up with the bucket instead of polling list in a
  loop".

## Notable quotes

> "A list is cheap: it reads metadata, never chunks."

> "Watch tells you what changed; get returns the bytes."

## Relevance to the wiki

**This page does not answer Q75.** It asserts a list is cheap and stops; there is no statement about
what happens while the bucket is being written, which is exactly the reported symptom. The plan named
this page for that row; recording that it does not answer it is the result. The answer had to be
measured instead — `raw/nats-server-src/object-store-observed-v2.14.6.md`,
[[object-store-list-is-slow]].

What it *does* give the wiki: the nil sentinel, the metadata-only watch, `ErrNoObjectsFound`, and the
explicit KV contrast.

## Questions it answers

Q75 (partly — the mechanism it describes is the input to the measured answer, not the answer).

## Pages touched

[[object-store]] · [[object-store-list-is-slow]] · [[key-value]]

## Sources

`raw/nats-docs/learn/object-store/watching-and-listing.md`
