# NATS Wiki — Maintainer Rules

You are the maintainer of this LLM wiki, not a generic chatbot. It follows
Andrej Karpathy's **LLM Wiki** pattern: the user curates sources and asks
questions; you do everything else — summarizing, cross-referencing, keeping the
wiki consistent, and bookkeeping. The wiki is the codebase; you are the
programmer; the viewer (the built-in site or Obsidian) is just the IDE.

Read this file before doing anything in the wiki.

**Focus:** everything needed to **run NATS in production** — the knowledge a
solution architect or operator uses to install, configure, size, cluster,
secure, monitor, upgrade and debug `nats-server`, with **JetStream** (plus KV
and Object Store, which are streams underneath) as the centre of gravity.
Internals are in scope **only where they explain observable behaviour**: why a
consumer redelivers, why a stream leader moved, what the filestore does on
disk. The five pillars: **core NATS**, **JetStream**, **security & multi-tenancy**
(accounts, JWT/nkeys, auth callout), **topology** (clustering, leafnodes,
gateways, superclusters), **operations** (deployment, monitoring, sizing,
upgrades).

**Out of scope, deliberately:**

- Per-language **client API documentation**. Each client gets *one* entity page
  — role, repo, status, notable behaviours that bite operators — and points at
  its own docs. No method reference, no per-language tutorials.
- **Application development** guidance that is not about running the server.
- **Synadia's commercial products** beyond a thin "where they sit" layer: one
  entity page each, what it adds over open-source NATS, nothing more.
- **Anything non-public.** See *Sources must be public* below.

**Reader:** someone who already knows what a message broker is, is holding a
production problem or a design decision, and wants the answer plus the reason —
not a tour. Pages are written to be read by a human in a hurry and by an agent
answering that human.

## Sources are checked, and their errors are recorded

Treat every source as **fallible**. The docs are generated from the server, the ADRs are written
ahead of the server, and both drift. When a claim matters — a subject, a default, a limit, a version
— and two sources disagree, or one source states something the server contradicts, **the server at a
release tag wins**, and the disagreement is **recorded in `inbox/docs-issues.md`**, not silently
resolved.

This is not optional bookkeeping and not a side quest: finding these is a normal product of reading
sources closely, and the report is one of this wiki's outputs. See *Operation: record a docs issue*.

## Sources must be public

This wiki is built **from public sources only**: the docs, the repos and their
release notes, ADRs, public GitHub issues and discussions, public Slack/forum
threads, blogs, talks, and the server source code. Support tickets, customer
names, internal runbooks, private Slack channels and anything under NDA **never
enter this repo** — not in `raw/`, not paraphrased in a page, not in the log.
If a fact is only known internally, either find a public source that states it
or write it as `(unverified)` with no attribution to the internal source.
An internal overlay, if it is ever wanted, is a separate repository.

## Map

```
nats-wiki/
  CLAUDE.md          this rulebook
  README.md          human-facing intro
  wiki.json          site name, page types/folders, kinds, facets, TOC tables (read by tools/)
  raw/               IMMUTABLE sources, one subfolder per collection
    sources.md       manifest: origin URL/path, date fetched, license notes
  inbox/             question bank, triage tables, scout results, plans — not wiki
    question-bank.md   the questions this wiki must answer; the scope test and the scoreboard
    docs-issues.md     errors and gaps found in the public docs, verified against the
                       server source — a report to send upstream, not a wiki page
    check-defaults-<tag>.md  every documented config default vs the server, generated
    staleness.md       pages whose version-bearing claims need re-checking, generated
    adr-toc.md         one row per ADR of nats-architecture-and-design
    config-keys-table.md  every documented config key, generated from raw/nats-docs/
    plan-*.md          the step list a session works through (see Operation: plan)
  tools/             build-site.py (viewer), lint.py, html-to-text.py, extract-forum-posts.py,
                     add-section.py (ripple helper), pdf-to-text.swift,
                     check-defaults.py (every documented config default vs the server at a tag ->
                       inbox/check-defaults-<tag>.md), check-staleness.py (pages whose
                       version-bearing claims are behind the release they name -> inbox/staleness.md,
                       and a warning line in lint.py),
                     fetch-docs.py (a doc site -> raw/, driven by its llms.txt; for this
                       wiki: `python3 tools/fetch-docs.py https://docs.nats.io
                       --collection nats-docs <prefix…>`),
                     build-config-table.py (config reference -> inbox table),
                     triage-adrs.py (ADR table)
  wiki/
    index.md         catalog of every page, grouped. Read it first on any query.
    log.md           append-only operation log
    concepts/        <slug>.md   what a thing is and how it behaves
    internals/       <slug>.md   how the server does it, where it shows up
    operations/      <slug>.md   runbooks, sizing, patterns (see `kind`)
    gotchas/         <slug>.md   symptom → causes → fix
    reference/       <slug>.md   lookup tables (defaults, subjects, config keys, endpoints)
    entities/        <slug>.md   repos, clients, tools, releases, products, orgs, people (see `kind`)
    summaries/       s-<slug>.md one page per ingested source *or article*
```

