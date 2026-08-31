# Plan — consolidation: land the ripples that stopped at the summary layer (proposed 2026-08-31)

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how, and
*Operation: consolidate* — new today — says how to work one page. One step at a time, `status:`
rewritten in place, `wiki/log.md` appended with before/after counts, lint run, question-bank cells
filled, and each step reported before the next begins.

**Why this plan, and why before anything else.** The linter grew two checks
(`llm-wiki-starter` commits `7a50866`, `c5d3508`, already pulled into `tools/lint.py`), and both
found real work here the moment they were run. They exist because this wiki, like its sibling,
**records the same fact twice** — so the two halves can be diffed:

- **citation drift** — frontmatter `sources:` versus the `## Sources` section. **22 pages, 25 rows.**
  A defect. Fixed today; see Step 1.
- **unlanded ripples** — a summary's `## Pages touched` naming a page that never cites it.
  **252 claims across 63 pages.** Not a defect: a review queue. This plan is that queue.

**What the measurement says about this wiki specifically.** The sibling wiki's diagnosis was a 6:1
ratio of summaries to reader pages — ingesting far faster than synthesising. That is **not** the
problem here:

| layer | pages |
|---|---:|
| `summaries/` | 116 |
| reader layer — `concepts` 23 · `internals` 4 · `operations` 15 · `gotchas` 15 · `reference` 6 | 63 |
| `entities/` (thin by design) | 34 |

**1.84 summaries per reader page**, and the thinnest reader page is 652 words
(`concepts/ordered-consumer`) — no stubs. So driver 2 of *Operation: consolidate* (thin pages on
well-sourced topics) barely applies, and driver 3 (missing pages) is governed by the question bank,
which is at 67/104. **The whole of the work is driver 1: the unlanded list.**

**And that list is genuinely mixed** — four pairs sampled 2026-08-31 before writing this plan:

| pair | verdict |
|---|---|
| `ack-and-redelivery` ← `s-docs-worker-pool` | material **landed** (nak/worker-pool behaviour is on the page), citation never recorded |
| `error-codes` ← `s-issue-4281-insufficient-storage` | both codes (`10028`, `10047`) already in the table — citation only |
| `account` ← `s-gh-7854-jwt-push-timeout` | **genuine gap**: `$SYS.REQ.CLAIMS.UPDATE` and the push timeout appear nowhere on the page |
| `nats-cli` ← `s-gh-6605-which-consumer-is-slow` | inconclusive from grep; needs the page-by-page read |

So the count cannot be worked down mechanically, and any pass that claims otherwise is faking it.
Half of each sitting is deciding **material or merely relevant**, per pair.

**Done when:** citation drift stays at 0; the unlanded count is down to the rows that are honestly
"merely relevant" and carry a pointer sentence; every strike from a `## Pages touched` list is named
in `wiki/log.md` with its reason; and no page in the top ten below still has material sitting unread
in a summary that names it.

---

## Step 1 — the mechanical half: the two checks, the config, and the rulebook · status: done 2026-08-31 — drift 22 → 0, wiki.json keys, CLAUDE.md gains *Operation: consolidate*

Not an ingest. Bookkeeping, so the rest of the plan has something to run against.

- `tools/lint.py` was already identical to `llm-wiki-starter/template/tools/lint.py` (pushed by
  `update-tools.sh` at 08:59) — the checks were live but nothing in this repo told the maintainer
  what to do with their output.
- **`wiki.json`**: the four lint keys made explicit (`source_type`, `touched_heading`, `sources_key`,
  `sources_heading`). They already resolved correctly by default; stating them documents the
  contract and stops a later folder rename from silently switching a check off.
- **Citation drift, 25 rows across 22 pages, reconciled to the union.** Each row checked first:
  17 rows were already cited inline in the body, 8 were `## Sources`-only (which `CLAUDE.md`
  permits) with the frontmatter half missing. The two least obvious — `config-keys` ←
  `s-docs-replication-and-r3` and `cross-account-sharing` ← `s-docs-mirrors-and-sources` — were read
  and confirmed material before being added. No `updated:` bump needed: all 32 touched pages already
  read `2026-08-31`.
- **`CLAUDE.md`**: *Operation: lint* now names both checks and says which is a defect and which is a
  queue; **`## Operation: consolidate`** is new, adapted from the starter's template to this wiki's
  folders, its version discipline and its docs-issue rule. Its six "shapes to look for" are recast
  for NATS (a runbook missing a `###` surface; a forward reference never landed; `raw/nats-server-src`
  evidence on the internals page but not the gotcha it explains; a page with no earliest version;
  release notes as a source about the *concept*; an entity page without the behaviours that bite).

