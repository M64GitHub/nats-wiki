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

## 2026-08-31 — plan step 1: the JetStream and clustering spine
- **Ingested 11 articles** from the local `raw/nats-docs/` mirror (nothing re-fetched), 9 from the
  plan's step 1 plus two the step needed:
  `learn/jetstream/` — `delivery-and-acknowledgment.md`, `acknowledgment.md`, `policies.md`,
  `retention-policies.md`, `pull-consumers.md`, `surviving-node-loss.md`;
  `learn/clustering/` — `raft-and-leaders.md`, `replication-and-r3.md`, `placement.md`;
  `reference/jetstream/api/` — `stream/create.md`, `consumer/create.md`.
- **Two corrections to the plan's step 1 list.** `surviving-node-loss.md` is under
  `learn/jetstream/`, not `learn/clustering/` (the plan's path 404s locally). And
  `learn/jetstream/acknowledgment.md` — the page that actually carries ack/nak/term, `ack_wait`,
  `max_deliver` and backoff — was not in the list; without it the step could not answer Q14–Q19.
  Added. `reference/jetstream/api/stream/create.md` was added as the authority for stream field
  defaults, which the prose learn pages state only in passing.
- **Summaries created (11):** [[s-docs-delivery-and-acknowledgment]], [[s-docs-acknowledgment]],
  [[s-docs-policies]], [[s-docs-retention-policies]], [[s-docs-pull-consumers]],
  [[s-docs-surviving-node-loss]], [[s-docs-raft-and-leaders]], [[s-docs-replication-and-r3]],
  [[s-docs-placement]], [[s-docs-stream-config]], [[s-docs-consumer-config]].
- **Wiki pages created (7):** concepts [[stream]], [[consumer]], [[ack-and-redelivery]],
  [[retention-policies]], [[replicas]]; internals [[raft-in-nats]], [[stream-placement]].
  All carry `area:`, `verified-against: nats-server 2.14`, `verified-on: 2026-08-31` and per-claim
  citations. No `since:` — every subject on these seven pages predates 2.10, the oldest minor the
  facets know; version notes are inline instead (e.g. `step-down --preferred` is 2.11+).
- **`verified-against` is `nats-server 2.14`, not `2.14.6`** as the plan's "Done when" line asks.
  The facts were checked against the docs.nats.io *latest* tree, which `release-notes/
  upgrade-to-2.14.md` confirms documents 2.14; nothing here was read from the 2.14.6 source or
  binary. Writing `2.14.6` would claim a check that did not happen. Step 6 reads
  `nats-io/nats-server` at tag v2.14.6 and can raise these pages then.
- **`wiki/index.md`**: the seven pages listed under Concepts and Internals, the eleven summaries
  grouped by source area; the five now-written pages removed from *Wanted*, and five deliberate new
  red links added — [[worker-pool]], [[direct-get]], [[mirrors-and-sources]], [[error-codes]],
  [[advisories]].
- **`inbox/question-bank.md`**: filled 8 `answered by` cells — Q14, Q15 ([[ack-and-redelivery]]),
  Q20, Q21 ([[retention-policies]]), Q22 ([[consumer]]), Q33, Q35 ([[stream-placement]]),
  Q36 ([[raft-in-nats]]). No new rows: a docs page is not someone asking a question, and the bank's
  rule is that every row needs a public thread behind it.
- **Deliberately left unanswered** of the questions step 1 aimed at, with the reason recorded in a
  `## To verify` section on the relevant page: Q16 and Q23 (the server's effective
  `duplicate_window` is not stated anywhere in the 2.14 docs — the schema says only "0 for
  default"), Q17 (the docs show `--backoff=linear`; nothing read confirms an *exponential* mode),
  Q18 (the 2.14 docs state the opposite of the question's premise — a plain nak redelivers
  immediately — so the thread needs reading first), Q19 (whether a delayed nak holds a
  `max_ack_pending` slot is unstated), Q24 and Q25 (per-subject/per-key and core NATS ordering are
  not covered by these sources), Q34 (`learn/clustering/scaling-and-peers.md` not ingested).
- `python3 tools/lint.py`: 20 pages, no frontmatter issues, no orphans, no broken links, none
  missing from the index, and no unverified-marker items on any wiki page. Where a source is silent
  the pages say so under `## To verify` and state no value at all, rather than marking a guess.

## 2026-08-31 — plan step 2: sizing
- **Ingested 3 articles.** `raw/nats-docs/learn/deployment/sizing-and-resources.md` (local);
  **`https://www.synadia.com/blog/nats-jetstream-high-ram-usage`** — fetched, saved verbatim as
  both `.html` and a `.txt` extract under a new `raw/synadia-blog/` collection and recorded in
  `raw/sources.md`; and `raw/nats-docs/reference/config/max_payload.md` with its three companion
  keys (`max_pending`, `max_connections`, `max_subscriptions`), added as ripple because the sizing
  page states values for all four.
- **Summaries created (3):** [[s-docs-sizing-and-resources]], [[s-synadia-jetstream-memory-patterns]],
  [[s-docs-connection-limits-config]].
- **Page created:** [[jetstream-sizing]] (`kind: sizing`) — inputs, the five-step calculation, RAM,
  a worked example, rules of thumb each with its source, what runs out first, how to measure it.
- **Ripple (2 pages):** [[stream]] gained a *deduplication window* section — the Synadia post
  supplies the **2-minute** default that the `StreamConfig` schema records only as "0 for default",
  so the `## To verify` item that blocked it is replaced by a narrower one (the post is dated
  2025-08-08 and names no server version). [[replicas]] gained *Replicas cost account quota, not
  just disk* — the un-tiered `replicas × bytes` rule against `MaxStore`.
- **Two facts worth flagging**, both widely mis-stated elsewhere: JetStream's storage defaults are
  **75% of RAM and 75% of available disk**; `256MB` and `1TB` are only the fallbacks used when the
  server cannot read system memory or disk size. And `max_payload`'s hard ceiling is **64MB** with
  **8MB** the recommended ceiling — two different numbers.
- **`inbox/question-bank.md`**: filled Q3 and Q12 (both [[jetstream-sizing]]).
- **Q1 and Q10 deliberately left open**, against the plan's target for this step. Q1 needs IOPS
  guidance and a per-message storage overhead figure; **no public source read so far states
  either**, and a guessed sizing number is the one thing this wiki must not contain. Q10 asks why
  memory grows with *unacknowledged* messages specifically, and the Synadia post — the only memory
  source available — does not address pending-message state. Both are recorded, with the four other
  unanswerable sizing questions (Q2, Q4, Q5, Q6, Q31), under **What is still unknown** on
  [[jetstream-sizing]] rather than papered over.
- **Tool bug fixed:** `tools/html-to-text.py` was missing `import sys, re, html` and crashed on
  every invocation with `NameError: name 'sys' is not defined` — it had evidently never been run.
  Patched here; it comes from `llm-wiki-starter` and the fix should be pushed back there with
  `tools/update-tools.sh` so the template stops shipping it broken.
- `python3 tools/lint.py`: 24 pages, clean on every check.

## 2026-08-31 — plan step 3: the ADRs
- **Ingested 7 ADRs** from `raw/adr/` — ADR-1, ADR-7, ADR-8, ADR-17, ADR-20, ADR-42, ADR-43 — and
  linked each summary into the `summary` column of `inbox/adr-toc.md`. 7 of 54 ADRs now summarized.
- **Skipped, deliberately and per scope:** the Go client interfaces in ADR-8 and ADR-20 (`KV`,
  `Entry`, `Status`, `KeyValueManager`, `ObjectStore`), ADR-8's Consul/etcd prior-art survey and
  API-naming discussion, and ADR-42/ADR-43's per-language client contracts. `CLAUDE.md` puts
  per-language client API out of scope; what was kept from each ADR is the server-observable half.
- **Summaries created (7):** [[s-adr-1-jetstream-json-api]], [[s-adr-7-server-error-codes]],
  [[s-adr-8-key-value-store]], [[s-adr-17-ordered-consumer]], [[s-adr-20-object-store]],
  [[s-adr-42-priority-groups]], [[s-adr-43-per-message-ttl]].
- **Pages created (6):** concepts [[key-value]], [[object-store]], [[ordered-consumer]],
  [[priority-groups]], [[message-ttl]]; internals [[js-api]]. `since: [2.11]` on
  [[priority-groups]] and [[message-ttl]]; the others' subjects predate the facet range and carry
  their version history inline instead.
- **[[js-api]] is an addition to the plan.** Step 3 routes ADR-1 and ADR-7 at
  `reference/js-api-subjects` and `reference/error-codes`, which step 6 writes from the docs tree.
  But both ADRs carry behaviour no reference table will hold — the ACL consequence of per-object
  subject tokens, paging at `limit: 1024`, and the rule that `err_code` is the contract while
  `description` is explicitly outside SemVer. That went to an internals page; the two reference
  pages remain step 6's.
- **Three facts the ADRs carry and no doc page does**, each recorded on the page it affects:
  - **`failover` on the `overflow` priority policy is not implemented as of 2.14** — the server
    silently ignores the field and does not enforce its documented 5–3600 bounds
    ([[priority-groups]]).
  - **The `Remove` and `Purge` subject-delete markers are documented but not implemented as of
    2.14** — only the `MaxAge` marker is placed ([[message-ttl]]).
  - **Per-message TTL is silently clamped.** Unless `MaxMsgsPer` is 1, a `Nats-TTL` below
    `SubjectDeleteMarkerTTL` is not rejected — the server raises it to that floor and **rewrites the
    stored header** ([[message-ttl]]).
- **`inbox/question-bank.md`**: filled Q28 ([[message-ttl]]), Q70 and Q72 ([[key-value]]), Q71
  ([[message-ttl]] · [[key-value]]). Running total **14 of 82 answered, 9 of 35 ★ rows**.
- **Q69 and Q75 left open** though the plan aimed at them. ADR-8 explains how a watch is built but
  not why one would *miss* updates; ADR-20 explains the two subject spaces but not why a list times
  out during uploads. Both need the GitHub thread behind them, which is step 5's job — the
  candidate mechanism is recorded under `## To verify` on each page so step 5 starts from it rather
  than from scratch.
- `python3 tools/lint.py`: 37 pages, clean on every check.

## 2026-08-31 — plan step 4: the change layer
- **Ingested 3 sources.** `raw/nats-docs/release-notes/upgrade-to-2.12.md` and `upgrade-to-2.14.md`
  (local), and **`https://github.com/nats-io/nats-server/releases/tag/v2.14.0`** via the GitHub API,
  saved verbatim as `raw/release-notes/v2.14.0.md`. Also saved
  `raw/release-notes/_tags-and-dates.md` — **all 291 release tags with publish date and prerelease
  flag** — so every version and date this wiki states traces to one file rather than to a memory.
  New `release-notes` collection recorded in `raw/sources.md`.
- **Summaries created (3):** [[s-docs-upgrade-to-2.12]], [[s-docs-upgrade-to-2.14]],
  [[s-relnotes-2.14.0]].
- **Release entities created (5):** [[nats-server-2.10]], [[nats-server-2.11]],
  [[nats-server-2.12]], [[nats-server-2.14]], [[nats-server-2.15-preview]] — all `kind: release`.
  Exact first/latest tags and dates from the tag index: 2.10.0 (2023-09-19) … 2.10.29 (2025-05-01);
  2.11.0 (2025-03-19) … 2.11.17 (2026-04-27); 2.12.0 (2025-09-22) … 2.12.15 (2026-08-12);
  2.14.0 (2026-04-30) … **2.14.6 (2026-08-27)**; `v2.15.0-preview.1` (2026-08-24, prerelease).
  **The tag index confirms there is no 2.13** — 0 tags matching `v2.13`.
- **[[nats-server-2.10]] and [[nats-server-2.11]] carry an explicit warning that they are not
  changelogs.** The docs mirror has upgrade guides only for 2.12 and 2.14, and neither older
  release body was fetched. Those two pages list only what *other* ingested sources attribute to
  the version by name, and say so at the top rather than implying completeness.
- **Ripple — 7 pages, each gaining a version boundary it did not have:**
  - [[retention-policies]] — the `## To verify` item about WorkQueue/Interest sourcing is
    **resolved**: supported since 2.14, via an automatic durable consumer with the new
    `AckFlowControl` ack policy, plus the expected mixed-version warning and the downgrade
    consequence.
  - [[priority-groups]] — **corrected**. ADR-42 is tagged `2.11` and describes all three policies
    together, but the `prioritized` policy actually arrived in **2.12**. The page now says so; the
    ADR alone would mislead about what a 2.11 server supports.
  - [[stream]] — the behaviour flags are now version-tagged: `allow_msg_ttl` and
    `subject_delete_marker_ttl` 2.11; `allow_atomic`, `allow_msg_counter`, `allow_msg_schedules`
    2.12; `allow_batched` and the cron/sampling/rollup schedule extensions 2.14.
  - [[raft-in-nats]] — two new sections: **overrun protection** (2.14, leaders step down when
    falling behind; a majority overloaded stays degraded) and **a node refuses to start on a
    corrupt or misaligned snapshot** (2.14, deliberate, to avoid data loss). Plus async stream
    flushing (2.12) and async state snapshots (2.14).
  - [[js-api]] — strict mode (log-only 2.11 → rejecting by default 2.12), the `$JS.ACK`/`$JS.FC`
    v1→v2 format change and its ACL deadline, `$JS.API.CONSUMER.RESET` (2.14), and info APIs being
    deprioritised below create-update-delete (2.14).
  - [[consumer]] — the consumer reset API, and the 2.14 `404 No Messages` change for a `no_wait`
    pull with no expiry.
  - [[jetstream-sizing]] — **memory behaves differently from 2.12 onward.** Elastic filestore
    pointers mean RSS may go up *or* down, `GOMEMLIMIT` is the lever, and RSS is no longer a
    straightforward capacity signal — nor comparable across a version boundary.
- **The single most time-sensitive fact this step surfaced:** in **2.15 the default `$JS.ACK` /
  `$JS.FC` subject format becomes v2**, inserting a domain and account hash. Any account
  import/export or subject permission naming `$JS.ACK.<stream>.>` or `$JS.FC.<stream>.>` **must be
  updated before 2.15 ships**. Catch-all `$JS.ACK.>` and single-account deployments are unaffected.
  It is testable today on 2.14 with `feature_flags { js_ack_fc_v2: true }`.
- **`inbox/question-bank.md`**: no cells filled. Q63 and Q64 (rolling upgrade, cross-version
  data-integrity risk) are now *substantially* covered for the 2.11→2.12→2.14 hops — the v2.11.9
  downgrade floor, the stream-state rebuild, offline assets, the `feature_flags` removal — but both
  rows ask for a **runbook**, and this wiki has no [[upgrade-a-cluster]] page yet. Filling them
  against release entities would overstate. Q55 was filled with [[js-api]] and then **reverted**:
  it asks which *server config* keys reload, which is step 6's `config-keys` page (the table
  already holds 411 reloadable / restart-only markers), not an API page.
- `python3 tools/lint.py`: 45 pages, clean on every check. Bank unchanged at 14/82, ★ 9/35.

## 2026-08-31 — plan step 5: the gotcha layer
- **Ingested 4 sources**, all four the plan named.
  - Three `nats-io/nats-server` GitHub Discussions — **gh#7982**, **gh#7831**, **gh#6605** — fetched
    through the GitHub **GraphQL** API rather than scraped, so the original post, chosen answer,
    comments and replies come back as Markdown exactly as their authors wrote them and can be quoted
    verbatim. Saved as `raw/gh-discussions/gh-<n>.md`; new collection recorded in `raw/sources.md`.
    (`tools/extract-forum-posts.py` is for HTML forums; GraphQL is strictly better for GitHub.)
  - **`https://www.synadia.com/blog/jetstream-design-patterns-for-scale`** — note the page's real
    title is *"JetStream Anti-Patterns: Avoid these pitfalls to scale more efficiently"* (Andrew
    Connolly, 2026-06-06); the URL slug and the title disagree.
- **Summaries created (4):** [[s-gh-7982-no-suitable-peers]], [[s-gh-7831-standalone-to-cluster]],
  [[s-gh-6605-which-consumer-is-slow]], [[s-synadia-jetstream-anti-patterns]].
- **Gotcha pages created (4):** [[no-suitable-peers-for-placement]],
  [[streams-deleted-when-clustering-a-standalone-server]], [[jetstream-slows-as-consumers-grow]],
  [[slow-consumer-detected]].
- **[[slow-consumer-detected]] is deliberately a page with no fix.** gh#6605 was asked 2025-03-05,
  never answered, and the one suggestion offered (`nats-top -sort pending`) was reported not to work
  by a second person eleven months later — "`nats top` reports 2 slow consumers but all the
  connections show 'Pending: 0'". The page records the verbatim log line, what it does **not**
  contain, the JetStream-consumer/core-connection terminology collision that sends people looking in
  the wrong place, three explicitly unverified-marked hypotheses, and a list of what would actually
  answer it. **Q58 is left blank in the bank** — the rulebook says a row is answered only when a
  page states the answer, and an unanswerable ★ row is the most valuable kind.
- **Numbers this step put into the wiki**, all from the Synadia post and all flagged as guidance
  rather than server limits (the source says "there's no hard cap" and "there is no hard limit
  here", and states neither the version nor the method behind them):
  **~100,000 consumers** cluster-wide before instability becomes likely, and **~300 disjoint subject
  filters** per consumer.
- **Ripple (3 pages):**
  - [[jetstream-sizing]] — new *Consumers are a cluster-wide budget* section; **Q6 struck off *What
    is still unknown***; two rules of thumb added; "what runs out first" now names the meta leader
    as loaded by **consumer count, not message count**.
  - [[consumer]] — new section: **`consumer info` is a debugging tool, not a control-loop
    primitive.** It routes to the meta leader and calculates state; `create` is idempotent so the
    exists-check is unnecessary, and `NumPending` already rides on every delivered message.
  - [[stream-placement]] — the `[DBG] Peer selection: discard ** reason: … **` line, and the point
    that a placement failure must be **reproduced** with debug on because the reason is not in the
    API response.
- **`inbox/question-bank.md`**: filled Q6, Q7, Q38, and appended the gotcha to Q33. Running total
  **17 of 82 answered, 12 of 35 ★**.
- **Of the twelve symptom-shaped ★ rows the plan pointed at** (Q7, Q13, Q20, Q26, Q33, Q36, Q38,
  Q42, Q55, Q69, Q72, Q77), these four sources cover Q7, Q33 and Q38; Q20 and Q72 were already
  answered in earlier steps. **Q13, Q26, Q36, Q42, Q55, Q69 and Q77 have no source ingested** — the
  plan supplied four URLs, not twelve, and inventing a symptom page without a thread behind it would
  be exactly the guessing the rulebook forbids. Each row still links its own public thread, so they
  are ready for a later pass.
- `python3 tools/lint.py`: 53 pages, clean on every check.

## 2026-08-31 — two tool bugs fixed and backported to llm-wiki-starter
- **`tools/html-to-text.py` was missing `import sys, re, html`** and crashed with
  `NameError: name 'sys' is not defined` on every invocation — it had never been run. Found while
  ingesting the first Synadia blog post in step 2.
- **`tools/build-site.py` crashed on a markdown link whose label contains inline code.**
  `mdlink()` re-enters `inline()` for the label, but each call built its own placeholder list `ph`;
  the CODE pass runs before the MDLINK pass, so a label like `` [`jsm.go`](url) `` already holds a
  `\x00N\x00` placeholder when the nested call starts, and the nested call's own (shorter) list
  indexes out of range. `IndexError: list index out of range`, no page name in the traceback.
  Fixed by sharing the list across nested calls and expanding only at the top level — which is what
  the existing `for _ in range(4)` expansion loop was always written to support.
- **Both bugs were in `../llm-wiki-starter/template/tools/`, not just here**, and
  `tools/update-tools.sh` copies template → wiki, so the next run would have overwritten both
  fixes. Backported both files, plus a **regression guard** in the starter's `tools/selftest.sh`:
  the test page now carries a `` [`code-label`](https://example.org/x) `` link and the test greps
  for its rendered `<a class="ext" …><code>code-label</code></a>`.
- Verified by temporarily reverting the fix in the starter: the selftest reproduces the exact
  `IndexError`. With the fix, `selftest passed` — template wiki plus the 664-page reference wiki
  (2050 files, 13313 links). Left uncommitted in both repos for review.
- Site built and served: **53 pages, 534 links, 30 wanted, 928 raw files, 757 TOC rows** on
  http://127.0.0.1:8080/.

## 2026-08-31 — plan step 6: the reference pages
- **Six reference pages written**, all from the local mirror plus, where the docs are silent, the
  **`nats-io/nats-server` source at tag v2.14.6**: [[defaults-and-limits]], [[config-keys]],
  [[js-api-subjects]], [[error-codes]], [[monitoring-endpoints]], [[advisories]]. Each carries a
  **How this was derived** section naming the exact file, endpoint or command it can be regenerated
  from.
- **New sources.** `raw/nats-server-src/constants-v2.14.6.md` — the exact line ranges quoted from
  `server/const.go`, `consumer.go`, `stream.go`, `filestore.go`, `server.go` and `jetstream_api.go`,
  verbatim with their real line numbers, so every default links to
  `…/blob/v2.14.6/server/<file>#L<line>`. Summarised as [[s-nats-server-constants-2.14.6]]. Also
  [[s-docs-monitoring-endpoints]], the only prose source for the monitoring port.
- **Four values the docs never state, now established against the source** — each had been carried
  as a `## To verify`:
  - **`duplicate_window` defaults to `2m`** (`stream.go:1658`), confirming the Synadia blog figure
    for 2.14 and closing the item on [[stream]]. It applies only when the stream sets no window and
    is neither mirror nor source, clamped by the account limit and by `max_age`.
  - **`write_deadline` defaults to `10s`** (`DEFAULT_FLUSH_DEADLINE`, `const.go:132`) — exactly the
    `10s` in the slow-consumer log line of [[slow-consumer-detected]], so that message reads the
    same on nearly every deployment.
  - **`PriorityTimeout` defaults to `2m`** (`JsDefaultPinnedTTL`, `consumer.go:582`), closing the
    item on [[priority-groups]].
  - **What "8MB not recommended" means**: above 8 MB the server logs a startup warning and does
    nothing else (`server.go:2342`); the constant's comment says a future version *may* reject it.
    Closes the item on [[jetstream-sizing]].
- **Three docs errors found and reported.** Cross-checking all 22 advisory reference pages against
  the `JSAdvisory*Pre` constants found **3 wrong subjects** — `MSG_NAK` (server: `MSG_NAKED`),
  `GROUP_PINNED` (server: `PINNED`), `GROUP_UNPINNED` (server: `UNPINNED`). Verified three ways: the
  constant, the publish site in `consumer.go`, and NATS' own learn page and ADR-42, both of which
  have it right — **only the generated reference pages are wrong**, and a subscription written from
  them receives nothing silently. Recorded with 4 further findings in **`inbox/docs-issues.md`**,
  now a fourth viewer TOC table (*Docs issues*). `CLAUDE.md` gained a standing rule plus
  *Operation: record a docs issue*, wired into the ingest checklist, lint, Boundaries and the map,
  so this is automatic rather than invoked.
- **Ripple (8 pages):** [[stream]] (dedup window confirmed + clamp rules), [[priority-groups]]
  (default confirmed; corrected advisory subjects), [[ack-and-redelivery]] (`MSG_NAKED` correction,
  defaults line-referenced), [[consumer]] (defaults line-referenced, docs gap named),
  [[slow-consumer-detected]] (**substantially rewritten** — `/varz`'s `slow_consumers` and
  `/connz?sort=pending&auth=true` are real leads the unanswered thread never mentions, plus a marked
  unverified-marked reading of why `Pending: 0` can coexist with a slow-consumer count),
  [[jetstream-sizing]] (8 MB resolved, `/jsz` scoping, `sync_interval` restart-only),
  [[replicas]] and [[raft-in-nats]].
- **`inbox/question-bank.md`**: filled Q57, Q59, Q82, extended Q12. **Q16 was filled and then
  reverted** — both `ack_wait` and `duplicate_window` are now known, but no source states how they
  *interact*, which is what the row asks. Running total **20 of 82 answered, 13 of 35 ★**.
- `python3 tools/lint.py`: 61 pages, clean. Viewer rebuilt: 1209 files, 642 links, 783 TOC rows.

## 2026-08-31 — plan step 7: entities (the last step of the plan)
- **34 entity pages, one for every repo, client, tool, product and organisation the docs' ecosystem
  page names.** Twelve clients ([[nats-go]], [[nats-js]], [[nats-py]], [[nats-java]], [[nats-rs]],
  [[nats-net]], [[nats-c]], [[nats-zig]], [[nats-swift]], [[nats-pure-rb]], [[nats-rb]],
  [[nats-ex]]); [[orbit]] for the seven `synadia-io/orbit.*` repos together; nine tools
  ([[nats-cli]], [[nsc]], [[nk]], [[nats-top]], [[nats-box]], [[prometheus-nats-exporter]],
  [[nats-surveyor]], [[nats-helm-charts]], [[nack]]); four project repos ([[nats-server]],
  [[nats-architecture-and-design]], [[jsm-go]], [[nats-streaming]] with `deprecated: true`); two
  organisations ([[synadia]], [[cncf]]); one products page. Every `kind: tool` page carries a
  `## Cheat sheet`, which the viewer collects.
- **Two deviations from the plan, deliberate.** (1) The plan listed the Prometheus exporter but not
  **[[nats-surveyor]]** or **[[nack]]**; both are named on the same ecosystem page, both are what an
  operator actually reaches for, and both had sources to hand — added. (2) The plan asked for "a thin
  page per commercial product"; the public sources read give **one sentence per product and no
  more**, so the five are one page, [[synadia-products]], rather than five stubs. Said on the page
  itself.
- **New sources, because the ecosystem page states no versions, licences or feature coverage and
  explicitly delegates coverage to "each repo's README".**
  - `raw/github-repos/` — **32 repos and 24 READMEs**, verbatim from the GitHub API through a new
    `tools/fetch-repo-facts.py` (`--readme`, `--refresh`, `--list`; regenerates `_index.md` every
    run). Summarised as [[s-github-repo-facts]]. This is what makes the entity pages falsifiable:
    one command re-checks every version, licence and archived flag.
  - `raw/nats-server-src/README-v2.14.6.md` → [[s-nats-server-readme]] — the only public source read
    for **CNCF membership**, the Apache-2.0 statement and the **Trail of Bits / OSTIF security audit
    (April 2025)**.
  - `raw/cncf/` → [[s-cncf-nats-project]] — "NATS was accepted to CNCF on **March 15, 2018** at the
    **Incubating** maturity level", which nothing inside `nats-io` states.
  - Docs ingests: [[s-docs-ecosystem]] (the naming authority for the whole step),
    [[s-docs-getting-started]], [[s-docs-kubernetes]], [[s-docs-prometheus-and-dashboards]].
- **Facts worth having found**: [[nats-swift]] is **Core NATS only** — JetStream, KV, Object Store
  and Services are roadmap, and its last release is 2024-10-31; [[nats-zig]] is pre-1.0 with **no
  Object Store and no mTLS**; [[nats-ex]] publishes as **`gnat`** and, with [[nats-top]], is **MIT**
  rather than Apache-2.0; [[nats-rs]]'s `chrono` feature is unified across the whole Cargo graph;
  [[nack]] **silently does not reconcile** KeyValue/ObjectStore resources outside `--control-loop`
  mode; the Helm chart's readiness probe is deliberately shallow, so a pod still catching up its R3
  replicas serves clients.
- **Three docs issues found and reported** (`inbox/docs-issues.md` #8–10), all from checking every
  claim in the docs' client tables against its repository — 12 clients read, 3 claims did not
  survive. **#8** `nats.net` is documented as ".NET 6+" but v3.0.0 (2026-07-10) **dropped `net6.0`**;
  **#9** `nats.deno` is listed among "the archived" superseded repos and is **not archived** (3 of 4
  are); **#10** the Python client now ships **two PyPI distributions** — `nats-py` (>=3.7) and
  `nats-core` 0.2.0 (**>=3.13**) — and no docs page reconciles them: the client map names neither and
  the only mention of `nats-core` in the whole tree is a WebSocket page. Both `wrong-value` rows are
  staleness in a hand-maintained table, which is a different failure from the generated-page errors
  in #1–3.
- **`inbox/question-bank.md`**: five rows added, each with a public thread behind it — **83–85** from
  three *unanswered* Q&A discussions on metrics (gh#3857, gh#6145, gh#6224), answered here by
  [[prometheus-nats-exporter]], [[nats-surveyor]] and [[monitoring-endpoints]]; **86–87** from
  gh#7296, answered by [[orbit]]. Two further rows were drafted and **dropped for want of a source** —
  a "which client should I pick" question is not in the public record in any form this wiki could
  cite, so it is not in the bank.
- `python3 tools/lint.py`: **97 pages, clean** — no frontmatter issues, no orphans, no broken links,
  nothing missing from the index.

## 2026-08-31 — plan step 0: the four most-cited wanted pages
Step 0 was **added to `inbox/plan-runbooks-and-security-2026-08-31.md` after measuring the wiki**
rather than reading a source: the link graph showed four pages already cited by six to nine other
pages each and resolving to nothing, with every source local. Paying them off first was the cheapest
real improvement available.

- **Four pages written**, from six ingests:
  - [[direct-get]] (11 inbound links from 9 pages) — `allow_direct` (default **false**, opt-in), the
    two subjects and the `_sys_` queue group, the request fields, batch with `Nats-Num-Pending` and
    the `204 EOB` sentinel, the four status codes, and the response headers. The operator line is
    blunt: **a missing `allow_direct` is a timeout, not an error**, and Direct Get can never confirm
    a write.
  - [[account]] (11 from 7) — the absolute boundary, `$G` and `$SYS`, per-account JetStream
    (`10039`), the `No responders are available` symptom that is really an account-boundary fact, and
    the three `no_auth_user` traps (no reload, `-t` will not catch it, rejected in operator mode).
  - [[worker-pool]] (10 from 7, `kind: pattern`) — demand-based distribution, `max_ack_pending` as a
    ceiling **shared across the consumer, not per worker**, `ack_wait` as the window in which a crash
    is invisible, and the queue-group comparison.
  - [[mirrors-and-sources]] (7 from 6) — the mirror/source table, `Lag` as **RPO**, the four
    `mirror_direct` alignment rules, and the two silent failures (a wrong cross-domain export *type*,
    and a desynchronised `mirror_direct`).
- **Six summaries**: [[s-docs-get-direct]], [[s-adr-31-direct-get]], [[s-docs-worker-pool]],
  [[s-docs-mirrors-and-sources]], [[s-docs-mirrors-as-dr]], [[s-docs-accounts-and-multitenancy]].
  ADR-31 was ingested beyond the plan's list because the docs page names it as the authoritative spec
  and it carries everything the docs page omits — subjects, headers, status codes and `mirror_direct`.
  Its row in `inbox/adr-toc.md` now links the summary (**8 of 54 ADRs read**).
- **Ripple.** [[js-api-subjects]] — the two Direct Get subjects rewritten with the payload/appended
  distinction, the `_sys_` queue group, the `allow_direct` precondition and the fact that Direct Get
  answers are **plain messages with headers, not the `$JS.API` JSON envelope**.
  [[error-codes]] — `10060 JSStreamNotMatchErr` added. [[replicas]] — a new section on reads served
  from outside the cluster via `mirror_direct`, and the R3-is-not-a-second-site point.
  [[key-value]], [[stream]], [[consumer]], [[ack-and-redelivery]], [[retention-policies]],
  [[object-store]] and [[jetstream-slows-as-consumers-grow]] needed no edit — they already linked
  these four pages, which is what made them the right ones to write.
- **One error caught in review before it shipped**: the `10060` row was first written with an
  invented Go constant (`JSStreamMismatchErr`). The real name is **`JSStreamNotMatchErr`**, verified
  against `raw/nats-docs/reference/jetstream/errors.md:166`. Recorded here because inventing a
  constant is exactly what `CLAUDE.md` forbids, and the fix came from checking rather than from luck.
- **No new docs issues.** All six sources were checked against the ADR and the generated reference;
  the docs and ADR-31 agree, including on the retracted `allow_direct` auto-promotion, which ADR-31
  documents as a superseded revision rather than leaving stale.
- **`inbox/question-bank.md`**: rows **88–91** added, each with a public thread; Q15 and Q22 extended
  with [[worker-pool]]. **89 and 91 are deliberately left unanswered** — cross-domain sourcing setup
  and mirror catch-up contention are not in any source read. **91 rows, 26 answered.**
- Wanted pages down from **17 to 13**. `python3 tools/lint.py`: **107 pages, clean.**

## 2026-08-31 — plan step 1: the install and cluster runbooks

**Operation:** plan → step 1 of `inbox/plan-runbooks-and-security-2026-08-31.md`
(*the install and cluster runbooks*).

**Sources ingested (9).** The four the plan listed —
`raw/nats-docs/learn/topologies/single-server.md`, `learn/topologies/your-first-cluster.md`,
`learn/clustering/forming-a-cluster.md`, `learn/deployment/hardening.md` — and **five more that the
work forced**, because a runbook may not state a command this wiki has not read:

- `util/nats-server-hardened.service` and `util/nats-server.service` at **v2.14.6**
  ([[s-nats-server-systemd-units]]). The hardening page shows an *extract* of the first, and the
  extract omits `User=`, `Group=`, `ExecStop=` and `TimeoutStopSec=`. The runbook quotes the file.
- `server/route.go` at v2.14.6 ([[s-nats-server-route-cluster-formation]]), read to check one log
  line and worth far more than that — see the docs issue below.
- **gh#7190** ([[s-gh-7190-asymmetric-cluster]]) — a three-node cluster with route counts 8 + 6 + 6
  and partitioned clients, from a single multi-value DNS name as the route address. Unanswered;
  @wallyqs names the cause.
- **gh#3569** ([[s-gh-3569-connect-to-route-port]]) — `attempted to connect to route port`, answered
  by @Jarema. The mirror image of the docs' own "half of cluster-formation bugs" pitfall.
- **gh#6070** ([[s-gh-6070-lame-duck-under-systemd]]) — a unit whose `ExecStop` sends **SIGINT**, so
  lame-duck mode never runs. Unanswered, but both maintainer replies agree: with systemd, drain
  through `systemctl`.

New raw files: `raw/nats-server-src/systemd-units-v2.14.6.md`, `route-v2.14.6.md`,
`const-lame-duck-v2.14.6.md`, `raw/gh-discussions/gh-7190.md`, `gh-3569.md`, `gh-6070.md`;
`raw/sources.md` updated for both collections.

**Two pages written.**

- [[install-nats-server]] (`kind: runbook`) — the config that earns its four lines, the systemd unit
  **as the repo ships it**, Docker, Helm, five verification commands, and a rollback that says
  plainly that stopping the service does not remove the data. Its three-line table of what
  `ExecReload` / `ExecStop` / `TimeoutStopSec` buy is the part the docs do not have.
- [[build-a-3-node-cluster]] (`kind: runbook`) — seed and joiners, gossip, TLS on the route block,
  firewall, Helm; then five checks in order, starting with `Cluster name is east` in the server's own
  log because it needs no credentials. Six pitfalls, three of them from the GitHub threads.

**Ripple (9 pages).** [[defaults-and-limits]] — `lame_duck_duration` `2m` and
`lame_duck_grace_period` `10s` with their `const.go` lines and why a service unit cares.
[[error-codes]] — `10074 JSStreamReplicasNotSupportedErr`. [[config-keys]] — the two lame-duck keys,
`cluster.port` `6222`, and **corrected counts** (below). [[monitoring-endpoints]] — the
`http: "127.0.0.1:8222"` bind that is right on a VM and an outage on Kubernetes.
[[replicas]] — R>1 on a standalone server is refused, not degraded. [[jetstream-sizing]] — the FD
limit now quoted from the shipped unit. [[nats-server]] — the four ports and the two units in
`util/`. [[nats-cli]] — `nats server check connection` in the cheat sheet.
[[streams-deleted-when-clustering-a-standalone-server]] — its prevention section now names both
runbooks.

**A wiki tool bug, found and fixed.** `tools/build-config-table.py` globbed
`raw/nats-docs/reference/config/**` and so never read the **root** `reference/config.md`, which is
where the docs state every top-level key's default and reload marking. `lame_duck_duration` looked
undocumented when the docs give `2m`. Fixed by loading the root page and by teaching `table()` to
read a `## Properties` section split across `###` subheadings. Result: **179 → 216 keys with a stated
default**, and the reload split corrected from 285/126/134/76 to **261/150/174/36**.
[[config-keys]] carried the old counts and now carries the new ones. *No wiki page had a wrong value
because of this — but [[defaults-and-limits]] would have grown one had the table not been fixed
first.*

**Two docs issues recorded** (`inbox/docs-issues.md` #11–12):

- **#11 · `missing`, medium** — both learn pages state that a cluster-name mismatch splits the
  cluster. True for two *configured* names; a server whose `cluster.name` is **unset** adopts the
  peer's name and drops its other routes (`route.go:3056–3070`, and `:576` on the soliciting side).
  The server warns — `Cluster name was dynamically generated, consider setting one` — and no doc page
  mentions it.
- **#12 · `enhancement`, low** — the hardening page's systemd extract drops `User=`/`Group=` (so the
  block as shown runs the server as root, on a hardening page), `ExecStop=`, `TimeoutStopSec=` and
  `Restart=`. The page does tell you to copy the real file, which is why this is not a defect.

**One invented fact caught before it shipped.** A question-bank row was first written citing
`gh#2543` for "is there a recommended systemd unit" — a thread number that does not exist. Checked
against the API, removed, and replaced with two threads that do (gh#3569, gh#6070) after reading
them. Recorded here because the failure was mine, not a source's, and the fix was a check rather
than luck.

**`inbox/question-bank.md`**: **Q47** answered by [[build-a-3-node-cluster]] (gh#7190 gives the
cause, not a fix, and the page says so); rows **92–93** added, each with a thread read in full.
**93 rows, 29 answered.**

Wanted pages down from **13 to 11**. `python3 tools/lint.py`: **118 pages, clean.**

## 2026-08-31 — plan step 2: upgrade, reload and rebalance

**Operation:** plan → step 2 of `inbox/plan-runbooks-and-security-2026-08-31.md`.

**Sources ingested (6).** The three the plan listed —
`raw/nats-docs/learn/deployment/rolling-upgrades.md`, `learn/deployment/config-management.md`,
`learn/clustering/scaling-and-peers.md` — and three more that verification turned into sources:

- `server/signal.go` + the `Command` constants ([[s-nats-server-signals]]). Confirms the docs' claim
  that a draining server **ignores SIGTERM**, and adds three facts the docs never state:
  `nats-server --signal stop` sends **SIGKILL**, `SIGUSR1` re-opens the log file (log rotation), and
  every signal is logged as `Trapped "…" signal` before it acts.
- The Helm chart's `values.yaml` **at chart release nats-2.14.6**
  ([[s-nats-helm-chart-values-2.14.6]]) — read from the tag rather than `main`, so the numbers are
  pinned. The lame-duck defaults satisfy the chart's own rule **exactly** (10 + 30 + 20 = 60), so
  there is no slack; the reloader only watches volumes under `/etc/`.
- `Server.lameDuckMode()` ([[s-nats-server-lame-duck]]) — read to check one sentence of sizing
  advice, and it did not survive. See the docs issue below.

New raw files: `raw/nats-server-src/signal-v2.14.6.md`, `lame-duck-v2.14.6.md`,
`raw/github-repos/nats-io__k8s.values-nats-2.14.6.md`; `raw/sources.md` updated.

**Three pages written, where the plan named one.** Reload and rebalance are different operations
answering different questions (Q54/Q55 versus Q34); merging them would have produced a page that
answers neither cleanly.

- [[upgrade-a-cluster]] (`kind: runbook`) — the drain, the order rule (non-leaders first, meta-leader
  last), the `current` gate between nodes, a signal table, the Kubernetes lifecycle, and a
  **version-hazard table** with the downgrade floors that make Q64 answerable: **v2.11.9** for
  2.12 → 2.11, `feature_flags` removed before 2.14 → 2.12, and `$JS.ACK` v2 becoming the default in
  2.15.
- [[reload-server-config]] (`kind: runbook`) — validate with `-t`, SIGHUP, verify
  `Reloaded server configuration`. Built on the docs' own rule: a reload changes **policy**, never
  **identity**.
- [[rebalance-streams]] (`kind: runbook`) — adding a node moves nothing. `--replicas` versus
  `peer-remove`, catchup and lag, and the discipline that matters: one change at a time, gated on a
  named leader and zero lag.

**Ripple (8 pages).** [[error-codes]] — `10075 JSPeerRemapErr` and
`10202 JSClusterServerMemberChangeInflightErr`. [[config-keys]] — the reload procedure, the
atomicity guarantee, and the `-t` blind spot. [[defaults-and-limits]] — what the lame-duck keys
actually bound. [[raft-in-nats]] — a new paragraph on **meta election versus stream election**, which
is the reason the upgrade order rule exists. [[nats-helm-charts]] — three facts read from the chart
rather than from a docs page. [[nats-cli]] — both `peer-remove` commands.
[[install-nats-server]] — the signal table. [[build-a-3-node-cluster]] — its rollback now points at
[[rebalance-streams]] rather than describing the move in prose.

**Two docs issues recorded** (`inbox/docs-issues.md` #13–14):

- **#13 · `wrong-value`, ★ medium.** `learn/deployment/rolling-upgrades.md` says to size
  `lame_duck_duration` to cover "how long JetStream needs to move leadership off this node", and its
  pitfall describes a node that "kicks its clients and exits while the stream is still catching up".
  `Server.lameDuckMode()` (v2.14.6, `server.go:4439–4565`) orders the work the other way: Raft
  stepdown (`transferRaftLeaders()`, fixed **one-second** wait) and JetStream shutdown complete
  **before** the close schedule is computed at `:4496`. The duration governs client disconnects only —
  and then it is `duration − grace_period`, with the per-client interval **capped at one second**
  (`:4514–4518`), so ten clients drain in about ten seconds whatever the duration says.
- **#14 · `enhancement`, low.** The same page uses "grace period" for `lame_duck_grace_period`
  (must be **shorter** than the duration — enforced at startup, `server.go:1152`) and for
  `terminationGracePeriodSeconds` (must be **longer**), two paragraphs apart. Applying the second
  sentence to the first key gives a server that refuses to start.

**A correction to this wiki's own page, made before publishing it.** The first draft of
[[upgrade-a-cluster]] repeated the docs' sizing advice verbatim. It was rewritten once the source was
read, and the page now says explicitly what the duration does not cover and points at the `current`
gate as the thing that protects the stream. The rule in `CLAUDE.md` — prefer the server, say the
sources disagree, record the finding — is what caught it.

**`inbox/question-bank.md`**: **Q34, Q54, Q55, Q63, Q64** answered, Q93 completed with the upgrade
page. **93 rows, 34 answered** (was 29).

Wanted pages down from **11 to 10**. `python3 tools/lint.py`: **127 pages, clean.**

## 2026-08-31 — plan step 3: backup, restore and disaster recovery

**Operation:** plan → step 3 of `inbox/plan-runbooks-and-security-2026-08-31.md`.

**Sources ingested (6).** Two of the plan's five ingests were **already done in step 0** (both
mirrors pages), so the three remaining docs pages —
`raw/nats-docs/learn/backup-recovery/stream-backup-restore.md`, `disaster-recovery.md`,
`config-and-jwt-backup.md` — plus three the work forced:

- the snapshot/restore path across `server/memstore.go`, `server/stream.go` and
  `server/jetstream_api.go` at v2.14.6 ([[s-nats-server-snapshot-restore]]);
- `natscli` **v0.4.0** `cli/stream_command.go` ([[s-natscli-backup-restore]]) — every flag the two
  commands take;
- **gh#4342** ([[s-gh-4342-memory-stream-backup]]), the thread question-bank Q32 was mined from,
  with an accepted maintainer answer.

New raw files: `raw/nats-server-src/snapshot-restore-v2.14.6.md`,
`raw/github-repos/nats-io__natscli.stream-backup-v0.4.0.md`, `raw/gh-discussions/gh-4342.md`.

**Three pages written.**

- [[backup-and-restore-jetstream]] (`kind: runbook`) — the snapshot's two files, `--check`, the two
  enforced restore rules, **restoring somewhere else at a different size**, the verification that is
  the actual deliverable, and a *Memory streams* section that states the real error.
- [[disaster-recovery]] (`kind: runbook`) — the failure-to-tool table, the five-step mirror
  promotion with `Lag` as the RPO, and the two preconditions (**meta quorum must survive the site
  loss**; the DR mirror belongs in its own domain or cluster) that are decided at design time.
- [[backup-and-restore-identity]] (`kind: runbook`) — the three file groups, sealing with a curve
  key, and step 4: **re-pushing accounts into the server's resolver**, without which every user still
  gets `Authorization Violation` while every local listing looks correct.

**Four docs issues recorded** (`inbox/docs-issues.md` #15–18), all from checking Q32's own subject:

- **#15 · `wrong-value`, ★.** A memory stream's backup is documented to fail with
  `memory streams do not support snapshots`. `memStore.Snapshot` returns **`no impl`**
  (`memstore.go:2425`), surfacing as **10064** `snapshot failed: no impl`. The string in the docs
  exists nowhere in the server, and the CLI does not pre-check storage type either. This is the
  question operators actually ask, and the documented message is unsearchable.
- **#16 · `wrong-value`, low.** The restore rename error is quoted as the server's and in the
  singular; it is the **CLI's** (`stream_command.go:1308`) and reads `stream names may not be changed
  during restore`. The server's own rejection is **10060**.
- **#17 · `wrong-value`, low.** The snapshot schema gives `chunk_size` a maximum of
  `9223372036854776000`; the server clamps to **1 MiB** silently (`jetstream_api.go:4277`).
  `window_size`'s documented 32 MiB is exactly right — same page, same generator, one field wrong.
- **#18 · `missing`, medium.** `nats stream restore` takes `--config`, `--cluster`, `--tag` and
  `--replicas`; neither the backup page nor the DR page mentions any of them, so "restore the
  production R3 snapshot into the DR cluster as R1" — one command — is invisible.

**Ripple (5 pages).** [[error-codes]] — `10064`, `10065`, `10130`, and a note that 10064's whole
description is `{err}`. [[stream]] — `storage: memory` gives up **backup**, not only durability, and
storage is fixed at creation. [[replicas]] — a new first bullet: **replication is not a backup**.
[[mirrors-and-sources]] — points at the promotion runbook. [[nats-cli]] — the backup/restore flags.

**Two question-bank rows corrected rather than filled**, both by reading the linked thread:

- **Q40** cited gh#6892, which turns out to ask how to *evict a sick-but-not-dead node and its
  clients by IP* during a hardware failure — a question no page here answers. The row's wording was
  corrected to match the thread and **left open**; the previous wording invited a wrong tick.
- A row for identity backup, added citing gh#4342, was **removed** after reading that thread: it is
  about memory streams, and is Q32's own source.

**[[backup-and-restore-identity]] therefore has no question-bank row.** Searches of
`nats-io/nats-server` discussions and `nats-io/nsc` issues found no public thread asking about
identity backup. The page stays — a restored stream nobody can authenticate against is not a
recovery, and the plan named the source — and the gap is recorded here rather than filled with an
invented citation. It is also a finding in its own right: the most unrecoverable loss in a NATS
deployment is the one nobody asks about in public.

**`inbox/question-bank.md`**: **Q32** answered, Q40 rewritten and left open. **93 rows, 35
answered.**

Wanted pages down from **10 to 9**. `python3 tools/lint.py`: **136 pages, clean.**

## 2026-08-31 — plan step 4: security and multi-tenancy

**Operation:** ingest ×17 (the whole `learn/security/` chapter, seven GitHub threads, and two source
readings) · **Plan:** `inbox/plan-runbooks-and-security-2026-08-31.md`, step 4.

The plan called this "the biggest gap in the wiki" and it was: the `security` facet held one page.
It now holds five concepts, two runbooks and a gotcha, and the facet is the second-largest in the
wiki.

**Sources ingested.** The plan listed eight docs pages; one ([[s-docs-accounts-and-multitenancy]])
was already done in step 0, so seven were read, plus the chapter's closing page:
[[s-docs-authentication-basics]], [[s-docs-authorization]], [[s-docs-cross-account]],
[[s-docs-operator-mode]], [[s-docs-decentralized-auth]], [[s-docs-auth-callout]],
[[s-docs-encryption-and-tls]], [[s-docs-security-checklist]].

**Nine ingests beyond the list**, every one forced by a question the docs do not answer:

- **seven GitHub threads**, one per open ★ or unanswered bank row —
  [[s-gh-7854-jwt-push-timeout]] (Q49), [[s-gh-7684-certificate-expiry]] (Q50),
  [[s-gh-7017-kv-across-accounts]] (Q51, **no replies since 2025-06-29**),
  [[s-gh-5044-restrict-durable-consumers]] (Q52, unresolved),
  [[s-gh-7505-auth-callout-nkey]] (Q53), [[s-gh-4535-unauthenticated-connections]] (Q56),
  [[s-gh-5606-cross-account-jetstream]] (Q90);
- **`nats-server` at v2.14.6** across eight files ([[s-nats-server-auth-and-tls]]) — the docs state
  the auth-callout deadline and the TLS handshake budget as flat numbers, and `CLAUDE.md` forbids
  repeating a default this wiki has not checked;
- **`natscli` at v0.4.0** ([[s-natscli-account-tls]]) — because Q50 asks how to *detect* expiry and
  neither the docs nor the thread names the command that does it.

**Pages created (8).** Concepts [[subject-permissions]], [[operator-mode]], [[auth-callout]],
[[tls-in-nats]], [[cross-account-sharing]]; runbooks [[set-up-operator-mode]] and
[[rotate-tls-certificates]] (a wanted page since step 0); gotcha
[[unauthenticated-clients-still-connect]].

**Three findings the sources do not carry:**

- **`nats account tls`** — a certificate-chain check with `--expire-warn` (default `1w`), a non-zero
  exit and a deliberately stable grep pattern, reading the chain off the CLI's own connection so no
  `handshake_first` is needed. Nobody in gh#7684 mentions it and no docs page names it. It is the
  real answer to Q50's second half.
- **The server verifies nothing the client presented before an auth callout.** `fillConnectOpts`
  copies `Nkey`, `SignedNonce`, `Token`, `Username` and `Password` verbatim — so
  `connect_opts.nkey` is a claim, not a fact. The thread says the same in one sentence; the source
  says it in code, and also shows the way out: the server fills `client_info.nonce` when a signature
  was supplied, so a callout service can do the challenge-response itself.
- **The `$G` user the server invents.** `server.go:1445` fabricates a user in the global account and
  points `no_auth_user` at it under four exact conditions — and `server.go:3290` deliberately leaves
  `auth_required: true` for it. That is the mechanism behind gh#4535, and it explains why the docs'
  rule of thumb ("only the system account declared") is now too broad: the 2.10.2 fix added the
  `!opts.authBlockDefined` condition.

**Docs issues #19–#21, all ★.** #19 is the largest sweep so far: **15 timeout defaults** in the
generated config reference, of which **10 are verified wrong** (all `tls.timeout` keys say `500ms`,
the server says `2s`; all `authorization.timeout` keys say `1`, the server says `2s` or
`tls_timeout + 1`), **1 documents an option the server does not have** (`websocket.tls.timeout`) and
4 were not checked. #20: `/varz` has carried `tls_cert_not_after` per listener since PR #7709 and the
861-page docs tree never names it, while telling operators to "monitor validity dates". #21: the
`external` block is required for cross-account replication, is pointed at a reference page that omits
it, and appears **nowhere** in the docs — which is why gh#7017 has gone unanswered for over a year.

**A wiki bug fixed, not just recorded.** [[config-keys]] carried the docs' `500ms` and `1` and had
*rationalised* the discrepancy ("They are different things and both are real"). Both sections are
rewritten against the server, with the correction stated on the page, and the derivation section now
says explicitly that where the generated table and the server disagree, the page states the server.

**Ripple (13 pages).** [[account]] — its three `## To verify` items resolved, a new *two
configuration models* section, and the fabricated-`$G`-user failure mode; [[config-keys]] (corrected,
plus an operator-mode key table); [[defaults-and-limits]] (*Authentication and TLS handshake
budgets*); [[monitoring-endpoints]] (`tls_cert_not_after`, with the three caveats);
[[error-codes]] (10021, 10022, 10024); [[js-api-subjects]] (a `$SYS` table — the claims subjects and
`$SYS.REQ.USER.AUTH`); [[key-value]] (*Sharing a bucket with another account*); [[nats-cli]] (the
identity cheat sheet extended, plus certificates and account data); [[nsc]] (*When a push fails*);
[[install-nats-server]], [[build-a-3-node-cluster]], [[reload-server-config]],
[[backup-and-restore-identity]] (links).

**Question bank: 93 rows → 98, 35 answered → 44.** Filled Q49, Q50, Q52, Q53, Q56, Q90. Added Q94–Q98,
two of them deliberately unanswered. **Q51 stays open on purpose** and the bank now says why: the
wiki can name both routes and their fields but no public source gives the configuration, so marking
it answered would be exactly the "a page touches the topic" claim the bank exists to prevent.

Wanted pages down from **9 to 8** ([[rotate-tls-certificates]] written). `python3 tools/lint.py`:
**161 pages, clean** (136 → 161: 8 wiki pages and 17 summaries) — no broken links, no orphans, no frontmatter issues, none missing from the
index.

## 2026-08-31 — plan step 5: the second gotcha pass

**Operation: ingest ×12**, worked from `inbox/plan-runbooks-and-security-2026-08-31.md` step 5. The
step said: take the ★ symptom rows still blank after steps 1–4 — **Q26, Q39, Q42, Q62, Q69, Q77** —
open the linked thread, and write one gotcha page per symptom. Do not crawl.

**Two of the six rows turned out to be wrong, and reading the threads first is what found it.**

- **Q26** ("what happens when JetStream runs out of disk") pointed at
  [gh#5924](https://github.com/nats-io/nats-server/discussions/5924), which is not about capacity at
  all: 45 of 50 stream directories had vanished from a `store_dir` on **tmpfs**, and the maintainer's
  answer is that `tmpwatch`/`tmpreaper`/`tmpfiles.d` reap tmpfs by age — *"pointing the file store to
  tmpfs is not a supported/endorsed configuration"* (@neilalexander). The row was **corrected** to
  the question the thread asks.
- **Q69** ("why does my KV watcher miss updates, and how do I watch many keys at once")  pointed at
  [gh#6746](https://github.com/nats-io/nats-server/discussions/6746), which asks only the second half
  and was **self-answered in an hour**. A search of `nats-io/nats-server` discussions found **nobody
  publicly reporting a missed KV update**, so the row lost that half and the wanted page
  `kv-watcher-misses-updates` was **retired rather than written**. Recorded in [[key-value]]'s
  `## To verify` and in `wiki/index.md`.

**Sources ingested (12).** Seven `nats-io/nats-server` **discussions** — gh#5924, gh#7463, gh#7834,
gh#6490, gh#6746, gh#5243, gh#5859 — plus **three GitHub issues** and **two server-source extracts**.

- **A new `raw/gh-issues/` collection.** The genuine out-of-disk question is asked in the *issue*
  tracker, not the discussion tree: [#4281](https://github.com/nats-io/nats-server/issues/4281)
  (`insufficient storage resources available (10047)`, **open since 2023-06-29**, six reporters),
  [#8322](https://github.com/nats-io/nats-server/issues/8322) and
  [#5871](https://github.com/nats-io/nats-server/issues/5871) (the same defect reported two years
  apart). Kept separate from `gh-discussions` because an issue carries a state, a closing PR and a fix
  version that a discussion does not — which is exactly what settled the version floor below.
- **`nats-server` v2.14.6 across ten files** and **`nats.go` v1.53.1**, saved as
  `raw/nats-server-src/jetstream-resources-v2.14.6.md`, `leafnode-js-domains-v2.14.6.md`,
  `jetstream-log-warnings-v2.14.6.md` and `raw/nats-go-src/errors-v1.53.1.md`.

**Summaries created (12):** [[s-gh-5924-filestore-dirs-vanished]], [[s-gh-7463-jetstream-corruption]],
[[s-gh-7834-leafnode-same-js-domain]], [[s-gh-6490-high-message-lag]], [[s-gh-6746-watch-many-keys]],
[[s-gh-5243-kv-watchers-at-scale]], [[s-gh-5859-unexpected-nats-timeout]],
[[s-issue-4281-insufficient-storage]], [[s-issue-8322-dynamic-maxstore-shrinks]],
[[s-nats-server-jetstream-resources]], [[s-nats-server-leafnode-js-domains]],
[[s-nats-server-jetstream-log-warnings]].

**Pages created (7), all `wiki/gotchas/`:**

- [[jetstream-out-of-disk]] — the most-cited wanted gotcha in the wiki (linked from three pages).
  Three failures wear the same words and only one is a full disk.
- [[stream-directories-disappear]] — the corrected Q26.
- [[malformed-or-corrupt-message]] — Q39, with a confirmed fix (upgrade) and the reason a fresh volume
  re-corrupts.
- [[streams-not-visible-across-a-leafnode]] — Q42.
- [[stream-has-high-message-lag]] — Q62, including a table of the **thirteen** neighbouring JetStream
  warnings read from source.
- [[kv-watchers-stall-the-cluster]] — the real KV-watcher failure. **No confirmed fix**; the thread is
  unanswered and the page opens by saying so.
- [[nats-timeout]] — Q77. Both reports in the thread are **unresolved**, and the page's strongest
  cause comes from the source, not the thread.

**Four findings no public source states.**

1. **`10047` and `10028` compare reservations, never usage.** `reserveStreamResources` adds a stream's
   `max_bytes` and returns early when it is `<= 0`; `checkBytesLimits` then compares that sum against
   the server and account limits (`jetstream.go:2523–2553`, `:2686–2700`). A `/varz` dump in #4281
   reads **4 MB stored beside 35 GiB reserved**. `reserved_storage` is therefore the field that
   decides the error, and no docs page names it in that role.
2. **The 2.14.6 version floor for the dynamic-limit fix.** PR
   [#8503](https://github.com/nats-io/nats-server/pull/8503) merged 2026-08-24 adding
   `finalizeDynamicMaxStore`; the function is **absent from v2.14.5 and v2.14.4 and present in
   v2.14.6**, checked tag by tag. The release notes do not mention it.
3. **The server has an explicit guard against two identical JetStream domains** across a leafnode —
   it denies publishing `$JS.<domain>.API.>` outward, with a comment saying the guard "will only cover
   some forms of this issue" (`leafnode.go:2122–2131`). That, plus the `generateJSMappingTable`
   prefix, explains **every one** of gh#7834's four observations including (e), the one the reporter
   called "really weird".
4. **The JetStream API queue drains entirely when it fills** — `queue.drain()` discards every pending
   request with **no reply of any kind**, logging one rate-limited line and one advisory
   (`jetstream_api.go:876–890`). It is the sharpest server-side producer of a client-side
   `nats: timeout`, and nothing documents it.

**Docs issue #22 ★ — the highest-impact sweep so far.** The generated `reference/config/jetstream`
block states ten defaults; **four are wrong**. The headline is `max_file_store`, documented as
*"Defaults to up to 1TB if available"* when 1 TB is the `statfs`-failure fallback and the real default
is **75% of the space *free* under `store_dir`, recomputed at every startup**. That description is
what makes operators leave the key unset, and leaving it unset is what made servers fail to restart
for two years. Also wrong: `max_buffered_msgs` (`10000` vs **100000**), `max_outstanding_catchup`
(`32M` vs **64MB**), `info_queue_limit` (`100000` vs **whatever `request_queue_limit` is**). Two more
gaps recorded in the same entry: the maintainers' *"auto-sizing is for development and testing"*
appears **nowhere** in the 861-page tree even though a reporter asked directly, and
`max_file_store: 0` silently means *no storage*, not *unlimited*. Same generated-vs-hand-written split
as #1–3 and #19 — `learn/deployment/sizing-and-resources.md` has it right.

**Ripple (18 pages).** [[jetstream-sizing]] — step 4 rewritten with the restart hazard and the
maintainers' quote, two new rules of thumb, `reserved_storage` added to the measurement commands, and
*What runs out first* re-ranked to put the reservation ceiling above the disk;
[[defaults-and-limits]] — the whole JetStream block re-read from source, six values added, the two
75% figures separated (total RAM vs *free* disk); [[config-keys]] — four values corrected with the
docs' number kept alongside; [[error-codes]] — 10028 and 10047 added with the reservation rule;
[[monitoring-endpoints]] — a `reserved_storage` section; [[advisories]] — `SERVER.OUT_OF_STORAGE`
fires once and after the shutdown, and `API.LIMIT_REACHED`'s `Dropped` count;
[[raft-in-nats]] — `resetClusteredState`, its four refusals and the one case that deletes messages;
[[key-value]] — the multi-key watcher and the churn cost; [[ordered-consumer]];
[[install-nats-server]] — both halves of the `store_dir` / `max_file_store` line;
[[nats-server-2.14]] — the 2.14.6 fix. Link-level updates to [[stream]], [[replicas]], [[js-api]],
[[slow-consumer-detected]], [[jetstream-slows-as-consumers-grow]], [[disaster-recovery]],
[[upgrade-a-cluster]], [[backup-and-restore-jetstream]].

**Question bank: 98 rows → 101, 44 answered → 53; ★ 31 of 41.** Filled Q39, Q42, Q62, Q77; corrected
and filled Q26 and Q69; added **Q99–Q101** (the two out-of-disk issues and the KV-watcher scale
thread), all three answered by pages that state their own limits.

Wanted pages down from **8 to 6** — [[jetstream-out-of-disk]] written, `kv-watcher-misses-updates`
retired. `python3 tools/lint.py`: **180 pages, clean** (161 → 180: 7 wiki pages and 12 summaries) —
no broken links, no orphans, no frontmatter issues, none missing from the index.

---

## 2026-08-31 — plan step 6: topology

**Operation:** ingest ×12 (`inbox/plan-runbooks-and-security-2026-08-31.md`, step 6 — the last step).

**Sources.** The four the plan named — `raw/nats-docs/learn/topologies/leaf-nodes.md`,
`super-clusters.md`, `jetstream-in-a-cluster.md`, `putting-it-together.md` — plus **eight beyond the
list**, each forced by a bank row the docs do not answer: six GitHub discussions
(`gh-6328`, `gh-7438`, `gh-7881`, `gh-5941`, `gh-4823`, `gh-7494`, all new to `raw/gh-discussions/`),
`nats-server` v2.14.6 across eight files, and `natscli` v0.4.0's `cli/stream_command.go`. New raw
files: `raw/nats-server-src/topology-v2.14.6.md` and
`raw/github-repos/nats-io__natscli.stream-external-v0.4.0.md`; `raw/sources.md` updated for both
collections.

**Created (7 pages).** [[leafnode]] and [[gateway]] — the last two wanted **concepts**, each with the
full documented key set and the operator-facing failure modes; [[jetstream-domain]] — the
`$JS.<domain>.API.>` mapping table and the three outcomes across a leafnode, promoted out of
[[streams-not-visible-across-a-leafnode]] because three other pages now need it;
[[choosing-a-topology]] (**Q41**) — the four properties that decide route vs gateway vs leafnode, the
docs' ladder, and the three cases where the ladder is wrong; [[multi-region-jetstream]]
(`kind: pattern`, **Q45**); [[cross-domain-sourcing]] (`kind: runbook`, **Q43/Q89**); and two gotchas,
[[duplicate-messages-across-a-leafnode]] (**Q44**) and
[[supercluster-slows-when-a-remote-subscriber-joins]] (**Q46**).

**Five findings no source carries.** (1) **None of the three topology listener ports has a default**
— the reference states `6222`/`7422`/`7222`; omitting the cluster or leafnode port opens **no
listener at all**, and omitting `gateway.port` **stops the server from starting**. (2) The docs' own
composed topology config — `cluster` + `gateway` + `leafnodes` in one file, the example that
demonstrates the chapter's central idea — **does not start**, because a server with both a leafnode
listener and a gateway requires `system_account`. (3) **`nats-server -t` is a syntax check**: it
passes every `validateOptions` failure, including both of the above and the lame-duck ordering rule,
which makes a `-t`-only config gate not a gate. (4) **Geo-affinity is an exclusion list over
queue-group names**, not a routing preference — with any *plain* subscriber on the far side the
message crosses the gateway regardless, which is the unanswered gh#7494 exactly. (5) A
**leafnode user cannot carry permissions in config mode** (`parseLeafUsers` takes four keys), so the
accepted answer in gh#5941 has no implementation there — its unanswered follow-up was reproduced
locally, and the boundary that does exist is the account. Items 1–3 and 5 were **reproduced on the
v2.14.6 binary**, with the configs and output kept in the raw extract. (They were first run on
v2.14.5, the binary the machine had; `brew upgrade nats-server` and a re-run the same day confirmed
all five on **v2.14.6** — identical output, down to the configuration checksums `-t` prints — so the
observations and the source ranges now name the same release. Both runs are kept:
`raw/nats-server-src/topology-v2.14.6.md` and `topology-observed-v2.14.6.md`.)

**Docs issues #23–#26**, three of them ★. #23 the three phantom port defaults; #24 the composed
config that will not start, plus `-t`'s real boundary; #25 the fast-producer stall and **both**
counters that expose it (`/varz` `stalled_clients`, `/connz` `stalls`) absent from the whole 861-page
tree — the mechanism behind an unanswered performance thread; #26 four `leafnodes.remotes` keys
published with **empty descriptions**, including `deny_imports` and `deny_exports`, which are the two
keys the only public question on the subject asks about.

**Ripple (16 pages).** [[config-keys]] — a *three listener ports have no default* section, the
`cluster.port` row corrected, and the two option checks `-t` misses; [[defaults-and-limits]] — new
*Topology* and *Fast-producer stall* tables, 17 values read from source;
[[monitoring-endpoints]] — the two stall counters and the three `nats server report` commands, with
the `Account`/`Spoke` columns explained; [[reload-server-config]] — the dry-run section rewritten:
`-t` parses, `validateOptions` runs in `NewServer`, and three reproduced examples;
[[build-a-3-node-cluster]] — the three checks to add before a gateway or leafnode layer, and the
gateway-name log pair; [[mirrors-and-sources]] — the `external` block and the domain-vs-account table;
[[js-api-subjects]] — the full `$JS.<domain>.API.>` mapping; [[replicas]] and [[rebalance-streams]] —
`nats stream find --replicas=1` and `nats server check stream --peer-expect`;
[[nats-cli]] — a topology and cross-domain cheat-sheet block. Link-level updates to
[[streams-not-visible-across-a-leafnode]], [[account]], [[cross-account-sharing]], [[error-codes]],
[[slow-consumer-detected]].

**Question bank: 101 rows → 104, 53 answered → 62; ★ 34 of 42.** Filled **Q41, Q43, Q44, Q45, Q46,
Q48, Q89**; added **Q102–Q104**. **Q103 is deliberately unanswered** — whether a leaf region can
become the hub, or a cluster be converted into a leaf without losing data, was asked twice in gh#7438
and answered neither time; both new topology pages record the silence instead of guessing. Row 89's
"open on purpose" note was rewritten: the same-account two-domain case is now answered end to end,
the cross-account half stops where the sources stop, and that residual gap stays with row 51.

**Every ★ row in the plan's runbook, security and topology clusters is now answered** — the plan's
*Done when* condition. Wanted pages **6 → 4** (`leafnode` and `gateway` written; the remaining four
are `consumer-keeps-redelivering`, `filestore-layout`, `meta-layer`, `stream-leader-keeps-moving`).
`python3 tools/lint.py`: **200 pages, clean** (180 → 200: 7 wiki pages and 13 summaries) — no broken
links, no orphans, no frontmatter issues, none missing from the index.

## 2026-08-31 — drift plan step 1: `tools/check-defaults.py`, and the sweep it produced

**Operation:** tool, then *record a docs issue* — not an ingest. Working
`inbox/plan-drift-and-adrs-2026-08-31.md` step 1: sweep the **generated** config reference against
the server, mechanically, and verify every disagreement by hand before recording it.

**The tool.** `tools/check-defaults.py` takes `inbox/config-keys-table.md` (621 keys, **216 with a
stated default**) and a `nats-server` tag, downloads that tag's tarball into `.cache/` (git-ignored;
`raw/nats-server-src/` keeps only quoted ranges, so a whole tree does not belong there), and resolves
each documented default against the code that fills the option in. It walks from the `case "<key>"`
in the parse function that reads the key, to the field that case assigns, to a default site for that
field — through seven indexes over `server/**/*.go`: constants and package vars, guarded default
sites, use-site defaults, override defaults (`x := <default>` … `if opts.X > 0 { x = opts.X }`),
command-line flag defaults, struct-literal constructors, and the `case` blocks themselves. It reports
**how** each value was found (`assign`, `use-site`, `global`, `flag-default`, `literal`,
`const-name`, `zero-value`) and links the line, because those are not equally strong.

**Result on v2.14.6** (`inbox/check-defaults-v2.14.6.md`, registered in `wiki.json` as *Defaults
check*, 216 rows, filterable): **175 agree, 15 disagree, 26 unresolved.** The unresolved list is the
honest output — each row says what was found and where to look, and none of them was guessed at.

**It re-derived the four hand sweeps with no human input**: all nine `tls.timeout` keys at 2s and all
six `authorization.timeout` keys at 2s (docs issue #19), `jetstream.max_buffered_msgs` at 100000 and
`info_queue_limit` at `request_queue_limit` (#22). That is the check on the tool, not on the docs.

**Three new findings, each verified by hand and then run on the v2.14.6 binary** — evidence in
`raw/nats-server-src/defaults-observed-v2.14.6.md`:

- **#27 ★ leafnode compression defaults to `s2_auto`, not `accept`.** `opts.go:6082–6089` (listener)
  and `6099–6106` (every remote). `accept` is the *cluster* default, twenty lines earlier. Observed:
  a hub/leaf pair with nothing configured reports `"compression": "s2_uncompressed"` on `/leafz`; the
  same pair carrying the documented `accept` on both ends reports `"off"`.
- **#28 `mqtt.max_ack_pending` is 1024, not 100** — `mqttDefaultMaxAckPending`, `mqtt.go:151`, applied
  at three use sites. `mqtt.ack_wait`'s documented `30s` is right by the same mechanism.
- **#29 ★ `mqtt.port` has no default**; `mqtt { }` with no port starts no listener and logs nothing
  (`mqtt.go:689–694`, observed) — the fourth listener with a published default the server never
  applies, after #23's three.

**Ripple (5 pages).** New summary [[s-nats-server-defaults-sweep]]; [[config-keys]] — the MQTT
paragraph corrected (it had been repeating the docs' `1883` and `100`), a leafnode-compression note,
and *The three listener ports have no default* became *The listener ports have no default* with an
`mqtt.port` row; [[defaults-and-limits]] — six rows in *Topology*, and *How this was derived* now
names the sweep and its counts; [[leafnode]] — a *Compression is on by default* section with the
`/leafz` evidence and the config to set it explicitly; [[index]].

**Question bank: unchanged at 104 rows.** Nobody asks in public what a default is — they discover it
— so no row was invented to fit; the summary says so explicitly.

`python3 tools/lint.py`: **201 pages, clean.** `python3 tools/build-site.py`: 1141 TOC rows (925 →
1141, the new report).

## 2026-08-31 — drift plan step 2: `tools/check-staleness.py`, and the wiring that survives an update

**Operation:** tool. `inbox/plan-drift-and-adrs-2026-08-31.md` step 2: make a stale page findable by
running a script rather than by remembering. All 201 pages currently read `verified-on: 2026-08-31`;
93 carry `verified-against`, and nothing said which of them would start lying at the next release.

**The tool.** `tools/check-staleness.py` checks each page against **the authority that page names**,
not against one global version: `nats-server` from the newest non-prerelease tag in
`raw/release-notes/_tags-and-dates.md` (`--current` to override, `--fetch` to ask GitHub), and every
tool or client from `raw/github-repos/*.release.json` — the files `tools/fetch-repo-facts.py
--refresh` already maintains, so a client release is detected by the run that refreshes the entity
pages. A version stated as a **minor** is compared as a minor, so "since 2.11" does not rot when
2.14.6 ships; only a pinned patch is compared at patch level.

**What it deliberately does not flag.** A page that states none of the six things `CLAUDE.md`
requires a version for — a default, a limit, a config key, a CLI flag, an API subject, an error code
— is left alone: 17 pages, nearly all client and org entities, which do not rot that way. The one
exception is a page pinned to a **repo's own release**: there the version *is* the claim, so it is
checked whether or not it states any of the six. Both paths were tested by pretending a release had
moved: `nats-cli` (natscli v0.4.0) and `nats-go` (nats.go v1.53.1) both appear, the second with
"claims: none — the version is the claim".

**Today: nothing is stale.** `inbox/staleness.md` is empty in all three sections, which is the honest
result one release after every page was written. Simulated, the mechanism works: at a hypothetical
**2.14.7** it lists **46** pages; at **2.15.0**, **64** — the extra 18 being the pages pinned to the
minor `2.14`. Each row carries the page, what it was verified against, what is current, which of the
six claim kinds it makes, and the summary pages it was verified *from*, so re-verifying is a re-read
of one named source.

**Wiring.** `tools/lint.py` now ends with a staleness warning line — never an error, and guarded, so
lint is unchanged where the script is absent. `tools/lint.py` is a **shared** file from
`llm-wiki-starter`, and `tools/update-tools.sh` overwrites it, so the same guarded block was added to
`llm-wiki-starter/template/tools/lint.py`: the wiring now survives a tools update instead of being
silently wiped. Noticed while checking that: **the starter's `lint.py` is ahead of this wiki's** — it
also checks *citation drift* and *unlanded ripples*. Running `update-tools.sh` would bring both, and
would also update `build-site.py` and the theme; not done here, because it is a change to the viewer
as well as the linter and belongs in its own step.

**`CLAUDE.md` updated** — both new tools in the Map, and *Operation: lint* now says to run them.

`python3 tools/lint.py`: **201 pages, clean**, plus `staleness: 0 behind 2.14.6`.

## 2026-08-31 — drift plan step 3: the six ADRs an open `## To verify` was waiting for

**Operation:** ingest ×6, from `raw/adr/`. Plan step 3, taken "in the order the wiki needs them"
rather than in number order: the two that [[mirrors-and-sources]] named as its missing spec, then
the one [[disaster-recovery]] needed, then the three KV refinements.

**ADR-59 — Stream Sourcing and Mirroring** ([[s-adr-59-sourcing-and-mirroring]], *Implemented*,
documents behaviour up to 2.12.5). The authoritative spec the docs point at and the wiki had never
read. New to the wiki: the mirror restriction list (why `subject_delete_marker_ttl` on a mirror is
refused — markers would insert messages and break sequence alignment), the four-field duplicate rule
for source entries, the transform order, **cycle detection stopping at the account boundary**, error
codes **10029** and **10045** with their 30s consumer-create timeout, the `Nats-Stream-Source`
origin header, and `/jsz?direct-consumers=true` for the hidden replication consumers. Two values were
re-checked against v2.14.6 rather than taken from the ADR: both error codes (HTTP 500, description
`{err}` — the ADR's friendly labels are not the wire text) and the 10s inactive threshold
(`sourceHealthCheckInterval`, `stream.go:3121`).

**ADR-60 — reliable sourcing on WQ/Interest streams** ([[s-adr-60-reliable-sourcing]],
*Implemented*, **2.14**). What the release notes had only summarised: the durable replication
consumer is **visible** as `JS_MIRROR_<suffix>` / `JS_SRC_<suffix>` with `_nats.mirror.*` /
`_nats.src.*` metadata naming its owner, **its deletion is best-effort** so leftovers are the
operator's to remove, `AckFlowControl` is driven by `Nats-Last-Stream` / `Nats-Last-Consumer` and
forbids `AckWait`/`BackOff`, "durable sourcing" lets you pre-create the consumer (and pause it to
pause replication), and the whole path needs **API level 4 on the upstream** — verified in the source
(`Nats-Required-Api-Level: 4`, `stream.go:3679`), which the ADR does not mention.

**ADR-61 — unsafe meta group quorum rescue** ([[s-adr-61-meta-quorum-rescue]], *Implemented*, tagged
**2.15**, which exists only as a preview). Confirmed absent from v2.14.6: `$JS.API.META.RESCUE`,
`meta_rescue`, `quorum_needed` and `10224` appear nowhere in the source, and every page says so. The
part that matters **today** is the trap it describes — Raft computes quorum from the *configured*
peer set, so a server switched off without a peer-remove still counts, and one further failure wedges
the meta layer with no way to shrink it.

**ADR-48 — KV TTL** ([[s-adr-48-kv-ttl]], *Implemented*, 2.11): "Limit Markers" is one setting
writing two stream fields, the floor is **≥ 1 second** (the wiki said "longer than a second"),
enabling is one-way, and a TTL is accepted on `Create` and `Purge` **only** — never `Put`, because
an expiring current value could resurrect an older revision.

**ADR-57 — KV subject transforms** ([[s-adr-57-kv-subject-transforms]], *Proposed*): why a KV mirror
always carries `mirror_direct`, the generated `$KV.<src>.>` → `$KV.<dst>.>` transform, and that
supplying your own transform turns the automation off — which is how a **plain stream becomes a KV
source**.

**ADR-54 — KV codecs** ([[s-adr-54-kv-codecs]], *Proposed*, `orbit`): mostly out of scope as a client
API, ingested for the constraint behind it — **a KV key is a subject and nothing escapes it for
you** — and for the two operator-visible costs: encoded keys are what `nats kv ls` shows, and a value
codec makes the server blind to values.

**Ripple (13 pages).** [[mirrors-and-sources]] — two new sections (restrictions and duplicates; the
WorkQueue/Interest story before and after 2.14) plus a third on reading replication state, and its
`## To verify` closed; [[retention-policies]] — what the durable replication consumer looks like;
[[consumer]] — `AckFlowControl` and the consumers you did not create, and the reset payload
semantics; [[error-codes]] — `10029`, `10045`, and a note that `10224` does not exist yet;
[[js-api-subjects]] — `$JS.API.META.RESCUE` and the full reset semantics; [[monitoring-endpoints]] —
`/jsz?direct-consumers=true`; [[disaster-recovery]] — *When the meta group itself is what you lost*,
with the 2.14 remedy and the 2.15 one; [[raft-in-nats]] — *The configured peer set, not the live
one*; [[cross-domain-sourcing]] — cycle detection stops at the boundary, and the forgotten `$JS.FC.>`
import; [[nats-server-2.14]] — API level 4; [[advisories]] — the 2.15 `META_RESCUE` advisory;
[[key-value]] — three new sections (TTL rules, mirrors and sources of a bucket, keys are subjects)
and two `## To verify` items closed; [[message-ttl]] — the KV TTL rules and its ADR-48 item closed.

One command was corrected while writing: the meta peer removal is
`nats server cluster peer-remove <server>`, as [[nats-cli]] already recorded — not the `raft`
spelling first drafted.

**Question bank: 104 rows, 62 answered.** Q36 (no quorum, stalled cluster) gains
[[disaster-recovery]] alongside [[raft-in-nats]]. **No rows were added**: an ADR is a specification,
not someone asking a question in public, and the bank's rule is a real asker with a URL.

`inbox/adr-toc.md`: **14 of 54 ADRs ingested** (was 8); ★ rows read: 9 of 22.
`python3 tools/lint.py`: **207 pages, clean**, staleness 0.

## 2026-08-31 — drift plan step 4: the remaining ★ ADRs, triaged down to three

**Operation:** triage + ingest ×3 (`inbox/plan-drift-and-adrs-2026-08-31.md` step 4).
**Sources:** `raw/adr/ADR-10.md`, `raw/adr/ADR-35.md`, `raw/adr/ADR-40.md`; `nats-server` v2.14.6
source and **the v2.14.6 binary**; `helm/charts/nats/values.yaml` at chart release `nats-2.14.6`.

**The triage first, because it is most of the work.** Fifteen ★ rows in `inbox/adr-toc.md` had no
summary. The bank's own test — *if no question needs it, it does not belong here* — leaves **three**:
ADR-10 (Q27), ADR-35 (Q31), ADR-40 (Q67). The other twelve are recorded with a reason in the plan
file, not silently dropped. Two deserve naming: **ADR-4** looked relevant and is not — it specifies
the HPUB/HMSG wire format and client header semantics, and never defines the reserved `Nats-*`
headers an operator actually meets. **ADR-41** (message path tracing) is a genuinely strong 2.11
operator tool that no bank row asks for; it wants a scouted thread before a page, not an ingest now.

**ADR-10 — extended purge** ([[s-adr-10-extended-purge]]): purge is three operations behind one
subject — `filter`, `seq`, `keep`. Verified against v2.14.6, including the JSON/Go name mismatch
(`filter` ↔ `Subject`) and the server-side rejection of `seq`+`keep` together (`10003`).

**ADR-35 — filestore compression** ([[s-adr-35-filestore-compression]]): block-level S2, compressed
only once a block stops being the tail, checksum deliberately excluded, compress-then-encrypt. **The
ADR is wrong about one thing**, and it is the thing an operator hits.

**ADR-40 — the NATS connection** ([[s-adr-40-nats-connection]]): kept for the operator-facing parts —
the `INFO`/`CONNECT` handshake, TLS-first since 2.10.4, the reconnect algorithm and the client
defaults that decide what a failure looks like. Its *Servers discovery* section is a `TODO`, so the
answer had to come from the server.

**Three new pages.** [[stream-compression]] (concept) — what `compression: s2` does, and why setting
it on a live stream changes nothing until the store re-opens. [[maximum-messages-exceeded]] (gotcha) —
`10077` on publish, the three limit texts behind it, and **the server log's complete silence**;
four ways out, ranked. [[how-clients-reach-a-cluster]] (pattern) — seed URLs versus advertised
`connect_urls`, the three designs, and the Kubernetes case end to end.

**Everything runnable was run**, on the v2.14.6 binary with nats CLI 0.4.0, recorded verbatim in
`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`:

- a `compression` change on a live stream — the block sealed *after* the edit is 31020 bytes and
  uncompressed; after a restart the same content seals at 790 bytes with a `cmp` header;
- a full `DiscardNew` stream — the `PubAck` error verbatim, `grep -ic 'failed to store' server.log`
  → `0`, and `--keep=1` leaving the sequence numbers untouched;
- the `INFO` line off the client port on a standalone server, a 2-node and a 3-node cluster, with
  `cluster { no_advertise }` and with `client_advertise` — which is how the discovery rules on
  [[how-clients-reach-a-cluster]] were derived, since no public source states them.

A second extract from the Helm chart was taken for the same page
(`raw/github-repos/nats-io__k8s.values-advertise-nats-2.14.6.md`): **`config.cluster.noAdvertise:
true`** is the chart's default, and its comment — "If clients are behind a load balancer it is best
to leave this as is" — is the closest thing to an official answer to Q67 that exists.

**Ripple (9 pages, plus the Helm summary).** [[stream]] — the compression paragraph now says the live-edit finding and links
the concept; [[retention-policies]] — a new section on what `discard: new` does at the limit and the
three purge shapes; [[jetstream-sizing]] — *Compression changes the disk term, and nothing else*,
including that it does **not** buy room against the account quota or the `max_bytes` reservation;
[[js-api-subjects]] — the purge request body; [[error-codes]] — `10077`, `10109`, `10110`, and why
`10077` never appears in a log; [[tls-in-nats]] — TLS-first since 2.10.4 and the client half;
[[build-a-3-node-cluster]] — read `connect_urls` from where the clients live;
[[nats-helm-charts]] — the chart's `noAdvertise` default and the ClusterIP Service;
[[jetstream-out-of-disk]] — a triage row separating `10077` from `10047`.

**Docs issues #30, #31, #32.** Two are **ADR** errors rather than doc-page errors — the first time
this report has gone that way twice in one step:

- **#30** — ADR-35's "newly minted blocks will use the newly selected compression algorithm" is false
  on a live stream; `fs.fcfg.Compression` is written once at store construction. Verified in source
  *and* by running it. `learn/jetstream/policies.md` states the real behaviour, so here **the docs
  are right and the ADR is wrong**.
- **#31** — ADR-40 is *Implemented* with a `TODO` where server discovery should be, a truncated
  sentence, and `**default: 3 / none` for max reconnects.
- **#32** — every `unsigned 64 bit integer` in the generated JetStream reference publishes
  `Maximum: 18446744073709552000`, which is 385 more than a uint64 holds. **All 11 pages** that state
  the bound carry it; the correct value appears nowhere in the 861-page tree.

**Question bank: 104 rows, 65 answered** (was 62); ★ unchanged at 34 of 42 — none of Q27, Q31, Q67
is starred. **No rows added**: an ADR is a specification, not someone asking in public.

`inbox/adr-toc.md`: **17 of 54 ADRs ingested** (was 14); **★ rows read: 10 of 22** (was 7 — the
previous entry's "9 of 22" counted the step-3 ingests, three of which are not ★ rows).

**Housekeeping:** `tools/lint.py` arrived from `llm-wiki-starter` with two new checks (citation drift
and unlanded ripples) part-way through this step. Drift on the seven pages this step already had open
was fixed by unioning the two lists, taking the wiki from 32 drifting pages to 25; the remaining 25
are pre-existing and untouched.

`python3 tools/lint.py`: **213 pages, clean** — no broken links, no orphans, no frontmatter issues,
nothing missing from the index; staleness 0.

## 2026-08-31 — drift plan step 5: the filestore, read and then measured

**Operation:** ingest (`inbox/plan-drift-and-adrs-2026-08-31.md` step 5 — the last step).
**Sources:** `nats-server` v2.14.6 `server/filestore.go`, `server/stream.go`, `server/memstore.go`
(ranges in `raw/nats-server-src/filestore-v2.14.6.md`) **and eleven experiments run on the v2.14.6
binary** with **nats CLI 0.4.0** (`raw/nats-server-src/filestore-observed-v2.14.6.md`).

The plan said this step was **"a `filestore-layout` internals page or nothing"** — write it, then
decide whether Q1 and Q2 could be answered *honestly*. They can, and the arithmetic closes.

**Created:** [[filestore-layout]] (internals) · [[s-nats-server-filestore-layout]] (summary).

**What the source gives.** A stored message costs `30 + len(subject)` bytes beyond payload, plus
`4 + len(headers)` when headers are present — a 22-byte record header and an 8-byte highwayhash,
`emptyRecordLen` (`filestore.go:1119–1121`, `fileStoreMsgSizeRaw` at `filestore.go:9821–9828`). That
figure is *also* what `nats stream info` reports (`updateAccounting`, `filestore.go:7696–7700`), so
`max_bytes`, `/jsz storage` and an account's `MaxStore` are all counted in record bytes and **payload
bytes are reported nowhere**. A memory stream uses a different formula entirely — `+16` and no
header-length field (`memstore.go:2334–2336`) — so the two `bytes` figures are not comparable.

**What only running it gives.** Reading settles arithmetic; it does not settle what a volume holds.
Eleven runs, all on the same v2.14.6 binary the pages cite:

- A block file is **exactly** the sum of its record lengths — 10,000 × 134 B produced a 1,340,000-byte
  `1.blk`, with no file header and no padding. The first record was decoded byte-for-byte out of the
  file and matches the format comment at `filestore.go:7502–7506`.
- **A delete makes the file bigger.** Five `nats stream rmm` dropped the reported bytes by 670 and
  **grew** `1.blk` by 150 — the dead records stay, and each delete appends a 30-byte tombstone.
- **A purge frees the disk at once**: 1,340,150 → 30 bytes, plus a forced `index.db`.
- The block size is picked for the operator and clamps to exactly **32,000 / 4MB / 8MB**; confirmed by
  watching where blocks roll on **seven** stream shapes. A stream with `max_bytes: 1MB` gets a **4MB**
  block, and **every KV bucket** gets 4MB via `defaultKVBlockSize`.
- **The last message block is never compacted** — `!isLastBlock` (`filestore.go:6151`) and `mb != lmb`
  under `// Do not compact last mb.` (`filestore.go:8037–8039`). An idle stream reporting 133,000
  bytes held **1,125,712** on disk — **8.47×** — and stayed there across a full `sync_interval` **and**
  a restart. A busy stream's overshoot is transient: one that measured 4.44× converged to 1.00 after
  a single sync pass.
- `index.db` costs **`len(subject) + 4` per subject**, landing on 4.0 on two independent streams
  (20,000 and 40,000 subjects).
- **Recovery is the honest negative.** 279,653 messages recovered in **22.1 ms** with `index.db` and
  **24.6 ms** without it. No measurable difference at this size; recorded so that nobody derives a
  claim about the tens-of-millions case from a 39 MB lab.

**Rippled (8 pages):** [[jetstream-sizing]] — Step 1 rewritten with the record formula and a new
**Step 1b** for physical slack (`stream_bytes × 1.1 + 8MB per stream`), the worked example redone
(96.6 GiB of payload is **101.9 GiB** of records, and the un-tiered R3 quota 305 GiB not 290), five
new rules of thumb, two new pitfalls, and Q2 struck from *What is still unknown*, leaving **IOPS as
the only unsourced term**; [[stream]] — what the reported `bytes` counts and the memory-store
difference; [[key-value]] — a bucket's 4MB blocks and its per-key `index.db` cost;
[[stream-compression]] — what the two numbers in its own `du` recipe actually are, and that an
uncompressed stream is **not** a 1.00 baseline; [[jetstream-out-of-disk]] — the volume filling while
every JetStream number says there is room; [[defaults-and-limits]] — a new *filestore's own
constants* table, 16 rows; [[monitoring-endpoints]] — `storage` is logical, and the three figures to
watch together; [[consumer]] — `o.dat` measured against `max_ack_pending`, not stream size.

**Docs issue #33** (`missing`, ★ high) — and it is the one with the most operational bite so far.
The docs' sizing chapter says *"Pin `max_file_store` to what the volume can actually hold"* and then
sets `10GB` on a 10 GiB volume. `max_file_store` bounds the **logical** figure, so that configuration
does not protect the volume. Observed on a second server deliberately set to `max_file_store: 4MB`:
`/jsz` reported **133,000 bytes used of 4,194,304** while the store directory held **3,786,236** —
3% by the server's accounting, 90% of the ceiling in reality, with nothing logged. The
per-message record overhead is likewise stated nowhere: a grep of all 861 pages for `emptyRecordLen`,
`index.db`, "per-message overhead", "storage overhead" and "bytes per message" returns **one** hit,
`learn/object-store/chunking.md`, which mentions the idea without a number. Neighbours swept: **all
nine** pages in the tree that state a JetStream storage number, and none says the figure is logical.

**Question bank: 104 rows, 67 answered** (was 65); **★ 36 of 42** (was 34). **Q1** and **Q2** — the
two oldest ★ rows in the bank and the last open ones in the *jetstream sizing* cluster — are now
filled, and **Q72** (why deleting keys does not reclaim disk in a bucket) gains the block mechanism
behind it. **Q9** is deliberately left open: the page gives the *storage* cost of a high-cardinality
subject space and the 1,000,000-subject `index.db` cut-off, not the latency figure the question asks
for. **No rows added** — a source read and a binary run reveal facts, not people asking questions;
the disk-versus-reported gap is worth a scout for a public thread before it becomes a row.

**Housekeeping:** citation drift unioned on the three touched pages that had it
([[consumer]], [[defaults-and-limits]], [[monitoring-endpoints]]), taking the wiki from 25 drifting
pages to **22**; the other 22 are pre-existing and untouched. Two `(unverified)` items were added
deliberately on [[filestore-layout]] and are listed under its `## To verify`: whether an encrypted
stream that sets `max_bytes` bypasses the 2MB block cap, and what `thw.db` / `sched.db` / the
subject-delete-marker state cost.

`python3 tools/lint.py`: **215 pages, clean** — no broken links, no orphans, no frontmatter issues,
nothing missing from the index; staleness 0.

## 2026-08-31 — next plan proposed: the last ★ rows, and the chapters nobody has read

**Operation:** plan (proposal only — no page changed).
**Written:** `inbox/plan-the-unread-chapters-2026-08-31.md`, six steps, all `status: open`.

`inbox/plan-drift-and-adrs-2026-08-31.md` is closed and its result line rewritten. It had proposed
`meta-layer` next; an audit of the bank against the docs tree before writing the new plan changed the
answer, and the audit itself is the finding worth recording:

- **Two ★ rows are answered and were never marked.** **Q51** (share a stream or KV bucket between
  accounts) is answered in full on [[cross-account-sharing]] — both routes, cited, with what no public
  source states named as such. **Q58** (find which consumer the server flagged as slow) is answered on
  [[slow-consumer-detected]] with `/connz?sort=pending` and the docs' own wording. The scoreboard has
  been under-reporting, and the fix is a re-read, not an ingest.
- **The docs tree is 861 pages and roughly 60 have been read.** The production chapters are done —
  `security` **9/9**, `topologies` **6/7**, `deployment` **5/6**, `clustering` **5/6**,
  `backup-recovery` **4/5** — but the **JetStream chapter, this wiki's declared centre of gravity, is
  9 of 22**, and `key-value` **0/6**, `object-store` **0/6**, `mqtt` **0/5**, `websocket` **0/5**,
  `monitoring` **2/6**. Coverage was computed by matching every `learn/**.md` against the
  `source-path` / `source-url` of all 47 `s-docs-*` summaries, not by memory.
- **13 of the 31 open non-★ rows are answered by pages already in `raw/`.** Q23, Q24, Q29, Q30, Q60,
  Q61, Q73, Q74, Q75, Q76, Q78, Q79, Q80, Q81 — the highest ratio of *answers already fetched* to
  *work required* anywhere in the repo. `mqtt/qos-sessions-and-retained.md` and
  `mqtt/auth-and-clustering.md` are named for Q80 and Q81; `websocket/tls-and-proxies.md` for Q79;
  `object-store/watching-and-listing.md` for Q75.
- **`interop` is a declared area with one page and zero summaries.** MQTT and WebSocket exist here
  only as config keys — including the two MQTT defaults corrected as docs issues **#28** and **#29**.
  A wiki that can tell you a default is wrong but not what the feature does has the ordering backwards.
- **`meta-layer` keeps.** `server/jetstream_cluster.go` is a large read and the two rows it serves
  (Q37 quorum loss, Q40 evicting a sick node) are **not ★**. It is the plan after this one, and it
  will be better for having the monitoring chapter's `/healthz` and advisory material read first.

**One step is a re-run, not a read.** Q97 — *does a config reload actually pick up a renewed
certificate file?* — is a behavioural claim that [[rotate-tls-certificates]] currently takes from the
docs, with its own `## To verify` admitting the server was never asked. Step 1 settles it on the
v2.14.6 binary and records the configs and output in `raw/`, the way step 5 of the last plan did.

**Target:** 104 rows, **67 answered → 83–86**, **★ 36 → 40–42 of 42**. Three of the 19 rows the plan
names are flagged doubtful up front (Q78 is a sizing number the docs rarely give; Q65 and Q103 depend
on a scout finding a public thread), and a row closed with a written *"nobody has published this"* is
recorded as work done rather than as a miss.

## 2026-08-31 — lint gains two checks from `llm-wiki-starter`, and the debt they found

**Operation:** lint (mechanical half) + plan.
**Tools:** `tools/lint.py` was already the starter's current version — commits `7a50866` (citation
drift, unlanded ripples) and `c5d3508` (optional staleness warning) had arrived via
`update-tools.sh`. Nothing in this repo told the maintainer what to do with their output; that is
what this entry fixes.

**Before → after:**

| check | before | after |
|---|---:|---:|
| citation drift (a defect) | **22 pages / 25 rows** | **0** |
| unlanded ripples (a review queue) | **252 claims / 63 pages** | 252 — the queue, now planned |
| unverified markers | 9 across 6 pages | 9 |
| broken links · orphans · frontmatter · index | 0 | 0 |
| staleness | 0 behind 2.14.6, 1 authority unknown | unchanged |

**Citation drift, all 25 rows reconciled to the union — verified per row, not swept.** 17 rows
already cited the summary inline in the page body; 8 named it in `## Sources` only, which
`CLAUDE.md` permits, with the frontmatter half missing. The two least obvious were read before being
added: [[config-keys]] ← `s-docs-replication-and-r3` (the page's R3 storage-accounting claim traces
to it) and [[cross-account-sharing]] ← `s-docs-mirrors-and-sources` (the page's whole "mirror or
source the stream" route). 32 pages touched; no `updated:` bump needed — all already read
`2026-08-31`.

**`wiki.json`** now states the four lint keys explicitly (`source_type`, `touched_heading`,
`sources_key`, `sources_heading`). They already resolved correctly by default; stating them stops a
later folder rename from switching a check off in silence.

**`CLAUDE.md`** gains **`## Operation: consolidate`** — the counterweight to ingest — and
*Operation: lint* now names both new checks and says which is a defect and which is a queue. The
operation is adapted from the starter's template to this wiki: its six "shapes to look for" are
recast for NATS (a runbook missing a `###` surface; a forward reference never landed;
`raw/nats-server-src/` evidence on the internals page but not on the gotcha it explains; a page with
no earliest version; release notes as a source about the *concept*, not only the release entity; an
entity page without the behaviours that bite), and it carries two rules the sibling wiki's experience
argues for: never manufacture a section to absorb a citation, and **name every strike from a
`## Pages touched` list in this log**, so a falling count can be told apart from a shortened list.

**What the measurement says.** 116 summaries against a 63-page reader layer — **1.84 per page**, not
the 6:1 that drove the sibling wiki's consolidation. The thinnest reader page is 652 words
([[ordered-consumer]]); there are no stubs. So the debt here is not under-synthesis in general, it is
252 specific ripples that stopped at the summary layer, concentrated in ten pages that hold 127 of
them — [[account]] (21), [[stream]] (16), [[replicas]] (15), [[config-keys]] (14),
[[error-codes]] (11), [[raft-in-nats]] (11), [[nats-cli]] (11), [[install-nats-server]] (10),
[[monitoring-endpoints]] (9), [[mirrors-and-sources]] (9).

**Four pairs sampled before planning, because the count would be dishonest without knowing its
shape:** [[ack-and-redelivery]] ← `s-docs-worker-pool` and [[error-codes]] ←
`s-issue-4281-insufficient-storage` are **citation-only** (the material is on the page; `10028` and
`10047` are already in the table), [[account]] ← `s-gh-7854-jwt-push-timeout` is a **genuine gap**
(`$SYS.REQ.CLAIMS.UPDATE` and the push timeout appear nowhere on the page), and [[nats-cli]] ←
`s-gh-6605-which-consumer-is-slow` was inconclusive from grep. The list cannot be worked down
mechanically.

**Upstream: `llm-wiki-starter/template/tools/lint.py` patched, and pulled back here.** Both sections
were located with a plain substring split, which fails two ways: an earlier lookalike heading matches
first (this wiki's [[message-ttl]] has `## Sources and mirrors`), and the unbounded read to end of
file swallows what follows — 8 pages here carry a `## To verify` *after* `## Sources`, whose inline
citations were counting as though they were in the list. Both checks now share one `section()` helper
that anchors the heading to its own line and stops at the next heading of the same or higher level.
It tolerates a configured heading with or without its `#` markers, which is not cosmetic: the sibling
wiki runs on the older default `"Pages touched"`, and a strictly anchored match would have reported
zero unlanded ripples there without saying anything. `tools/selftest.sh` gained a fixture that fails
on the old code — a decoy summary cited in a `## Sources and notes` section before the list and a
`## To verify` after it — so `citation drift: 0` only holds when both halves are right. This wiki's
counts are unchanged by the patch and `--strict` still passes.

**The patch immediately found a row on the sibling wiki.** Against `../chiptune-wiki` (676 pages) it
reports **1 citation drift the old check could not see**: `entities/hermit` lists `s-duet-readme` in
`sources:` but not in its `## Sources` section. It was invisible because that page has a
`## Sources released` heading at line 28, and the split from there to end of file picked up the
inline `(source: s-duet-readme)` citation on line 30. Unlanded ripples there are unchanged at 80/59 —
worth re-running that wiki's own lint after `update-tools.sh`.

**Plan written:** `inbox/plan-consolidation-2026-08-31.md`, eight steps, step 1 done. It is the
unlanded queue, ordered by count and grouped so that a summary naming five pages is read once —
`s-docs-security-checklist` alone names five.

## 2026-08-31 — consolidation step 4: the reference layer, landed

**Operation:** consolidate (plan `inbox/plan-consolidation-2026-08-31.md`, step 4).
**Before → after:** unlanded ripples **252 across 63 pages → 206 across 57**; citation drift **0 → 0**;
`--strict` passes; question bank **67 → 68 answered, ★ 36 → 37**. No `verified-against` moved — every
touched page already read `2.14`/`2.14.6` on `2026-08-31`.

**Pages updated:** [[error-codes]] (11 claims) · [[monitoring-endpoints]] (9) · [[js-api-subjects]] (6) ·
[[config-keys]] (14) · [[defaults-and-limits]] (4) · [[advisories]] (2 — not in the step, taken because
it finished the layer). **No reference page carries an unlanded ripple now.**

**The mix, which is the finding worth carrying into the rest of the plan.** Of 46 pairs, **33 were
citation-only** (the material had landed; only the record was missing), **10 were real additions**, and
**3 were neither**. Grep settled the citation-only ones in bulk: every `10xxx` code named in all 11
`error-codes` summaries was already in the table, and all 14 `config-keys` summaries named only keys
the generated table already carries. So the queue is roughly **7 parts bookkeeping to 2 parts writing**
on reference pages — the pages where a table can be diffed. Expect a worse ratio on concepts.

**Every real addition was a behaviour, not a table row** — which is the shape a reference page's own
derivation script cannot produce:

- **`/healthz`** — the Kubernetes probe mapping the Helm chart renders (`startupProbe` unqualified with
  `failureThreshold: 90`, `readinessProbe` `?js-server-only=true`, `livenessProbe`
  `?js-enabled-only=true`), and why the gradient runs that way: liveness must ask the least or a
  slow-recovering stream restarts the pod recovering it. Plus the failure text a lagging KV watcher
  produces, `Healthcheck failed: "JetStream consumer … is not current"`, observed on **2.10.12**.
- **`/routez`** — the check means nothing on one node and nothing before every node is up; a partial
  split-brain shows as *unequal counts with every node still in the list*, confirmed on **2.11.7**.
- **`/jsz`** — **`active` is the JSON name for what the CLI prints as `Last Seen`**.
- **Endpoint → metric**: the names follow the wire fields, `num_pending` → `nats_consumer_num_pending`,
  `jetstream_` renamed to `nats_` by `-prefix nats`.
- **`$JS.API.CONSUMER.DURABLE.CREATE.<stream>.<consumer>`** — the *legacy* subject, added precisely
  because it is gone: an ACL written against it catches only clients that still send it, since modern
  clients put the durable name in the body of `$JS.API.CONSUMER.CREATE`. Also the coarse `$JS.API.>`
  grant in its three roles (permission, account export, supercluster export) and the three export
  **types** cross-account replication needs, where the wrong type fails **silently**.
- **`no_auth_user` cannot be introduced or changed by a reload** — `config reload not supported for
  NoAuthUser`, the old config stays active, and `-t` does not catch it. That section is now *three*
  option checks, not two.
- **`leafnodes { authorization { users } }` is a trimmed parser** — `user`, `pass`, `account`,
  `proxy_required` only; `permissions` there is a **parse error** (`unknown field "permissions"`), so
  a leaf cannot be restricted that way in config mode at all.
- **`max_file_store` is recomputed at every start**, so a server whose disk filled comes back with a
  ceiling below the streams it already holds.
- **Failures that carry no `err_code` at all** — a cross-account config error stops the server with a
  file and line, and `No responders are available` is a core status, not a JetStream error.
- **Advisories are unreachable without a system-account user** — declaring your own `accounts` block
  without a `SYS` account silently takes the event surface away, `nats server account info` included.

**Three strikes from `## Pages touched`**, recorded here as the rule requires, so the falling count is
not mistaken for work:

| summary | struck from | why |
|---|---|---|
| [[s-docs-authentication-basics]] | `config-keys` | its config-shaped claim is a CLI behaviour — `nats server passwd` refusing passwords under 10 characters — not a key |
| [[s-docs-your-first-cluster]] | `config-keys` | every key it uses is already in the generated table; the worked config it shows is material for [[build-a-3-node-cluster]], not for a key reference |
| [[s-gh-7494-supercluster-degradation]] | `config-keys` | its one identifier, `stalled_clients`, is a `/varz` field, not a config key |

**One scope bug caught mid-step.** A `$JS.FC.>` row was added to [[js-api-subjects]] before noticing
that page's own intro excludes the `$JS.FC` space. The row was removed and the intro now names the one
exception — the export-type table — rather than the page quietly contradicting itself. A reminder that
landing a ripple can introduce a wiki bug, so the page's stated scope is worth re-reading before adding
to it.

**Question bank:** **Q58** (which consumer the server flagged as slow) filled with
[[slow-consumer-detected]] · [[monitoring-endpoints]] — the audit in
`inbox/plan-the-unread-chapters-2026-08-31.md` had spotted it as answered-but-unmarked and this step
confirmed it. **Q47** gains [[monitoring-endpoints]] for the `/routez` check, **Q100** gains
[[config-keys]] for the recomputed ceiling.

## 2026-08-31 — unread-chapters plan step 1: the ★ rows, closed by running and by scouting

**Operation:** plan step (`inbox/plan-the-unread-chapters-2026-08-31.md`, step 1) — one *ingest*, one
run on the binary, two scouts and an audit. Not a consolidation.

**Before → after:** pages **215 → 219**; unlanded ripples **206 across 57 pages → 206 across 57**;
citation drift **0 → 0**; unverified markers 9 across 6 pages → 9 across 6; staleness 0; lint clean.
Question bank **68 → 72 answered**, ★ **37 → 41 of 42**. `inbox/docs-issues.md` **33 → 34**.

**Rows closed:** **Q51** ([[cross-account-sharing]] · [[mirrors-and-sources]] — audit only, the page
already answered it), **Q97** ([[rotate-tls-certificates]] · [[reload-server-config]]), **Q65**
([[kubernetes-storage]], a new page), **Q103** (closed as *no public answer*, stated on
[[choosing-a-topology]]). **Q58** was already filled by consolidation step 4, so the bank started at
68, not the 67 the plan file predicted. The one ★ row still open is **Q23**, which is step 2's.

**Pages created:** [[kubernetes-storage]] (operation, `kind: pattern`) ·
[[s-nats-server-tls-reload]] · [[s-gh-7749-hostpath-jetstream]] ·
[[s-k8s-760-jetstream-pvc-per-replica]].
**Pages updated:** [[rotate-tls-certificates]] · [[reload-server-config]] · [[tls-in-nats]] ·
[[leafnode]] · [[monitoring-endpoints]] · [[jetstream-sizing]] · [[jetstream-out-of-disk]] ·
[[stream-directories-disappear]] · [[replicas]] · [[choosing-a-topology]] ·
[[multi-region-jetstream]] · [[s-nats-helm-chart-values-2.14.6]] (extended with a third extract) ·
[[index]].

**New in `raw/`:** `nats-server-src/tls-reload-observed-v2.14.6.md` (the eight experiments and two
controls), `gh-discussions/gh-7749.md`, `gh-discussions/k8s-760.md` — **the first file here from a
`nats-io` repo other than `nats-server`**, so the naming rule is now recorded in `raw/sources.md`:
`gh-<n>.md` is a `nats-server` discussion, anything else carries its repo in the slug — and
`github-repos/nats-io__k8s.values-jetstream-storage-nats-2.14.6.md`.

### Q97 — the reload works; nothing tells you so

Eight experiments and two controls on the **v2.14.6** binary with **nats CLI 0.4.0**, the binary
matching every `verified-against` on the pages touched. A client listener's `cert_file` replaced in
place moved `/varz`'s `tls_cert_not_after` from `2026-09-30T20:18:19Z` to `2029-02-16T20:18:19Z`; a
fresh **keypair** worked the same way; `nats account tls` confirmed it from the client side. So the
`## To verify` item that had stood since [[s-gh-7684-certificate-expiry]] was ingested is settled in
the affirmative, and the incident there did **not** reproduce.

The findings worth having are the three negative ones, all of which explain how a working reload can
look broken:

- **The log lies by being identical.** A reload that changed nothing prints the same four `Reloaded:`
  lines, `Reloaded: tls = enabled` included. The no-op control was run first for this reason.
- **`config_digest` never moves**, because it digests the configuration *text* and a rotation changes
  only the file behind the path. A monitoring check on the digest cannot see a rotation at all.
- **`nats-server --signal reload` exits 0 even when the server refused the reload.** A mismatched
  certificate/key pair and a missing certificate file both produce
  `[ERR] Failed to reload server configuration: …` in the server log and **exit 0** at the caller,
  with the old certificate left live and clients unaffected. `nats-server -t` catches both and exits
  1.

The leafnode half was worth its extra hour: the generated reference warns on six keys under
`leafnodes { remotes[].tls }` that *"On 2.11/2.12 the reload succeeds but the old certificate keeps
being used"*, and never says whether that still holds. Tested with a hub accepting exactly one
certificate identity (`verify_and_map` plus `authorization { users: [ { user: "CN=leaf-A" } ] }`),
**`cert_file`, `key_file` and `ca_file` all reload at 2.14.6** — with the file replaced in place *and*
with the path changed in the config. Both controls clean. That is docs issue **#34**;
`cipher_suites`, `curve_preferences` and `insecure` were not tested and the page says so.

**A methodological note worth keeping.** The first version of the leafnode test used a certificate
signed by a CA the hub did not trust and expected a rejection to prove the swap. The hub instead
logged `tls: client didn't provide a certificate` — Go's TLS client filters its own certificates
against the acceptable-CA list in the server's `CertificateRequest`, so an unknown-CA certificate is
never offered. The result still pointed the right way, but it could not distinguish "rejected" from
"not sent". Keeping both certificates under one CA and telling them apart by subject is the design
that answers the question, and the failed attempt is recorded in `raw/` so it is not repeated.

Two side observations, both landed: `verify_and_map` matches the certificate's **RFC 2253 DN**, so
`user: "CN=leaf-A"` works and `user: "leaf-A"` produces
`User in cert ["CN=leaf-A"], not found` ([[tls-in-nats]] already had the mapping order and now has
the observation); and **`nats server check` has no certificate-expiry check** at natscli v0.4.0 —
`server check credential` checks a user JWT, not an X.509 certificate — which settles the second
`## To verify` item on [[rotate-tls-certificates]]. Both `## To verify` items on that page are now a
*Settled by running it* section, with one new item taking their place.

### Q65 — the scout found two threads, and the chart contradicted one of them

`gh#7749` asks the question in exactly the bank's words and was answered **five months later by a
community member**; there is no chosen answer and **no maintainer ever replied**. That provenance is
on the summary and on the page, because the answer is used. `nats-io/k8s#760` supplies the reasoning
that makes it trustworthy — a chart maintainer: *"JetStream needs fast block based storage. Should
not use NFS or other slow file based storage with it. Most fast block based storage in the cloud only
works with a single host as a writer."* That is the only public maintainer statement this wiki has
found ruling out network file storage for JetStream.

Checking the community answer's YAML against the chart at `nats-2.14.6` was the right instinct: its
key path `nats.jetstream.fileStorage.*` is an older generation's, and the chart uses
`config.jetstream.fileStore.*`. The page states the real keys and warns about the drift.
A `grep` for `hostPath` and `emptyDir` across all 741 lines of `values.yaml` returns **nothing** —
the chart does not offer the choice the question is about, which is itself the answer.

**And it found a live one for docs issue #33.** `helm/charts/nats/files/config/jetstream.yaml`
renders `max_file_store: << {{ .pvc.size }} >>` when `fileStore.maxSize` is unset, and `pvc.size`
defaults to `10Gi`. So the *stock* JetStream install runs a 10Gi ceiling on a 10Gi volume — precisely
the arrangement #33 shows to be unsafe, since every JetStream storage figure is logical while the
directory is larger ([[filestore-layout]]). Recorded inside #33 rather than as a new row, because it
is a chart default rather than a doc sentence, but it changes the fix: "set `fileStore.maxSize`", not
just "pin `max_file_store`". [[jetstream-out-of-disk]] and [[jetstream-sizing]] now say so.

### Q103 — a dead end, stated once

The two questions in gh#7438 (2025-10-20) were never answered by anyone. Searched again on
2026-08-31 across the docs tree, the ADRs, GitHub discussions and issues, and the public blogs:
nothing states a procedure, states that one exists, or states that one does not. Rather than leave
three passages hedging the same unknown, the finding now lives in one place — *Choosing the hub is a
one-way decision* on [[choosing-a-topology]], which also says what the neighbouring published facts
imply and why assembling them into a runbook would be invention — and [[multi-region-jetstream]]
points at it, losing one hedge in *When not to use it* and one `## To verify` bullet. The bank row
carries a new **`no-public-answer`** flag, added to the legend, and names the page in bold.

**Scouted, not ingested:** `nats-io/nats-server` issue **#6921** (open, 2025-05-23, *defect*,
assigned to @neilalexander) — explicit acks stalling on a stream with `max_msgs_per_subject: 5` under
a `LastPerSubject` deliver policy, ack floor frozen, cleared by `AckPolicy: None` or
`DeliverPolicy: All`. Recorded in the plan file as the best candidate yet for the wanted
`consumer-keeps-redelivering` page.

## 2026-08-31 — unread-chapters plan step 2: the JetStream chapter's unread half

**Operation:** ingest ×7 (`inbox/plan-the-unread-chapters-2026-08-31.md`, step 2) —
`learn/jetstream/`'s `publishing`, `advanced-publishing`, `shaping-the-stream`,
`altering-stream-state`, `filtering`, `reading-back` and `subject-mapping`, all already mirrored in
`raw/nats-docs/`.

**Before → after:** pages **219 → 228**; unlanded ripples **206 across 57 pages → 206 across 57**;
citation drift **0 → 0**; lint clean. Question bank **72 → 74 answered**, **★ 41 → 42 of 42 — every
starred row is now answered.** `inbox/docs-issues.md` stays at 34 rows; **#5 was corrected**.

**Rows closed:** **Q23** (★, exactly-once and the dedup window) → [[publishing]] · [[stream]];
**Q24** (what ordering JetStream guarantees, and per what) → [[publishing]] · [[stream]] ·
[[subject-transforms]].

**Pages created:** [[publishing]] · [[subject-transforms]] · [[s-docs-publishing]] ·
[[s-docs-advanced-publishing]] · [[s-docs-shaping-the-stream]] · [[s-docs-altering-stream-state]] ·
[[s-docs-subject-mapping]] · [[s-docs-reading-back]] · [[s-docs-filtering]].
**Pages updated:** [[stream]] · [[consumer]] · [[retention-policies]] · [[ordered-consumer]] ·
[[priority-groups]] · [[mirrors-and-sources]] · [[maximum-messages-exceeded]] · [[error-codes]] ·
[[advisories]] · [[defaults-and-limits]] · [[jetstream-sizing]] · [[worker-pool]] · [[nats-cli]] ·
[[orbit]] · [[nats-server-2.12]] · [[nats-server-2.14]] · [[index]].

### The unit of ingestion, applied

These seven pages are **5,388 lines**, and most of that is one example repeated in seven client
languages under `#### Go`, `#### Python`, `#### Java`, `#### Rust`, `#### C#/.NET`, `#### C` and
`#### JavaScript/TypeScript`. `CLAUDE.md` puts per-language client API documentation out of scope, so
the article ingested was the **prose and the `#### CLI` block**. A filter that drops the
per-language sections cut `advanced-publishing.md` from 796 lines to 149 — and nothing in the
summaries came from a code block in a language other than the shell.

### Two mechanisms the wiki had no page for

**Publishing.** The wiki knew `allow_atomic` (2.12) and `allow_batched` (2.14) as boolean rows in
[[defaults-and-limits]] and one line each in the release entities. Nothing said what they do.
[[publishing]] now carries:

- **the two failure modes, which are not the same.** `no responders` means *nothing was stored* and
  arrives immediately; a **timeout means nothing at all** — "the server may have stored the message
  and the ack got lost on the way back". That distinction is the whole reason `Nats-Msg-Id` exists.
- **exactly-once, stated honestly.** JetStream gives at-least-once storage with duplicate
  suppression over a bounded window, plus at-least-once delivery. The promise is precisely *a publish
  repeated within `duplicate_window` with the same `Nats-Msg-Id` is stored once* — and a retry later
  than the window stores a second copy, header or not. Nothing protects a side effect from running
  twice except an idempotent consumer.
- **the async order trap.** Nothing is resent automatically; a failed async publish is simply
  missing, and by the time the retry runs the later messages hold lower sequences, so the retry lands
  last. `Nats-Msg-Id` fixes a lost ack; `Nats-Expected-Last-Subject-Sequence` is what fixes *order*,
  by failing the retry fast.
- **the three ways an atomic batch ends without committing**, and that only two of them tell you: a
  sequence gap and an over-limit batch return an error `PubAck`, while **ten seconds without a
  message drops the batch with no error reply at all** — only a `stream_batch_abandoned` advisory.
  The committing `PubAck` is the sole proof.
- **`allow_atomic` and `persist_mode: async` are mutually exclusive**, because atomicity depends on
  the synchronous write path. Fast-ingest is fine on such a stream.
- **`gap: ok` fast ingest loses data by design**, which is correct for metrics and wrong for object
  chunks.
- **Orbit is a dependency of both batch modes in most clients**, not an optional extra — landed on
  [[orbit]], which said nothing about it.

**Subject transforms and republish.** The `{{wildcard(n)}}` / `{{partition(n,1)}}` language,
`nats server mappings` for testing one without a stream, deterministic sharding, and republish's five
headers — including `Nats-Last-Sequence`, "the stream sequence of the previous message *on the same
subject*", which is how a plain core subscriber can tell it missed something. Plus the pitfall that
matters at design time: **a partition count is permanent once consumers filter on buckets.**

### Reference work the reading paid for

**Eleven batch error codes were sitting in `raw/nats-docs/reference/jetstream/errors.md` and none was
in [[error-codes]]** — `JSAtomicPublish*` (`10176`, `10179`, `10199`, `10201`, `10210`) and
`JSBatchPublish*` (`10205`–`10209`, `10211`). They are two families, one per publish mode, with
near-identical names. **`10210` and `10211` are the only two `429`s in that table**, and they report
the in-flight-batch ceiling.

**And the limits behind them are recorded as unverified, deliberately.** The docs state 1,000
messages per atomic batch, 50 batches in flight, and a ten-second stall, calling all three
"operator-configurable server limits". **No config key for any of them exists in
`inbox/config-keys-table.md`**, and none was checked against the server. [[defaults-and-limits]] and
[[publishing]] both say so rather than presenting them as defaults.

### Sharper facts landed on existing pages

- **Sequences are addresses** ([[stream]]): deletes leave permanent holes, a purge sets first-seq to
  one past last rather than rewinding, a stored sequence "either still points at the same message or
  points at nothing", and a count is never a sequence. Plus the CLI/library asymmetry —
  **`nats stream rmm` securely erases** (overwrites the bytes) where a client's `DeleteMsg` does not;
  the server sees only a `no_erase` flag.
- **Stream vs consumer sequence** ([[consumer]]): the consumer's counter increments on **every
  delivery, redeliveries included**, so a consumer sequence ahead of the stream sequence is
  redelivery, not corruption — and the numbers ride on every delivered message, so
  `nats consumer info` should never be in a per-message path.
- **Two meanings of "overlap"** ([[consumer]]): between consumers it is the point of the design on
  `limits` and `interest` streams; inside one consumer a covering filter is refused with
  `consumer subject filters cannot overlap`, while a *partial* overlap is accepted. And **a filter
  that matches nothing is accepted silently** — an empty pull is as likely a typo as an empty stream.
- **`max_age` never rejects a publish** ([[stream]], [[maximum-messages-exceeded]]): it expires
  stored messages under either discard policy, so a "full" stream is always full on bytes or count.
  With it, the third rejection string and the fact that `discard: new` alone does **not** make a full
  *subject* reject — that needs `discard_new_per_subject` on top.

### Docs issue #5, corrected rather than quietly fixed

#5 recorded that the two-minute `duplicate_window` default is "never stated", and said the only
public statement of it was a Synadia blog post from 2025-08-08. **That was wrong.** The `learn`
chapter states it in three pages — `publishing.md` in prose ("the duplicate-tracking window is two
minutes by default"), and `your-first-stream.md` and `shaping-the-stream.md` in `nats stream info`
output — and all three agree with `StreamDefaultDuplicatesWindow` at v2.14.6.

The row is now scoped to what is genuinely defective: **the generated reference page where the field
is defined**, which says only "0 for default" and is where a reader goes for a default. Severity
medium → low. The correction is written into the issue's detail section, because a report that
quietly revises its own claims is worth less than one that shows them being tested.

### Checked and not ingested

The plan named six tutorial pages to skip unless they added something. All six were checked and four
did add something — the comma-list priority-group trap, the two pause pitfalls, the ordered-consumer
fan-out, and the `Duplicate Window: 2m0s` evidence. `message-ttl.md` is recorded as **read, added
nothing**: [[message-ttl]] already had `allow_msg_ttl`'s irreversibility with both error codes.
Those four additions cite the doc **path** and say the page has not been ingested, so a later pass
can tell a spot-check from a summary.

**Q29 and Q30 stay open, and the plan's expectation for them was wrong.** Message scheduling is not
in `learn/jetstream/` at all: a grep of the full 861-page tree for `allow_msg_schedules`,
`Nats-Schedule` and "message schedul" hits exactly three files, none under `learn/` —
`release-notes/upgrade-to-2.14.md`, `reference/jetstream/api/headers.md` and
`reference/jetstream/errors.md`. Those are where a later step should go for them.

## 2026-08-31 — unread-chapters plan step 3: `learn/key-value`, all five articles

**Operation:** ingest ×5 (`inbox/plan-the-unread-chapters-2026-08-31.md`, step 3) —
`your-first-bucket`, `watching`, `history-and-revisions`, `ttl-and-limits`, `under-the-hood`.
`where-next.md` skipped as a chapter recap, though its production checklist supplied the
bucket-name charset.

**Before → after:** pages **228 → 233**; unlanded ripples **206 across 57 pages → 206 across 57**;
citation drift **0 → 0**; lint clean. Question bank **74 → 76 answered**, ★ **42 of 42** (unchanged).

**Rows closed:** **Q73** (when a bucket is the wrong tool — the KV half; the Object Store half is
step 4's) and **Q74** (a distributed lock or lease with KV), both → [[key-value]].

**Pages created:** [[s-docs-kv-under-the-hood]] · [[s-docs-kv-watching]] ·
[[s-docs-kv-history-and-revisions]] · [[s-docs-kv-ttl-and-limits]] ·
[[s-docs-kv-your-first-bucket]].
**Pages updated:** [[key-value]] (substantially) · [[stream]] · [[direct-get]] ·
[[subject-permissions]] · [[message-ttl]] · [[object-store]] · [[ordered-consumer]] ·
[[subject-transforms]] · [[kv-watchers-stall-the-cluster]] · [[nats-cli]] · [[index]].

### The watcher gap closes, and the answer was never the server

[[key-value]] has carried "why a KV watcher would *miss* updates" as an open item since the ADRs were
ingested. `watching.md` names it outright as **"the most common watch bug"**, and it is client-side:
a watch delivers a snapshot, then **one end-of-initial-data signal**, then live changes — and a loop
that treats that signal as end-of-stream reads the snapshot and quits before the first live change.

The signal's shape differs per client, which is the part worth having in a wiki:

| client | how the boundary arrives |
|---|---|
| Go, Python | a **nil / `None` entry** in the same stream as real entries |
| JavaScript | an **`isUpdate` flag** on each entry |
| Java | an **`endOfData()` callback** |
| C# | an **`OnNoData` option** |
| **Rust** | **no marker at all** — snapshot-plus-live or live-only is chosen when the watch opens |
| `nats` CLI | consumed silently; never printed |

The earlier note stands on its own terms: nobody has publicly reported a *server-side* missed update,
and ADR-8's gap-detection remains a candidate cause with no report behind it. What changed is that
there is now a documented, ordinary explanation for the symptom.

### Five facts the wiki did not have

- **A revision is the stream sequence, so the counter is bucket-wide, not per key.** The docs' own
  worked history shows one key at revisions **2** and **5**, with 3 and 4 taken by writes to other
  keys. Anything that reasons about the gap between two revisions of one key is wrong. Landed on
  [[key-value]] and on [[stream]], where it explains *why*.
- **`put` over a TTL'd key silently makes it permanent.** "A put or an update appends a new latest
  value with no TTL of its own, so the key simply stops expiring." No error, no warning. On a bucket
  used for sessions or leases this is an outage, and it is the single most dangerous thing in the
  chapter.
- **`deny_delete` does not stop a raw publish.** The setting blocks the JetStream message-delete API
  so nothing removes entries behind the KV API's back — but a `nats pub` to `$KV.<bucket>.<key>`
  lands a bare message with none of the headers the KV API sets, so "a watcher can't tell it from a
  real put and a purge you meant never happens". **The only thing that actually prevents it is an
  ACL**, which is now a section on [[subject-permissions]] rather than an aside on the KV page: it is
  a security control, and the stream setting that looks like one is not.
- **`*` is a whole token in a key filter.** `widget-*` over flat hyphenated keys matches **nothing**;
  only `widget.blue` / `widget.red` can be filtered as `widget.*`. Key naming decides once, before
  the first put, whether a subset can ever be watched cheaply — which makes it the same decision
  [[subject-transforms]] makes about `{{partition(n,1)}}`, and it is cross-linked as such.
- **CAS is two operations, and a rejected update is dropped rather than queued.** `create` is CAS
  against revision 0, `update` against a named revision; value and revision must come from a
  **single** get, "two separate gets could pair a stale value with a fresh revision".

### Q74 answered by composing documented primitives, with the caveats larger than the recipe

No public source publishes a KV lock recipe. Every piece is documented, and they compose in exactly
one way — `create` to acquire, `update` to renew, delete to release, the per-key TTL to expire — so
[[key-value]] now states it, and then spends more words on what it is **not**: a lease rather than
mutual exclusion (a holder's TTL can expire mid-work), no fencing token beyond the revision, no
blocking acquire, and the renewal trap — **a renewal written with `put` instead of `update` drops the
TTL and the lock never expires again.** The composition is marked as this wiki's, not a source's.

### Two open items, honestly

- **Q76** (a KV mirror on file storage slower than on memory) is **not answered and now known not to
  be answerable from this chapter**: `learn/key-value` mentions mirrors exactly once, in its closing
  recap, with no performance claim. That is a result — it stops the same chapter being re-read for it
  in a later plan — and both the bank row and [[key-value]]'s *To verify* say so.
- **`subject_delete_marker_ttl` still has no documented default.** `ttl-and-limits.md` always passes
  `--marker-ttl` explicitly and never says what happens without it. The item on [[message-ttl]]
  survives a second source and now records that it was checked.

**A note on `under-the-hood.md`**, the page the plan expected most from: most of it **confirmed**
[[key-value]]'s existing stream-config table, which was built from ADR-8. That is worth recording as
a result in itself — the ADR-derived table is correct against the docs — and the page's real
contributions were the three things above plus the literal direct-get subject,
`$JS.API.DIRECT.GET.KV_INVENTORY.$KV.INVENTORY.widget-blue`, now on [[direct-get]].

## 2026-08-31 — unread-chapters plan step 4: `learn/object-store`, and a leak found by reading it

**Operation:** plan step 4 — ingest the five `learn/object-store` articles (`where-next.md` skipped as
a recap, though its production checklist supplied `ErrNoObjectsFound`). Then two things the plan did
not ask for and the reading demanded: **Q75 run on the binary** because no public source answers it,
and a **leafnode leak** found by reading the server's JetStream deny list next to the object store's
real subject spaces.

**Sources:** `raw/nats-docs/learn/object-store/{your-first-object,chunking,metadata-and-links,watching-and-listing,under-the-hood}.md`;
`raw/gh-discussions/gh-6836.md` (new); `raw/nats-server-src/object-store-observed-v2.14.6.md` (new,
nine experiments); `raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md` (new, four
experiments). Both raw runs are on **nats-server v2.14.6** with **nats CLI 0.4.0**, matching
`verified-against`.

**Summaries created (8, at the step's cap):** `s-docs-object-store-your-first-object`,
`s-docs-object-store-chunking`, `s-docs-object-store-metadata-and-links`,
`s-docs-object-store-watching-and-listing`, `s-docs-object-store-under-the-hood`,
`s-gh-6836-object-store-list-slow`, `s-nats-server-object-store-observed`,
`s-nats-server-object-store-leafnode`.

**Page created:** [[object-store-list-is-slow]] (gotcha).

**Pages updated:** [[object-store]] (substantially — six new sections), [[filestore-layout]],
[[jetstream-sizing]] (new *Step 6*), [[js-api-subjects]], [[defaults-and-limits]] (new *Key-Value and
Object Store* section), [[subject-permissions]], [[key-value]], [[cross-account-sharing]],
[[jetstream-domain]], [[leafnode]], [[streams-not-visible-across-a-leafnode]], `wiki/index.md`,
`raw/sources.md`.

**Numbers.** Bank: 105 rows (was 104), **77 answered** (was 76), ★ **42 of 42** unchanged.
Unlanded ripples **206 → 205** (peaked at 211 mid-step, from the new summaries' own `## Pages
touched`); citation drift 0 → 0; lint clean; **233 → 242 pages**. `inbox/docs-issues.md` **34 → 35**.

**Rows closed: Q75** ([[object-store-list-is-slow]]) and the object-store half of **Q73**
([[object-store]] joins [[key-value]]). **Row added: Q105**, open.

### Q75 had no public answer, so it was measured

`learn/object-store/watching-and-listing.md` is the page the plan named for this row. Read for it, it
is a **negative result**: it says "a list is cheap: it reads metadata, never chunks" and never
mentions concurrency, contention or latency. And gh#6836 — the only public report — has **one comment,
by the asker, and no reply from anyone else** since 2025-04-25. So the row was settled on the binary:

- **Object count is nearly free.** 200 objects list in 0.027–0.034 s, 5,000 in 0.044–0.046 s — 25× the
  objects for 1.6× the time. The obvious hypothesis is wrong, and saying so is half the answer.
- **The effect has two separable layers.** Under a sustained upload, core NATS RTT moves +4 %; every
  JetStream call pays a flat **server-wide +27–35 %** (an *unrelated* stream's `stream info` slows
  exactly as much as the busy one's); and on top of that, **only on the bucket being written to**,
  list latency runs **2× to 6.9×** and becomes jittery.
- **The mechanism, traced on `$JS.API.>`:** one `nats object ls` is four API calls, the third an
  **ephemeral `last_per_subject` push consumer created and destroyed on every call**. That also went
  onto [[js-api-subjects]], with the ACL consequence — a grant of `$O.<bucket>.M.>` alone lets a
  client *watch* but not *list*.
- **A negative result kept deliberately:** `--timeout` does not bound the whole operation.
  `nats object ls --timeout=1ms` completed successfully. The reporter's `>5 s` is the CLI's `5s`
  default hitting one of the four round trips, not the listing running long.

### The chapter's claims, checked rather than repeated

Everything [[object-store]] carried from ADR-20 alone was confirmed on the running server, and three
things gained numbers the docs never give:

- **The default chunk size is exactly 128 KiB**, not "roughly": 3,145,728 bytes → exactly 24 chunks.
- **The disk-reclamation pitfall is overstated.** The docs warn that space after a delete "is
  reclaimed as the stream cleans up, not synchronously at the call". Measured: a 200 MiB delete took
  the stream directory from 204,912 KB to **3,212 KB at the call** and held there through +60 s.
  **98.4 % is synchronous**; the residue is one trailing block — which [[filestore-layout]] already
  explains, because neither compaction path touches the last block. Both pages now say so.
- **Per-message overhead has a figure at last.** `chunking.md` is the one page in the docs tree that
  raises it and it states no number; at the 128 KiB default it is about **2.4 %**. On
  [[filestore-layout]] and in [[jetstream-sizing]]'s new *Step 6*.

Also settled: the raw metadata message shows `Nats-Rollup: sub`, the `SHA-256=<base64url>` digest, and
**`mtime` as the zero time** — the observable proof of ADR-20's "modified time is never stored", which
the wiki had asserted from the spec alone.

### The finding the plan did not ask for: an object bucket is not isolated by a JetStream domain

Reading `server/jetstream_api.go:323` while writing the chapter's ripple: the leafnode JetStream deny
list is `["$JS.API.>", "$KV.>", "$OBJ.>"]`. **The object store does not use `$OBJ` — it uses `$O.`**,
per ADR-20, the docs, and the running server. `$OBJ` appears nowhere in the 861-page docs tree.

Run on a hub/leaf pair with domains `hub` and `leaf` in a non-system account: `$KV.TEST.key1` and
`$OBJ.TEST.thing` were denied; **`$O.TEST.C.abc` and `$O.TEST.M.abc` crossed.** With a same-named
object bucket on each side, one 600 KiB put **on the leaf only** left both streams at
`6 msgs / 615,040 bytes` and the hub listing an object nobody put there — chunks and metadata both, a
complete gettable object. The KV control in the same account stayed at 0 msgs on the hub; the
connectivity control confirmed the link was up.

Nothing is logged and the put looks normal. Recorded as **docs issue #35** (the documentation gap is
unambiguous; whether the `$OBJ`/`$O.` mismatch is a defect or an intended asymmetry is **not**
established, and the entry says so), and on four pages including the mitigation — a `deny` for `$O.>`
on the leafnode remote, one of the few cases where [[leafnode]]'s deny-only keys are exactly right
because there is nothing to allow.

### One strike, named

**`s-docs-object-store-your-first-object` → [[jetstream-sizing]]** was struck from that summary's
`## Pages touched` at ingest time, with the reason recorded in the summary itself: the page is about
the put/get contract and the two client error branches and carries no rate, size, count or overhead
figure. The chunk-count arithmetic sizing actually needs comes from `s-docs-object-store-chunking`,
which did land there.

### Two `## To verify` items closed, three opened

Closed on [[object-store]]: **Q75** (measured, above) and **chunk-size guidance** — the ADR gives none
and `chunking.md` does, with both bounds. Opened, honestly: **no source states which nats-server
version the object store shipped in**, so `since:` is left empty rather than guessed; **links and
`UpdateMeta` were not run**, because the `nats` CLI has no `link` or `update-meta` subcommand, so those
claims rest on the docs alone; and **`ErrDigestMismatch` was not observed**.

## 2026-09-01 — unread-chapters plan step 5: `interop`, and fifteen runs to price QoS

**Operation:** plan step 5 — ingest all eight articles of `learn/mqtt` and `learn/websocket`
(both `where-next.md` pages skipped as recaps, though each supplied facts named below). The chapter
that answers question-bank row **Q80** describes MQTT's JetStream state in prose and **never names a
single stream**, so the plan's warning applied and the row was **run on the binary** instead.

**Sources:** `raw/nats-docs/learn/mqtt/{your-first-mqtt-client,topics-and-subjects,qos-sessions-and-retained,auth-and-clustering}.md`;
`raw/nats-docs/learn/websocket/{your-first-websocket-connection,browsers-and-origins,tls-and-proxies,leaf-nodes-over-websocket}.md`;
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md` (new, fifteen experiments) and
`raw/nats-server-src/mqtt-probe-client-v3.1.1.py` (new, the instrument).

**Summaries created: 9** — eight doc articles plus one observed run. That is **one over the step's
~8 cap**, and the overrun is the observed run: the alternative was leaving Q80 answered from prose
that names nothing, which the plan explicitly warned against.

**Pages created:** [[mqtt]] and [[websocket]] (concepts), [[run-nats-behind-a-proxy]] (runbook,
`kind: runbook`).

**Pages updated:** [[defaults-and-limits]] (new *Interop* section), [[config-keys]],
[[subject-permissions]], [[account]], [[operator-mode]], [[tls-in-nats]], [[leafnode]],
[[reload-server-config]], [[replicas]], [[jetstream-domain]], [[monitoring-endpoints]],
[[ack-and-redelivery]], [[no-suitable-peers-for-placement]], [[how-clients-reach-a-cluster]],
`wiki/index.md`.

**Numbers.** Bank: 105 rows, **81 answered** (was 77), ★ **42 of 42**. Unlanded ripples
**205 → 203** (peaked at 230 mid-step); citation drift 0 → 0; lint clean; **242 → 254 pages**.
`inbox/docs-issues.md` unchanged at 35 — the chapters were **accurate**, which is itself the result
below.

**Rows closed: Q79** ([[run-nats-behind-a-proxy]] · [[websocket]]) and **Q80** ([[mqtt]], measured).
**Q78 and Q81 closed as dead ends**, both with `no-public-answer` and a bold cell.

### `interop` now has pages, not scattered config keys

The area was one entity page (`nats-js`) and **zero summaries**. It is now two concepts, a runbook,
nine summaries, and an `Interop` section in [[defaults-and-limits]]. MQTT and WebSocket previously
appeared in this wiki only as config keys — including two defaults corrected as docs issues #28 and
#29, which made for a wiki that could tell you a default was wrong but not what the feature did.

### Q80: the five streams nobody documents

`nats stream ls -a` before any MQTT client connects says `No Streams defined`. After one CONNECT there
are five, created **lazily on first connection**:

| stream | subjects | retention | discard | `max_msgs_per_subject` |
|---|---|---|---|---|
| `$MQTT_sess` | `$MQTT.sess.>` | limits | old | 1 |
| `$MQTT_msgs` | `$MQTT.msgs.>` | **interest** | old | -1 |
| `$MQTT_out` | `$MQTT.out.>` | **interest** | old | -1 |
| `$MQTT_qos2in` | `$MQTT.qos2.in.>` | limits | **new** | 1 |
| `$MQTT_rmsgs` | `$MQTT.rmsgs.>` | limits | old | 1 |

And the price, with a 100-byte payload: **QoS 0 costs nothing; QoS 1 and QoS 2 cost the same** — one
message in `$MQTT_msgs`, 194 bytes — so **QoS 2's extra price is round trips and transient state, not
stored bytes**. A retained message costs 174 bytes **even at QoS 0**, which is the concrete reason the
account needs JetStream for a fleet that never uses QoS 1. A session record is 104 bytes bare and
**791 bytes with one subscription**: the subscription is the expensive part.

`$MQTT_out` turned out to hold the **outbound PUBREL state** for QoS 2 *delivery* — traced packet by
packet: the subscriber's PUBREC drops `$MQTT_msgs` to zero and writes one record to `$MQTT_out`, then
the server sends packet type 6.

### Two findings the chapters do not contain

**An abandoned QoS 2 handshake leaks a record.** A PUBLISH at QoS 2 whose PUBREL never arrives leaves
a record in `$MQTT_qos2in` that survives the disconnect and never expires (`max_age: 0`); a completed
handshake leaves nothing. The subject is `$MQTT.qos2.in.<client-id>.<packet-id>` with
`max_msgs_per_subject: 1`, so the leak is **bounded at 65,535 per client id** and unbounded in the
number of client ids.

**Stale sessions pin QoS 1 messages forever — which is Q81's thread, explained.** `$MQTT_msgs` uses
**interest retention**, so a vanished session's durable consumer still holds interest and nothing is
removed. Three killed durable sessions plus five publishes left five messages that did not drain;
reconnecting each dead client id **once with the clean-session flag** took the stream to zero. The
reporter of gh#7397 has exactly this and has had no reply since 2025-10-06. **No public source
connects the two facts.**

### The chapters were right, which is a result

Both are unusually accurate, and this step produced **no new docs issue**:

- **All ten topic→subject conversion rules matched exactly**, including the four wildcard-passthrough
  cases.
- **The 63/31 subscription ceiling the chapter derives is exact** — subscription #64 refused with
  `0x80` for plain filters, #32 for `#` filters.
- **The origin table reproduced row for row**, one `101` and four `403`.
- The six refused characters, the publish-closes/subscribe-`0x80` asymmetry, MQTT v5 refused with
  CONNACK return code 1, `Nmqtt-Pub` carrying the QoS, and four startup errors verbatim — all as
  documented.
- **`stream_replicas` derived from the `routes` list is real**: a genuine three-node cluster whose
  node listed two routes created all five MQTT streams at **R=2**, and the server says so once —
  `Creating MQTT streams/consumers with replicas 2 for account "$G"`.

That last one produced a bonus while the cluster was half up: asking for `stream_replicas: 3` on a
two-node cluster makes **MQTT clients unable to connect at all**, with the device getting the TCP
connection closed and **no CONNACK** — nothing an MQTT client can report — while the server logs
`create sessions stream for account "$G": no suitable peers for placement (10005)`. That landed on
[[no-suitable-peers-for-placement]] as a second way into an existing gotcha.

### Method notes worth keeping

**No MQTT client was installed for this.** `raw/nats-server-src/mqtt-probe-client-v3.1.1.py` is a
~110-line stdlib-only MQTT 3.1.1 client written for the step, which is what made SUBACK `0x80` codes
and the full QoS 2 handshake directly observable. Installing `mosquitto` would have changed the user's
machine for one step's worth of verification.

**One near-miss recorded in the raw file.** A first pass at the origin table reported `400` for every
origin *including the allowed one*. That was a shell-quoting bug in the harness —
`${1:+-H "Origin: $1"}` word-splits and hands curl a malformed header — not server behaviour. It was
caught by re-running a single case by hand and getting `101`. The table was then rebuilt in Python.
Recorded because a harness bug that produces a plausible finding is the most dangerous kind.

### Two rows closed as dead ends

**Q78** (WebSocket connections per server) — no source gives a number, and `max_connections` bounds
all connection kinds together, so it does not answer the question. Deliberately **not** measured: a
connection-count benchmark says more about the machine than the server, and this wiki does not publish
sizing numbers it cannot attribute. Stated once, on [[websocket]]'s *To verify*.

**Q81** (restrict MQTT client ids via JWT) — the page named for it restricts a *connection type*, not
a client id, and the thread is unanswered. Closed with the mechanism behind the reporter's actual
problem on [[mqtt]] instead, which is the more useful half.

### Harvested from the two `where-next.md` recaps without ingesting them

Cited by doc path, not by summary, so a later plan can tell the difference: **MQTT v3.1.1 only, v5
rejected at connect** (confirmed on the binary), the **`MQTT_WS`** connection type for browser-based
MQTT clients, and Sparkplug B being ordinary MQTT traffic to the server.

## 2026-09-01 — unread-chapters plan step 6: `learn/monitoring`, and two rows answered from the source

**Operation:** plan step 6 — ingest the three unread `learn/monitoring` articles
(`where-next.md` skipped as a recap). The step was kept last because `advisories-and-events.md` is the
best available cross-check on docs issues **#1–#3**; that cross-check is reported below, and it is a
partial result.

**Sources:** `raw/nats-docs/learn/monitoring/{advisories-and-events,jetstream-health,profiling}.md`;
`raw/nats-server-src/monitoring-observed-v2.14.6.md` (new — `monitor.go`, `pse/pse_linux.go`,
`client.go`, `const.go`, `jetstream_api.go` at v2.14.6, plus runs); `raw/gh-discussions/gh-7362.md` and
`gh-7483.md` (new).

**Summaries created: 6** — three doc articles, one source/observed, two threads. Within the ~8 cap.

**Pages updated:** [[monitoring-endpoints]] (four new sections), [[advisories]],
[[stream-has-high-message-lag]], [[consumer]], [[ack-and-redelivery]], [[jetstream-sizing]],
[[raft-in-nats]], [[config-keys]], [[mqtt]], `wiki/index.md`. **No page created** — see below.

**Numbers.** Bank: 105 rows, **83 answered** (was 81), ★ **42 of 42**. Unlanded ripples
**203 → 202** (peaked at 211 mid-step); citation drift 0 → 0; lint clean; **254 → 260 pages**.
`inbox/docs-issues.md` **35 → 36**.

**Rows closed: Q60** and **Q61** — both from the server source, and neither from the chapter the plan
named for them.

### Q60 — what `/varz` `cpu` is relative to

The chapter never says, and `profiling.md` is about CPU *profiles*, a different thing. From the source:
`Varz.CPU` comes from `pse.ProcUsage`, and on Linux a background timer samples `utime + stime` from
`/proc/<pid>/stat` **once a second**, takes the delta, divides by elapsed seconds, and stores
`(total*1000/ticks)/seconds`, returned `/10.0`. So:

> **`cpu: 100.0` is one core fully consumed.** It is relative to **neither** the host's cores nor a
> container's allocation.

The thread this row comes from was **closed with zero comments**. Its asker was building a
`nats server check server` threshold on a 0.25 vCPU Fargate task and saw `"cores": 2, "cpu": 10` — that
`cpu: 10` is **40 % of their allocation**. Two caveats came with it: `ticks` is **hardcoded to 100**
rather than read from `sysconf(_SC_CLK_TCK)` (commented "Avoiding to generate docker image without
CGO"), and the elapsed-seconds term uses the **host's** uptime.

### Q61 — `rtt` is a PING/PONG that can be an hour old

`c.rtt` is written in exactly two places: at connect it is `computeRTT(c.start)` — the **connection
setup time, not a ping** — and thereafter on each PONG. It is floored at 1ns, so it is never zero once
set. The refresh rule is the part that matters:

- routes, gateways and spoke leafnodes are pinged **every ping-timer tick** (default `2m`);
- a **client** is pinged only when `rtt == 0` or **more than an hour** has passed
  (`DEFAULT_RTT_MEASUREMENT_INTERVAL = time.Hour`);
- **MQTT connections never get an RTT ping at all**.

The public thread has a chosen answer — "periodic PING/PONG response times" — which is correct and
omits the period. Its reporter then said "I don't see these values getting updated, even if we wait
minutes", which is **exactly right**, and the final reply was a referral to commercial support. Three
fresh loopback clients here showed `rtt` of 314µs, 286µs and 177µs — hundreds of microseconds where a
real loopback ping is tens, consistent with connect-time estimates.

### The #1–#3 cross-check: a partial result, and an upgrade

`advisories-and-events.md` **does not settle #2 and #3**. It names `nak`, `consumer_action` and
`terminated` as *types* and never writes their subjects, and does not mention pinned or unpinned at
all. Those two issues still rest on the server alone, and the page is recorded as having been checked
so nobody re-reads it for that.

**But #1 is now confirmed on the wire.** A message was NAK'd on a live 2.14.6 server with
`nats sub '$JS.EVENT.ADVISORY.>'` attached:

```
$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.naktest
```

against the generated reference's `…CONSUMER.MSG_NAK.{stream}.{consumer}`. That upgrades the evidence
from a source constant to an observed subject, which is what the report needed before being sent
upstream.

### A new one: docs issue #36

The same page's **prose** gives the max-deliveries subject correctly as
`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping`, and its **animation caption drops
`.CONSUMER.` three times**. The server and the wire both agree with the prose. Filed `low`, because the
right value is on the same page immediately above the picture.

Two smaller findings from the same run, recorded inside #36 rather than as rows: the advisory body
carries **`id` and `timestamp`** beyond the fields the docs' example shows, and
**`$JS.EVENT.ADVISORY.API` fires for ordinary API calls** — three arrived just from creating a stream
and two consumers, so the chapter's `subscribe '$JS.EVENT.ADVISORY.>'` example is noisier in practice
than it reads.

### No profiling page, deliberately

`profiling.md` is the method behind a pointer [[jetstream-sizing]] has carried for five plans —
"profile with Go's `pprof`" with no instructions. The material landed there as a section, plus
`$SYS.REQ.SERVER.PING.PROFILEZ` on [[monitoring-endpoints]] and the two reload behaviours on
[[config-keys]].

**It did not become a runbook.** No row in `inbox/question-bank.md` asks about profiling, and a search
of `nats-io/nats-server` discussions for a public question about it returned **nothing**. `CLAUDE.md`'s
scope test says a page needs a question behind it, so no page was created and **no question was
invented to justify one**. Recorded here because "we chose not to write a page" is otherwise invisible.

The section does carry the security point the docs make plainly: `prof_port` has **no authentication**,
binds to the same `host` as the client port (default `0.0.0.0`), has no separate profiling host to
narrow, and a goroutine dump exposes subjects and internal state.

### Landed on the reader layer

`jetstream-health.md` gave [[stream-has-high-message-lag]] what it lacked: lag as arithmetic
(`last_seq − delivered.stream_seq`), the three numbers that get confused (`num_pending` /
`num_ack_pending` / `num_redelivered`, with "rising in-flight means a stuck handler, rising lag means
not enough handlers"), and the **crashed-worker signature** — `num_pending` climbing while
`num_waiting` is 0 and `delivered.stream_seq` is flat. The field table went to [[consumer]].
[[ack-and-redelivery]] gained the fact that **there is no dead-letter queue**: one advisory, published
once, stored nowhere.

## 2026-09-01 — the reports made sendable, and server findings split out

**Operation:** not an ingest. Preparing `inbox/docs-issues.md` to actually be sent, after an audit of
how it reads to someone who did not write it.

**What the audit found.** The evidence layer was already strong — 36 rows, each verified against
`nats-server` at a release tag with file and line, the doc text quoted beside the code, 33 detail
sections, most with a *Suggested fix*, and a `kind`/`severity` split that maps onto triage. Six things
got in the way of sending it:

1. **One file, three recipients** — 33 rows to `nats-docs`, 3 (#7, #30, #31) to the ADR repo, and #35
   really a server question.
2. **54 unresolvable path references** (20 `raw/`, 34 `wiki/`) — dead pointers outside this repo.
3. A **`Where the wiki records each of these`** table: internal bookkeeping presented as report.
4. The **`status` column is ours**, and reads like one the recipient owns.
5. **Nowhere to record what happened upstream** once filed.
6. **#35 misfiled** — a docs gap and a server behaviour in one row.

**Created `inbox/server-issues.md`**, registered in `wiki.json` as its own nav table (`Server issues`).
The reason for a separate file is **authority, not tidiness**: `docs-issues.md` runs on "the server is
the authority", so every row there is *settled*; a server finding inverts that, because there is no
higher authority to check it against, so an entry can only be an observation plus a question. Mixing
unsettled entries into the settled file erodes what makes the settled file worth sending.

Its discipline differs deliberately: **no `wrong-value`** — the kinds are `unexpected`, `inconsistent`,
`undocumented` — and every entry **must** carry a runnable reproduction with its config and output, the
release it ran on, **what would settle it** (the question actually being asked upstream), what was
searched for and not found, and what was *not* tested.

**`SI-1`** is the first entry: the leafnode JetStream deny list names `$OBJ.>` while the object store
uses `$O.`, so object data crosses a domain boundary KV data does not and same-named buckets converge.
Its "what would settle this" is one question — *is `$OBJ.>` intended to be the object store's subject
space?* — with both answers spelled out, because they lead to different fixes in different repos.

**Reshaped `docs-issues.md`** without touching a single verified row's evidence:

- a **"How to read this, if you maintain the docs"** preamble, including a column-by-column table
  written for the recipient and an explicit note that internal paths are traceability, not dependencies;
- a **`destination`** column (`nats-docs` / `ADR repo`) so the three ADR rows are visibly not the docs
  maintainer's problem;
- an **`upstream`** column, `not filed` on all 36, to record issue numbers and outcomes as they are
  sent;
- **#35 narrowed to its documentation half**, pointing at `SI-1` for the behaviour, and `SI-1` pointing
  back;
- the internal table moved under a heading that says *Not part of the report*.

**`CLAUDE.md` updated**: the map gains `server-issues.md`, and *Operation: record a docs issue* gains a
**"Which file"** rule with the authority reasoning, the `SI-<n>` entry requirements, the
`destination`/`upstream` fields, and the note that one finding may legitimately produce a row in each.

**Also corrected**: `wiki/index.md`'s inbox section said **26** docs issues (it is 36) and named a
finished plan as "the current plan". Both fixed, and all five plans now show their finished dates.

**Numbers unchanged** — 260 pages, bank 105/83, ★ 42 of 42, unlanded ripples 202, drift 0, staleness 0,
lint clean. Nothing was ingested and no wiki page's content changed.

**Correction, same day.** The `inbox/` list above was written in this session claiming
`plan-consolidation-2026-08-31.md` was **finished**. It is not: steps 1 and 4 are done, **steps 2, 3,
5, 6, 7 and 8 are still `status: open`**. Corrected in `wiki/index.md`. The consolidation plan is the
standing follow-on queue for the unlanded-ripple count, which is why that count has been reported
before and after every step since — it stands at **202 across 56 pages**, and `concepts/account` is
still its single biggest debt.

**Proposed, not started:** `inbox/plan-the-meta-layer-2026-09-01.md` — `meta-layer` and
`stream-leader-keeps-moving`, the two remaining wanted pages, plus Q37 and Q40 and
[[raft-in-nats]]'s open `## To verify` items. Everything it needs is unfetched:
`server/jetstream_cluster.go`, gh#7533 and gh#6892. **Filing the two reports stays parked** — the
current phase is collecting, and both files are shaped to be sent whenever that changes.

**Two plans are now open at once**, which has not happened before, so a bare `start the plan` is
ambiguous: it takes the *newest* `inbox/plan-*.md`, which is now the meta-layer one. Both should be
started by naming the file.


## 2026-09-01 — consolidate: `concepts/account`, the plan's single biggest debt (step 2)

*Operation: consolidate*, `inbox/plan-consolidation-2026-08-31.md` step 2. No new sources; nothing in
`raw/` touched.

**Unlanded ripples 202 across 56 pages → 181 across 55.** `concepts/account` goes **21 → 0**. Citation
drift stayed 0, lint clean, staleness 0. Bank **105/83** unchanged — no row moved from open to
answered; four already-answered rows gained `[[account]]` as a second answering page (48, 90, 95, 96).

**The mix, per the pacing note step 4 established:** of 21 pairs, **3 were citation-only** and **18
were real additions** — the opposite ratio to the reference layer, and the reason this page was the
plan's first target. A concept page absorbs behaviour; a reference table only absorbs values.

**What actually landed** (each was absent from the page, not merely uncited):

- **The system account may not have JetStream.** `[FTL] Not allowed to enable JetStream on the system
  account`, confirmed at 2.14.6 in `server.go:2429`. The page previously said only that JetStream is
  opt-in per account, which reads as if the system account were an ordinary opt-in.
- **Per-account JetStream limits**, a whole section: `10047` has *two* origins, server `max_file_store`
  or the account's `MaxStore` tier (a 2023 report ran a `122 MiB` account under a far larger server);
  `nats account info` is what tells them apart; on an untiered account R3 counts three times against
  the account limit; `max_consumers` is the only enforceable control on consumer creation.
- **What crosses the boundary**: there is no cross-account user, and the two shapes that get across
  anyway (a `$JS.API.>` service export under a prefix; mirroring/sourcing with `external`), both
  all-or-nothing unless the export is narrowed.
- **What an account does *not* scope**: TLS is per kind of peer and encryption at rest is server-wide.
- **The account is what a leafnode binds to** — `leafnodes.remotes[].account` and
  `leafnodes.authorization.users[].account`; `permissions` there is a parse error
  (`opts.go:3005–3064`); extending JetStream needs the **system account** *and* identical domains, and
  identical domains on any other account make the server deny JetStream outright.
- **Where auth callout puts a client** — the callout's `account` defaults to `$G`, the target account
  must already exist in the config, and `allowed_accounts` (2.11+) with its `$G` exception.
- **The push is `$SYS.REQ.CLAIMS.UPDATE`** over the client port, its four-subject temporary user, and
  the silent timeout with no server-side log line. This was the gap the plan sampled before writing.
- **Composed servers refuse to start without `system_account`** (`leafnode.go:346–349`), which
  `nats-server -t` does not catch; and the `Account` column of `nats server report leafnodes` is the
  isolation audit.
- Accounts, users, permissions, account limits and the `jetstream` flag **all reload** — which is what
  makes `no_auth_user` not reloading the sharp exception.

**Citation-only** (material was already on the page): `s-docs-authentication-basics` (`$G` landing),
`s-docs-security-checklist` (narrow `no_auth_user`, declare `SYS`), `s-docs-forming-a-cluster` (the
cluster chapter sets up no system account).

**No strikes.** Every one of the 21 had something to say to this page. Two were landed as pointer
sentences rather than sections, because their material belongs elsewhere and the page now says so:
`s-gh-7505-auth-callout-nkey` (what the server validates before a callout — on [[auth-callout]]) and
`s-docs-config-and-jwt-backup` (the two copies of the account JWTs — on [[backup-and-restore-identity]]).

**`## To verify` grew rather than shrank**, deliberately: the JetStream tier fields are now stated, so
the old item was narrowed to the connection-side limits it still does not cover, and a second item
records the import-ceiling question asked on gh#5606 and never answered (bank row 98, still empty).

`verified-against: nats-server 2.14.6` / `verified-on: 2026-08-31` left as they were — no server was
run today; every added claim carries the version its own summary verified it at.


## 2026-09-01 — consolidate: the JetStream core — `stream`, `replicas`, `consumer` (step 3)

*Operation: consolidate*, `inbox/plan-consolidation-2026-08-31.md` step 3. No new sources ingested;
one **new file in `raw/`**, which is a run, not a fetch (below).

**Unlanded ripples 181 across 55 pages → 144 across 52.** `concepts/stream` **16 → 0**,
`concepts/replicas` **15 → 0**, `concepts/consumer` **6 → 0** — all 37 claims of the step. Citation
drift 0, lint clean. Bank **105/83**; rows 32 and 38 gained `[[stream]]` / `[[replicas]]` as further
answering pages, no row moved from open to answered.

**Mix: 33 real additions, 4 citation-only, 0 strikes.** The concept-page ratio from step 2 held.

**`concepts/stream`** gained: the account owning the stream namespace and the `10065
subjects overlap with an existing stream` check that runs across it; `max_bytes` as a **reservation**
against server and account limits, not just a ceiling; ~2 FDs per stream and `replicas × bytes` on an
untiered account; the 2.14 change making a filestore I/O error **freeze** the stream; why
`nats stream info` can list a stream whose directory is gone (metadata in the meta layer, blocks under
`store_dir`); the restore rules (`stream names may not be changed during restore`, no merge into a
live stream); a **Purging is a request with options** section from ADR-10 (`filter`/`seq`/`keep`,
`10003` for `seq`+`keep`, `10109` sealed, `10110` `deny_purge`, and `--keep` as *the* recovery tool);
the per-stream API subject as an **ACL boundary** plus `nats schema show` and `--trace`; two new rows
in *What you cannot change later* (`mirror` fixed vs `sources` editable; `allow_msg_ttl` enable-only,
API level 1, not on a mirror); and a **Streams you did not create by hand** table giving the `KV_` and
`OBJ_` bucket shapes.

**`concepts/replicas`** gained: growing a group as a placement decision, and the sharp part —
**a new peer counts for quorum immediately and holds no data**, so R=4 commits at three while the
empty peer cannot win an election; one membership change at a time; `--replicas` on **restore** and
the "temporarily R3" technique as the other two ways a count changes; the **standalone → clustered
migration that deletes the streams**; `current` as the gate on every rolling operation and the fact
that Kubernetes **readiness does not tell you this** (catch-up belongs in a startup probe, and a
peer-aware readiness probe deadlocks the cluster); the `Peer selection: discard … reason:` debug lines
as the only diagnostic for `10005`; placement never relaxing to fit a replica count; the replication
lag warning being about the stream leader, not consumers; 2.12's empty-state protection and its cost
(**all** replication peers available, not just quorum); and a *replica is not a mirror* paragraph.
Shape 3 landed too: the account-quota rule now cites `accountReservation`
(`jetstream.go:2511–2519`, 2.14.6) beside the docs sentence it explains.

**`concepts/consumer`** gained: the **ordered consumer as a client construct** with the seven fields
the client forces and the four things it may not be; the KV read patterns as consumers (watch =
ordered at `last_per_subject`, history = filtered `deliver_all`, keys = headers-only last-per-subject);
that a durable and an ephemeral **cannot be told apart at the subject level** on modern clients, so
`max_consumers` on the account is the enforceable control; the worker-pool facts (`max_ack_pending`
shared, arrival-order service, position owned by the consumer); and that **"Slow Consumer Detected" is
about a connection, not a JetStream consumer**.

### A docs issue the pass found: `inbox/docs-issues.md` #37

Consolidation put two pages side by side that had never met: [[consumer]] carried
`learn/jetstream/policies.md`'s "priority policy — can change" and [[priority-groups]] carried
ADR-42's "you cannot switch between policies. Only `PriorityTimeout` is updatable". **The server
settles it against the ADR.** Run on the local **v2.14.6** binary (matching `verified-against`) with
nats CLI 0.4.0: `overflow` → `pinned_client`, removing groups, and adding them back are all accepted
with no error; and a consumer created with **two** groups keeps both, against the ADR's "more than one
is an error".

**Neighbour sweep, as the rulebook requires: four ADR-42 rules checked, two wrong, two hold** — the
16-character group-name cap (`10162`) and the push-consumer refusal (`10178`) both fire. A fifth
observation, not a defect: `pinned_client` with no explicit value fills `priority_timeout` with
**2 minutes**, and that field *is* updatable — the one accurate clause in the sentence.

Recorded as **#37** (`destination: ADR repo`, `kind: wrong-value`, `medium`, `upstream: not filed`) —
the second ADR-42 row after #7. Evidence: `raw/nats-server-src/priority-groups-observed-v2.14.6.md`,
registered in `raw/sources.md`. [[priority-groups]] now states the server's behaviour and says the
sources disagree; its `verified-against` moved to **2.14.6** and `verified-on` to **2026-09-01**,
because a run happened. The run's transcript also records what was **not** tested: whether a two-group
consumer serves both groups (the docs say only the first is used — unverified), behaviour with active
pinned clients, and the clustered case. [[consumer]]'s claim was already right and now carries the
run behind it.

**Not filled: `since:` on these three pages.** None of the 37 summaries states which release streams,
replicas or consumers first appeared in, so shape 4 stays open here rather than being answered from
memory. Version attribution for individual *fields* is on the pages (2.11/2.12/2.14) and is sourced.


## 2026-09-01 — consolidate: topology and cluster operations (step 5)

*Operation: consolidate*, `inbox/plan-consolidation-2026-08-31.md` step 5. No new sources; nothing in
`raw/` touched.

**Unlanded ripples 144 across 52 pages → 105 across 47.** `internals/raft-in-nats` **10 → 0**,
`operations/install-nats-server` **10 → 0**, `concepts/mirrors-and-sources` **9 → 0**,
`operations/build-a-3-node-cluster` **7 → 0**, `internals/stream-placement` **3 → 0** — all 39 claims
of the step (the plan's count of 40 was written when `raft-in-nats` had 11). Citation drift 0, lint
clean. Bank **105/83** unchanged; rows 35, 77 and 92 gained further answering pages.

**Mix: 34 real additions, 5 citation-only, 0 strikes.**

**Shape 1 was the step's prediction and it was half right.** Both runbooks already had their
`### Kubernetes` and `### systemd` surfaces — what was missing was not a surface but the *content*
inside two of them, plus one surface nobody had noticed was absent:

- `install-nats-server` gained a **`### TLS`** section it never had (the three independent blocks;
  `verify: true` meaning different things on client and route), plus `include` path resolution, the
  quoted-vs-unquoted `$NAME` inversion that makes bcrypt hashes the values you *do* quote,
  `nats-server -c … -t`, and the reload/restart principle in the docs' own words. Its `### Kubernetes`
  gained the two chart facts that bite — **the shipped drain arithmetic has no slack**
  (`10s + 30s + 20s = 60`, exactly `terminationGracePeriodSeconds`) and the reloader sidecar's
  `natsVolumeMountPrefixes: [/etc/]`, so a certificate mounted elsewhere never produces a SIGHUP.
- `build-a-3-node-cluster` gained a **second independent report** of the one-DNS-name `routes` defect
  (gh#5859 alongside gh#7190), the two log lines from that thread that are *not* symptoms, the
  "composition adds reach, not boundaries" framing with the system-account startup refusal, and a new
  **What this cluster now supports** section covering membership changes and upgrade order.

**`raft-in-nats`** gained the RAFT log-line family from a real incident (`Wrong index`,
`Critical write error`, `has NO quorum, stalled`), the reading that `JetStream out of resources` on
that path is **not** a capacity message, `Restored N messages …` as the positive startup signal,
three independent elections rather than one, a draining node's groups becoming **observers**, a new
peer counting for quorum while holding no data, `Routes` being a connection count and not a peer
count (8 for three servers), the super-cluster's single WAN-wide meta group as a quorum hazard, and
meta leadership as the explanation for an asymmetric memory profile.

**`mirrors-and-sources`** gained the KV shapes from ADR-57 (a KV mirror always sets `mirror_direct`;
a KV source gets `$KV.<source>.>` → `$KV.<bucket>.>` generated), Direct Get's staleness, the
file-backed mirror as the *only* backup path for a memory stream, promotion needing meta quorum, and
a section naming the four cross-boundary problems that all resolve to "mirror or source".

**`stream-placement`** gained `peer-remove` versus `--replicas` — the two commands people confuse —
with `10075 peer remap failed` leaving an R>1 stream a replica short when nowhere qualifies, the
serialised meta-group variant (`10202`), restore as a third placement lever, and the `…ErrF` naming
rule that explains why `10005` can quote your tag.

**Citation-only** (material already on the page): `s-docs-encryption-and-tls` and
`s-nats-server-systemd-units` on `build-a-3-node-cluster`, `s-gh-5924-filestore-dirs-vanished` and
`s-nats-server-lame-duck` on `install-nats-server` (both sharpened rather than merely cited), and
`s-docs-single-server` on the cluster runbook's rollback.

**No strikes.** Four pairs landed as pointer sentences rather than sections, because their material
belongs elsewhere and the page now says where: `s-docs-your-first-cluster` /
`s-nats-server-route-cluster-formation` / `s-docs-forming-a-cluster` on `install-nats-server` (route
formation is the cluster runbook's subject) and `s-docs-rolling-upgrades` on both runbooks
([[upgrade-a-cluster]] owns the procedure).


## 2026-09-01 — consolidate: security, part two (step 6)

*Operation: consolidate*, `inbox/plan-consolidation-2026-08-31.md` step 6. No new sources; nothing in
`raw/` touched.

**Unlanded ripples 105 across 47 pages → 80 across 40.** `concepts/subject-permissions` **6 → 0**,
`concepts/cross-account-sharing` **5 → 0**, `concepts/operator-mode` **5 → 0**,
`entities/nk` **3 → 0**, `concepts/tls-in-nats` **3 → 0**, `entities/nsc` **1 → 0**, and
`operations/backup-and-restore-identity` **2 → 0** — 25 claims. Citation drift 0, `--strict` passes.
Bank **105/83** unchanged; rows 48 and 49 gained further answering pages.

**Mix: 22 real additions, 3 citation-only, 0 strikes.**

**The step's premise held, and it was worth the ordering.** The plan put this after step 2 because
"whatever `account` absorbs will change what these four still owe", and the list had already moved:
`tls-in-nats` came into the step at **3** rather than the plan's 4, and none of the 25 pairs
duplicated what `account` had taken. What was left was the material that genuinely belongs to a
*user*-level page rather than a tenant-level one.

**`subject-permissions`** gained a whole surface it did not have: **two places the permission model
changes shape**. On a leafnode in config mode there are no user permissions at all — `parseLeafUsers`
(`opts.go:3005–3064`) accepts four fields and `permissions` is a parse error — leaving
`deny_exports` / `deny_imports` (deny-only) and the bound account; in operator mode the permissions
travel in the leaf's user JWT, are reversed on the hub side and merge with the leaf's own. With auth
callout the lists are minted per connection, the server auto-denies `$SYS.REQ.USER.AUTH` for every
user on the callout's account, and nothing the client sent is verified first. It also gained the
scoped-signing-key mechanics (edit re-permissions every user on the next push; invisible until
pushed; removing one is mass revocation), the renamed-import rule, and gh#4535's community lock-down
`no_auth_user` — with the observation that its `deny: ["*"]` denies **one token only**, since `*` is
one token and `>` is the form that denies everything. That follows from two claims already sourced on
the page; it is flagged as the weakness in the quoted workaround, not as new server behaviour.

**`cross-account-sharing`** gained the `nats` CLI's two `external` branches, which state the
precondition the docs never do — **the `external` block does not create the import, it names the
local prefix an existing import already lives under**, so Route 1 is a prerequisite for Route 2's
cross-account case, not an alternative. Plus the error a missing far-side export produces
(`service import not authorized` on `$JS.leaf01a.API.CONSUMER.CREATE.tank`, from a thread with **no
maintainer reply**), import/export as account properties, and the leafnode case where this page *is*
the answer to "restrict what a leaf shares".

**`operator-mode`** gained what it replaces (the three config-mode credential styles plus mTLS's
cert-as-credential), leafnode permissions as a genuine operator-mode-only capability, the
certificate-mapped system user that has no password to give a leafnode remote, and the
config-vs-operator asymmetry on shares: config mode stops the server on an unmatched import, operator
mode is silent on **both** halves, with `--token-position` as `nats auth`'s substitute for activation
tokens.

**`tls-in-nats`** gained the reason stream compression exists — "use of filestore encryption can
almost completely prevent host filesystem compression", so the server compresses *before* it
encrypts and `jetstream { key }` without `compression: s2` is the combination that quietly costs the
most disk — plus where TLS sits among the credential styles.

**The two entity pages were pure shape 6** (what the thing does, but not what bites you). `nk` gained
a **What bites** section: a lost seed is a permanently lost identity; an operator backup is a seed in
cleartext unless `--key` encrypts it with a **curve** NKey (a different kind from the Ed25519 keys the
page tabulates), and that curve seed is itself unrecoverable; prefer signing keys to identity keys.
`nsc` gained the two-copies problem — the workstation store versus the server's resolver directory,
which drift silently, where a restored store does not refill the resolver and the symptom is
`Authorization Violation` while every local listing looks right — and `resolver_preload` of the system
account as the bootstrap that belongs in the backup set.

**`backup-and-restore-identity`** was taken with the step rather than left for step 8, to finish the
security layer in one sitting, the way step 4 took `reference/advisories`. It gained what the archive
actually is, the store's real layout (`$XDG_DATA_HOME/nats` — JWTs in `stores`, seeds in `keys`,
nsc-compatible), and the point that after a leak **restoring is not the remedy, revoking is** — a
`user add` JWT never expires, and revocation is an entry in the account JWT, so it too only takes
effect on a push.

**Citation-only:** `s-docs-authorization` on `operator-mode` (the permission rules are unchanged in
JWT form), `s-docs-security-checklist` on `cross-account-sharing`, and `s-docs-operator-mode` on `nk`.
**No strikes.**

## 2026-09-01 — consolidate: tools and entities (step 7)

**Operation: consolidate**, plan `inbox/plan-consolidation-2026-08-31.md` step 7 — every remaining
`entities/` page. Unlanded ripples **80 → 50** (40 → 26 pages); the whole entity layer is now clear.
Citation drift held at **0**, `--strict` passes, broken links 0. Question bank unmoved at **105/83**,
★ **42/42** — no row was earned, and none of the 22 open rows is about a tool or an entity.

**Pages: 14 · claims: 30 · mix: 28 real additions, 2 pointer sentences, 0 citation-only, 0 strikes.**
That is the inverse of step 4's reference-table pass (33 of 46 citation-only there) and it confirms
what step 6 saw on `nk` and `nsc`: **an entity page is almost never merely missing a citation.**
Shape 6 — "what the thing does but not what bites you" — was the whole of this step, on all 14 pages.

**`entities/nats-cli` (11) was the sitting the plan predicted**, and its 11 pairs split 9 additions,
2 pointers:

- **A permissions failure reaches the CLI as a timeout, not a denial.** Every JetStream API call is a
  request, so a locked-down user running `nats stream info` gets `context deadline exceeded` and
  never a permission error; the evidence is server-side and names the CLI by version string. The same
  shape one level up: `nats account info` printing **no `Account:` line at all** is the user being
  denied `$SYS.REQ.USER.INFO`, not a broken server.
- **The `Routes` column of `nats server list` counts connections, not peers** — 2 peers × (3 pooled +
  1 system) = 8 on a healthy three-node cluster. What confirms the mesh is the count being *equal and
  non-zero on every row*, never its value.
- **Every `nats server …` command needs a system-account user**, which the docs' own walkthrough
  configs do not create.
- **The `nats auth` store's location and layout** (`$XDG_DATA_HOME/nats`, nsc-compatible) went into
  the Facts table, which previously named only the context directory; plus the whole backup/restore
  path — `nkey gen curve`, `--key` taking a **file path not a key string**, restore keeping the
  original keys so old creds still work, and the resolver still being empty until you push.
- **`SYSTEM` is pre-created and its user is not**, which is one of the ordinary reasons a push finds
  nothing listening on `$SYS.REQ.CLAIMS.UPDATE`.
- **What `--chunk-size` / `--window-size` actually tune**: the 8 MiB window of 128 KiB chunks and the
  **five-second ack timeout that aborts the backup** — the reason a distant link needs them, not
  throughput.
- **`--trace` on a long `--count` run** as the cheapest demonstration of server-driven failover.
- **Why `nats account tls` exists**: `openssl s_client` against 4222 normally fails, because the
  server sends plaintext `INFO` before the handshake.
- **Never mix CLI and CRD ownership of a stream** — [[nack]] restores a *deleted* stream on its
  ~30-second resync but does not revert a manual `nats stream edit` unless run with `--control-loop`.

**The two pointer sentences, both honest "merely relevant" calls.** `s-docs-single-server`'s
`replicas > 1 not supported in non-clustered mode` is a server rule that already lives on
[[replicas]] — the CLI page takes only the `--server` flag as the alternative to a context and points
there. `s-gh-6605-which-consumer-is-slow` is a thread with no answer: the page records that
**`nats-top` is a different binary with no `nats top` subcommand** and that the suggested
`nats-top -sort pending` was reported not to work, then points at [[slow-consumer-detected]], which
owns the unknown.

**`entities/nats-helm-charts` (4)** gained four behaviours, all of which bite:
`http: "127.0.0.1:8222"` — the standard host hardening answer — is an **outage** here, because the
kubelet's probes dial the pod IP, not loopback; the reloader's real mechanics (inotify, the PID at
`/var/run/nats/nats.pid`, **30 retries four seconds apart**, and `reloader.merge` replacing the
container's args *wholesale* when you add `--force-poll`); the chart's **`jetstream_` → `nats_`
metric rename**, which is why a self-run exporter without `-prefix nats` produces empty panels; and
the chart enumerating peer DNS names rather than one multi-value name, which is the shape a reported
asymmetric-cluster failure comes from copying wrong.

**`entities/nats-server` (2)** gained the **complete signal table** from `server/signal.go` at
v2.14.6 — including the two that bite: `nats-server --signal stop` is **`SIGKILL`**, not a graceful
stop, and **`SIGTERM` is ignored once a drain is in progress**, which is what lets a `preStop` hook
running `--signal ldm` finish. Plus `Trapped %q signal` as the log record of what a node was asked to
do. The CNCF row gained its date and level (**Incubating since 2018-03-15**, still not Graduated).

**The four smallest pages carried the four sharpest facts.** `nats-py`: the client **would not send
credentials when the server's `INFO` omitted `auth_required`**, so an authenticated user silently
landed as the anonymous one — fixed in **v2.4.0**, and Go never had it. `nats-server-2.10`: the same
thread's server-side half, **PR #4605, "will be in 2.10.2"** — before that release, declaring an
`accounts` block ignored top-level `authorization` users outright and accepted credential-less
connections. `nats-server-2.11`: **`allowed_accounts` is 2.11+**, and it is what makes an auth-callout
rollout incremental at all. `nats-server-2.12`: the closest thing to a public support policy — a
maintainer's "2.9.x is now very old, unsupported and 100s of bug fixes behind … You need to upgrade
to 2.12.x", with the asker confirming the upgrade fixed it.

**And four smaller ones.** `cncf`: "almost every repo" is now counted — **30 of 32** Apache-2.0, the
exceptions `nats.ex` and `nats-top`, both MIT. `nats-box`: it is **not** a Docker Official Image
(`natsio/nats-box`) while the server **is** (`_/nats`) — different provenance rules on a cluster that
allow-lists. `nats-js` / `orbit`, from one sentence: `nats.js` is the only client that sends a batched
Direct Get itself, so what is one dependency there is an Orbit dependency in Go, Rust, Java and C# —
which makes **three** features reachable only through Orbit, and the oldest is 2.11, not 2.12.
`synadia-products` gained a **sixth product name, Synadia Control Plane**, known only from a community
reply and recorded as exactly that.

**`entities/nats-architecture-and-design`** was the one page where the landing was a correction: its
"ADRs this wiki has read" line still said **7 of 54** and the real count is **17**. The material from
ADR-31 is sharper than the count: **an ADR can retract its own earlier text in place, with no version
bump** — "Earlier revisions of this document described the server auto-promoting `allow_direct: true`
… servers leave `allow_direct` untouched". `main` is the state and there are no releases, which is
why this wiki mirrors the tarball with a fetch date.

**One number was checked rather than written.** The `cncf` licence row first said "31 of the 33";
counting the rows in `s-github-repo-facts` gave **30 of 32**, and the page says that.

## 2026-09-01 — consolidate: step 8, first sitting — the twelve mid-sized pages

**Operation: consolidate**, plan `inbox/plan-consolidation-2026-08-31.md` step 8, first of its two
sittings: the 12 pages the plan rescoped out of "26 pages carrying one claim each" because they carry
two to five. Unlanded ripples **50 → 14** (26 → 14 pages) — every one of the 36 claims landed, and
what remains is exactly the 14 single-claim rows the second sitting is for. Citation drift held at
**0**, `--strict` passes, broken links 0. Question bank **105/83**, ★ **42/42** — no row moved from
open to answered; **seven rows gained further answering pages** (32, 38, 39, 52, 62, 69, 77).

**36 claims across 12 pages: 35 real additions, 0 pointer sentences, 1 strike that was already
recorded and had never taken effect.** The plan predicted these would be addition-shaped because they
are concept- and operation-shaped, and they were.

**The strike that had not counted.** `s-docs-object-store-your-first-object` struck
`operations/jetstream-sizing` **at ingest**, with its reason written out — but the note sits inside
`## Pages touched` and named the page in wikilink syntax, so `tools/lint.py` went on counting it. The
strike is real and stands; the link is now plain text and the note says why. Swept the rest of the
summary layer for the same shape: **this was the only one**, so the count has been carrying exactly
one false positive, not a systemic one.

**`concepts/key-value` (5)** gained a surface it did not have at all: **`$KV.>` is its own subject
space**, which is why the server's leafnode deny list is three entries —
`["$JS.API.>", "$KV.>", "$OBJ.>"]` — why a deny list meaning to cover KV must name `$KV.>` itself, and
why addressing a bucket in another domain needs the mapping `$JS.<domain>.API.$KV.>` → `$KV.>` that
the source's own comment calls "very very very ugly". Plus the read mechanism (a `_sys_` queue group
of stream peers, so a KV read is load-balanced across R replicas *by design* and the stale read is the
price), the docs' own sentence that "'the latest value for a key' is 'the last message on its
subject'" with the `nats stream get --last-for` line that makes a KV get inspectable without a KV
client, `Lag` as the honest staleness bound on a replicated bucket, and a maintainer's answer that the
shape for a regional read replica is a **leafnode with JetStream sourcing**, not a gateway. One
addition narrows a stated gap: ADR-31's Subject-Appended `$JS.API.DIRECT.GET.<stream>.>` exists "so
that environments may choose to apply subject-based interest restrictions", which makes per-key
**read** sharing expressible as an ordinary subject grant — recorded with both caveats, that it is
reads only and that this wiki has not verified the grant against a running server.

**`operations/jetstream-sizing` (4 → 3 after the strike)** gained the two ways a sizing exercise is
the wrong exercise. `has high message lag` is usually not undersized hardware: "you are sending faster
then the system can process and store messages into the stream. This can happen if you use a core
publish into a stream or if you use async Jetstream publishes with many publishers" — both **remove
the backpressure a synchronous `PubAck` provides**, so no hardware fixes them. And a `store_dir` on
tmpfs is not a memory stream: "we don't support running the JetStream file store on RAM disks", with
the adjacent trap that an unset `store_dir` defaults under `os.TempDir()`, exactly where
`tmpwatch` and `systemd-tmpfiles` look. Plus the memory pairing the page implied but never sized:
**neither `max_memory_store` nor `GOMEMLIMIT` reserves anything at startup**, so the hardened unit's
`MemoryMax=6G` / `GOMEMLIMIT=5500MiB` over a `4Gi` store is the shape to copy.

**`gotchas/jetstream-slows-as-consumers-grow` (4)** was shape 3 throughout — evidence that had reached
other pages and not this one. Cause 4 (churn) now carries the log line that tells churn from count,
`Consumer assignment for '…' not cleaned up, retrying`, its companion tell (**`Consumers: 0` while the
log floods**), and `Readloop processing time: 2m11s`. Cause 3 gained the client feature that silently
turns a filter problem into a consumer-count problem: "watch multiple keys on one watcher" needs
**2.10+**, and below it the same code opens **one consumer per key**. Prevention gained the hard
backstop the page lacked — **`max_consumers` on the account** — with the reason subject permissions
cannot do the job: durable and ephemeral consumers share
`$JS.API.CONSUMER.CREATE.<stream>.<name>` and the `durable_name` is in the payload.

**`operations/upgrade-a-cluster` (4)** gained a precondition that can cost every message: **a roll
destroys R1 memory streams**, with the maintainer's own sequence (`replicas=3`, wait for caught-up,
restart, back to `replicas=1`) and its boundary — "if it's fault-tolerance you need (unscheduled
server restart) then you must use `replicas=3`". Plus the restart trap that only appears on a loaded
server: with no explicit `max_file_store` the ceiling is **75% of what is *free*** at startup, so
every byte JetStream wrote lowers the next start's limit. Plus the client-side timing nobody budgets
for — **~4 minutes** of silence before a default client notices a dead server (two missed pongs on a
two-minute ping interval), which is the argument for draining rather than killing.

**`concepts/direct-get` (3)** gained a second reason to reach for it, and it is a *security* reason
rather than a capacity one: untrusted clients that need history will otherwise create consumers, and
**subject permissions cannot stop them**. It also gained the fact that on a KV bucket `allow_direct`
is not a choice — "we do not support disabling direct get on any buckets" — so the page's own
"`allow_direct` off ⇒ the read hangs" failure cannot happen to a conforming bucket while the stale-read
one always applies.

**`operations/disaster-recovery` (3)** gained the restore advisories
(`$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE/COMPLETE.<stream>`) as free monitoring and as the way to
alert on a restore nobody authorised; the identity-plane sequence, where restoring the operator
backup leaves the **resolver directory empty** and every client fails `Authorization Violation` until
a push, which works only because `server.conf` preloads the `SYSTEM` JWT — "that preload is the
bootstrap path for the whole recovery"; and a pitfall worth the whole entry: **a fresh replica can
resync the damage**. Deleting the PVC and syncing from two healthy replicas reproduced
`Critical write error: malformed or corrupt message`, and the fix was an upgrade, not a recovery.

**`gotchas/slow-consumer-detected` (3)** gained the other half of the relationship and, with it, a
partial answer to one of its own open questions. `/connz` **does** carry a per-connection counter —
**`stalls`** — but it counts the producer being held back, not the reader being dropped; `/varz`
carries **`stalled_clients`**; the log line is `Producer was stalled for a total of %v`; and the stall
is bounded at 2 ms / 5 ms / 10 ms per read-loop invocation. `no_fast_producer_stall: true` trades the
latency problem for a loss problem. The page's *Explained by* section, which read "Nothing yet", now
says **partly**: the stall half has a mechanism, the disconnect half still does not.

**The last five.** `backup-and-restore-jetstream` gained a whole missing surface —
**`nats account backup` / `restore`**, the account-level analogue with its four flags, per connected
account — and the migration the runbook exists for: **a standalone server cannot be clustered in
place**, the streams are deleted on restart before you can raise their replica counts, and the two
supported paths are backup-and-restore or leafnode-mirror-and-promote. `internals/js-api` gained the
mechanism behind its own "info APIs are deprioritised" section: there are literally **two queues**,
and a full one **drains entirely**, sending no reply of any kind — the sharpest server-side cause of a
client `nats: timeout`, traceable only through the rate-limited log line and
`$JS.EVENT.ADVISORY.API.LIMIT_REACHED`. `concepts/leafnode` gained `remotes[].nkey` as a credential
form and the spoofing trap that comes with it (the server verifies **nothing** in `connect_opts`; the
callout service must check `signed_nonce` against `client_info.nonce` itself), plus the cross-domain
failure that names its own subject, `service import not authorized`. `reload-server-config` gained
exports and imports as reloadable, the operator-mode counterpart (`push`, not SIGHUP), and the
pitfall that **`-t` is a parse check, not a start check** — the docs' own composed example passes it
and then refuses to boot. `retention-policies` gained the sentence that makes its table make sense —
on `limits` and `interest` **an ack advances a position, it does not remove a message** — and the rule
that `10099`/`10100` are the contract while their text is not.

**One tool note.** `tools/check-staleness.py` now reports **5** authority-unknown rows rather than 2:
`nats-py`, `orbit` and `synadia-products` began stating a config key or a subject in step 7, and their
`verified-against` names a site capture or a date rather than a release feed. Not stale — correctly
unverifiable by machine, and the report says so.

## 2026-09-01 — consolidate: step 8, second sitting — the fourteen single-claim rows, and the queue reaches zero

**Operation: consolidate**, plan `inbox/plan-consolidation-2026-08-31.md` step 8, second sitting.
Unlanded ripples **14 → 0**. Citation drift **0**, `--strict` passes, broken links 0, orphans 0,
frontmatter clean. Question bank **105/83**, ★ **42/42**; three rows gained further answering pages
(26, 41, 69). **The queue this plan was written to work is empty.**

**14 claims across 14 pages: 13 real additions, 1 citation-only, 0 strikes, 0 pointer sentences.**
The plan expected this sitting to be where "merely relevant" was the honest answer most often and
where the first earned strike would appear. **It was wrong about that, and the reason is worth
recording**: a single-claim row is not a weak pairing, it is a pairing nobody has had a second reason
to revisit. Twelve of the fourteen turned out to be a source explaining something the page already
*asserted* — the explanation, not the claim, was what had never landed.

**That shape, three times over.** `concepts/message-ttl` says mirrors may not set
`subject_delete_marker_ttl` "because inserting new messages would make it impossible to match
sequences" — and the mirror contract that makes that true (a mirrored message "keeps the **same
sequence number, the same timestamp, and the same subject**", a sourced one gets "**fresh sequence
numbers**") was sitting in a summary the page did not cite. Same page, same source: **a mirror keeps
its own retention**, which is what actually produces the audit-trail behaviour the page describes.
`concepts/jetstream-domain` says a domain "does not move data" and points at the `external` block —
without saying that in that block **the domain is not named as a domain**: it is carried as
`$JS.<domain>.API`, which the CLI composes (`mirror.External.ApiPrefix = fmt.Sprintf("$JS.%s.API",
domainName)`) and the server reads back as `tokenAt(ext.ApiPrefix, 2)` (`stream.go:432–437`,
v2.14.6). And `gotchas/streams-not-visible-across-a-leafnode` had the whole server-source rule table
but not the docs' statement of the **mirror-image symptom**: "a stream you create on the factory floor
may land on the hub, not locally" — the same first row of that table, read by an operator standing at
the other end.

**Three additions change what a reader would do.**

- **`concepts/auth-callout`**: credentials are re-offered on **every reconnect**, so a node going down
  produces not just a reconnect storm at the survivors but a **callout storm** at a service whose
  outage already means no new connections. The page's central thesis is "the service is on the
  connection path"; this is the sentence that prices it. Two more from the same source: config-mode
  passwords reach the service as **plaintext** ("bcrypt protects only the config file at rest"), and
  `Authorization Violation` is by design **indistinguishable** from a wrong password or an unknown
  user, so a client cannot tell your service rejected it from the server never having heard of it.
- **`concepts/ack-and-redelivery`**: `max_ack_pending` is **shared by the whole consumer** — "five
  workers get 1000 between them, not 1000 each" — so it doubles as the pool's concurrency ceiling and,
  set below the worker count, starves it: "set it to 3 and only three messages are ever in progress,
  so ten workers leave seven of them idle no matter how much is stored".
- **`concepts/choosing-a-topology`**: a leaf remote's `urls` list is a **reconnect pool for one NATS
  system**, not one entry per cluster. Listing two clusters of a super-cluster builds two bridges into
  the same system that feed each other, and the server's loop guard does not catch this shape. Reach a
  super-cluster through DNS instead.

**Two mitigations landed where the warning lives.** `concepts/ordered-consumer` now carries the lever
that removes whole consumers rather than describing their cost: **multiple filter subjects on one
consumer, 2.10+**, with the trap that a client on an older server silently falls back to one consumer
per key. `operations/rebalance-streams` gained the memory-stream case it had no mention of — the same
grow-and-shrink it already documents, run around a **planned** restart, with the maintainer's boundary
attached: "if it's fault-tolerance you need (unscheduled server restart) then you must use
`replicas=3`".

**And two pages gained a "not here" that saves an hour.** `gotchas/stream-has-high-message-lag` now
says outright that the timeout half of its own symptom pairing **is not in the server log** —
`nats: timeout` is client-side, "the server does not send it and does not log it" — so the two must be
correlated by time, not by grep. `gotchas/jetstream-out-of-disk` gained two more ways `store_dir` is
not where you think: **tmpfs is RAM** and unsupported ("we don't support running the JetStream file
store on RAM disks"), and an unset `store_dir` defaults under **`os.TempDir()`**, where `tmpwatch` and
`systemd-tmpfiles` look.

**The one citation-only pair, named as such.** `operations/rotate-tls-certificates` ←
`s-docs-security-checklist`: every TLS item on the checklist — reload after replacing, files read once
at startup, TLS on the cluster/leafnode/gateway blocks, `serverAuth`+`clientAuth`, the mapped user
matched to the certificate subject, TLS-first with a duration — was **already on the page from other
sources**. The citation is recorded against the checklist's one-line compression of the whole runbook
rather than a manufactured section. No strike: the summary genuinely bears on the page, it just had
nothing left to add to it.

**Also corrected in passing.** `streams-not-visible-across-a-leafnode` carried a *To verify* item
saying the docs' leafnode chapter "has not been ingested — that is plan step 6". It has been since;
`s-docs-leaf-nodes` is what this sitting landed on the page. The stale item is removed.

**The plan is done.** **202 claims** landed over steps 2–8 — **183 real additions, 16
citation-only, 2 pointer sentences, 1 phantom strike** — from **252** at the plan's writing and
**202** when this run of steps began. This session took the last three steps — **80 claims across the
40 pages** lint listed at its start (step 7's 14 entity pages, 8a's 12 mid-sized, 8b's 14
single-claim). Zero strikes earned in-pass across the whole plan, two
pointer sentences, one phantom strike cleared, one docs issue (**#37**) produced, and citation drift
held at 0 throughout.

## 2026-09-01 — scout: delivery timing, and a contradiction three sources cannot settle

**Operation: scout** `delivery-timing` → `inbox/scout-delivery-timing-2026-09-01.md`, and the plan it
produced, `inbox/plan-delivery-timing-2026-09-01.md`. **Nothing ingested.**

**Why this topic.** With unlanded ripples at 0 and ★ complete (42/42), the bank's 22 open rows need
*sources*, not synthesis. Six of them are one mechanism — 16, 17, 18, 19 (redelivery) and 29, 30 (the
message scheduler) — because they are one decision: **a message needs to arrive later than now, so do
you delay the redelivery or schedule the publish?** Row 30 is a maintainer being asked to choose
between exactly those two.

**Eleven candidates, none blocked.** Six GitHub discussions, two Synadia posts, ADR-51, the JetStream
headers reference and the docs' acknowledgment chapter. **Four are already in `raw/`** (ADR-51, the
headers reference, the acknowledgment chapter, and the 2.14 release notes), so most of this topic can
be ingested without fetching anything. Five of the six discussions carry maintainer answers and three
are formally accepted — an unusually high hit rate for this bank, where most rows point at threads
that died.

**Finding 1 — the docs and a Synadia post contradict each other, and an unanswered thread sits between
them.** `learn/jetstream/acknowledgment.md` says three separate times that a consumer backoff does not
slow a nak: "it only shapes redeliveries that fire when the AckWait timer runs out — **it doesn't slow
a nak**" (line 298), "a bare nak redelivers right away, and a configured backoff doesn't slow it"
(586), "the CLI's `--nak` only asks for immediate redelivery" (42). The Synadia reliability post
(Andrew Connolly, 2026-07-24) says the backoff schedule *does* apply to nak-triggered redeliveries.
And **gh#5631 — bank row 18 — reports a nak that did not redeliver immediately** on 2.10.14, with no
error and no reply in the thread, ever. Three positions, and the wiki currently states the docs'.

This is *Operation: record a docs issue* shaped, and the claim is **behavioural**, so the rulebook
requires it to be **run**. The local binary is **v2.14.6** — checked, and exactly the version
[[ack-and-redelivery]] already cites, so a run is attributable without moving any `verified-against`.
The plan's step 2 does it, with all three outcomes routed in advance: docs right → a row against the
blog; docs wrong → a `wrong-value` row against `nats-docs` in three places *and* row 18 explained;
depends on something neither names → `inbox/server-issues.md`, because there is no authority above the
server. **Which one it is has not been guessed.**

**Finding 2 — the message scheduler has no prose anywhere in the documentation.** Checked against the
**live** `docs.nats.io/llms.txt` rather than the 2026-08-31 mirror: no `learn/` page mentions message
scheduling, scheduled messages, cron or delayed publishing. The feature exists in the docs as a header
table, **nine error codes** (10186–10192, 10203, 10212) and three lines of release notes. A 2.12
feature extended in 2.14, with no page telling anyone how to use it — a `missing` row for `nats-docs`,
and the clearest case this wiki has for a page that does not exist: outside ADR-51 and one vendor blog
post there is no readable account of it at all.

**One thing checked and found *not* to be a gap.** `wiki/reference/error-codes.md` carries none of
those nine codes — and that is correct, not a defect. The page states its own scope: "the full 222-row
table is not reproduced here… This page gives the structure, the lookup, and **the codes this wiki
cites**." They join it when a page cites them. Recorded because the opposite conclusion was the
tempting one.

**The plan that came out of it** has four steps, ordered so the falsifiable one comes early: the three
answered threads first (they may already explain half of gh#5631), the server run second, ADR-51 and
the new `message-scheduling` page third, and the applied layer last — because step 4 is the only step
allowed to add pages and has to earn them from the bank. Its dead-letter page is explicitly
conditional: **no public question, no page**, and the refusal gets logged if the search comes up empty.

**Bank unchanged at 105/83.** A scout adds no answers; it says where they would come from. Expected at
the end of the plan: **105/88**, or 105/87 with row 18 as a stated dead end.

## 2026-09-01 — a standing scout backlog

Not an operation of its own: `inbox/scout-backlog.md`, so the next session can pick a scout without
re-deriving the grouping. The bank's 22 open rows split three ways — **6** taken by
`plan-delivery-timing-2026-09-01.md`, **2** by `plan-the-meta-layer-2026-09-01.md`, and the remaining
**14** grouped into three scouts, ordered by how likely each is to produce a finding rather than a
summary:

1. **Mirror and replication internals** (76, 91, 105) — first, because it is runnable and because row
   105 sits directly next to `SI-1`, the `$OBJ.>` / `$O.` deny-list mismatch already recorded in
   `inbox/server-issues.md`. Expect a second `SI-` entry, and check the two are not the same finding.
2. **Stream scale ceilings and the filestore** (4, 5, 9, 13) — row 9's mechanism may already be on
   [[filestore-layout]] and merely unconnected to the question (`index.db` at `len(subject) + 4` per
   subject is a per-subject cost that a high-cardinality space multiplies); row 13 is runnable.
3. **Throughput and memory under load** (8, 10, 11, 68, plus 66) — flagged as the most
   **environment-bound** group in the bank, to be scouted for mechanisms and what to measure rather
   than for figures.

**Two rows are recorded as *not* scouts**, with the reason, so nobody spends a session on them twice:
37 and 40 are ingested by the meta-layer plan's step 2 by URL, and 98's thread is **already ingested**
— `s-gh-5606-cross-account-jetstream` records that the import-ceiling question went unanswered — so it
is a short source read or an honest `no-public-answer`, not a scout.

**Two things were checked rather than assumed** while writing it. Row 25 looked answered — [[publishing]]
has an `## Ordering, and what breaks it` section — but that section is about *JetStream* publish
ordering, and row 25 asks what **core** NATS guarantees, which no page states; it stays open, and is
too thin for its own scout. And row 98's premise was verified against
`raw/nats-server-src/constants-v2.14.6.md`, which holds no import ceiling.

The note the file ends on is the one worth keeping: the easy rows were answered first, so what remains
is disproportionately **the questions nobody public has answered**. `no-public-answer` will be the
right result more often from here, and per the bank's own convention a stated dead end with a date on
it is the most valuable row in the table.

## 2026-09-01 — ingest: three answered redelivery threads (delivery-timing plan, step 1)

*Operation: ingest*, three times, working `inbox/plan-delivery-timing-2026-09-01.md`. Candidates 1, 2
and 4 of `inbox/scout-delivery-timing-2026-09-01.md`, fetched through the GitHub GraphQL API into
`raw/gh-discussions/` and recorded in `raw/sources.md`.

**Fetched:** `gh-6628.md`, `gh-6350.md`, `gh-4972.md` — and `gh-5631.md`, which belongs to step 2 but
was fetched in the same call. It has **zero comments** and is stored for the same reason `gh-7017` is:
an unanswered public question is evidence.

**Summaries created (3):** [[s-gh-6628-ackwait-vs-dupe-window]] · [[s-gh-6350-exponential-backoff]] ·
[[s-gh-4972-nak-with-delay-blocks]].

**Pages updated (5):**

- [[ack-and-redelivery]] — a new `## Retry: two mechanisms, one shared budget` with three parts: the
  implicit/explicit split from @jnmoyne's marked answer; the delayed-nak-holds-its-slot constraint
  with @ripienaar's reason and @derekcollison's dissent in the same thread; and a flat statement that
  the duplicate window has nothing to do with redelivery. The `## To verify` bullet for Q19 was
  **retired** — it is now answered on the page rather than listed as unknown.
- [[publishing]] — `### The window bounds re-*publication*, not re-*delivery*`, under *Limits and
  failure modes*.
- [[consumer]] — `## The batch is on the clock, all of it`: `ack_wait` starts on the whole batch, not
  on the message being worked, which is what actually caused gh#6628's redeliveries.
- [[worker-pool]] — `## Retries come out of the same budget as concurrency`, with the stall signature
  (`Outstanding Acks` at maximum, every worker idle) and why extra consume loops buy nothing.
- [[jetstream-sizing]] — `### A retry policy is a capacity input`, with the sleeping-slot arithmetic
  marked as derived from the constraint rather than quoted from a source.

**Question bank:** rows **16**, **17** and **19** filled. Row 18 deliberately untouched — it is step
2's, and it is the one that needs the binary.

**`inbox/docs-issues.md`:** nothing added. All three threads are consistent with the docs and with the
server as this wiki already states it; the contradiction this plan exists to settle is in step 2's
source, not in these.

**One thing worth recording about age.** gh#4972 is from 2024-01-18 and both maintainers describe the
`max_ack_pending` behaviour as current *"today"*, with @derekcollison arguing in the thread that it
should change and **no fix version named anywhere**. The page states it against v2.14.6 because step 2
re-ran it on that binary, not because a 2024 thread is authority for a 2026 release.

## 2026-09-01 — ingest + run: the nak/backoff contradiction, settled on the binary (delivery-timing plan, step 2)

The step the plan was written for. Three public sources disagreed about whether a consumer `backoff`
affects a nak; the claim is behavioural, so per `CLAUDE.md` it was **run**, not read. **Both published
answers turned out to be wrong.**

**Source ingested:** the Synadia post *Reliable Message Delivery in NATS JetStream* (Andrew Connolly,
2026-07-24) → `raw/synadia-blog/jetstream-reliable-delivery-dlq-replay.{html,txt}`,
[[s-synadia-reliable-delivery-dlq]]. Also [[s-gh-5631-nak-not-immediate]], row 18's own thread —
**zero comments in two years**, recorded as unanswered.

**Run:** `raw/nats-server-src/nak-backoff-observed-v2.14.6.md` — thirteen experiments on
**nats-server v2.14.6** (`nats-server --version` checked first; it matches what
[[ack-and-redelivery]] cites) with **nats CLI 0.4.0**, plus three ranges of `server/consumer.go` at
the tag. The instrument is `raw/nats-server-src/nats-probe-client.py`, a ~90-line stdlib-only NATS
client written for this, because **nats CLI 0.4.0 cannot send a delayed nak at all** — `nats consumer
next` has `--ack`, `--nak`, `--term` and no delay flag. Summary: [[s-nats-server-nak-backoff-observed]].

**The result, which is neither of the two answers on offer:**

- A **bare** `-NAK` is redelivered immediately, with or without a backoff — **0.00s**. The docs are
  right about this case and the blog is wrong.
- A nak **carrying a delay** waits `delay + (backoff[dc] − backoff[0])`. Asking for 2s gave
  **2.000 · 7.000 · 12.000 · 12.001** seconds; asking for **zero** delay gave **0.00 · 4.94 · 9.94**.
  The docs' "it doesn't slow a nak" is wrong here.
- **`-NAK {}` is not a bare nak** — the server branches on anything after `-NAK`, and an empty options
  object parses to a zero delay, so two clients implementing the same API call can differ.
- `ack_wait` set beside a `backoff` is silently overwritten by the first backoff entry, **in the
  server** (`consumer.go:658`) — the blog's own Go snippet stores `ack_wait: 1s` where it reads 30s.
- Row 19 **re-run on 2.14.6** rather than inherited from a 2024 thread: cap 2, both messages nak'd
  with a 30s delay, next pull returns `408` and nothing.

Two controls make the negatives real: no answer at all redelivers on the documented schedule
(**5.00 · 10.00 · 15.00**, so the backoff is not inert), and delayed naks on a backoff-free consumer
are exact (**1.95 · 1.95 · 1.95**).

**A harness bug is recorded in the transcript on purpose.** The first run created every consumer with
**no filter subject** on a `test.>` stream, so consumers shared each other's messages and the delivery
counts read `1, 1, 2`. Every table since carries the stream sequence beside the delivery count.

**Recorded in three places, as the rulebook requires when one finding is both:**

- `inbox/docs-issues.md` **#38** — `learn/jetstream/acknowledgment.md`, `wrong-value`, `high`,
  `destination: nats-docs`. Deliberately **not ★**: the retry still happens, only its timing is wrong.
- `inbox/docs-issues.md` **#39** — the Synadia post, `wrong-value`, **★ high**, `destination: Synadia
  blog` — a **new destination value**, noted in that file's legend. ★ because its copyable snippet
  gives a reader a 1-second ack deadline where the code says 30.
- `inbox/server-issues.md` **SI-2** — `unexpected`, `high`, the behaviour itself, with the question
  that would settle it and the four things not tested. #38 and SI-2 point at each other.

**Neighbour sweep** (required when a page is wrong): every timing claim in the acknowledgment chapter
was checked against the same binary — **five checked, one wrong**. The default `ack_wait` of 30s, the
backoff reusing its last entry, `--nak` being immediate-only, and "a plain nak redelivers immediately"
all hold.

**Pages updated (6):** [[ack-and-redelivery]] (three new sections — *What a delayed nak actually
waits*, *`ack_wait` beside a `backoff` is silently discarded*, *Why a nak never reports a failure* —
plus the older `Backoff` bullet, the nak row of the four-answers table and failure mode 3 corrected to
match, and `verified-on` moved to 2026-09-01) · [[consumer]] · [[worker-pool]] · [[advisories]] ·
[[direct-get]] · [[retention-policies]].

**Question bank:** row **17** and row **19** completed, row **18** filled and flagged `measured` — the
wiki answers the question from the binary while stating that the thread it came from was never
answered and that the reporter's 2.10.14 case is not confirmed. Lint: 0 unlanded ripples, 0 citation
drift.

## 2026-09-01 — ingest + run: the message scheduler, and the page that should exist (delivery-timing plan, step 3)

Four sources ingested and one new page written. ADR-51 is the **only real description of this feature
in public**, so rather than paraphrase it, every rule in it that could be checked was **run** on the
binary — 26 publishes and 4 stream operations on **nats-server v2.14.6** with **nats CLI 0.4.0**.

**Summaries created (4):** [[s-adr-51-message-scheduler]] (Approved, 8 revisions, 2.12 → 2.14) ·
[[s-docs-jetstream-headers]] · [[s-gh-7672-cron-schedules]] · [[s-gh-7628-scheduler-vs-nak]] · plus
[[s-nats-server-message-schedules-observed]] for the run
(`raw/nats-server-src/message-schedules-observed-v2.14.6.md`).

**New page:** [[message-scheduling]] — licensed by bank rows 29 and 30, which no page owned.

**Everything ADR-51 states held on 2.14.6**, including revision 8's Discard New rule, whose server
version the ADR still records as `TBD`. The run's own additions:

- **Ten scheduler error codes, not nine** — `10223 JSMessageSchedulesTimeZoneInvalidErr` joins the
  nine the scout counted — each pinned to its exact condition off the `PubAck`.
- **`10189` has at least four unrelated causes** and names none: a five-field cron, `@every` under
  `1s`, a time zone on a non-cron schedule, and a 2.14 expression on a 2.12 server.
- **The two stream-level refusals arrive as `10052`**, the generic `JSStreamInvalidConfigF`, so the
  reason lives only in the message text.
- **`allow_msg_schedules` stores `allow_rollup_hdrs: true` and `deny_purge: false`** — observed, not
  just specified, which is why it also reached [[subject-permissions]].
- **`nats pub` without `-J` is a core publish and hides a rejected JetStream publish.** This produced
  a **false first result** — every invalid publish appeared to be accepted — and is recorded in the
  transcript, on [[publishing]] and on the new page.
- **nats CLI 0.4.0's `--schedule-after` cannot work**: it emits `Nats-Schedule: <RFC3339>` with no
  `@at ` prefix and is always rejected with `10189`. Caught from the server's `-DV` trace.

**Two things the plan and the scout had slightly wrong, corrected from the source rather than
repeated:** the `@every` minimum is **`1s`**, not `1m` (`@every 1m` is ADR-51's example), and there
are **ten** error codes, not nine.

**Pages updated (10):** [[message-ttl]] (the load-bearing link — the scheduler is built on it) ·
[[error-codes]] · [[publishing]] · [[stream]] · [[retention-policies]] · [[mirrors-and-sources]] ·
[[subject-permissions]] · [[js-api-subjects]] · [[nats-server-2.12]] · [[nats-server-2.14]]. The
ADR-51 row of `inbox/adr-toc.md` now links its summary.

**`inbox/docs-issues.md` — three rows:**

- **#40** — `nats pub --schedule-after`, `destination: natscli`, a **new destination value** noted in
  that file's legend. `high`, not ★: the flag implies `--jetstream`, so the error is printed.
- **#41** — the header reference calls `Nats-Scheduler` a "Scheduler ID" and `Nats-Schedule-TTL` a
  TTL for *the schedule*; both are wrong, and the second is silent — a schedule set to expire itself
  never does.
- **#42** — no prose page anywhere, confirmed against the **live** `docs.nats.io/llms.txt` on the day.
  The neighbours were swept rather than assumed: 2.12 has 3 of 18 bullets linking only to an ADR and
  2.14 has 4 of 15, so scheduling is not unique — what distinguishes it is being announced **four
  times across two releases** while comparable features (priority groups, atomic batch) got chapters.

**Question bank:** rows **29** and **30** filled. Lint: 0 broken links, 0 unlanded ripples, 0 citation
drift, 0 pages missing from the index.

## 2026-09-01 — ingest: the applied layer, and a dead-letter page the bank had to earn (delivery-timing plan, step 4)

**Source ingested:** *Delayed Message Scheduling in NATS JetStream* (Peter Humulock, 2026-04-09) →
[[s-synadia-delayed-scheduling]]. Its four caveats were each checked against ADR-51 and the binary:
past-dated schedules firing immediately, one schedule per subject, mirrors/sources refused, and DST —
**all confirmed** except DST, which needs a clock and was not tested. It also states a rule the
specification does not: **the target may not be the schedule's own subject**, which the server
enforces with `10190` (run and appended to
`raw/nats-server-src/message-schedules-observed-v2.14.6.md`). Where the blog and the ADR give
different advice about stale schedules, the page says so and prefers the ADR.

**Not recorded as a docs issue:** the ADR's silence about that target rule is an omission, not a
contradiction — `enhancement` at most — so it is stated on [[message-scheduling]] and left out of the
report rather than inflating it.

**The dead-letter page: the scope test ran, and the bank passed it.** `CLAUDE.md` is explicit that no
question means no page, so GitHub issues and discussions were searched before anything was written.
Two real public questions turned up, and both are now bank rows with their URLs:

- **Q106** — [gh#4994](https://github.com/nats-io/nats-server/discussions/4994), answered by
  @derekcollison: *"We do not have automated DLQs… by design since we truly separate consumers from
  stream semantics."* Plus the finding that makes the row `★`: **with no client fetching, `ack_wait`
  expiring does not advance a pull consumer's delivery count**, so a pool scaled to zero produces no
  redelivery, no advisory and no dead letter — and every number looks calm.
- **Q107** — [gh#7590](https://github.com/nats-io/nats-server/discussions/7590), still open: the
  advisory carries **no payload**, and @ripienaar explains the objection is that payloads may be
  sensitive and advisories leave NATS.

**Summaries created (3):** [[s-synadia-delayed-scheduling]] · [[s-gh-4994-scale-to-zero-dlq]] ·
[[s-gh-7590-dlq-payload-loss]]. **New page:** [[dead-letter-queue]] (`kind: pattern`).

**A public disagreement settled on the binary.** gh#7590's reporter says a max-delivered message is
gone from the stream; a later commenter says it is still there. Run at v2.14.6 R1 on **both**
`workqueue` and `limits` streams: the advisory fires and **the message survives and is fetchable by
the sequence the advisory names** — the commenter is right. The reporter's failure was real on their
version: issue #7817 lost max-delivered messages on **R3 WorkQueue** streams at 2.12.3/2.12.4, fixed
by PR #7845 and shipped in **2.12.5**, quoted from that release's notes. Both halves are now on
[[ack-and-redelivery]] and [[retention-policies]] with the version attached.

**Pages updated (6):** [[message-scheduling]] · [[mirrors-and-sources]] · [[message-ttl]] ·
[[ack-and-redelivery]] · [[advisories]] · [[consumer]] · [[retention-policies]].

**Lint:** 0 broken links, 0 orphans, 0 citation drift, 0 unlanded ripples, 0 pages missing from the
index.

## 2026-09-01 — plan finished: delivery timing, and what it settled

`inbox/plan-delivery-timing-2026-09-01.md` is done, all four steps, with the two-line result written
at the top of the file.

**The scoreboard.** Question bank **107 rows, 91 answered, 16 open**; ★ complete at **43/43**. All six
rows the plan targeted are closed (16, 17, 18, 19, 29, 30), and the work earned two more (106, 107),
each with the URL of someone publicly asking it. Row 18 closed **properly** rather than as a stated
dead end, because the run explained the symptom rather than just failing to find an answer.

**What was produced.** Eleven summaries, two new reader pages ([[message-scheduling]],
[[dead-letter-queue]]), around twenty existing pages rippled, and **two run transcripts** in
`raw/nats-server-src/` — the nak/backoff experiments and the message-scheduler experiments — plus a
purpose-written stdlib NATS client (`nats-probe-client.py`), which existed because **nats CLI 0.4.0
cannot send a delayed nak at all**.

**Six findings recorded**, four of them impossible to reach without running the binary:

| record | what it is |
|---|---|
| docs-issues **#38** | `nats-docs`: "a backoff doesn't slow a nak" is true of a bare nak and false of a delayed one |
| docs-issues **#39** ★ | a Synadia post: recommends the one nak a backoff does not shape, and its snippet silently gives a 1-second ack deadline |
| docs-issues **#40** | `natscli`: `nats pub --schedule-after` emits a schedule the server always rejects |
| docs-issues **#41** | `nats-docs`: the header reference misdescribes `Nats-Scheduler` and `Nats-Schedule-TTL` |
| docs-issues **#42** | `nats-docs`: the message scheduler has no prose page at all, verified against the live `llms.txt` |
| server-issues **SI-2** | the delayed-nak timing arithmetic, with the question that would settle it |

Two new `destination` values entered the report — a **published blog post** (#39) and **`natscli`**
(#40) — and the file's legend now says so.

**Three things worth carrying forward as method**, all recorded in the transcripts rather than tidied
away:

1. **A harness bug produced a plausible false finding**, twice. First, consumers created with no
   filter subject shared each other's messages, so delivery counts read `1, 1, 2`. Then `nats pub`
   without `-J` reported every rejected schedule as published, because a core publish has no reply
   subject to carry the `PubAck`. Both are in the raw files, with what changed to catch them.
2. **Two of the plan's and scout's own numbers were wrong** and were corrected from the sources rather
   than repeated: the `@every` minimum is `1s`, not `1m`, and there are **ten** scheduler error codes,
   not nine.
3. **A public disagreement was settled by running it** rather than by picking a side — whether a
   max-delivered message survives on a WorkQueue stream. It does, at 2.14.6; the reporter who said
   otherwise was hitting a real defect fixed in **2.12.5**.

**Next.** The bank's 16 open rows are the three clusters `inbox/plan-the-meta-layer-2026-09-01.md` and
the standing scout backlog already name. Nothing from this plan is left open.

## 2026-09-01 — ingest + run: the meta layer, from `jetstream_cluster.go` and a three-node cluster (meta-layer plan, step 1)

**Operation:** ingest `server/jetstream_cluster.go` (with `raft.go`, `jetstream_api.go`,
`monitor.go`, `jetstream.go`, `server.go`, `opts.go`, `errors.json`) at **v2.14.6**, read for the
plan's five questions rather than summarised, then **run**: a three-node cluster on the v2.14.6 binary
with nats CLI 0.4.0. Baseline measured before starting, as the plan asked: unlanded ripples **0 across
0 pages**; bank 107 rows / 91 answered.

**Raw:** `raw/nats-server-src/jetstream-cluster-v2.14.6.md` (65 quoted ranges with real line
numbers) and `raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md` (thirteen numbered
observations plus what was not tested). `raw/sources.md` row updated.

**Created:** `wiki/summaries/s-nats-server-jetstream-cluster.md` (one summary over both raw files);
**`wiki/internals/meta-layer.md`** — the wanted page five pages already pointed at.

**Updated (16, each now citing the summary):** `raft-in-nats` (new section *What the meta layer adds*;
heartbeat/election To-verify item **settled** — constants, no config key; `/jsz?meta=1` corrected),
`replicas` (meta replica-count To-verify item **settled** — there is none; new section on a
timed-out publish), `streams-deleted-when-clustering-a-standalone-server` (the orphan check reproduced,
with the 30-second timer), `jetstream-domain` (observer mode and `extension_hint`),
`no-suitable-peers-for-placement` (the pre-leader timeout explained), `js-api-subjects` (two wrong
subjects corrected against the server; two undocumented subjects added), `monitoring-endpoints`
(`meta_cluster` fields, the five `/healthz` meta messages), `error-codes` (10008, 10039, 10044, 10202),
`advisories` (the `SERVER.REMOVED` body observed), `choosing-a-topology` and `gateway` (global-quorum
To-verify items **settled** from the source), `multi-region-jetstream`, `nats-timeout`,
`disaster-recovery` (peer-remove: reply after quorum, the misleading CLI message, the five-minute
rejoin), `upgrade-a-cluster` (the meta leader's own transfer on shutdown), `build-a-3-node-cluster`
(the meta log lines to expect). `verified-against` raised to 2.14.6 / 2026-09-01 on the eleven pages
whose facts were re-checked on the binary or the source; left alone on the rest.

**What the run settled that reading could not:** bootstrap elects in 0.28 s, recovery in 5.3 s, a
stepdown in 0.5 s, a SIGKILLed leader in 3.5 s; a lone survivor **claims meta leadership for 10 s**
after losing its peers (healthz ok, `10008` only afterwards); a create or publish that timed out is
committed if the old leader re-wins and discarded if not — observed both ways; a standalone server's
stream is deleted **30.0 s** after joining; a peer-removed server that keeps running is **re-added
after five minutes**, with no log line. And `nats pub -J` prints `Published` before waiting for the
ack — the raw file records the column that invalidated.

**Docs issues, four new (42 → 46), each verified against the source and two on the wire:**

| record | what it is |
|---|---|
| docs-issues **#43** ★ | `nats-docs`: the API reference's `$JS.API.META.SERVER.REMOVE` and `$JS.API.ACCOUNT.PURGE` are not the subjects the server serves; 98 subject mentions swept, 5 wrong, all these two; the purge row's system-account column is wrong too |
| docs-issues **#44** | `nats-docs`: nothing says a standalone server's streams are deleted when it joins a cluster, on the migration the topology chapter narrates |
| docs-issues **#45** | `nats-docs`: the meta API reference is called "the full set" and omits the two stream-move subjects |
| docs-issues **#46** | `nats-docs`: `extension_hint` is documented without its purpose or its two values |

**Index:** `meta-layer` under Internals, the summary under Summaries, Wanted pages down to two
(`consumer-keeps-redelivering`, `stream-leader-keeps-moving`), the docs-issues count and routing line
corrected (it had been left at 36).

**Question bank:** 107 rows / **91** answered → 91. Q36 and Q38 gained `[[meta-layer]]`; Q40's
peer-remove half is now observed but the thread is step 2's, so the row stays open.

**Step 3, partly done early:** two of its four items — the heartbeat/election keys and the global-quorum
claim — were settled by this read. `/raftz` and compaction remain.

**Lint:** clean — broken links none, citation drift 0, **unlanded ripples 0 → 0**, staleness 0 behind
2.14.6. The cluster (n1–n4) was left running on ports 4291–4294 for step 3's `/raftz` run.

## 2026-09-01 — ingest + run: two unanswered threads, `stream-leader-keeps-moving` and `evict-a-sick-server` (meta-layer plan, step 2)

**Operation:** ingest `nats-io/nats-server` discussions **#7533** (Q37) and **#6892** (Q40), fetched
through the GraphQL API into `raw/gh-discussions/gh-7533.md` and `gh-6892.md`. **Both had zero
comments and no answer.** Per the plan, neither page manufactures the thread's answer: each maps the
report to mechanisms this wiki has already verified and says what stays unexplained. Then a short read
of `mqtt.go`, `events.go`, `server.go` and `jetstream_cluster.go` at v2.14.6
(`raw/nats-server-src/kick-ldm-and-mqtt-session-v2.14.6.md`, nine ranges) and a **run** of the two
per-client system requests against a live client on the step-1 cluster
(`raw/nats-server-src/kick-ldm-observed-v2.14.6.md`).

**Created:** `wiki/summaries/s-gh-7533-quorum-loss-mqtt.md`,
`wiki/summaries/s-gh-6892-evict-a-sick-node.md`, `wiki/summaries/s-nats-server-kick-ldm-mqtt-session.md`;
**`wiki/gotchas/stream-leader-keeps-moving.md`** — symptom-first, six causes ranked (a peer quiet for
ten seconds; 2.14 overrun stepdown; `resetClusteredState`; deliberate transfers; membership churn
including the five-minute rejoin; pre-2.12 empty-state elections), each with *how to confirm* and *the
fix* from pages already sourced, and gh#7533's sequence traced line by line — `10071` to
`mqttSession.save`'s `Nats-Expected-Last-Subject-Sequence` header, `10008` to the meta layer, the
`MS` timeouts and `NO quorum` to the stream and consumer groups — with the first line's cause named as
the part nobody has explained; **`wiki/operations/evict-a-sick-server.md`** (runbook) — decided from
the thread, which gave no procedure and no existing runbook owned one: stepdown, peer-remove (and its
five-minute undo), `KICK` per cid through the sick server, the `LDM` request that only informs, what
no request can do (by IP, in bulk, or to routes), and the platform as the reliable half.

**Updated (4):** `mqtt` (the `10071` / `10008` pair as cluster errors), `slow-consumer-detected` (a
route slow consumer removes a server from its peers, not from its clients), `raft-in-nats` and
`meta-layer` (pointers to both new pages with the thread citations). The last wanted gotcha pointed
at from `raft-in-nats` and `advisories` now exists; **Wanted pages is down to one**
(`consumer-keeps-redelivering`).

**What the run settled:** `KICK` closes the connection — `>>> Disconnected due to: EOF, will attempt
reconnect`, back on another server in 2.5 s; `LDM` sends an INFO with `ldm: true` and nats CLI 0.4.0
stayed connected; an unknown cid answers `no such client or leafnode id`; the per-server request set at
2.14.6 is `KICK`, `LDM`, `RELOAD` and the `z` endpoints, all executed by the server named in the subject.

**Question bank:** 107 rows, **91 → 93** answered. Q37 marked `no-public-answer` with the page in bold;
Q40 answered by the runbook and `meta-layer`, flagged `observed`, with the row noting the thread itself
got no reply. Docs issues: none this step.

**Lint:** clean — broken links none, citation drift 0 after one repair (`mqtt`'s frontmatter), unlanded
ripples **0 → 0**, staleness 0 behind 2.14.6. The cluster stays up for step 3.

## 2026-09-01 — ingest + run: `/raftz`, and the reference page that was supposed to document it (meta-layer plan, step 3 — plan finished)

**Operation:** ingest `reference/system/monitor/raftz.md` from the mirror (re-fetched live the same
day: **173 bytes**, two request options, no response fields), read `Raftz`, `RaftzGroup`,
`RaftzGroupPeer` and `HandleRaftz` in `monitor.go` at v2.14.6 plus the parameter-decode lines of five
sibling handlers, and **run** the endpoint on the step-1 cluster — follower and leader views, six
filter combinations, and the documented `account=` parameter shown ignored on `/raftz` and `/accountz`
(`raw/nats-server-src/raftz-v2.14.6.md`, 12 ranges plus the observations).

**Created:** `wiki/summaries/s-docs-monitor-raftz.md`, `wiki/summaries/s-nats-server-raftz.md`.

**Updated (4):** `monitoring-endpoints` (the `/jsz`, `/raftz` and `/accountz` rows now carry the
HTTP names; a `/raftz` section with the full field set and the `acc`-defaults-to-`$SYS` rule; *A docs
error worth knowing* on the six pages that print payload names), `raft-in-nats` (its last `## To
verify` item settled; the *Where it lives* sentence corrected — the docs claim compaction, snapshot
timing and batching are "documented with `/raftz`" and they are not; a new section with the endpoint
and a **table of the constants** the docs promised: heartbeat 1 s, election 4–9 s, lost-quorum 10 s,
append batch 256 KB / 512 entries, meta / stream / consumer snapshot thresholds, the 5-minute
peer-remove timeout, the 48-hour observer timer), `stream-leader-keeps-moving` (triage gains the
per-group `term`, `overrun`, `catching_up` view), `meta-layer` (the `_meta_` group as `/raftz` shows it).

**Docs issues, two new (46 → 48):**

| record | what it is |
|---|---|
| docs-issues **#47** | `nats-docs`: the `/raftz` reference page is empty of response fields while three learn pages promise "the full field set", heartbeat intervals, batching and log compaction there — none of which is a field or a key |
| docs-issues **#48** ★ | `nats-docs`: six monitor reference pages (`accountz`, `jsz`, `leafz`, `subsz`, `gatewayz`, `raftz`) print the `$SYS.REQ.SERVER.PING.<Z>` payload names as the endpoint's request options; the HTTP handlers ignore them, observed (`/accountz?account=NOPE` → the normal page, `?acc=NOPE` → `400`). 14 pages swept; `connz` and `healthz` are right |

**The plan is finished.** Its *Done when* list, checked: `meta-layer` and `stream-leader-keeps-moving`
exist and are cited by every page that pointed at them; Q37 carries a written reason it cannot be
answered and Q40 is answered from the source and a run; every `## To verify` item on `raft-in-nats` is
settled. Two-line result written at the top of `inbox/plan-the-meta-layer-2026-09-01.md`, with the
next plan proposed there.

**Numbers for the whole plan:** pages **276 → 285** by `tools/lint.py`'s count (3 reader pages, 6 summaries); bank 107 rows,
**91 → 93** answered; docs issues **42 → 48** (two ★); unlanded ripples **0 → 0** at every step;
wanted pages 3 → **1** (`consumer-keeps-redelivering`); binary and every `verified-against` touched
at **2.14.6**. The scratch cluster (n1–n4) is stopped; its logs stay in the session scratchpad.

**Lint:** clean — broken links none, citation drift 0, unlanded ripples 0, staleness 0 behind 2.14.6.

## 2026-09-02 — lint: the viewer's broken links that `tools/lint.py` could not see (frontmatter parsing)

**Symptom** (reported by the user from the built site): on `mqtt` the *sources* row carried a link to
`wanted/[s-docs-mqtt-your-first-mqtt-client, s-docs-mqtt-topics-and-subjects,.html`, while lint reported
*broken links: none*. A fresh build showed the same on five more pages, plus a bogus `since` chip on
`priority-groups` reading `[2.11]   # overflow and pinned_client; …`.

**Cause:** the two tools parsed the frontmatter differently. `tools/lint.py` reads a `sources:` list with a
multi-line regex; `tools/build-site.py` read the block one line at a time, so a `sources:` list wrapped
over several indented lines became the single "slug" `[s-a, s-b,` (rendered as a wanted page) and a
trailing YAML `# comment` stayed inside the value. `tools/add-section.py` had the same one-line regex
and silently skipped the frontmatter on those pages; `tools/check-staleness.py` truncated their
*verified from* column the same way.

**Fixed, in `llm-wiki-starter` and pushed here with its `update-tools.sh`** (`build-site.py`,
`add-section.py`, `lint.py`; lint also picks up the starter's newer `section()` — it was one commit
behind, with no local changes): the viewer's `parse_frontmatter` now joins wrapped values, accepts
block lists (`key:` then `  - a`) and drops trailing comments outside quotes; the ripple helper's
`sources:` match spans lines and rewrites the list on one line; lint's `fm_list` tolerates a comment
after `]`. **Also in `add-section.py`, while it was open:** the `## Sources` append is bounded to its
own section — it used to land on the last line of the page, i.e. inside `## To verify` when one
follows (the drift seen on 2026-09-01 on `jetstream-domain` and `multi-region-jetstream`). Tested on
scratch copies of `jetstream-domain` and a re-wrapped `websocket`. The local `check-staleness.py`
joins continuation lines. Starter self-test passes; the starter's changes are uncommitted there.

**Pages normalised** (frontmatter only, `sources:` unwrapped onto one line, no claim touched):
`object-store`, `websocket`, `filestore-layout`, `run-nats-behind-a-proxy`, `defaults-and-limits`.
`CLAUDE.md` gains the convention: one line per frontmatter key.

**After:** built site has exactly one wanted link, `consumer-keeps-redelivering` (5 pages), as
lint says; `priority-groups` shows `2.11+`; lint clean (broken links none, citation drift 0,
unlanded ripples 0, staleness 0 behind 2.14.6); `inbox/staleness.md` unchanged.

## 2026-09-02 — repo: published to GitHub

Pushed to https://github.com/M64GitHub/nats-wiki, public, under Apache-2.0 (`LICENSE` added, README
gains a *License* section saying what `raw/` keeps of its own). `site/` stays git-ignored; `raw/` is
published in full, the user's decision. The goal stated for the repo: anyone can clone it and run
their own agent in it.

## 2026-09-02 — rulebook: the scope test retired, posed questions allowed

The user's call, after the state-of-the-wiki review: "no question, no page" with a public URL behind
every row seeded the bank well but now blocks the pages the wiki most needs — design and
architecture questions are rarely asked in one public thread in the form an architect holds them.
`CLAUDE.md` *The question bank* rewritten: the test for a page is the reader in *Focus*; a row may be
*asked* (URL) or *posed* (`own` in `asked at`); a `design` flag marks architecture questions answered
by `kind: pattern` pages; *Operation: consolidate* item 3 loses "No question, no page". Same change
in the bank's header, the map line and the README line; `wiki.json` gains a `design` filter on the
Questions table. No rows changed.

## 2026-09-02 — bank: seeded with 30 posed design rows (108–137)

The first use of the retired scope test. Thirty `design` rows, `asked at` = `own`, one per
architecture decision: stream-per-tenant vs prefix, subject hierarchy and cardinality, retention
choice, one stream vs many for fan-out, dedup by `Nats-Msg-Id` vs expected-sequence, replica count
and storage, mirror vs source vs filtered consumer, consumer design for N replicas, worker-pool
tuning, durable vs ephemeral, KV bucket design and KV uses, object store vs blob storage, accounts vs
subject permissions, operator mode vs config vs auth callout, per-account limit apportioning,
topology for multi-region, edge with intermittent links, 3 vs 5 across zones, role partitioning,
capacity planning, minimum alert set, rolling-upgrade design, Kubernetes vs VMs, backup/DR design,
core vs JetStream, a service layer on core NATS, large messages, migrating from Kafka/RabbitMQ,
built-in MQTT vs a broker. **8 filled** from pages whose sections state the answer (`publishing`,
`stream`, `replicas`, `worker-pool`, `ack-and-redelivery`, `choosing-a-topology`,
`multi-region-jetstream`, `jetstream-sizing`, `upgrade-a-cluster`, `disaster-recovery`,
`backup-and-restore-jetstream`); **22 open**. Bank 107 → **137 rows, 101 answered**.
`inbox/scout-backlog.md` gains section 5 with the two scouts these rows call for. No page changed.

## 2026-09-02 — rulebook: a git-ignored local overlay, `local/CLAUDE-MD-EXTENSION.md`

`CLAUDE.md` now says: if `local/CLAUDE-MD-EXTENSION.md` exists, read it after the rulebook, and where
the two conflict the overlay wins. `local/` is git-ignored (`.gitignore`) and listed in the README's
layout table so anyone who clones the repo can carry their own instructions without touching the
public rulebook. Here it holds the maintainer's multi-session programme (`local/megaplan.md`, started
2026-09-02, entered with "start the megaplan") — a tracker, not wiki content: every source, plan,
scout and page it produces goes into the public tree as usual.

## 2026-09-02 — plan: the lab, step 1 — `tools/lab/cluster.sh`

Phase A of the maintainer's programme, `inbox/plan-the-lab-2026-09-02.md`. `tools/lab/cluster.sh`
(`up [n]`, `down [--purge]`, `status`, `logs k`, `conf k`, `stop k [-9]`, `start k`, `url k`) and the
two templates in `tools/lab/conf/` render and start the scratch cluster every
`raw/nats-server-src/*-observed-v2.14.6.md` run described in prose: `n1`…`n4`, cluster `east`, ports
`429k` / `629k` / `829k`, a `$SYS` user `sys`, JetStream stores under `${TMPDIR:-/tmp}/nats-lab`,
nothing in the repo. `up` prints `nats-server --version` and refuses a binary that is not
`NATS_LAB_VERSION` (default `v2.14.6`), so a run is always attributable to the release the pages'
`verified-against` names. Verified: `up 3` healthy in 0.9 s; `nats server report jetstream` shows
the meta table with the same peer ids as the 2026-09-01 run; `up 1`, `up 4`, a SIGKILL-and-restart
of one node, and the version refusal. No page changed; lint unchanged (285 pages, wanted 1,
unverified 12, drift 0, unlanded 0).

## 2026-09-02 — plan: the lab, step 2 — `tools/lab/README.md`

What the script starts (names and ports), the commands, where the scratch files live, the version
gate and why it exists, the fourteen `raw/nats-server-src/*-observed-v2.14.6.md` files with the shape
each was run on — two on this cluster, §14 of a third, the rest single servers or hub/leaf pairs on
their own ports — and how a run is recorded. No page changed.

## 2026-09-02 — ingest: the meta-layer run repeated through the lab (plan: the lab, step 3)

Source: `raw/nats-server-src/jetstream-cluster-lab-rerun-observed-v2.14.6.md` — §1, §2 and §6 of
`jetstream-cluster-observed-v2.14.6.md` run again with `bash tools/lab/cluster.sh up 3`, plus a probe
and `server/monitor.go` 3573–3589 at v2.14.6. Summary: `s-nats-server-meta-layer-rerun-observed`.
Numbers: bootstrap 303 ms (282 ms on 2026-09-01), restart-to-leader 5.07 s (5.32 s), stepdown 0.54 s
(0.53 s), and the same three meta peer ids on freshly purged stores. **Correction:** the original
record said every node logs `Healthcheck failed: "…"` once a second until a leader exists; the re-run
showed the two unpolled nodes logging it zero times, and the probe showed 0 lines in 5 s without a
request and exactly one line per `/healthz` request — the handler writes it (`monitor.go:3584–3589`).
Pages fixed and citing the summary: `meta-layer` (outage table row, log legend),
`build-a-3-node-cluster` (the restart sentence), `monitoring-endpoints` (the `?js-meta-only=true`
paragraph). Not a docs issue: the wrong sentence was this wiki's own observation. `raw/sources.md`
`nats-server-src` row extended; index updated. Bank unchanged (Q36, Q38 gain a second run). Lint:
286 pages, drift 0, unlanded ripples 0 → 0.

## 2026-09-02 — plan: the lab, step 4 — README, and the plan finished

`README.md` gains *Reproducing the observed runs* (the three commands, the version gate, the pointer
to `tools/lab/README.md`) and a `tools/lab/` row in the layout table. Fresh-clone check: `tools/lab/`
copied outside the repository and run with its own `NATS_LAB_DIR` gave a healthy three-node cluster in
one command. `inbox/plan-the-lab-2026-09-02.md` carries its result line. Lint: 286 pages, wanted 1,
unverified 12 across 9 pages, drift 0, unlanded 0, staleness 0 behind 2.14.6. Bank unchanged at 137
rows / 101 answered — this plan built a tool, not a page.

## 2026-09-02 — scout: mirror and replication internals (plan: the runnable scouts, step 1)

Phase B opened: `inbox/plan-the-runnable-scouts-2026-09-02.md` written from the megaplan's phase B
(six steps: scout 1 → runs and ingest → scout 2 → run and ingest → `consumer-keeps-redelivering` →
close the backlog sections). Step 1: `inbox/scout-mirrors-and-replication-2026-09-02.md` for rows 76,
91, 105 — gh#8417, gh#8444 and issue #5106 fetched through the GraphQL API and read; `stream.go` and
`filestore.go` at v2.14.6 read for the mirror consumer, `skipMsgs`, `SkipMsgs` and the linear-scan
heuristic (line numbers in the scout); the v2.14.1–v2.14.6 release bodies grepped (the interior-delete
work is v2.14.4, #8403/#8405/#8406); the client follow-ups (nats.go #1874 open, #1648 open, nats.js
#155 closed) and the CLI's flags (`nats kv add --mirror --mirror-domain` exists, `nats object add
--mirror` does not) checked; two Synadia posts skimmed and placed. Twelve candidates, three runs
named, six summaries proposed. Nothing ingested; the user picks. Lint unchanged.

## 2026-09-02 — ingest: mirror and replication internals, runs A/B/C (plan: the runnable scouts, step 2)

Sources, all fetched 2026-09-02: `raw/gh-discussions/gh-8417.md` and `gh-8444.md`,
`raw/gh-issues/issue-5106.md` and `client-issues-object-store-mirror.md` (nats.go #1874, #1648,
nats.js #155), `raw/release-notes/v2.14.1.md` … `v2.14.6.md`, `raw/nats-server-src/mirror-v2.14.6.md`
(`stream.go` / `filestore.go` ranges, plus the `mirror-%s` naming at v2.10.0 and v2.12.0),
`raw/nats-go-src/kv-object-mirror-v1.53.1.md`, and the runs in
`raw/nats-server-src/mirrors-observed-v2.14.6.md` with their client `mirrorlab.py`. Seven summaries:
`s-gh-8417-kv-mirror-file-vs-memory`, `s-gh-8444-mirror-catchup-under-a-reader`,
`s-issue-5106-object-store-mirror-list`, `s-nats-server-mirror`, `s-nats-server-mirrors-observed`,
`s-relnotes-2.14.4`, `s-nats-go-kv-object-mirror`.

**The runs** (nats-server v2.14.6, nats CLI 0.4.0). A: a 400,000-key bucket with 2,000,000 overwrites
(83 % holes) mirrored on file and on memory — sync 1.24 s / 0.74 s; the everything-matching filter
`$KV.DNS.>` read the file mirror at 267,866 msg/s against 1,740,462 without it (6.5×; 9.4× at 1 M keys
over 4 M sequences), no gap on the memory mirror or on the origin — the mechanism gh#8417's answer
names, alive at 2.14.6. B, third form: three `nats bench js ordered` readers made the mirror's catch-up
3.4–3.9× slower on file and 3.1–3.4× on memory (gh#8444's 2.89× reproduces; not file-store-specific
here). C: an object bucket mirrored from the leaf into the hub across two domains — empty without the
`$O.dms.> → $O.dms_mirror.>` transform, whole with it; a KV mirror across the same boundary readable by
its own name at once; a same-domain KV mirror (`nats kv add --mirror`) not readable by its own name at
all. Found on the way: an un-acked publish flood is dropped at the stream's 100,000-message inbound
queue with one `[WRN] Dropping messages due to excessive stream ingest rate` line (`stream.go:441–442`).

**Pages.** New gotcha `consumer-slow-on-a-sparse-stream` (row 76's symptom; causes: the filter on a
mirror, readers during catch-up, pre-2.14.4 interior deletes). `mirrors-and-sources`: *How a mirror
catches up* (the `JS_MIRROR_<id>` consumer and its config, the 10 s stall check, the 2 s retry gate,
the gap → `skipMsgs` branch, one Raft entry per hole on a replicated mirror), *A mirror of a bucket
answers to the origin's subjects*, the `mirror-<id>` line corrected to the 2.14 names, the `## To
verify` item on row 76 settled and removed, two dated Synadia pointers. `filestore-layout`: *Interior
deletes, and what they cost a reader* (the delete map, the linear-scan heuristic with its lines,
`SkipMsgs`, what 2.14.4 changed, the mirror's re-packing). `key-value`: *Reading a mirror: which name,
which storage, which filter*. `object-store`: *Mirroring a bucket* (the config, the transform, what
the mirror is not, the maintainers' warnings). Sections or pointers on `object-store-list-is-slow`,
`cross-domain-sourcing` (step 5), `consumer`, `nats-go` (*What bites you*), `nats-cli`,
`nats-server-2.14` (the patch releases table), `jetstream-slows-as-consumers-grow` (cause 5),
`publishing` (the inbound-queue drop), `jetstream-domain`.

**Bank.** Rows 76, 91, 105 filled — 91 answered with the mechanism and the run, marked unanswered
upstream on the page. 104 / 137 answered, 33 open.

**Docs issues** #49 (ADR-59 still names the replication consumer `mirror-<id>` / `src-<id>`; the 2.14
server names it `JS_MIRROR_<id>` / `JS_SRC_<id>` unconditionally — verified at v2.10.0, v2.12.0,
v2.14.6 and observed), #50 (nothing in the docs says an object bucket can be mirrored or needs the
`$O.` transform — grep over the whole tree), #51 (ADR-57 never says which name a mirror bucket is read
by, and nats.go reads a same-domain mirror at its own prefix and a cross-domain one at the origin's —
`jetstream/kv.go:1610–1618`). 51 docs issues total. **No new server issue**: with no mirror the hub sees
nothing of the leaf's bucket, so row 105 is not SI-1 restated; run B's effect has a public analysis and
no contradiction with the source. `raw/sources.md` rows extended; index updated; the scout's *Status*
line carries the candidate → summary map. Lint: 294 pages, wanted 1 (`consumer-keeps-redelivering`),
unverified 12 across 9 pages, drift 0, unlanded ripples 0 → 0, staleness 0 behind 2.14.6.
