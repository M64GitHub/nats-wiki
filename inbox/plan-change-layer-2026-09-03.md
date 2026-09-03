# Plan — the change layer: release notes 2.10.0 → 2.14.6 (proposed 2026-09-03)

**Result (2026-09-03, all nine steps done in two sessions).** 70 release bodies in `raw/release-notes/` with a manifest row; `inbox/relnotes-toc.md` (70 rows, 26 ★) in the viewer with every 2.14 row and the preview linked to a summary; five change-layer summaries (`s-relnotes-2.10`, `-2.11`, `-2.12`, `-2.14`, `-2.15-preview`) read per minor and checked against the two upgrade guides and the server source; the five release entities rewritten as changelogs with *Which patch to be on* and *The default diff*; ~170 version-note sections rippled; **`since:` on every reader page with `verified-against`** — 47 given `[2.10]` in step 7, 8 with a stated reason instead, residue 0; `inbox/check-defaults-v2.10.29 / v2.11.17 / v2.12.15.md` and the default diff per minor in `wiki/log.md` (one documented default moved: `max_buffered_msgs`, 2.12.0); docs issues **#54–#64** (60 → 64 this session), one wiki correction (the subject tree is 2.10.10); bank 116 / 137 → 121 / 160. Lint: 317 pages, wanted 0, drift 0, unlanded 0, staleness 0 behind 2.14.6. **Next:** phase E, the reference layer (`inbox/plan-the-reference-layer-<DATE>.md`) — read `raw/nats-docs/reference/system/` and `reference/jetstream/api/` end to end first.

Say **`start the plan inbox/plan-change-layer-2026-09-03.md`** to work this file — name it
explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-03, commit `ba61ccc`).** 310 pages; question bank 158 rows, 116
answered, 42 open (18 asked, 24 posed `design`); wanted 0; `(unverified)` 12; citation drift 0,
unlanded ripples 0; staleness 0 behind nats-server 2.14.6; docs issues 53, server issues 3. Binary
`nats-server v2.14.6`, `nats` CLI 0.4.0. `raw/release-notes/` holds `_tags-and-dates.md` (291 tags)
and **11 release bodies** (v2.10.16, v2.10.17, v2.11.2, v2.11.5, v2.14.0–v2.14.6), each fetched for
one question; five `s-relnotes-*` summaries exist (2.11.2, 2.11.5, 2.14.0, 2.14.1, 2.14.4) and two
upgrade-guide summaries (`s-docs-upgrade-to-2.12`, `-2.14`). The release entities for 2.10 and 2.11
say of themselves "**not a changelog**" and list only what ADRs attribute to them. Of the 55 reader
pages under `concepts/`, `internals/`, `operations/`, `gotchas/` and `reference/` that carry
`verified-against`, **55 have no `since:`** (19 concepts, 5 internals, 10 operations, 15 gotchas, 6
reference); 23 do.

**Why this plan.** Phase D of the maintainer's programme. Version is existential in this wiki, and
so far every "since 2.x" on a page comes from an ADR's tag or a docs upgrade guide — second-hand,
and silent on the patch releases where defaults move, flags arrive and behaviours are fixed. The
release bodies are the primary record: 69 GA releases from v2.10.0 (2023-09-19) to v2.14.6
(2026-08-27) plus the v2.15.0-preview.1 body, every one with the same `## Changelog` shape
(`### Added`, `### Changed`, `### Improved`, `### Fixed`, `### CVEs`, `### Removed`, `### Downgrade
compatibility note`, plus `> [!WARNING]` / `> [!IMPORTANT]` admonitions). This plan does for them what
`tools/triage-adrs.py` did for the ADRs and `tools/triage-discussions.py` for the discussions —
every body into `raw/`, a regenerable table under `inbox/` rendered by the viewer — and then reads
them **per minor** into four change-layer summaries, so that `since:` on every reader page, the
release entities and the default tables rest on the notes themselves. It also gives
`tools/check-defaults.py` its diff base: one report per minor's last patch, diffed in sequence.

