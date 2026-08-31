---
title: Log
type: log
created: 2026-08-31
updated: 2026-08-31
---

# Log

Append-only. One entry per operation: date, operation, source, pages created / updated.

## 2026-08-31 — setup
- Created from llm-wiki-starter (`new-wiki.sh`). Waiting for the first session to run `KICKOFF.md`.

## 2026-08-31 — kickoff
- Configured for **running NATS in production** (nats-server + JetStream, operator/SA persona).
  Scope, page model and facets recorded in `inbox/kickoff-2026-08-31.md`.
- `wiki.json`: 7 types (concept, internals, operation·runbook/sizing/pattern, gotcha, reference,
  entity·repo/client/tool/release/product/org/person, summary); facets `area` and `since`;
  cheat sheets per tool; TOC tables for the question bank and the ADRs.
- Rewrote `CLAUDE.md` (focus, public-sources-only rule, domain notation, seven page templates,
  version rules, NATS ripple examples), `README.md`, `wiki/index.md` (28 wanted pages).
- Mined `inbox/question-bank.md`: **82 questions**, each linked to the public thread where it was
  asked — 484 `nats-io/nats-server` GitHub Discussions (GraphQL) plus 257 Stack Overflow
  questions across the `nats-jetstream` / `nats.io` / `nats-server` tags.
- Copied the ADR repo into `raw/adr/` (54 ADRs, tarball of `main`, 2026-08-31) and wrote
  `tools/triage-adrs.py`; `inbox/adr-toc.md` has 54 rows, 22 flagged ★ (server-tagged, shipped).
- Wrote `inbox/scout-sources-2026-08-31.md` (the six source layers, all URLs checked) and
  `inbox/plan-first-ingests-2026-08-31.md` (7 steps with literal ingest commands).
- Verified against the GitHub API: latest stable **v2.14.6** (2026-08-27); minors 2.10, 2.11,
  2.12, 2.14 — **no 2.13**; `v2.15.0-preview.1` exists.
- No wiki pages written yet: the first ingest creates them.

## 2026-08-31 — source mirror + mechanical config reference
- `tools/fetch-docs.py`: fetches docs.nats.io into `raw/nats-docs/`, paths taken from the site's
  `llms.txt` (never guessed — `/reference/config/limits/max_payload.md` looks plausible and 404s).
  Fetched **861 pages, 0 failed**: `concepts/` (11), `learn/` (122), `reference/` (715, of which
  621 config keys, 32 `$JS.API` subject pages, 22 JetStream advisories, 15 monitoring endpoints,
  a 240-row error table), `tutorials/` (7), `release-notes/` (2, the 2.12 and 2.14 upgrade guides).
- `tools/build-config-table.py`: merges the per-key pages (H1, reload marker, description,
  `## Types`) with the parent pages' `## Properties` tables (which carry the defaults) into
  `inbox/config-keys-table.md` — **621 keys, 179 with a documented default, 411 hot-reloadable**.
  Empty cells mean the docs state nothing; the `cited by` column is hand-kept across runs.
- Registered as a third TOC table (`Config keys` in the nav): 757 TOC rows total across
  questions, ADRs and config keys; 919 raw files in the viewer.
- `CLAUDE.md`: added **Operation: plan** (`start the plan` works the newest `inbox/plan-*.md`,
  one step at a time, status rewritten in place), taught `ingest` that the docs are already local.
- Rewrote `inbox/plan-first-ingests-2026-08-31.md` around the local mirror; recorded the three
  follow-up answers (config reference mechanically: yes; all official clients get pages; the wiki
  may become official) in `inbox/kickoff-2026-08-31.md`.
- Still no wiki pages: everything above is sources and tooling. Step 1 of the plan writes the first.

## 2026-08-31 — fetch-docs.py generalized and backported
- `tools/fetch-docs.py` moved into the `llm-wiki-starter` template as a generic `llms.txt`
  fetcher (no site hard-coded) and came back here via `tools/update-tools.sh`. New form:
  `python3 tools/fetch-docs.py https://docs.nats.io --collection nats-docs <prefix…>`.
  Verified against the existing mirror: all 861 pages recognised as present, nothing re-fetched.
- Two robustness fixes found by testing the parser on other sites' indexes: links may live on a
  different host than the index (`--allow-host`, with a message naming the hosts it skipped), and
  the description separator may be ` - ` rather than `: `. docs.nats.io: 863 links, unchanged.
- Command lines updated in `CLAUDE.md`, `README.md` and `tools/build-config-table.py`;
  `__pycache__/` added to `.gitignore`.