**Patched upstream the same day.** `lint.py` located both sections with a plain substring split, which
fails twice: an earlier lookalike heading matches first (this wiki's `concepts/message-ttl` has
`## Sources and mirrors`), and the unbounded read to end of file swallows whatever follows — 8 pages
here carry a `## To verify` **after** `## Sources`, whose inline citations were counting as if they
were in the list. `llm-wiki-starter/template/tools/lint.py` now shares one `section()` helper that
anchors the heading to its own line and bounds the section at the next heading of the same or higher
level, tolerating a configured heading with or without its `#` markers — that last part matters,
because the sibling wiki runs on the older default `"Pages touched"` and a strictly anchored match
would have silently reported zero there. `tools/selftest.sh` gained a fixture that fails on the old
code: a decoy summary cited in a `## Sources and notes` section before the list and in a `## To
verify` section after it, so the `citation drift: 0` assertion only holds when both halves are right.
Pulled back here with `update-tools.sh`; this wiki's counts are unchanged, and `--strict` still passes.

**It found a real row on the sibling wiki.** Run against `../chiptune-wiki` (676 pages) the patched
check reports **1 citation drift the old one could not see**: `entities/hermit` lists `s-duet-readme`
in `sources:` and not in `## Sources` — invisible before because the page has a `## Sources released`
heading at line 28, and the split from there to end of file swallowed the inline
`(source: [[s-duet-readme]])` on line 30. Unlanded ripples there are unchanged at 80 across 59.

## Step 2 — `concepts/account`, the single biggest debt (21 claims) · status: open

21 summaries name this page and none of them is cited on it — a third of the security layer's ingest
never reached the page an operator opens first. The sample above found a real gap here, not a
bookkeeping one.

The 21: `s-docs-auth-callout`, `s-docs-authentication-basics`, `s-docs-authorization`,
`s-docs-config-and-jwt-backup`, `s-docs-config-management`, `s-docs-decentralized-auth`,
`s-docs-encryption-and-tls`, `s-docs-forming-a-cluster`, `s-docs-hardening`, `s-docs-leaf-nodes`,
`s-docs-putting-it-together`, `s-docs-security-checklist`, `s-gh-5044-restrict-durable-consumers`,
`s-gh-5606-cross-account-jetstream`, `s-gh-5941-restrict-leafnode-subjects`,
`s-gh-7017-kv-across-accounts`, `s-gh-7505-auth-callout-nkey`, `s-gh-7834-leafnode-same-js-domain`,
`s-gh-7854-jwt-push-timeout`, `s-issue-4281-insufficient-storage`, `s-nats-server-leafnode-js-domains`.

Expect shape 1 (a whole surface missing — the account page likely has the config-file side and not
the `nsc` side) and shape 6 (limits: an account's JetStream tier limits are named by
`s-issue-4281-insufficient-storage` and `s-gh-7017-kv-across-accounts`).

## Step 3 — the JetStream core: `stream` (16), `replicas` (15), `consumer` (6) · status: open

37 claims across the three pages every other JetStream page links to. `stream` is named by five ADR
summaries (`s-adr-1`, `s-adr-8`, `s-adr-10`, `s-adr-20`, `s-adr-43`) — shape 4 (no earliest version)
is the one to watch: these are the summaries that say *when* a field arrived, and `since:` on those
pages should come out of this step, not out of memory.

## Step 4 — the reference tables: `config-keys` (14), `error-codes` (11), `monitoring-endpoints` (9), `js-api-subjects` (6), `defaults-and-limits` (4) · status: done 2026-08-31 — 252 → 206, the whole reference layer clear, 3 strikes logged

44 claims, and the cheapest sitting in the plan: a reference page either lists the key, the code, the
endpoint field or the subject, or it does not — grep decides most rows, as the `error-codes` sample
showed. A reference page states values and does not explain them, so **the pointer sentence is not
available here**: either the value belongs in the table or the summary belongs on the concept page
instead. Re-check `verified-against` on anything touched.