**Scope decisions, stated once.** (1) One raw file per **release** — the 69 non-prerelease tags of
2.10–2.14 (including `v2.10.27-binary` and `v2.11.1-binary`, the CVE binary-only releases) and the
one 2.15 preview the megaplan names. The 129 RC and preview bodies are **not** written: each GA body
is the consolidated changelog of its RCs (the 2.10.17 body is 5.6 KB against nine RC bodies of ~1 KB
each; the 2.12.0 body matches RC.6's), and `_tags-and-dates.md` already records their existence and
dates. The tool says so in its docstring and the manifest row says so. (2) The **unit of ingestion is
the minor line**, read end to end — the megaplan's decision, because the value is the change layer
(what moved, in which release), not 70 summaries of dependency bumps. The five per-patch summaries
that exist stay and are linked from the per-minor one, not duplicated. (3) `since:` uses the wiki's
existing convention — `[2.10]` means *present at 2.10, the oldest line this wiki covers*, and the
page says so in words where it matters; a specific minor is written only when a release body (or an
already-cited ADR or guide) attributes the arrival. Nothing older than 2.10 is asserted from the
archive: the 2.0–2.9 bodies are in the cache but out of scope, and `CLAUDE.md` names 2.10 as the
floor. (4) Copyright as always: the summaries paraphrase by kind of change with the PR number and
tag; the bullet lists are not copied. Dependency bumps, Go versions and the *Complete Changes* links
are noted as columns, not prose.

**Done when** (measured): every release from v2.10.0 to v2.14.6 has a body in `raw/release-notes/`
with a manifest row; `inbox/relnotes-toc.md` exists, is registered in `wiki.json` and renders as a
filterable table; the four per-minor summaries and the 2.15 preview summary exist and the five
release entities cite theirs (their "not a changelog" notes gone); **every reader page with
`verified-against` carries `since:`** or a one-line reason in `## To verify` why it cannot — the
script in step 7 reports 0; `inbox/check-defaults-v2.10.29.md`, `-v2.11.17.md`, `-v2.12.15.md`
exist and `wiki/log.md` records the default diff per minor; every docs contradiction the notes
surfaced is in `inbox/docs-issues.md`, verified.

---

## Step 1 — every release body into `raw/release-notes/` · status: done 2026-09-03 — `tools/triage-releases.py --fetch --include v2.15.0-preview.1`: three API pages (291 releases) cached, **59 bodies written** (2.10 ×27, 2.11 ×16, 2.12 ×15, the 2.15 preview), 11 kept and verified unchanged, **70 in all**; the live fetch equals the 2026-09-02 cache on every tag, body and date; 129 RC/preview bodies skipped by design, 92 tags below the 2.10 floor. Manifest row, README, Map, scratch index, log. Lint clean.

`tools/triage-releases.py --fetch`: page `gh api repos/nats-io/nats-server/releases?per_page=100`
(three pages, 291 releases) into `local/scratch/releases/releases-<DATE>-p<n>.json` (the 2026-09-02
pages stay as the fallback: `--offline` reads the newest cached set instead of calling GitHub), then
write one `raw/release-notes/<tag>.md` per non-prerelease tag from v2.10.0 up, plus any prerelease
named with `--include` (used once, for `v2.15.0-preview.1`), in exactly the form of the files that
exist: the `<!-- source: … · fetched <DATE> -->` provenance line, `# Release <tag> — published
<date>`, a blank line, the body with CRLF normalised to LF (the existing 11 were written that way —
checked byte for byte against the cache on 2026-09-03), trailing newline. **A file that exists is
never rewritten** (raw is immutable); the tool prints the skips, and compares each existing file's
body with the fetched one so an edited release body is reported rather than silently diverging.
Expected: 59 new files, 70 in all. Then the manifest row in `raw/sources.md` (what was added, from
which endpoint, on which date, what was deliberately left out and why), a `local/scratch/INDEX.md`
row for the new cache pages (and the old row marked promoted), README and `CLAUDE.md` Map lines for
the tool. Log, lint. Report the file count per minor and any body the live fetch and the cache
disagree on.

## Step 2 — `tools/triage-releases.py` → `inbox/relnotes-toc.md` · status: done 2026-09-03 — 70 rows, registered in `wiki.json` (nav *Releases*), renders with every tag linked to its body. ★ rule as proposed, **26 ★** (2.10 10, 2.11 8, 2.12 5, 2.14 2, 2.15 1), no tightening; two flag defects fixed (the v2.14.0 date from `_tags-and-dates.md`; `downgrade` no longer matches *downgraded to QoS0*). Counts: added 29, changed 6, removed 2, cve 12, downgrade 5, warning 5, withdrawn 2, binary 2, cited 37, 7 with a summary. The v2.12.5 consumer-loss warning noted for step 5. Log, lint clean.

*Operation: triage.* The same tool without `--fetch` builds the table from `raw/release-notes/`:
`| tag | minor | published | go | items | flags | file | summary |`, oldest first, one row per
raw body (the 2.15 preview included, flagged). `go` is the `### Go Version` line; `items` counts the
changelog bullets outside *Dependencies* and *Complete Changes*. Flags are read off the body's own
sections — the survey of the 70 bodies on 2026-09-03: `Fixed` 67, `Improved` 53, `Dependencies` 53,
`Added` 29, `CVEs` 12, `Changed` 6, `Downgrade compatibility note` 3, `Removed` 2, admonitions
`IMPORTANT` 3 / `WARNING` 2 — so: `added`, `changed`, `removed`, `cve` (a `### CVEs` section or a
`CVE-`/`GHSA-` id), `downgrade` (the section, or *downgrade* in the body), `warning` (an admonition),
`withdrawn` ("contains a regression … upgrade to … instead"), `default` (the word *default* in the
changelog — a filter for the change layer, 22 bodies), `binary` (a `-binary` tag), `first` (`x.y.0`),
`preview`, `cited` (a non-summary wiki page names the tag). **★ rule, stated in the script and the
table head and printed with the counts on every run**: *changed, removed, downgrade, withdrawn,
warning, cve, or the first release of a minor* — the releases an operator must read before or after
upgrading, because something they configured, relied on, or must patch moved. The `summary` column
is preserved on re-run **and** filled from `wiki/summaries/*.md` whose `source-path` names the file
or whose `aliases` list the tag (the per-minor summaries will alias every tag they fold in).
Register in `wiki.json` → `tocs` (nav *Releases*; `collection: release-notes` is already in
`raw_collections`; filters ★, added, changed, cve, downgrade, warning, default, cited); README and
Map rows for the table; `python3 tools/build-site.py` to prove it renders. Report the counts by
minor (releases, ★, items) — they set the reading order of steps 3–6 — and the ★ total; tune the
rule if it stars more than about 30 of 70 and record the tuning in the docstring. Log, lint.

## Step 3 — ingest the 2.10 line (v2.10.0 → v2.10.29, 29 releases) · status: done 2026-09-03 — `s-relnotes-2.10` (the change layer by kind, a data-integrity table, three CVEs) plus `s-gh-6005-sourcing-memory-stream-restart` and `s-gh-6748-cve-binary-release-docker-images` (threads fetched whole); the release entity rewritten as a changelog; **41 pages rippled** with version notes; bank rows **150, 154, 155 filled** (116 → 119 / 158); docs issue **#54** (the undocumented `RELOAD`/`KICK`/`LDM`/`IDZ` requests); one wiki correction — the subject tree is since **2.10.10**, not 2.10.9, with the evidence in `raw/nats-server-src/stree-arrival-v2.10.10.md`; unlanded 46 → 0, lint clean.

*Operation: ingest*, the article being the minor line. `wiki/summaries/s-relnotes-2.10.md`
(`source-path: raw/release-notes/` — the 29 files named; `aliases` every tag; `version: "2.10"`):
a per-release table (tag, date, Go, ★ or not, one line of what an operator needs from it — for a
dependency-and-fixes release, say that), then the **change layer by kind**, each item a paraphrase
with tag and PR number: *defaults that changed* · *config keys, flags and options that arrived* ·
*subjects, headers and API fields that arrived* · *behaviours that changed* (the "now" / "no longer"
lines) · *removed and deprecated* · *withdrawn releases, warnings and known regressions* ·
*data-integrity and data-loss fixes* (the material for rows 64 and 130) · *CVEs* (row 155 — the
`v2.10.27-binary` pattern) · *what the existing per-patch summaries already carry* (2.10.16, 2.10.17
via [[s-relnotes-2.11.2]]). Relevance, questions answered, pages touched. **Ripple**: the release
entity `nats-server-2.10` — its *What other sources attribute* becomes a changelog section and its
"not a changelog" note and the *To verify* items it answers go; every concept, reference, gotcha and
operations page whose key, default, subject, flag or behaviour the notes attribute to a 2.10.x
release gets the "since 2.10.x" sentence with the citation, and `since:` where it is missing;
`defaults-and-limits` and `config-keys` for any default or key the notes date; `upgrade-a-cluster`
for the withdrawn and warning releases. Every note that contradicts a docs page → verified against
the server → `inbox/docs-issues.md`. Bank cells (row 154 is a 2.10.21 symptom — read 2.10.22+ for
its fix; row 155 for the binary release). Report unlanded ripples before and after. Log, lint.

## Step 4 — ingest the 2.11 line (v2.11.0 → v2.11.17, 18 releases) · status: done 2026-09-03 — `s-relnotes-2.11` (change layer by kind; the 2.11.9 floor, the withdrawn 2.11.2, the 2.11.0–2.11.5 filtered-consumer regression, twelve CVEs in 2.11.14–2.11.16); the release entity rewritten as a changelog; **39 pages rippled**; docs issues **#55** (leafnode `handshake_first` duration typed boolean), **#56** (`cluster_traffic` undocumented), **#57** (`config_digest`, `tls_cert_not_after`, `leader_since` undocumented), and #22 extended (the `max_buffered_*` description); two release-body typos noted (`ping_internal`, "400 No Messages"); bank unchanged (119 / 158); unlanded 0, lint clean.

As step 3: `s-relnotes-2.11.md`, folding in what [[s-relnotes-2.11.2]] and [[s-relnotes-2.11.5]]
already say by reference. Particular targets: the arrival of API level 1, per-message TTL, priority
groups, `allowed_accounts`, the strict-API *warning*, the consumer-consistency change of 2.11.2 and
its throughput note, the v2.11.9 downgrade floor — every one of which the wiki currently attributes
from an ADR or the 2.12 guide and can now cite from the notes. Ripple to `nats-server-2.11` (its
*To verify* says "the GitHub release body for v2.11.0 has not been ingested" — close it),
`message-ttl`, `priority-groups`, `direct-get`, `auth-callout`, `key-value`, `consumer`,
`ack-and-redelivery`, `consumer-keeps-redelivering`, `js-api`, and the reference tables. Bank,
docs issues, log, lint.

## Step 5 — ingest the 2.12 line (v2.12.0 → v2.12.15, 15 releases) · status: done 2026-09-03 — `s-relnotes-2.12` (change layer by kind, the guide checked line by line: one wrong item → docs issue **#58**, two undocumented keys → **#59** `max_concurrent_io`, **#60** `proxies { trusted }`; #22 and #57 extended); the release entity rewritten; **40 pages rippled**; the three 2.12 hazards (2.12.5 warning, 2.12.7 → 2.12.11 regression, 2.12.15 data-loss fix) on `upgrade-a-cluster`; bank unchanged (119 / 158); unlanded 0, lint clean, 315 pages.

As step 3: `s-relnotes-2.12.md`. Targets: strict JetStream API on by default, atomic batch publish,
counters, schedules, `prioritized`, elastic filestore pointers, offline/unsupported assets,
`GOMEMLIMIT`, the `sources.db`/recovery lines the stream-scale work cited from 2.15, and the 2.12
patches that shipped alongside 2.14.x (2.12.9–2.12.15 mirror the 2.14.1–2.14.5 dates — say which
fixes were backported). Cross-check against [[s-docs-upgrade-to-2.12]] line by line: every place the
guide and the notes disagree is a docs issue. Ripple to `nats-server-2.12`, `publishing`,
`message-scheduling`, `stream`, `filestore-layout`, `jetstream-recovery-is-slow`, `js-api`,
`defaults-and-limits`. Bank, docs issues, log, lint.

## Step 6 — ingest the 2.14 line and the 2.15 preview (7 + 1 releases) · status: done 2026-09-03 — `s-relnotes-2.14` (the seven bodies as one changelog, the three per-patch summaries folded by reference, the guide checked line by line: one unconfirmed claim, the frozen-stream wording as the guide's own, the omissions listed) and `s-relnotes-2.15-preview` (the body read whole; the four new subjects **verified at the preview tag**, and `js_ack_fc_v2` found still `false` there); the keys the bodies introduce verified at v2.14.6 in `raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md`; docs issues **#61** (`dial_timeout` undocumented), **#62** (`feature_flags.md` names no flag; the `js_raft_delete_range` panic warning nowhere), **#63** (`CONSUMER.RESET` absent from the API index); **46 pages rippled**; the TOC regenerated (every 2.14 row linked); bank unchanged (119 / 158); unlanded 0, lint clean, 317 pages.

`s-relnotes-2.14.md` folds the existing [[s-relnotes-2.14.0]], [[s-relnotes-2.14.1]] and
[[s-relnotes-2.14.4]] by reference and reads 2.14.2, 2.14.3, 2.14.5 and 2.14.6 for the first time as
a line; `s-relnotes-2.15-preview.md` is the preview body as it stands on 2026-09-03 (`version:
"2.15"`, dated, and said to be a preview). Cross-check against [[s-docs-upgrade-to-2.14]]. Ripple to
`nats-server-2.14`, `nats-server-2.15-preview`, `consumer`, `mirrors-and-sources`, `raft-in-nats`,
`ack-and-redelivery`, and the pages the 2.14.x fixes already touch. Bank, docs issues, log, lint.

## Step 7 — the `since:` sweep · status: done 2026-09-03 — 55 pages listed by script; **47** got `since: [2.10]` (the frontmatter line carries the convention as a comment; the 21 concept and internals pages say it in words at the head of *Version notes*, naming the first 2.10.x body that patches the subject; `subject-transforms` states the real 2.10.0 arrival of stream-level transforms); **8** keep no `since:` with a one-line `## To verify` reason (domains ×3, object store, ordered consumer, client discovery, KV watchers, the message-lag warning — none dated by any source read); residue **0**; lint clean.

The measured half of *done when*. A short script (in the log, or `tools/lint.py` if it earns a
place there) lists every non-summary, non-entity page with `verified-against` and no `since:`. For
each of the 55: read the four summaries for the page's own keys, subjects and flags (`grep -inE`,
not a re-read), write `since:` — the specific minor when a note dates the subject's arrival, `[2.10]`
with a sentence *present at 2.10, the oldest line this wiki covers* when it predates the archive's
floor — and the "since 2.x" sentences the page's sub-features earned but did not get in steps 3–6.
A page whose subject cannot be dated from any source read gets a one-line `## To verify` item saying
so, and keeps no `since:`. Bump `updated:`; re-check `verified-against` / `verified-on` on every
page where a default, key or subject was touched. Report the count (55 → 0, or the residue with
reasons). Log, lint.

