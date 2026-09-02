# Scout — mirror and replication internals: rows 76, 91, 105 (2026-09-02)

**Why this topic.** Section 1 of `inbox/scout-backlog.md`, and step 1 of
`inbox/plan-the-runnable-scouts-2026-09-02.md` (phase B). Three open rows, one mechanism — a mirror
is an internal consumer on the upstream feeding a local store — and all three are runnable on the
lab (`tools/lab/`) plus the hub/leaf pair of `raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md`.

| row | question | asked at | state before this scout |
|---:|---|---|---|
| **76** | Why is a KV mirror on file storage far slower than on memory storage? | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) | open; [[mirrors-and-sources]] carries it under `## To verify` |
| **91** | Why does mirror catch-up slow down when a consumer reads the mirror at the same time? | [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) | open |
| **105** | Why does `nats object ls <bucket>` fail on a **mirror** of an object-store bucket, and what does mirroring one across a leafnode with two JetStream domains actually give you? | [issue #5106](https://github.com/nats-io/nats-server/issues/5106) | open; `SI-1` is the neighbour |

**Everything below was fetched or read on 2026-09-02.** Nothing is ingested. The three threads were
pulled through the GitHub GraphQL API into the session scratchpad and are quoted from there; at
ingest they are saved verbatim under `raw/gh-discussions/` and `raw/gh-issues/`. Source lines are
from `server/stream.go` and `server/filestore.go` at tag **v2.14.6**, fetched today; the release
notes are the GitHub release bodies for v2.14.1–v2.14.6.

**The shape of the answers, in one paragraph.** Row 76 is answered upstream, and the answer is not
"file is slow": the reporter's consumer passed a `FilterSubject` that matched everything, and on a
*mirror* (a stream with no ingest subjects) that sends every message lookup down the per-subject-state
path instead of the linear scan, which on a stream whose sequence space is 83 % holes costs ~65× —
remove the filter and file storage reads at 150k+ msg/s. The *initial sync* being slow on file was
never explained in the thread. Row 91 is **unanswered by the maintainers**; one community comment
argues from the source that a sparse backlog makes the mirror take two exclusive store locks per live
message (`SkipMsgs` for the gap, then the store) against a reader's `RLock` per message — the
structure is visible at v2.14.6 and the reporter shipped a reproduction. Row 105's first half was a
**client bug, fixed in nats.go in 2024-03** (the client looked the stream up by subject, which a mirror
does not answer); its second half is that mirrored object stores are still not first-class anywhere —
no `nats object add --mirror` in CLI 0.4.0 (KV has `--mirror` / `--mirror-domain`), nats.go issue
#1874 open since 2025-05 — so the operator builds the mirror by hand with a subject transform.

---

## The candidates

### Row 76 — a KV mirror on file storage

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 1 | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) — *JetStream file-store ~65x slower than memory-store on KV mirror (83% of seq space is deleted)* · Q&A · opened 2026-07-24 by @cyqsign · **answer chosen** (@MauriceVanVeen, 2026-07-27) · closed 2026-08-03 · v2.14.2 | The best-instrumented thread in the bank: hub cluster + leaf, `KV_DNS` (2.0 M live messages, 11.9 M sequences, **9.9 M deleted** — "83% of the seq space is holes"), two mirrors on the leaf differing only in `storage`. Pull consumer with `FilterSubject: "$KV.DNS.>"`, `DeliverLastPerSubject`: memory 266,840 msg/s, file ~4k msg/s; disk idle, page cache warm, one core busy. Maintainer: *"You're not intending to filter, but a filter is passed anyway … since it's a mirror, the stream has no ingest subjects. So the first `doLinearScan = false`. Then there's a check whether there are 4x more messages than there are subjects. However, that uses the first/last sequence range, which is huge because you have so many deletes. For every single message lookup there is an expensive read through `mb.fss`"*. Without the filter: **~150k+ msg/s** on file. Initial sync on file: `msgs=855,017 lag=1,164,860 elapsed=412.5 s` (~2k live msg/s) — *"Have no way to tell at the moment"*; the reporter never posted the reproducer. Also: a block never starts with a deleted sequence (interior holes only, tail holes compacted); rollup-as-delete versus `PurgeStream`; the maintainer's *"I'm working on an improvement in the filestore for a situation like this where the number of deletes are greater than the number of unique subjects"* — which is candidate 4. | 76, 2, 9 | [[mirrors-and-sources]], [[key-value]], [[filestore-layout]], [[consumer]], [[jetstream-sizing]], [[nats-server-2.14]] | **★** answered, runnable |
| 2 | `server/filestore.go` at v2.14.6, lines **3086–3112** (`firstMatching`: `doLinearScan := isAll \|\| (wc && len(subjs) == 1 && subjs[0] == filter)`, then `doLinearScan = mb.fss.Size()*4 > int(lseq-fseq)` — the heuristic the answer names, with its comment *"Optimize for 25th quantile of a match in a linear walk"*), **3033** (`firstMatching`), **9427** (`LoadNextMsg`, `fs.mu.RLock()` for the whole call), **9556–9561** (the same heuristic in the multi-filter path) | The mechanism with line numbers, so the page can say *why* a wildcard filter that matches everything is the slow path on a mirror and not on the origin (`subjs[0] == filter` is true on the origin's own subject). | 76, 9 | [[filestore-layout]], [[consumer]], [[mirrors-and-sources]] | **★** source |
| 3 | `nats kv add --help` (CLI 0.4.0, run today): `--mirror=MIRROR`, `--mirror-domain=MIRROR-DOMAIN`, `--source=BUCKET …`, `--storage=STORAGE (file, memory)`; and `raw/nats-docs/learn/key-value/where-next.md` line 40 — the docs' one paragraph on bucket mirroring (*"a regional `EU_INVENTORY` bucket could source from `INVENTORY` … kept in sync by a subject transform from `$KV.SRC.>` to `$KV.DST.>`"*) | What an operator actually types to build the row-76 setup, and the one place the docs mention it. | 76 | [[key-value]], [[nats-cli]] | local |
| 4 | Release notes **v2.14.4** (2026-07-30): *"Calculating and looking up sequences in delete maps for file-backed streams with large numbers of interior deletes is now faster and holds locks for less time (#8403)"*, *"Inserts, iterations and deletes in AVL sequence sets are now faster in many cases, which speeds up the tracking of interior deletes (#8406)"*, *"Stream snapshots now attempt to determine the correct encode buffer size up front, avoiding many unnecessary allocations on streams with large numbers of interior deletes (#8405)"*; PR #8403's own text: *"A synthetic benchmark at ~300M interior deletes: 23.1s -> 17.7ms per `deleteMap`"*. Plus **v2.14.2** (2026-06-02): *"The filestore no longer performs a block skip check on streams with extremely high subject counts, as it could result in runaway CPU usage (#8227)"* and *"Fixed an issue where the per-subject state last block was not stored correctly with a max messages per subject limit of 1 (#8254)"*; **v2.14.1**: *"Mirror consumers are now retried immediately on a last sequence mismatch, avoiding stalling for longer than necessary (#8152)"*. | The version layer for rows 76 and 91: the thread ran on v2.14.2, the interior-delete work landed in v2.14.4, and the lab runs on v2.14.6 — so a re-measurement is on the fixed side. #8227 is also the first public statement of a subject-count threshold (~1 M, from the PR) for row 9 in scout 2. Phase D will ingest the notes per minor; this scout only needs the 2.14.4 article now. | 76, 91, 9, 13 | [[nats-server-2.14]], [[filestore-layout]], [[mirrors-and-sources]] | **★** version |

### Row 91 — catch-up under a competing reader

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 5 | [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) — *Mirror Stream sync is ~2.9× slower when a Consumer cold-scans the mirror during catch-up* · Q&A · opened 2026-08-10 by @cyqsign (the same reporter) · **no answer chosen, no maintainer reply** as of 2026-09-02 · one comment (@gitsult4n, 2026-08-17) · v2.14.2 | Hub + leaf as two processes with domains `hub` / `leaf`; source with `MaxMsgsPerSubject: 1`, 1 M keys, 300k hot keys, 3 M overwrites → *"span ≈ 4 000 000, holes ≈ 3 000 000, hole ratio ≈ 75%"*. Mirror catch-up from scratch: **14.201 s** alone, **41.003 s** with a `DeliverAll`, `AckNone`, unfiltered consumer re-scanning head→tail in a loop (2.89×; min ingest 64,217 → 23,080 seq/s). A buildable reproduction zip is attached. The comment's argument, from source: one `fileStore.mu` for the whole store; the reader's `LoadNextMsg` holds `RLock` for a whole multi-block walk; the mirror does `skipMsgs` → `store.SkipMsgs` (exclusive lock) for every gap **plus** the store call for the message, so a 75 %-sparse backlog roughly doubles exclusive acquisitions; Go's `RWMutex` is writer-preferring. Its own caveat: *"a strong, code-grounded hypothesis rather than something I've isolated with a profiler"*; its mitigation: start the scan when `lag` reaches 0. | 91 | [[mirrors-and-sources]], [[filestore-layout]], [[jetstream-slows-as-consumers-grow]] | **★** unanswered, runnable |
| 6 | `server/stream.go` at v2.14.6: **3118–3124** (`sourceHealthHB = 1 * time.Second`, `sourceHealthCheckInterval = 10 * time.Second`), **3125–3205** (`processMirrorMsgs`: the goroutine, the 10 s stall ticker), **3206–3262** (`processInboundMirrorMsg`: heartbeats carry `Nats-Last-Consumer` and a `Nats-Consumer-Stalled` reply subject; a delivery-sequence gap means *"the upstream stream has expired or deleted messages"* and calls `skipMsgs`), **3403–3440** (`skipMsgs`: unclustered → `store.SkipMsgs(start, n)`; clustered → one Raft entry per skipped sequence in batches of 10,000, or a single `DeleteRange` op behind the `FeatureFlagJsRaftDeleteRange` flag), **3552–3582** (the mirror consumer the server creates: `Name: JS_MIRROR_<id>`, `DeliverByStartSequence` from `LastSeq + 1`, `AckNone`, `AckWait: 22h`, `MaxDeliver: 1`, `Heartbeat: 1s`, `FlowControl: true`, `Direct`, `Sourcing`, `InactiveThreshold: 10s`, metadata `_nats.mirror.stream` / `.acc` / `.domain`), **3924** (`sourceConsumerRetryThreshold = 2 * time.Second`); `server/filestore.go` **5465–5482** (`SkipMsgs` under `fs.mu.Lock()`), **5311 / 5336** (`StoreRawMsg` / `StoreMsg`). | The internals page material for *how a mirror actually catches up* — which no page states today ([[mirrors-and-sources]] says "an internal consumer" and stops) — and the exact lock structure row 91 turns on. Also a **docs-issue candidate**: `raw/adr/ADR-59.md` line 654 says the internal consumer *"is created with an explicit name following the pattern `mirror-<id>` or `src-<id>`"* when a filter is configured, and [[mirrors-and-sources]] repeats it; `stream.go:3561` at v2.14.6 names the mirror consumer `fmt.Sprintf("JS_MIRROR_%s", id)`. Verify at ingest — read the whole naming branch (filtered and unfiltered, mirror and source) and what `/jsz?direct-consumers=true` prints in run A — before recording it against the ADR repo. | 91, 76 | [[mirrors-and-sources]], [[filestore-layout]], [[raft-in-nats]], [[advisories]] | **★** source |

### Row 105 — `nats object ls` on a mirrored bucket, across two domains

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 7 | [issue #5106](https://github.com/nats-io/nats-server/issues/5106) — *Object Store replication from LeafNode to Cluster nats: error: nats: no stream matches subject* · defect · opened 2024-02-19 by @b3rtram · **closed 2024-03-04** · v2.10.11, CLI 0.1.3 · 11 comments | Leaf (domain `leafnode`) writes bucket `dms`; hub (domain `cluster`) creates `OBJ_dms_mirror --mirror OBJ_dms` with the import from domain `leafnode`. `nats object ls` lists the bucket; `nats object ls dms_mirror` → **`nats: error: nats: no stream matches subject`**. @Jarema: *"CLI assumes that the subject name where to look for metadata and chunks is aligned with stream name, which is not the case for mirrors"* — fixed with a mirror subject transform **`$O.dms.>` → `$O.dms_mirror.>`** — *"However, CLI also sends request to list all streams by subject, and that does not include mirrors"* — fixed client-side in **nats.go #1568** (*"Bind Object Store bucket stream when getting object"*, merged 2024-02-26) and #1578. The trace in the thread shows the failing call: `$JS.API.STREAM.NAMES {"subject":"$O.dms_mirror.M.>"}` → `streams: null`. Reporter confirmed list + get working on 2024-03-04. | 105 | [[object-store]], [[mirrors-and-sources]], [[cross-domain-sourcing]], [[jetstream-domain]], [[object-store-list-is-slow]], [[nats-go]], [[nats-cli]] | **★** answered, runnable |
| 8 | The client side today: [nats.go #1874](https://github.com/nats-io/nats.go/issues/1874) *Support mirrored ObjectStore* (**open**, 2025-05-15, 8 comments: *"The manual stream creations works great since #5106 was fixed, but first class support would align with KV and streams"*; the use case is exactly row 105 — leaf buckets mirrored into the cluster with a longer TTL); [nats.js #155](https://github.com/nats-io/nats.js/issues/155) same title (closed 2025-07-02); [nats.go #1648](https://github.com/nats-io/nats.go/issues/1648) *Object store publishes chunks without using domain in subject* (**open**, 2024-06-14); and `nats object add --help` on CLI 0.4.0, which has `--storage`, `--replicas`, `--js-domain` and **no `--mirror`**, where `nats kv add` has `--mirror` and `--mirror-domain`. | The honest second half of row 105: a mirrored object bucket is a hand-built `OBJ_<name>` mirror with a transform, readable by clients that bind by stream name (nats.go since 2024-03; the others per client), and not a first-class bucket anywhere as of 2026-09-02. Feeds the *what bites you* sections in phase F. | 105 | [[object-store]], [[nats-go]], [[nats-js]], [[nats-cli]] | relevant |
| 9 | `raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md` + `inbox/server-issues.md` **SI-1** — the hub/leaf pair with different domains on which `$O.<bucket>.>` traffic crosses the leafnode because the deny list names `$OBJ.>` | Not new, but the **overlap check** the backlog asked for: row 105 mirrors a bucket across the same boundary that SI-1 says is already porous for `$O.` subjects. Before the run: on that pair, does `nats object ls dms` on the hub show the leaf's bucket with *no* mirror at all? If yes, the mirror's job is durability on the hub side, not visibility — and the page must say both. Distinct finding from SI-1 unless the run says otherwise. | 105 | [[object-store]], [[leafnode]] | local |
| 10 | Docs, negative result: `grep -ril mirror raw/nats-docs/learn/object-store/` → nothing; `learn/jetstream/mirrors-and-sources.md` never mentions an object-store bucket; the KV chapter has the one paragraph of candidate 3. | A `missing` candidate for `inbox/docs-issues.md`: the only public route to a mirrored object bucket is a closed GitHub issue. Verify at ingest by reading the object-store chapter end to end, not by grep alone. | 105 | — (`inbox/docs-issues.md`) | docs-issue |

### Context, lower priority

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 11 | Synadia blog — [Mirror Streams in NATS JetStream: One-Way Replication Made Simple](https://www.synadia.com/blog/mirror-streams-jetstream) (Peter Humulock, 2026-02-18) | General introduction. Three sentences worth having with a date: *"When the connection drops, the mirror waits about 10–20 seconds before retrying"* (matches `sourceHealthCheckInterval` = 10 s), *"Deletes don't replicate in either direction"*, and the mirror-promotion recipe for 2.12 (`nats str edit events --subjects '$devnull' --force` then `--no-mirror`). It also says *"Interest-based retention is not supported with mirrors"* and WorkQueue support is *"partial"* — true before 2.14, superseded by ADR-60 ([[s-adr-60-reliable-sourcing]] if it exists, else the 2.14 release notes) — so cite it with its date, not as current. | — | [[mirrors-and-sources]], [[disaster-recovery]] | relevant, dated |
| 12 | Synadia blog — [Mirror, Merge, or Consume: How to Choose Your Edge-to-Core Streaming Pattern](https://www.synadia.com/blog/nats-edge-event-architecture-8-mirror-merge-or-consume) (Bruno Baloi, 2026-05-18) | A pattern source — *"The patterns are not interchangeable. Each exists because a different problem demands it"* — with nothing on storage, buckets or domains. Belongs to phase G (the topology and edge pattern pages), not to these rows. | (125, 108) | [[multi-region-jetstream]], [[choosing-a-topology]] | later |

**Blocked or not worth fetching:** nothing was blocked. The reproduction zip on gh#8444 is a
GitHub user-attachment; the run below rebuilds its shape with the `nats` CLI rather than importing
Go code into `raw/`.

---

## The runs the ingest would make

All on `nats-server v2.14.6` / `nats` CLI 0.4.0 (re-check with `--version` first), recorded in
`raw/nats-server-src/mirrors-observed-v2.14.6.md`. Small values (≈100 B) keep the disk budget in
the hundreds of megabytes.

- **Run A — row 76, the same mirror on file and on memory.** `bash tools/lab/cluster.sh up 1` (one
  server is enough for the mechanism; the thread's hub/leaf split is not what the answer turns on).
  Source bucket `DNS` with `--history 1`, ~200k keys written once, then ~1.5 M overwrites on a hot
  20 % of keys so the sequence space is mostly holes; report `Messages`, `Last Sequence`, `Deleted
  Messages` from `nats stream info KV_DNS`. Then `nats kv add DNS_FILE --mirror DNS --storage file`
  and `… DNS_MEM --storage memory`; time each initial sync (`nats stream info` `Lag` → 0, sampled
  every second). Then read each mirror four ways and time it: a pull consumer with
  `--filter '$KV.DNS_FILE.>'` and `--deliver last-per-subject`, the same with no filter,
  `nats kv ls`, `nats kv get` of one key. The thread's claim to test: **filter → slow, no filter →
  fast, on file only**. Also compare block counts and bytes on disk of source versus file mirror
  (the thread saw the mirror re-pack to 98 % live bytes).
- **Run B — row 91, catch-up with and without a reader.** Same sparse source. Delete and recreate
  the file mirror twice: once alone, once while an unfiltered `DeliverAll` / `AckNone` ephemeral
  consumer re-scans it in a loop (the probe client in `raw/nats-server-src/nats-probe-client.py`, or
  `nats consumer next` in a loop — whichever keeps the scan running). Wall time for `Lag` → 0 each
  way; a second pair on a **memory** mirror to separate the file-store lock from the general cost.
  Report a ratio and the log lines, never a design number.
- **Run C — row 105, a mirrored object bucket across two domains.** The hub/leaf pair from
  `object-store-across-leafnode-observed-v2.14.6.md` (domains `hub` / `leaf`, account `APP`), started
  by hand from its configs. On the leaf: `nats object add dms`, three puts. On the hub, first the
  SI-1 check (`nats object ls`, `nats object ls dms` with no mirror at all), then
  `nats stream add OBJ_dms_mirror --mirror OBJ_dms --js-domain hub` importing from domain `leaf`
  **without** a transform (expect the thread's error, verbatim, on CLI 0.4.0 — or not), then with
  `$O.dms.> → $O.dms_mirror.>`; `nats object ls dms_mirror`, `nats object info dms_mirror`,
  `nats object get dms_mirror <name>`; and what `nats object add --mirror` says (it should not exist).
  A `$JS.API.STREAM.NAMES {"subject":"$O.dms_mirror.M.>"}` request by hand, to show the
  server-side half of the original failure still holds on 2.14.6 (a mirror has no subjects to match).

## What the ingest would write

- Summaries: `s-gh-8417-kv-mirror-file-vs-memory`, `s-gh-8444-mirror-catchup-under-a-reader`,
  `s-issue-5106-object-store-mirror-list`, `s-nats-server-mirror` (the stream.go / filestore.go
  ranges of candidates 2 and 6, one raw file `raw/nats-server-src/mirror-v2.14.6.md`),
  `s-nats-server-mirrors-observed` (the three runs), `s-relnotes-2.14.4` (candidate 4, the one
  release article this scout needs; phase D folds it into the per-minor summary later). Six, under
  the cap.
- A new section on [[mirrors-and-sources]] — *How a mirror catches up* (the consumer the server
  creates, heartbeats, flow control, the gap → `skipMsgs`, the 10 s stall check, the 2 s retry
  threshold) — and the `## To verify` item on it settled. A new section on [[filestore-layout]] —
  *Interior deletes, and what they cost a reader* (the `dmap`, a block never starts with a hole,
  the linear-scan heuristic, `SkipMsgs`, what 2.14.4 changed). Sections on [[key-value]]
  (mirroring a bucket: the flags, file versus memory, and that the filter is the trap) and
  [[object-store]] (mirroring a bucket: no flag, the transform, which clients can read it). A gotcha
  — working slug `consumer-slow-on-a-sparse-stream` — whose symptom is the row-76 one and whose
  first cause is the everything-matching filter; row 91 lands on it or on [[mirrors-and-sources]]
  depending on what run B shows. Pointers on [[object-store-list-is-slow]] (a mirror fails the list
  for a different reason), [[cross-domain-sourcing]], [[consumer]], [[nats-go]], [[nats-cli]],
  [[nats-server-2.14]].
- Bank: 76 answered; 105 answered; 91 answered with the mechanism and the run, marked as unanswered
  upstream in the page (the way [[slow-consumer-detected]] does it) — or bold `no-public-answer` if
  run B is inconclusive. Rows 2 and 9 gain material. Docs issue: candidate 10 if it verifies. Server
  issue: only if run C or run B shows something the source does not explain — the backlog's expected
  "second `SI-`" is more likely to be "SI-1 restated on a mirror", which is a sentence on the page,
  not a row.

**Status:** picked 2026-09-02 by the user (candidates 1, 2, 4, 5, 6, 7, 8 ingested; 3, 9, 10 run as local checks; 11, 12 pointer sentences). **Ingested 2026-09-02**, step 2 of `inbox/plan-the-runnable-scouts-2026-09-02.md`. Candidate → summary: 1 → [[s-gh-8417-kv-mirror-file-vs-memory]]; 2 and 6 → [[s-nats-server-mirror]] (`raw/nats-server-src/mirror-v2.14.6.md`); 4 → [[s-relnotes-2.14.4]] (all six patch bodies saved in `raw/release-notes/`); 5 → [[s-gh-8444-mirror-catchup-under-a-reader]]; 7 → [[s-issue-5106-object-store-mirror-list]] (with nats.go #1874, #1648 and nats.js #155 in `raw/gh-issues/client-issues-object-store-mirror.md`); 8 → folded into that summary and [[s-nats-go-kv-object-mirror]] (`raw/nats-go-src/kv-object-mirror-v1.53.1.md`, read because the runs needed it); the three runs → [[s-nats-server-mirrors-observed]] (`raw/nats-server-src/mirrors-observed-v2.14.6.md`, with `mirrorlab.py`). 3: `nats kv add --mirror` / `--mirror-domain` exist, `nats object add --mirror` does not (run C §7). 9: with no mirror at all the hub sees nothing of the leaf's bucket — SI-1 needs a same-named bucket on both sides; row 105's mirror is a different thing, no new `SI-`. 10: verified by grep over the whole docs tree — docs issue **#50**. The ADR-59 naming discrepancy verified at three tags — docs issue **#49**; the client's same-domain/cross-domain read asymmetry — docs issue **#51**. Rows 76, 91, 105 filled; new gotcha [[consumer-slow-on-a-sparse-stream]].
