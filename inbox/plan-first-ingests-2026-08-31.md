# Plan — first ingests (2026-08-31)

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how. One step at
a time, `status:` rewritten in place, `wiki/log.md` appended, lint run, question-bank cells filled.

**Done when:** every ★ row of `inbox/question-bank.md` has an `answered by` page, and every page
that states a default carries `verified-against: nats-server 2.14.6`.

**Already local — no fetching needed for steps 1–4 and 6:**
`raw/nats-docs/` (861 doc pages incl. 621 config keys, 32 `$JS.API` subject pages, 22 JetStream
advisories, 15 monitoring endpoints, a 240-row JetStream error table, both upgrade guides) and
`raw/adr/` (54 ADRs). Regenerate the tables with `python3 tools/build-config-table.py` and
`python3 tools/triage-adrs.py`.

---

## Step 1 — the JetStream and clustering spine · status: open

```
ingest raw/nats-docs/learn/jetstream/delivery-and-acknowledgment.md
ingest raw/nats-docs/learn/jetstream/policies.md
ingest raw/nats-docs/learn/jetstream/retention-policies.md
ingest raw/nats-docs/learn/jetstream/pull-consumers.md
ingest raw/nats-docs/learn/clustering/replication-and-r3.md
ingest raw/nats-docs/learn/clustering/raft-and-leaders.md
ingest raw/nats-docs/learn/clustering/placement.md
ingest raw/nats-docs/learn/clustering/surviving-node-loss.md
```

Creates `[[stream]]`, `[[consumer]]`, `[[ack-and-redelivery]]`, `[[retention-policies]]`,
`[[replicas]]`, `[[stream-placement]]`, `[[raft-in-nats]]`. Answers Q14–Q25, Q33–Q36.
**Done when** those eight pages exist with `area:`, `since:` where applicable, and citations.

## Step 2 — sizing · status: open

```
ingest raw/nats-docs/learn/deployment/sizing-and-resources.md
ingest https://www.synadia.com/blog/nats-jetstream-high-ram-usage
```

Creates `[[jetstream-sizing]]` (`kind: sizing`): inputs → math → worked example → what runs out
first → how to measure it. Answers Q1–Q3, Q10. Numbers the docs do not state stay `(unverified)`
until step 6 — a guessed sizing number is the worst thing this wiki could contain.

## Step 3 — the ADRs · status: raw/adr/ copied 2026-08-31, 0 of 54 summarized

`inbox/adr-toc.md`, 22 rows flagged ★ (server-tagged and shipped). Start with:

```
ingest raw/adr/ADR-8.md      # KV on streams — Q69-Q72
ingest raw/adr/ADR-20.md     # Object Store on streams — Q75
ingest raw/adr/ADR-17.md     # Ordered consumer
ingest raw/adr/ADR-42.md     # Pull consumer priority groups
ingest raw/adr/ADR-43.md     # Per-message TTL — Q28, Q71
ingest raw/adr/ADR-7.md      # Server error codes -> reference/error-codes
ingest raw/adr/ADR-1.md      # JetStream JSON API -> reference/js-api-subjects
```

Summaries are `s-adr-<n>-<slug>.md`; put the link in the TOC's `summary` column.

## Step 4 — the change layer · status: open

```
ingest raw/nats-docs/release-notes/upgrade-to-2.12.md
ingest raw/nats-docs/release-notes/upgrade-to-2.14.md
ingest https://github.com/nats-io/nats-server/releases/tag/v2.14.0
```

Entity pages `kind: release` for **2.10, 2.11, 2.12, 2.14** (there is no 2.13) and
2.15-preview; set `since:` on the pages whose behaviour arrived in one of them. Answers Q63–Q64.
The docs are versioned (`/reference/`, `/reference/2.12/`, `/reference/2.11/`) — `raw/nats-docs/`
holds the 2.14 tree, so a "what changed" question is a diff against the older tree, not a guess.

## Step 5 — the gotcha layer · status: open

Do **not** crawl. Take the symptom-shaped ★ rows of the question bank (Q7, Q13, Q20, Q26, Q33,
Q36, Q38, Q42, Q55, Q69, Q72, Q77), open the linked thread, write one gotcha page per symptom.

