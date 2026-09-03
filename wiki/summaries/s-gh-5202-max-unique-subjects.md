---
title: "gh#5202 — Max unique subjects in a single jetstream"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/5202
source-path: raw/gh-discussions/gh-5202.md
author: "@suchen-sci (asked); @derekcollison (chosen answer); @bjorndm (community)"
article: "GitHub Discussion 5202 (Q&A, opened and answered 2024-03-12)"
date: 2024-03-12
version: "2.10.9"
tags: [subjects, cardinality, psim, stree, adaptive-radix-tree, memory, kv, since-2.10]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-03
---

# gh#5202 — how many distinct subjects one stream can hold, and where the index lives

The version-layer answer to question-bank row 9: **since 2.10.9 the per-subject index is an
in-memory adaptive radix tree**, and the maintainer names what it holds.

## The question

A stream on `events.id.>` with an unbounded set of ids — `events.id.123`, `events.id.abc` — *"how
many different subjects is allowed in max? Is it possible to put like 50000 different subjects into a
single jetstream?"*

## The answer (@derekcollison, chosen)

> Currently the recent versions of the server, >= 2.10.9, use a modified Adaptive Radix Trie to
> store in memory index data per subject that identifies metadata about the subject. Currently that
> is number of messages and first and last blocks. Assuming you are talking about a filestore backed
> stream.
>
> The stree (ART impl) uses path compression and lazy expansion so is efficient at the types of
> subjects you have mentioned, since only the suffix needs to be stored at the leafs.
>
> We do have plans to implement a version that can be stored to disk as well, but currently this is
> all kept in memory. 50k subjects should be fine.

At v2.14.6 that is still the design: `fs.psim *stree.SubjectTree[psi]` with `psi{total uint64;
fblk, lblk uint32}` per subject (`filestore.go:169–173`, `:197`), plus a per-block `fss` tree
(`:242`) — quoted in [[s-nats-server-filestore-recovery]]. The on-disk version the maintainer planned
has not shipped as of 2.14.6; `index.db` is a periodic *snapshot* of the tree, not a substitute for it.

A community reply: one million small JSON values into a single KV bucket in **2 min 30 s** on a
two-year-old MacBook Pro — a data point for the write side only.

## Practical takeaways

- There is **no configured maximum** for subjects per stream; the bound is RAM for the tree.
- What the tree holds per subject is small (a count and two block indexes) plus the suffix of the
  subject after path compression — which is why long common prefixes cost little and random
  suffixes (UUIDs) cost the most.
- Since 2.10.9. Older servers used a different structure; nothing older is verified here.

## Relevance to the wiki

The `since:` fact for the subject index, from the person who wrote it. Pairs with
[[s-gh-8333-high-cardinality-subjects]] (the RAM figure) and [[s-synadia-how-many-subjects]]
(the per-subject byte estimate).

## Questions it answers

Row **9** (version layer).

## Correction from the source tree (2026-09-03)

The maintainer's ">= 2.10.9" is off by one. `server/stree/` does not exist at tag v2.10.9;
`fileStore.psim` is `map[string]*psi` there and `*stree.SubjectTree[psi]` at v2.10.10, whose release
body lists the change as "NumPending calculations and subject index memory in filestore and memstore
(#4960, #4983)". The claim above stays as the thread made it; the wiki pages say **2.10.10**
(evidence: `raw/nats-server-src/stree-arrival-v2.10.10.md`; [[s-relnotes-2.10]]).

## Pages touched

[[filestore-layout]] · [[jetstream-sizing]] · [[nats-server-2.10]]
