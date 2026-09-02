---
title: "nats-server v2.14.6 source — stream recovery at startup, index.db, the cardinality threshold, and the source scan"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/filestore-recovery-v2.14.6.md
author: "nats-io/nats-server maintainers (source at tag v2.14.6); PRs #8282 and #8516 by the maintainers; release notes"
article: "server/jetstream.go, server/stream.go, server/filestore.go, server/server.go, server/opts.go at v2.14.6, plus the bodies of PRs #8282 and #8516 and the recovery lines of the 2.11.11–2.15.0-preview.1 release notes"
date: 2026-08-27
version: "2.14.6"
tags: [recovery, restore, index.db, recoverFullState, recoverMsgs, rebuildState, highCardinalityThreshold, psim, stree, startingSequenceForSources, sources, sources.db, backward-scan, max_concurrent_io, parallelTaskQueue, since-2.15]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# What the server does when a file-backed stream starts, read at v2.14.6

The source behind question-bank rows 4, 5, 9 and 13. Every line number below is the real one at tag
v2.14.6 and is quoted verbatim in the raw file.

## Key claims

**Two timers.** `Took %s to start JetStream` wraps all of `EnableJetStream` (`jetstream.go:203–207`).
Per stream, `Starting restore for stream '<acc> > <name>'` starts a timer (`:1554–1555`) and
`Restored %s messages for stream … in %v` stops it (`:1658–1659`) **after `a.recoverStream` returns**
(`:1569`). Streams of an account are recovered through one `parallelTaskQueue` sized
`min(64, diskIOSemaphore.cap())` (`:752`; `max_concurrent_io`, 4–8192, `opts.go:2789–2794`).

**What the per-stream timer wraps.** `recoverStream` is `addStreamWithAssignment(…, recovering =
true)` (`stream.go:724–726`). On a single server that calls `setLeader(true, 0)` inline
(`:1053–1060`); `setLeader` calls `subscribeToStream` (`:1314`); and for a stream with `sources`,
`subscribeToStream` calls `setupSourceConsumers` **inline when `Replicas == 1`** and via a
100–600 ms `time.AfterFunc` otherwise (`:4958–4972`). `setupSourceConsumers` runs
`startingSequenceForSources` first (`:4914`).

**The backward scan.** `startingSequenceForSources` (`stream.go:4787–4894`) discards what the
stream knew ("Always reset here"), then walks from `state.LastSeq` **backwards** with
`LoadPrevMsgMulti`, reading the `Nats-Stream-Source` header of each message, removing each source
from the sublist as it is found, and returns early only when every configured source has been seen
(`len(seqs) == expected`, `:4890`). A source with no message in the stream keeps the loop going to
`ErrStoreEOF` — sequence 1. Each step: `LoadPrevMsgMulti` iterates blocks downward under the store's
read lock (`filestore.go:9704–9718`), and `prevMatchingMulti` **loads the whole block into the cache**
if it is not there (`:3199–3204`, `loadMsgsWithLock`, decompressing it). So a stream with
*n* sources is read end to end at every start, and at every leader change on R3, whenever any one
source is idle or empty. Cost: one goroutine, one block at a time, at whatever the volume reads.

