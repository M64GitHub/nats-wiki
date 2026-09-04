# Plan — the client side: what a client sees (proposed 2026-09-03)

Say **`start the plan inbox/plan-the-client-side-2026-09-03.md`** to work this file — name it
explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-03, commit `b2282e7`).** 345 pages; question bank 165 rows, 131
answered, 34 open (13 `own`); wanted 0; `(unverified)` 11; citation drift 0, unlanded ripples 0;
staleness 0 behind nats-server 2.14.6; docs issues 78 (none filed), server issues 5. Binary
`nats-server v2.14.6`, `nats` CLI 0.4.0; nats.go **v1.52.0** in the Go module cache while the
`nats-go` entity is pinned at **v1.53.1** (`raw/nats-go-src/` holds two quoted extracts at that tag);
natscli v0.4.0 in the module cache. The full server source at v2.14.6 sits in `.cache/nats-server-2.14.6/`
(the tarball `tools/check-defaults.py` keeps) and the phase-E file set in `local/scratch/src/v2.14.6/`.
Of the 12 client entities, two (`nats-go`, `nats-net`) have a *What bites you* section. No reader page
mentions `$GR.`, `$LDS.`, `$SRV`, `NATS/1.0 503`, `Stale Connection` or `-ERR`; no page owns core-NATS
delivery, queue groups, request/reply or the wire protocol.

**Why this plan.** Phase F of the maintainer's programme. Every page so far answers "what does the
server do"; the unread half of the docs answers "what does *my client* experience while the server
does it" — at-most-once and its ordering rule, the reconnect buffer, drain, the 503, the `-ERR` strings
a client prints, the services framework's queue groups. Rows 25, 133 and 134 wait on it, and ten client
entities owe the operator their *What bites you*.

**What the read found (2026-09-03, all four trees end to end, plus `concepts/` and
`reference/services/`).** 45 articles: `learn/core-nats` 11 + index, `learn/resilient-clients` 8 +
index, `learn/services` 6 + index, `reference/protocols` 4 + index, `reference/services` 3 + index,
`concepts` 11, `reference/config/mappings` 4. The digests are cached in `local/scratch/digest-*.md`
(never cited; the summaries re-read the raw files). What the plan must carry:

1. **The three `learn/` chapters are unversioned by design** — "This chapter is unversioned and
   concept-first" (`learn/core-nats/where-next.md`, `learn/resilient-clients/where-next.md:20`,
   `learn/services/where-next.md:24`). Not one nats-server, client or ADR version appears in the 26
   learn pages; the only version anywhere is `"version":"2.14.0"` in a sample `INFO` line
   (`connecting.md:59`). Every `verified-against` on the pages this plan writes therefore comes from
   the server source at v2.14.6, nats.go at v1.53.1 and natscli 0.4.0 — never from the chapter.