## Step 8 — the default diff per minor · status: done 2026-09-03 — `inbox/check-defaults-v2.10.29.md` (13 / 37 / 166), `-v2.11.17.md` (14 / 29 / 173), `-v2.12.15.md` (14 / 27 / 175) beside the v2.14.6 report (15 / 26 / 175); the server column diffed in sequence and recorded in `wiki/log.md` as *the default change layer*: **one documented default moved** (`max_buffered_msgs` 10,000 → 100,000 at 2.12.0, already in the bodies), twelve keys are arrivals (eight at 2.11, three batch limits at 2.12, `info_queue_limit` at 2.14 — the last one missed by step 6 because the body names the queue and not the key, now on the summary and both reference tables); the diff also produced docs issue **#64** (five pages "since 2.12" for keys the 2.11 line parses — verified in `opts.go` at v2.11.17 / v2.10.29, `raw/nats-server-src/backported-keys-v2.11.17.md`); the four release entities carry their diff; lint clean.

`python3 tools/check-defaults.py --tag v2.10.29`, `--tag v2.11.17`, `--tag v2.12.15` (the last patch
of each line; the tarballs cache under `.cache/`), then diff the *server* column of each report
against the next (`v2.10.29 → v2.11.17 → v2.12.15 → v2.14.6`): a key whose resolved value moves
between two tags is a default that changed, to be confirmed in the notes (steps 3–6) or, when the
notes are silent, verified in the source at both tags and recorded on `defaults-and-limits` with both
values and both versions. The three reports stay in `inbox/` unregistered (the v2.14.6 one is the
one the viewer shows); the diffs go into `wiki/log.md` as the *default change layer*, and onto the
release entities. Expect more *unresolved* at older tags — the resolver was written against 2.14.6
source — and report it, not paper over it. Log, lint.

