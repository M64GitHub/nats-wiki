---
title: "docs — Object Store: Chunking"
type: summary
area: [objectstore, jetstream]
source-url: https://docs.nats.io/learn/object-store/chunking.md
source-path: raw/nats-docs/learn/object-store/chunking.md
author: nats-io docs
article: "learn/object-store/chunking.md"
date: 2026-08-31
version: ""
tags: [chunk-size, max_payload, NUID, orphan-chunks, digest, 128KB]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — Object Store: Chunking

The one page in the whole 861-page docs tree that discusses **per-message overhead** for the object
store, and the only hand-written page that states the default chunk size and what bounds it.

## Key claims

**The default chunk size is 128 KB**, stated in prose: "The default chunk size is **128 KB**." At
that default "a 3 MB file lands in roughly 24 chunks", and 200 MB would land 1,600.

**The chunk size is per put and is a plain byte count**: `nats object put INVOICES file.pdf
--chunk-size 65536`, `--chunk-size 524288`. Re-putting over an existing object needs `--force`.

**The hard ceiling is `max_payload`.** "Keep each chunk under the server's maximum payload
(`max_payload`, 1 MB by default); a chunk larger than that is rejected and the put fails." The page
adds a second ceiling: "or any smaller max message size an operator has set on the backing stream".
Its mechanism sentence says the **server** rejects it — "the server rejects the oversized message
rather than splitting some other way" — which the wiki's own run contradicts (see below).

**The guidance the ADR never gave.** "Don't tune the chunk size to chase a benchmark; the 128 KB
default fits almost every file and stays well under the default payload limit." And the two
directions of failure:

- too small — "a single file becomes thousands of tiny messages. Each chunk is a NATS message that
  carries its own protocol framing (headers and subject routing on top of the slice of bytes), so
  very small chunks waste storage on per-message overhead and slow puts and gets down";
- too large — the put fails outright at `max_payload`.

**No number is attached to that per-message overhead** anywhere on the page.

**A failed put leaves no half-object, by two mechanisms.** The metadata is last, so "an interrupted
put never produces a gettable object". Additionally, "when the client survives the failure it also
purges the partial chunks it already wrote". The exception is named: "A process killed mid-put runs
no cleanup, so the chunks it had already written stay in the stream as **orphans**: invisible to get,
because no metadata points at them, but still holding storage until the bucket's limits or age
reclaim them."

**A re-put never merges into old bytes.** "Each put gets a fresh **NUID**: a unique identifier
generated for that put alone, separate from the object's name… When you put the same object name
twice, the second put's chunks never overlap the first's."

**Get is reassemble-then-verify**, and "a single missing or reordered chunk changes [the digest] and
the get refuses to return". `nats object get` "exits non-zero on a failed reassembly or digest
mismatch".

## Practical takeaways

- Orphan chunks are the object store's one silent disk leak, and the only stated cause is a hard
  client crash mid-put. Nothing in the docs offers a way to find or reclaim them short of the
  bucket's own limits.
- The chunk-size decision is bounded on both sides but the page gives no way to compute the small
  side, because it never states the per-message overhead.

## Notable quotes

> "Don't tune the chunk size to chase a benchmark; the 128 KB default fits almost every file and
> stays well under the default payload limit."

> "A process killed mid-put runs no cleanup, so the chunks it had already written stay in the stream
> as orphans."

## Relevance to the wiki

Settles the open `## To verify` item on [[object-store]] — whether any source gives chunk-size
guidance beyond "clients may tune this". This page does. It also supplies the orphan-chunk failure
mode, which no ADR describes, and it is the page whose unnumbered per-message overhead
[[filestore-layout]] can now put a figure against (docs issue #33).

## Questions it answers

Q75 (background only — the mechanism, not the latency).

## Pages touched

[[object-store]] · [[filestore-layout]] · [[jetstream-sizing]] · [[defaults-and-limits]]

## Sources

`raw/nats-docs/learn/object-store/chunking.md` · run against the server in
`raw/nats-server-src/object-store-observed-v2.14.6.md`