2. **`reference/protocols/client.md`'s `-ERR` table carries three wrong defaults on one table**:
   `Authorization Timeout … (default 1 second)` (L424) against `AUTH_TIMEOUT = 2 * time.Second`
   (`const.go:117`); `max_control_line … The default is 1024 bytes` (L426) against
   `MAX_CONTROL_LINE_SIZE = 4096` (`const.go:90`) — while the sibling `learn/core-nats/request-reply.md:37`
   says 4 KB; `Slow Consumer … (default 10MB)` (L431) against `MAX_PENDING_SIZE = 64 MB`
   (`const.go:102`). The page never states the ping interval or the outstanding-ping count
   (`DEFAULT_PING_INTERVAL = 2m`, `DEFAULT_PING_MAX_OUT = 2`, `const.go:120,123`), lists `client_id`
   twice with two types (L52 `uint64`, L63 `string`), and the four pages spell the payload error three
   ways (`Maximum Payload Violation` / `Maximum Payload Exceeded`) where the server has one literal
   (`client.go:2554`). The gateway and leafnode pages' "common errors" (`Invalid Account`, `Gateway
   Protocol Error`, `Loop Detected`, `Leafnode Not Allowed`) look invented — settled by grepping
   `sendErr(` in `gateway.go` / `leafnode.go`. `reference/system/errors.md` (phase E skipped it) is the
   second `-ERR` list and must be diffed against the first.
3. **The resilient-clients chapter states one thing nats.go does not do**: `slow-consumers.md:100`
   and `where-next.md:99` say a nats.go connection with no async error callback "discards" slow-consumer
   reports, so drops are invisible; nats.go installs `defaultErrHandler` when `AsyncErrorCB == nil`
   and writes `<err> on connection [<cid>] for subscription on "<subject>"` to stderr (v1.52.0
   `nats.go:1853–1856`, `1881–1902`; re-pin at v1.53.1 in step 3).
4. **ADR-40 contradicts the chapter and nats.go on stale detection**: `raw/adr/ADR-40.md:222–225`
   "If two consecutive PONGs are missed, connection is marked as lost"; `reconnection.md:325` and
   `where-next.md:72` say the *third* unanswered ping (~6 min); nats.go `pout++ ; if pout >
   MaxPingsOut` with `DefaultMaxPingOut = 2` (v1.52.0 `:5783–5784`, `:61`) sides with the chapter.
   **The wiki carries the ADR's reading** — `wiki/operations/upgrade-a-cluster.md:430–432` ("roughly
   four minutes") and `s-adr-40-nats-connection.md:79,122` — a wiki bug, fixed in step 3, and a docs
   issue with `destination: ADR repo`.
5. **The services chapter makes the queue group readiness-aware**: `scaling.md:150` "the server
   delivers each message to whichever queue-group member is ready", `:272` "sending requests to the
   busy instance's peers instead". The server picks a random start index over the members
   (`client.go:5516–5519`, "Find a subscription that is able to deliver this message starting at a
   random index") and knows nothing of a handler; a two-member run with one sleeping handler settles
   what an architect would size on (step 2, run C). `reference/services.md` — the overview — says
   services "announce themselves on startup" (L47; they subscribe and answer, `discovery.md:18`,
   ADR-32) and lists stats fields (`Resource utilization`, `rates`, `structured logging`) that no
   schema has. Every services page hands off to "Reference — every service configuration field and its
   valid range", a page that does not exist (`reference/services/` holds three response schemas);
   `where-next.md:38,40,42` promise `$SRV` coverage in Security and Topologies and a service-latency
   schema in Reference, none of which exist; `where-next.md:34` ("when an instance stops, its
   in-flight work is gone") contradicts `scaling.md:164` (`Stop()` drains). ADR-32 is cited by none of
   the eleven pages and is not ingested; neither are ADR-4 (headers, ★), ADR-47 (request many) or
   ADR-3 (service latency).
6. **`concepts/` (11 pages) is the deep dive's shorter form** — nine restate a learn page, two are
   already ingested (`s-docs-ecosystem`, `s-docs-getting-started`). Three sentences are the whole
   surplus: `subjects.md:1101` "Limit to ~16 tokens and under 256 characters" (no server basis: no
   subject limit exists; `max_control_line` 4096 bounds the line; `JSMaxNameLen = 255`
   (`jetstream_api.go:363`) is for stream and consumer names), `queue-groups.md:24` (a member cut as a
   slow consumer leaves the group), `request-reply.md:589` (`request()` returns the first reply and
   drops the rest). `reference/config/max_subscription_tokens.md` is an empty page for a real key
   (alias `max_sub_tokens`, `uint8` 1–255, unset = unlimited, subscriptions only, `opts.go:1370–1380`;
   `-ERR 'Permissions Violation for Subscription to "<subj>", too many tokens'`, `client.go:5814–5819`)
   that `wiki/reference/config-keys.md` also lacks.
7. **The core-NATS chapter's claims split into three kinds.** Verified while reading: `nats reply
   --queue` defaults to `NATS-RPLY-22`, `nats request --replies=1 --reply-timeout=300ms
   --wait-for-empty --timeout=5s`, `nats server mappings <source> <dest> <subject>`, `nats trace
   --deliver` (all `--help`, 0.4.0); echo on by default (`client.go:706`, the skip at `:3761–3762`);
   `no_responders` without `headers` closes the connection with `no responders requires headers
   support` (`client.go:2462–2467`); the 503 is `HMSG <reply> <sid> … NATS/1.0 503\r\nNats-Subject:
   <subject>` (`client.go:4508–4511`) — **the `Nats-Subject` header is stated nowhere in the docs**;
   weights above 100 per destination or per source are refused and a shortfall auto-adds the source at
   the difference (`accounts.go:811–816`, `:844`); the lame-duck notice is `Entering lame duck mode,
   stop accepting new clients` (`server.go:4446`); a wildcard in a *publish* is refused only in pedantic
   mode (`client.go:2931–2932`). To run: `/subsz?subs=1&acc=$G&test=<subject>`; `nats server request
   subscriptions` failing on a plain server while `… connections` answers; `nats trace` output on
   2.14.6; a whitespace subject over raw `nc` (the docs say nats.py and nats.go before v1.48.0 skip
   the check — a client version claim to source); headers counted against `max_payload`
   (`processHeaderPub`, `client.go:2861–2916`); listing the source subject as its own destination to
   drop the remainder. Stated without a source: "nats.go before v1.48.0" (`subjects-and-wildcards.md`),
   the reconnect buffer "8 MB" (nats.go `DefaultReconnectBufSize`, v1.52.0 `:63`).
8. **Row 25 is answered in one sentence in its own thread** — gh#7577, chosen answer 2025-11-24: "for a
   single publish connection order will always be preserved globally", after the maintainer's
   explanation that ordering is per publisher connection across subjects, with interleaving between
   publishers (`local/scratch/gh-index/threads-2026-09-03.md:16349–16365`; fetched whole in step 1).
   `publish-subscribe.md`'s "doesn't guarantee that two subscribers see messages in the same order
   under load" is the complement, not a contradiction.
9. **The resilient-clients chapter is the one source of per-client defaults**, and they diverge: connect
   timeout 2 s (Go, most) / 5 s Rust / 20 s JavaScript; `MaxReconnect` 60 Go, Java, Python / 10 JS /
   unlimited Rust, C#; reconnect buffer 8 MB Go, Java / 2 MB Python / backpressure Rust; pending limits
   500,000 msgs and 64 MB Go / 65,536 Rust / unbounded JS / 1,024 C#; drain timeout 30 s nats.go with a
   hardcoded 5 s flush; `Flush()` 10 s; ping 2 m × 2 (1 m Rust); Python and C# have no discovery
   opt-out, Python and Rust no auth-error abort, C# no closed event and no per-subscription drain, Java
   needs `reportNoResponders()`. The Go values are checked against nats.go v1.52.0 in the digest and
   re-pinned at v1.53.1 in step 3; the others are the docs' word and stay so on the client entities,
   cited to the summary with no version (step 6 reads each README and release for what it can confirm).

**Scope decisions, stated once.** (1) **The unit of ingestion is the article group, not the file**:
the eleven core-NATS pages become four summaries by the page they feed, the eight resilient-clients
pages five, the services tree three plus ADR-32, the protocols tree two (the client page; the three
internal protocols in one, because their operator value is the diff). The `concepts/` primers,
`reference/config/mappings/` and the `where-next` checklists are **read and folded** — named in the log
with the learn summary each folds into, the three surplus sentences carried as pointer lines with
`concepts/<file>.md:<line>` in the sentence. (2) **Authorities**: nats-server v2.14.6 for every server
claim (the `.cache` tree for whole files, `local/scratch/src/v2.14.6/` for the phase-E set, extracts
into `raw/nats-server-src/`); **nats.go v1.53.1** for every Go-client claim — `nats.go` (the file) is
fetched at that tag into `local/scratch/src/nats.go-v1.53.1/` in step 3 and the ranges quoted into
`raw/nats-go-src/`, every line number in the digest re-pinned there; natscli **0.4.0** for the CLI
(`--help` texts into `raw/nats-cli/`, the source from the module cache for the `>>>` lines, the
backoff table and the reply/request exit paths). Other clients' behaviour is stated as the docs state
it, cited to the summary, no version — step 6 confirms what a README or release note confirms and
marks the rest. (3) **Pages, by step**: concepts `core-nats-delivery` (row 25), `subjects-and-wildcards`,
`request-reply`, `queue-groups`, `client-connection-lifecycle`, `services-framework`; reference
`client-defaults`, `wire-protocol`; gotchas `slow-consumer-in-the-client` and
`connection-closed-after-auth-error`; patterns `services-on-core-nats` (row 134) and `core-or-jetstream`
(row 133, which closes G7); the account-level `mappings` block goes onto `subject-transforms` (its
aliases already claim *subject mapping* and `nats server mappings`), not a new page. Enrich, never
duplicate: `nats-timeout` keeps the timeout-vs-no-responders triage and points at `request-reply` for
the mechanism. (4) **Every behavioural claim is run** on `tools/lab/cluster.sh` (or a standalone
`nats-server -c` where the claim is about a single server), recorded in `raw/nats-server-src/*-observed-v2.14.6.md`
with the script beside it, as phases A–E did; the binary and every `verified-against` stay at 2.14.6.
(5) **Version dating**: core NATS predates every line this wiki covers, so the new concept pages carry
`since: [2.10]` with the *present at 2.10, not the arrival* comment `nats-timeout` uses; headers and
no-responders are dated from the v2.2.0 release body, fetched into `raw/release-notes/` in step 2
(one file, one manifest row) — never from memory. (6) **`$SRV` and the services framework are in
scope as what an operator sees** — the subject tree, permissions, queue groups, stats an exporter can
read, drain on stop — not as an API tutorial; handler code and the C structs stay in `raw/`.
(7) Design rows 133 and 134 get **pattern pages scouted first** from the discussions comment cache
(`local/scratch/gh-index/`), Synadia's *Design Patterns* series where `raw/synadia/` already has it,
and NATS by Example — the backlog's §5(b) rule — with `own` replaced by a URL when one turns up.

**Done when** (measured): rows **25, 133, 134** are filled; every one of the 12 client entities has a
`## What bites you` section; `wiki/log.md` states the docs coverage for `learn/core-nats` 11/11,
`learn/resilient-clients` 8/8, `learn/services` 6/6, `reference/protocols` 4/4, `reference/services`
3/3, `concepts` 11/11 (nine folded, two prior) and `reference/config/mappings` 4/4; the pages in scope
decision (3) exist, are in `wiki/index.md`, carry `verified-against` naming the authority each rests on
(2.14.6, nats.go v1.53.1, natscli 0.4.0) and `since:`; the ADR-40 reading on `upgrade-a-cluster` and
`s-adr-40-nats-connection` is corrected; every item in *What the read found* is in
`inbox/docs-issues.md` verified with file, line and run (the protocol table sweep with its count) or in
`inbox/server-issues.md` where only a question remains; `python3 tools/lint.py` reports **0 · 0**,
wanted 0; `check-staleness.py` 0 behind 2.14.6.

---

## Step 1 — core NATS, part 1: delivery, subjects and mapping · status: done 2026-09-03 — s-docs-core-nats-subjects-and-mapping, s-docs-core-nats-publish-subscribe, s-gh-7577-core-nats-ordering, s-nats-server-core-delivery, s-nats-server-core-delivery-observed, s-nats-cli-core-commands, s-gh-5097-subject-token-limit, s-gh-2855-publish-with-wildcards, s-gh-5172-mapping-in-config-or-stream, s-nats-go-relnotes-1.48.0; pages `core-nats-delivery` (row 25) and `subjects-and-wildcards`; 12 ripples; docs issues #81–#84, SI-7; rows 25, 169–171 filled (169/170 got URLs from the cache: gh#5097 + gh#2855, gh#5172); runs A–G + F8 in `core-delivery-observed-v2.14.6.md`; the 503's `Nats-Subject` row deferred to step 2 as planned; lint 366 pages, 0 · 0, wanted 0, unverified 12 (one new, under `## To verify`), staleness 0 behind

*Operation: ingest*, six summaries. **Cache first**: fetch gh#7577 whole with
`python3 tools/fetch-discussion.py 7577 --out raw/gh-discussions` (manifest row); capture `nats
request --help`, `nats reply --help`, `nats trace --help`, `nats server mappings --help`, `nats sub
--help`, `nats pub --help` into `raw/nats-cli/help-core-0.4.0.md` (one file, a provenance header,
each block verbatim). **Extract** `raw/nats-server-src/core-delivery-v2.14.6.md` (verbatim ranges, the
`constants-v2.14.6.md` form): `const.go:88–123` (control line, payload, pending, ping); `client.go`
`:676–707` (`ClientOpts`, `defaultOpts` with `Echo: true`), `:2454–2470` (the `no_responders` /
headers mismatch), `:2545–2560` (`Maximum Payload Violation`), `:2861–2920` (`processHeaderPub`, the
header-plus-body check), `:2925–2935` (the pedantic literal-subject check), `:3085–3130` (`Invalid
Subject`, too many tokens), `:3755–3765` (the echo skip), `:4500–4515` (the 503 `HMSG` with
`Nats-Subject`), `:5810–5820` (the token-count violation); `opts.go:1370–1380` (`max_subscription_tokens`),
`:1750–1751` (`no_header_support`); `accounts.go:760–870` (`MapDest`, the weight checks, the auto-add
of the source); `sublist.go` `isValidSubject` (the rune set: empty token, ` \t\n\f\r`, non-final `>`);
`server.go:4440–4450` (the lame-duck notice). **Run** on a standalone `nats-server -m 8222 -c
mappings.conf` (v2.14.6, version printed into the transcript) and once on `tools/lab/cluster.sh up 3`,
recorded in `raw/nats-server-src/core-delivery-observed-v2.14.6.md` with `core-delivery-run.sh`
beside it: (A) `nc` capture of the `INFO` line, then `PUB "orders.us created" 0` over raw `nc` and a
`nats sub '>'` tap showing the misroute (`orders.us` as subject, `created` as reply) — the whitespace
claim; and `nats pub "orders.us created"` failing client-side with its exact text; (B) a 2 MB `nats
pub` against `max_payload` (client-side text) and an `HPUB` whose headers plus body cross 1 MB over
`nc` (the server's `-ERR`); (C) `SUB orders.>.created 1` over `nc` → the `-ERR`; a `PUB orders.*.created`
from a non-pedantic and a pedantic (`CONNECT {"pedantic":true}`) connection; (D)
`/subsz?subs=1&acc=$G&test=orders.us.created` with an `orders.>` subscriber, then with none; `nats
server request subscriptions` and `… connections` on the plain server (the two outcomes the docs
claim), then on the lab with the system account; (E) `nats trace orders.us.created` with and without
`--deliver`, with no subscriber and with `orders.>` — the exact output; (F) `nats server mappings`
dry runs for the three docs examples; a config with weights `10`, with `60 + 50` (refused — the exact
refusal text), with the source listed as its own destination at `90 + 10` (does the remainder drop:
count 200 publishes on the tap); `{{partition(3,1)}}` with the three order ids from the docs; a
`nats-server --signal reload` after editing `mappings` and a publish that proves it took; (G) `nats
sub orders.created` then stop and restart the server: the `>>> Disconnected due to: EOF` line, `--trace`
for the reconnect line, and a publish in the gap counted lost; `nats-server --signal ldm` with the
subscriber attached — the server's notice line and the CLI's. **Summaries**:
`s-docs-core-nats-subjects-and-mapping` (`subjects-and-wildcards.md`, `subject-mapping.md`,
`reference/config/mappings.md` + `destination.md`, `weight.md`, `cluster.md`; `concepts/subjects.md`
folded with its L1101 pointer), `s-docs-core-nats-publish-subscribe` (`core-nats.md`,
`connecting.md`, `publish-subscribe.md`, `headers.md`, `connection-lifecycle.md`,
`debugging-delivery.md`, `where-next.md`; `concepts/pub-sub-basics.md`, `what-is-nats.md`, `intro.md`
folded), `s-gh-7577-core-nats-ordering`, `s-nats-server-core-delivery` (the extract),
`s-nats-server-core-delivery-observed` (the runs), `s-nats-cli-core-commands` (the six help blocks:
flags, defaults, aliases). **Pages**: `wiki/concepts/core-nats-delivery.md` — what core NATS
promises (at-most-once; the interest graph; fan-out; ordering per publisher connection across subjects
with interleaving between publishers, gh#7577; what a queue group and a cluster hop do to it — pointers
to step 2), what it never does (retry, dedupe, store), echo and `NoEcho`, `max_payload` with headers
counted (`processHeaderPub`), the slow subscriber (pointer to `slow-consumer-detected` and step 4),
the connection's part (buffered publishes, flush before exit, the reconnect gap — pointer to step 3),
the four debugging surfaces as a table (wire tap · `/subsz?test=` · `/connz?subs=true` · `nats trace`,
with the 2.11 floor for tracing and the system-account rule for `nats server request`) — **row 25**;
`wiki/concepts/subjects-and-wildcards.md` — tokens, case, the rune set the server refuses (`isValidSubject`),
`*` and `>` and where each may sit, a `*` inside a token (→ `SI-3`), publish-side wildcards refused only
in pedantic mode, the reserved prefixes (`$SYS`, `$JS`, `$KV`, `$O`, `$SRV`, `_INBOX`, and that the
server enforces none of them for a plain client — `$SRV` never appears in `server/*.go`), no length or
token limit except `max_control_line` and the optional `max_subscription_tokens`, what cardinality
costs (pointers to `filestore-layout`, `jetstream-sizing`). **Ripples**: `subject-transforms` gains
*Account-level `mappings`* (the block, weights, the remainder rule as observed, `cluster`, reloadable,
`nats server mappings`); `defaults-and-limits` (`max_subscription_tokens` row; the `-ERR` behind
`max_control_line` / `max_payload`); `config-keys` (`mappings` reloadable, `no_header_support`,
`max_subscription_tokens` / `max_sub_tokens` — reload or restart, checked); `monitoring-endpoints`
(`/subsz` `test=`, `acc=`, `subs=1`, `qgroup`); `slow-consumer-detected` (the client-side counterpart
sentence); `publishing` (one sentence pointing at core ordering); `nats-cli` cheat sheet (`nats
trace`, `nats server mappings`, `-H`, `--headers-only`, `--count`, `--connection-name`, `--trace`);
`nats-server-2.11` (`nats trace` needs 2.11 — tie to the message-tracing entry already there);
`nats-py` (`publish` skips the whitespace check — the docs' claim, `(unverified)` until step 6 reads the
client); `nats-go` (the "before v1.48.0" claim — settle from the v1.48.0 release body, fetched to
`raw/github-repos/` or `raw/nats-go-src/`, else `(unverified)`); `unauthenticated-clients-still-connect`
(the plain server's `$G` account and `$SYS` with no user, from run D). **Docs issues** (verified):
`concepts/subjects.md:1101` (the unsourced limit), `reference/config/max_subscription_tokens.md`
(empty page; sweep the sibling `max_*` config pages and say how many), the `Nats-Subject` header on the
503 stated nowhere (record with step 2's run), `concepts/subjects.md:1080–1087` (`_INBOX` under "starting
with `$`"), and whatever runs A–G contradict. **Bank**: row 25 → `[[core-nats-delivery]]`; add posed rows
the pages now answer (a subject's legal characters and reserved prefixes; account-level mapping to
rename or shard a subject; which tool shows why a message never arrived), scouting the comment cache
for a URL first. Index, log (with the fold list for `concepts/`), lint.

## Step 2 — core NATS, part 2: request/reply and queue groups · status: done 2026-09-03 — s-docs-core-nats-request-reply, s-docs-core-nats-queue-groups, s-adr-4-message-headers, s-adr-47-request-many, s-relnotes-2.2.0, s-nats-server-request-reply, s-nats-server-request-reply-observed, s-nats-cli-request-reply-source, s-gh-2760-one-connection-or-two; pages `request-reply` and `queue-groups`; 15 ripples + 2 in place (+ the `gateway` line-number correction); docs issues #85–#89 (#86 is the services tree's row, recorded now with run C), SI-8 (a leaf's members skew the hub's split 3 : 1); rows 138 and 150 filled, 172–174 added and answered; runs A–H in four passes (`request-reply-observed-v2.14.6.md`, the lab for E, a standalone hub + leaf for H); the v2.2.0 body names neither headers nor `no_responders` — dated from `server.go`/`client.go` at v2.1.9 and v2.2.0 (`headers-arrival-v2.2.0.md`), `Nats-Subject` from the 2.12.0 body; the digest's "same server first" reading was wrong — uniform per member (run E, `sublist.go:741–747`); the docs' readiness claim settled (random, run C); lint 377 pages, 0 · 0, wanted 0, unverified 12, staleness 0 behind. Carried to step 3: natscli 0.4.0 pins nats.go v1.51.0 (the entity pin is v1.53.1 — say which is quoted); the nats.go request/inbox ranges were read at v1.52.0 and not quoted

*Operation: ingest*, six summaries. **Cache first**: the v2.2.0 release body via `gh api
repos/nats-io/nats-server/releases/tags/v2.2.0` into `raw/release-notes/` (manifest row; the date for
headers and no-responders); ADR-4 and ADR-47 are in `raw/adr/`. **Extract** (append to
`core-delivery-v2.14.6.md` or a second file): `client.go:5440–5575` (`processMsgResults`: the random
start index, "favor qsubs in our own cluster", the route/leaf fallback, the spoke rule) and
`:4470–4515` (queue names carried on `RMSG`, the no-responders send); `gateway.go` around `:2652`
(the queue-group exclusion list, already on `gateway`). **Run** (`request-reply-observed-v2.14.6.md`,
script beside it): (A) `nats reply` with the default group and a second `nats reply` with `--queue
carrier-b`: `/subsz?subs=1` showing `qgroup: NATS-RPLY-22` and the reply counts under `nats request
--replies 0 --timeout 2s` (one reply vs two); (B) the 503 over raw `nc` — `CONNECT
{"headers":true,"no_responders":true}`, `SUB _INBOX.x 1`, `PUB nobody _INBOX.x 0` → the `HMSG … NATS/1.0
503 … Nats-Subject:` bytes; then `CONNECT {"no_responders":true}` without headers → the `-ERR` and the
close; (C) **the readiness claim**: two `nats reply` members, one with `--sleep 2s`, `nats request
--count 20`, then per-member counts from `/subsz` `msgs` — does the busy member keep its share (the
answer to *What the read found* 5, and the queue-group section's "random, not readiness-aware"
sentence); (D) `--replies 3 --timeout 2s` vs `--replies 0 --timeout 2s` vs `--wait-for-empty` timed
against three responders and against two (the docs' timing claims); (E) on the lab: a queue group with
members on two nodes and a publisher on one — which node's member is picked over 100 publishes (the
same-server preference from `processMsgResults`); (F) `nats request` exit codes on timeout and on no
responders (the docs say 0 for both). **Summaries**: `s-docs-core-nats-request-reply`
(`request-reply.md`, `scatter-gather.md`; `concepts/request-reply.md` folded with its L589 and Java
`reportNoResponders()` pointers), `s-docs-core-nats-queue-groups` (`queue-groups.md`;
`concepts/queue-groups.md` folded with its L24 and L2064–2093 pointers), `s-adr-4-message-headers`
(the wire format, `Nats-` reservation, the status line, when it landed), `s-adr-47-request-many`
(count / stall / sentinel, which clients implement it — the *Partially Implemented* status),
`s-relnotes-2.2.0` (only the headers, no-responders and JetStream-arrival lines matter; the rest
folded as "before this wiki's range"), `s-nats-server-request-reply-observed` (runs A–F). **Pages**:
`wiki/concepts/request-reply.md` — the inbox (`_INBOX.<nuid>.*` one subscription per connection, the
per-request token, `--inbox-prefix` / `CustomInboxPrefix` and why an allow-list needs `_INBOX.>`),
timeouts (no client default in nats.go; the CLI's 5 s), the three outcomes and how each client names
them, the 503 exactly as the server sends it (`Nats-Subject`, requires `headers` + `no_responders` in
`CONNECT`, closes the connection otherwise, arrival version from the 2.2.0 body), scatter-gather (the
first-reply-wins rule; `--replies`, `--reply-timeout`, `--wait-for-empty` as run; ADR-47's helpers and
which clients ship one), what a cross-account import does to the 503 (pointer to `cross-account-sharing`,
row 150), the services framework as the next layer (pointer to step 5); `wiki/concepts/queue-groups.md`
— membership by exact name, the random pick as observed (run C: not readiness-aware; a slow member
keeps receiving until its pending buffer fills — pointer to step 4), coexistence with plain
subscribers, one subject per group, wildcard groups, the in-cluster and cross-cluster preference as
the source states it (run E), what a leaf does (`topologies.md:109`, the spoke rule), the at-most-once
consequence and `worker-pool` as the durable alternative, the typo-makes-a-second-group pitfall,
`/subsz` `qgroup` as the only view. **Ripples**: `nats-timeout` (the 503 mechanics and the exit-code
note, pointer to `request-reply`); `worker-pool` (the core queue group as the non-durable sibling);
`gateway` (the same-server-first order from `processMsgResults`, if not already exact); `leafnode`
(queue groups across a leaf); `subject-permissions` (`--inbox-prefix`, `_INBOX.>`); `cross-account-sharing`
(row 150's note lands: what the run shows for a 503 over an import — one extra run if cheap);
`nats-java` (`reportNoResponders()` opt-in, from the docs); `nats-cli` (`nats reply --queue
NATS-RPLY-22`, `--echo`, `--command`, `NATS_REQUEST_BODY`; `nats request --replies` family);
`orbit` (`RequestMany`); `nats-js` (`requestMany`); `nats-net` (`RequestManyAsync`); `core-nats-delivery`
(the queue-group and reply sentences now link). **Docs issues**: `scaling.md:150,272` if run C
contradicts it (the row belongs to the services tree but the evidence is this step's), the 503's
`Nats-Subject` (with run B), `concepts/queue-groups.md:1528` "exactly once" vs `:2131`. **Bank**: rows
138 (one connection or two — the head-of-line sentence on `request-reply` / `core-nats-delivery` if
the sources support it, else left), 150 (if the import run is done); posed rows for scatter-gather
timing and the queue-group readiness question, URL-scouted first. Index, log, lint.

## Step 3 — resilient clients, part 1: connecting, reconnecting, draining · status: done 2026-09-04 — s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown, s-nats-go-connection, s-nats-cli-reconnect, s-nats-server-client-lifecycle-observed; pages `client-connection-lifecycle` and `reference/client-defaults`; 17 ripples; the ADR-40 four-minute reading corrected on `upgrade-a-cluster` and `s-adr-40-nats-connection`; docs issues #90-#95, no server issue; rows 175-179 added and answered (147 / 179, `own` 24); runs A1-A3, B1-B5, C1/C4, D1-D3, E1-E9 in four passes (`client-lifecycle-observed-v2.14.6.md`, the lab for A/B/C/E, standalone servers for D). **What the runs settled**: a one-URL client fails over only through gossip (A2); the reconnect gap is 0 lost at 89 msg/s and 10 lost at 25 800 msg/s, one run of ~0.39 ms (A3); the lame-duck INFO carries `"ldm":true` and drops the server's own address 0.6 s in, a peer's clients get the shortened list without the flag, and clients are closed 10.0 s after the JetStream shutdown (B1-B4); a client that never PINGs gets no lame-duck INFO at all, `route.go:1026-1028` (B5); `nats reply` Ctrl-C answered 4 of 8 and abandoned 4 (C4); the server's stale rule is the third interval too, `-ERR 'Stale Connection'` at t=12.19 s with nothing in its log (D1); **nats.go's own detection is exactly six minutes**, which settles ADR-40 (D3); the CLI's backoff never uses its 500 ms first step, `Duration(3)`=2.15 s proves the indexing (D3, docs issue #91); a pull consumer across a consumer-leader move loses one fetch of 120 to `no responders` in 17 ms (E8) and un-acked messages return with `tries: 2` while `num_redelivered` still reads 0 (E9). Lint 385 pages, 0 * 0, wanted 0, unverified 12, staleness 0 behind. **Carried to step 4**: the `websocket` ripple (`wss://` is named only in `tls-and-auth.md`), the client-side slow consumer and the expired-credential `-ERR` strings — all three need a Go program rather than the CLI, which step 4 already plans; and nats.go's request/inbox ranges are still unquoted (carried from step 2)

*Operation: ingest*, five summaries. **Cache first**: `nats.go` at **v1.53.1**
(`raw.githubusercontent.com/nats-io/nats.go/v1.53.1/nats.go`) into `local/scratch/src/nats.go-v1.53.1/`
(INDEX row; may stay for the life of the pin); natscli v0.4.0 `cli/util.go`, `cli/reply_command.go`,
`cli/req_command.go`, `internal/util/backoff.go` from the module cache. **Extract**
`raw/nats-go-src/connection-v1.53.1.md`: the default constants (`DefaultTimeout`, `DefaultReconnectWait`,
the two jitter values, `DefaultMaxReconnect`, `DefaultReconnectBufSize`, `DefaultPingInterval`,
`DefaultMaxPingOut`, `DefaultDrainTimeout`, `DefaultSubPendingMsgsLimit`, `DefaultSubPendingBytesLimit`,
`DefaultMaxChanLen` — every line re-pinned from the digest's v1.52.0 numbers), `doReconnect` (the
full-sweep sleep, `Reconnects++`, the reset on success, `CustomReconnectDelay` replacing jitter),
`selectNextServer` (the drop rule — settle it), the reconnect-buffer check (`ErrReconnectBufExceeded`),
`processPingTimer` (`pout > MaxPingsOut`), `processAuthError` (the same-server-twice rule,
`IgnoreAuthErrorAbort`), `drainConnection` (the two phases, the 5 s flush, **`Close()` when
RECONNECTING**), `Flush` (10 s), `ForceReconnect`, `StatusChanged`, `defaultErrHandler`;
`raw/nats-cli/reconnect-0.4.0.md`: the `>>>` lines, `MaxReconnects(-1)` + `IgnoreAuthErrorAbort` +
the 500 ms → 20 s table and its `jitter()`, the reply/request exit paths, the twice-registered error
handler. **Run** on `tools/lab/cluster.sh up 3` (`client-lifecycle-observed-v2.14.6.md`, script
beside it, nats.go and natscli versions in the header): (A) a `nats sub --trace` and a `nats pub
--count 1000 --sleep 10ms` publisher on n1; `cluster.sh` stops n1 mid-run — the client lines, the
reconnect target, how many of the 1000 arrived (the at-most-once gap measured), the publisher's
outcome; (B) the same with `nats-server --signal ldm=<pid>` on n1 — the `ldm` `INFO`, when the client
moved, whether anything was lost; (C) `nats reply --sleep 1s` under a `--count 50` request burst, Ctrl-C
→ the `Draining...` line and how many requests were answered after it (the "exits before the drain
completes" claim); (D) a stale-link test if the lab allows it (`iptables`/`pfctl` are not portable —
if a raw `nc` client that never answers `PING` is enough: time from the last `PONG` to the server's
`Stale Connection` and the log line, against `ping_interval` 2 m × `ping_max` 2, shortened in a test
config to `ping_interval: 5s` so the run takes seconds and the arithmetic is the point); (E) a
JetStream pull consumer mid-`nats consumer next --count 100` while its stream leader's node stops —
what the client prints, what is redelivered (the megaplan's "consumer leader mid-flow"). **Summaries**:
`s-docs-resilient-clients-connecting` (index + `connecting.md`),
`s-docs-resilient-clients-reconnection-and-events` (`reconnection.md`, `connection-events.md`,
`where-next.md` folded), `s-docs-resilient-clients-drain-and-shutdown`, `s-nats-go-connection` (the
extract), `s-nats-server-client-lifecycle-observed` (runs A–E; the natscli extract rides in
`s-nats-cli-core-commands` from step 1 or its own `s-nats-cli-reconnect`). **Pages**:
`wiki/concepts/client-connection-lifecycle.md` — the states, the pool and discovery (`connect_urls`,
`no_advertise`, the per-client opt-outs), the handshake, reconnect (sweep, wait, jitter, `MaxReconnect`
per server, first-connect retry, `CustomReconnectDelay`), the reconnect buffer (size, overflow error,
in-memory only, dropped by `Close()` and by a drain issued while reconnecting), keepalive (the third
unanswered ping, ~6 min; the ADR-40 disagreement stated), the six events and the closed-is-final rule,
readiness, force reconnect, drain vs close (phases, `DrainTimeout`, the 5 s flush, per-subscription
drain for queue rotation), flush as a receipt barrier, LDM as the client sees it (`ldm`, the peer-only
`connect_urls`), what the runs measured; `wiki/reference/client-defaults.md` — one table per client
of what the sources state (nats.go's column from the source at v1.53.1 with line numbers; natscli's
overrides; Python / Java / JS / Rust / C# columns from the docs, marked as the docs' word), *How this
was derived*. **Wiki fix**: `upgrade-a-cluster.md:430–432` and `s-adr-40-nats-connection.md:79,122`
(the four-minute reading → third ping, ~6 minutes, with the nats.go line). **Ripples**:
`how-clients-reach-a-cluster` (discovery opt-outs, the one-URL SPOF, LDM's `connect_urls`),
`evict-a-sick-server` and `run-nats-behind-a-proxy` (keepalive arithmetic), `upgrade-a-cluster` (the
client's LDM path, run B), `websocket` (`wss://`), `worker-pool` (per-subscription drain for rotation),
`consumer` / `ack-and-redelivery` (run E: what a pull consumer sees when the leader moves — pointer),
`nats-go` *What bites you* (`Drain()` returns at once, drain-while-reconnecting closes,
`ErrReconnectBufExceeded`, per-server `MaxReconnect`, `IgnoreAuthErrorAbort`, `ReconnectToServerCB`),
`nats-cli` (`--trace` lines, the backoff policy, `nats reply` exits before its drain, `nats server check
connection` thresholds and `--format`, `nats rtt`), `nats-c` (the calls the chapter names),
`defaults-and-limits` (a pointer row to `client-defaults`), `config-keys` (`no_advertise`,
`ping_interval` / `ping_max` from the client's side). **Docs issues**: ADR-40 `:222–225` (destination
ADR repo, with nats.go and the chapter as the two witnesses), `connection-events.md:244` vs
`tls-and-auth.md:206` ("twice" vs "same server twice"), the unnamed client at `reconnection.md:45`,
`drain-and-shutdown.md:168` (the CLI `--timeout` description). **Bank**: posed rows — what a client
sees when its server restarts or enters lame duck and what is lost (run A/B), how to stop a client
without losing in-flight work (drain), how long a client takes to notice a dead server — URL-scouted
first (rows 82 and 93 are adjacent). Index, log, lint.

## Step 4 — resilient clients, part 2: slow consumers, request/reply resilience, TLS and auth · status: done 2026-09-04 — s-docs-resilient-clients-slow-consumers-and-request-reply, s-docs-resilient-clients-tls-and-auth, s-docs-system-errors, s-nats-go-subscription, s-nats-server-client-errors, s-nats-server-client-faults-observed (six, not four: the two new extracts are cited directly by the gotcha pages, so each got its own summary); pages `slow-consumer-in-the-client` and `connection-closed-after-auth-error`; 19 ripples, unlanded 42 → 0; docs issues #96–#101 (#100 is the ★ **sweep** of `reference/system/errors.md` — 129 rows against the 58 `-ERR` call sites: 70 identifier rows and 37 close-reason rows accurate, **11 of 22** claimed wire errors not sent at all), no server issue; rows 180–182 added and answered (150 / 182, `own` 27); runs A1–A6, B1–B7, C1–C6 in five passes (`client-faults-observed-v2.14.6.md`, standalone servers; `client-faults-mintjwt.go` builds the operator/account/user chain with jwt v2.8.2 + nkeys v0.4.16 because no `nsc` is installed). **What the runs settled**: the client-side slow consumer never reaches the server (`slow_consumers` stayed 0 through four scenes, A1–A4) — `slow-consumers.md:102` is wrong (#96); the callback fires **per transition**, 13 times for 4,888 drops, and stderr gets 12 lines when no callback is set (A1/A2); `SetPendingLimits(0, …)` is `ErrInvalidArg`, negative is unlimited (A3); a **sync** subscription starts at **65,536**, not 500,000 (A4, #101); the server's two branches log differently and **neither sends an `-ERR`** — 556,002 bytes then EOF (A5/A6); `-ERR 'User Authentication Expired'` and `-ERR 'Account Authentication Expired'` captured on the wire (B1/B5, #99); the CLI printed **two lines in 45 s while being rejected eleven times** (B2); nats.go closes after **one** reconnect at 500 ms and **two** at its 2 s default, because `jwt/v2`'s one-second check makes a reconnect inside the expiry second get the *same* error again (B3/B6); `handshake_first: "auto"` and a duration **let a plain client connect** (0.093 s / 0.359 s) and log no startup warning, which the client chapter omits (C1–C4, #98). Lint 393 pages, 0 · 0, wanted 0, unverified 12, staleness 0 behind. **Carried to step 5**: the three wrong defaults on `reference/protocols/client.md`'s `-ERR` table (`Authorization Timeout` "1 second" vs `AUTH_TIMEOUT = 2s`, `max_control_line` "1024" vs 4096, `Slow Consumer` "10MB" vs `MAX_PENDING_SIZE` 64 MB) plus the five strings it has that `errors.md` does not and the two spellings of the payload error — all diffed in `s-docs-system-errors` and left for the wire-protocol read; `raw/nats-server-src/client-errors-v2.14.6.md` is already step 5's authority for the `-ERR` literals, so it needs no re-read. The nats.go request/inbox ranges are still unquoted (carried from step 2)

*Operation: ingest*, four summaries. **Extract**: `raw/nats-go-src/subscription-v1.53.1.md`
(`SetPendingLimits`, the slow-consumer transition `sc := !sub.sc`, `Dropped()`, `ErrSlowConsumer`,
`defaultErrHandler` and the release it arrived in — from the nats.go release bodies via `gh api`, cached
then quoted; `UserCredentials` re-read per attempt; `processAuthError`'s prefixes; `connectProto`'s
`no_responders`); `raw/nats-server-src/client-errors-v2.14.6.md`: `client.go:2495–2510` (`User
Authentication Expired`, `Account Authentication Expired`), `:2525–2535` (`Authorization Violation`),
`opts.go:5305–5330` + `const.go:114` (`handshake_first` and its 50 ms fallback), `errors.go` whole (the
`-ERR` literals — also step 5's authority). **Run** (`client-faults-observed-v2.14.6.md`): (A) a
`nats sub` with a slow handler is not something the CLI offers — use a short Go program (kept beside
the transcript) with `SetPendingLimits(100, -1)` under `nats pub --count 10000`: the stderr line
`defaultErrHandler` writes with no callback set, `Dropped()` after, and that the connection stayed up;
against it the server-side case: `write_deadline: 100ms` and a raw `nc` subscriber that never reads →
`Slow Consumer Detected` in the log, `slow_consumers` on `/varz`, the client's disconnect; (B) a user JWT
with a 30 s expiry (nsc on the lab's operator setup, or the standalone operator config from
`set-up-operator-mode`) → the `-ERR 'User Authentication Expired'` bytes over `nc`, the CLI's lines
through the abort, and `nats` (with `IgnoreAuthErrorAbort`) versus a Go program (closes after the
second) side by side; (C) `--tlsfirst` against a plaintext-`INFO` listener and a plain client against
`handshake_first: true` and `handshake_first: auto` (the fallback the chapter omits) — the exact
failure texts and the timing. **Summaries**: `s-docs-resilient-clients-slow-consumers-and-request-reply`
(`slow-consumers.md`, `request-reply-resilience.md`), `s-docs-resilient-clients-tls-and-auth`,
`s-docs-system-errors` (`reference/system/errors.md`, diffed against `reference/protocols/client.md`'s
table and against `errors.go` — the count of strings checked and wrong goes in the docs-issue row),
`s-nats-server-client-faults-observed` (runs A–C; the nats.go subscription extract rides in
`s-nats-go-connection` or its own). **Pages**: `wiki/gotchas/slow-consumer-in-the-client.md` (symptom:
`nats: slow consumer, messages dropped` on stderr or in the error callback, `Dropped()` climbing, the
subscription alive; against `slow-consumer-detected`, the server's; causes: handler latency × rate,
pending limits, one connection for a fast and a slow subscription; fixes: limits, a worker, a queue
group, a stream; prevention; explained by `client-connection-lifecycle`);
`wiki/gotchas/connection-closed-after-auth-error.md` (symptom: `User Authentication Expired` then
`Authorization Violation` on every reconnect then CLOSED; causes: JWT expiry, revoked user, rotated
creds not re-read, a creds file half-written mid-rotation; the per-client abort rules; fixes:
callbacks, re-read paths, rotate by draining onto a new connection). **Ripples**: `request-reply`
(retry policy per outcome, idempotency, the in-flight request lost on a drop), `nats-timeout` (the
no-default-timeout sentence, the CLI's exit codes), `slow-consumer-detected` (the client-side sibling
and the local/server table), `operator-mode` (`.creds` = JWT + seed, the nonce, expiry, the abort
rules), `tls-in-nats` (the client side of `handshake_first`, both-sides rule, the fallback),
`rotate-tls-certificates` (a pointer to creds rotation), `subject-permissions` (`Permissions
Violation` is recoverable; `CustomInboxPrefix`), `monitoring-endpoints` (`/varz` `slow_consumers`),
`nats-go`, `nats-cli`, `nats-c`, `nats-py`, `nats-java`, `nats-js`, `nats-rs`, `nats-net` (each
divergence the chapter states, as the docs' word). **Docs issues**: `slow-consumers.md:100` +
`where-next.md:99` (`defaultErrHandler`), `slow-consumers.md:102` (the server "raises" a local slow
consumer), `tls-and-auth.md:100` (the `handshake_first` fallback omitted, against
`learn/security/encryption.md:281`), `request-reply-resilience.md:154` (no-responders undated —
closed by the 2.2.0 body from step 2), the `errors.md` sweep result, `tls-and-auth.md:220` (`Account
Authentication Expired` unmentioned). **Bank**: posed rows for the two gotchas (URL-scouted; "slow
consumer" threads in the cache are mostly the server's — say so). Index, log, lint.

## Step 5 — the wire protocol: `reference/wire-protocol` · status: open

*Operation: ingest*, three summaries. **Extract** `raw/nats-server-src/wire-protocol-v2.14.6.md`:
`server.go` `type Info struct` (every json tag; which are client-, route-, gateway-, leaf-only),
`client.go` `type ClientOpts` / `clientOpts` and every `sendErr(` literal, `processPingTimer` (no ping
delay for ROUTER / GATEWAY / spoke LEAF versus the client's traffic proxy), `processConnect`'s wrong-port
branch (`ErrConnectedToRoutePort` / `ErrConnectedToWrongPort`); `route.go` `connectInfo`, the
`RouteProto*` constants, `:3073–3075` (the cluster-name rejection); `gateway.go` const block
(`gwReplyPrefix`, `oldGWReplyPrefix`, the `RS-` count before the interest-only switch, the
`gatewayCmd*` codes), `processGatewayAccountSub/Unsub`, `:1099–1105` (the wrong-gateway rejection);
`leafnode.go` const block (`$LDS.`, the two 30 s delays, the WebSocket path), `leafConnectInfo`,
`processLeafSub` (the origin-cluster token position); `parser.go` (which of `LMSG` / `HMSG` a leaf
sends for headers); `server.go:445–451` (the compression names). **Run** (`wire-protocol-observed-v2.14.6.md`):
(A) `nc` captures of the `INFO` line from a standalone server, a lab node (with `connect_urls`,
`cluster`), a node in LDM, a leaf listener (7422) and a route listener (6222 — the `nats-route://` `ip`
field); (B) `CONNECT {}` then `PING` — accepted or not (the "Required: true" columns); `CONNECT
{"verbose":true}` and a `PUB` → the `+OK`; (C) each `-ERR` provoked and its exact bytes:
`max_connections: 1` (`maximum connections exceeded` casing), `authorization { timeout: 1 }` and a
silent client, a 5000-byte control line, `max_payload` exceeded, `Attempted To Connect To Route Port`
by dialing 6222 with a client `CONNECT`, a subscription outside a permission set, `Invalid Subject`
(the `Recoverable` column verified: does the socket stay open); (D) two `nc` clients that never answer
`PING` with `ping_interval: 2s ping_max: 2` — `-ERR 'Stale Connection'` timing; (E) on the lab with
`-DV` on one node: a `RS+`, `RS-`, `RMSG` sequence for one subscribe/publish, quoted. **Summaries**:
`s-docs-protocol-client` (`reference/protocols.md` folded, `client.md`), `s-docs-protocols-internal`
(`route.md`, `gateway.md`, `leafnode.md` — one comparison table, the shared defects recorded once),
`s-nats-server-wire-protocol` (the extract and runs; or split observed). **Page**:
`wiki/reference/wire-protocol.md` — one line on scope; the `INFO` fields as the 2.14.6 server sends
them to a client, with the docs' rows marked where they differ (the duplicate `client_id`,
`tls_available`, `ip`); the `CONNECT` fields and what nats.go and the CLI send by default; the verb
table per connection kind (client / route / gateway / leaf) with the byte-counted forms; the `-ERR`
table — string as sent, the setting behind it, its default from `const.go`, recoverable or not as run;
the prefixes seen on the wire (`_INBOX.`, `$SYS.`, `$JS.`, `$SRV.`, `$LDS.`, `$GR.`, `$GNR.`) with a
pointer to `system-subjects`; PING/PONG per connection kind; the gateway interest modes and the
`gateway_cmd` sequence; the leaf loop-detection subject and the 30 s delays; *How this was derived*.
**Ripples**: `gateway` (`$GR.`, the `RS-` threshold, `A+`/`A-` semantics as settled), `leafnode`
(`$LDS.`, the delays, `LS+` token order, `lnoc`), `duplicate-messages-across-a-leafnode` (loop
detection), `supercluster-slows-when-a-remote-subscriber-joins` (the switch threshold), `tls-in-nats`
(`tls_available` corrected, `ssl_required` history), `auth-callout` / `operator-mode` (`nonce`,
`xkey`, `sig`), `subject-permissions` (the exact violation strings and the queue / reply variants),
`how-clients-reach-a-cluster` (`connect_urls` format, `protocol: 1`), `build-a-3-node-cluster`
(the `ip: nats-route://` gossip), `defaults-and-limits` (the `-ERR` column), `error-codes` (a pointer:
`-ERR` strings are not `err_code`s), `monitoring-endpoints` (`client_id` ↔ `cid`), `system-subjects`
(the prefix rows), `nats-server` entity, `nats-server-2.10` (route pooling and compression as protocol
additions, if the extract confirms the fields). **Docs issues**: the three wrong defaults on
`client.md`'s table (one row, the sweep count against `errors.md` from step 4), the missing ping
values, the duplicate `client_id`, `tls_available`, the three payload-error spellings across the four
pages, the invented gateway / leaf errors as the grep settles them, `leafnode.md:50` (`client_id` "for
compression negotiation"), `LDS` listed as a verb, the `LS+` token order if wrong, the compression
list missing `s2_best` / `on`. **Bank**: posed rows — what a given `-ERR` means and which setting is
behind it; how to smoke-test a port with `nc`; what `$GR.` / `$LDS.` subjects are; why a leaf reconnects
every 30 s (a gotcha candidate if the run shows a symptom worth a page — else the `leafnode` section
answers it). Index, log, lint.

## Step 6 — the services framework · status: open

*Operation: ingest*, five summaries. **Cache first**: the micro JSON schemas
(`schemas/micro/v1/{ping,info,stats}_response.json` from `nats-io/jsm.go` at v0.4.1, the tag
`raw/jsm-go/` already uses) into `raw/jsm-go/` — the collapsed `endpoints` and `metadata` sub-schemas
the docs' rendering lost. **Run** (`services-observed-v2.14.6.md`, on the lab): (A) `nats service
serve` twice (the demo service) — `nats service list`, `info`, `ping`, `stats`, `request`, and the raw
`nats request '$SRV.INFO' '' --replies 0` bodies; the `.echo` subject claim; (B) a `nats pub
'$SRV.PING' x` from a plain client — accepted or refused (the "reserved" claim; `$SRV` is not in
`server/*.go`); (C) `Nats-Service-Error` headers on a request to the demo service if it can produce
one, else recorded as not testable without a client program; (D) if step 2's run C was not done, do
it here. **Summaries**: `s-adr-32-service-api` (revisions 1–6, 2022-11-23 → 2025-02-17; the subjects,
schemas, name and version rules, the overridable `$SRV` prefix, immutable metadata, drain on stop),
`s-docs-services-framework` (`services.md`, `your-first-service.md`, `endpoints-and-groups.md`,
`where-next.md`), `s-docs-services-discovery-and-stats` (`discovery.md`, `observability.md`,
`reference/services.md` + the three response pages, the jsm.go schemas), `s-docs-services-scaling`
(`scaling.md`), `s-nats-server-services-observed`. **Pages**: `wiki/concepts/services-framework.md`
— what it is (a client-library convention over request/reply and queue groups; nothing to enable on
the server), name / id / version rules, the `{group}.{endpoint}` subject layout and the three-level
queue group with default `q`, the `$SRV.{PING,INFO,STATS}[.<name>[.<id>]]` tree and its broadcast
semantics, the three response types and the five counters with units, the two error headers and
"a service error is a delivered reply" (against the 503), scaling by instances, `Stop()` drains, the
readiness fact from step 2's run, permissions (`$SRV.>` for discovery, the endpoint subjects, across an
import — the ADR's prefix override), what an exporter can read (`nats service stats --json`; no
Prometheus bridge in the tree — say so), the CLI commands (`nats service list|info|ping|stats|request|serve`,
alias `micro`), which module each client ships (`micro` / `service` / `services`, from the docs and
the READMEs); `wiki/operations/services-on-core-nats.md` (`kind: pattern`, **row 134**) — the
problem (a service layer with no broker state), the design (endpoints on subjects, queue groups per
endpoint, timeouts sized from p99, no-responders as the deploy check, scatter-gather only outside a
queue group, idempotent handlers, drain on stop, `$SRV` for discovery and health), the configuration
(permissions per service account, `--inbox-prefix` per app, the export/import shape for
cross-account services with `allow_responses`), trade-offs (at-most-once; nothing survives an instance
crash; no backlog — pointers to `worker-pool` and step 7), when not. **Ripples**: `request-reply`,
`queue-groups`, `nats-timeout` (service error vs 503), `system-subjects` (a `$SRV` pointer row),
`subject-permissions` (`$SRV.>`), `cross-account-sharing` (services across an import, the prefix
override), `advisories` / `metrics` (service latency is the server's export feature, not the
framework's counters — one sentence each), `nats-cli` (`nats service`), `worker-pool` (the
non-durable sibling), each client entity (the module name). **Docs issues**: `reference/services.md:47`
("announce themselves"), `:30–51` (the capabilities the schemas lack), the missing configuration
reference (one row, the seven hand-offs), `where-next.md:38,40,42` (three promised chapters), `:34` vs
`scaling.md:164`, `scaling.md:150,272` (with step 2's run), `scaling.md:158` → `endpoints-and-groups.md:311`
(`WithEndpointQueueGroupDisabled` never named), `stats-response.md:51` ("stated"), the `$SRV`
reservation as a client convention (with run B). **Bank**: row 134 → `[[services-on-core-nats]]`;
scout the comment cache for the public form of 134 (`nats micro`, "service framework", "request reply
at scale") and replace `own` if found. Index, log, lint. The adr-toc rows 32, 47 and 4 gain their
summary links (3 stays open — a pointer in the `advisories` sentence, ingest only if step 6 needs it).

## Step 7 — `core-or-jetstream` · status: open

The design page for **row 133** (closes G7). **Scout first** (`inbox/scout-core-or-jetstream-2026-09-<DD>.md`,
5–10 candidates from the discussions comment cache — grep `local/scratch/gh-index/threads-2026-09-03.md`
for "core vs", "when to use jetstream", "request reply jetstream", "at-least-once request" — Synadia's
*Design Patterns* posts already in `raw/synadia/`, NATS by Example's core-vs-JetStream pages, ADR-22
(JetStream publish retries on no responders — the one ADR that sits on the boundary), and
`learn/core-nats/where-next.md` + `learn/jetstream/your-first-stream.md#why-a-stream` as the docs' own
answer); the user picks, or the plan takes the ★ ones. **Ingest** the picks (≤ 4 summaries) and write
`wiki/operations/core-or-jetstream.md` (`kind: pattern`): the problem (per subject, per flow); the
decision table (what the message is worth if lost · who must see it · replay · ordering across
publishers · fan-in with backpressure · request/reply latency), each row resting on a concept page
(`core-nats-delivery`, `stream`, `retention-policies`, `publishing`, `request-reply`,
`ack-and-redelivery`); the mixed design (core for request/reply and live state, JetStream for
events and work; the same subject space; a stream capturing a core subject with publishers unchanged;
`PubAck` as the only proof of storage); the configuration that implements it (one stream per event
family, `--subjects`, no stream for `_INBOX.>` or `$SRV.>`, the services layer on core with a stream
behind the endpoints that need it — pointer to `services-on-core-nats`); trade-offs (throughput and
latency numbers only where a source states them — `jetstream-sizing`, row 8's material stays with
phase H); when not (JetStream as a request/reply transport; core for anything with a retry budget).
**Ripples**: `core-nats-delivery`, `publishing`, `services-on-core-nats`, `worker-pool`,
`choosing-a-topology` (a pointer), `jetstream-sizing` (a pointer). **Bank**: row 133 →
`[[core-or-jetstream]]`, `own` replaced by a URL if the scout found the public form; phase G's G7 row
struck in the megaplan table. Index, log, lint.

## Step 8 — *What bites you* on the ten client entities · status: open

*Operation: consolidate* over the entity layer, no new docs. For each of `nats-c`, `nats-ex`,
`nats-java`, `nats-js`, `nats-pure-rb`, `nats-py`, `nats-rb`, `nats-rs`, `nats-swift`, `nats-zig`
(and a second pass on `nats-go`, `nats-net` for the items steps 1–6 produced): read the README in
`raw/github-repos/nats-io__<repo>.README.md` and the latest release in `…release.json`; `gh api` the
last ~10 release bodies of each repo into `local/scratch/releases/<repo>/` and quote the lines that
confirm a behaviour the docs stated (the 2 MB Python buffer, the JS 20 s timeout, the C# `MessageDropped`
channel, Java's `reportNoResponders()`, Rust's growing backoff and `flush()` semantics, the C client's
missing reconnect-error callback, nats.py's unchecked `publish` subject, nats.go's v1.48.0 subject
check) into `raw/github-repos/<repo>.releases-<DATE>.md` (verbatim, manifest row); the open issues a
`gh api` search on the repo returns for "slow consumer", "reconnect", "drain", "no responders"
(titles and numbers only, into the same file). **Write** `## What bites you` on each page in the
`nats-go` form: three to six bullets, each an operator-visible behaviour with its source (the
resilient-clients summary for the docs' word, the release line for the confirmed ones), the tier and
the module name for services, the deprecation line where one applies (`nats-rb` vs `nats-pure-rb` —
say which is current from the release dates); `verified-against` names the client's own release
where a release line is quoted. **Bank**: rows 156 (supercluster discovery from the client — answered
by `client-connection-lifecycle` / `how-clients-reach-a-cluster` if the sources say what a client
learns across gateways; else `no-public-answer` after a cache grep), 138 (if step 2 left it), 148
(`TCP_NODELAY` — one grep of `net.go` / `client.go` at 2.14.6 for `SetNoDelay`, and nats.go's dialer;
a `defaults-and-limits` row), 87 (the Orbit module per language — re-check against the READMEs).
Index (the entity lines gain the section's hook), log, lint.

## Step 9 — close · status: open

Measure every *done when* clause and write the numbers: the bank cells (25, 133, 134, and every row the
new pages name), the twelve `## What bites you` sections, the coverage line in the log (the seven
trees with their counts and the fold list), the index entries, `check-staleness.py` (the client
authorities are outside its six versioned things — say so), `python3 tools/lint.py` 0 · 0, wanted 0;
the plan's result line at the top of this file; `local/scratch/INDEX.md` pruned (the digests deleted,
the nats.go and natscli sources kept for the life of their pins, the run transcripts kept as
originals); phase F's `status:` / `next:` in `local/megaplan.md` and the G7 row struck; the fourteen
*Where the wiki records* rows in `inbox/docs-issues.md` for the phase's issues; a `wiki/log.md` entry
with the before / after table. Propose phase G's first plan (G1, stream and subject design — `subjects-and-wildcards`
from step 1 is its foundation) in the megaplan's `next:` line.
