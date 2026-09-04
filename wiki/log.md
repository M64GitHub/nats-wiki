---
title: Log
type: log
created: 2026-08-31
updated: 2026-09-02
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

## 2026-09-02 — scout: stream scale ceilings and the filestore (plan: the runnable scouts, step 3)

*Operation: scout* for question-bank rows 4, 5, 9 and 13, backlog section 2, written to
`inbox/scout-stream-scale-2026-09-02.md`: 15 candidates, none blocked. Read in the scratchpad, not
ingested: six discussions through the GraphQL API (gh#8001, gh#8333, gh#7147, gh#7032, plus gh#5202
and gh#3772 found by a discussion search), `server/filestore.go`, `stream.go`, `jetstream.go`,
`server.go` and five more files at v2.14.6, PRs #8282, #8516, #8227, #8403, #7526, #7876, #7783,
#7787, #6684, the release bodies of all 198 2.10–2.14 releases (grep for recovery lines; phase D
fetches them into `raw/`), the v2.15.0-preview.1 body, one Synadia blog post and two Synadia
*insights* check pages, issue #4424.

**The finding.** Row 13's thread (gh#8001, 50 M messages, `Restored … in 6m38s` after a clean
shutdown, no maintainer reply after the reporter posted a goroutine dump) is answerable from the dump
the maintainers never read back: goroutine 111 sits in `startingSequenceForSources` →
`LoadPrevMsgMulti` → `prevMatchingMulti` → `loadMsgsWithLock` — a stream with `sources` (the
reporter had about twenty) scans backwards through every block at every start to find the last
message from each source, and a source with nothing in the stream sends the scan to sequence 1.
`stream.go:4787–4895` at v2.14.6 still does it; the `Restored … in` timer (`jetstream.go:1555–1659`)
wraps it, so the log charges the scan to "restore". The 2.15 preview fixes exactly this
(`sources.db`, #8282, #8516: *"Restarts and leader changes previously required expensive backward
scans"*). Underneath: `recoverFullState` (`filestore.go:1927–2216`) reads `index.db` and stats the
blocks; five `Filestore [<stream>] Stream state …` warnings name the reasons it is refused; above
`highCardinalityThreshold` (1,000,000 subjects or interior deletes, `:390`, `:12006`) the periodic
write is skipped and only a clean stop writes one (`:12254`). Rows 4 and 5: no one-billion constant
anywhere in the server, `uint64` sequences, a maintainer's stream at 1,174,510,552 messages, and
gh#7032's marked answer *"There is no hard limit to the size of a stream"* — row 5 is answerable,
not the `no-public-answer` the backlog expected. Row 9: gh#8333 (~100 MB of RAM per 1 M small
subjects, unmarked maintainer comment), gh#5202 (the in-memory ART index since 2.10.9, marked),
Synadia's "a few hundred bytes" per subject, and the three places the 1 M constant changes behaviour.

**Runs named** for step 4, ~9 GB, through `tools/lab/cluster.sh up 1`: D (50 M fill, four restarts
— clean, `-9`, no `index.db`, and a sourcing stream with an idle source), E (1.2 M subjects against
6, RSS and restart both ways), F (`--max-msgs 1000000000` accepted). Docs-issue candidate: the docs
tree never states the per-subject RAM term, the threshold, or that recovery cost depends on a clean
stop; `concepts/subjects.md` says subjects are "essentially free". `SI-3` only if run D reproduces
the attribution. Nothing in the wiki changed; the bank is unchanged (104 / 137). Lint: 294 pages,
wanted 1, unverified 12, drift 0, unlanded 0, staleness 0 behind 2.14.6. Picked the same day, as proposed; the pick is the scout file's
*Status* line. Step 4 starts in a fresh session.

## 2026-09-02 — tools and rulebook: `tools/fetch-discussion.py`, and a scratch cache that outlives the session

The scout above was fetched into the per-session scratchpad, which does not survive to the next
session: six rendered threads, ten server source files at v2.14.6, the release bodies and the
GraphQL-to-Markdown renderer would all have had to be fetched and rewritten again for step 4 — the
third time for the renderer (`raw/sources.md` has said "rendered by a small script" since
2026-08-31 without the script existing anywhere). The user asked for a durable place. Two changes:
**`tools/fetch-discussion.py`** — `gh api graphql` for one or more discussion numbers (any repo,
`--repo`), pages comments past 100, writes the JSON and the rendering to a cache (default
`local/scratch/gh/`) and, with `--out raw/gh-discussions`, promotes the rendering at ingest time
without ever overwriting a file there; slugs follow the manifest's convention (`gh-<n>`, else
`<repo>-<n>`). Checked against the file already in `raw/`: a re-fetch of gh#8417 differed from
`raw/gh-discussions/gh-8417.md` only in carriage returns (GitHub bodies arrive CRLF; the 2026-09-02
renderer had stripped them, and three older raw files — gh-3569, gh-4342, gh-4535 — still carry them,
left as they are because `raw/` is immutable), so the tool normalises bodies to LF and, re-rendered
with `--render-only`, is byte-identical to the raw copy, which it refused to overwrite. Registered in the `CLAUDE.md` map. And, in the local overlay only (it is a
per-clone convention): **`local/scratch/`** with an `INDEX.md`, laid out by purpose (`gh/`,
`src/<tag>/`, `releases/`, `runs/<topic>/`), a cache and never a source — nothing in it may be
cited, the ingest copies the picked files into `raw/` with a manifest row, and a scout's *Status*
line names the cache paths the next step starts from. This session's material is in it now. Nothing
in `wiki/` changed; lint unchanged.

## 2026-09-03 — ingest: stream scale ceilings and the filestore — rows 4, 5, 9, 13 (phase B, step 4)

Step 4 of `inbox/plan-the-runnable-scouts-2026-09-02.md`, from the pick in the *Status* line of
`inbox/scout-stream-scale-2026-09-02.md`. **Runs first**, through `tools/lab/cluster.sh up 1` on
v2.14.6 / CLI 0.4.0, recorded in `raw/nats-server-src/stream-scale-observed-v2.14.6.md` with the
scripts (`stream-scale-runE.sh`, `stream-scale-runD.sh`, `stream-scale-agg*.json`) beside it. **Run
E** (row 9): 3 M messages over 1.2 M subjects against the same over 6 — RSS ~380 B per subject
(whole process), no periodic `index.db` in five minutes above the threshold (the clean stop wrote
one of 19.2 MB), restarts 153 ms / 1.02 s / 850 ms (clean, SIGKILL, no file) against 2 ms / 303 ms /
309 ms. **Run D** (row 13): 50 M × 100 B in 130 s, 6.7 GB in 800 blocks; clean-stop restarts **3–27
ms** with the disk idle and 1.8–7 s within seconds of a bulk write (not isolated); SIGKILL **6.4 s**
with `Stream state outdated, last block has additional entries, will rebuild` and every goroutine
sample in `rebuildState`; `index.db` deleted **9.5 s**, silently. The sources variant, twice in the
idle regime with goroutine samples: a 1.6 GB stream with one **empty** source restores in **2.57 s**
(all samples in `startingSequenceForSources`), **23 ms** with that source removed — the thread's
6 min 38 s is that scan at 20 MB/s, read off the reporter's own dump; on R1 it runs inside the
`Restored … in` timer, on R3 after it (`stream.go:4958–4972`). **Run F** (rows 4, 5): `--max-msgs
1000000000` and `10000000000` accepted; 134 B/msg → 10⁹ messages = 124.8 GiB, as arithmetic. The
S2 variant was skipped, as the pick allowed.

**Ingested** (8 summaries, at the cap): `s-gh-8001-jetstream-startup-slow-50m`,
`s-gh-8333-high-cardinality-subjects`, `s-gh-5202-max-unique-subjects`, `s-gh-7147-one-billion-cap`,
`s-gh-7032-max-msgs-known-good`, `s-nats-server-filestore-recovery` (candidates 2 + 4, with the PR
texts of 3 and the release lines of 5 quoted in `raw/nats-server-src/filestore-recovery-v2.14.6.md`),
`s-nats-server-stream-scale-observed`, `s-synadia-how-many-subjects` (the blog post into
`raw/synadia-blog/`, the two Insights check pages into a new collection `raw/synadia-insights/`).
Raw: the five threads promoted from `local/scratch/gh/` with `tools/fetch-discussion.py
--render-only --out`; manifest rows extended. Candidate 13 (gh#3772) stays a pointer for phase G;
14 skipped.

**Pages.** New gotcha **`jetstream-recovery-is-slow`** (five causes, ranked; the source scan first,
marked unanswered upstream). New sections: `filestore-layout` — *Recovery at startup* (the four
checks, the five warnings, the measured table) and a version note; `mirrors-and-sources` — *What a
sourcing stream does at every start*; `jetstream-sizing` — *Subjects are a RAM term* (three figures)
and *There is no message cap*, item 7 (the restart window) under *What runs out first*, rows 4/5
struck from *What is still unknown*; `stream` — *There is no cap on messages, and no known-good
`max_msgs`*; `defaults-and-limits` — the threshold row gains its three uses; `nats-server-2.15-preview`
— *The source index: `sources.db`*, and its *To verify* corrected; `nats-server-2.14` — the 2.14.2
block-skip change on the concept side; `nats-server-2.12` — recovery in the 2.12 line;
`nats-server-2.10` — the ART index since 2.10.9; `kubernetes-storage` — the restart window and the
probe; `consumer-slow-on-a-sparse-stream` — cause 4, the block skip off above a million subjects;
`synadia`; `retention-policies` — the event-store shape.

**Bank.** Rows **4, 5, 9, 13 answered** — 5 by a maintainer's "no hard limit", not the
`no-public-answer` the backlog expected; 13 with the mechanism the thread never received. 108 / 137.

**Docs issues #52** (missing: the sizing chapter has no per-subject memory term and no recovery
term; the whole tree never names `index.db` or the subject index) and **#53** (enhancement:
"Subjects are essentially free" is unqualified for JetStream). **Server issue `SI-3`**
(inconsistent, low): a `*` inside a token — `pt.1*` — is a wildcard to the subject tree and a
literal to the sublist, so `num_pending` and the subjects report count messages that delivery never
matches; reproduced on a five-message stream, mechanism at `stree/parts.go:79–147` against
`sublist.go:1172–1183`. Found because run E's planned filtered read used `card.1*` by mistake. The
`SI-3` the scout anticipated — the `Restored … in` line charging the source scan to "restore" — is
recorded as a fact on the pages (the timer wraps `recoverStream`; on R1 the scan is inside it) rather
than as a question: the attribution is what the code does, and 2.15 removes the scan.

Found and not pursued: clean restarts made within seconds of a bulk write took 1.8–7 s where the
same restart with the disk idle took milliseconds; the disk was at ~800 MB/s of write-back in the
worst case. Recorded in the raw file as observed, cause not isolated.

## 2026-09-03 — ingest: `consumer-keeps-redelivering`, the last wanted page (phase B, step 5)

Step 5 of `inbox/plan-the-runnable-scouts-2026-09-02.md`. **Sources first**: issue #6921 through the
GraphQL `repository.issue(number:)` query the other `raw/gh-issues/` files were made with, cached in
`local/scratch/gh/` and rendered into `raw/gh-issues/issue-6921.md`; the Stack Overflow thread row 14
was mined from (#78603662, never read until today) through the Stack Exchange API into a **new
collection `raw/stackoverflow/`**; and four release bodies from the cache into `raw/release-notes/`
(`v2.10.16`, `v2.10.17`, `v2.11.2`, `v2.11.5`) because the v2.11.5 notes name the fix the issue does
not (#7005), and the release archive turned out to hold a family of "acked, then redelivered" fixes
worth a table. **Runs** through `NATS_LAB_FLAGS=-DV bash tools/lab/cluster.sh up 1` on v2.14.6 / CLI
0.4.0, recorded in `raw/nats-server-src/redelivery-observed-v2.14.6.md` with five scripts beside it:
**G** — #6921's own recipe delivers once each with the floor following (the defect is gone at
2.14.6); **I** — a redelivery loop as `tries:`, `consumer info`, the JSON counters and the `-DV`
trace show it, with **zero** `INF`/`WRN`/`ERR` lines about it; **H** — the Stack Overflow shape:
`backoff: [10000]` is stored as `ack_wait: 10000` and printed as `Ack Wait: 10µs`; acked on arrival
the ack wins six pulls of seven on localhost and the seventh redelivered ten messages ninety times in
six milliseconds; with 5 ms of work before the ack every message is delivered exactly `max_deliver`
times — twice, the poster's report to the letter; and a redelivery needs a pull *waiting* when the
deadline passes (batch 10 against ten messages: none). The mechanism read at the tag:
`checkPending` `:6003–6110`, `hasMaxDeliveries` `:2372`, `processAckMsgLocked` `:3717–3731`, the
ack queue `:2778–2779` / `:5182`.

**Ingested** (6 summaries): `s-issue-6921-last-per-subject-acks`,
`s-so-78603662-acked-but-redelivered`, `s-relnotes-2.11.5`, `s-relnotes-2.11.2` (with the 2.10.16 /
2.10.17 lines), `s-relnotes-2.14.1`, `s-nats-server-redelivery-observed`.

**Pages.** New gotcha **`consumer-keeps-redelivering`** — symptom from run I verbatim; *rule out
first* (a stall is not a loop; not the duplicate window; not a leafnode replay); five causes ranked:
the deadline shorter than the work including a `backoff` in the wrong unit, a batch the workers cannot
drain in `ack_wait`, no ack on the success path or a lost ack, a nak loop with `max_deliver: -1`, and
a **table of server versions** that redelivered acked messages (2.11.0–2.11.4 `last_per_subject`
fixed 2.11.5; before 2.11.3 after a leader change; before 2.10.17 on rollouts; 2.14.0 drifted state).
Ripples: `ack-and-redelivery` — *Acked, and redelivered anyway — the three ways* (the unit, the
waiting pull, when it was the server); `consumer` — *The redelivery rides the next pull*, *The entries
are nanoseconds on the API*, *The reply subject carries the delivery count*, *Version notes: when the
consumer was not at fault*; `nats-server-2.11` and `nats-server-2.14` — *The patch releases, for
consumers*; `nats-server-2.10` — *Redelivery of acked messages, fixed in 2.10.16 and 2.10.17*;
`nats-net` — its first **What bites you** (the `Backoff` unit; #6921 filed first as nats.net #860);
`dead-letter-queue` — a version note on `max_deliver` accounting before 2.14.1. `verified-on` bumped
to today on `ack-and-redelivery` and `consumer` (their claims were re-run). Index: the gotcha entry,
six summary lines, the *Wanted pages* line for gotchas struck.

**Bank.** Rows 14, 15, 16, 17, 18, 19 gain `[[consumer-keeps-redelivering]]`; no new row (nothing
surfaced that the bank lacks). 108 / 137, unchanged.

**Docs issues**: none new; **#4** extended with *evidence of harm* — the collapsed consumer node
also hides the **unit** of every duration field, and #78603662 is what that costs. **Server
issues**: none — the runaway in run H is a race the source explains, on a deadline the config asked
for. Found and stated as unknown: the poster's "without `MaxDeliver`, once" is not what 2.14.6 does
(unlimited redelivers more); whether NATS.Net passed `10000` through unchanged is inferred from the
match, not read from the client.

Lint: 310 pages (303 → 310), **wanted: none** (the finish-line measure for this plan), missing from
index none, citation drift 0, unlanded ripples 0 → 0, unverified 12 across 9 pages, staleness 0
behind 2.14.6.

## 2026-09-03 — plan closed: the runnable scouts (phase B, step 6)

Backlog sections 1 and 2 of `inbox/scout-backlog.md` struck, naming the scout files and the plan
steps that closed them; the result line written at the top of
`inbox/plan-the-runnable-scouts-2026-09-02.md`. Over the plan (2026-09-02 → 2026-09-03): bank
**101 → 108** of 137 (rows 4, 5, 9, 13, 76, 91, 105 — all *answered*, none needed
`no-public-answer`, including row 5 the backlog expected to), wanted **1 → 0**, pages **286 → 310**
(22 summaries, 3 gotchas — `consumer-slow-on-a-sparse-stream`, `jetstream-recovery-is-slow`,
`consumer-keeps-redelivering`), docs issues **48 → 53** (#49–#53; #4 extended), server issues
**2 → 3** (SI-3), unlanded ripples 0 → 0, citation drift 0 → 0. Six observed runs on 2.14.6 recorded
in `raw/nats-server-src/` with their scripts. Phase B's *done when* holds; phase C is next.

## 2026-09-03 — triage: nats-io/nats-server discussions (phase C, step 1)

`inbox/plan-discussions-triage-2026-09-03.md` written from the megaplan's phase C (goal, steps, *done
when*), then step 1. **New tool `tools/triage-discussions.py`**: pages `repository.discussions` through
`gh api graphql` (100 a page, five pages, one rate-limit point each), writes the replies verbatim to
**`raw/gh-discussions-index/discussions-2026-09-03-p1..5.json`** and a rendering
`discussions-2026-09-03.md` (one `## gh#<n> — <title>` section per thread: meta line, original post;
no comments), and builds **`inbox/gh-discussions-toc.md`** — 484 rows: number, title, category, opened,
answered (by whom, when), upvotes, comments, `area` guessed from the title's keywords and said to be,
`bank` (the question-bank rows whose *asked at* cites the thread), flags, GitHub link, index file,
summary (preserved on re-run and filled from `wiki/summaries/` whose `source-url` names the thread —
48 filled today). **The ★ rule, stated in the script and the table head:** *answered and upvoted
(upvotes ≥ 2, since a discussion opens with its author's own upvote), or design-shaped and answered*;
`design` is a title regex with the trade-off in it. Counts on 2026-09-03: **40 ★, 28 of them not yet
in the bank**; 181 answered, 103 upvoted, 22 design-shaped (15 not in the bank), 89 already cited by a
bank row, 48 in `raw/gh-discussions/`, 1 skip (Show and tell); categories Q&A 351, General 99, Ideas
33, Show and tell 1; upvotes: 376 threads at 1, 55 at 2, 21 at 3, 32 above. The rule needed no
tightening (the plan's threshold for that was ~40 new rows). Registered in `wiki.json` → `tocs`
(nav *Discussions*, filters ★ / answered / upvoted / design / in-bank / in-raw) and `raw_collections`
(`article_pattern` on the `## gh#<n>` headings, so each row's title opens the original post in the
index rendering); `raw/sources.md` row; README rows for the tool and the table. Built: the table
renders with 484 rows and 484 article anchors. `--with-comments` also cached every thread's comments
and replies (808 comments; replies truncated past 5 on 48 threads, which `fetch-discussion.py` fetches
whole when needed) under `local/scratch/gh-index/` for step 2's body search — a cache, never cited.
Lint: 310 pages, wanted none, drift 0, unlanded 0, unverified 12 across 9 pages. Bank unchanged,
108 / 137.

## 2026-09-03 — scout: the public form of the posed rows 108–137 (phase C, step 2)

`inbox/scout-posed-rows-public-form-2026-09-03.md`. Every one of the 30 posed rows searched for the
place somebody asked it in public: the discussions index (484 titles and original posts), the comment
and reply cache from `tools/triage-discussions.py --with-comments` (808 comments, never cited), and the
Stack Overflow tags through the Stack Exchange API (60 short tag-scoped queries; long queries return
nothing because the search ANDs every term). Rule: a row is *found* only when a thread asks the row's
question with its trade-off, or one named half of it. **21 found** (13 whole, 8 partial — the file
names the half), **9 not found** (112, 116, 123, 127, 128, 131, 132, 133, 134). The bank's *asked at*
cells for the 21 replaced `own` with the URL, the row text unchanged; the *Thread titles behind the
rows* list gained entries 108–137 for them; a note at the end of the bank records the pass. Row 129's
thread is row 57's (gh#6182) — 129 is its design form, so one page will answer both. Row 120 is the
only Stack Overflow find (*Is anyone using Nats Object Store in production?*, score 6, unanswered).
Found and worth naming: gh#6100 (stream per subject or one stream — answered "one stream; every
replicated stream is a Raft group"), gh#6571 (WorkQueue source + Limits mirror, or one stream with two
consumers — the asker wrote the pros and cons out), gh#3654 (Kafka partition rebalancing onto
JetStream, 15 upvotes, no chosen answer), gh#6848 (thousands of edge accounts and a JWT the server
cannot hold), gh#5974 (1,700 stores as leaf nodes with source and mirror), gh#5468 (KV and Object
Store as a database). The 9 not-found rows and what was searched are in `inbox/scout-backlog.md`
§5(a) so the search is not repeated; nothing ingested — the threads for phase G's page scouts are
listed at the end of the scout file. Bank: 108 / 137 answered (unchanged); `own` rows 30 → 9.
Lint clean: 310 pages, wanted none, drift 0, unlanded 0.