```
ingest https://www.synadia.com/blog/jetstream-design-patterns-for-scale
ingest https://github.com/nats-io/nats-server/discussions/7982   # replicas 1->3, no suitable peers
ingest https://github.com/nats-io/nats-server/discussions/7831   # standalone -> cluster, streams orphaned
ingest https://github.com/nats-io/nats-server/discussions/6605   # which consumer is slow
```

Use `tools/extract-forum-posts.py` so the whole thread lands in `raw/` and the answer is citable
by line. A gotcha page with no confirmed fix is still worth writing — say what is unknown.

## Step 6 — the reference pages · status: config table generated 2026-08-31, pages not written

The mechanical half is done: `inbox/config-keys-table.md` holds all **621 keys** with type,
default (179 stated), reload behaviour (411 reloadable) and the doc page each came from.
Now write the curated pages from it, each citing the table's source pages and carrying
`verified-against`:

- `wiki/reference/config-keys.md` — the keys that matter for running a server, by block
  (jetstream, cluster, leafnodes, gateway, tls, authorization, websocket, mqtt, limits), with the
  621-row table linked for the rest. Fill the `cited by` column of the table as pages land — it
  survives regeneration and shows coverage.
- `wiki/reference/defaults-and-limits.md` — start from the 179 documented defaults, then add the
  values only the source states, read from `nats-io/nats-server` at tag **v2.14.6** with **file
  path and line** next to each. Anything neither source states does not go on the page.
- `wiki/reference/js-api-subjects.md` — from `raw/nats-docs/reference/jetstream/api/` (32 pages).
- `wiki/reference/error-codes.md` — from `raw/nats-docs/reference/jetstream/errors.md`
  (240 rows) plus ADR-7.
- `wiki/reference/monitoring-endpoints.md` — from `raw/nats-docs/reference/system/monitor/`
  (15 endpoints incl. `varz`, `jsz`, `healthz`, `raftz`). Answers Q57, Q60, Q61.
- `wiki/reference/advisories.md` — from `raw/nats-docs/reference/jetstream/advisory/` (22) and
  `system/advisory/` (3). Answers Q59, Q82.

## Step 7 — entities · status: open

- **Clients — all official ones**, from `raw/nats-docs/concepts/ecosystem.md`: tier 1
  `nats.go`, `nats.js`, `nats.py`, `nats.java`, `nats.rs`, `nats.net`, `nats.c`; tier 2
  `nats.zig`, `nats.swift`, `nats-pure.rb`, `nats.rb` (legacy), `nats.ex`. One short page each:
  language, repo, tier, what an *operator* needs to know (does it lag on server features, does it
  do ordered consumers, does it reconnect sanely) — and a link to its own docs. No API reference.
  The Orbit extension repos (`synadia-io/orbit.*`) get one page together.
- **Tools**: `natscli` (`nats`), `nsc`, `nk`, `nats-top`, `nats-box`, the Prometheus exporter,
  the Helm charts (`nats-io/k8s`) — each with a `## Cheat sheet` section; the viewer collects
  those plus the `### <tool>` sections of the operations pages.
- **Repos**: `nats-server`, `nats-architecture-and-design`, `jsm.go` (the JetStream JSON schemas
  used by the docs generator), `nats-streaming-server` with `deprecated: true`.
- **Orgs and products**: `synadia`, `cncf`, and a thin "where they sit" page per commercial
  product — what it adds over open-source NATS, nothing more.

---

## Method notes

- The question bank was mined on 2026-08-31 from 484 `nats-io/nats-server` GitHub Discussions
  (GraphQL, ordered by last update) and 257 Stack Overflow questions across the `nats-jetstream`,
  `nats.io` and `nats-server` tags. Repeat that mining when the bank goes stale; a row without a
  link to someone actually asking it does not belong in the table.
- Everything ingested must be public — `CLAUDE.md` → *Sources must be public*.
- **This wiki may become an official NATS thing.** Two consequences while working: (1) write
  every page so it could be read by the NATS maintainers tomorrow — no internal shorthand, no
  unattributed claims, no snark about the docs; (2) keep the mechanical parts mechanical
  (`fetch-docs.py`, `build-config-table.py`, `triage-adrs.py` regenerate from source), because a
  wiki someone else maintains has to be rebuildable, not hand-woven.
