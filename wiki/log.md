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