## Step 9 — close: entities, bank, result line · status: done 2026-09-03 — every release entity cites its `s-relnotes-*` summary (grep: 2.10 ×9, 2.11 ×6, 2.12 ×8, 2.14 ×6, 2.15-preview ×3 body links) and no "not a changelog" note remains; bank rows **159–160** added (`own` — the discussions index and comment cache hold no asked form) and answered on arrival, 119 / 158 → **121 / 160**; nothing struck in the backlog; result line written; megaplan phase D closed.

Verify by grep that each of the five release entities cites its `s-relnotes-*` summary and that no
"not a changelog" note remains; fill every `answered by` the phase earned and add the rows the notes
revealed — with a URL where the discussions index (`inbox/gh-discussions-toc.md`, grep *changelog*,
*release notes*, *what changed*, *what's new*) holds the asked form, `own` otherwise; strike nothing
in the backlog (no section is this phase's); the result line at the top of this file; the megaplan's
`status:` / `next:` for phase D; `wiki/log.md`. Report: raw files, TOC counts, summaries, pages that
gained `since:`, docs issues added, default diffs, bank (rows, answered, open), lint.

---

## Not in this plan

- The 2.0–2.9 release bodies (in the cache, out of scope: `CLAUDE.md` names 2.10 as the floor). A
  later phase may want v2.9's notes for "what 2.10 changed from"; the cache keeps them.
- RC and preview bodies as raw files (folded into the GA bodies; see *Scope decisions*).
- The per-language client release notes (phase F reads the client repos).
- Filing the docs issues this phase records (phase J).
- Re-verifying every page against the binary — only the pages whose defaults, keys or subjects the
  notes move get their `verified-against` / `verified-on` re-checked here.
