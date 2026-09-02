# Plan — discussions triage, and the public form of the posed rows (proposed 2026-09-03)

**Result (2026-09-03).** All four steps done in one session: `tools/triage-discussions.py` and `raw/gh-discussions-index/` (the 484 discussions as five GraphQL pages plus a rendering), `inbox/gh-discussions-toc.md` registered and rendering (40 ★ by the stated rule); the 30 posed rows searched for their public form — **21 replaced `own` with a URL** (8 for one half of the row), 9 recorded as *searched, not found* in backlog §5(a); **21 new bank rows 138–158** from the ★ threads nobody had cited, 8 answered on arrival. Bank 108 / 137 → **116 / 158**, `own` 30 → 9, lint 0 · 0, wanted 0. No page written, by design. **Next: phase D** — the change layer, release notes 2.10.0 → 2.14.6.

Say **`start the plan inbox/plan-discussions-triage-2026-09-03.md`** to work this file — name it
explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-03, commit `1a5a6ec`).** 310 pages; question bank 137 rows, 108
answered, 29 open (7 asked, 22 posed `design`); wanted 0; `(unverified)` 12 across 9 pages; citation
drift 0, unlanded ripples 0; staleness 0 behind nats-server 2.14.6; docs issues 53, server issues 3.
Binary `nats-server v2.14.6`, `nats` CLI 0.4.0. `raw/gh-discussions/` holds 49 threads, fetched one
at a time; 89 distinct discussions are cited in the bank's *asked at* column.

**Why this plan.** Phase C of the maintainer's programme. The question bank was seeded on 2026-08-31
by reading the 484 `nats-io/nats-server` discussions **by title** (`inbox/plan-first-ingests-2026-08-31.md`,
*Method notes*); nothing of that reading was kept, so it cannot be re-run, filtered or diffed, and the
30 posed rows (108–137) were written from the maintainer's head because design questions hide in
bodies and replies, not titles. This plan does for the discussions what `tools/triage-adrs.py` did
for the ADRs: a regenerable table under `inbox/`, its inputs under `raw/`, rendered by the viewer —
and then uses it to find the public form of each posed row, so `own` becomes evidence where it can,
and to add the strong threads the seeding missed. The bank growing here is the point.

**Two constraints on top of *Operation: plan*.** Everything the script fetches is public GitHub
content and goes into `raw/` verbatim (JSON as returned, plus a rendering), with a `raw/sources.md`
row; comment and reply bodies fetched only to be searched stay in `local/scratch/gh-index/` and are
never cited — a thread the scout picks is promoted with `tools/fetch-discussion.py --out
raw/gh-discussions` like every other one. A row's `own` is replaced only by a thread that asks **the
row's question with its trade-off**, not one that merely touches the topic; the scout file records
the judgement per row either way.

**Done when** `inbox/gh-discussions-toc.md` exists, is registered in `wiki.json` and renders as a
filterable table; every `own` row (108–137, all 30) has a *searched* verdict in the scout file — a
URL in the bank or "searched, not found" in `inbox/scout-backlog.md` §5(a); the ★ threads not yet in
the bank are rows, with URL; backlog §5(a) struck.

---

## Step 1 — `tools/triage-discussions.py` → `inbox/gh-discussions-toc.md` · status: done 2026-09-03 — the script, `raw/gh-discussions-index/` (five JSON pages verbatim + `discussions-2026-09-03.md`, manifest row), the table with 484 rows registered in `wiki.json` (`tocs` + `raw_collections`, article anchors), README rows; built and renders. ★ rule as proposed, no tightening needed: 40 ★, **28 not in the bank**; 181 answered, 103 upvoted, 22 design-shaped (15 not in the bank), 89 in-bank, 48 in-raw, 48 summaries auto-linked. The comment cache for step 2 is in `local/scratch/gh-index/` (808 comments, 48 threads with replies truncated past 5).

*Operation: triage.* The script pages `repository.discussions(first:100)` through `gh api graphql`
(number, title, URL, category, author, opened, last updated, answered and by whom, upvotes, comment
count, closed, the original post's body) and writes the replies verbatim to
`raw/gh-discussions-index/discussions-<DATE>-p<n>.json`, plus one rendering
`discussions-<DATE>.md` (one `##` per thread — meta line, then the original post) that the viewer
serves and the TOC anchors into (`raw_collections` → `article_pattern`). A manifest row in
`raw/sources.md`. Then `inbox/gh-discussions-toc.md`: `| # | title | category | opened | answered |
upvotes | comments | area | flags | link | summary |`, sorted by number; `area` guessed from the
title's keywords and said to be; flags `answered`, `upvoted` (someone other than the author — the
author's own upvote is the default 1), `design` (a stated title regex: *vs*, *or*, *best practice*,
*how should*, *recommended*, *architecture*, *pattern*, *strategy*, *multi-tenant* …), `in-bank`
(the number already sits in a bank row), `in-raw` (`raw/gh-discussions/gh-<n>.md` exists), `skip`
for *Polls* and *Show and tell*; **★ rule stated in the script and in the table's head** — the
default proposal is *answered and upvoted, or design-shaped and answered*, to be tuned to the
distribution once seen and reported with the counts. The `summary` column is preserved on re-run
**and** filled from `wiki/summaries/` whose `source-url` names the thread. Register the table in
`wiki.json` → `tocs` (nav *Discussions*, filters ★, answered, design, in-bank, in-raw) and the
collection in `raw_collections`; `--offline` rebuilds from the newest raw set without calling
GitHub. README rows for the tool and the table. `python3 tools/build-site.py` to prove it renders.
Log, lint.