## 2026-09-03 — bank rows 138–158 from the discussions triage (phase C, step 3)

The 24 ★ threads of `inbox/gh-discussions-toc.md` that no bank row cited (after step 2 had taken
five of the original 29) were read — title, original post, chosen answer. **21 became rows 138–158**,
each the question as an operator or architect holds it, with the URL; three were left out with a
reason recorded in the bank's closing note (gh#2933 re-asks rows 108/111 and went to the scout file
as a second candidate; gh#3164 is a Go test-helper import path; gh#6301 is a third-party Helm chart
defect fixed in that chart). `answered by` filled for **eight** where a page already states the answer
with a citation and a version — 141 (a cluster behind one DNS name: `build-a-3-node-cluster`,
`how-clients-reach-a-cluster`), 142 (the leader does the work: `replicas`, `subject-transforms`), 143
(no external database — `storage` is `file` or `memory`: `stream`, `nats-streaming`), 145 (lame duck
then peer-remove: `rebalance-streams`, `evict-a-sick-server`), 147 (the Raft groups, the filestore,
reads from any replica: `raft-in-nats`, `meta-layer`, `filestore-layout`, `direct-get`), 151 (delete
by sequence, secure delete, purge: `stream`, `s-docs-altering-stream-state`), 152 (`no_tls` behind a
proxy: `run-nats-behind-a-proxy`, `websocket`), 158 (MQTT 3.1.1 only: `mqtt`). Thirteen open. Two
findings on the way: **row 150** — gh#4761's maintainer answer says a request over a service import
never fails fast with `No responders` because the import itself is a subscription, while
`cross-account-sharing` states a matched import with nobody answering fails fast; to settle on the
binary (phase I, or the next security pass), then the page or `inbox/docs-issues.md`. **Row 158** —
the maintainers stated on 2026-07-06 that MQTT 5 will not be accepted; the `mqtt` page says 3.1.1
only and should carry the statement when gh#8362 is ingested. Bank: 137 → 158 rows, **108 → 116
answered**, open 29 → 42 (24 `design`), `own` 9, ★ 43. TOC after the re-run: ★ not in the bank 3
(the three skipped), in-bank 129. Lint clean.

## 2026-09-03 — plan closed: discussions triage (phase C, step 4)

`inbox/scout-backlog.md` §5(a) struck (the not-found table stays under it; §5(b) open for phase G);
the result line at the top of `inbox/plan-discussions-triage-2026-09-03.md`. Over the plan, one
session: a new tool and a new raw collection (`tools/triage-discussions.py`,
`raw/gh-discussions-index/`), `inbox/gh-discussions-toc.md` with 484 rows in the viewer, the scout of
the 30 posed rows (21 → URL, 9 recorded as not found), 21 new bank rows. Bank **108 / 137 → 116 /
158**, `own` 30 → 9, pages 310 (no page written — this phase was bookkeeping by design), wanted 0,
drift 0, unlanded 0, unverified 12, docs issues 53, server issues 3. Phase C's *done when* holds;
phase D (the change layer) is next.

## 2026-09-03 — every release body into `raw/release-notes/` (phase D, step 1)

Phase D opened with `inbox/plan-change-layer-2026-09-03.md` (nine steps: the archive into `raw/`, a
release TOC, four per-minor ingests plus the 2.15 preview, a `since:` sweep over the 55 reader pages
that have none, the default diff per minor with `check-defaults.py --tag`, close). Step 1: a new tool,
`tools/triage-releases.py --fetch`, paged `repos/nats-io/nats-server/releases?per_page=100` (three
pages, 291 releases) into `local/scratch/releases/`, and wrote **59 release bodies** — every
non-prerelease tag from v2.10.0 up that was not yet there (27 of 2.10, 16 of 2.11, 15 of 2.12,
including the two `-binary` tags of CVE-2025-30215) plus `v2.15.0-preview.1` by name — in the form of
the 11 files written by hand since 2026-08-31 (provenance line, `# Release <tag> — published <date>`,
the body with CRLF normalised). Those 11 were left untouched and still match the archive; the live
fetch matched the 2026-09-02 cache on every tag, body and date. **70 bodies in all.** The 129 RC and
preview bodies were deliberately not written (each GA body is the consolidated changelog of its RCs;
`_tags-and-dates.md` has their tags and dates) — said in the tool's docstring and the manifest row.
`raw/sources.md` extended; README and the `CLAUDE.md` Map name the tool; the scratch index row marks
the cache promoted. The same run built `inbox/relnotes-toc.md` (70 rows, 28 ★) — step 2 registers and
tunes it. Lint clean: 310 pages, wanted 0, drift 0, unlanded 0, unverified 12.

## 2026-09-03 — `inbox/relnotes-toc.md` in the viewer (phase D, step 2)

