---
title: "Observed on nats-server v2.14.6 — a 50 M-message stream restarted six ways, an empty source, 1.2 M subjects, --max-msgs past a billion"
type: summary
area: [jetstream, deploy]
source-path: raw/nats-server-src/stream-scale-observed-v2.14.6.md
author: "this wiki, run locally (nats-server v2.14.6, nats CLI 0.4.0, through tools/lab/cluster.sh up 1)"
article: "runs D, E and F of 2026-09-02 plus the sampled restarts that followed; scripts stream-scale-runE.sh / stream-scale-runD.sh and the stream-scale-agg*.json configs in the same directory"
date: 2026-09-02
version: "2.14.6"
tags: [recovery, restore, index.db, SIGKILL, clean-shutdown, sources, backward-scan, startingSequenceForSources, cardinality, psim, RSS, max_msgs, healthcheck, stacksz, measured, filter_subject, stree]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# Observed on v2.14.6 — the stream-scale runs

Made for question-bank rows 4, 5, 9 and 13 after reading the threads and the source
([[s-gh-8001-jetstream-startup-slow-50m]], [[s-gh-8333-high-cardinality-subjects]],
[[s-gh-5202-max-unique-subjects]], [[s-gh-7147-one-billion-cap]], [[s-gh-7032-max-msgs-known-good]],
[[s-nats-server-filestore-recovery]]). One laptop, one standalone server, an SSD whose page cache
held every store after the first read. Mechanisms and ratios, never limits.

## Run D — 50 M messages, restarted six ways (row 13)

`EVENTS`: 50,000,000 × 100 B over six subjects, filled in 130 s (383,895 msg/s), **6.7 GB reported =
6.2 GiB on disk, 800 blocks of 8 MB, 134 B per message**. `index.db` was 21.7 KB during the fill and
22.9 KB after the clean stop.

| restart | `Restored … in` | what happened |
|---|---:|---|
| clean stop, disk idle (six restarts: three minutes after the last write, three back-to-back, and one 200 ms after 200,000 new writes) | **3–27 ms** | `recoverFullState` took the file, opened no block |
| clean stop, seconds after a bulk write (the 6.2 GB fill; the 1.1 GB sourcing catch-up; a full rebuild) — four restarts | 1.8–7.0 s | same path; the disk was at ~800 MB/s of write-back during the 7 s one. Not isolated further |
| **SIGKILL** after 200,000 new writes | **6.372 s** for 50.6 M / 6.8 GB | `[WRN] Filestore [EVENTS] Stream state outdated, last block has additional entries, will rebuild` · `Recovering stream state from index errored: prior state file`; reads at 1.0–1.6 GB/s; 37 of 37 goroutine samples in `recoverMsgs → recoverMsgBlock → rebuildState` (a `read`, the HighwayHash of each record, the subject-tree insert) |
| `index.db` deleted from a cleanly stopped store | **9.524 s** for 50.2 M | no warning at all — a missing file is silent — then the same full read |

While `up` waited, `[WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"`
was logged once per `/healthz` poll (26 lines in 7 s at the lab's cadence): the row-13 thread's
repeating line is the readiness probe, not a fault.

**The source scan.** `AGG` sources `EVENTS` with `filter_subject: ev.1` (8.4 M messages, 1.6 GB) plus
`IDLE` (one message) and, for D5e/f, `IDLE2` (**empty**):

| `AGG`'s sources | `Restored … in` | samples |
|---|---:|---|
| `EVENTS/ev.1` + `IDLE` (1 msg) + **`IDLE2` (empty)**, twice | **2.572 s / 2.577 s** | 15 of 15 in `startingSequenceForSources → LoadPrevMsgMulti → LoadPrevMsg → prevMatching → loadMsgsWithLock`; no disk reads (page cache), ~620 MB/s on one goroutine |
| `EVENTS/ev.1` + `IDLE` (1 msg) | **23 ms** | none (too fast to sample) |
| the same pair, busy-disk regime (D5a vs D5b) | 4.656 s with an empty `IDLE`, 1.645 s without | — |

`EVENTS`, with no sources, restored in 3 ms in the same restarts. So on 2.14.6 a stream with `sources`
re-reads itself end to end at every start for as long as any source has no message in it; the cost is
its own size at the volume's read speed on one core — the thread's 7 GB at 20 MB/s is six minutes,
this laptop's 1.6 GB from RAM is 2.6 s. Gone in 2.15 (`sources.db`).

## Run E — 1.2 M subjects against 6 (row 9)

`CARD`: 3,000,000 × 100 B over **1,200,000** subjects (`card.0000000`…`card.1199999`); `FLAT`: the
same over six.

- **RSS**: 17.7 MiB → **540.6 MiB** after `CARD`; **+87.4 MiB** after `FLAT`. Taking `FLAT`'s delta as
  the cost of 3 M cached messages, the subjects cost ~435 MiB, **~380 B per subject** of whole-process
  RSS — between the maintainer's "100 megs" per million and Synadia's "a few hundred bytes".
- **`index.db`**: `FLAT`'s appeared 130 s after the fill (1,324 B); `CARD` got **none in five
  minutes** — above the threshold the periodic write is skipped — and the clean stop wrote one of
  **19,201,304 B** (Σ(len(subject)+4) predicted 18,088,890; the rest is varints above one byte).
- **Restart, 3.2 M messages each**: clean stop **`FLAT` 2 ms, `CARD` 153 ms** (the 1.2 M-entry tree
  rebuilt from the file); SIGKILL **303 ms / 1.024 s**; `index.db` deleted **309 ms / 850 ms**. So for
  a high-cardinality stream the index path is ~6× the full read, not ~150× as for six subjects — and
  after an unclean stop there is no index to take.
- The filtered-read timing planned for E3 was not made: the filter `card.1*` is not a wildcard (below).

## Run F — `max_msgs` past a billion (rows 4, 5)

`nats stream edit EVENTS --max-msgs 1000000000` and `--max-msgs 10000000000`: both accepted,
`config.max_msgs` reads back as given. At 134 B per message, **a billion messages of this shape is
124.8 GiB and 15,000 blocks** — arithmetic, not a fill.

## Found on the way — a `*` inside a token (`SI-3`)

`filter_subject: pt.1*` on a five-message stream: `num_pending` **3** and the subjects report **3
subjects** (the subject tree reads `1*` as `1` followed by anything), delivery **nothing** and a
direct get `no message found` (the sublist reads `1*` as the literal token). Reproduced twice; the
mechanism is `stree/parts.go:79–147` against `sublist.go:1172–1183`. In `inbox/server-issues.md`.

## Questions it answers

Rows **13** (the scan, measured and sampled), **9** (RSS, `index.db`, restart at 1.2 M subjects),
**4** and **5** (the edit accepted; the arithmetic).

## Pages touched

[[jetstream-recovery-is-slow]] · [[filestore-layout]] · [[mirrors-and-sources]] ·
[[jetstream-sizing]] · [[stream]] · [[kubernetes-storage]] · [[nats-server-2.15-preview]]
