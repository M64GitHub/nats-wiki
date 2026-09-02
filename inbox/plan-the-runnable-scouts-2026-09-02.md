# Plan — the runnable scouts, and the last wanted page (proposed 2026-09-02)

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

## Step 3 — scout 2: stream scale ceilings and the filestore (rows 4, 5, 9, 13) · status: open

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

## Step 4 — the run, and the ingest for scout 2 · status: open

The row-13 run, recorded in `raw/nats-server-src/stream-scale-observed-v2.14.6.md` (state the
message count, bytes on disk, and the restart timings; if the laptop cannot reach the thread's
scale, say what scale it reached and what the log shows there). Ingest the picked candidates (≤ 8).
Ripple: [[filestore-layout]], [[jetstream-sizing]], [[stream]], [[defaults-and-limits]] for any
stated bound, a gotcha page if the threads give a symptom (`jetstream-recovery-is-slow` is the
likely slug), and [[nats-server-2.14]] if a release changed recovery. Fill rows 4, 9, 13; row 5 is
expected to be **`no-public-answer`** — the page that says so is the answer, not an invented number.

## Step 5 — `consumer-keeps-redelivering` · status: open

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

## Step 6 — close the backlog sections, and the log · status: open

Strike sections 1 and 2 of `inbox/scout-backlog.md` with the scout files that closed them; the
plan's result line; `wiki/log.md`. Report the bank (rows filled, `no-public-answer` rows named),
`inbox/server-issues.md` and `inbox/docs-issues.md` counts before and after, and lint.

---

## Not in this plan

- Backlog section 3 (rows 8, 10, 11, 66, 68) — phase H, the sizing family.
- Row 25 (core NATS ordering) — phase F, with the `learn/core-nats` chapters.
- The posed design rows — phases C and G.
