# Plan — stream and subject design (proposed 2026-09-04)

Say **`start the plan inbox/plan-stream-and-subject-design-2026-09-04.md`** to work this file — name
it explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-04, commit `1720c02`).** 417 pages; question bank 197 rows, **169
answered**, 28 open (20 `design`, 10 `sizing`, overlapping; 3 open `own`); wanted **0**;
`(unverified)` 12 on 9 pages (one under a `## To verify`); citation drift 0, unlanded ripples 0;
staleness 0 behind nats-server 2.14.6; docs issues **122** (none filed), server issues **8**. Binary
`nats-server v2.14.6`, `nats` CLI 0.4.0. The server source at v2.14.6 is in
`local/scratch/src/v2.14.6/` and `.cache/nats-server-2.14.6/`; the 484-thread comment cache is in
`local/scratch/gh-index/`; `tools/lab/cluster.sh up 3` brings up the R3 lab in one command.

**Why this plan.** Phase **G1** of the maintainer's programme (`local/megaplan.md`): the first group of
the twenty open `design` rows. These are the questions a solution architect holds *before* anything is
running — how many streams, what the subjects look like, which retention, how a second copy is made —
and the wiki currently answers none of them. It has the parts (every concept page they turn on is
written, most of the sources are already ingested) and no page that puts the parts in the order a
decision needs them. Phase F left exactly the foundation this group stands on:
[[subjects-and-wildcards]] (no length or token limit exists in the server; `max_control_line` bounds
the line; `max_subscription_tokens` is the one optional cap — docs issues #81, #82) and
[[core-or-jetstream]] (the durability decision per subject, and **#119 ★**: a stream laid over a
request/reply subject answers the requests itself — a subject-design rule, not a curiosity).

## The rows

| # | question | asked at | flags |
|---:|---|---|---|
| 108 | One stream per tenant or service, or one stream with a tenant prefix in the subject — which, and at what count does "many streams" start to cost you (meta layer, account limits, consumers)? | [gh#6100](https://github.com/nats-io/nats-server/discussions/6100) ★ answered (@Jarema) | design pattern sizing |
| 109 | How should I design a subject hierarchy for JetStream — token order, where the wildcards go, and what subject cardinality costs the filestore and filtered consumers? | [gh#4170](https://github.com/nats-io/nats-server/discussions/4170) answered (@derekcollison) | design pattern |
| 110 | Limits, Interest or WorkQueue — how do I choose retention for a task queue, an event log and a cache, and what breaks when I choose wrong? | [gh#4499](https://github.com/nats-io/nats-server/discussions/4499) answered (@ripienaar) | design concept |
| 111 | Filtered consumers on one large stream, or many small streams — which scales better for fan-out to N services, and where do `max_consumers` and per-consumer state bite? | [gh#3405](https://github.com/nats-io/nats-server/discussions/3405) ★ answered (@derekcollison) | design pattern sizing |
| 114 | Mirror, source, or a filtered consumer on the original stream — which replication shape for read replicas, fan-in and cross-region copies, and what does each cost? | [gh#6571](https://github.com/nats-io/nats-server/discussions/6571) answered (@jnmoyne) | design pattern |
| 144 | Is JetStream suitable as an event store — millions of events, one subject per aggregate, optimistic concurrency on publish, and tiering to cold storage? | [gh#3772](https://github.com/nats-io/nats-server/discussions/3772) ★ answered (@bruth), 10 upvotes | design pattern |

All six have a **chosen answer from a maintainer**, three are ★ in `inbox/gh-discussions-toc.md`, and
none of the six threads is in `raw/gh-discussions/` yet. Rows 108–111, 114 got their URLs from phase C's
scout (`inbox/scout-posed-rows-public-form-2026-09-03.md`); row 144 came from phase C's ★ sweep.

## Pages this plan writes

| page | type | rows | why it is its own page |
|---|---|---|---|
| `subject-design` | `kind: pattern` | 109 | The subject tree is designed once and everything else is laid over it. [[subjects-and-wildcards]] states the **rules**; this states the **choices** — token order, where the wildcard goes, cardinality, and the subjects you must not hand to a stream. |
| `stream-topology-design` | `kind: pattern` | 108, 111, 114 | One question asked three ways: how many streams, how many consumers on each, and how a second copy is made. Splitting it would put the trade-off on one page and the cost on another. |
| a `## Choosing retention` section on [[retention-policies]] | concept | 110 | The concept page already carries every rule and every failure mode; what it lacks is the *decision*. A separate page would duplicate it. |
| `event-sourcing-on-jetstream` | `kind: pattern` | 144, 198 | **Decided in step 2: its own page.** gh#3772 alone carries a subject-per-aggregate design, two OCC granularities (three headers, since 2.11.0), a filtered-replay cost model, a Raft-asset ceiling and a named dead end — no tiered storage, asked again in gh#3871 and still "planned" three and a half years on. That is more than a section of `stream-topology-design` can hold. |

## What is already in place — do not re-ingest

- **Concepts**: [[subjects-and-wildcards]] (F1), [[stream]] (with *Choosing the subject list: what a
  stream quietly takes over* and *There is no cap on messages, and no known-good `max_msgs`*),
  [[retention-policies]] (with *A limits stream with no limits: the event-store shape*),
  [[mirrors-and-sources]], [[subject-transforms]], [[publishing]] (the dedup window,
  `Nats-Expected-*`), [[consumer]], [[core-or-jetstream]] (F7).
- **Sizing and cost**: [[jetstream-sizing]], [[filestore-layout]] (`index.db` at `len(subject) + 4`
  per subject; the 30-byte record overhead), [[jetstream-slows-as-consumers-grow]] (~100k consumers,
  ~300 filters, the HA-asset unit), [[stream-placement]], [[meta-layer]], [[metrics]] (`ha_assets`).
- **Summaries already ingested that these pages must draw on**: `s-synadia-jetstream-anti-patterns`
  (the *Design Patterns for Scale* post), `s-synadia-how-many-subjects`, `s-gh-8333-high-cardinality-subjects`,
  `s-gh-5202-max-unique-subjects`, `s-gh-5097-subject-token-limit`, `s-gh-3944-subjects-in-a-stream`,
  `s-gh-5128-ha-assets`, `s-docs-core-nats-subjects-and-mapping`,
  `s-docs-subject-mapping`, `s-docs-filtering`, `s-docs-retention-policies`, `s-docs-policies`.
  The scout's job is to find what is **missing**, not to re-list these.
- **Raw sources on disk, unsummarised or partly used**: `raw/synadia-insights/nats-subject-count-threshold.txt`,
  `raw/synadia-insights/nats-stream-message-limit.txt`, `raw/synadia-blog/jetstream-design-patterns-for-scale.txt`.
- **Cache**: `local/scratch/gh/gh-3772.{json,md}` (fetched 2026-09-02; **must be fetched whole into
  `raw/gh-discussions/` before anything cites it**), `local/scratch/gh-index/` (484 threads with
  comments, for the §5(b) page scouts).

---

## Steps

### 1 · Scout G1, and put gh#3772 in `raw/`
status: done 2026-09-04 — `inbox/scout-stream-and-subject-design-2026-09-04.md`, 17 candidates in four groups plus a *seen and not in G1* table for later phases. The six threads are in `raw/gh-discussions/` (`gh-6100`, `gh-4170`, `gh-4499`, `gh-3405`, `gh-6571`, `gh-3772`) with their `raw/sources.md` entry; `local/scratch/gh/gh-3772` is retired. New ground: **`synadia.com/blog` read end to end (111 posts)** — eight posts for G1 and one per later G-group — and **natsbyexample.com**, the first source from that site here. Two findings for the pages to carry: the **16-token limit three sources state and the server does not have** (with 256 characters, a 32-token stack array and a 100,000-entry cap to verify at v2.14.6), and the **one-stream / one-stream-per-tenant disagreement** between gh#6100's chosen answer and Synadia's per-tenant FIFO post, which nobody has measured. Recommended ingest: **G1, G3, G4, G5, G6, G7, S1, S7** (eight). No `own` to replace — all six rows already carry a URL.

*Operation: scout*, run for this group rather than for all twenty rows (backlog §5(b): "page by page,
not all at once" — G1 is two pages, one section and one decision). Write
`inbox/scout-stream-and-subject-design-2026-09-04.md` with candidates **grouped by the page they would
serve**, each with URL, one line, a relevance flag, the rows it answers and the pages it touches.

Where to look, in this order:
1. The six threads above — fetch each whole with `python3 tools/fetch-discussion.py <n> --out raw/gh-discussions`
   (gh#3772 first, from the cache or refetched; add the `raw/sources.md` rows).
2. `local/scratch/gh-index/threads-2026-09-03.md` — grep the 484 threads' comments for the terms these
   pages turn on: `stream per`, `many streams`, `tenant`, `subject hierarchy`, `token`, `cardinality`,
   `filtered consumer`, `max_consumers`, `mirror vs`, `source vs`, `event sourc`, `aggregate`,
   `Nats-Expected`, `tiered`, `cold storage`, `archive`.
3. Synadia's *Design Patterns for Scaling NATS* series — the one post in `raw/synadia-blog/` is
   already summarised as `s-synadia-jetstream-anti-patterns`; check whether the **series** has other
   parts and whether `synadia.com/blog` has newer design posts.
4. **NATS by Example** (natsbyexample.com) — the one source in this space the wiki has never touched.
   Its stream/consumer and multi-tenancy examples are candidate material for both pattern pages.
5. The ADRs — `inbox/adr-toc.md` for anything on subject transforms, per-subject limits, consumer
   filtering or stream sourcing that is not yet ingested.
6. Stack Overflow, via the API pattern already in use, for the two rows whose public form is a
   maintainer answer rather than a design question (109, 114).

**Replace `own` with a URL wherever one turns up**, and record "searched, not found" per row otherwise.
The user picks what enters the wiki; do not auto-ingest. Cap the ingest that follows at ~8 summaries.

### 2 · Ingest the picked sources
status: done 2026-09-04 — the scout's recommendation taken whole: **eight summaries** (`s-gh-6100-stream-per-subject-or-one`, `s-gh-4170-subject-indexing-internals`, `s-gh-4499-workqueue-fanout-retention`, `s-gh-3405-consumer-filtering-performance`, `s-gh-6571-source-mirror-or-one-stream`, `s-gh-3772-jetstream-as-an-event-store`, `s-synadia-subject-hierarchies`, `s-synadia-expected-sequence-headers`) and **15 ripples**, unlanded back to 0. Docs issue **#123** (one paragraph of S1 explains wildcard cost with a matching path the server does not have; its other four checkable claims hold). An open `## To verify` item on `publishing` **settled** from the source: five expectation headers, six rejection codes, the 2.11.0 and 2.12.0 boundaries. Bank 169/197 → **170/198** (row 198 added from gh#3871; row 112 re-pointed). **Row 144 gets its own page**, `event-sourcing-on-jetstream` — gh#3772 alone carries a subject-per-aggregate design, two OCC granularities with a third header the thread predates, a filtered-replay cost model, a Raft-asset ceiling and a named dead end, which is more than a section of `stream-topology-design` can hold without unbalancing it.

*Operation: ingest* for each source the user picks, ~8 summaries maximum. Expect: six thread
summaries (`s-gh-6100-…`, `s-gh-4170-…`, `s-gh-4499-…`, `s-gh-3405-…`, `s-gh-6571-…`,
`s-gh-3772-event-store`), plus whatever the scout adds from NATS by Example and the Synadia series.
Ripple each summary onto the pages it touches **now** ([[stream]], [[subjects-and-wildcards]],
[[retention-policies]], [[mirrors-and-sources]], [[consumer]], [[filestore-layout]],
[[jetstream-slows-as-consumers-grow]], [[jetstream-sizing]]) rather than leaving it for the page steps
— that is what keeps the unlanded-ripple count at 0. Record every contradiction found on the way in
`inbox/docs-issues.md`, verified against the server at v2.14.6.

Decide here whether row 144 gets `event-sourcing-on-jetstream` or a section (see the table above), and
write the decision into this step's `status:` line.

### 3 · The runs — what many streams and many filtered consumers actually cost
status: done 2026-09-04 — `raw/nats-server-src/stream-topology-observed-v2.14.6.md` (1,478 lines, six runs A–F plus the R3 pass, with twelve run scripts, `topolab.py`, `snap.py` and `limits.conf` beside it; `raw/sources.md` row added). **Run A/B**: an empty file stream is 8 KiB and 3 files on disk and ~53–58 KiB of RSS; 1,000 R1 streams create at 1,592/s, 10,000 at 675/s; the publish rate into one stream does not move between 1 and 1,000 streams (194k–209k msg/s); the **first** message into a fresh stream costs ~4.4 ms; the same 100,000 messages cost **1.26×** more disk spread over 1,000 streams than in one; a clean restart is 125 ms at 1,001 streams and **5.4 s at 10,000**. **R3**: creating a replicated stream is **P50 ~110 ms** against R1's 0.6 ms, `ha_assets` = streams + 1, and a node holding 1,000 R3 streams takes **18 s** to come back and more than 10 s to shut down. **Run C**: gh#3405 confirmed — a filter with one match in the middle of a million is a 0.9 ms create and a 2.3 ms first message; 1,000 consumers on one stream cost nothing at publish time; **the ~300 figure is about *disjoint filters on one consumer*, and it is a create-time cost** (1.0 → 4.6 → 33.7 → 784 ms at 1 → 300 → 1,000 → 5,000 filters) while the first fetch stays 0.2 ms. The 300-way fan-out one way costs **2.75× the RSS** and **1.5× less ingest** than the other. **Run D**: `10027` / `10026` / `10002`, and the account's `max_consumers` is **per stream** — docs issue **#124**. **Run E**: `index.db` is exactly Σ(len+4) + ~550 B, cardinality costs ~256 B of RSS per subject and a few hundred ms of restart, and `STREAM.INFO` pages its subject list at `JSMaxSubjectDetails` = 100,000. **Run F**: a sourcing stream costs **1.38–1.57×** a mirror because it stores a `Nats-Stream-Source` header on every message; a mirror may not have subjects (`10034`) or sources (`10031`); neither copy follows a delete on the origin and both survive the origin's deletion; and **the third shape does not exist server-side** — a push consumer delivering into a second stream delivers **nothing**, because `Sublist.registerNotification` only counts an exact-subject subscriber (server issue **SI-9**). Also read from the source for step 4: the **32-token stack array** and the **256-byte subject buffer** are real (`sublist.go`, `stree/stree.go`), the 16-token limit is not.

Rows 108 and 111 are answered in public with a *shape* ("streams are cheap, consumers are not";
"filtering is indexed") and no numbers, and both are behavioural. Run them on the 2.14.6 binary
through `tools/lab/cluster.sh`, and write `raw/nats-server-src/stream-topology-observed-v2.14.6.md`
with the scripts, exactly as phases B, E and F did. The runs, in the order that each one's result
shapes the next:

- **A — many streams against one stream.** Create 1, 10, 100, 1000 R1 streams on one server, then the
  same message volume through one stream with a tenant prefix. Measure: creation time per stream,
  RSS, `nats server report jetstream`, `$SYS` `STATSZ`/`JSZ` numbers, the `store_dir` tree, and a
  restart's recovery time. Repeat the 100-stream case at **R3** on the lab cluster for the meta-layer
  cost (`ha_assets`, the meta snapshot).
- **B — the per-stream floor.** What one empty stream costs on disk and in memory (the block-size
  slack already on [[filestore-layout]] and [[jetstream-sizing]] gives the arithmetic to check
  against).
- **C — filtered consumers on one stream.** 1, 10, 100, 300 consumers with disjoint filters on one
  stream; publish rate at each; the ~300-filter threshold [[jetstream-slows-as-consumers-grow]]
  states from a public report, measured. Then the same fan-out as N small streams with one consumer
  each, for the comparison row 111 asks for.
- **D — `max_consumers` and `max_streams` at the account limit.** What a tenant sees at the limit:
  the exact error code and message on stream create and on consumer create.
- **E — subject cardinality.** 10, 10k, 1M unique subjects in one stream: `index.db` size against the
  `len(subject) + 4` arithmetic, `nats stream subjects` cost, a filtered consumer's first fetch, and
  the restart recovery time (the connection to [[jetstream-recovery-is-slow]]'s "more than a million
  subjects" cause).
- **F — the three replication shapes for row 114.** The same source stream copied by (i) a mirror,
  (ii) a `sources` stream, (iii) a filtered consumer writing into a second stream: what each costs in
  disk, in lag, and in what it can and cannot do (`mirror_direct`, subject transforms, writability).

Record what was **not** tested. A number from one laptop is a ratio, never a limit — say so on every
page that quotes one.

### 4 · `subject-design` — the pattern page for row 109
status: done 2026-09-04 — `wiki/operations/subject-design.md` (`kind: pattern`, 325 lines) and, first, the missing summary of step 3's run file: **`s-nats-server-stream-topology-observed`**, without which steps 4–7 have nothing to cite. The page: the four mechanisms that read the subject strings; start from the queries ("define all possible sets within a stream and make sure they represent tokens"), two lookup keys and only two; the three shapes with the tie-break rule (**"you can prepend a tenant token; you cannot easily un-prepend one"**); token order left-to-right, argued from the matcher (`*` recurses, `>` is a pointer check) *and* from growth; cardinality as entity-ids-yes / per-message-ids-no with the ART since **2.10.10**; **the four subjects a stream must never be given** (#119's request/reply hijack, `>`, the nine reserved prefixes, sweeping a tree); the tenant token against an account; the version-token disagreement carried as a disagreement; the five places a subject string appears and the migration order; run E's cardinality table; and **the three "limits" that are not limits** (16 tokens, 256 characters, `max_subscription_tokens`). **Ripple: ten pages** — [[subjects-and-wildcards]] (cardinality on one axis), [[stream]] (the per-stream floor), [[filestore-layout]] (`index.db` = Σ(len+4) + ~550 B, checked at three cardinalities), [[jetstream-sizing]] (the floor and the per-subject RAM term), [[jetstream-slows-as-consumers-grow]] (the ~300 is *disjoint filters on one consumer* and it is a **create-time** cost; the 300-way fan-out both ways), [[mirrors-and-sources]] (1.38–1.57×, the `Nats-Stream-Source` header, and SI-9 killing the third shape), [[consumer]] (the seek measured), [[account]] (**#124** — `max_consumers` is per *stream*; the account bullet above it corrected), [[jetstream-recovery-is-slow]] (stream **count** against stream size), [[meta-layer]] (`ha_assets` = streams + 1, R3 create at P50 ~110 ms). Bank **170 → 171 / 198** (row 109). Lint 427 pages, drift 0, unlanded 0, broken 0 with **two deliberate wanted links** — `stream-topology-design` and `event-sourcing-on-jetstream`, steps 5 and 7 — registered in `wiki/index.md`.

`wiki/operations/subject-design.md`, `kind: pattern`, in the pattern template. What it must carry:
the token order that survives (coarse to fine, the tokens you will filter on to the left of the ones
you will not), where a wildcard can and cannot go, the cost of cardinality with the numbers from run
E, the subjects a stream must never be given (#119 — request/reply; `>`; `$JS.API.>`; `$SYS.>`), the
account/tenant token and what it buys against a separate account, subject transforms and
`{{partition(n,1)}}` as the escape hatch, and the three things that are **not** limits
(no length limit, no token limit, `max_subscription_tokens` off by default). Link
[[subjects-and-wildcards]] for the rules and do not restate them.

### 5 · `stream-topology-design` — the pattern page for rows 108, 111, 114
status: done 2026-09-04 — `wiki/operations/stream-topology-design.md` (`kind: pattern`, 12 summaries cited), the three questions in one page. **How many streams**: the one-stream default with the maintainer's quote and the one reason to leave it (policy, not performance), plus blast radius and placement; a table of what a second stream costs at `R1` against `R3` (0.6 ms against P50 ~110 ms to create, 8 KiB + ~55 KiB of RSS, `ha_assets` 0 against streams + 1, restart 125 ms → 5.4 s → **18 s**); the publish path flat from 1 to 1,000 streams, ~4.4 ms for the first message, 1.26× the disk when a volume is spread; and the answer to *where does it start to cost you* — **at `R1` count restart seconds, at `R3` count HA assets** (Synadia's operating 2k/server, the "100s of thousands" theoretical ceiling, `max_ha_assets`). **The per-tenant question** carried as the disagreement it is: gh#6100 says one stream, Synadia's per-tenant FIFO post says one per tenant at "hundreds to low thousands" — they answer different questions (per *subject* against per *tenant*), and the `R3` numbers say the line falls exactly in that range. **`## Tenancy: what an account's limits actually cap`** with docs issue **#124** (`max_consumers` is per *stream*, so a tenant's real ceiling is `max_streams × max_consumers`), the four codes, the 22-byte reservation, the budget returning at once, and copies not spending the consumer budget. **How many consumers**: consumers flat to 1,000, the 300-way fan-out built both ways (**2.75× the RSS, 1.5× less ingest** for many streams), the ~300 sharpened into a **create-time** cost, the ~100k guidance, and which readers need a consumer at all (republish, Direct Get, one consumer per *app* not per instance). **How a second copy is made**: the premise rejected first ("it's not because a stream is larger…"), then mirror against source in a table (1.38× disk, 1.57× with a transform, the `Nats-Stream-Source` header that explains it, `10034`/`10031`), what neither does (follow a delete; break when the origin is deleted), and **SI-9 as a design rule** — the third shape does not exist server-side, a client has to make the copy and the copy loses the origin's sequence identity. Then the config block, a seven-row trade-off table and *when not to*. Ripple: `stream-topology-design` added to the `## Pages touched` of `s-gh-6100`, `s-gh-3405` and `s-gh-6571`; `wiki/index.md` (Patterns, and off the wanted list); **SI-9 given its `Where the wiki records this` line**, which it lacked. Bank **171 → 174 / 198** (rows 108, 111, 114). Lint 428 pages, drift 0, unlanded 0, broken 0, one wanted link left (`event-sourcing-on-jetstream`, step 7).

`wiki/operations/stream-topology-design.md`, `kind: pattern`. The three questions in one page:
**how many streams** (the per-stream floor, the meta-layer cost, account `max_streams`, the blast
radius argument, and the one-stream-per-tenant case that is really an account question — link
[[account]] and leave the tenancy design itself to G4); **how many consumers, and on what** (filtered
consumers against small streams, `max_consumers`, per-consumer state, the ~100k and ~300 thresholds);
**how a second copy is made** (mirror against source against a consumer, from run F, linking
[[mirrors-and-sources]] and [[multi-region-jetstream]]). Trade-offs, costs, and *when not to*: name
the counts at which each design stops working, with the run behind each number.

Two commitments made by step 3 land here: a **`## Tenancy: what an account's limits actually cap`**
section carrying docs issue **#124** (an account's `max_consumers` is per *stream*; `10027`, `10026`,
`10002`), which `inbox/docs-issues.md`'s *where the wiki records each of these* table already points
at; and the third replication shape's failure (**SI-9**) stated as a design rule rather than a
curiosity — a consumer cannot make the copy on its own, a client has to.

### 6 · `## Choosing retention` on `retention-policies` — row 110
status: done 2026-09-04 — **`## Choosing retention: a task queue, an event log, a cache`** on [[retention-policies]], inserted before *What you cannot change later* so the permanence argument lands immediately after the choice, with `tools/add-section.py` (seven summaries added to the frontmatter, one of them new to the page: `s-adr-8-key-value-store` for the bucket shape). The section reframes the three policies as **two questions asked in order** — *how many independent readers must see each message* (more than one excludes WorkQueue before anything else) and *does the message still have value once every reader has finished* (yes → `limits`, no → `interest`) — then a four-row table: task queue → `workqueue` (non-overlapping filters or a shared pool, `ack_policy: explicit` / `10084`); event log → `limits` (or no limits at all and a time shard, from row 27's answer); **the fan-out that must be complete but not kept** → `interest`, with the trap that the consumers must exist *before* the messages; and cache → `limits` with `max_msgs_per_subject`, which is exactly what a KV bucket is. Then **`### What breaks on each wrong choice`**: `10099`/`10100` found on the *second* consumer (gh#4499, diagnosed for two weeks as a filter bug), WorkQueue's ack/term/purge destroying data that had a second life, Interest dropping a message with **no** interested consumer the moment it is published and one stalled consumer holding the whole stream, `discard: old` discarding silently and `discard: new` refusing with `10077` and logging nothing, and a cache without `max_msgs_per_subject` where a hot key evicts the cold ones. `verified-against` deliberately **left at 2.14** — the section restates claims already on the page and adds no new version-bearing one, so bumping it would imply a re-check that did not happen. `wiki/index.md`'s one-line entry rewritten. Bank **174 → 175 / 198** (row 110). Lint 428 pages, drift 0, unlanded 0, broken 0.

One section on the existing concept page: the task queue, the event log and the cache, each with the
retention it wants and the reason; what breaks on each wrong choice (the `10099`/`10100` WorkQueue
consumer rules, Interest filling the disk with no consumer, Limits silently discarding); and the fact
that makes it matter — the choice is effectively permanent (the page's own *What you cannot change
later*). `tools/add-section.py` for the insert, so the frontmatter records the sources.

### 7 · `event-sourcing-on-jetstream` — rows 144 and 198
status: done 2026-09-04 — `wiki/operations/event-sourcing-on-jetstream.md` (`kind: pattern`, `since: [2.11]`, 13 summaries cited), **plus the second-pass ingest the step-1 scout left open**: row 198 had no source in the wiki at all, so `gh#3871` and `gh#6478` were fetched whole into `raw/gh-discussions/` with their `raw/sources.md` entry and summarised as `s-gh-3871-tiered-storage-planned` and `s-gh-6478-s3-offload-and-query`. The page: the four things an event store needs; one stream with a subject per aggregate and `limits` with **no limits** (row 27's answer); **the OCC header most designs get wrong** — subjects are exact, so an aggregate spanning `order.1.created` and `order.1.shipped` needs `Nats-Expected-Last-Subject-Sequence-Subject` (**2.11.0**, and `10193` for the half-sent form only since **2.12.0** — the reason the page's `since:` is 2.11); 2.12 atomic batch for several events from one command, with the abandoned-batch trap; reading (an indexed range scan per aggregate, 0.9 ms create / 2.3 ms first message measured; Direct Get for current state; filtered consumers for projections; an ordered consumer for a full replay); snapshots in a KV bucket keyed by aggregate; **what a million aggregates cost** — run E's table with four consequences, of which two are new here: *the index does not shrink when an aggregate goes quiet* (a dead entity costs its bytes forever on a keep-everything stream, which is the argument for time-sharding), and *the per-aggregate read stays cheap while the wildcard read goes 170×/190×*, so projections are the expensive readers. **The dead end** stated with dates: 2023-01-08 "not built-in", 2023-02-16 "planned but no schedule", asked twice more and never answered again, the 42-upvote idea with **no maintainer in it**, and the two workarounds — a block-level offload (the rclone mount that demonstrably worked, retention deletes included, then failed with `corrupted on transfer`) and an archiving consumer — with **sharding by time** as the only supported way to bound the store. Then a six-row trade-off table and five *when not to* rules. Ripple: [[stream]] (*And there is no tier below them either*), [[filestore-layout]] (*Why sealed blocks make an offload look easy, and what happened to someone who tried*) and [[kubernetes-storage]] (*Not an object-store mount either* — the rule read as being only about NFS also excludes an object store behind rclone or a CSI driver, and the mechanical reasons). Bank **175 → 176 / 198** (row 144; row 198's cell rewritten from a pointer into an answer). Lint 431 pages, drift 0, unlanded 0, broken 0, **wanted 0**.

`wiki/operations/event-sourcing-on-jetstream.md`, `kind: pattern` (decided in step 2), from `raw/gh-discussions/gh-3772.md` and the runs. What the
thread's chosen answer gives (2023-01-08, @bruth — re-verify every claim against 2.14.6 before it goes
on a page): a subject per aggregate under one stream; optimistic concurrency with
`Nats-Expected-Last-Sequence` (stream) or `Nats-Expected-Last-Subject-Sequence` (per aggregate);
subjects indexed inside a stream, so a filtered replay scans the blocks between that subject's first
and last sequence rather than the whole stream; a total order across the stream for consumption while
appends across subjects do not contend; and the dead end — **no tiered storage**, an archiving
consumer is the answer, and it was still "not built in" at the time of writing. Check whether 2.11–2.14
changed any of it (per-subject limits, `Nats-Expected-*` behaviour, the 2.15 preview), and check
[[publishing]] and [[direct-get]] state the OCC headers the same way this page will.

### 8 · Close the step group
status: not started

`wiki/index.md` (the new pages under Operations → Patterns, and the *Patterns* line under *Wanted
pages* rewritten); `inbox/question-bank.md` rows 108, 109, 110, 111, 114, 144 filled, and any new rows
the sources revealed; `inbox/scout-backlog.md` §5(b) updated with what G1 closed and what is left;
`inbox/docs-issues.md` and `inbox/server-issues.md` complete for the phase; `wiki/log.md`; then
`python3 tools/lint.py` (expect **0 · 0**, wanted 0) and `python3 tools/check-staleness.py` (expect 0
behind 2.14.6). Result line at the top of this file; `local/megaplan.md` phase G `status:`/`next:`
rewritten for **G2**.

---

## Done when

Rows **108, 109, 110, 111, 114, 144** are filled in `inbox/question-bank.md` (answered, or bold
`no-public-answer` — none is expected to need it, all six threads have a chosen answer);
`subject-design` and `stream-topology-design` exist as `kind: pattern` pages in the index, each with
`since:` and a `verified-against` naming its authority; [[retention-policies]] has its *Choosing*
section; row 144 has its page or section; every number quoted from a run names the run;
`tools/lint.py` reports **0 · 0** with wanted 0; `check-staleness.py` reports 0 behind 2.14.6; and
`inbox/scout-backlog.md` §5(b) records G1 as done with the scout that closed it.
