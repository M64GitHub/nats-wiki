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