**Result.** 46 claims cleared (the 44 planned plus `reference/advisories`, 2, taken because it
finished the layer): **252 → 206 across 57 pages, and no reference page carries an unlanded ripple.**
Citation drift stayed 0, `--strict` passes, and no `verified-against` needed moving — every touched
page already read `2.14`/`2.14.6` on `2026-08-31`. Question bank **67 → 68**, ★ **36 → 37**.

**The mix, which is the number the rest of the plan should be paced by:** of 46 pairs, **33 were
citation-only** — the material had landed and only the record was missing — and **10 were real
additions**. Three were neither, and were struck. Grep decided the citation-only ones in bulk (every
`10xxx` code in all 11 `error-codes` summaries was already in the table; all 14 `config-keys`
summaries named only keys the generated table already carries). **The additions were where the value
was, and none of them was a table row** — every one was a *behaviour* a table cannot hold:

- `/healthz` — which variant belongs on which Kubernetes probe, and why liveness must ask the least;
  plus the `Healthcheck failed: … is not current` line a lagging KV watcher produces (2.10.12).
- `/routez` — the check is only meaningful cluster-wide and only once every node is up; a partial
  split-brain shows as unequal counts with every node still in the list (2.11.7).
- `/jsz` — `active` is the JSON name for the CLI's `Last Seen`.
- The endpoint→metric rule: metric names follow the wire fields, `num_pending` →
  `nats_consumer_num_pending`.
- `$JS.API.CONSUMER.DURABLE.CREATE` — the *legacy* subject, and why an ACL written against it catches
  nothing; the coarse `$JS.API.>` grant in its three roles; the three export **types** cross-account
  replication needs, where the wrong type fails silently.
- `no_auth_user` cannot be introduced or changed by reload — `config reload not supported for
  NoAuthUser`, old config stays active, and `-t` does not catch it (a **third** entry in that section).
- `leafnodes { authorization { users } }` is a trimmed parser: four fields only, and `permissions`
  there is a **parse error**.
- `max_file_store` is recomputed at every start, so a filled disk brings the server back with a
  smaller ceiling than the streams it already holds.
- Failures that carry **no error code at all** — a cross-account config error stops the server with a
  file and line; `No responders are available` is a core status, not a JetStream error.
- Advisories are unreachable without a system-account user, which is exactly what declaring your own
  `accounts` block silently takes away.

**Three strikes**, each logged in `wiki/log.md` with its reason: `s-docs-authentication-basics`,
`s-docs-your-first-cluster` and `s-gh-7494-supercluster-degradation` no longer name `config-keys`
under `## Pages touched`.

**One scope bug caught and repaired mid-step:** a `$JS.FC.>` row was added to `js-api-subjects`
before noticing the page's own intro excludes the `$JS.FC` space. The row was removed and the intro
now names the single exception (the export-type table), rather than the page quietly contradicting
itself.

## Step 5 — topology and cluster operations: `raft-in-nats` (11), `install-nats-server` (10), `mirrors-and-sources` (9), `build-a-3-node-cluster` (7), `stream-placement` (3) · status: open

40 claims. Two runbooks here, so shape 1 is the one to look for deliberately: `s-docs-kubernetes`,
`s-nats-helm-chart-values-2.14.6` and `s-nats-server-systemd-units` all name runbook pages, which
suggests missing `### Kubernetes / Helm` and `### systemd` surfaces rather than missing prose.

## Step 6 — security, part two: `subject-permissions` (6), `operator-mode` (5), `cross-account-sharing` (5), `tls-in-nats` (4), `nk` (3), `nsc` (1) · status: open

24 claims. Follows Step 2 deliberately: whatever `account` absorbs will change what these four still
owe, and `s-docs-security-checklist` names five of these pages at once — read it once, land it five
times.

## Step 7 — tools and entities: `nats-cli` (11), `nats-helm-charts` (4), the release entities (2.10 / 2.11 / 2.12, 1 each), `nats-server` (2), `nats-py`, `nats-js`, `nats-box`, `orbit`, `synadia`, `synadia-products`, `cncf` · status: open

~26 claims. Shape 6 is the whole of this step: entity pages that say what a thing is without the
behaviours that bite an operator. `nats-cli` at 11 is the outlier and should get its own sitting —
its cheat sheet is collected by the viewer, so a missing command is missing twice.

## Step 8 — the tail: the 26 pages carrying one claim each · status: open

One sitting, but the same per-pair judgement — this is where "merely relevant" will be the honest
answer most often, and therefore where the pointer sentence and the logged strike both get used.
Finish by re-running lint and reporting the final number against the 252 this plan started from.