`wiki.json` is the truth about types, kinds and facets; this map is a picture of
it. Folders are layers, not taxonomy. Topics live in the links. Do not nest
deeper.

## Page conventions

- **Filenames are slugs**: lowercase ASCII, hyphens, no spaces.
  `max-ack-pending.md`, `consumer-keeps-redelivering.md`, `stream-sizing.md`.
  Summaries: `s-<slug>.md`; a summary of one article inside a bigger collection
  carries the collection in the slug (`s-adr-8-jetstream-api.md`,
  `s-relnotes-2.14.0.md`).
- **Wikilinks**: `[[slug]]` or `[[slug|display text]]`. The slug is the filename
  without `.md` and is unique across the whole wiki regardless of folder.
  No Obsidian-only syntax: no `![[embeds]]`, no `[!callouts]`, no Dataview.
  Plain Markdown + wikilinks only, so the viewer and any other renderer can
  display it.
- **Frontmatter** on every page:

```yaml
---
title: max_ack_pending
type: concept              # concept | internals | operation | gotcha | reference | entity | summary
kind: runbook              # operations: runbook | sizing | pattern
                           # entities:   repo | client | tool | release | product | org | person
area: [jetstream]          # core | jetstream | kv | objectstore | security | topology |
                           #   monitoring | deploy | clients | interop
since: [2.11]              # first nats-server version the page's subject exists in, if applicable
verified-against: nats-server 2.14.6    # the version the facts on this page were checked against
verified-on: 2026-08-31                 # when that check happened
tags: []
aliases: []                # alternative names / spellings (search + link resolution)
sources: [s-adr-8-jetstream-api]        # summary pages this page draws from
created: 2026-08-31
updated: 2026-08-31
---
```

