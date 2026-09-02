---
title: "gh#8417 — JetStream file-store ~65x slower than memory-store on KV mirror (83% of seq space is deleted)"
type: summary
area: [kv, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/8417
source-path: raw/gh-discussions/gh-8417.md
author: "@cyqsign (asked); @MauriceVanVeen (chosen answer)"
article: "GitHub Discussion 8417 (Q&A, answered 2026-07-27, closed 2026-08-13)"
date: 2026-07-24
version: "2.14.2"
tags: [kv, mirror, filestore, filter_subject, interior-deletes, linear-scan, last_per_subject, sparse-stream, leafnode]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# gh#8417 — a KV mirror on file storage reads 65× slower than on memory storage

The best-instrumented performance thread in the question bank, and one whose answer is *not* the one
in its title. Opened 2026-07-24 against **nats-server v2.14.2**; answered by a maintainer three days
later; closed by the reporter on 2026-08-03 with "the root cause has been identified and the fix is
clear".

## The report

A hub cluster owns the KV bucket `KV_DNS` on file storage. A leaf node mirrors it **twice**, the two
mirrors differing only in `storage` — `KV_DNS` on memory, `KV_DNS_FILE` on file — both with
`MaxMsgsPerSubject: 1`, `AllowDirect`, `MirrorDirect`, R1, `Mirror.External: $JS.hub.API`. After
sync both hold the same state:

```
Messages:          2,019,878
Bytes:             5.9 GiB
First Sequence:    1
Last Sequence:     11,920,111
Deleted Messages:  9,900,233     <-- 83% of the seq space is holes
Subjects:          2,019,878
```

A KV put on an existing key removes the previous sequence, so a hot key space leaves the sequence
space mostly holes — "~12 M seqs spanned, of which ~9.9 M are deleted holes and only ~2 M are live".

**Observation 1.** The same pull consumer — `DeliverLastPerSubjectPolicy`, `AckNonePolicy`,
`FilterSubject: "$KV.DNS.>"`, 4 MB batches — reads the memory mirror at **266,840 msg/s** (2,019,878
messages in 7.57 s) and the file mirror at a lumpy **~4,000 msg/s** (1.5 k → 8 k → 3.5 k per two-second
window). Ruled out with numbers: disk (`iostat` shows `%util 0.00–0.30`), page cache (pre-warming the
`.blk` files changes nothing), CPU saturation (two or three server threads at 73 % / 20 % / 13 %,
the box 98 % idle), and the `DeliverLastPerSubject` cost (with `MaxMsgsPerSubject=1` the server takes
the fast path and scans sequentially).

**Observation 2.** The file mirror's *initial sync* from the hub was also slow — `msgs=855,017
lag=1,164,860 elapsed=412.5 s`, about 2,000 live messages a second — where the memory mirror synced
the same data "in seconds".

**Attachment 3** compares the two sides on disk for the same 5.89 GiB of live data: the hub's source
holds it in ~5,037 block files and 7.3 GB (81 % live bytes); the leaf's file mirror in ~1,597 files
and 6.0 GB (98 %), "because it replays messages sequentially rather than in-place". Consumer
throughput was ~4 k msg/s on both, so fragmentation alone does not explain it.

## The answer

The maintainer's first reply asked for one experiment: remove the `FilterSubject`. Without it the
file mirror read at **~150,000+ msg/s** (292 k, 131 k, 66 k, 222 k, 202 k per window). The
explanation, quoted because every clause matters:

> "You're not intending to filter, but a filter is passed anyway. This isn't too bad if the server
> can recognize that you're using the same filter subject as the stream uses for ingest, but since
> it's a mirror, the stream has no ingest subjects. So the first `doLinearScan = false`. Then there's
> a check whether there are 4x more messages than there are subjects. However, that uses the
> first/last sequence range, which is huge because you have so many deletes. For every single
> message lookup there is an expensive read through `mb.fss` (per-subject state), with doesn't allow
> to skip ahead since the filter matches everything, so it's wasted additional work for every
> message. The heuristic can potentially be improved, but best is to just not pass a filter subject
> if you don't intend on filtering, then the server always takes the (for your use case) cheaper
> linear scan path."

The linked code is `firstMatching` in `filestore.go`; at v2.14.6 the heuristic is at lines
3093–3103 ([[s-nats-server-mirror]]). The maintainer also said he was "working on an improvement in
the filestore for a situation like this where the number of deletes are greater than the number of
unique subjects" — the interior-delete work that shipped in **v2.14.4** three days after the thread
closed ([[s-relnotes-2.14.4]]).

**Left open.** The slow *initial sync* on file storage: "Have no way to tell at the moment. Could you
package this up into a reproducible example?" The reporter never posted one, so that half of the
title is unexplained in public. This wiki's own run did not reproduce it on one host
([[s-nats-server-mirrors-observed]]).

## Three other things the thread settles

- **A block never starts with a deleted sequence.** "`2.blk` would start at sequence 2000. `1.blk`
  would start at sequence 1, and have deleted entries stored in its `mb.dmap` from 1000-1999. When
  that block is compacted it removes deletes at the tail. A block never starts with deleted
  messages, it can only have interior deletes between messages, or deletes at the tail that can be
  compacted. That is the range of the linear scan."
- **Interior `dmap` entries are not cleaned up** while their block lives; only head and tail
  deletes are pruned by compaction (the reporter's reading of `compactWithFloor`, not contradicted).
- **Do not publish a rollup message to delete a subject hierarchy.** For "delete everything under
  `event.foo.>`" the maintainer's answer is `PurgeStream` with a filter, which stores nothing; a
  rollup message on `event.foo.>` persists and needs a `Nats-TTL` to age out. An atomic swap of
  *distinct* subjects is not possible: "You can do an atomic swap with a rollup, but only for
  replacing that same subject."

## Practical takeaways

- On a **mirror**, a consumer filter that matches every message is a performance bug, not a no-op.
  Leave `filter_subject` empty when you mean "everything". The same filter on the origin bucket is
  harmless, because there it equals the stream's own subject.
- Anything that lists or watches a whole KV bucket **through a file mirror** — a KV watch, `nats kv
  ls`, a `last_per_subject` consumer — passes exactly that filter ([[key-value]]).
- The trigger is the *ratio* of sequence span to subjects, which interior deletes inflate. A KV
  bucket with a hot key space is the canonical case; 2.14.4 made the delete-map lookups cheaper but
  did not change the heuristic ([[s-relnotes-2.14.4]]).
- The intended pattern the reporter was already using — the authoritative bucket on file storage,
  reads from a memory mirror — remains a sound one; the thread just shows it was not needed for
  *this* problem.

## Questions it answers

- **Q76** (why is a KV mirror on file storage far slower than on memory storage) — the consumer
  half, fully; the sync half is a stated unknown.
- Material for **Q2** (what a stream costs beyond the raw bytes: the 81 % / 98 % block packing) and
  **Q9** (subject cardinality: the `fss` read per lookup).

## Pages touched

[[consumer-slow-on-a-sparse-stream]] · [[mirrors-and-sources]] · [[key-value]] ·
[[filestore-layout]] · [[consumer]] · [[nats-server-2.14]]