## Step 2 — scout 5(a): the public form of rows 108–137 · status: done 2026-09-03 — `inbox/scout-posed-rows-public-form-2026-09-03.md`. Searched: the index (titles + original posts), the comment cache (808 comments), the Stack Overflow tags (60 queries). **21 found** (13 whole, 8 partial: 109, 113, 117, 118, 122, 126, 130, 137), **9 not found** (112, 116, 123, 127, 128, 131, 132, 133, 134) recorded in backlog §5(a). Bank cells replaced for the 21 (row text unchanged), title list extended, note appended; `own` 30 → 9. Row 129 = row 57's thread (gh#6182). One Stack Overflow find (row 120, so#78477337, unanswered). Nothing ingested; the threads for phase G's page scouts are listed in the file.

*Operation: scout.* `inbox/scout-posed-rows-public-form-2026-09-03.md`. For each of the 30 posed
rows: grep the index (titles and original posts) and a scratch fetch of every thread's comments and
replies (`local/scratch/gh-index/`, never cited) for the row's trade-off — its two options named, or
its "how should I …" — then, where the discussions give nothing, one Stack Overflow search on the
`nats-jetstream` / `nats.io` tags through the Stack Exchange API. Per row: the verdict (*found* with
the thread and the sentence that asks it, or *searched, not found* with what was searched), and for
a found thread whether it is already in the bank under another number. Replace `own` with the URL in
`inbox/question-bank.md` for the found rows (the row's question text stays; the URL is evidence,
not a rewrite); write the *searched, not found* rows into backlog §5(a) so the search is not
repeated. Threads worth ingesting later are named for phase G's page scouts, not ingested here.

## Step 3 — the ★ threads that are not rows · status: done 2026-09-03 — 24 ★ threads outside the bank read; **21 rows added (138–158)**, 8 answered on arrival by existing pages (141, 142, 143, 145, 147, 151, 152, 158), 13 open; 3 skipped with a reason (gh#2933 duplicate of 108/111, gh#3164 test helper, gh#6301 third-party chart). No tightening of the ★ rule needed (well under 40). Row 150 carries a page-vs-maintainer contradiction to settle on the binary. Bank 108 / 137 → 116 / 158.

From the TOC, every ★ thread whose number is in no bank row: read its title and original post, and
write a bank row — the question as the architect or operator holds it, `area`, the URL, flags
(`design` where the shape is one, `★` only where *The question bank* would give it) — with
`answered by` filled **only** where an existing page already states the answer with a citation and a
version, otherwise empty (that is open work for phases D–I, and the finish line counts it). Report
how many rows were added, how many arrived already answered, and how the open count moved. If the
★ rule yields more than about 40 new rows, tighten it (say to *answered, upvoted by two or more,
or design-shaped*) and record the tightening in the script's docstring before adding rows.

## Step 4 — close: backlog §5(a), the result line, the log · status: done 2026-09-03 — §5(a) struck (heading and record), result line written, log entries for steps 3 and 4, megaplan phase C marked done. TOC: 484 rows, 40 ★ (3 not in bank, the skipped ones), 129 in-bank, 48 ingested. Bank 116 / 158, open 42 (24 design), `own` 9. Lint clean.

Strike §5(a) of `inbox/scout-backlog.md` (leave §5(b), phase G's per-page scouts, open) naming the
scout file and the steps; the result line at the top of this file; `wiki/log.md`; the megaplan's
`status:` / `next:` for phase C. Report the bank (rows, answered, open, `own` remaining), the TOC's
counts (rows, ★, in-bank, ingested), and lint.

---

## Not in this plan

- Ingesting any thread the TOC or the scout surfaces — phase G scouts per pattern page (§5(b)), and
  the sizing rows of phase H.
- The 22 open design rows themselves — phase G writes the pattern pages.
- Re-mining Stack Overflow as a table — a `triage-stackoverflow.py` may follow if the SO searches in
  step 2 show the tags hold design questions the discussions do not.
