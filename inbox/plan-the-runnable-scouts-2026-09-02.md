# Plan — the runnable scouts, and the last wanted page (proposed 2026-09-02)

**Result (2026-09-03).** All six steps done: rows 4, 5, 9, 13, 76, 91, 105 filled — every one *answered*, none needed `no-public-answer` — and `consumer-keeps-redelivering` written from issue #6921, Stack Overflow #78603662, three runs on 2.14.6 and the redelivery summaries; `python3 tools/lint.py` reports **wanted: none**; backlog sections 1 and 2 struck. Over the plan: 286 → 310 pages, bank 101 → 108 of 137, docs issues 48 → 53, server issues 2 → 3, six observed runs recorded. **Next: phase C** — `tools/triage-discussions.py` and the public form of the posed rows.

Say **`start the plan inbox/plan-the-runnable-scouts-2026-09-02.md`** to work this file — name it
explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-02, commit `f4400cc`).** 286 pages; question bank 137 rows, 101
answered, 36 open (14 asked, 22 posed `design`); wanted 1 (`consumer-keeps-redelivering`);
`(unverified)` 12 across 9 pages; citation drift 0, unlanded ripples 0; staleness 0 behind
nats-server 2.14.6; docs issues 48, server issues 2. Binary `nats-server v2.14.6`, `nats` CLI 0.4.0,
and since today `bash tools/lab/cluster.sh up 3` starts the scratch cluster.

**Why this plan.** Phase B of the maintainer's programme. `inbox/scout-backlog.md` marked two of its
groups *runnable* on 2026-09-01 — the mirror and replication rows (76, 91, 105) and the stream-scale
rows (4, 5, 9, 13) — and running the binary is where this wiki's findings have come from (docs issue
#37, `SI-1`, today's healthcheck correction). Between them sits the wiki's only red link,
`consumer-keeps-redelivering`: the commonest operator symptom in the bank's area, pointed at from the
index's *Wanted pages*, with five redelivery summaries already ingested and issue #6921 not yet in
`raw/`. Seven rows, one page, two backlog sections.

**Two constraints on top of *Operation: plan*.** Cap each ingest at **~8 summaries** and report
`tools/lint.py`'s unlanded-ripple count before and after. Every run goes through `tools/lab/` where
the shape allows it, is recorded verbatim under `raw/nats-server-src/<topic>-observed-v2.14.6.md`,
and quotes `nats-server --version` — a measured number on one laptop is evidence of a *mechanism*,
never a stated limit.

**Done when** rows 4, 5, 9, 13, 76, 91, 105 are filled (answered, or bold `no-public-answer`),
`consumer-keeps-redelivering` exists and is cited, `python3 tools/lint.py` reports **wanted: none**,
and backlog sections 1 and 2 are struck.

---

## Step 1 — scout 1: mirror and replication internals (rows 76, 91, 105) · status: done 2026-09-02 — `inbox/scout-mirrors-and-replication-2026-09-02.md`, 12 candidates, none blocked. Row 76 is answered upstream (an everything-matching `FilterSubject` on a mirror takes the per-subject path on a sparse stream; the initial-sync slowness was never explained), row 91 is unanswered by maintainers (one community comment from the source, a reproduction attached), row 105's first half was fixed in nats.go 2024-03 and its second half is that mirrored object buckets are still hand-built (no `nats object add --mirror`, nats.go #1874 open). Three runs named; six summaries proposed. Waiting for the user's pick.