**Fixed in 2.15.** PR #8282 (merged 2026-08-20) indexes the sourced sequences as messages arrive and
persists them as **`sources.db` at the stream's root** (not under `msgs/`, "since it should not be
removed if the stream is purged"); replicated streams need the `js_snapshot_sources` feature flag
because the snapshot format changes. PR #8516 (2026-08-28) drops the stream-level scan entirely and
indexes empty sources too ("if new sources were added but not used for an extended period of time,
then backward scans would still happen every single time"). Release v2.15.0-preview.1 (2026-08-24):
"Restarts and leader changes previously required expensive backward scans through the stream to find
the last sourced indices. These are now persisted in an index for instant lookup." No 2.10–2.14
release body mentions the scan. Not in any 2.14.x.

**The store itself: `index.db` first, blocks otherwise.** `newFileStoreWithCreated` tries
`recoverFullState` and on any error resets and calls `recoverMsgs` (`filestore.go:509–549`). A
missing file is silent; any other refusal logs `Recovering stream state from index errored: …`.
`recoverFullState` (`:1927–2216`) reads `index.db`, checks its HighwayHash, rebuilds `psim` subject by
subject, and lists the blocks **without opening them**; it trusts the file only if the last block it
names exists, that block's **last record checksum matches** the one saved (`:2159–2163`), and no
higher-numbered block exists (`:2176–2190`). The refusals, each a `[WRN] Filestore [<stream>] …` line
(`:1861–1867`): `Stream state checksum did not match`, `Stream state outdated, last block has
additional entries, will rebuild` (a SIGKILL after the last periodic write), `Stream state outdated,
found extra blocks, will rebuild`, `Stream state detected prior state, could not locate msg block %d`,
`Stream state encountered internal inconsistency on recover`. The fallback `recoverMsgs`
(`:2454–2563`) opens every `<n>.blk` in order through `recoverMsgBlock` (`:1232–1322`), which — with
no pre-2.10 `.idx` — runs `rebuildState`: **the whole block file read, decrypted, decompressed and
walked record by record** (`:1558–1620`), then `populateGlobalPerSubjectInfo` folds its subjects
into `psim`.

**When `index.db` is written.** `flushStreamStateLoop` ticks every **2 min + up to 30 s of jitter**
per store (`:11904–11906`) and calls the *unforced* `writeFullState`; `stop(delete, writeState)` on a
clean shutdown, and a purge, call the *forced* one (`:12251–12256`). The unforced write returns
`errStateTooBig` without writing when `numSubjects > highCardinalityThreshold` **or** interior
deletes `> highCardinalityThreshold` (`:12000–12010`); the forced write ignores that.

**The threshold, three uses.** `highCardinalityThreshold = 1_000_000` (`:390`, "Above this number of
subjects, index.db may not be written regularly anymore, and certain psim optimisations may not be
used") — (1) the periodic `index.db` write is skipped (`:12006`); (2) `checkSkipFirstBlock` /
`checkSkipFirstBlockMulti` do not intersect the subject index to skip blocks on a filtered read
(`:3519–3521`, `:3544–3546`; added in v2.14.2 / v2.12.10, #8227); (3) the same test on interior
deletes. A code constant, not a config key.

**The index in memory.** `fs.psim *stree.SubjectTree[psi]` (`:197`) with `psi{total uint64; fblk,
lblk uint32}` per subject (`:169–173`); a per-block `fss` tree as well.

**No message cap.** No constant of 10⁹ in the filestore, stream, consumer, memstore, server, options
or API sources; sequences are `uint64`; `max_msgs` is an `int64` whose only validation rewrites 0 or
< −1 to −1 (`stream.go:1713–1718`), and its only other use at creation is the reservation estimate
`max_msg_size × max_msgs` (`:1419–1421`).

## Practical takeaways

- A clean stop makes the **store** recover in one file read; it does nothing for the **source scan**
  on 2.10–2.14. A stream with `sources` whose any source is idle re-reads itself at every start and
  every leader change until 2.15.
- Above a million subjects, or a million interior deletes, treat every restart as an unclean one:
  there is no periodic `index.db`, only the one a clean stop writes.
- `Filestore [<stream>] Stream state …` warnings say *why* the index was refused. No log line names
  the source scan at all; only a goroutine dump shows it.
- On R1 the scan is inside `Restored … in`; on R3 it runs after the line, on the leader, and the
  stream sources nothing until it finishes.

## Relevance to the wiki

The mechanism pages for rows 4, 5, 9 and 13: [[filestore-layout]] (recovery and the threshold's
three uses), [[mirrors-and-sources]] (what a sourcing stream does at every start), the gotcha
[[jetstream-recovery-is-slow]], [[defaults-and-limits]] (the threshold row), and the version
entities. The runs that exercise each path are [[s-nats-server-stream-scale-observed]].

## Questions it answers

Rows **13** (mechanism and fix), **9** (the threshold and the index), **4** and **5** (no cap).

## Pages touched

[[filestore-layout]] · [[mirrors-and-sources]] · [[jetstream-recovery-is-slow]] ·
[[defaults-and-limits]] · [[jetstream-sizing]] · [[stream]] · [[nats-server-2.15-preview]] ·
[[nats-server-2.14]] · [[nats-server-2.12]] · [[consumer-slow-on-a-sparse-stream]]
