# Plan — consolidation: land the ripples that stopped at the summary layer (proposed 2026-08-31)

> **Result (2026-09-01): done. Unlanded ripples 252 → 0; citation drift 0 → 0 held throughout;
> `--strict` passing.** 202 claims landed over steps 2–8 — **183 real additions to 16 citation-only**
> on the behaviour-carrying layers, against 10 to 33 on the reference tables (step 4) — with **zero strikes
> earned in-pass**, two pointer sentences, and one verified docs issue (**#37**) found by
> consolidating rather than ingesting.
> **Next**: `inbox/plan-the-meta-layer-2026-09-01.md` is proposed and unstarted; the question bank is
> the other open front, at **105/83** with ★ complete (42/42), so the 22 unanswered rows now need
> *sources*, not synthesis — which makes the next move an ingest or a scout, not another consolidate.

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

## Step 2 — `concepts/account`, the single biggest debt (21 claims) · status: done 2026-09-01 — 202 → 181, `account` 21 → 0, no strikes

**Result.** All 21 landed: **18 real additions, 3 citation-only, 0 strikes** — the inverse of step 4's
ratio, and the evidence that a concept page absorbs *behaviour* where a reference table only absorbs
values. Both shapes the step predicted were there: shape 1 (a whole surface missing — the leafnode
`account` binding and the `$SYS.REQ.CLAIMS.UPDATE` push mechanics) and shape 6 (limits — the account's
`MaxStore` tier as the second origin of `10047`, R3 counting three times, `max_consumers` as the only
enforceable control). Two pairs were landed as pointer sentences, their material living on
[[auth-callout]] and [[backup-and-restore-identity]]. Bank 105/83 unchanged; rows 48, 90, 95 and 96
gained `[[account]]` as a second answering page. Full account in `wiki/log.md`.

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

## Step 3 — the JetStream core: `stream` (16), `replicas` (15), `consumer` (6) · status: done 2026-09-01 — 181 → 144, all three at 0, 1 docs issue found

**Result.** All 37 landed: **33 real additions, 4 citation-only, 0 strikes.** Shape 3 appeared as
predicted on `replicas` (the `accountReservation` source range now sits beside the docs sentence it
explains) and shape 5 on all three (2.12 and 2.14 release notes read as sources *about the concept*).
**Shape 4 did not resolve**: none of the 37 summaries says which release streams, replicas or
consumers first shipped in, so `since:` stays empty rather than being filled from memory — the plan
predicted this step would settle it and it could not.

**The step's real find is a docs issue.** Putting `consumer` and `priority-groups` side by side
exposed that they disagreed because their sources do — `learn/jetstream/policies.md` says a priority
policy can be changed on a live consumer, ADR-42 says it cannot. The local **v2.14.6** binary settles
it for the docs: all three forbidden transitions are accepted, and two priority groups are accepted
and stored against the ADR's "more than one is an error". Neighbour sweep: **4 rules checked, 2 wrong,
2 hold** (`10162`, `10178`). Recorded as `inbox/docs-issues.md` **#37** (`ADR repo`, `wrong-value`,
medium), evidence in `raw/nats-server-src/priority-groups-observed-v2.14.6.md`. This is the first
time consolidation, rather than ingest, produced a verified row. Full account in `wiki/log.md`.

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

## Step 5 — topology and cluster operations: `raft-in-nats` (11), `install-nats-server` (10), `mirrors-and-sources` (9), `build-a-3-node-cluster` (7), `stream-placement` (3) · status: done 2026-09-01 — 144 → 105, all five at 0, 0 strikes

**Result.** 39 claims (not 40 — `raft-in-nats` was at 11 when the plan was written and at 10 when the
step ran): **34 real additions, 5 citation-only, 0 strikes.** Bank 105/83 unchanged; rows 35, 77 and
92 gained further answering pages.