*Operation: scout.* Write `inbox/scout-mirrors-and-replication-2026-09-02.md`: 5–10 candidates
with URL, one line, relevance flag, rows, pages touched. Fetch and skim each; say which are blocked.
The three threads first — [gh#8417](https://github.com/nats-io/nats-server/discussions/8417),
[gh#8444](https://github.com/nats-io/nats-server/discussions/8444),
[issue #5106](https://github.com/nats-io/nats-server/issues/5106) — then the docs' mirror pages
not yet in `wiki/summaries/`, the ADR that specifies sourcing and mirroring, and the source ranges
in `server/stream.go` that do the catch-up (`processMirrorMsgs`, the mirror consumer's
`FlowControl`/`Heartbeat`, and what a file-backed mirror writes per message). Name the three runs
the ingest will make (row 76: the same KV mirror on file and on memory storage, timed; row 105:
`nats object ls` on a mirrored bucket, then the same across two domains through a leafnode; row 91:
catch-up with and without a competing reader) and the `SI-1` overlap to check before writing a new
`SI-` entry. **Stop there; the user picks.**

## Step 2 — the runs, and the ingest for scout 1 · status: done 2026-09-02 — s-gh-8417-kv-mirror-file-vs-memory, s-gh-8444-mirror-catchup-under-a-reader, s-issue-5106-object-store-mirror-list, s-nats-server-mirror, s-nats-server-mirrors-observed, s-relnotes-2.14.4, s-nats-go-kv-object-mirror (7 summaries); raw: gh-8417, gh-8444, issue-5106, client-issues-object-store-mirror, release-notes v2.14.1–v2.14.6, mirror-v2.14.6.md, mirrors-observed-v2.14.6.md + mirrorlab.py, nats-go-src/kv-object-mirror-v1.53.1.md. Runs A/B/C made (B in three forms; the third, with Go readers, is the one that answers). New gotcha `consumer-slow-on-a-sparse-stream`; rows 76, 91, 105 filled (91 answered with the mechanism and the run, marked unanswered upstream). Docs issues #49 (ADR-59 consumer names), #50 (object-store mirroring undocumented), #51 (ADR-57 read-by-name gap). No new `SI-`: with no mirror the hub sees nothing of the leaf's bucket, so row 105 is not SI-1 restated. Found on the way: an un-acked publish flood is dropped at the stream's 100,000-message inbound queue (`publishing`).

Runs through `tools/lab/` (a three-node cluster for the mirror timings; the hub/leaf pair of
`object-store-across-leafnode-observed-v2.14.6.md` for row 105, started by hand with its two domain
configs), recorded in `raw/nats-server-src/mirrors-observed-v2.14.6.md`. Then ingest the picked
candidates (≤ 8 summaries). Ripple: [[mirrors-and-sources]], [[key-value]], [[object-store]],
[[direct-get]], [[cross-domain-sourcing]], [[object-store-list-is-slow]], [[jetstream-domain]],
[[filestore-layout]] where the per-message write cost explains row 76, and the gotcha or section
each row's answer needs. Fill rows 76, 91, 105 — answered, or bold `no-public-answer` with the page
that says so. A server surprise goes to `inbox/server-issues.md` as `SI-3` with its reproduction,
unless it is `SI-1` again; a doc contradiction to `inbox/docs-issues.md`, verified.

## Step 3 — scout 2: stream scale ceilings and the filestore (rows 4, 5, 9, 13) · status: done 2026-09-02 — `inbox/scout-stream-scale-2026-09-02.md`, 15 candidates (six threads, the source at v2.14.6, two 2.15 PRs, the release lines, one blog, two check pages), none blocked. Row 13 is unanswered upstream and answerable here: the reporter's own goroutine dump shows the six minutes in `startingSequenceForSources` — a sourcing stream's backward scan for each source's last message, worst when a source is idle — not in the index rebuild; fixed for 2.15 by `sources.db` (#8282 in v2.15.0-preview.1, #8516), still present at v2.14.6. Underneath it the general answer: `recoverFullState` reads `index.db` and stats the blocks; a stale, missing, or never-written one (above 1,000,000 subjects or interior deletes the periodic write is skipped) means every block is read. Row 9: two maintainers (gh#8333 ~100 MB per 1 M small subjects; gh#5202 the ART index since 2.10.9) plus Synadia's few-hundred-bytes figure and the three uses of the 1 M constant. Rows 4 and 5: no cap in the server (no 1e9 constant, `uint64` sequences, a maintainer's stream at 1,174,510,552) and a maintainer's "no hard limit" — row 5 is answerable, not `no-public-answer`. Three runs named (D: 50 M fill, four restarts incl. a sourcing stream with an idle source; E: 1.2 M subjects vs 6; F: `--max-msgs 1000000000` accepted), disk budget ~9 GB, 50 M fill capped at 15 min. Picked 2026-09-02 by the user as proposed (candidates 1, 2, 3, 4, 6, 7, 9, 11, 12 and 8 ingested; 5 to phase D; 10 a docs-issue check; 13 a pointer; 14 skipped); run D's S2 variant, or any part of run D that adds nothing over the source, may be skipped. Step 4 in a fresh session.

*Operation: scout.* `inbox/scout-stream-scale-2026-09-02.md`. The four threads —
[gh#7147](https://github.com/nats-io/nats-server/discussions/7147),
[gh#7032](https://github.com/nats-io/nats-server/discussions/7032),
[gh#8333](https://github.com/nats-io/nats-server/discussions/8333),
[gh#8001](https://github.com/nats-io/nats-server/discussions/8001) — plus whatever public source
states a recovery mechanism (release notes that changed startup, the docs' filestore pages, the
source's `recoverMsgs` / index rebuild path), and a check of what [[filestore-layout]] already says
about `index.db` at `len(subject) + 4` per subject for row 9. Name the run for row 13 (fill a file
stream to tens of millions of small messages through the lab, restart, time `Restored N messages …`
and what precedes it) with its disk budget stated. **Stop there; the user picks.**

## Step 4 — the run, and the ingest for scout 2 · status: done 2026-09-03 — runs D/E/F on 2.14.6 (`stream-scale-observed-v2.14.6.md` + the run scripts), the S2 variant skipped; 8 summaries: s-gh-8001-jetstream-startup-slow-50m, s-gh-8333-high-cardinality-subjects, s-gh-5202-max-unique-subjects, s-gh-7147-one-billion-cap, s-gh-7032-max-msgs-known-good, s-nats-server-filestore-recovery, s-nats-server-stream-scale-observed, s-synadia-how-many-subjects; raw: gh-8001/8333/5202/7147/7032, filestore-recovery-v2.14.6.md, synadia-blog/how-many-subjects…, a new collection synadia-insights/. New gotcha `jetstream-recovery-is-slow`; sections on 12 pages. Rows **4, 5, 9, 13 answered** (5 by a maintainer's "no hard limit" — not `no-public-answer`). Docs issues #52 (missing) and #53 (enhancement). `SI-3`: not the attribution the scout expected (that is recorded as fact on the pages) but a `*` inside a token that `num_pending` counts as a prefix wildcard and delivery treats as a literal, found through a mistaken filter in run E, reproduced on five messages. Measured: clean restart 3–27 ms for 50 M messages, 6.4 s after SIGKILL, 2.57 s for a 1.6 GB sourcing stream with one empty source vs 23 ms without.

The row-13 run, recorded in `raw/nats-server-src/stream-scale-observed-v2.14.6.md` (state the
message count, bytes on disk, and the restart timings; if the laptop cannot reach the thread's
scale, say what scale it reached and what the log shows there). Ingest the picked candidates (≤ 8).
Ripple: [[filestore-layout]], [[jetstream-sizing]], [[stream]], [[defaults-and-limits]] for any
stated bound, a gotcha page if the threads give a symptom (`jetstream-recovery-is-slow` is the
likely slug), and [[nats-server-2.14]] if a release changed recovery. Fill rows 4, 9, 13; row 5 is
expected to be **`no-public-answer`** — the page that says so is the answer, not an invented number.

## Step 5 — `consumer-keeps-redelivering` · status: done 2026-09-03 — s-issue-6921-last-per-subject-acks, s-so-78603662-acked-but-redelivered (a new `raw/stackoverflow/` collection; row 14's own thread, read for the first time), s-relnotes-2.11.5, s-relnotes-2.11.2 (with the 2.10.16/2.10.17 lines), s-relnotes-2.14.1, s-nats-server-redelivery-observed (6 summaries; runs G/H/I on 2.14.6 in `redelivery-observed-v2.14.6.md` with five scripts). Gotcha **`consumer-keeps-redelivering`** written: five causes ranked, a version table; lint **wanted: none**. Rows 14–19 gain the page. Docs issue #4 extended (the unit of every duration field is hidden with the node; #78603662 is the cost); no new docs issue, no `SI-`. Found: `backoff: [10000]` is `Ack Wait: 10µs` and every acked message is then processed exactly `max_deliver` times once the handler takes 5 ms; a redelivery needs a pull waiting when the deadline passes; #6921's fix is #7005 in v2.11.5, unnamed on the issue, and its recipe delivers cleanly on 2.14.6.

```
ingest https://github.com/nats-io/nats-server/issues/6921
```

Through the GraphQL fetch the other `raw/gh-issues/` files were made with. Then the gotcha page,
symptom first (the log lines, `nats consumer info` fields and advisories a redelivery loop shows),
causes ranked by how often they are the answer — each with *how to confirm* and *the fix* — from
#6921 plus [[s-gh-6628-ackwait-vs-dupe-window]], [[s-gh-6350-exponential-backoff]],
[[s-gh-4972-nak-with-delay-blocks]], [[s-gh-5631-nak-not-immediate]],
[[s-nats-server-nak-backoff-observed]], [[s-docs-delivery-and-acknowledgment]] and
[[s-docs-acknowledgment]]; *Explained by* [[ack-and-redelivery]]; related [[dead-letter-queue]],
[[worker-pool]], [[nats-timeout]]. Strike the wanted line in `wiki/index.md`, add the page under
*Gotchas*, and fill the bank rows the page answers (check rows 16–19 and any row whose question is
the symptom). Lint must report **wanted: none**.

## Step 6 — close the backlog sections, and the log · status: done 2026-09-03 — backlog sections 1 and 2 struck with the scout files and steps; result line below the title; log entry written. Bank 101 → 108 / 137, wanted 1 → 0, pages 286 → 310, docs issues 48 → 53, server issues 2 → 3, unlanded 0 → 0.

Strike sections 1 and 2 of `inbox/scout-backlog.md` with the scout files that closed them; the
plan's result line; `wiki/log.md`. Report the bank (rows filled, `no-public-answer` rows named),
`inbox/server-issues.md` and `inbox/docs-issues.md` counts before and after, and lint.

---

## Not in this plan

- Backlog section 3 (rows 8, 10, 11, 66, 68) — phase H, the sizing family.
- Row 25 (core NATS ordering) — phase F, with the `learn/core-nats` chapters.
- The posed design rows — phases C and G.
