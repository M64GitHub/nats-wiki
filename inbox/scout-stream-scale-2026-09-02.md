# Scout — stream scale ceilings and the filestore: rows 4, 5, 9, 13 (2026-09-02)

**Why this topic.** Section 2 of `inbox/scout-backlog.md`, and step 3 of
`inbox/plan-the-runnable-scouts-2026-09-02.md` (phase B). Four open rows that are one question —
*how big can one stream get before something bends* — asked from four directions: a message cap, a
`MaxMsgs` figure, a subject count, a restart that took six minutes. Two of the four are runnable on
the lab (`tools/lab/`), and the third is arithmetic the wiki already half-owns.

| row | question | asked at | state before this scout |
|---:|---|---|---|
| **4** | Is there a practical cap on the number of messages in a single stream? | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) | open |
| **5** | What is the largest known-good value for `MaxMsgs` on a stream? | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) | open; the backlog expected `no-public-answer` |
| **9** | Does a high-cardinality subject space hurt stream performance? | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) | open; [[filestore-layout]] already carries `index.db` at `len(subject) + 4` per subject and the **1,000,000** `highCardinalityThreshold`, unconnected to the row |
| **13** | Why is JetStream startup and recovery slow with tens of millions of messages? | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) | open; `raw/nats-server-src/filestore-observed-v2.14.6.md` §8 measured recovery at 279,653 messages and found *no* difference with and without `index.db` — recorded so nobody derives a claim from it |

**Everything below was fetched or read on 2026-09-02.** Nothing is ingested. The six threads were
pulled through the GitHub GraphQL API into the session scratchpad and are quoted from there; at
ingest they are saved verbatim under `raw/gh-discussions/`. Source lines are from
`server/filestore.go`, `server/stream.go` and `server/jetstream.go` at tag **v2.14.6**, fetched
today from raw.githubusercontent.com; the release bodies are the GitHub releases API
(`repos/nats-io/nats-server/releases`, 291 releases, 198 of them 2.10–2.14), read in the
scratchpad only — phase D fetches them into `raw/`.