*Operation: triage.* `tools/triage-releases.py` (without `--fetch`) reads the 70 bodies in
`raw/release-notes/` into a table — tag, minor, published, Go version, changelog items, flags, file,
summary — registered in `wiki.json` → `tocs` (nav *Releases*, collection `release-notes`, filters ★,
added, changed, cve, downgrade, warning, default, cited) and rendering with 70 rows, each tag linking
to its raw body. Flags are the bodies' own sections and admonitions. Two defects fixed on the first
look: `v2.14.0` had no date because its hand-written header (2026-08-31) predates the `— published`
form — the tool now falls back to `_tags-and-dates.md`, the raw file is untouched; and `downgrade`
matched "downgraded to QoS0" in the MQTT fix line of v2.12.14 and v2.14.4 — the noun form only now.
**★ rule as proposed, 26 of 70** (changed, removed, downgrade, withdrawn, warning, cve, or the first of a
minor), no tightening needed: 2.10 10 ★ (662 items, 77 KB), 2.11 8 (434, 55 KB), 2.12 5 (509, 61 KB),
2.14 2 (220, 26 KB), 2.15 preview 1. Other counts: 29 `added`, 6 `changed`, 2 `removed`, 12 `cve` (none
in the 2.14 line), 5 `downgrade`, 5 `warning`, 2 `withdrawn` (v2.10.28 and v2.11.2, "upgrade to …
instead"), 2 `binary` (CVE-2025-30215 as binaries a week before v2.10.27 / v2.11.1), 37 `cited` by a
wiki page, 7 with a summary (the per-patch summaries, matched through their `aliases`). One line to
carry into step 5 already: the v2.12.5 body warns that a stream update "may result in the loss of
consumers in clustered deployments", mitigated by `meta_compact_sync: true` — a data-loss note the wiki
does not have. Reading order for steps 3–6 is the table's: 2.10 first, largest. Lint clean.

## 2026-09-03 — ingest: the 2.10 line, v2.10.0 → v2.10.29 (phase D, step 3)

The 29 release bodies of 2.10 read end to end as one changelog into `s-relnotes-2.10` — per-release
table, then the change layer by kind: defaults and intervals that moved (leafnode compression
`s2_auto`, `statsz` 30 s → 10 s in 2.10.21, the API queue limit in 2.10.21, `write_deadline` per
64 MB batch in 2.10.26, the 32 MB publish cap in 2.10.28, peer-remove re-admission after five minutes
in 2.10.28), the keys that arrived with their PRs (`auth_callout`, `logfile_max_num`,
`sync_interval`, `prof_block_rate`, `tls.certs`, `tls.min_version`, `cluster.ping_interval`,
`no_fast_producer_stall`, `first_info_timeout`, the Windows cert-store keys), the subjects and
endpoints (`$SYS.REQ.SERVER.<id>.RELOAD`/`KICK`/`LDM`, `PING.IDZ`, `/expvarz`, `/raftz`), the
"now"/"no longer" lines, the withdrawn and warned releases (2.10.16's zero-byte `tav.idx`, the
2.10.19 → 2.10.20 KV CAS regression, 2.10.19 → 2.10.22 start-sequence clipping, 2.10.28 withdrawn),
a data-integrity table by release for rows 64 and 130, and the three CVEs. Two threads fetched and
summarised on the way: `s-gh-6005-sourcing-memory-stream-restart` (row 154: 2.10.19's #5785 stopped
clipping source-consumer start sequences, reverted in 2.10.22 by #6014; the same stall reported on
2.14 with the `AckFlowControl` sourcing consumer on 2026-08-07, answered with #8384 in the 2.15
preview) and `s-gh-6748-cve-binary-release-docker-images` (row 155: the official image is built by
Docker's library from a PR the team opens; `-binary` images within the day, Alpine variants after
2025-04-08). Row 150 settled from the notes: a service import with no interest returns "no
responders" **since 2.10.26** (#6532), which is why the older maintainer answer on gh#4761 says the
opposite.

**Corrections.** The wiki said the per-subject index has been a subject tree "since 2.10.9" (a
maintainer's words in gh#5202, repeated on `nats-server-2.10`, `jetstream-sizing`,
`filestore-layout`). The source tree says **2.10.10**: `server/stree/` is absent at v2.10.9,
`fileStore.psim` is `map[string]*psi` there and `*stree.SubjectTree[psi]` at v2.10.10, the oldest
commit on the package is #4960 (2024-01-20), listed in the 2.10.10 body. Evidence with lines in
`raw/nats-server-src/stree-arrival-v2.10.10.md`; the three pages corrected, the summary of gh#5202
given a correction note. Also noted: the 2.10.0 body misspells `sync_interval` as `sync_internal`,
and the 2.10.22 "safer default file permissions" line cites the release PR (#6013) rather than a
change.

**Docs issue #54** (`missing`, medium): the four system-account requests the v2.10.0 notes announce —
`$SYS.REQ.SERVER.<id>.RELOAD`, `.KICK`, `.LDM`, `$SYS.REQ.SERVER.PING.IDZ` — appear nowhere in the
docs tree; the whole mirror writes out only `PING.VARZ` and `PING.PROFILEZ`, while `server/events.go`
at v2.14.6 declares all four (lines 62, 63, 68/1268, 70) and fifteen `PING.<Z>` names. The 2.10 upgrade
guide every body links (`whats_new_210`) now redirects to `/release-notes/` — not filed, since the
link is in the release bodies, not the docs.

**Ripple: 41 pages.** The release entity rewritten from the bodies (facts, *What v2.10.0 added*,
*What the patch releases changed*, *Which patch to be on, and why*; its "not a changelog" note gone);
`mirrors-and-sources` (the restart-empty window), `cross-account-sharing` (no responders since
2.10.26), `install-nats-server` (a CVE as a binary-only release), `upgrade-a-cluster` (*The 2.10
line* under version hazards), `evict-a-sick-server`, `reload-server-config` (reload over the system
account), `stream-has-high-message-lag`, `nats-server-2.15-preview` (#8384), `nats-server-2.11`;
version notes on `stream`, `consumer`, `ack-and-redelivery`, `retention-policies`, `key-value`,
`account`, `auth-callout`, `tls-in-nats` (a since-table of keys), `leafnode`, `mqtt`,
`subject-transforms`, `monitoring-endpoints` (*What arrived in 2.10*), `meta-layer`, `raft-in-nats`,
`js-api`, `advisories`, `filestore-layout`, `jetstream-sizing`, `defaults-and-limits` (*Defaults
that moved during 2.10*), `config-keys` (*Keys that arrived during 2.10*), `stream-placement`, the
gotchas `stream-directories-disappear`, `maximum-messages-exceeded`, `slow-consumer-detected`,
`jetstream-slows-as-consumers-grow`, `jetstream-out-of-disk`, `duplicate-messages-across-a-leafnode`
(a five-fix table, and its *To verify* claim that the notes describe no change struck),
`jetstream-recovery-is-slow`, `consumer-keeps-redelivering` (*The 2.10 patch trail*), `worker-pool`,
`error-codes`. Manifest rows for the threads and the evidence file; index lines for the three
summaries. Bank: rows 150, 154, 155 filled — **116 → 119 / 158**. Unlanded ripples 46 (after the
summaries were written) → 0; lint clean, 313 pages, drift 0.

## 2026-09-03 — ingest: the 2.11 line, v2.11.0 → v2.11.17 (phase D, step 4)

The 18 release bodies of 2.11 read as one changelog into `s-relnotes-2.11`: what 2.11.0 added
(per-message TTL and delete markers, priority groups, consumer pause, multi-get, message tracing,
the config digest, ingest rate limiting with its `429`, `cluster_traffic`, `strict`, pedantic mode,
`preferred` on stepdown; acks on clustered interest and WorkQueue streams proposed through Raft;
SIGTERM exits 0), then the change layer by kind — the defaults and behaviours that moved (a new
leader answers only when up to date, updates refused with every peer offline in 2.11.4, monotonic
Raft time in 2.11.5, the offline-assets floor in 2.11.9, parallel stream loading and `write_timeout`
and `meta_compact` in 2.11.11, the interest-switch head removal and the Raft membership batch in
2.11.12, the 1 MB JWT limit in 2.11.15, `no_auth_user` client-only in 2.11.16), the withdrawn 2.11.2,
the 2.11.0 → 2.11.6 filtered-consumer throughput regression, the 2.11.9 → 2.11.10 meta snapshot
regression, a data-integrity table by release, and the twelve CVEs of 2.11.14–2.11.16 (2.11.16's CVE
line reads `TBD`). The release entity rewritten from the bodies (facts, *What v2.11.0 added*, the
patch table, *Which patch to be on*), its "release body not ingested" item closed.

**Docs issues #55–#57, and #22 extended.** #55 — the generated reference types the leafnode
listener's `handshake_first` as `boolean`; since 2.11.0 (#5783) it accepts the duration and `auto`
forms like every other TLS block (`opts.go` 5309–5331 and 2888–2889 at v2.14.6; the remote keeps only
the boolean, 3157, so its page is right). #56 — the per-account `jetstream { cluster_traffic: owner }`
option (2.11.0, parsed in `parseJetStreamForAccount`, `opts.go` 2451–2463, values `system` | `owner`)
and its `traffic_account` / `system_account` reporting fields are documented nowhere. #57 —
`config_digest` (2.11.0), `tls_cert_not_after` (2.11.12) and `leader_since` (2.11.9) appear on no docs
page (`monitor.go` 1283, 1296, 4208; `stream.go` 375). #22 gains the description finding: the docs
call `max_buffered_msgs` a buffer "for a stream whose storage is temporarily unavailable"; the body
and `stream.queueInbound` (`stream.go` 5768–5783) describe ingest-rate limiting with a `429 Too Many
Requests` reply. Two typos in the bodies noted, not filed: `ping_internal` (2.11.12) for
`websocket { ping_interval }`, and "400 No Messages" (2.11.11) for the `404` the server sends
(`consumer.go` 4678, 5024). PR #4119 is listed by both 2.10.0 and 2.11.0 — the boolean is 2.10.0's,
the duration 2.11.0's (#5783). The docs' 2.11 upgrade guide, linked from every body, redirects to
`/release-notes/`.

**Ripple: 39 pages.** `upgrade-a-cluster` (*The 2.11 line* under version hazards), `message-ttl`
(the patch trail from #6741 to #7385), `priority-groups`, `direct-get`, `consumer` (pause, #6253,
the 2.11.6 regression, #7691), `stream` (ingest rate limiting, #6856, #7766), `retention-policies`,
`key-value`, `mirrors-and-sources`, `js-api`, `js-api-subjects` (`$JS.API.CONSUMER.PAUSE` since
2.11.0), `raft-in-nats`, `meta-layer`, `replicas` (`cluster_traffic`), `evict-a-sick-server`,
`monitoring-endpoints` (*What arrived in 2.11*), `tls-in-nats`, `leafnode`, `websocket`, `mqtt`,
`account`, `subject-permissions`, `operator-mode`, `auth-callout`, `cross-account-sharing`,
`slow-consumer-detected` (`write_timeout`), `jetstream-slows-as-consumers-grow` (the 2.11.0–2.11.5
regression), `jetstream-recovery-is-slow`, `filestore-layout`, `consumer-keeps-redelivering`,
`jetstream-out-of-disk`, `install-nats-server` (SIGTERM exit 0), `reload-server-config` (the config
digest), `config-keys`, `defaults-and-limits`, `error-codes`, `stream-placement`, `advisories`,
`nats-server-2.12` (the same-day 2.11/2.12 patches; #7158's 2.11.9 half). Index line. Bank unchanged
at 119 / 158 (row 71 now cites the body through `message-ttl`). Unlanded ripples 0; lint clean, 314
pages, drift 0.

## 2026-09-03 — ingest: the 2.12 line, v2.12.0 → v2.12.15 (phase D, step 5)

The 15 release bodies of 2.12 read as one changelog into `s-relnotes-2.12`, and — the one line with a
docs upgrade guide — checked line by line against `s-docs-upgrade-to-2.12`: every feature the guide
lists is in the v2.12.0 body except "system events for `$G`" (in no body; unverified either way) and
"`GOMAXPROCS` and `GOMEMLIMIT` in server stats", which the bodies date to 2.10.28 / 2.11.2 (#6791,
merged 2025-04-11) → **docs issue #58**. The guide omits the API level 2, the `max_buffered_msgs` ×10
(#6633 — the docs still print the 2.11 default; #22 extended with the history), the TCP-keepalive
change, trusted proxies, `Nats-Required-Api-Level`, the `Nats-Subject` header, and everything after
2.12.0. Two more gaps verified in the v2.14.6 source: **#59** `jetstream { max_concurrent_io }`
(2.12.14 / 2.14.4, #8336; `dios.go` default 4096, bounds 4–8192; `opts.go` 2789–2794) documented
nowhere, and **#60** the `proxies { trusted [ … ] }` block of ADR-55 (2.12.0, #7153; `parseProxies`
at `opts.go:5720`) documented nowhere while `proxy_required` and the `Proxy is not trusted` error
are. #57 extended with the `in_client_*` counters (2.12.9 / 2.14.1) and the snapshot `window_size`
(2.12.5), both absent from the docs. The change layer: defaults that moved in 2.12.0 (API level 2,
strict on, async flush on, `max_buffered_msgs` ×10, keepalives off, insecure ciphers off, weak-pointer
caches, empty-vote protection), the keys and headers that arrived (atomic batch, counters,
`prioritized`, trusted proxies, mirror promotion, single-message scheduling, `Nats-Required-Api-Level`,
`server_metadata`, `isolate_leafnode_interest`, `disabled` remotes, `Nats-Subject` on no-responders;
per-block `write_deadline` and the leafnode HTTP proxy in 2.12.1; the PROXY protocol in 2.12.2;
`meta_compact_sync` and `max_consumers` updates and `max_conns: 0` in 2.12.5; reloadable
`max_mem_store`/`max_file_store` in 2.12.7; `in_client_*` in 2.12.9; `max_concurrent_io` in 2.12.14),
the three hazards (**2.12.5's warning** — a stream update could lose a cluster's consumers, mitigation
`meta_compact_sync: true`, fixed 2.12.6 #7939; **2.12.7 → 2.12.11** stale subject state and `Message
Not Found` with `max_msgs_per_subject`, "v2.14.x not affected"; **2.12.15**'s idempotent-create data
loss fix #8449), the 2.12.12 corruption fixes (counter running total #8311, compaction of compressed
or encrypted blocks #8312), the 2.12.14 authentication bypasses (`verify_and_map` with blank
passwords; `no_auth_user` with auth callout), and the same-day twins (2.12.2–2.12.8 with 2.11.11–17,
2.12.9–2.12.15 with 2.14.1–2.14.5). The release entity rewritten from the bodies (facts, the patch
table, *Which patch to be on*, *The docs' upgrade guide against the bodies*).

**Ripple: 40 pages.** `upgrade-a-cluster` (*The 2.12 line*), `publishing` (atomic batch patches,
`Nats-Required-Api-Level`, counters), `message-scheduling`, `priority-groups`, `stream`, `consumer`,
`retention-policies`, `key-value` (2.12.7–2.12.10 unsafe for buckets), `mirrors-and-sources`,
`js-api`, `raft-in-nats`, `meta-layer` (async snapshots and the warning), `replicas`,
`monitoring-endpoints` (*What arrived in 2.12*), `tls-in-nats`, `leafnode`, `websocket`, `mqtt`,
`account`, `subject-permissions`, `auth-callout`, `cross-account-sharing`, `run-nats-behind-a-proxy`
(trusted proxies, PROXY protocol, HTTP proxies), `slow-consumer-detected`, `jetstream-sizing`
(`max_concurrent_io`, the cardinality threshold, the limits accounting fix), `filestore-layout`,
`jetstream-recovery-is-slow`, `jetstream-out-of-disk`, `consumer-keeps-redelivering`,
`backup-and-restore-jetstream`, `evict-a-sick-server`, `reload-server-config`, `install-nats-server`,
`unauthenticated-clients-still-connect`, `config-keys`, `defaults-and-limits`, `error-codes`,
`subject-transforms`, `nats-server-2.14` (the 2.12 twins); the 2.11 summary's forward link to the
2.12 summary restored; index line. Bank unchanged at 119 / 158. Unlanded 0; lint clean, 315 pages,
drift 0. Docs issues 53 → 60 over steps 3–5.

## 2026-09-03 — ingest: the 2.14 line, v2.14.0 → v2.14.6, and the 2.15 preview (phase D, step 6)

The seven 2.14 bodies read as one changelog into `s-relnotes-2.14`, folding the three per-patch
summaries (`s-relnotes-2.14.0`, `-2.14.1`, `-2.14.4`) by reference; the v2.15.0-preview.1 body read
whole into `s-relnotes-2.15-preview`. Both checked against the docs' 2.14 upgrade guide
(`s-docs-upgrade-to-2.14`): every guide feature is in the v2.14.0 body except "sourcing streams can
now perform deduplication when fanning in multiple sources" (in no body; kept as the guide's claim,
marked as such on `nats-server-2.14`), and the guide's frozen-stream / `write error` account is its
own wording for #7788. The guide omits `ignore_discovered_servers`, the `404 No Messages` change
(#7466 — also listed by 2.11.11), the divergent-consumer-state reset, the info-API deprioritisation
and every patch. The keys and subjects the bodies introduce were **verified in the server source**
and the excerpts recorded in `raw/nats-server-src/feature-flags-dial-timeout-and-2.15-subjects.md`
(manifest row extended): `dial_timeout` at both levels with its `DEFAULT_ROUTE_DIAL` = `1s` fallback
(`opts.go`, `const.go`, `leafnode.go` at v2.14.6); `feature_flags.go` at v2.14.6 — exactly two
flags, `js_ack_fc_v2` and `js_raft_delete_range`, both `false`, the second with a source warning that
older peers panic — and at the preview tag a third, `js_snapshot_sources`, with **`js_ack_fc_v2`
still `false`** ("Enabled: TBD"), so the v2.14.0 body's "enabled by default in v2.15" has not
happened in the preview; `$JS.API.CONSUMER.RESET` at `jetstream_api.go:159`; the preview's
`$JS.API.STREAM.CANCEL_MOVE.<stream>` (account-level, rolls back any in-flight desired state),
`$JS.API.STREAM.PEER.EVACUATE.<stream>`, `$JS.API.SERVER.EVACUATE` and `$JS.API.META.RESCUE`
(system account), none of which exist at v2.14.6; the `AckFlowControl` constraints
(`consumer.go:758–780`). Three docs gaps → **docs issues #61** (`dial_timeout` documented nowhere),
**#62** (`reference/config/feature_flags.md` names no flag; the panic warning on
`js_raft_delete_range` is documented nowhere), **#63** (`$JS.API.CONSUMER.RESET` absent from the
consumer API index). The change layer: no default moved in 2.14 — what moved is behaviour (info
APIs deprioritised #7898, Raft refusing to start on a bad snapshot #7566 …, overrun stepdown #7853,
JSONP removed 2.14.3, the 4096-slot semaphore 2.14.4, R > 1 updates rejected non-clustered 2.14.6
#8464, the reservation ratchet 2.14.6 #8503) and the keys that arrived (`feature_flags`,
`ignore_discovered_servers`, reloadable `remotes`, `max_concurrent_io`, `dial_timeout`, the
`in_client_*` counters); *Which patch to be on* on the 2.14 entity (2.14.1 consumer accounting,
2.14.3 counters/compression/encryption and the security batch, 2.14.4 `verify_and_map`, 2.14.5
#8449, 2.14.6 #8488 / #8491 / #8503); the 2.12 twins (2.14.1–2.14.5 = 2.12.9, .10, .12, .14, .15;
2.14.6 has none). The 2.15 entity's *To verify* rewritten (the body is read whole; the backup v2
format and #8429 known from one sentence each; no date; nothing says whether `js_ack_fc_v2` flips
before 2.15.0). `inbox/relnotes-toc.md` regenerated: every 2.14 row and the preview row now carry a
summary link (7 + 1 with a summary; 26 ★ unchanged).

**Ripple: 46 pages.** `nats-server-2.14` (*The seven releases, from the bodies*, *Which patch to be
on*, *The docs' upgrade guide against the bodies*; two lines corrected), `nats-server-2.15-preview`
(*The preview body, read whole*), `upgrade-a-cluster` (*The 2.14 line*, *The 2.15 preview*),
`consumer`, `ack-and-redelivery`, `stream`, `retention-policies`, `mirrors-and-sources`,
`publishing`, `message-scheduling`, `key-value`, `direct-get`, `replicas`, `raft-in-nats`,
`meta-layer`, `filestore-layout`, `js-api`, `js-api-subjects` (the preview's four subjects verified
at the tag), `leafnode` (`dial_timeout` with file and line), `gateway`, `tls-in-nats`,
`auth-callout`, `account`, `subject-permissions`, `cross-account-sharing`, `mqtt`, `websocket`,
`monitoring-endpoints` (*What arrived in 2.14*), `defaults-and-limits` (*Defaults that moved during
2.14*), `config-keys` (*Keys that arrived during 2.14*), `error-codes` (the `AckFlowControl`
refusals), `jetstream-sizing`, `jetstream-out-of-disk`, `jetstream-recovery-is-slow`,
`consumer-keeps-redelivering` (2.14.2–2.14.6 beyond the table), `stream-leader-keeps-moving`
(overrun stepdown as a deliberate cause), `stream-placement`, `backup-and-restore-jetstream`,
`reload-server-config`, `install-nats-server`, `run-nats-behind-a-proxy`, `rebalance-streams`,
`disaster-recovery`, `evict-a-sick-server`; `verified-on` re-set to 2026-09-03 on the five pages
whose keys or subjects were checked in the source (`leafnode`, `config-keys`, `defaults-and-limits`,
`js-api-subjects`, `js-api`) and on the two release entities; index lines for both summaries and the
docs-issues bullet recounted (63: 55 `nats-docs`, 6 ADR repo, 1 `natscli`, 1 blog). Bank unchanged at
119 / 158 — no open row is closed by release notes alone; rows 63, 64, 130, 14, 9, 13, 76, 91, 139
gain material. Unlanded 0; lint clean, **317 pages**, drift 0, staleness 0. Docs issues 60 → 63.

## 2026-09-03 — the `since:` sweep over the reader layer (phase D, step 7)

The measured half of the change layer. A script listed every page under `concepts/`, `internals/`,
`operations/`, `gotchas/` and `reference/` with `verified-against` and no `since:` — **55** (three of
them with an empty `since: []`). For each, the 2.10 release bodies were grepped for the page's
subject: a fix to the subject in a 2.10.x body proves it present at 2.10, the oldest line this wiki
covers, which is what `since: [2.10]` means here (the plan's convention; the frontmatter line now
carries the comment *present at 2.10, the oldest line this wiki covers; not the arrival* so no reader
takes it for a birth date). **47 pages** got `since: [2.10]`; on the 21 concept and internals pages
among them a *Since* line at the head of *Version notes* says so in words, names the first 2.10.x
body that patches the subject and cites `s-relnotes-2.10`; `subject-transforms` states the one real
arrival — stream-level transforms, republish on mirrors and sources and the partition function are
*Added* in v2.10.0 (#3814 …) while account-level mapping is older. **8 pages** could not be dated
from any source read and keep no `since:`, each with a one-line `## To verify` item saying why:
`jetstream-domain`, `cross-domain-sourcing` and `streams-not-visible-across-a-leafnode` (domains are
first patched in v2.12.5; no body records their arrival), `object-store` (no body names it; ADR-20
gives no server version), `ordered-consumer` (ADR-17 gives none; v2.11.2 is the first body to mention
them), `how-clients-reach-a-cluster` (`client_advertise` / `no_advertise` dated by nothing read),
`kv-watchers-stall-the-cluster` (watchers named only in v2.11.5) and `stream-has-high-message-lag`
(the warning appears in no body). The pre-existing 17 pages with a `since:` were left as they were,
including `websocket`'s `[2.11]`, which the page justifies (the cookie settings). Residue **55 → 0**
by the script's measure (a page has `since: [x]`, or the `## To verify` reason). Lint clean, 317
pages, drift 0, unlanded 0.

## 2026-09-03 — the default change layer: `check-defaults.py` at v2.10.29, v2.11.17, v2.12.15 (phase D, step 8)

`python3 tools/check-defaults.py --tag v2.10.29 / v2.11.17 / v2.12.15` (the last patch of each line;
tarballs cached under `.cache/`), three reports in `inbox/` beside the v2.14.6 one, unregistered as
the plan says. Totals, disagree / unresolved / agree of 216 documented defaults: **v2.10.29 13 / 37 /
166 · v2.11.17 14 / 29 / 173 · v2.12.15 14 / 27 / 175 · v2.14.6 15 / 26 / 175**. The *server* column
diffed in sequence:

| hop | resolved value moved | keys that become resolvable (arrivals) | keys that become unresolvable |
|---|---|---|---|
| v2.10.29 → v2.11.17 | none | `jetstream.max_buffered_msgs` = 10,000 and `max_buffered_size` = 128 MB (2.11.0 #5796); `jetstream.strict` unset = off (2.11.0); `mqtt.js_api_timeout` = 5s (2.11.3); `websocket.ping_interval` → global 2m (2.11.12 #7614); `cluster` / `gateway` / `leafnodes.write_deadline` → global 10s (parsed at v2.11.17, announced only by 2.12.1 #7405) | — |
| v2.11.17 → v2.12.15 | **`jetstream.max_buffered_msgs` 10,000 → 100,000** (2.12.0 #6633, confirmed by the body; docs print the 2.11 value — #22) | `jetstream.limits.batch.max_inflight_per_stream` = 50, `max_inflight_total` = 1,000, `max_msgs` = 1,000 (2.12.0, ADR-50; all agree with the docs) | `jetstream.strict` — 2.12 inverted the option (`NoJetStreamStrict = !v`), the mechanism of "on by default" |
| v2.12.15 → v2.14.6 | none | `jetstream.info_queue_limit` → `request_queue_limit` = 10,000 (2.14.0 #7898, the key unnamed in the body; docs print 100,000 — #22) | — |

So the archive's one default that *moved* on a documented key is `max_buffered_msgs`, and it was
already in the bodies and on the pages; the rest of the diff is arrivals, which is the change layer
the resolver can see — the semaphore, `dial_timeout` and the feature-flag defaults are keys whose
defaults the docs never state, so the reports are blind to them (they are on the pages from step 6).
One finding the diff produced that the bodies could not: **docs issue #64** — five generated pages
say "Available since NATS Server `2.12`" for keys the 2.11 line parses (`write_timeout` 2.11.11,
`websocket.ping_interval` 2.11.12, the three block-level `write_deadline` at v2.11.17), verified in
`opts.go` at v2.11.17 and v2.10.29 and recorded in
`raw/nats-server-src/backported-keys-v2.11.17.md` (manifest row extended). A second product:
`info_queue_limit` had been missed in step 6 because the 2.14.0 body names the queue and not the
key; now on `s-relnotes-2.14`, `config-keys` and `defaults-and-limits`. Ripple: the four release
entities each gain *The default diff at v2.x.y*; `slow-consumer-detected` gains the #64 note. The
older tags' extra *unresolved* rows are the keys their parsers lack, not resolver gaps — reported,
not papered over. Lint clean.

## 2026-09-03 — phase D closed: the change layer (step 9)

Grep-verified: each of the five release entities cites its `s-relnotes-*` summary in `sources:` and
in the body (2.10 ×9, 2.11 ×6, 2.12 ×8, 2.14 ×6, 2.15-preview ×3 links) and no "not a changelog"
note remains. Bank rows **159** (which patch of a minor to be on, and what each fixed) and **160**
(when a key, default, subject or header arrived) added as `own` — the discussions index and the
comment cache were searched for *release notes*, *changelog*, *what's new*, *which version*, *patch
release* and hold only gh#3778 (row 63) and a maintainer's "be current with the latest version and
patched release" — and both answered on arrival by the release entities' *Which patch to be on*
sections and the reference tables' per-minor *Defaults that moved* / *Keys that arrived*. Bank 119 /
158 → **121 / 160**, `own` 11. Nothing struck in the backlog (no section is this phase's). The plan's
result line written. Over the phase (two sessions, 2026-09-03): 70 release bodies, the TOC, five
per-minor summaries, five entities rewritten, ~170 version-note sections, `since:` on every reader
page with `verified-against` (47 + 8 reasons, residue 0), three default reports and the diff, docs
issues #54–#64, the subject-tree correction; 310 → 317 pages, bank 116 / 137 → 121 / 160, docs issues
53 → 64, unverified 12 (unchanged), lint clean at drift 0 · unlanded 0 · staleness 0 behind 2.14.6.

## 2026-09-03 — phase E, step 1: `reference/system-subjects`, and the endpoint correction

Plan `inbox/plan-the-reference-layer-2026-09-03.md` written first, after reading
`raw/nats-docs/reference/system/` (23 pages) and `reference/jetstream/` (59 pages) end to end; the
seven findings of that read are in the plan head. Step 1 then: `server/jetstream_events.go` and
`accounts.go` at v2.14.6 fetched into the cache; `raw/nats-server-src/system-subjects-v2.14.6.md`
(25 verbatim ranges of `events.go`, `server.go`, `accounts.go`, and `jetstream_events.go` whole) and
`system-subjects-observed-v2.14.6.md` with `system-subjects-run.sh` (eight runs on the lab cluster and
a standalone two-account server with a latency export and a leaf); gh#5768 and gh#5902 fetched
(`raw/gh-discussions/`). **Eight summaries**: `s-nats-server-system-subjects`,
`s-nats-server-system-subjects-observed`, `s-docs-system-monitor-reference`,
`s-docs-system-advisories-and-metrics`, `s-docs-jetstream-api-index`,
`s-docs-jetstream-advisories-reference` (24 pages swept field by field against
`jetstream_events.go`), `s-gh-5768-track-connected-clients`, `s-gh-5902-leafnode-connect-events`.
**Page** `wiki/reference/system-subjects.md`: the fifteen `$SYS.REQ.SERVER.PING.<Z>` requests with
their envelopes and HTTP twins (three have none), the account requests and the two built-in imports
an ordinary user may use, the claims and auth subjects (moved from `js-api-subjects`), every event
with its body and cadence (`STATSZ` 10 s, `CONNS` 30 s on both subjects, never for `$G`), the
subjects the docs name that do not exist, permissions, a cheat sheet, version notes.
**A wiki bug fixed**: `monitoring-endpoints` had inherited the docs' list and printed `/statsz`,
`/profilez` and `/idz` as endpoints — all three are 404 on 2.14.6; the table is now the mux's
(`/stacksz`, `/debug/vars`, `/subscriptionsz` added), and its 2.10 note that `/expvarz` arrived in
2.10.16 corrected (the request did; the HTTP path is `/debug/vars`, 2.11.11 / 2.12.2, #7469 — read
off `server.go` at twelve tags). **Ripple** (11 pages): `monitoring-endpoints`, `advisories`
(*System events* corrected — `SERVER.CONNS`, the heartbeat, `SHUTDOWN` after lame duck — the bodies
sweep under *A docs error*, two *To verify* items struck), `js-api-subjects` (the `$SYS` table → a
pointer; *What the operation pages add*), `account`, `reload-server-config` (the observed `RELOAD`),
`evict-a-sick-server`, `nats-cli`, `nats-surveyor`, `prometheus-nats-exporter`,
`slow-consumer-detected`, `leafnode` (gh#5902 settled: the leafnode-connect event needs gateways and
has no disconnect twin). **Docs issues #65–#72** (64 → 72): the three non-endpoints and two
undocumented paths; `CONNECTIONS` and "limits reached" versus a 30 s heartbeat; the service-latency
subject and `error`/`description`; `max_connections` as a duration; `stream/names` `consumers`;
four wrong advisory bodies (`consumer_seq` string, `snapshot_create` `blocks`/`block_size`,
`stream_action` `template`, the `unsupported` reason); the missing `domain`/`account` and copied
descriptions (`enhancement`); `metric.md`'s stream-level toggle. **Server issues SI-4, SI-5** (3 → 5):
connect events stamped UTC and disconnect events local; no `SHUTDOWN` after a client-less lame-duck
exit. **Bank**: rows 161 (own), 162 (gh#5902), 163 (gh#5768) added and answered on arrival; rows 54
and 82 gain the page — 121 / 160 → **124 / 163**, `own` 12. Docs coverage: `reference/system` 23/23,
`reference/jetstream` 59/59 read (each page in a summary). Manifest rows extended, cache INDEX
updated. Lint: **326 pages**, wanted 0, drift 0, unlanded 0, staleness 0 behind 2.14.6.

## 2026-09-03 — phase E, step 2: `reference/stream-and-consumer-config`

`raw/nats-server-src/stream-consumer-config-v2.14.6.md` (27 ranges: `StreamConfig`, `ConsumerConfig`
and their nested structs, `checkStreamCfg`, `configUpdateCheck`, `setConsumerConfigDefaults`,
`checkConsumerCfg`, `checkNewConsumerConfig`, `updateConfig`, the batch constants, the limit structs,
the policy enumerations, the two timestamp sites) and `config-mutability-observed-v2.14.6.md` with
three run scripts (raw `$JS.API` updates against every fixed, one-way and free field of a stream and a
pull consumer; what sealing forces; an ephemeral's defaults; `subjects_filter`; a pull of `batch: 300`
served in full). Two new raw collections: `raw/jsm-go/` (the stream and consumer JSON schemas at
jsm.go v0.4.1 — 38 and 34 properties, the consumer descriptions the docs never render) and
`raw/nats-cli/` (`stream add/edit`, `consumer add/edit` help at 0.4.0). gh#3944 fetched. **Eight
summaries**: `s-nats-server-stream-consumer-config`, `s-nats-server-config-mutability-observed`,
`s-jsm-go-config-schemas`, `s-nats-cli-help-0.4.0`, `s-gh-3944-subjects-in-a-stream`,
`s-adr-33-metadata`, `s-adr-34-multiple-filters`, `s-adr-9-idle-heartbeats` (ADR rows 9, 33, 34
linked). **Page** `wiki/reference/stream-and-consumer-config.md`: 38 stream and 35 consumer fields —
type, the server's default, the minor of arrival, *after creation* (free / fixed / one-way /
conditional, with the refusal string as the binary produced it), the CLI flag, the rule that bites;
the three limit layers; *Which subjects a stream holds*; *Which clock stamps a message* (the leader's,
`stream.go:6929–6931` — row 140). **Corrections the source forced**: the API's `ack_policy` default is
`none` (the CLI's is `explicit`), `ack_wait` / `max_ack_pending` are filled in only for `explicit` and
`all`, `max_waiting` defaults to 512; the batch-publish limits (1000 / 50 / 1000 / 10 s) are the
compiled-in defaults — the `(unverified)` on `defaults-and-limits` cleared (12 → 11). **Ripple** (18
pages): `stream` (*What you cannot change later* rebuilt with every refusal string; *Which clock
stamps a message*), `consumer`, `defaults-and-limits`, `config-keys` (`jetstream { limits }`),
`publishing`, `nats-cli`, `jsm-go`, `js-api-subjects`, and pointer sections on `message-ttl`,
`message-scheduling`, `mirrors-and-sources`, `direct-get`, `priority-groups`, `retention-policies`,
`replicas`, `stream-placement`, `key-value`, `subject-transforms`. **Docs issues #73–#75** (72 → 75):
the pull `batch` "Maximum: 256" the server does not enforce; the consumer schema's `opt_start_time`
naming the wrong policy (destination jsm.go); `restore.md`'s label. **Bank**: rows 140 and 146
filled, row 164 (own — the mutability question, searched and not found) added and answered, ten
answered rows gain the page — 124 / 163 → **127 / 164**. A harness lesson recorded in the observed
file: pass 1 copied `allow_rollup_hdrs: true` forward and six cases had to be re-run. Lint: **335
pages**, wanted 0, drift 0, unlanded 0, unverified 11, staleness 0 behind 2.14.6.

## 2026-09-03 — phase E, step 3: `reference/metrics`

`prometheus-nats-exporter` v0.20.2 and `nats-surveyor` v0.9.11 installed with `go install` (module
versions confirmed with `go version -m`; both binaries print `0.0.0`), the exporter's `collector/`,
`exporter/exporter.go` and `main.go` cached at the tag, and `server/client.go` + `raft.go` added to the
v2.14.6 cache. **Three raw files quote the sources**: `raw/prometheus-nats-exporter-src/collector-v0.20.2.md`
(the two namespaces `gnatsd` / `jetstream`, the flattening rule and its drop list, 33 JetStream
descriptors and their labels, the `/jsz` query per `-jsz` value, `healthz_status` inverted, the inverted
"defaulting to varz" test), the appendix of `raw/nats-surveyor-src/metrics-observed-v0.9.11.md`
(`Prefix string // TODO`, the literal `nats` namespace, `jsServerLabels` vs `serverLabelValues`) and
`raw/nats-server-src/traffic-counters-and-ha-assets-v2.14.6.md` (the atomic counters, the
follower branch of consumer info, `streamNumPending`, `numRaftNodes`, `max_ha_assets` at creation and
placement). **Thirteen scrapes on the lab** (three nodes, an R3 stream with 30 messages, a pull consumer
holding 10 twice-delivered unacked messages, an R1 mirror and an R1 source on n2; scripts
`metrics-run.sh` / `metrics-run2.sh` beside the exporter file): every collector on → **167 series**
(139 `gnatsd_*`, 28 `jetstream_*`, 135 of the core ones gauges, four `connz` counters); `-prefix nats`
renames all 167; the R1 streams and the mirror/source lag series appear on n2's exporter only;
**`num_pending` 20 on the consumer leader, 0 on both followers** while `num_ack_pending` and
`num_redelivered` agree (exporter and surveyor alike); `-jsz=streams` drops the `limit_*` series and
the raft label; no collector flag → `[FTL] … no Collectors specified`; `-jsz=all` alone → "Defaulting
to varz" and 84 `varz` series unasked; `gnatsd_healthz_status 0` on a healthy node; `-connz_detailed`
prints `account=""` for a `$G` client (the server omits it); surveyor → **105 series**, `--prefix x`
renaming nothing, `--jsz-leaders-only` 439 → 411 samples (one per asset, not half), the three `raftz`
series with `cluster_name` and `server_id` swapped. Four discussions promoted (2818, 3857, 6182,
5128) and one exporter issue (#218, 0 / 8 / 0 across pods, open since 2023) rendered into
`raw/gh-issues/` — the first file there from another repository, the manifest row says so. **Nine
summaries** (one over the step's seven: gh#3857 and gh#6182 are one-paragraph threads):
`s-prometheus-nats-exporter-collector`, `s-prometheus-nats-exporter-metrics-observed`,
`s-nats-surveyor-metrics-observed`, `s-nats-server-traffic-counters-and-ha-assets`,
`s-gh-2818-counters-exact-or-sampled`, `s-gh-3857-consumer-pending-series`,
`s-gh-6182-what-to-alert-on`, `s-gh-5128-ha-assets`,
`s-exporter-issue-218-num-pending-differs-per-node`. **Page** `wiki/reference/metrics.md`: the naming
rule and the prefix table; which node's exporter to read; one table per collector (`varz` 83, `connz`
10 + 11 detailed, `healthz` 6, `routez` 3, `subsz` 12, `accstatz` 9, `accountz` 15, `leafz` 9,
`gatewayz` 24, `jsz` 33) with field, labels, type and dated arrivals; surveyor's eight families;
*The series behind the alerts* (quorum, lag, disk, consumer pending, redeliveries, down, latency —
and what has no series: the advisories, `js-meta-only`, per-stream Raft lag, per-message latency);
*Counters are exact*; `ha_assets`; the docs gaps; *How this was derived*; *Version notes*. **Ripple**
(16 pages): four corrections in place — `prometheus-nats-exporter` (the three-label series sample
replaced by the seventeen-label one, the prefix row and bullet now naming `gnatsd_`, "a blank
invocation exports almost nothing" → it does not start), `nats-surveyor` (the cheat sheet's
`--prefix nats` line, "halves the noise" → one sample per asset), `monitoring-endpoints` (*From an
endpoint to a time series* rewritten: both prefixes, the pointer, the two facts), `slow-consumer-detected`
(the *To verify* item on a per-account exporter metric struck and answered: `gnatsd_accstatz_slow_consumers`
yes, per connection no) — and sections on `advisories` (*none of the four is a series*), `consumer`
(*The consumer's numbers as time series*), `worker-pool`, `jetstream-out-of-disk`,
`stream-has-high-message-lag`, `nats-top`, `jetstream-sizing` (*HA assets: the unit the maintainers
size by*), `stream-placement` (`max_ha_assets` in peer selection), `jetstream-slows-as-consumers-grow`,
`raft-in-nats` (surveyor's Raft series), `system-subjects`, `config-keys`. Not rippled:
`nats-helm-charts` — the chart's `values.yaml` in `raw/github-repos/` states no exporter flags, so
there is nothing to cite. **Docs issues #76–#78** (75 → 78): the learn page's dangling "documented in
Reference" and the never-named `gnatsd_` default (`missing`); surveyor's `--prefix` help for a flag
that is a `// TODO` (`wrong-value`, destination `nats-surveyor` — a new destination); the
`nats_consumer_num_pending` sample that never says "leader only" (`enhancement`). **Three tool
behaviours recorded on the entity pages and in neither inbox file, because they are code, not
documentation and not nats-server** — candidates for the two tool repositories: the exporter's
inverted flag test (`main.go:79–88`: no flags fatal, `-jsz` alone adds `varz`), the exporter's
missing `js-meta-only` collector, surveyor's shifted `raftz` labels (`collector_statz.go:953` vs
`:356–358`). **Bank**: rows 139, 153 and 129 filled (129 by the alert table; the runbook stays with
G6), rows 22, 57, 59, 60, 83, 84, 85 gain the page, row 165 (exporter #218) added and answered —
127 / 164 → **131 / 165**. Lint: **345 pages**, wanted 0, drift 0, unlanded 0, unverified 11,
staleness 0 behind 2.14.6.

## 2026-09-03 — phase E closed: the reference layer (step 4)

Every clause of the plan's *Done when* checked with the tool that measures it. The Reference group
of `wiki/index.md` carries the three lines (`system-subjects`, `stream-and-consumer-config`,
`metrics`, nine pages in the folder); each of the three pages carries `verified-against: nats-server
2.14.6` (`metrics` the exporter's v0.20.2 and surveyor's v0.9.11 as well) and a *How this was
derived* section naming file, line and run; `monitoring-endpoints` lists the fifteen paths the mux
registers and nothing else. **Bank**: rows 82, 139, 140, 146 filled; rows 15–17, 21, 22, 28, 57, 59,
71, 83–85, 88, 116, 151, 160 name the page that now answers them; row 129 filled by `metrics` (the
`production-alerting` runbook stays with G6); rows 161–165 added over the phase — 131 / 165, `own` 13.
**`inbox/docs-issues.md`**: #65–#78 each have a row in *Where the wiki records each of these* —
fourteen issues from the phase, eleven `wrong-value` or `missing` and three `enhancement`, two
destinations new to the file (`jsm.go`, `nats-surveyor`); every contradiction the plan's *What the
read found* listed is among them. **Docs coverage of the two trees**, stated as the plan asks:
`reference/system/` — 23 pages, 22 read into a summary (`s-docs-system-monitor-reference`:
`monitor.md` and the 14 endpoint pages other than `raftz`; `s-docs-monitor-raftz`;
`s-docs-system-advisories-and-metrics`: `advisory.md` + 3, `metric.md` + 1), 1 skipped with a reason
— `errors.md`, the system error strings a client is shown, which is phase F's material (the plan's
scope decision 5). `reference/jetstream/` — 59 pages, 58 read (`s-docs-jetstream-advisories-reference`:
`advisory.md` + 22, `metric.md` + 1; `s-docs-jetstream-api-index`: `api.md`, the four index pages
and the 25 operation pages; `s-docs-stream-config`, `s-docs-consumer-config`,
`s-docs-jetstream-headers`), 1 not re-ingested — `errors.md`, already the source of the 222-code table
on [[error-codes]] through [[s-adr-7-server-error-codes]]. The megaplan's baseline read 1/23 and
3/59. `python3 tools/check-staleness.py`: 0 behind 2.14.6, 0 without `verified-against`, 7 authority
unknown (unchanged). `local/scratch/INDEX.md` pruned: the promoted discussion, issue, Stack Overflow,
jsm.go schema, Synadia and release-page caches deleted after their `raw/` copies were checked (the
release pages were the `--offline` input of `tools/triage-releases.py`; a `--fetch` restores them);
gh#3772 and the discussions comment cache kept for phase G, the server and exporter sources at their
tags and the five run directories kept as the unedited originals. Over the phase (four sessions,
2026-09-03; three ingests of 8 + 8 + 9 summaries): 317 → **345 pages**, three reference pages,
25 summaries, four new raw collections (`jsm-go`, `nats-cli`, `prometheus-nats-exporter-src`,
`nats-surveyor-src`), eight system-subject runs, three update passes and thirteen scrapes on the
lab, 45 page-ripples with five in-place corrections, docs issues 64 → 78, server issues 3 → 5
(SI-4, SI-5), bank 121 / 160 → 131 / 165, unverified 12 → 11; lint clean at drift 0 · unlanded 0,
wanted 0, staleness 0 behind 2.14.6. The plan's result line written; phase F proposed in
`local/megaplan.md`.

## 2026-09-03 — phase F, the read and the plan: the client side

Operation: plan (written), no ingest. Read end to end, for `inbox/plan-the-client-side-2026-09-03.md`:
`raw/nats-docs/learn/core-nats/` (11 pages + the chapter index), `learn/resilient-clients/` (8 + index),
`learn/services/` (6 + index), `reference/protocols/` (4 + index), and — beyond the megaplan's list,
because the chapters point at them — `reference/services/` (3 + index), `concepts/` (11) and
`reference/config/mappings/` (4). 45 articles; none summarised yet, none entered the wiki today. The
read's notes are cached as `local/scratch/digest-*.md` (never cited). What it found, carried into the
plan's *What the read found*: the three `learn/` chapters are unversioned by design, so every
`verified-against` this phase writes comes from the server at v2.14.6, nats.go at v1.53.1 and natscli
0.4.0; `reference/protocols/client.md`'s `-ERR` table gives 1 s / 1024 / 10 MB where the server has
`AUTH_TIMEOUT` 2 s, `MAX_CONTROL_LINE_SIZE` 4096 and `MAX_PENDING_SIZE` 64 MB (`const.go:117,90,102`)
and never states the ping defaults; `learn/resilient-clients/slow-consumers.md:100` says nats.go
discards slow-consumer reports without a callback while nats.go installs `defaultErrHandler` (v1.52.0
`:1853–1856`, to re-pin); ADR-40's "two consecutive PONGs" disagrees with the chapter and with nats.go's
`pout > MaxPingsOut` — and `upgrade-a-cluster` carries the ADR's four-minute figure (a wiki bug, fixed in
step 3); `learn/services/scaling.md:150,272` make queue-group delivery readiness-aware, against the
random start index at `client.go:5516–5519` (a run in step 2); `reference/services.md` describes
capabilities the schemas do not have; `concepts/` restates the deep dive (nine pages to fold, two already
ingested, three surplus sentences). Verified while reading, from the binaries: `nats reply --queue`
defaults to `NATS-RPLY-22`; `nats request --replies=1 --reply-timeout=300ms --wait-for-empty
--timeout=5s`; `nats server mappings` and `nats trace --deliver` exist on 0.4.0; gh#7577's chosen
answer (row 25) read from the comment cache. Plan: nine steps (core NATS ×2, resilient clients ×2, the
wire protocol, services, `core-or-jetstream`, the client entities, close), ~28 summaries, 12 pages, the
runs named per step. `local/megaplan.md` phase F: `plan file:` set, `next:` = start step 1, sessions
revised ~3 → ~9. No page, bank cell or docs-issue row changed; lint unchanged at 0 · 0.

## 2026-09-03 — query: `share: true` on a service import, `Nats-Request-Info`, activation tokens

Operation: query. The question, in its open-source shape: a service in its own account authorises
callers from the `Nats-Request-Info` header the server stamps on a service import; the header carries
the user only when the tenant's import has `share: true` — is that a supported setting, what else is in
the header, what is known to bite, and can an export every tenant imports be guarded with an activation
token per tenant instead of an `accounts` list. Read: [[cross-account-sharing]], [[synadia-products]],
`server/{accounts,client,jetstream,jetstream_api,stream,events,opts}.go` at v2.14.6 from the scratch
cache, `nats-io/jwt` v2.8.2 `v2/{imports,exports,activation_claims}.go` (the tag `go.mod` pins at
v2.14.6; fetched to `local/scratch/src/jwt-v2.8.2/`), `nats-io/nsc` `cmd/{addimport,addexport,generateactivation}.go`
at `main` (fetched to `local/scratch/src/nsc-main-2026-09-03/`), `nats auth account imports add --help`
and `exports add --help` on natscli 0.4.0, nats-server issue #8271 and PR #8278 via `gh`, and advisory
GHSA-55h8-8g96-x4hj (CVE-2026-33246). **Run** (`local/scratch/runs/share-import/`, nats-server v2.14.6,
config mode, two accounts): without `share` the responder saw `Nats-Request-Info:
{"acc":"APP","rtt":268000}`; with `share: true` on the import, after `--signal reload`, it saw
`{"start":…,"host":"127.0.0.1","id":10,"acc":"APP","user":"app","name":"tenant-agent-1","lang":"go","ver":"1.51.0","rtt":196958,"server":"sharelab","kind":"Client","client_type":"nats"}`.
What the wiki knows: `share` is `jwt.Import.Share` (`imports.go:42`, valid on service imports only,
`imports.go:88–90`), read by the server at `accounts.go:2199–2203`, a config key at `opts.go:4505`, a flag
on both `nsc add import --share` and `nats auth account imports add --share`; `getClientInfo(detailed)`
(`client.go:6590–6622`) adds `user`, `name`, `host`, `id`, `start`, `lang`, `ver`, `jwt`, `issuer_key`,
`name_tag`, `tags`, `kind`, `client_type` and the server/cluster only when `detailed` is the import's
`share`; on a chain of imports the **first** import's `share` decides (`client.go:4932–4935`); the
system account's own `$JS.API.>` import is forced to `share = true` (`jetstream.go:795`) and the
JetStream API refuses requests without the header (`jetstream_api.go:810–815`) — the mechanism is
load-bearing for JetStream itself; a stream strips the header before storing (`stream.go:6357`).
Known to bite: #8271 (open, `defect` + `stale`, fix PR #8278 unmerged 2026-09-03: the header is added
after the `max_payload` check, so a request within a header's size of the limit is delivered oversized);
CVE-2026-33246 (a leafnode could forward a spoofed header; fixed 2.11.15 / 2.12.6, "no workarounds");
the header's `acc` is rewritten to the hub-side account name across a leafnode
(`client.go:5757–5783`). Export guards: `checkAuth` (`accounts.go:2863–2882`) tries
`account_token_position`, then `token_req` → `checkActivation` (`3046–3087`: issuer = the exporting
account or its signing key, subject = the importer, import subject contained, unexpired, not in
`revocations`), then the `accounts` list; only `token_req` leaves the exporter's JWT untouched when an
importer joins — revocation rewrites it. NGS's pre-auth `INFO` (read without credentials, not recorded
in `raw/`) reports `version 2.14.6`, `max_payload 8388608`. Not in the wiki, and out of its scope: the
Control Plane REST API, its UI and its token model — commercial, no public source read. **Bank**: rows
166–168 added (166, 167 posed; 168 asked, #8271), none answered. **Docs issues**: #79 (six
import/export keys the parsers accept and the config reference omits, both sibling pages swept) and
#80 (activation tokens on no page; zero `nsc` pages in the mirror). No page changed; a
`service-import-request-info` page or a *Cross-account sharing* section was offered.

## 2026-09-03 — ingest: `share: true`, `Nats-Request-Info` and the export guards (from the query above)

Operation: ingest, on the user's "yes please we should add that to the wiki". Eight sources entered
`raw/`, each with a summary: `raw/nats-server-src/service-imports-v2.14.6.md`
([[s-nats-server-service-imports]] — the server ranges at v2.14.6 plus v2.10.0 for the arrival, including
`getRawAuthUser`, which makes `user` a public key for a JWT login and `[REDACTED]` for a token);
`raw/nats-server-src/share-import-observed-v2.14.6.md` with `share-import-run.sh` and
`share-import-rawsub.py` ([[s-nats-server-share-import-observed]] — four scenes: the two shapes, the
two-hop chain where the first hop decides, `max_payload: 256` delivering `HMSG … 257 507`, and `share`
on a stream import accepted silently); `raw/jwt-src/imports-exports-activation-v2.8.2.md`
([[s-jwt-imports-exports-activation]], the tag nats-server v2.14.6 pins; new collection `jwt-src`);
`raw/nsc-src/import-export-activation-v2.15.0.md` ([[s-nsc-imports-exports-activation]]; new collection
`nsc-src`); `raw/gh-issues/issue-8271.md` with the whole PR #8278 thread
([[s-issue-8271-request-info-max-payload]] — **the PR's maintainers lean towards not enforcing**:
"it is generally about what the client sends not what the server needs to add to it", which corrects the
query's "fix pending" reading); `raw/gh-advisories/GHSA-55h8-8g96-x4hj.md` + `secnote-2026-08.txt`
([[s-ghsa-2026-08-request-info-spoofing]]; new collection `gh-advisories`);
`raw/nats-cli/help-auth-account-exports-imports-0.4.0.md` ([[s-natscli-auth-exports-imports]]); and the
docs' `reference/config/accounts/{exports,imports}` pages already in the mirror
([[s-docs-config-accounts-exports-imports]]). **Created**: [[service-import-request-info]] (concept:
the header's two shapes, what `user` holds, the first-hop rule, the leaf rewrite, the stream strip, the
JetStream dependence, `share` in JWT / nsc / nats auth / config, #8271, the CVE, and the design notes for
a multi-tenant service). **Updated**: [[cross-account-sharing]] — a pointer in *How it behaves* and the
new *Who may import: the three export guards* (with the correction that **a JWT export has no account
list**: operator mode has `token_req` and `account_token_position` only), the *To verify* item on the
generated reference closed, `since` comment and `verified-on` re-pinned; [[leafnode]] (*The request-info
header across a leaf*); [[js-api]] (*The header every API request carries*); [[publishing]] (the
`max_payload` overshoot); [[operator-mode]] (*Private exports and activation tokens*); [[nsc]] and
[[nats-cli]] (cheat-sheet lines); [[config-keys]] (a new `accounts { exports, imports }` table with the
six unlisted keys marked); [[s-relnotes-2.11]] (the 2.11.15 row now names the CVE's fix line). Index:
the concept, eight summaries, a new group *The `jwt` library and `nsc`*. `raw/sources.md`: three rows
appended, three added. **Bank**: 166 → [[service-import-request-info]] · [[cross-account-sharing]];
167 → [[cross-account-sharing]] · [[operator-mode]] · [[nsc]]; 168 → [[service-import-request-info]] ·
[[publishing]]. **Docs issues** #79 and #80 now point at the pages. **Server issue SI-6** added
(`share` on a stream import: config-mode no-op, JWT-mode error; searched, nothing upstream). Nothing about
the customer or the person who measured the API entered the repo. Lint: 354 pages (345 → 354), drift 0,
unlanded 0, wanted 0, unverified 11 (unchanged), staleness 0 behind 2.14.6.

## 2026-09-03 — phase F step 1: core NATS, part 1 — delivery, subjects and mapping

Operation: plan, `inbox/plan-the-client-side-2026-09-03.md` step 1 (*Operation: ingest*, ten summaries —
the plan's six plus three small threads the bank rows can cite and one release body). **Sources into
`raw/`**: gh#7577 whole (`raw/gh-discussions/gh-7577.md`, row 25's thread), gh#5097, gh#2855 and gh#5172
(the public forms found for the posed rows); `raw/nats-cli/help-core-0.4.0.md` (six `--help` blocks,
verbatim); `raw/nats-server-src/core-delivery-v2.14.6.md` (16 verbatim ranges: `isValidSubject`, the two
`PUB` parsers, the pedantic check, echo, the `no_responders`-needs-headers check, the 503 `HMSG` with
`Nats-Subject`, `max_subscription_tokens`, `no_header_support`, top-level `mappings` as `$G`,
`AddWeightedMappings` / `selectMappedSubject`, `/subsz`, the reload rule, the `$NRG.` refusal) and
`core-delivery-observed-v2.14.6.md` with `core-delivery-run.sh` and `core-delivery-raw.py` beside it
(runs A–G plus F8 on the binary, D6 on the lab); `raw/github-repos/nats-io__nats.go.release-v1.48.0.md`.
Four manifest rows extended. **Read and folded** (named here as the plan requires): `concepts/subjects.md`
into `s-docs-core-nats-subjects-and-mapping` (three surplus lines carried as pointers: L10 "any UTF-8",
L1101 the 16-token limit, L1080–1087 `_INBOX` under `$`); `concepts/pub-sub-basics.md`, `what-is-nats.md`
and `intro.md` into `s-docs-core-nats-publish-subscribe` (nothing the learn pages lack; the "~15MB" footprint
not recorded); `reference/config/mappings.md` + `destination.md`, `weight.md`, `cluster.md` into the first.
Docs coverage after this step: `learn/core-nats` 8/11 (`request-reply.md`, `queue-groups.md`,
`scatter-gather.md` are step 2), `concepts` 6/11 (`subjects`, `pub-sub-basics`, `what-is-nats`, `intro`
folded here; `ecosystem`, `getting-started` prior), `reference/config/mappings` 4/4.
**Summaries** (10): [[s-docs-core-nats-subjects-and-mapping]], [[s-docs-core-nats-publish-subscribe]],
[[s-gh-7577-core-nats-ordering]], [[s-nats-server-core-delivery]], [[s-nats-server-core-delivery-observed]],
[[s-nats-cli-core-commands]], [[s-gh-5097-subject-token-limit]], [[s-gh-2855-publish-with-wildcards]],
[[s-gh-5172-mapping-in-config-or-stream]], [[s-nats-go-relnotes-1.48.0]]. **Pages created** (2):
[[core-nats-delivery]] (row 25 — at-most-once, order per publisher connection across subjects from gh#7577,
echo, `max_payload` over header plus body, the header negotiation, the connection's part through a restart
and a lame duck, the four debugging surfaces as a table, the config table) and [[subjects-and-wildcards]]
(the rule table by `SUB` / default `PUB` / pedantic `PUB`, the two wildcards, the six reserved prefixes and
who enforces them, no length limit / `max_control_line` / `max_subscription_tokens`, cardinality pointers).
**Updated** (12): [[subject-transforms]] (*Account-level `mappings`* — weights, the remainder rule measured
on a literal and a wildcard source, partition, `cluster`, reload through `accounts`, the maintainer's
placement rule; the "different topic" sentence now points there), [[defaults-and-limits]] (the rows'
behaviour when crossed, `max_subscription_tokens`, `no_header_support`; `verified-on` re-pinned),
[[config-keys]] (three top-level keys with reload checked; re-pinned), [[monitoring-endpoints]] (the `/subsz`
row corrected to the HTTP names `acc`, `subs` — docs issue #48's `/subsz` half had not landed on the table —
and a `/subsz?test=` section; re-pinned), [[slow-consumer-detected]] (the client-side sibling),
[[publishing]] (core order for comparison), [[nats-cli]] (the core commands from `--help`),
[[nats-server-2.11]] (`nats trace` is this line's feature), [[nats-py]] and [[nats-c]] (the chapter's
claim that their publish skips the whitespace check — the docs' word until step 8), [[nats-go]] (subject
validation since v1.48.0, dated from the release body), [[unauthenticated-clients-still-connect]] (what a
bare server answers). **What the runs settled beyond the docs**: the header block counts against
`max_payload` and a violation closes the connection; pedantic mode sends `-ERR 'Invalid Publish Subject'`
and delivers anyway; `max_subscription_tokens` refuses a reload (`config reload not supported for
MaxSubTokens`); `mappings` reloads as `Reloaded: accounts`; the weighted remainder is dropped only when the
source is listed — for a wildcard source too (98 of 200), against the docs' "literal only"; `nats trace`
needs no system user; under `--signal ldm` a single-server client sees only an EOF disconnect and the server
exits after the grace period once its clients are closed (`lame_duck_duration` has a 30 s floor: `3s` is
refused at start). **Docs issues** #81 (`concepts/subjects.md:1101`, the unsourced 16-token / 256-character
limit — gh#5097 shows it confusing a reader), #82 (`reference/config/max_subscription_tokens.md` empty;
sweep: 7 sibling `max_*` pages' reload labels all agree with `reload.go`), #83 (`_INBOX` under `$`),
#84 (`subject-mapping.md:646,772` "literal source only" — wrong; the server's example config uses a wildcard
source for loss). The 503's `Nats-Subject` header (documented nowhere) waits for step 2's run B, as the
plan says. **Server issue SI-7** (pedantic mode's error-then-deliver; searched: 0 hits in the docs mirror
and the 484 discussions). **Bank**: row 25 → [[core-nats-delivery]]; rows 169 (gh#5097 + gh#2855), 170
(gh#5172), 171 (`own`, searched) added and answered on arrival — 138 / 171. `since: [2.10]` on both new
pages with the *present at 2.10* comment. Lint: 366 pages (354 → 366), drift 0, unlanded 0 (9 → 0 after five pointer paragraphs on `defaults-and-limits`, `nats-cli`, `publishing`, `subjects-and-wildcards`, `config-keys`), wanted 0, unverified 12 (11 → 12: the new marker is the cross-server ordering item under `## To verify` on `core-nats-delivery`), staleness 0 behind 2.14.6.

## 2026-09-03 — phase F step 2: core NATS, part 2 — request/reply and queue groups

Operation: plan, `inbox/plan-the-client-side-2026-09-03.md` step 2 (*Operation: ingest*, nine summaries —
the plan's six plus a source extract for the server, one for natscli, and row 138's thread). **Sources into
`raw/`**: `raw/release-notes/v2.2.0.md` (the GA body, 2021-03-15 — it names JetStream, WebSocket and MQTT
and **never names headers or `no_responders`**); `raw/nats-server-src/headers-arrival-v2.2.0.md`
(`server.go`, `client.go` at v2.1.9 and v2.2.0: nothing matches `headers`/`HMSG`/`503` at 2.1.9, the `INFO`
field, the two `CONNECT` options, the refusal and the 16-byte `NATS/1.0 503` send are at 2.2.0 — so the
signal is dated from the source, and `Nats-Subject` from the v2.12.0 body, #5250);
`raw/nats-server-src/request-reply-v2.14.6.md` (the pmr flags, the tail of `processInboundClientMsg` with
the 503 and `subForReply`, `processMsgResults`' queue selection and delivery, the sublist's weight
expansion, `RS+ … <weight>`, the gateway exclusion); `raw/nats-server-src/request-reply-observed-v2.14.6.md`
with `request-reply-run.sh`, `-run2.sh`, `-run3.sh`, `-run4.sh` and `request-reply-subsz.py` beside it
(runs A–H in four passes: A–D and G on a standalone server, E on the lab, H on a standalone hub with a
standalone leaf); `raw/nats-cli/request-reply-0.4.0.md` (`req_command.go`, `reply_command.go` from the
module at the tag; its go.mod pins nats.go v1.51.0); `raw/gh-discussions/gh-2760.md`. Four manifest rows
extended. **Read and folded**: `concepts/request-reply.md` (into `s-docs-core-nats-request-reply`, with
its L589 first-reply-wins and L1040–1046 `reportNoResponders()` lines) and `concepts/queue-groups.md`
(into `s-docs-core-nats-queue-groups`, with L24, L1528 vs L2131, L2064–2093). Docs coverage after this
step: `learn/core-nats` **11/11**, `concepts` 8/11 (`request-reply`, `queue-groups` folded here; `jetstream`,
`security`, `topologies` remain), `reference/config/mappings` 4/4.
**Summaries** (9): [[s-docs-core-nats-request-reply]], [[s-docs-core-nats-queue-groups]],
[[s-adr-4-message-headers]], [[s-adr-47-request-many]], [[s-relnotes-2.2.0]], [[s-nats-server-request-reply]],
[[s-nats-server-request-reply-observed]], [[s-nats-cli-request-reply-source]],
[[s-gh-2760-one-connection-or-two]]. **Pages created** (2): [[request-reply]] (the mux inbox and
`--inbox-prefix`; the three outcomes as a table with each client's name and the CLI's exit code; the 503's
four preconditions and its bytes, `Nats-Subject` since 2.12.0, the signal since 2.2.0; timeouts;
scatter-gather with ADR-47's four stop conditions and the CLI's flags timed; the 503 across an import for
row 150; one connection or two for row 138; responders; the config table) and [[queue-groups]] (the random
pick — not round-robin, **not readiness-aware**, run C; coexistence, one subject, wildcards, the typo; the
cluster split uniform per member, run E; the leafnode fallback and the hub's skewed split, run H; the
gateway exclusion; `NATS-RPLY-22`; at-most-once; `/subsz` as one server's view). **Updated** (15 + 2 in
place): [[nats-timeout]] (*The 503, and what the CLI's exit code tells you*), [[worker-pool]] (*The core
queue group, measured*), [[gateway]] (*Inside one cluster there is no affinity at all*; **wiki correction**:
its quoted block was off by one line — `2652:`/`2653:` → `2653:`/`2654:`, the range `2637–2654` →
`2638–2654`, checked against `topology-v2.14.6.md:361` and the tarball), [[leafnode]] (*Queue groups across a
leafnode*), [[subject-permissions]] (*The requester's inbox prefix*), [[cross-account-sharing]] (*Run on
2.14.6 — the 503 crosses the import, and names the importer's subject*), [[nats-java]] (*What bites you*:
`reportNoResponders()`), [[nats-cli]] (*`nats request` and `nats reply`, as run on 0.4.0*), [[orbit]]
(*`RequestMany`*), [[nats-js]] (*`requestMany`*), [[nats-net]] (*`RequestManyAsync`, and no responders by
default*), [[monitoring-endpoints]] (*`/subsz` and queue groups: one server, its own members only*),
[[slow-consumer-detected]] (*A queue member cut here leaves its group*); in place: [[core-nats-delivery]]
(the three step-2 pointers now link the pages; row 138's sentence rewritten from gh#2760; the 2.2.0 and
ADR-4 sentences) and [[nats-server-2.12]] (the `Nats-Subject` line points at the page). **What the runs
settled beyond the docs**: the 503 is `HMSG <inbox> <sid> 38 38` + `NATS/1.0 503\r\nNats-Subject: nobody`
and needs the inbox subscription on the requesting connection (B1, B4); `nats request` exits 0 on all
three outcomes and prints nothing on a timeout (B6–B8); a busy queue member keeps its random share — 8 of
20 and 12 of 20 while sleeping a second per request (C); `--replies 3` with two responders returns after
the average reply time plus `--reply-timeout`, `--replies 0` always the full window, and an empty reply
ends a counted gather with or without `--wait-for-empty` (D; the first pass's sentinel run lost a race to
the 300 ms gap and was repeated); inside a cluster the pick is uniform per member — one local and three
remote, 90 / 97 / 106 / 107 (E2) — and `/subsz` shows only the local member; the 503 crosses a service
import in 37 ms and names the importer's subject (G); across a leafnode the publisher's side wins outright
(200 / 0, 0 / 200) and **a leaf's members skew the hub's own split 3 : 1** — 148 / 52, 89 / 311, 297 / 103,
302 / 98; 2 : 1 for two and one; 1 : 1 : 3 for three and two; even without a leaf member (H5–H8). **The
read's claim corrected by the run**: the plan's digest read `processMsgResults` as "same server first"
inside a cluster; run E and `sublist.go:741–747` (a routed entry shadowed once per member) say uniform.
**Docs issues** #85 (`Nats-Subject` on the 503 stated nowhere; sweep: five mentions in the tree, all Direct
Get's), #86 (`learn/services/scaling.md:150, 272` readiness — wrong-value, with run C; recorded now, the
row the services tree owns in step 6), #87 (`concepts/queue-groups.md:1528` "exactly once" vs `:2131`),
#88 (`learn/core-nats/queue-groups.md:218` "a cluster adds a locality preference" — none inside one
cluster, run E), #89 (natscli: the silent timeout at exit 0 and the empty-reply rule; destination
`natscli`). **Server issue SI-8** (the leafnode skew; searched: the topology docs, the 484 discussions for
"queue group" with "leaf", the 2.10.22/2.10.23 release lines — which are about the leaf-side direction).
**Bank**: row 138 → [[core-nats-delivery]] · [[request-reply]] (gh#2760's chosen answer); row 150 gains
[[request-reply]] and *measured*; rows 172–174 added (`own`, the cache searched first — the one queue-group
"round-robin" line is a JetStream thread) and answered on arrival — 142 / 174, `own` 19. `inbox/adr-toc.md`
rows 4 and 47 linked. No strike from any *Pages touched*. `since: [2.10]` on both new pages with the
*present at 2.10* comment; the 503's own dates in the sentence. Lint: 377 pages (366 → 377), drift 0,
unlanded 0 (5 → 0 after three citation sentences on `nats-cli`, `gateway`, `leafnode`), wanted 0,
unverified 12, staleness 0 behind 2.14.6. For step 3: natscli 0.4.0 carries nats.go **v1.51.0** while the
entity pin is v1.53.1 — the extract must say which it quotes; the request/inbox ranges of nats.go
(`NewRespInbox`, `createNewRequestAndSend`, `UseOldRequestStyle`, the 503 check) were read at v1.52.0 from
the module cache and not quoted — add them to the v1.53.1 extract if [[request-reply]] is to cite the
client rather than the docs for "no default timeout" and the mux.

## 2026-09-04 — phase F step 3: resilient clients, part 1 — connecting, reconnecting, draining

Operation: plan, `inbox/plan-the-client-side-2026-09-03.md` step 3 (*Operation: ingest*, six summaries —
the plan's five plus a natscli extract of its own). **Sources into `raw/`**:
`raw/nats-go-src/connection-v1.53.1.md` (26 verbatim ranges of `nats.go` at tag v1.53.1, fetched from
`raw.githubusercontent.com` into `local/scratch/src/nats.go-v1.53.1/` — the const block,
`GetDefaultOptions`, the seven `Status` values, `defaultErrHandler` and where it is installed,
`selectNextServer`, `doReconnect`, the reconnect-buffer check, `processAuthError`, `processPingTimer`,
`drainConnection`, `Drain`, `Flush`, `ForceReconnect`, `StatusChanged`, the pending defaults);
`raw/nats-cli/reconnect-0.4.0.md` (natscli v0.4.0 from the Go module cache: `cli/util.go`'s `natsOpts()`,
`internal/util/backoff.go`, `cli/reply_command.go`, `cli/rtt_command.go`);
`raw/nats-server-src/client-lifecycle-observed-v2.14.6.md` with `client-lifecycle-run.sh`, `-run2.sh`,
`-run3.sh`, `-stale-run.sh`, `client-lifecycle-raw-watch.py` and `client-lifecycle-stale-client.py` beside
it. Three `raw/sources.md` rows extended. **Summaries** (6):
[[s-docs-resilient-clients-connecting]], [[s-docs-resilient-clients-reconnection-and-events]] (with
`where-next.md`'s checklist folded), [[s-docs-resilient-clients-drain-and-shutdown]],
[[s-nats-go-connection]], [[s-nats-cli-reconnect]], [[s-nats-server-client-lifecycle-observed]].
**Pages**: [[client-connection-lifecycle]] (concept — the state machine and every edge: connecting and
discovery, reconnect and what the gap costs, the keepalive, events and readiness, drain and close, flush,
lame duck, and what a JetStream client sees when a leader moves) and [[client-defaults]] (reference —
three tables plus a measured one, each saying which level of evidence it rests on). **Ripples** (14):
[[nats-go]] (*What bites you — the connection*), [[nats-cli]] (*What bites you — the connection the CLI
opens is not the library's*), [[nats-c]] (*What the resilient-clients chapter says about this client*),
[[how-clients-reach-a-cluster]] (*What the client does with the list*), [[core-nats-delivery]] (*The
reconnect gap is at-most-once, measured*), [[nats-timeout]] (*A leadership move gives you no responders*),
[[ack-and-redelivery]] (*What a leader move does to un-acked messages*), [[consumer]] (*What a client sees
when the consumer leader moves*), [[upgrade-a-cluster]] (*What the drain looks like from the client's
side*, plus the four-minute correction below), [[queue-groups]] (*Rotating one member out*),
[[worker-pool]] (*Retiring a worker without losing its in-flight batch*), [[publishing]] (*Flush is a
receipt from the server, not a `PubAck`*), [[defaults-and-limits]] (*Client-side defaults are a different
table*), [[config-keys]] (*Three keys whose real effect is on the client*),
[[run-nats-behind-a-proxy]] (*The client's keepalive is what the proxy timeouts must respect*),
[[evict-a-sick-server]] (*Why kicking the clients is a step at all*), [[slow-consumer-detected]] (*Why
`nats sub` will not show you a client-side drop*).

**The wiki bug this step existed to fix.** [[upgrade-a-cluster]] said "clients can stay silent for about
**four minutes** after a node dies", and [[s-adr-40-nats-connection]] said "~2 ping intervals". Both came
from ADR-40, which says it three times (L178, L224, L337: "if two consecutive PONGs are missed, connection
is marked as lost"). nats.go does `nc.pout++` and *then* `if nc.pout > nc.Opts.MaxPingsOut`
(`nats.go:5899–5921`), so it is the **third** interval; `learn/resilient-clients/reconnection.md:325` says
the same. **Run D3 settles it**: a `nats sub --trace` against a `SIGSTOP`ped 2.14.6 printed
`>>> Disconnected due to: nats: stale connection` at **exactly six minutes** after the connect. Both pages
now carry six, and the ADR's reading is docs issue #90 with `destination: ADR repo`.

**What the runs settled beyond the docs** (five runs, four passes; A/B/C/E on `tools/lab/cluster.sh`, D on
standalone servers): a **one-URL client has failover only because of gossip** — a publisher pinned to n1
finished on n2 it had never been told about (A2), which is exactly what `no_advertise` removes; the
**at-most-once reconnect gap measured at two rates** — 0 lost at 89 msg/s, **10 lost (43891–43900, one run,
≈ 0.39 ms)** at 25 800 msg/s (A3), narrow because nats.go sleeps only after a whole sweep; **lame duck**
sends the departing server's clients an `INFO` with `"ldm":true` and its own address **removed** from
`connect_urls` **about a second after the notice** — `lameDuckMode` transfers Raft leadership, waits a
second, shuts JetStream down and *then* calls `sendLDMToClients` (`server.go:4463–4529`) — while a client
on a *peer* gets the same shortened list with **no `ldm` key** (B3, B4), and clients are closed **10.0 s
after that INFO**, 11.0 s after the notice (B1, B3). The B3 bullet in the observed file first said "0.6 s
after the signal", read off the client's clock alone; it was re-checked against the source and corrected
in the same session, with the correction stated in the file and the transcripts left untouched. The same
source explains the second pass's instant shutdown: with **no clients** left the server calls `Shutdown()`
straight away (`server.go:4487–4494`); **a client that never sends a PING gets no
lame-duck INFO at all** and is simply closed, because `sendAsyncInfoToClients` skips anything without
`firstPongSent` (`route.go:1026–1028`; B5, found by a bug in the first raw client and kept); **`nats reply`
Ctrl-C** answered **4 of 8** in-flight requests and abandoned four, exit 1 (C4); the **server's** stale rule
is the same third-interval shape — `-ERR 'Stale Connection'` at t=12.19 s with `ping_interval: "5s"` and
`ping_max: 2`, and **nothing in the server log** (D1); the CLI's backoff prints 640 ms, 800 ms, **2.15 s**,
… and 2.15 s can only be `Duration(3)`, so **the table's first entry, 500 ms, is never used** (D3); a pull
consumer across a **consumer-leader move** lost **one fetch of 120** with `no responders` in 17 ms (E8),
and ten messages held `--no-ack` came back with **`tries: 2`** while `num_redelivered` still read 0 (E9).

**Docs issues** #90 (ADR-40's stale rule off by one ping — ADR repo, with the run), #91 (natscli's backoff
never reaches its own first step — `natscli`), #92 (`slow-consumers.md:100` "a connection with no async
error callback discards these reports" — nats.go installs `defaultErrHandler`, which writes them to
stderr), #93 (`connection-events.md:244` "the same authentication error twice" against
`tls-and-auth.md:206`'s "the same **server** … twice in a row" — the source keys on `nc.current`), #94
(nothing says a drain during an outage **closes** and drops the reconnect buffer), #95 (the CLI's
`--timeout` shown as a drain-timeout stand-in is "time to wait on responses"). No server issue: everything
surprising here was settled against the client source or the docs.

**Bank**: rows 175–179 added (`own`; the 484-thread comment cache was searched first for each — *lost on
reconnect*, *stale connection*, *ping* with *detect*, *drain* with *shutdown/SIGTERM/graceful/in-flight*,
*lame duck* with *client/reconnect/connect_urls*, *max reconnect*, *readiness probe* — and every hit was
the server's side of the question, so all five are posed) and answered on arrival — **147 / 179**, `own`
24. No strike from any *Pages touched*. `since: [2.10]` on both new pages with the *present at 2.10*
comment; `verified-against` names the authority each rests on (`nats.go v1.53.1, natscli 0.4.0,
nats-server 2.14.6` on [[client-defaults]], which is why it joins the staleness report's *authority the
tool cannot check* list, as [[nats-py]] already does). Lint: **385 pages** (377 → 385), drift 0, unlanded
**0**, wanted 0, unverified 12, staleness 0 behind 2.14.6. **Deferred to step 4** as the plan places them:
the `websocket` ripple (`wss://` is only named in `tls-and-auth.md`), the client-side slow consumer and the
expired-credential `-ERR` strings, both of which need a program rather than the CLI.

## 2026-09-04 — phase F step 4: resilient clients, part 2 — slow consumers, request-reply resilience, TLS and auth

Operation: plan, `inbox/plan-the-client-side-2026-09-03.md` step 4 (*Operation: ingest*, six summaries —
the plan's four plus one for each of the two new extracts, because both are cited directly by the gotcha
pages). **Sources into `raw/`**: `raw/nats-go-src/subscription-v1.53.1.md` (21 further verbatim ranges of
`nats.go` at v1.53.1 from the same cached file — the pending defaults and where they are applied,
`PendingLimits` / `SetPendingLimits` / `Pending` / `Dropped`, the overflow path, `NextMsg`'s validity
check, `processTransientError`, `processAuthError`, `checkAuthError`, `processErr`, `UserCredentials`,
`userFromFile`, `connectProto`, `Request`); `raw/nats-server-src/client-errors-v2.14.6.md` (a **generated**
table of all **58** client-protocol `-ERR` call sites at v2.14.6 plus 15 ranges — `ClosedState`'s 37
values, `errProto`, the `sendErr` family and the four credential paths, both server-side slow-consumer
branches with `markConnAsClosed`'s skip-flush rule, `setExpiration` and its zero-length timer, the
account's `expiredTimeout`, `handshake_first`'s parser and the startup warning's gate);
`raw/nats-server-src/client-faults-observed-v2.14.6.md` with `client-faults-runA.sh`, `-runA2.sh`,
`-runB.sh`, `-runB2.sh`, `-runC.sh`, `client-faults-deadsub.py` and four Go programs
(`client-faults-slowsub.go`, `-mintjwt.go`, `-rawcreds.go`, `-authclient.go`). Two `raw/sources.md` rows
extended.

**Summaries** (6): [[s-docs-resilient-clients-slow-consumers-and-request-reply]],
[[s-docs-resilient-clients-tls-and-auth]], [[s-docs-system-errors]], [[s-nats-go-subscription]],
[[s-nats-server-client-errors]], [[s-nats-server-client-faults-observed]]. **Pages** (2):
[[slow-consumer-in-the-client]] and [[connection-closed-after-auth-error]], the two gotchas the plan
names. **Ripples** (19 pages): [[client-defaults]] (pending limits, the per-client auth-abort table),
[[client-connection-lifecycle]] (the three faults that do not disconnect you, and where credentials enter
the handshake), [[slow-consumer-detected]] (the client-side comparison table, the two branches, and no
`-ERR` on either), [[tls-in-nats]] (the measured mismatch matrix), [[operator-mode]] (what expiry looks
like on the wire, and when), [[subject-permissions]] (a violation is transient, and per subscription),
[[request-reply]] (retry per outcome, idempotency, the in-flight request lost on a drop), [[nats-timeout]]
(there is no default request timeout), [[monitoring-endpoints]] (`/connz?state=closed` and the 37 reasons),
[[error-codes]] (the `-ERR` surface has no codes at all), [[advisories]] (a pointer to the sweep),
[[defaults-and-limits]] (the 75 % stall gate and the two cut thresholds), [[queue-groups]] and
[[worker-pool]] (why a bigger buffer is not the answer), [[nats-go]] and [[nats-cli]] (*what bites you*),
[[rotate-tls-certificates]] and [[set-up-operator-mode]] (the credential rotation that pairs with them),
and [[websocket]] — the `wss://` line deferred from step 3. Unlanded ripples went 42 → **0** in the pass.

**Runs** (five passes on standalone servers, all on 2.14.6; the CLI can neither set pending limits nor
mint a JWT with a chosen expiry, and no `nsc` was installed, so `client-faults-mintjwt.go` builds the
operator/account/user chain with `nats-io/jwt` v2.8.2 and `nkeys` v0.4.16 — the libraries the server
itself verifies against). **What they settled**: the client-side slow consumer is entirely client-side —
4,889 of 5,000 dropped with the subscription still valid, the connection **CONNECTED** throughout and
`/varz` `slow_consumers` still **0** (A1), which makes `slow-consumers.md:102`'s "the server raises a
SlowConsumer error back to that subscriber" wrong (docs issue #96); with **no** callback set nats.go wrote
**12 stderr lines**, and with one set it fired **13 times for 4,888 drops** and stderr stayed empty (A1,
A2) — the callback is per *transition* and the transition re-arms on the next message that fits;
`SetPendingLimits(0, …)` is `ErrInvalidArg` and a negative limit is unlimited (A3); a **sync** subscription
starts at **65,536**, not 500,000, because the limit comes from the channel's capacity (A4, docs issue
#101); the server's two branches produce **different log lines and different close reasons** —
`WriteDeadline of 100ms exceeded with 2 chunks of 4029 total bytes` → `Slow Consumer (Write Deadline)`
(A5) and `MaxPending of 1048576 Exceeded` → `Slow Consumer (Pending Bytes)` (A6) — and **neither sends the
client anything**: the cut subscriber drained **556,002 bytes and then read EOF** (A6). On the auth side,
the wire carries `-ERR 'User Authentication Expired'` at the JWT's second (B1) and
`-ERR 'Account Authentication Expired'` when the **account** JWT lapses (B5, docs issue #99); the `nats`
CLI printed **two lines in 45 s while the server rejected it eleven times** (B2); and nats.go closed after
**one** reconnect at `ReconnectWait 500ms` but **two** at its own default of 2 s (B3, B6) — because
`jwt/v2` checks `now > Expires` at one-second resolution, so a reconnect inside the expiry second is
accepted and expired at once by `setExpiration`'s zero-length timer, repeating the same error, while a
second later the answer becomes `Authorization Violation`. With `IgnoreAuthErrorAbort` the same credential
gave **46 rejected attempts in 45 s** (B4). On TLS, `--tlsfirst` against a plain server fails in **25 ms**
(a TLS record error, not a timeout), a plain client against `handshake_first: true` fails in **2.055 s**,
and against `"auto"` and `"300ms"` it **succeeds** in 0.093 s and 0.359 s — the fallback delay visible in
the connect time — with the startup warning printed only for the bare `true` (C1–C4, docs issue #98).

**Docs issues** #96 (the animation caption puts the local slow consumer on the server), #97 (no-responders
dated "for years" — it is 2.2.0, and it requires `headers` or the connection is closed), #98
(`handshake_first`'s `"auto"` and duration forms omitted from the client chapter, with the timings), #99
(account expiry unmentioned, and "each attempt" wrong for the first one), **#100 ★** — the **sweep** of
`reference/system/errors.md`: all 129 rows checked against the 58 `-ERR` call sites, the **70** identifier
rows and **37** close-reason rows accurate, **11 of 22** claimed wire errors not sent at all (eight absent
from the source, three log lines or monitoring reasons) — and #101 (the Go pending default is two numbers).
No server issue: everything surprising was settled against the server source or the client source.

**Bank**: rows 180–182 added (`own`, and answered on arrival) — the comment cache was searched first for
*slow consumer*, *messages dropped*, *pending limits*, *authentication expired*, *authorization
violation*, *auth error*, *creds* + *expire* and *IgnoreAuthErrorAbort*, and every "slow consumer" hit is
the **server's** version of the failure while the auth side has one incidental leafnode line. **150 / 182**,
`own` 27. No strike from any *Pages touched*. `since: [2.10]` on both new pages with the *present at 2.10*
comment; both carry `verified-against: nats-server 2.14.6, nats.go v1.53.1, nats CLI 0.4.0`, so they join
the staleness report's *authority the tool cannot check* list. [[slow-consumer-detected]]'s
`verified-against` moved from `2.14` to `2.14.6`, the tag its constants were read at. Lint: **393 pages**
(385 → 393), drift 0, unlanded **0**, wanted 0, unverified 12, staleness 0 behind 2.14.6.

## 2026-09-04 — phase F step 5: the wire protocol

*Operation: ingest* — step 5 of `inbox/plan-the-client-side-2026-09-03.md`. The last unread tree of the
docs (`reference/protocols/`, four pages, 1,303 lines), read against the server at v2.14.6 and then
provoked on the binary. Three summaries as planned, one new reference page, sixteen ripples, six docs
issues.

**Sources.** [[s-docs-protocol-client]] (`reference/protocols.md` folded in, plus `client.md`),
[[s-docs-protocols-internal]] (`route.md`, `gateway.md`, `leafnode.md` read as one, with a
three-at-a-glance table and the shared defects recorded once), and [[s-nats-server-wire-protocol]] —
the extract `raw/nats-server-src/wire-protocol-v2.14.6.md` (30 verbatim ranges from `server.go`,
`client.go`, `parser.go`, `route.go`, `gateway.go`, `leafnode.go`, `const.go`, `util.go`) plus
`raw/nats-server-src/wire-protocol-observed-v2.14.6.md`, runs A–G in seven passes with
`wire-protocol-raw.py` and nine scripts beside it.

**Page.** [[wire-protocol]] (`reference/`): the verb table by connection kind with the message forms
exactly; the 49 `INFO` fields split into common / route / gateway / leafnode, with the six a client is
sent that no doc row has; the 22 `CONNECT` fields with an *omitted means* column instead of the docs'
*Required* one; the `-ERR` inventory with the setting behind each string and whether the connection
survives; the strings the docs list that the server never sends; the five ways a connection dies
silently; PING/PONG per kind; the reserved prefixes; gateway interest; compression; the leafnode
delays; and a *Smoke-testing a port* section, because an `INFO` line identifies any listener before
auth.

**What the runs settled.** The standalone default `INFO` carries `api_lvl` and `xkey` (A1). **An `INFO`
line ends with a space before its CRLF** — `generateInfoJSON` joins three pieces with `" "`
(`util.go:360–364`) — except from a gateway, which formats `InfoProto` and does not (A1–A5). The
leafnode and route listeners advertise `proto: 3`, not the `1` their pages state (A3/A4).
**`CONNECT {}` gets a `+OK`**, because `defaultOpts` seeds `Verbose`, `Pedantic` and `Echo` to true
(B2/B13) — the docs' `Required` column has no counterpart, and a CONNECT with broken JSON gets **no
`-ERR` at all** (B9). Sixteen errors provoked: `Authentication Timeout` (not `Authorization Timeout`)
at 1003 ms with `timeout: 1` (C15); a TLS-required server sends **nothing** and drops at 2002.8 ms,
because `TLSHandshakeError` is the fifth member of `markConnAsClosed`'s skip-flush set, so
`Secure Connection - TLS Required` is unreachable at this release (C16); `-ERR 'Stale Connection'` at
**6139.9 ms** with `2s`/`2`, which is `(ping_max + 1) × ping_interval` and the server-side counterpart
of nats.go's six minutes from step 3 (C17); and **four `-ERR`s leave the connection usable** —
`Invalid Subject`, `Invalid Publish Subject`, the permission violations and
`maximum subscriptions exceeded` (C2/C3/C11/C19). The `-ERR` inventory is **60** sites, not the 58 of
step 4: `Stale Connection` is written with `enqueueProto` directly (`client.go:5867`, `:5908`), which
the new extract records as a correction to `client-errors-v2.14.6.md`.

On the server-to-server side, the `-DV` traces settled every verb form. `$LDS.` arrives as an ordinary
`LS+` — **there is no `LDS` verb** (E1b). The origin cluster is the **first** token, and of a *route's*
`LS+`/`LS-`, not a leafnode's: `LS+ LEAF1 $G edge.ping` on the route while the leaf's own frame is
`LS+ edge.ping` (E/F). A leaf's header messages are **`HMSG`** (`HMSG edge.work | W 18 31`), and
`LMSG` has an undocumented three-token reply form with no `+`. `RMSG` carries `|` and the queue names.
A gateway rewrites a reply to `_GR_.<6-char cluster hash>.<6-char server hash>.<original reply>` (G).
And **`gateway_iom: true`**: since 2.9.0 every account goes to interest-only at once
(`gateway.go:552–558`), so the optimistic mode `reference/protocols/gateway.md` still describes as
current is never entered between two modern servers — which also rules it out as an explanation on
[[supercluster-slows-when-a-remote-subscriber-joins]].

**Ripples (16).** [[gateway]] — *Interest-only is the default, and has been since 2.9.0*;
[[leafnode]] — *What a leafnode connection puts on the wire*, the four reconnect delays and the three
wrong CONNECT tags; [[client-connection-lifecycle]] — the server's side of the keepalive, timed;
[[client-defaults]] — *The server's own connection defaults*; [[core-nats-delivery]] — *What delivery
looks like on the wire*; [[defaults-and-limits]] — *The `-ERR` each connection limit produces*;
[[error-codes]] — *`-ERR` strings are not `err_code`s*; [[subject-permissions]] — the five exact
strings and the two `(sid …)` reload variants; [[tls-in-nats]] — why a plain client gets no error;
[[monitoring-endpoints]] — `client_id` ↔ `cid`; [[how-clients-reach-a-cluster]] — `connect_urls` and
`protocol: 1`; [[build-a-3-node-cluster]] — *Checking a route port without a client*;
[[system-subjects]] — the seven reserved prefixes; [[duplicate-messages-across-a-leafnode]] — loop
detection in one command; [[supercluster-slows-when-a-remote-subscriber-joins]] — *Not the
interest-mode switch*; [[nats-server]] and [[nats-server-2.10]]. The two step-4 gotchas each gained a
paragraph on the string that is documented and never sent. Unlanded **21 → 0**.

**Docs issues** #102–#107, one per protocol page plus two more for `client.md`, which carries three
separate tables. **#102 ★** is the `-ERR` table: three wrong defaults (auth timeout 1 s vs `2s`,
`max_control_line` 1024 vs 4096, slow consumer 10MB vs 64MB), six strings that are not what the server
sends (the casing rule is that `errors.New` text is lowercase and call-site literals are Title Case),
two that can never arrive, an incomplete `Recoverable` column and no ping values anywhere. **#105 ★**
is the leafnode page's four verb forms the parser does not have. #103 is the duplicated `client_id`
row, the six missing INFO fields and the undocumented trailing space; #104 the `Required` column and
`account` / `new_account` now being an error; #106 the retired optimistic mode; #107 the route CONNECT
table listing the two fields whose *absence* is the client/route discriminator. No server issue —
everything surprising was settled against the source.

**Bank**: rows 183–187 added (`own`, answered on arrival) — a `-ERR` and its setting, identifying a
listener with `nc`, reading the server-to-server verbs in a capture, what a `CONNECT` must carry, and
whether the gateway interest switch is something to size for. **155 / 187**, `own` 32. No strike from
any *Pages touched*. `since: [2.10]` on the new page with the *present at 2.10* comment.
Lint: **397 pages** (393 → 397), drift 0, unlanded **0**, unverified 12, staleness 0 behind 2.14.6.
Wanted is **1**: `services-on-core-nats`, registered deliberately in `wiki/index.md` because
[[wire-protocol]]'s `$SRV.` prefix row points at it and step 6 writes it.

## 2026-09-04 — phase F step 6: the services framework

*Operation: ingest*, step 6 of `inbox/plan-the-client-side-2026-09-03.md`. The last unread docs
chapter, and the one whose subject tree an operator has to secure and monitor without any server
feature to hang it on.

**The frame.** `$SRV` appears nowhere in `nats-server`'s source. There is no registry, no discovery
handler and no reserved prefix; a "service" is a convention in the client libraries, specified by
ADR-32 and implemented per language. Everything an operator can see, permit or scrape is therefore an
ordinary subject, which is what the two new pages are about.

**Cache first**: the three `io.nats.micro.v1.*_response` JSON schemas from `nats-io/jsm.go` v0.4.1
into `raw/jsm-go/`, beside the two JetStream configuration schemas already there. They are the only
public place the `endpoints[]` item fields can be read — the docs' renderer collapsed them (#108).

**Six passes on 2.14.6** (`raw/nats-server-src/services-observed-v2.14.6.md`, eight scripts, a
six-endpoint nats.go v1.53.1 service, the step-5 raw client and a subscription dumper, all copied in
beside it). What they settled:

- **Ten subscriptions per instance** — three verbs × three levels, all *plain*, plus one queue
  subscription per endpoint. That is why discovery is a broadcast and work is not.
- **The `$SRV` bodies**: `ping_response` is five fields and nothing else; `stats_response` carries
  `started` in UTC, integer-nanosecond `processing_time`, `last_error` as `""` when there has been
  none, and the `StatsHandler`'s `data`. `last_error` is formatted `"<code>:<description>"`.
- **A service error and a 503 side by side on the wire** — `HMSG … 92 109` with two headers and a
  body against `HMSG … 55 55` with `NATS/1.0 503`, `Nats-Subject:` and nothing. Both are delivered
  replies; only the headers tell them apart.
- **★ A blocked endpoint does not block its siblings** (`check` in 327 µs while `slow` was 3 s into a
  block), because nats.go gives each endpoint its own `QueueSubscribe` and dispatcher.
- **★ A blocked instance keeps its share.** Two instances, 3 s handlers, eight simultaneous requests:
  all delivered at once, split 3 / 5 at random, worked through serially, **four of eight callers
  timed out** while replies arrived at 20.09 s, 23.09 s and 26.09 s into dead inboxes. This is the
  sizing fact of the whole ingest.
- **`Stop()` removes all fifteen subscriptions at once and returns in 1.3 ms**, leaving the in-flight
  handler to finish — it replied at 5.001 s because the process stayed alive. `kill -9` in the same
  place loses the work and the caller sees only a timeout, never no-responders.
- **The server does not reserve `$SRV`**: `nats pub '$SRV.PING' hello` → `Published 5 bytes`, and a
  plain subscriber on `$SRV.>` saw another caller's discovery request with its inbox. Permissions are
  the only isolation, and discovery and invocation separate cleanly — with the refusal invisible to
  the client and visible only as `Publish Violation` in the server log.
- **★ `$SRV` and endpoint subjects cross a leafnode with no configuration**, but the queue group keeps
  to the local member: 8 of 8 from the hub to the hub instance, 8 of 8 from the leaf to the leaf
  instance, while discovery listed both from either side. An instance at the edge serves the edge and
  adds nothing to the hub.
- Also: `nats service info` shows one instance when several run; `nats service serve` never calls
  `Stop()`; an endpoint subject is an ordinary subscription, so a publish with no reply still runs the
  handler; and nats.go's `APIPrefix` is a `const`, so ADR-32's overridable prefix does not exist.

**Six summaries**, not five: `s-adr-32-service-api`, `s-docs-services-framework`,
`s-docs-services-discovery-and-stats`, `s-docs-services-scaling`, `s-nats-server-services-observed`,
plus `s-gh-4984-micro-with-jetstream` — the (b) scout of the comment cache found only two `micro` hits
in 484 threads, and that one is the public statement of where the pattern stops, so it was fetched
whole into `raw/gh-discussions/` and summarised rather than merely cited.

**Two pages.** `concepts/services-framework` — the subjects, the verbs, the counters and their units,
the two error headers against the 503, the queue-group rules, what `Stop()` drains, permissions, and
the leafnode result. `operations/services-on-core-nats` (`kind: pattern`, **row 134**) — the design
decisions: sizing the caller's timeout from the queue rather than the handler, no-responders as the
deploy check, scatter-gather only outside a queue group, permissions per role, drain-then-wait, and
five conditions under which the pattern is the wrong one.

**Twelve ripples**, unlanded 33 → 0: [[queue-groups]] — *The services framework's queue groups*;
[[request-reply]] — *A service error is a third outcome*; [[system-subjects]] — *`$SRV` — the one
reserved prefix the server does not own* (and its `$SRV.` row, which said "(step 6)", now points at
the page); [[nats-timeout]] — *A fourth outcome when the responder is a service*; [[worker-pool]] —
*The core-NATS sibling, and where the line falls*; [[leafnode]] — *Where that leaves a service at the
edge*; [[subject-permissions]] — *`$SRV.>` is an ordinary permission*; [[nats-cli]] — the six
`nats service` subcommands and the three that bite; [[nats-go]] — *What bites you — the `micro`
package*; [[advisories]] and [[metrics]] — the two "service" mechanisms separated; [[core-nats-delivery]]
— the at-most-once boundary asked in public; [[monitoring-endpoints]] — what an instance adds to
`/subsz`; [[client-connection-lifecycle]] — draining a service is two steps; [[slow-consumer-in-the-client]]
— a blocked handler is the same shape, but the callers give up first.

**Docs issues #108–#117**, ten from one chapter, two of them ★. **#113 ★** is the `$SRV` reservation:
two pages say the server reserves the prefix, the server reserves nothing, and an operator who
believes them never writes the one permission that protects it. **#114 ★** is
`scaling.md:272`, wrong in both directions at once — too pessimistic within an instance, far too
optimistic across them; it shares its second half with **#86**, whose detail section gained the harder
eight-request run. The rest: #108 the collapsed schema objects, #109 nine hand-offs to a configuration
reference that was never written, #110 a cross-reference to an option the target page never names,
#111 three chapters promised `$SRV` coverage that contain none, #112 the reference overview's six
invented capabilities and its backwards account of discovery, #115 "in-flight work is gone" against
"`Stop()` drains" on the same chapter, #116 ADR-32's overridable prefix (destination **ADR repo**),
#117 a typo whose home is the jsm.go schema, not the docs page (destination **jsm.go**). No server
issue: everything surprising was settled against the source or the run.

**Bank**: row **134** filled — the last of the three the phase promised that step 6 owed — and rows
**188–193** added and answered (what an instance puts on the server, the blocked-instance timeout
question, telling the three reply outcomes apart, who may see `$SRV`, services across a leafnode, and
gh#4984's acking handler). **162 / 193**, `own` 37. `inbox/adr-toc.md`: row 32 links its summary and
row **3** gets a recorded decision (*skip for now* — service latency is a server export feature this
wiki already covers from the source). Docs coverage: `learn/services` **6/6** and
`reference/services` **3/3**, both now read end to end.

Lint: **405 pages** (397 → 405), drift 0, unlanded **0**, unverified 12, staleness 0 behind 2.14.6.
Wanted is **1** again and deliberately: [[core-or-jetstream]], which step 7 writes for row 133 —
`core-nats-delivery` and `services-on-core-nats` both stop at the durability boundary and hand the
decision to it.

## 2026-09-04 — phase F step 7: `core-or-jetstream`, the durability decision per subject

*Operation: plan* — step 7 of nine of `inbox/plan-the-client-side-2026-09-03.md`, which closes
megaplan group **G7** and writes the wiki's last registered wanted page.

**Scout first.** `inbox/scout-core-or-jetstream-2026-09-04.md`, ten candidates. The comment cache
(`local/scratch/gh-index/threads-2026-09-03.md`, all 484 threads with every comment and reply) was
searched again with different terms — `core (nats )?(vs|or) jetstream`, `when (to|should i) use
jetstream`, `do i need jetstream`, `without jetstream`, and every thread whose comments contain
"core NATS" — plus the Stack Exchange API, `natsbyexample.com`'s index (11 categories, no comparison
example) and the docs tree. The 5(a) sweep's verdict stands: **row 133 is asked in halves, never
whole**, so it keeps `own`. The halves that are public became rows of their own.

**Seven summaries, not the planned four**, and the reason is that the scout found no thread to build
on: `s-docs-concepts-jetstream` (the primer's statement of the boundary — "JetStream extends that
decoupling to time"), `s-docs-core-nats-chapter` (the docs' clearest form of the rule, with examples:
at-most-once is right "when each message is superseded by the next one, such as a live price, a
current temperature, or a cache invalidation"), `s-docs-jetstream-where-next` (the same rule from the
JetStream side, plus the two acks), `s-gh-2961-js-and-core-one-cluster` (the only public maintainer
statement on the mixed deployment), `s-adr-22-publish-retries` (the ADR that says a JetStream publish
*is* a core request), `s-nats-server-core-or-jetstream-observed` (the runs), and
`s-gh-3507-no-external-store` — the last one a **repair**: the scout said "cite, do not re-ingest",
but bank row 143 was marked answered by `stream` and `nats-streaming` and **neither page stated the
fact**, so citing it would have been citing nothing.

**One page.** `operations/core-or-jetstream` (`kind: pattern`, **row 133**): a nine-row decision table
taken per subject; what actually differs on the wire; the cost as four measured ratios; the mixed
design (one cluster, one subject tree, an unchanged publisher); the configuration; the trade-offs; when
not to; and *The two ways to get it wrong*.

**Runs A–H in eight passes** (`raw/nats-server-src/core-or-jetstream-observed-v2.14.6.md`, nine
scripts, the step-3 raw client unchanged; run G on `tools/lab/cluster.sh up 3`). **What they settled:**

- **A JetStream publish is a core publish with a reply subject** — `MSG orders.created 1 4` against
  `MSG orders.created 1 _INBOX.… 4`, same verb, same payload — and once stored the two messages are
  *indistinguishable*: `stream get --json` shows no header and no marker on either.
- **The cost, as ratios on one laptop**: core 2,882,347 msgs/s · JetStream synchronous **30,876**
  (~93×) · asynchronous 366,110 (~7.9×) · asynchronous into a memory stream 591,419 · and a core
  publish into a subject a stream *does* capture, **2,885,763 — unslowed**, because it waits for
  nothing and is told nothing.
- **The core publisher loses nothing**: 100,000 publishes at 2.7 M msgs/s into a file stream stored
  100,000, `slow_consumers 0`, no log line.
- **A stream laid over a request/reply subject answers the requests itself.** With a responder on
  `svc.echo`, adding a stream on `svc.>` made `nats request` return `{"stream":"SVC","seq":1}` at
  277 µs while the responder's `pong` came second at 451 µs; on the wire, two indistinguishable `MSG`
  frames on one inbox, and the stream stored every request. The server refuses exactly three shapes of
  this — `>`, `$JS.>`/`$JSC.>`/`$NRG.>`, `$SYS.>`, each only by demanding `no_ack`
  (`server/stream.go:2170–2196`) — and allows every ordinary subject silently.
- **The documentation's own example does this to itself** (run H, both chapters' commands verbatim):
  after `nats stream add ORDERS --subjects "orders.>" --defaults`, the core chapter's inventory service
  on `orders.inventory.check` answers `{"stream":"ORDERS","seq":1}` instead of `in stock: 42`, and
  `nats stream subjects ORDERS` shows the stream recording the requests.
- **A `>` stream needs `no_ack` *and* R1**, and the one the server accepts swallowed twelve subjects
  and 41 messages from six commands — every `_INBOX.…`, `$SRV.PING.DEMO`, and
  `$JS.API.STREAM.INFO.<itself>`, which went from 3 to 6 between two `nats stream subjects` calls:
  reading it writes to it. A JetStream publish into it can never succeed (`nats: timeout` at the full
  deadline).
- **A stream-leader step-down costs an R3 JetStream publisher exactly one publish** — one 503 in 312,
  32 ms after the command — while the core publisher beside it saw nothing and a **meta**-leader
  step-down cost nothing at all. ADR-22's motivation, measured.
- **`nats pub -J` never retries.** natscli v0.4.0 `cli/pub_command.go:279` is a plain
  `nc.RequestMsg`, so ADR-22's back-off is skipped and the error is `no responders available for
  request`, not `no response from stream`; and `:277` prints `Published …` *before* the request is
  sent. ADR-22's own defaults do hold in nats.go v1.53.1, in both APIs
  (`raw/nats-go-src/jetstream-publish-v1.53.1.md`, new).

**Fifteen ripples**, unlanded 25 → 0: [[core-nats-delivery]] — *Where this guarantee ends*;
[[publishing]] — *Why a publish can 503, and what to do about each cause*; [[stream]] — *Choosing the
subject list* and *Two storage backends, and there is no third*; [[consumer]] — *Why a consumer,
rather than several subscribers*; [[ack-and-redelivery]] — *The two acks, in the docs' own words*;
[[request-reply]] — *A fourth outcome*; [[nats-timeout]] — the two causes of a publish-time 503;
[[nats-cli]] — *`nats pub -J` is a diagnostic, not a resilient publisher*; [[nats-go]] — *The publish
retry, at v1.53.1*; [[jetstream-sizing]] — what enabling JetStream costs a mixed cluster;
[[stream-and-consumer-config]] — *The three rules behind `no_ack`*; [[services-on-core-nats]] — *Keep a
stream off the service's subjects*; [[worker-pool]] — *Why the stream goes behind the endpoint*;
[[subjects-and-wildcards]] — subject design comes first; [[choosing-a-topology]] — core and JetStream
are not two topologies; [[nats-streaming]] — the migration loses the pluggable store.

**Docs issues #118–#120**, one of them ★. **#119 ★**: nothing in the tree warns that a stream
capturing a request/reply subject answers those requests, and the docs' own continuous Acme example
walks into it — run H is the two chapters executed in the order they are taught, and the inventory
service stops working. #118: the rule the JetStream chapter turns on is a checklist bullet filed under
a Pitfalls section that does not contain it, and `supersede` occurs **twice in 861 pages**. #120: the
stream field `no_ack` appears **nowhere** in the docs tree, though three server-side subject rules
exist only to force it on. No server issue — every surprise was settled against the source or the run.

**Bank**: row **133** filled (`own` kept: searched twice, in two different ways, and the design
question is not asked in public), rows **194–197** added and answered, and row **143** re-pointed at
pages that now state its answer. **167 / 197**, `own` 39. `inbox/adr-toc.md` row 22 links its summary.

Lint: **413 pages** (405 → 413), drift 0, unlanded **0**, wanted **0**, unverified 12, staleness 0
behind 2.14.6.

## 2026-09-04 — phase F step 8: *What bites you* on the twelve client entities

*Operation: consolidate* over the entity layer, with the one thing the entity layer had never been
given: a **dated** source per client. Every per-client sentence in `learn/resilient-clients` is
unversioned by design, and the READMEs already in `raw/github-repos/` say what a client *does*, not
what it *did*. So the step began by fetching, for each of the twelve official clients, the last ten
release bodies and every open issue — 12 files under `raw/github-repos/nats-io__<repo>.releases-2026-09-04.md`,
release bodies verbatim, issues as number, open date and title (`gh api …/releases?per_page=10` and
`gh api …/issues?state=open --paginate`; the search API rate-limits at 30/min and was abandoned for
the core issues endpoint after the first pass). Then two source reads the release record could not
substitute for.

**Three summaries.** [[s-client-releases-and-issues]] — the twelve clients' release record read as
one source, which is what dates the chapter's claims. [[s-nats-pure-rb-client-source]] — seven quoted
ranges of `lib/nats/io/client.rb` at tag **v2.5.0**, read because **no `learn/` page names Ruby at
all** and the ten release bodies state no default: the preferred Ruby client's behaviour under a fault
was, until now, publicly undocumented. [[s-nats-server-tcp-nodelay]] and
[[s-nats-server-connect-urls-gossip]] are two greps of the server tree that close two bank rows
(below), each recorded in `raw/nats-server-src/` as a source reading, explicitly not a run.

**Twelve `## What bites you` sections**, one per client entity — ten new, two second passes
([[nats-go]], [[nats-net]]) for what steps 1–7 produced. Each bullet is an operator-visible behaviour
with the release that introduced it or the open issue that reports it. What the reading turned up:

- **Subject validation is a version question, not a language one.** It arrived separately in every
  client and recently: nats.js **v3.3.0** (2025-12-16), nats.go **v1.48.0** (2025-12-17), nats.java
  **2.25.1** (2026-01-15), nats.rs **v0.47.0** (2026-03-31); nats.net deprecated its
  `SkipSubjectValidation` opt-out at **v3.0.0**, giving the mechanism better than the docs do — "a
  subject containing a space splits into subject and reply-to tokens on the wire with no error",
  which is exactly run A2 of step 1. **nats.c and nats.py add none in their last ten releases.** The
  table is now on [[client-defaults]].
- **The Python maintainers publish a message-loss figure for their own client**: "\* nats-py dropped
  47-87% of messages under load", footnoting the `nats-core/v0.1.0` benchmark, against "Zero message
  loss with nats-core across all configurations".
- **Ruby diverges from every documented client in two ways**: a publish **blocks** when the outbound
  `SizedQueue` fills instead of failing, and the stale check is `>=` rather than `>`, so a dead link
  is caught on the **second** unanswered ping — about four minutes against Go's six. That settles
  docs issue **#90** as a real cross-client divergence: **nats-pure.rb implements ADR-40's rule as
  written and nats.go does not.**
- **`nats.swift` ships JetStream** — its v0.4.0 notes and `Sources/JetStream/` both say so — while its
  README has said "on the roadmap" for 22 months. The wiki page had carried the README's claim; the
  Facts table and the intro are corrected.

**Two bank rows closed from the server source.** Row **148** (`TCP_NODELAY`): the server never calls
`SetNoDelay` anywhere at v2.14.6 and has no key for it, because Go's `net.newTCPConn` calls
`setNoDelay(fd, true)` on every TCP connection it makes — Nagle is off on every connection kind and
cannot be turned on. Row **156** (supercluster discovery): the two connect-URL helpers in `server.go`
have exactly **three call sites, all in `route.go`** (`:2389`, `:728`, `:3205`), all gated on
`!opts.Cluster.NoAdvertise`; `gateway.go` and `leafnode.go` call neither, so a client never learns
another cluster exists. Row **87** re-checked against the READMEs and left as it stood, with the
answer sharpened: seven Orbit repos, versioned per module, and three (`orbit.py`, `orbit.net`,
`orbit.c`) with no published release.

**Ripples beyond the twelve entities** (7): [[client-defaults]] — *Three C# cells are out of date, and
the client says so*, *Ruby — read from the client, because the documentation never names it*,
*Publish subject validation, per client and per version*, and two new rows in *The auth-error abort*;
[[subjects-and-wildcards]] — the per-client arrival dates replacing "until the client pages are read";
[[client-connection-lifecycle]] — the Ruby keepalive beside the ADR-40 paragraph, and discovery
stopping at the gateway; [[defaults-and-limits]] — *The socket options the server never sets*;
[[wire-protocol]] — *The one socket option, which the server does not set*; [[gateway]] — *A client
never learns another cluster exists*; [[how-clients-reach-a-cluster]] — *Discovery stops at the
cluster edge*.

**Docs issues #121–#122.** #121: `learn/resilient-clients` states two .NET defaults that nats.net
**v3.0.0** changed on 2026-07-10, seven weeks before the docs tree was fetched — the 1,024-message
channel is 16,384 with `DropNewest`, and "C# is the exception: it has no drain call on a single
subscription" is answered by `INatsSub<T>.DrainAsync()`. Both were true of the v2 line, and the
chapter carries no version anywhere, which is the finding. #122: the `nats.swift` README contradicts
its own release notes and its own source tree about JetStream, and docs.nats.io delegates capability
to that README — a new `destination` value, the client repository itself. No server issue: every
surprise here is a client's, and a client has a maintainer to ask.

**Bank**: rows **148** and **156** filled, **87** re-checked. **169 / 197**, `own` 39.

Lint: **417 pages** (413 → 417), drift 0, unlanded **0**, wanted **0**, unverified 12, staleness 0
behind 2.14.6.

## 2026-09-04 — phase F step 9: close — the client side, measured

**Operation: plan**, step 9 of `inbox/plan-the-client-side-2026-09-03.md`, and the close of megaplan
phase F. No new source, no new page: the step is the measurement of the phase's *done when*, the two
`concepts/` primers still unfolded, and the bookkeeping.

**The two primers, read and folded.** `concepts/security.md` (116 lines) and `concepts/topologies.md`
(117 lines) were the last two of the eleven `concepts/` pages. Both are the deep dives' shorter form
and **neither carries a surplus sentence**: security's three pillars are on [[subject-permissions]]
(its L48 "an allow list closes off the rest" and "deny takes precedence over allow" are already rules
1 and 2 there), [[tls-in-nats]] (L59 `verify_and_map` mapping the certificate's SAN or DN, L63
encryption at rest with AES or ChaCha20-Poly1305), [[operator-mode]] (L21's operator → account → user
chain) and [[auth-callout]] (L22); topologies' five shapes are on [[choosing-a-topology]], [[build-a-3-node-cluster]],
[[gateway]] (L46's geo-affinity, which the page states precisely — and which docs issue **#88** records
as false *inside one cluster*, where this page does not claim it) and [[leafnode]] (L109's "the cluster
sees one leaf connection", already at `leafnode.md:407` as a client connect event on the bound
account). Nothing carried, nothing added to a page; recorded here so the fold is traceable rather than
implied.

**Docs coverage, the seven trees this phase owed** — the *done when* clause, now measurable:

| tree | files | read | how |
|---|---|---|---|
| `learn/core-nats` | 11 + index | **11/11** | steps 1–2, four summaries |
| `learn/resilient-clients` | 8 + index | **8/8** | steps 3–4, five summaries |
| `learn/services` | 6 + index | **6/6** | step 6, three summaries + ADR-32 |
| `reference/protocols` | 4 + index | **4/4** | step 5, two summaries |
| `reference/services` | 3 + index | **3/3** | step 6, folded into [[s-docs-services-discovery-and-stats]] |
| `concepts` | 11 | **11/11** | nine folded (`subjects`, `pub-sub-basics`, `what-is-nats`, `intro` in step 1; `request-reply`, `queue-groups` in step 2; `jetstream` as [[s-docs-concepts-jetstream]] in step 7; `security`, `topologies` here), two prior ([[s-docs-ecosystem]], [[s-docs-getting-started]]) |
| `reference/config/mappings` | 3 + index | **4/4** | step 1, folded into [[s-docs-core-nats-subjects-and-mapping]] |

**The phase's twelve pages**, each in `wiki/index.md`, each carrying `since:` and a `verified-against`
naming the authority it rests on (nats-server 2.14.6, nats.go v1.53.1, natscli 0.4.0, ADR-32 rev 6):
concepts [[core-nats-delivery]], [[subjects-and-wildcards]], [[request-reply]], [[queue-groups]],
[[client-connection-lifecycle]], [[services-framework]]; reference [[client-defaults]],
[[wire-protocol]]; gotchas [[slow-consumer-in-the-client]], [[connection-closed-after-auth-error]];
patterns [[services-on-core-nats]] (row 134) and [[core-or-jetstream]] (row 133, which closes megaplan
G7). All twelve client entities carry `## What bites you`; [[nats-go]] carries five such sections,
[[nats-java]] and [[nats-net]] two.

**Before and after** — phase F, 2026-09-03 → 2026-09-04, eight working steps:

| measure | before (phase E close) | after |
|---|---|---|
| pages | 345 | **417** |
| — of which summaries | 228 | **287** (+59: **51** from this phase's eight steps, 8 from the 2026-09-03 interlude ingest that also added [[service-import-request-info]], #79–#80 and SI-6) |
| — reader pages added | — | **13** (12 this phase, 1 the interlude) |
| question-bank rows · answered | 165 · 131 | **197 · 169** |
| open rows · open `own` | 34 · 13 | **28 · 3** |
| wanted pages | 0 | **0** (two registered and closed on the way: `services-on-core-nats`, `core-or-jetstream`) |
| `(unverified)` markers | 11 | **12** (the one added in step 1 sits under a `## To verify`) |
| citation drift · unlanded ripples | 0 · 0 | **0 · 0** |
| staleness behind 2.14.6 | 0 | **0** |
| docs issues | 78 | **122** (#79–#80 from the 2026-09-03 interlude ingest, **#81–#122** from this phase — six ★) |
| server issues | 5 | **8** (SI-6 interlude, SI-7 step 1, SI-8 step 2) |

`check-staleness.py` reports 0 behind and **15 authority unknown** — the client authorities (nats.go
v1.53.1, natscli 0.4.0, ADR-32 rev 6) are outside the six versioned things the script tracks, so a
page pinned to a client release is invisible to it by design, not overdue. Every one of those pins is
re-checked by hand when the pin moves.

**What the phase settled that no page had before.** Core NATS had no owner page at all: at-most-once
and its ordering rule (per publisher connection, across every subject), the 503 and its `Nats-Subject`
header, queue-group selection (random over the members, not readiness-aware), the reconnect buffer and
what the gap costs, the `-ERR` inventory as **60** call sites with which strings leave a connection
usable, the services framework as a pure client convention over ten subscriptions per instance, and the
durability boundary — including that **a stream laid over a request/reply subject answers the requests
itself**, which the docs' own Acme example walks into (#119 ★). Forty-two docs issues came out of it,
and every behavioural claim on the twelve pages was run on the 2.14.6 binary and recorded in
`raw/nats-server-src/*-observed-v2.14.6.md` with its scripts beside it.

**Bank**: no cell earned by this step — it creates no page. 169 / 197 stands.

Lint: **417 pages**, drift 0, unlanded **0**, wanted **0**, unverified 12, staleness 0 behind 2.14.6.
**Phase F is done.** Next: megaplan phase G, starting with G1 (stream and subject design), whose
foundation is [[subjects-and-wildcards]] from step 1.