**The step's prediction was half right.** Shape 1 was the thing to look for, and both runbooks
already *had* their `### Kubernetes` and `### systemd` surfaces — what was missing was the content
inside them (the Helm chart's zero-slack drain arithmetic; the reloader watching only `/etc/`) plus
one genuinely absent surface, **`### TLS` on `install-nats-server`**. The prediction that
`s-nats-server-systemd-units` implied a missing systemd surface was wrong: that pair was
citation-only. Full account in `wiki/log.md`.

40 claims. Two runbooks here, so shape 1 is the one to look for deliberately: `s-docs-kubernetes`,
`s-nats-helm-chart-values-2.14.6` and `s-nats-server-systemd-units` all name runbook pages, which
suggests missing `### Kubernetes / Helm` and `### systemd` surfaces rather than missing prose.

## Step 6 — security, part two: `subject-permissions` (6), `operator-mode` (5), `cross-account-sharing` (5), `tls-in-nats` (4), `nk` (3), `nsc` (1) · status: done 2026-09-01 — 105 → 80, all six at 0 plus `backup-and-restore-identity`

**Result.** 25 claims: **22 real additions, 3 citation-only, 0 strikes.** `tls-in-nats` came into the
step at **3** rather than 4 — the list had already moved under step 2, which is what the ordering was
for; none of the 25 duplicated what `account` absorbed. `operations/backup-and-restore-identity` (2)
was taken here rather than left for step 8, finishing the security layer in one sitting the way step 4
took `reference/advisories`. Shape 6 was the whole of the two entity pages: `nk` and `nsc` said what
the tools are and not what bites. Bank 105/83 unchanged; rows 48 and 49 gained further answering
pages. Full account in `wiki/log.md`.

24 claims. Follows Step 2 deliberately: whatever `account` absorbs will change what these four still
owe, and `s-docs-security-checklist` names five of these pages at once — read it once, land it five
times.

## Step 7 — tools and entities: every remaining `entities/` page · status: done 2026-09-01 — 80 → 50, all 14 at 0, 0 strikes

**Result.** 30 claims: **28 real additions, 2 pointer sentences, 0 citation-only, 0 strikes** — the
inverse of step 4 and the confirmation of what step 6 saw on `nk` and `nsc`: an entity page is almost
never merely missing a citation. **Shape 6 was the whole of the step, on all 14 pages.** `nats-cli`
got its own sitting as the plan asked (9 additions, 2 pointers) and its cheat sheet gained the
`nats auth` backup/restore path, the `--chunk-size`/`--window-size` arithmetic and the permission-edit
rule. The two pointer sentences are the first of the plan: `s-docs-single-server`'s
`replicas > 1 not supported in non-clustered mode` belongs to [[replicas]], and
`s-gh-6605-which-consumer-is-slow` is an unanswered thread whose unknown is owned by
[[slow-consumer-detected]]. One landing was a correction rather than an addition — the ADR repo page
said it had read **7 of 54** ADRs and the real count is **17**. Bank unmoved at 105/83, ★ 42/42; none
of the 22 open rows is about a tool or an entity. Full account in `wiki/log.md`.

The recount the step ran against, from `python3 tools/lint.py` (the plan's original header said
"~26 claims" and listed the pages from the 252-era run):

| page | claims |
|---|---:|
| `entities/nats-cli` | **11** |
| `entities/nats-helm-charts` | 4 |
| `entities/nats-server`, `entities/nats-py`, `entities/synadia` | 2 each |
| `entities/cncf`, `entities/nats-architecture-and-design`, `entities/nats-box`, `entities/nats-js`, `entities/nats-server-2.10`, `entities/nats-server-2.11`, `entities/nats-server-2.12`, `entities/orbit`, `entities/synadia-products` | 1 each |

`entities/nk` and `entities/nsc` were in this step's territory and were **cleared in step 6** with the
rest of the security layer; that is why the entity list is shorter than the count is.

Shape 6 is the whole of this step: entity pages that say what a thing is without the behaviours that
bite an operator. Step 6 ran that shape twice already, on `nk` and `nsc`, and both were pure shape 6 —
expect the same here. `nats-cli` at 11 is the outlier and should get its own sitting: its cheat sheet
is collected by the viewer, so a missing command is missing twice.

## Step 8 — everything left: **50 claims across 26 pages** · status: done 2026-09-01 — 50 → **0**, both sittings, 0 strikes

**Sitting 1 result (the 12 mid-sized pages, 36 claims).** All 36 landed: **35 real additions, 0
pointer sentences, 1 strike that was already recorded and had never taken effect.** The plan predicted
these would be addition-shaped because they are concept- and operation-shaped; they were, and at a
higher rate than any earlier step. Bank 105/83, ★ 42/42 unchanged; **seven rows gained further
answering pages** (32, 38, 39, 52, 62, 69, 77). Full account in `wiki/log.md`.

**The find of the sitting is a false positive in the count itself.**
`s-docs-object-store-your-first-object` struck `operations/jetstream-sizing` at ingest and wrote out
its reason — but the note sits inside `## Pages touched` and named the page as a `[[wikilink]]`, so
`tools/lint.py` kept counting it. The strike stands; the link is now plain text. The rest of the
summary layer was swept for the same shape and **this was the only one**, so the queue has been
carrying exactly one phantom row since the strike was made, not a systemic miscount.

**Two other things worth carrying into sitting 2.** Shape 3 (server-source evidence on one page but
not the gotcha it explains) accounted for most of `jetstream-slows-as-consumers-grow` and all of the
`stalls` material on `slow-consumer-detected` — the pattern to look for is a `raw/nats-server-src/`
observation already summarised and landed *somewhere*. And shape 1 is not only about runbooks:
`backup-and-restore-jetstream` was missing the whole `nats account backup` surface, and
`concepts/key-value` was missing the leafnode/domain one.

**Sitting 2 result (the 14 single-claim rows, 14 claims).** All 14 landed: **13 real additions, 1
citation-only, 0 strikes, 0 pointer sentences** — and the sitting's prediction was **wrong**. This was
supposed to be where "merely relevant" was the honest answer most often and where the first earned
strike appeared. Instead, twelve of the fourteen were a source explaining something the page already
*asserted*: a single-claim row turns out not to be a weak pairing but one nobody has had a second
reason to revisit. The one citation-only pair is named in `wiki/log.md`
(`rotate-tls-certificates` ← `s-docs-security-checklist`, every checklist TLS item already on the page
from other sources), and the citation went on the checklist's one-line compression of the runbook
rather than a manufactured section. Bank 105/83, ★ 42/42; rows 26, 41 and 69 gained further answering
pages. One stale *To verify* item was removed in passing — `streams-not-visible-across-a-leafnode`
still said the docs' leafnode chapter "has not been ingested", which stopped being true several plans
ago.

**The rows, as lint listed them after sitting 1:**

| page | summary |
|---|---|
| `concepts/ack-and-redelivery` | `s-docs-worker-pool` |
| `concepts/auth-callout` | `s-docs-authentication-basics` |
| `concepts/choosing-a-topology` | `s-gh-4823-leafnode-supercluster-duplicates` |
| `concepts/gateway` | `s-gh-6328-jetstream-behind-gateways` |
| `concepts/jetstream-domain` | `s-natscli-stream-external` |
| `concepts/message-ttl` | `s-docs-mirrors-and-sources` |
| `concepts/ordered-consumer` | `s-gh-6746-watch-many-keys` |
| `concepts/priority-groups` | `s-docs-worker-pool` |
| `gotchas/jetstream-out-of-disk` | `s-gh-5924-filestore-dirs-vanished` |
| `gotchas/nats-timeout` | `s-gh-6490-high-message-lag` |
| `gotchas/stream-has-high-message-lag` | `s-gh-5859-unexpected-nats-timeout` |
| `gotchas/streams-not-visible-across-a-leafnode` | `s-docs-leaf-nodes` |
| `operations/rebalance-streams` | `s-gh-4342-memory-stream-backup` |
| `operations/rotate-tls-certificates` | `s-docs-security-checklist` |

*(Written before the sitting: "this is where 'merely relevant' will be the honest answer most often,
and therefore where the pointer sentence and a newly earned strike are most likely." Kept as written —
it did not survive contact, and why it did not is the finding.)*

**The original header — "the 26 pages carrying one claim each" — is wrong now, and was only ever half
right.** 26 pages is the right number, but only **14** of them carry a single claim. The other 12 are
mid-sized and were never assigned to any named step, because steps 2–7 were scoped by *topic* and
these fall between the topics:

| page | claims |
|---|---:|
| `concepts/key-value` | 5 |
| `operations/upgrade-a-cluster`, `operations/jetstream-sizing`, `gotchas/jetstream-slows-as-consumers-grow` | 4 each |
| `operations/disaster-recovery`, `gotchas/slow-consumer-detected`, `concepts/direct-get` | 3 each |
| `operations/reload-server-config`, `operations/backup-and-restore-jetstream`, `internals/js-api`, `concepts/retention-policies`, `concepts/leafnode` | 2 each |
| 14 pages at 1 each | `concepts/ack-and-redelivery`, `concepts/auth-callout`, `concepts/choosing-a-topology`, `concepts/gateway`, `concepts/jetstream-domain`, `concepts/message-ttl`, `concepts/ordered-consumer`, `concepts/priority-groups`, `gotchas/jetstream-out-of-disk`, `gotchas/nats-timeout`, `gotchas/stream-has-high-message-lag`, `gotchas/streams-not-visible-across-a-leafnode`, `operations/rebalance-streams`, `operations/rotate-tls-certificates` |

**So this is two sittings, not one.** The 12 mid-sized pages deserve the same per-pair reading the
concept pages got — `concepts/key-value` at 5 is a real page with real material waiting. The 14
single-claim rows are where "merely relevant" will be the honest answer most often, and therefore
where the pointer sentence and the first logged **strike** are most likely to be earned; four steps
have now run with zero strikes, which is itself worth noticing rather than assuming.

Finish by re-running lint and reporting the final number against the **252** this plan started from
(**202** when the current run of steps began, on 2026-09-01).

---

## Running total (steps worked 2026-09-01)

| step | before → after | note |
|---|---|---|
| — | 252 → 206 | step 4, 2026-08-31 |
| — | 206 → 202 | drift/bookkeeping between sessions |
| 2 · `account` | 202 → 181 | 18 additions, 3 citation-only |
| 3 · JetStream core | 181 → 144 | 33 additions, 4 citation-only; produced docs issue **#37** |
| 5 · topology & cluster ops | 144 → 105 | 34 additions, 5 citation-only |
| 6 · security, part two | 105 → 80 | 22 additions, 3 citation-only |
| 7 · tools and entities | 80 → 50 | 28 additions, 2 pointer sentences |
| 8a · the 12 mid-sized pages | 50 → 14 | 35 additions, 1 phantom strike cleared |
| 8b · the 14 single-claim rows | 14 → **0** | 13 additions, 1 citation-only |

**202 claims landed, no strike earned in-pass (one pre-existing strike was cleared of
a phantom link), citation drift held at 0, `--strict` passing throughout.** Question bank unmoved at **105/83** (★ 42/42): these steps deepened existing pages
rather than answering new questions, which is what driver 1 is supposed to do.

**What the mix says, now that it is settled.** The ratio inverts by **layer**, and that is the finding
to carry into the next plan:

| layer | pairs | real additions | citation-only | other |
|---|---:|---:|---:|---|
| `reference/` (step 4) | 46 | 10 | **33** | 3 struck |
| `concepts` · `operations` · `gotchas` · `internals` · `entities` (steps 2–3, 5–8) | 202 | **183** | 16 | 2 pointer sentences, 1 phantom strike |

**248 pairs**, plus the 4 the drift/bookkeeping pass between sessions accounted for, is the 252 this
plan opened with.

A reference table either holds the value or it does not, so grep decides most of its rows in bulk. A
page that carries *behaviour* almost never merely lacks a citation. **The corollary the last sitting
proved**: a single-claim row is not a weak pairing. Twelve of the fourteen were a source explaining
something the page already asserted — the explanation, not the claim, was what had never landed — and
the sitting produced **13 additions against 1 citation-only**, the opposite of what this plan
predicted for it.

**Across the whole plan: zero strikes earned in-pass**, two pointer sentences, one phantom strike
cleared, and one verified docs issue (**#37**) produced by consolidation rather than ingest. The
`## Pages touched` lists written at ingest time were, in the end, almost entirely honest.