**The shape of the answers, in one paragraph.** Row 13 is **unanswered upstream and answerable
here**: the reporter posted a goroutine dump that the maintainers never read back, and it shows
the six minutes were not spent rebuilding the index at all — the store was recovered, and the
time went into `startingSequenceForSources`, a **backward scan of the whole stream** that a stream
with `sources` makes at every start to find the last message it received from each source. The
reporter's stream had about twenty sources; one that had gone quiet (or never delivered) sends the
scan to sequence 1 — 7 GB read at 20 MB/s is 6 minutes. The maintainers fixed exactly this for
2.15 (`sources.db`, PR #8282 in `v2.15.0-preview.1`, and #8516), and their release note says so:
*"Restarts and leader changes previously required expensive backward scans through the stream to
find the last sourced indices."* At 2.14.6 the scan is still there. Underneath it sits the general
answer the row also needs: with `index.db` intact and matching, recovery reads one file and stats
the blocks; when it is missing, stale, or never written — and above **1,000,000** subjects or
interior deletes it is *never written periodically* — every block is read end to end. That last
clause is also row 9's other half: cardinality costs RAM (a maintainer: *"in the order of 100 megs
of RAM"* per million small subjects; Synadia: *"roughly a few hundred bytes"* each), and above the
threshold it costs every restart. Rows 4 and 5 have the same answer from two maintainers: there is
**no cap** — no constant in the server, sequences are `uint64`, a maintainer showed a stream at
**1,174,510,552** messages — and *"practically you will eventually run out of some kind of
resource, be it disk space or memory space on the servers (as they maintain some per subject
indexing)"*. Row 5 is therefore not `no-public-answer`: the public answer is that no such number
exists, and the page states what bounds it instead. Row 4's reporter never reproduced the discard
they saw, and the thread says nothing about their limits, so that half stays unexplained.

---

## The candidates

### Row 13 — startup and recovery

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 1 | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) — *JetStream startup seems slow for ~50M messages* · General · opened 2026-04-02 by @zig · **no answer chosen, no maintainer reply after the goroutine dump** · last message 2026-04-13, the asker's, unanswered · v2.12.5 | R1, file, S2 compression, `max_age: 7d`, **about twenty `sources`**, 6 subjects, 50,319,725 messages, 39 GiB reported / ~7 GB on disk (Ceph, "> 200MB/s"). Log: `Restored 50,005,377 messages for stream 'project > project-event' in 6m38.284s`; the sibling stream did 274,003 in 1.921 s; `Healthcheck failed` repeated throughout. Shutdown log shows the clean path (`Initiating JetStream Shutdown…`, `JetStream Shutdown`, `Server Exiting..`). During the restore: < 2 cores, ~20 MB/s constant reads, no writes, 1.4 GB RSS under a 1800 MiB `GOMEMLIMIT`. @wallyqs: *"is it a version past v2.11.11? newer versions do this in parallel"*; @derekcollison: *"On a clean shutdown startup should be very fast. If the shutdown is not clean the server will need to rebuild the metadata and indexes"* — then *"Ok that does not seem normal given not that many subjects"* and a request for a CPU profile. The `stacksz` the reporter posted has goroutine 111 in `startingSequenceForSources` → `LoadPrevMsgMulti` → `prevMatchingMulti` → `loadMsgsWithLock` → `loadBlock` (`stream.go:4311`, `filestore.go:8597/2967/7784/7729` at 2.12.5), 36 `parallelTaskQueue` workers otherwise idle. Nobody replied to it. Last question, still open: *"is it true also in standalone mode that it should be fast after a clean shutdown?"* | 13 | [[filestore-layout]], [[mirrors-and-sources]], [[jetstream-sizing]], [[kubernetes-storage]], the new gotcha, [[nats-server-2.12]], [[nats-server-2.15-preview]] | **★** unanswered, runnable |
| 2 | `server/stream.go` at v2.14.6, **4787–4895** (`startingSequenceForSources`: *"Always reset here"*; walks from `state.LastSeq` backwards with `LoadPrevMsgMulti`, one `Nats-Stream-Source` header at a time, deleting each source from the sublist as it is found, and returns early only *"if len(seqs) == expected"* — a source with no message in the stream keeps the loop going to `ErrStoreEOF`, i.e. sequence 1), **4898** (`setupSourceConsumers`), **4928** (`subscribeToStream`); `server/filestore.go` **9683–9720** (`LoadPrevMsgMulti`: `for i := bi; i >= 0; i--` over every block under `fs.mu.RLock()`), **3186–3230** (`prevMatchingMulti`: `if mb.cacheNotLoaded() { mb.loadMsgsWithLock() }` — the whole block file, decompressed, per block); `server/jetstream.go` **1554–1555** (`Starting restore`, `rt := time.Now()`), **1571** (`a.recoverStream`), **1658–1659** (`Restored %s messages … in %v` — the timer wraps `recoverStream`, which through `addStreamWithAssignment` → `setLeader` → `subscribeToStream` runs the source scan, so the log line charges the scan to "restore") | The mechanism with line numbers, and the reason the thread's own logs misled everyone in it: the time is inside the `Restored … in` timer but after the store is recovered. Also the source of the **`SI-`** candidate below. | 13 | [[mirrors-and-sources]], [[filestore-layout]], the gotcha | **★** source |
| 3 | PR [#8282](https://github.com/nats-io/nats-server/pull/8282) *(2.15) [IMPROVED] Index stream sources to avoid backward scans* (merged 2026-08-20: *"As messages come in, their `Nats-Stream-Source` is inspected and the source key is mapped to the sequence that's sourced … written to disk as `sources.db` … at the stream's root"*, feature flag `js_snapshot_sources` for replicated state) and [#8516](https://github.com/nats-io/nats-server/pull/8516) *Index all stream sources, drop stream-level scan* (2026-08-28: *"if new sources were added but not used for an extended period of time, then backward scans would still happen every single time to come to the same conclusion of it not existing"*); release **v2.15.0-preview.1** (2026-08-24): *"Stream source indexing (#8282) — Restarts and leader changes previously required expensive backward scans through the stream to find the last sourced indices. These are now persisted in an index for instant lookup."* Not in any 2.14.x body; `startingSequenceForSources` at v2.14.6 still scans. | The version layer: the fix names the mechanism the thread hit, four months after the thread, without citing it. Gives [[nats-server-2.15-preview]] its first storage fact and the gotcha its *fixed in* line. | 13 | [[nats-server-2.15-preview]], [[mirrors-and-sources]], the gotcha | **★** version |
| 4 | `server/filestore.go` at v2.14.6, the recovery path proper: **1927–2216** (`recoverFullState`: reads `index.db`, checks the HighwayHash, rebuilds `psim` subject by subject, builds the block list from the per-block records **without opening the blocks**, then the three ways it refuses the file — `Stream state outdated, last block has additional entries, will rebuild` when the last block's last checksum differs, `Stream state outdated, found extra blocks, will rebuild`, `Stream state detected prior state, could not locate msg block %d` — plus `Stream state checksum did not match` and `Stream state encountered internal inconsistency on recover`, all `fs.warn` = `[WRN] Filestore [<stream>] …` (**1861–1867**)), **2454–2600** (`recoverMsgs`: every `%d.blk` in order through `recoverMsgBlock`), **1232–1320** (`recoverMsgBlock`: the last 8 bytes for the checksum, then — with no pre-2.10 `.idx` — `mb.rebuildState()`, which is `rebuildStateFromBufLocked` **1609–…**, the whole block read and walked record by record, then `populateGlobalPerSubjectInfo`), **11937–12010** (`_writeFullState`: `if !force { … if numSubjects > highCardinalityThreshold \|\| numDeleted > highCardinalityThreshold { return errStateTooBig } }`), **390** (`highCardinalityThreshold = 1_000_000`), **11898–11915** (`flushStreamStateLoop`, the unforced periodic write), **12216–12254** (`stop(delete, writeState)`: `if writeState { … fs.forceWriteFullState() }` — the forced write on a clean stop, which ignores the threshold); `server/jetstream.go` **204–207** (`Took %s to start JetStream`), **752** (`parallelTaskQueue(min(64, s.diskIOSemaphore().cap()))`), **1676–1684** (streams recovered through that queue); `server/server.go` **4794** (`diskIOSemaphore`, configured by `max_concurrent_io` since 2.14.4 — [[s-relnotes-2.14.4]]) | The general answer to row 13 as asked — what a clean shutdown buys, what breaks it, which log line says which, and the cardinality clause that ties row 9 to it: above the threshold no periodic `index.db` is written, so an unclean stop always means the full read. Goes to `raw/nats-server-src/filestore-recovery-v2.14.6.md`. | 13, 9 | [[filestore-layout]], [[defaults-and-limits]], [[jetstream-sizing]], the gotcha | **★** source |
| 5 | Release bodies, the recovery lines (scratchpad only; phase D ingests per minor): **v2.11.11 / v2.12.2** (2025-11-13) *"Streams are now loaded in parallel when enabling JetStream, often reducing the time it takes to start up the server (#7482, #7526)"* / *"JetStream recovery parallelism now matches the I/O gated semaphore (#7526)"* — the line @wallyqs was thinking of; PR #7526: *"`dios` are often less than the full core count and are often the limiting factor anyway"*; **v2.12.5** *"The filestore now always uses tombstones for recovering trailing deletes (#7782)"*, *"Fixed a race condition when rebuilding block state during recovery (#7783)"*; **v2.14.0** *"Asynchronous stream state snapshots for replicated streams (#7876)"* — Raft snapshots, not `index.db`; do not conflate; **v2.14.4** *"Filestore blocks with unsynced or truncated key files are now removed and counted as lost data instead of failing to recover altogether (#8365)"*; **v2.12.2 / v2.11.11** *"Improved the performance of enforcing `max_bytes` and `max_msgs` limits (#7455)"* (row 5's version layer). | The `since:` sentences for the gotcha and for [[filestore-layout]]'s version notes. This scout needs only the lines; the summaries are phase D's. | 13, 5 | [[nats-server-2.12]], [[nats-server-2.14]], [[filestore-layout]] | version |

### Row 9 — a high-cardinality subject space

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 6 | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) — *Is there performance issues possible with a high cardinality subjects for a stream?* · General · opened 2026-06-23 by @ashumkin · no answer marked · one comment, **@jnmoyne 2026-06-24** | The question as an architect holds it: file stream, `subject.>` with ~1 M `subject.<uuid>`, 10 GB / 5–10 days, R3, *"consuming, subscribing, publishing, cluster startup, RAFT leader election, etc."*. The maintainer: *"No problem with having a lot of subjects in a stream in terms of performance impact, even with a lot more than a million subjects. The only thing to keep in mind is that the server will use RAM to store its index of subjects (radix tree index) … for something around 1 million subjects it would be in the order of 100 megs of RAM (with small subjects)."* Nothing on startup, which is where the source says it does cost (candidate 4). | 9 | [[jetstream-sizing]], [[stream]], [[filestore-layout]] | **★** answered (maintainer comment, not marked) |
| 7 | [gh#5202](https://github.com/nats-io/nats-server/discussions/5202) — *Max unique subjects in a single jetstream* · Q&A · 2024-03-12 · **answer chosen** (@derekcollison, same day) | *"Currently the recent versions of the server, >= 2.10.9, use a modified Adaptive Radix Trie to store in memory index data per subject … number of messages and first and last blocks … path compression and lazy expansion … only the suffix needs to be stored at the leafs. We do have plans to implement a version that can be stored to disk as well, but currently this is all kept in memory. 50k subjects should be fine."* A community reply: 1 M small JSON values into one KV bucket in 2 min 30 s on a two-year-old laptop. The in-memory record is `psi{total uint64; fblk, lblk uint32}` (`filestore.go:169–173`) in `fs.psim *stree.SubjectTree[psi]` (**197**), plus a per-block `fss` (**242**). | 9 | [[filestore-layout]], [[jetstream-sizing]], [[nats-server-2.10]] | **★** answered, source-confirmed |
| 8 | Synadia blog — [How Many Subjects Should a NATS JetStream Stream Have?](https://www.synadia.com/blog/how-many-subjects-jetstream-stream) (Andrew Connolly, 2026-05-20): *"Each indexed subject has overhead, roughly a few hundred bytes"*, ~10 M subjects *"roughly 3-4 GB of memory overhead"*, *"Millions of subjects can be practical if the server has sufficient memory"*; the design advice is to size on consumption pattern (durable consumers, republish, KV) rather than on subject count. Two Synadia *insights* check pages, undated and unsigned: [JETSTREAM_025 subject-count threshold](https://www.synadia.com/insights/checks/nats-subject-count-threshold) (metadata keys `io.nats.monitor.subjects-warn` / `-critical`, example 100,000 / 500,000; names **recovery time** — *"Subject index rebuilding after restarts takes significantly longer with millions of subjects"* — as the third cost) and [JETSTREAM_003 stream message limit](https://www.synadia.com/insights/checks/nats-stream-message-limit) (fires at 90 % of `max_msgs`; the sizing formula `max_msgs = publish_rate × retention_window × 1.5`). | The only published per-subject byte figure, and the only public statement that cardinality costs restart time. Cite the blog with its date; the checks as what a commercial monitor watches, with no date. The `subjects-warn` metadata keys are a Synadia-product convention, not a server feature — say so. | 9, 5 | [[jetstream-sizing]], [[production-alerting]] (phase G6, later), [[synadia]] | relevant |
| 9 | Release **v2.14.2 / v2.12.10** (2026-06-02): *"The filestore no longer performs a block skip check on streams with extremely high subject counts, as it could result in runaway CPU usage (#8227)"*; PR #8227 (merged 2026-05-22): *"At a certain threshold, intersecting the entire stream subject state becomes considerably more expensive than just walking forward normally … In other places in the filestore, we tweak operations at 1 million subjects"*, with the benchmark (`checkSkipFirstBlockMulti` 173 µs at 1,000 unique subjects → 88 ms at 1,000,000 → 184 ms at 2,000,000 on an M2 Ultra, before the change). At v2.14.6 the guard is `fs.psim.Size() > highCardinalityThreshold` at `filestore.go:3519` and **3544**. Already noted in passing by scout 1 (candidate 4 there) for the version layer; here it is the row-9 mechanism. | The third use of the same constant — three things change at 1,000,000 subjects: no periodic `index.db` (candidate 4), no block-skip on filtered reads (this), and the interior-delete clause. That is the number the page gives, with the caveat that it is a code constant, not a tuning knob. | 9 | [[filestore-layout]], [[defaults-and-limits]], [[nats-server-2.14]], [[consumer-slow-on-a-sparse-stream]] | **★** version |
| 10 | Docs, negative result: `grep -rn -iE 'per-subject index\|subject index\|radix\|index\.db\|unique subjects' raw/nats-docs/` finds one line in the whole tree — `concepts/subjects.md:1110`: *"**Subjects are essentially free**: Creating new subjects has virtually no overhead - NATS efficiently handles millions of unique subjects."* — a core-NATS statement; `learn/deployment/sizing-and-resources.md` never mentions subjects as a RAM term, the threshold, `index.db`, or that recovery cost depends on a clean stop; no docs page names the `Restored … messages … in` line. | A **`missing`** candidate for `inbox/docs-issues.md` (the sizing chapter has no per-subject term and no recovery term), and an **`enhancement`** one (the core statement is true and, read from JetStream, misleading — the docs never say the JetStream side differs). Verify at ingest by reading the sizing chapter and the streams page end to end, not by grep alone. | 9, 13 | — (`inbox/docs-issues.md`) | docs-issue |

### Rows 4 and 5 — a cap on messages, a known-good `MaxMsgs`

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 11 | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) — *Is jetstream message count capped at 1 billion for a single stream?* · Q&A · opened 2025-08-04 by @ftong2020 · **no answer**; @wallyqs 2025-08-05 shows a 2.11.7 stream at **`Messages: 1,174,510,552`, 36 GiB, one subject** — *"a limits based stream should be possible to have +1B msgs"*; the asker: *"Let me try to reproduce"* and never returned. The reporter's discards (*"messages are discarded (can not figure out if it is latest message/oldest message)"*, *"maxMessageSize and MaxMessages are all set to 0"*) were never explained; the thread never shows `max_bytes`, `max_age`, the account's `max_store` or the discard policy. | Row 4's answer: **no cap**. `grep -nE '1_000_000_000\|1000000000\|1e9' server/{filestore,jetstream,stream,consumer,memstore,server,opts,const,jetstream_api,jetstream_cluster}.go` at v2.14.6 finds nothing; sequences are `uint64` throughout ([[stream]] already says they are never reused). The page says the reporter's loss is unexplained and lists what *would* discard at a size — `max_bytes`, `max_file_store`, the account tier — without asserting which. | 4 | [[stream]], [[jetstream-sizing]], [[defaults-and-limits]] | **★** unanswered, source-settled |
| 12 | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) — *Maximum known-good value for `MaxMsgs` in a JetStream stream* · Q&A · 2025-07-03 by @asymmetric · **answer chosen** (@jnmoyne, 2025-09-25) | An event-store shape: ~100 B events, ~5 M per year, R3, `LimitsPolicy`, never discard. The answer: *"Many people use streams with no limit or a very large one, and store equivalent (or larger) message sets without a problem … There is no hard limit to the size of a stream, but practically you will eventually run out of some kind of resource, be it disk space or memory space on the servers (as they maintain some per subject indexing). At that point you can investigate ways to shard onto multiple streams (e.g. you could have a stream per year, or decade) … For quick replay of a lot of messages (presented to you in order) consider using 'ordered' consumers."* | Row 5's answer, from a maintainer: **no known-good number exists because there is no hard limit**; what bounds a stream is disk, then the per-subject index in RAM; the mitigation is sharding by time. The page states that, and the bank row is *answered*, not `no-public-answer` — the backlog's expectation was one step too pessimistic. | 5, 4 | [[stream]], [[jetstream-sizing]], [[retention-policies]] | **★** answered |
| 13 | [gh#3772](https://github.com/nats-io/nats-server/discussions/3772) — *Using Nats Jetstream as an event store* · Q&A · 2023-01-08 · answered by @bruth (10 upvotes): *"a stream in general can grow as large as you have resources to support it"*; *"if a consumer is filtered to a specific subject, since the index is present, it only performs a linear scan over the blocks between the earliest and latest events for that subject"*; no tiered storage; NATS stream ≈ one Kafka *partition*, not a topic. | Context for rows 4/5 and a source for phase G (G1 `stream-topology-design`, G8 `migrating-from-kafka-or-rabbitmq`). Pre-2.10, so cite for the design statements only. | (5, 108, 136) | [[stream]], [[stream-topology-design]] (later) | later |

### Context, lower priority

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 14 | [issue #4424](https://github.com/nats-io/nats-server/issues/4424) — *Jetstream memory consumption 10x with multi-subject stream compared to multi-stream with single subject* (2023-08-24, v2.9.19, **open, one maintainer question, no follow-up**: 1.8 GB vs 206 MB) | Pre-2.10, unreproduced, no mechanism given. Not worth a summary; one sentence on the gotcha's *what this page does not explain* list at most. | 9 | — | skip |
| 15 | `raw/nats-server-src/filestore-observed-v2.14.6.md` §7–§8 and [[s-nats-server-filestore-layout]] — `index.db` measured at 4 bytes per subject beyond the subject itself; recovery of 279,653 messages 22.1 ms with `index.db` vs 24.6 ms without | Already ingested; the baseline the new run must dwarf. The page keeps its "no measurable difference at this size" sentence next to the new numbers. | 13 | [[filestore-layout]] | local |

**Blocked or not worth fetching:** nothing was blocked. The Synadia *insights* pages carry no
author or date, so they are cited as a product's check definitions, not as a dated claim. GitHub
code search for the one-billion constant was done on fetched files rather than the search API.

---

## The runs the ingest would make

All on `nats-server v2.14.6` / `nats` CLI 0.4.0 (re-check with `--version` first), one node
through `bash tools/lab/cluster.sh up 1`, recorded in
`raw/nats-server-src/stream-scale-observed-v2.14.6.md`. **Disk budget: about 9 GB** under
`$TMPDIR/nats-lab` (98 GB free on 2026-09-02): ~6.8 GB for the big stream (50 M × (30 + 5 + 100) B
records, the thread's ~7 GB), ~1.2 GB for the sourced copy, under 1 GB for the cardinality pair.
**Time budget is the unknown:** the 50 M fill through `nats bench js pub async` on one file-backed
node is the longest step; if it has not finished in 15 minutes, stop at whatever count it reached
(20 M is enough for the mechanism) and say so in the raw file.

- **Run D — row 13, the thread's shape, four restarts.** `nats bench js pub async --create
  --storage file --maxbytes 20GB --stream EVENTS --msgs 50000000 --size 100 --batch 500
  --multisubject --multisubjectmax 6 ev` (six subjects, like the thread; `nats stream info EVENTS`
  for `Messages`, `Bytes`, `Number of Subjects`; `du -sh` and `ls msgs/ | wc -l` for the blocks).
  Then, timing `Restored … messages for stream … in` and `Took … to start JetStream` from `n1.log`
  each time, and `iostat`/`du` reads in between: (1) `cluster.sh down` (SIGTERM, clean) → `up 1`
  — expect milliseconds and no `Filestore [EVENTS]` warning; (2) `cluster.sh stop 1 -9` → `up 1` —
  expect `Stream state outdated, last block has additional entries, will rebuild` and a time
  proportional to the store; (3) `find … -name index.db -delete` on a cleanly stopped store → `up
  1` — the no-file path, same order as (2); (4) **the sources variant**: `nats stream add IDLE
  --subjects idle.> --storage file` (empty), `nats stream add AGG --source EVENTS --source IDLE
  --storage file` with a `--source` filter `ev.1` on EVENTS (≈ 8.3 M messages, ~1.2 GB) — let it
  catch up (`nats stream info AGG`, sources `Lag` 0), clean stop, `up 1`, and read AGG's `Restored
  … in` against EVENTS's; then `nats stream edit AGG` to drop the IDLE source and restart once more.
  The claim to test: **AGG's restore time scales with AGG's size on disk when one source has
  nothing in the stream, and drops to milliseconds without that source**. One variant with
  `--compression s2` on EVENTS only if time allows (the thread had S2; the CPU cost is the block
  decompression in `loadMsgsWithLock`).
- **Run E — row 9, the cardinality pair.** `CARD`: `--multisubject --multisubjectmax 1200000
  --msgs 3000000 --size 100 card` (1.2 M distinct subjects, above the threshold); `FLAT`: the same
  message count on 6 subjects. For each: `/varz` `mem` before and after the fill (the RSS term per
  subject, to set against *"100 megs"* and *"a few hundred bytes"*), `nats stream info` `Number of
  Subjects`, whether `msgs/index.db` appears within 3 minutes (`flushStreamStateLoop` runs every 2
  min + jitter; above the threshold expect none), its size when it does (`Σ(len + 4)` predicts it),
  whether a clean stop writes one anyway (`stop(delete, writeState)` forces it, `filestore.go:12254`), and the restart
  time after a clean stop **and** after `-9` for both streams. Then one filtered pull consumer on
  each (`--filter 'card.1*'`) timed, for the `checkSkipFirstBlock` guard.
- **Run F — rows 4 and 5, one command, no fill.** `nats stream edit EVENTS --max-msgs
  1000000000` (and `--max-msgs 10000000000`) to show the API accepts a value past a billion with
  no validation cap, and the arithmetic from run D: bytes on disk and `index.db` bytes at the count
  reached, extrapolated to 1 B *as arithmetic, labelled as such*. Nobody fills a billion messages on
  a laptop, and the page must not pretend otherwise.

## What the ingest would write

- Summaries (eight, at the cap): `s-gh-8001-jetstream-startup-slow-50m`,
  `s-gh-8333-high-cardinality-subjects`, `s-gh-5202-max-unique-subjects`,
  `s-gh-7147-one-billion-cap`, `s-gh-7032-max-msgs-known-good`,
  `s-nats-server-filestore-recovery` (candidates 2 and 4, one raw file
  `raw/nats-server-src/filestore-recovery-v2.14.6.md`, with the PR texts of candidate 3 quoted in it
  and the 2.15 preview line), `s-nats-server-stream-scale-observed` (runs D–F),
  `s-synadia-how-many-subjects` (candidate 8, with the two check pages as dated-as-unknown
  pointers). Candidate 13 is a pointer sentence for phase G; candidate 5's release lines are cited
  from the scratchpad on the pages and become summaries in phase D.
- A new gotcha, working slug **`jetstream-recovery-is-slow`**: symptom `Restored N messages for
  stream … in 6m…` with `Healthcheck failed` repeating under it; quick triage (was the stop clean —
  the `Filestore [<stream>] Stream state …` warnings say; does the stream have `sources`; how many
  subjects; what does the disk read at); causes ranked — **1.** a stream with `sources` scanning
  backwards for each source's last message, worst when a source is idle or empty (2.10–2.14; fixed
  by `sources.db` in 2.15 preview), **2.** an unclean stop or a stale `index.db`, the full block
  read, **3.** more than 1,000,000 subjects or interior deletes, so no periodic `index.db` at all,
  **4.** a volume that reads at 20 MB/s, **5.** pre-2.11.11 serial recovery; each with *how to
  confirm* and *the fix*. *Explained by* [[filestore-layout]] and [[mirrors-and-sources]].
- New sections: [[filestore-layout]] — *Recovery: what `index.db` buys, and the five lines that
  say it was refused*; [[mirrors-and-sources]] — *What a sourcing stream does at every start* (the
  scan, its cost, `sources.db` in 2.15); [[jetstream-sizing]] — *Subjects are a RAM term* (the
  maintainer's figure, Synadia's, the measured one) and *There is no message cap* (rows 4 and 5:
  what actually bounds a stream, the shard-by-time advice), plus recovery time as a sizing input
  under *What runs out first*; [[stream]] — the no-cap statement in *Limits and failure modes*;
  [[defaults-and-limits]] — the `highCardinalityThreshold` row gains its three uses;
  [[nats-server-2.15-preview]] — the source index; [[nats-server-2.14]] — 2.14.2 #8227 on the
  concept side; pointer sentences on [[kubernetes-storage]] (the thread ran under the Helm chart
  on Ceph, and the readiness probe failed for the whole six minutes) and
  [[consumer-slow-on-a-sparse-stream]] (the same constant guards the block skip).
- Bank: **13 answered** (the mechanism the thread never got, the run, the 2.15 fix; marked
  *unanswered upstream* on the page the way [[slow-consumer-detected]] does it); **9 answered**;
  **4 answered** (no cap, the reporter's loss unexplained); **5 answered** — by a maintainer's "no
  hard limit", with the page saying no known-good figure is published and why; not
  `no-public-answer`. Docs issues: candidate 10, two rows if both verify. Server issue: **`SI-3`
  candidate** only if run D reproduces it — the `Restored … in` line charges the source scan to
  "restore" and no log line names the scan at all (`undocumented`; *what would settle it*: is the
  attribution intended, and should 2.14.x log the scan — 2.15 removes the cost but not the
  question). Rows 2 and 3 gain material.

**Status:** picked 2026-09-02 by the user, as proposed: candidates **1, 2, 3, 4, 6, 7, 9, 11, 12** ingested (the eight summaries named above, with 2 + 4 as one source summary quoting 3, and 9 on the version layer); **8** as its own summary; **5** cited from the release lines on the pages and left to phase D; **10** verified and recorded as a docs issue if it holds; **13** a pointer sentence for phase G; **14** skipped; **15** local. Runs D, E, F as named; the S2 variant of run D, and any part of run D that adds nothing over what the source already settles, may be skipped at the maintainer's discretion. Step 4 starts in a fresh session from the cache: the six threads (JSON and rendering), the ten server files at v2.14.6 and the release bodies are in `local/scratch/` (`gh/`, `src/v2.14.6/`, `releases/`; see its `INDEX.md`), and `tools/fetch-discussion.py` re-fetches or promotes a thread into `raw/gh-discussions/`.