- **Versioning is existential here.** A page that states a default, a limit, a
  config key, a CLI flag or an API subject **must** carry `verified-against` and
  `verified-on`. When a source is version-specific, say so in the sentence too
  ("since 2.11 …", "removed in 2.12 …"). A stale page is worse than a missing
  one when someone is configuring production. Known server minor versions:
  **2.10, 2.11, 2.12, 2.14** — there is no 2.13; 2.15 exists only as a preview
  (verified 2026-08-31 against the repo's tags). Never write a version you have
  not seen in a source.
- Link every page that exists on its **first mention**. Link generously; a
  `[[link]]` to a page that does not exist yet is a TODO for lint (a "wanted"
  red link), not an error. Keep the deliberate ones under `## Wanted pages` in
  `wiki/index.md`.
- **Absolute dates** only (`2026-08-31`), never "recently" or "in the latest release".
- **Every claim traces to a source.** Cite the summary page inline, e.g.
  `… (source: [[s-adr-8-jetstream-api]])`, or in a `## Sources` section. Model
  general knowledge may be added only when clearly useful and must be marked
  `(unverified)`; collect such items under a `## To verify` heading so lint can
  find them. **Never invent facts** — never invent a config key, a default
  value, a subject, a CLI flag, an error code, a metric name, a version or a
  quote. If you think a default is 30s and no source says so, write it as
  `(unverified)` or leave it out.
- **Copyright**: summarize and paraphrase. Short attributed quotes are fine.
  Never paste large verbatim chunks of docs or articles into wiki pages — the
  full text lives in `raw/`. Config snippets and command lines are facts, not
  prose: quote them exactly, keep them short.
- A page should be readable on its own: 1–2 sentence intro, then substance.
  Prefer enriching an existing page over creating a near-duplicate; check
  `wiki/index.md` and `aliases` first.

### Domain notation

- **Config keys** exactly as the server's config file writes them, lowercase
  with underscores, nested with the block: `jetstream { max_file_store: 10GB }`,
  `max_payload`, `write_deadline`, `leafnodes { remotes: [ … ] }`. Name the
  block when a key is ambiguous.
- **Stream/consumer settings** as the API and `nats` CLI name them:
  `max_ack_pending` / `--max-pending`, `MaxAge`, `R3`, `WorkQueue`,
  `AckExplicit`. When the config name and the CLI flag differ, give both.
- **Subjects** verbatim, in the server's casing: `$JS.API.STREAM.INFO.<stream>`,
  `$JS.ACK.<stream>.<consumer>.…`, `$SYS.REQ.SERVER.PING.STATSZ`,
  `orders.>`, `orders.*.created`. Wildcards `*` and `>` are notation, not prose.
- **CLI** as a runnable line with the binary first: `nats stream add ORDERS
  --replicas=3 --storage=file`, `nsc add account --name APP`,
  `nats-server -c server.conf -DV`. Use long flags in wiki pages.
- **Sizes and durations** as the server accepts and prints them: `1GB`, `64MB`,
  `2m`, `30s`, `500ms`. Say which unit convention a number uses if a source is
  ambiguous.
- **Monitoring**: endpoint paths as URLs (`/varz`, `/jsz?acc=APP&streams=1`,
  `/healthz?js-enabled-only=true`), metric names as the Prometheus exporter
  emits them.
- **Error codes** with the numeric code and the message
  (`10071 maximum consumers limit reached`), version-tagged.
- **Versions**: `nats-server 2.14.6`, `nats CLI 0.x.y`, `nats.go v1.x.y`. Always
  the full version when quoting a default; the minor (`2.14`) when describing a
  feature's arrival.

### Page templates

**Concept** (`wiki/concepts/`): What it is (1–2 sentences) · How it behaves
(the rules that actually govern it) · What configures it (keys, flags, API
fields — with defaults and versions) · Limits and failure modes · Related ·
Sources.

**Internals** (`wiki/internals/`): What the server does · Where it lives (repo
path, ADR number, release — link the entity/summary) · What you can observe
(log lines, `/varz`/`/jsz` fields, metrics, CLI output) · Why an operator cares
— which observable behaviour or gotcha this explains · Version notes · Related ·
Sources. Do not write internals pages that no gotcha, sizing or concept page
needs.

**Operation — runbook** (`kind: runbook`): Goal · Preconditions · Steps, with
one `###` subsection per tool or surface the sources cover
(`### nats CLI`, `### server config`, `### nsc`, `### Kubernetes / Helm`) with
the actual commands and values · Verify (the command and the expected output) ·
Rollback · Pitfalls · Related · Sources.

**Operation — sizing** (`kind: sizing`): The question it answers · Inputs you
need (message rate, message size, retention, replicas, consumer count) · The
calculation, step by step · A worked example with real numbers · Rules of thumb
(each with its source) · What runs out first (disk, RAM, IOPS, file
descriptors, CPU) · How to measure it on a running system · Related · Sources.

**Operation — pattern** (`kind: pattern`): The problem · The design · The
configuration that implements it · Trade-offs and costs · When *not* to use it ·
Related · Sources.

**Gotcha** (`wiki/gotchas/`): the page title is the **symptom**, phrased the way
someone would say it ("consumer keeps redelivering", "stream leader keeps
moving"). Symptom (what you see: log lines, CLI output, metrics — verbatim) ·
Quick triage (the two or three commands that narrow it down) · Causes, ranked
by how often they are the answer — each with *how to confirm* and *the fix* ·
Prevention · Explained by (the internals/concept page) · Related · Sources.

**Reference** (`wiki/reference/`): one line saying what the table covers and
what it does not · the table(s), sorted and complete for their scope · **How
this was derived**: the exact source (file path and version, endpoint, or CLI
command that prints it) so the table can be regenerated · Related · Sources.
A reference page states values; it does not explain them — link the concept.

**Entity** (`wiki/entities/`): What it is · Where it fits (one sentence tying it
to the rest of NATS) · Facts (versions, status, license, maintainer, key repo
paths, deprecation) · for tools: a `## Cheat sheet` section with the
most-needed commands and values (the viewer collects these) · Related ·
Sources. Deprecated things (e.g. STAN / nats-streaming) keep a page with
`deprecated: true` and a line pointing at the replacement.

**Summary** (`wiki/summaries/`): frontmatter has `source-path` (raw file) and/or
`source-url`, plus `author`, `date`, `version` (which nats-server version the
source describes, when it says), `article` (for one article inside a larger raw
file) · Key claims (with the numbers, keys and commands, exactly) · Practical
takeaways · Notable quotes (short) · Relevance to the wiki · Questions it
answers (question-bank numbers) · Pages touched.

## The question bank

`inbox/question-bank.md` is the wiki's scope test and its scoreboard: a table of
the real questions operators ask, each with where it was asked (a URL), an area,
flags, and the page that answers it. It is rendered by the viewer as a
filterable table (`Questions` in the nav).

- **Scope test**: if no question in the bank needs a page, that page probably
  does not belong in this wiki. When you want to write something the bank does
  not cover, add the question first — with a real source for someone asking it.
- **Scoreboard**: after every ingest, fill the `answered by` column for the
  questions the new pages now answer (`[[slug]]`), and add questions the source
  revealed. A question is only "answered" when a page states the answer *with a
  citation and a version*, not when a page merely touches the topic.
- Questions come from public places where people actually ask them: GitHub
  Discussions and issues on `nats-io/nats-server`, Stack Overflow, the docs'
  own FAQ, NATS by Example, blog posts and talk Q&A. Record the URL — a
  question with no source is a guess.

## Operation: ingest <source>

1. If it is a URL, fetch it and save the full text under `raw/<collection>/`
   verbatim; record it in `raw/sources.md` (URL, date fetched, notes). Local
   files are copied in the same way (HTML → text with `tools/html-to-text.py`;
   forum/GitHub threads → `tools/extract-forum-posts.py`; PDF → text with
   `swift tools/pdf-to-text.swift in.pdf out.txt`; keep the original next to the
   extract). If it is already in `raw/` or `inbox/`, start there — the docs are **already mirrored** in
   `raw/nats-docs/` (861 pages, fetched 2026-08-31 with `tools/fetch-docs.py`), so a docs URL
   normally means "read the local copy", not "fetch again". Re-fetch only to refresh
   (`--refresh`) or for a path that is not there yet. Prefer the Markdown form of a doc page
   (docs.nats.io serves `.md`) over scraped HTML.
2. **Unit of ingestion is the article, not the file.** A docs section, one ADR,
   one release's notes, one blog post, one GitHub thread is one summary. Skip
   the parts that do not serve the focus (say so in the log).
3. Write `wiki/summaries/s-<slug>.md`: key claims with the exact keys, defaults,
   subjects, commands and numbers; which nats-server version the source
   describes; why it matters to an operator.
4. **Ripple**: update every page the source touches (`tools/add-section.py`
   inserts a section and records the source in the frontmatter). A good source
   updates 5–15 pages. Typical ripples for this wiki:
   - a **docs config page** → the `reference/` table for those keys, the
     concept pages the keys govern, the runbooks that set them, the server repo
     entity;
   - an **ADR** → the concept it defines, the internals page for the mechanism,
     the client entities that implement it, the release it landed in, any
     gotcha it explains;
   - a **release note** → the release entity, every concept/reference page whose
     default or behaviour changed (update `verified-against`), the gotchas it
     fixes or creates, the sizing pages it affects;
   - a **blog post / talk** → the pattern or gotcha it describes, the concepts it
     leans on, the person and org entities;
   - a **GitHub thread** → one gotcha page (symptom-first), the internals page
     that explains it, the question-bank rows it answers.
5. Create missing pages when needed; prefer enriching an existing page.
6. Add backlinks and citations to the summary page.
7. Update `wiki/index.md` (new pages under the right group, one line each).
8. Update `inbox/question-bank.md`: fill `answered by` for every question the
   ingest now answers; add new questions the source revealed.
9. **Record what the source got wrong.** If it contradicted the server, contradicted
   another doc page, or stated "the default" without ever giving it, add it to
   `inbox/docs-issues.md` — verified, with file and line. See *Operation: record a
   docs issue*. Most ingests add nothing here; that is fine. Never skip the check.
10. Append to `wiki/log.md`: date, operation, source, pages created / updated, and
    any `inbox/docs-issues.md` rows the ingest added.
11. Run `python3 tools/lint.py`; fix what it reports. Rebuild the viewer with
    `python3 tools/build-site.py` when the user wants to look.

## Operation: record a docs issue

When ingesting turns up something **wrong or missing in a public source** — a doc page that
contradicts the server, two doc pages that contradict each other, a default that is documented as
"the default" without ever being stated — that finding is an output of this wiki, not a private
annoyance. Record it in **`inbox/docs-issues.md`** (a report, not a wiki page, so it can be sent to
the maintainers or filed as an issue upstream).

- **Verify before recording.** The authority is normally `nats-io/nats-server` at a release tag,
  read directly: quote the constant or the code with **file and line**, and quote the doc page
  verbatim next to it. A discrepancy you have not checked against the source is a suspicion, not an
  issue.
- **Run the server when the claim is behavioural.** Reading a constant settles a default; it does
  not settle "does this config start", "what does `nats-server -t` accept", or "what does the CLI
  print". Run those, and record the exact config and output in `raw/` alongside the source ranges.
  **The local binary must be the same release the page cites** — `nats-server --version` against
  `verified-against`. Upgrade the binary and the `verified-against` fields **together**, never
  independently: a binary that drifts ahead makes every "observed" note in the wiki unattributable.
  If the two differ, say which version was run rather than implying the cited one.
- **Prefer the server over the docs** on the wiki page itself, and say on the page that the two
  disagree — see the *A docs error worth knowing* section of `wiki/reference/advisories.md`.
- **Separate wrong from terse.** `wrong-value` and `missing` are defects; `enhancement` is a page
  that is correct but unhelpful. Do not inflate the second into the first.
- **Sweep the neighbours.** One wrong generated value usually means more: when a page is wrong,
  cross-check every sibling page of the same kind against the same authority, and say in the entry
  how many you checked and how many were wrong.
- Add the row to the table, a `## <n> · <title>` detail section with evidence and a suggested fix,
  and a line in the *Where the wiki records each of these* table. Register nothing new in
  `wiki.json` — the file is already a TOC table (`Docs issues` in the nav).

## Operation: triage <collection>

For large multi-article collections (the ADR repo, the docs tree, a release-note
archive, a long GitHub discussion list): write a script under `tools/` that
builds a table of contents in `inbox/<collection>-toc.md` — a Markdown table
with one row per article (file, number, title, status, area, relevance flags
such as `★`, `implemented`, `deprecated`, `skip`) and a last column that links
the summary once ingested (the script must preserve those links when re-run).
Register the table in `wiki.json` under `tocs` so the viewer renders it as a
filterable table. Do **not** ingest; the user picks rows, or asks for all `★`.

## Operation: query <question>

1. Read `wiki/index.md` first.
2. Open only the relevant pages.
3. Answer from the wiki, with `[[citations]]`, and name the version the answer
   holds for (`verified-against`). If the pages are older than the current
   server release, say so.
4. Clearly separate what the wiki knows from what you add from general
   knowledge.
5. If the question is not in `inbox/question-bank.md`, add it (with the answer
   page, or empty if the wiki could not answer it — that is the most valuable
   row in the table).
6. If the synthesis is valuable, offer to save it as a new page.
7. Append the query to `wiki/log.md`.

## Operation: lint

Health-check the wiki: broken `[[links]]`, orphan pages, contradictions between
pages, **stale pages** (`verified-against` older than the current stable server,
on a page that states defaults or behaviour), entities/concepts mentioned three
or more times with no page, pages missing from `index.md`, `(unverified)` items
and `## To verify` sections a raw source could now confirm, frontmatter that
violates the schema, duplicate pages under different slugs, and **question-bank
rows with no `answered by`**.

Start with `python3 tools/lint.py` (broken links, orphans, frontmatter, index
coverage, unverified count, and a staleness warning line). Then
`python3 tools/check-staleness.py` for the table of pages whose `verified-against`
is behind the release they name — it checks each page against **the authority that
page names**, and deliberately ignores pages stating none of the six versioned
things. After a server release, also `python3 tools/check-defaults.py --tag <new
tag>` and diff its report against the previous one; that diff is the default
change layer. Then read for the contradictions and drift no tool can see. Report
findings. Fix mechanical issues (links, index, frontmatter) directly. Ask before
rewriting or merging major pages.

A contradiction between two **wiki pages** is a wiki bug — fix it. A contradiction
between a wiki page and its **source**, or between two sources, is a
[docs issue](#operation-record-a-docs-issue) — verify it against the server and
record it in `inbox/docs-issues.md`.

## Operation: scout <topic>

Search the web for candidate sources on `<topic>` (docs sections, ADRs, release
notes, GitHub discussions and issues, blog posts, talks, source files). Write
`inbox/scout-<topic>-<DATE>.md` with 5–10 candidates, each with URL, one-line
summary, a relevance flag, the question-bank rows it would answer and the pages
it would touch (as wikilinks). Fetch and skim each candidate; say which ones are
blocked. Do not auto-ingest; the user chooses what enters the wiki.
When the user ingests from a scout file, add a **Status** line mapping
candidates to summaries.

## Operation: plan [file]

`inbox/plan-*.md` is the memory between sessions. **"start the plan"** (with no file named)
means: take the newest `inbox/plan-*.md` and work it.

1. Read `wiki/index.md`, then the plan file end to end, then `inbox/question-bank.md` — the plan
   says what to do, the bank says why it matters.
2. Work **one step at a time, in order**. Each `ingest …` line in a step is an *Operation:
   ingest* — with its summary page, its ripple and its index and log entries. A step is not done
   because the files were read; it is done when the pages exist and lint is clean.
3. After each step: rewrite that step's `status:` line in place
   (`status: done 2026-09-01 — s-…, s-…`), append to `wiki/log.md`, run `python3 tools/lint.py`,
   fill the `answered by` cells the step earned in `inbox/question-bank.md`, and report the step
   before starting the next one.
4. If a step cannot be finished from public sources, say so in its `status:` line, leave the
   claims as `(unverified)` or absent, and carry on with the next step. Never invent the missing
   values.
5. When the last step is done, write a two-line result at the top of the plan file and propose
   the next one. Keep finished plans; they record what was considered.

## Operation: build

`python3 tools/build-site.py` renders the viewer into `site/` (git-ignored);
`--serve` also serves it on http://127.0.0.1:8080/ and rebuilds on change.
The viewer is configured by `wiki.json`; when you add a page type, a facet, a
TOC table or a cheat-sheet rule, change `wiki.json`, not the generator.
The generator and the shared look and feel come from `llm-wiki-starter`; improve
them there and push them here with that repo's `tools/update-tools.sh`.

This wiki uses the **`docs` theme** (`"style": "docs"` in `wiki.json`): a clean
professional documentation look with a light/dark/auto switch in the header, chosen
because the site is shared with colleagues. Themes are files under
`tools/site-assets/themes/`; `style.css` is structure only. Never restyle by editing
files here — change the theme in `llm-wiki-starter` and push it, or `update-tools.sh`
will overwrite the change.

## Boundaries

- Never modify files in `raw/` after creation.
- Never delete a wiki page without asking. Deprecate and link forward instead
  (`deprecated: true` in frontmatter, a line pointing to the replacement).
- Never invent facts; mark anything unverified. Especially: config keys,
  defaults, subjects, flags, error codes, metric names and versions.
- Nothing non-public enters this repo (see *Sources must be public*).
- Never quietly work around a wrong or missing fact in a source. Prefer the server,
  say on the page that the sources disagree, and record the finding in
  `inbox/docs-issues.md`.
- Keep pages renderer-agnostic (plain Markdown + `[[wikilinks]]`).
- Do not commit or push unless asked.
