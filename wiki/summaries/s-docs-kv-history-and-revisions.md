---
title: "docs — Key/Value: History and revisions"
type: summary
area: [kv, jetstream]
source-url: https://docs.nats.io/learn/key-value/history-and-revisions.md
source-path: raw/nats-docs/learn/key-value/history-and-revisions.md
author: nats-io docs
article: "learn/key-value/history-and-revisions.md"
date: 2026-08-31
version: ""
tags: [revision, history, compare-and-swap, CAS, create, update, optimistic-concurrency, max_msgs_per_subject]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Key/Value: History and revisions

Compare-and-swap, and the one fact about revisions that changes how you reason about a bucket.

## Key claims

**The revision counter is bucket-wide, not per key.**

> "The bucket keeps one counter across all of its keys, and every write — to any key — takes the next
> number. So a revision always increases when you write a key, but not by one each time: writes to
> other keys advance the counter in between."

The worked history makes it concrete — `widget-blue` shows revisions **2** and **5**, with 3 and 4
taken by writes to other keys. This is exactly what it is underneath: the revision is the **stream
sequence**, and a stream sequence is assigned across the whole stream ([[stream]]).

**CAS is exposed as two operations, not one:**

- **`create`** — "writes a key only if it doesn't exist yet. It's CAS against the expectation *this
  key is at revision 0* (no value present)."
- **`update`** — "writes a key only if it's at the revision you name."

```
REVISION=$(nats kv get INVENTORY widget-blue | sed -n 's/.*revision: \([0-9]*\).*/\1/p')
nats kv update INVENTORY widget-blue 40 "$REVISION"
```

**A rejected update is dropped, not queued.** "Optimistic concurrency doesn't wait. When update finds
the key at a different revision than you named, the server returns an error and your value is not
written. If you fire-and-forget an update, a conflict silently loses the write." The re-get-and-retry
loop "is what CAS exists to support. Without that loop you have the same lost-write bug `put` had."

**Read the value and its revision from a single get.** The doc's own retry example carries the
warning in a comment: "Two separate gets could pair a stale value with a fresh revision if a
concurrent write landed in between."

**`put` is unconditional and is the wrong call for a read-modify-write.** "Use put to set a key to a
given value, and update to change it from the value it currently holds."

**History depth is `--history`, is raised in place with `nats kv edit`, and caps at 64.** "The depth
caps at 64." Raising it is not retroactive: "the values written before the raise are already gone,
because at depth 1 each new write dropped the one before it." History "isn't an audit log of the
whole bucket, and it doesn't grow without bound: once a key has more revisions than the depth allows,
the oldest one is removed."

## Practical takeaways

- **Do not derive anything from the numeric gap between two revisions of one key.** The counter is
  bucket-wide; gaps are other keys' writes, not lost data.
- Every read-modify-write needs `update` plus a retry loop. `put` in that position is a lost-write
  bug that only appears under concurrency.
- Raising `--history` starts keeping revisions from that moment; it cannot recover what depth 1
  already dropped.

## Relevance to the wiki

Gives [[key-value]] the CAS primitives by name (`create` = revision 0, `update` = named revision) —
which is the building material for a lock or lease (**Q74**) — and the bucket-wide revision counter,
which no source the wiki had read stated plainly.

## Questions it answers

**Q74** — the primitives a distributed lock or lease is built from.

## Pages touched

[[key-value]] · [[stream]]

## Sources

The doc page.
