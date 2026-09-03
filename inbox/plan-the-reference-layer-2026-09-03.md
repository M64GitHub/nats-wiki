# Plan — the reference layer: three lookup tables (proposed 2026-09-03)

Say **`start the plan inbox/plan-the-reference-layer-2026-09-03.md`** to work this file — name it
explicitly, a bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation:
plan* says how: one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-03, commit `bf6db19`).** 317 pages; question bank 160 rows, 121
answered, 39 open (15 asked, 24 posed `design`); wanted 0; `(unverified)` 12; citation drift 0,
unlanded ripples 0; staleness 0 behind nats-server 2.14.6; docs issues 64 (none filed), server
issues 3. Binary `nats-server v2.14.6`, `nats` CLI 0.4.0, Go 1.27 on the path, neither
`prometheus-nats-exporter` nor `nats-surveyor` installed. `wiki/reference/` holds six pages
(`advisories`, `config-keys`, `defaults-and-limits`, `error-codes`, `js-api-subjects`,
`monitoring-endpoints`). Of the 23 pages under `raw/nats-docs/reference/system/` one has a summary
(`raftz`); of the 59 under `reference/jetstream/`, three (`stream/create`, `consumer/create`,
`api/headers`).

**Why this plan.** Phase E of the maintainer's programme. An agent answering "which series tells me
a consumer is falling behind", "what does the system account answer on", or "can I change this
field after the stream exists" needs a table, not a paragraph spread over four concept pages. The
megaplan names three: `reference/metrics`, `reference/system-subjects`,
`reference/stream-and-consumer-config`, each with *How this was derived*.

**What the read found (2026-09-03, both trees end to end).** The two trees are generated schema
listings — field, type, one line — with no prose about behaviour, and they carry defects that the
plan must record and that the wiki has partly inherited:

1. `reference/system/monitor.md` presents fifteen "HTTP monitoring endpoints" reachable at
   `http://localhost:8222/<z>`. The server's HTTP mux (`server.go:3030–3044`, `3134–3162` at v2.14.6)
   registers `/`, `/varz`, `/connz`, `/routez`, `/gatewayz`, `/leafz`, `/subsz` (alias
   `/subscriptionsz`), `/stacksz`, `/accountz`, `/accstatz`, `/jsz`, `/healthz`, `/ipqueuesz`,
   `/raftz` and `/debug/vars` — **`statsz`, `idz` and `profilez` are not HTTP endpoints**; they exist
   only as `$SYS.REQ.SERVER.PING.<Z>` requests (`events.go:1268–1315`), and `/stacksz` and
   `/debug/vars` are documented nowhere. **`wiki/reference/monitoring-endpoints.md` copied the docs'
   list** and prints `/statsz`, `/profilez`, `/idz` as endpoints: a wiki bug, fixed in step 1 after
   the run that proves it.
2. `reference/system/advisory.md` and `advisory/account-connections.md` give the subject
   `$SYS.ACCOUNT.{account}.CONNECTIONS` and describe it as fired "when account connection limits are
   reached"; the schema on the same page says "Regular advisory published with account states". The
   server publishes `$SYS.ACCOUNT.<acc>.SERVER.CONNS` (`events.go:58`) and, for compatibility,
   `$SYS.SERVER.ACCOUNT.<acc>.CONNS` (`events.go:59`); `wiki/reference/advisories.md` names only the
   old form. A run settles which arrive and when.
3. `reference/jetstream/api/stream/names.md` documents the response array as `consumers string[]`;
   the server writes `streams` (`jetstream_api.go:464–468`, `JSApiStreamNamesResponse`).
4. `reference/system/monitor/varz.md` annotates `max_connections` — an integer count — with
   "nanoseconds depicting a duration in time"; `advisory/nak.md` and `advisory/terminated.md` type
   `consumer_seq` as a **string**; `advisory/consumer-pause.md` describes `consumer` as "the Consumer
   that elected a new leader" and `consumer-group-pinned.md` describes `group` as "the group that
   unpinned a client"; `api-limit-reached.md` gives a string field a numeric minimum;
   `api/stream/restore.md` labels its request "A response from…". Docs issues #1 and #2 already
   record two wrong advisory subjects on this tree, so a sibling sweep against
   `server/jetstream_events.go` is due (step 1).
5. `reference/jetstream/metric.md` says metrics "can be enabled or disabled at the stream or consumer
   level"; the only switch the server has is the consumer's `sample_freq`. `reference/system/metric.md`
   gives service latency a fixed subject, `$SYS.SERVER.METRIC.SERVICE.LATENCY`; the server publishes
   it on the subject the export's `latency {}` block names. Both checked by running (step 1).
6. `api/consumer/create.md` never expands `ConsumerConfig` (docs issue #4, recorded 2026-08-31), so
   the consumer half of page 3 rests on the server's struct (`consumer.go:88–141`), its defaults and
   validation (`consumer.go:573–593`, `720–1000`), its update rule (`checkNewConsumerConfig`,
   `consumer.go:2481–2549`) and the jsm.go JSON schema the docs were generated from. The stream half
   has the schema on the page and the server's update rule at `stream.go:2300–2370`.
7. `api/consumer/get-next.md` caps `batch` at 256; the server's constant, if any, is checked in step 2.

**Scope decisions, stated once.** (1) **`$JS.EVENT.*` stays on `advisories`; the new
`system-subjects` page owns every `$SYS.*` subject** — requests and events. The `$SYS` table on
`js-api-subjects` (seven rows) moves there and leaves a pointer and its two permission facts; the
*System events* section of `advisories` keeps the three documented events, corrected, and points
across. Enrich, never duplicate. (2) **The unit of ingestion for a generated tree is the tree, not
the page.** One summary for the system monitor tree (16 pages), one for the system advisories and
metrics (6), one for the JetStream API index and its 25 unsummarised operation pages, one for the
JetStream advisories and metric (24) — each cross-checked against the server source and the runs.
The four pages that already have summaries keep them. (3) **The server at v2.14.6 is the authority
for page 3 and page 2; the exporter at its own tag, v0.20.2, for page 1** (the tag the entity
already cites); nats-surveyor at v0.9.11 if it installs in one command, otherwise its README only.
(4) Every observed run goes through `tools/lab/cluster.sh` and lands in `raw/` with its script,
as phases A, B and D did. (5) Nothing from the two `errors.md` pages is re-ingested — `error-codes`
already covers the JetStream table and the system error strings belong to phase F's client side.

**Done when** (measured): `wiki/reference/system-subjects.md`, `stream-and-consumer-config.md` and
`metrics.md` exist, are in `wiki/index.md`, carry `verified-against: nats-server 2.14.6` (the
exporter's tag on page 1 as well) and a *How this was derived* section naming file, line and run;
`monitoring-endpoints` lists the HTTP endpoints the mux registers and nothing else; rows **82, 139,
140, 146** are filled and rows 15–17, 21, 22, 28, 57, 59, 71, 83–85, 88, 116, 151, 160 name the page
that now answers them; row 129 is filled if page 1 states the minimum set with series and versions,
else its `status:` says it stays with phase G6; every contradiction in *What the read found* is in
`inbox/docs-issues.md`, verified with file, line and run, with the advisory sweep's count; the
docs coverage for `reference/system` and `reference/jetstream` is complete (every page read into a
summary or named as skipped); `python3 tools/lint.py` reports **0 · 0**, wanted 0.

---

## Step 1 — `reference/system-subjects`, and the endpoint correction · status: done 2026-09-03 — the extract (25 ranges + `jetstream_events.go` whole), the runs (eight, lab + a two-account standalone with a latency export and a leaf), eight summaries, the page, the `monitoring-endpoints` correction (three 404s out, `/stacksz` `/debug/vars` `/subscriptionsz` in, the `/expvarz` note fixed), eleven pages rippled; docs issues **#65–#72**, server issues **SI-4, SI-5**; bank rows 161–163 added and answered, 54 and 82 filled (124 / 163); lint 326 pages, 0 · 0, wanted 0

*Operation: ingest*, six summaries. **Cache first**: `server/jetstream_events.go` and
`server/accounts.go` at v2.14.6 into `local/scratch/src/v2.14.6/` (`events.go`, `monitor.go`,
`server.go` are there), INDEX row. **Extract** `raw/nats-server-src/system-subjects-v2.14.6.md`
(verbatim line ranges, the `constants-v2.14.6.md` form): the subject constants `events.go:43–96`;
the `PING.<Z>` handler table `1268–1340` and the per-account table around `1362–1400`
(`$SYS.REQ.ACCOUNT.<acc>.<CONNZ|SUBSZ|LEAFZ|JSZ|INFO|CONNS|STATZ>`, and the `PING.CONNZ` import at
`2385–2387`); the request and event structs (`EventFilterOptions`, `StatszEventOptions`,
`ConnectEventMsg`, `DisconnectEventMsg`, `AccountNumConns`, `ServerStatsMsg`, `AuthErrorEventMsg`,
the `ServerInfo` envelope); `server.go:3030–3044` and `3134–3162` (the HTTP mux); the advisory type
and subject constants and structs in `jetstream_events.go` (the sweep's authority); the latency
publish in `accounts.go`. **Run** on `tools/lab/cluster.sh up 3` (binary v2.14.6, checked by the
script), recorded in `raw/nats-server-src/system-subjects-observed-v2.14.6.md` with
`system-subjects-run.sh` beside it: (a) `curl -o /dev/null -w '%{http_code}'` for `/statsz`, `/idz`,
`/profilez`, `/stacksz`, `/debug/vars`, `/subscriptionsz` on one node; (b) `nats server request` (or
`nats req '$SYS.REQ.SERVER.PING.<Z>' ''` with the system user) for `STATSZ`, `IDZ`, `PROFILEZ` and
one HTTP twin (`VARZ`) — the bodies, trimmed; (c) `nats sub '$SYS.>'` on the system account while:
a client connects and disconnects (which of `CONNECT`, `DISCONNECT`, `SERVER.CONNS`,
`SERVER.ACCOUNT.<acc>.CONNS` arrive, their bodies, and whether `CONNS` is periodic or
limit-triggered — leave the subscriber running two minutes with nothing happening); a client fails
authentication (`CLIENT.AUTH.ERR`); one node is sent `nats-server --signal ldm=<pid>` (`LAMEDUCK`)
and stopped (`SHUTDOWN`); a config reload is requested by message on
`$SYS.REQ.SERVER.<id>.RELOAD`; a service export with `latency { sampling: 100%, subject: … }` is
called once (which subject the `io.nats.server.metric.v1.service_latency` event appears on).
**Summaries**: `s-nats-server-system-subjects` (the extract), `s-nats-server-system-subjects-observed`
(the runs), `s-docs-system-monitor-reference` (`reference/system.md`, `monitor.md` and the 14
monitor pages without a summary — the request and response field lists, and what the pages get
wrong), `s-docs-system-advisories-and-metrics` (`advisory.md` + 3, `metric.md` + 1),
`s-docs-jetstream-api-index` (`jetstream.md`, `api.md`, the four index tables and the 25 operation
pages — subject, request fields, response fields, the *System Account* column; `names.md`'s
`consumers`; `stream/info`'s `subjects_filter`, `msg-get`'s batch and `multi_last`, `purge`'s three
modes, `snapshot`'s `chunk_size` / `window_size` bounds, `get-next`'s `min_pending` /
`min_ack_pending` / `priority`), `s-docs-jetstream-advisories-reference` (`advisory.md` + 22,
`metric.md` + `consumer-ack.md`, **swept field by field against `jetstream_events.go`** — the count
of pages checked and pages wrong goes into the docs-issue row). **Page**
`wiki/reference/system-subjects.md`: one line on scope (every `$SYS` subject the v2.14.6 server
publishes on or answers; `$JS.API` is on [[js-api-subjects]], `$JS.EVENT` on [[advisories]]); the
tables — server requests (`$SYS.REQ.SERVER.PING.<Z>` and `$SYS.REQ.SERVER.<id>.<Z>` for the fifteen
`Z` plus `RELOAD`, `KICK`, `LDM`: request body, response envelope, the HTTP twin or **request-only**,
and the two HTTP paths with no request form), account requests (`$SYS.REQ.ACCOUNT.<acc>.<Z>`,
`$SYS.REQ.ACCOUNT.PING.<Z>` and what an ordinary account reaches through the built-in import),
claims and user requests (moved from `js-api-subjects`), events (`$SYS.ACCOUNT.<acc>.CONNECT` /
`DISCONNECT` / `SERVER.CONNS` / `LEAFNODE.CONNECT`, `$SYS.SERVER.<id>.STATSZ` / `LAMEDUCK` /
`SHUTDOWN` / `CLIENT.AUTH.ERR` / `OCSP.*`, `$SYS.ACCOUNT.CLIENT.AUTH.ERR`, `$SYS.LATENCY.M2.<acc>`,
the old `CONNS` form — schema type, body fields, and the observed body), the inbox and debug forms
(`$SYS._INBOX.<id>.<x>`, `$SYS._INBOX_.<x>`, `$SYS.DEBUG.SUBSCRIBERS`); a *Permissions* section —
what a monitoring user needs, what a system-account narrowing breaks; *How this was derived*;
*Version notes* from the four `s-relnotes-*` summaries (2.10's `RELOAD`/`KICK`/`LDM`/`IDZ`, 2.12's
`$G` connect events, whatever 2.11 and 2.14 added); Related; Sources. **Ripple**:
`monitoring-endpoints` (the endpoint table rebuilt from the mux — `/statsz`, `/profilez`, `/idz` out,
`/stacksz`, `/debug/vars`, `/subscriptionsz` in, a *request-only* note, the docs-error section
extended, `verified-on` bumped), `advisories` (*System events* corrected and pointed across; the
sweep's findings in *A docs error worth knowing*), `js-api-subjects` (the `$SYS` table → pointer),
`account`, `reload-server-config` (the observed `RELOAD` run), `evict-a-sick-server`
(`KICK`/`LDM` → the reference), `nats-cli` (cheat sheet: `nats server request <z>`),
`nats-surveyor` and `prometheus-nats-exporter` (which surface each reads: `PING.STATSZ`/`JSZ` versus
HTTP), `slow-consumer-detected` (`SERVER.CONNS` carries `slow_consumers`), `install-nats-server` if it
names the endpoints. **Docs issues**, verified by the extract and the run: the three non-endpoints
and two undocumented paths (`wrong-value`, `reference/system/monitor.md` + the three pages); the
`CONNECTIONS` subject and the limit-versus-periodic contradiction; `varz.md`'s `max_connections`
annotation; the advisory-schema sweep (one row per kind: wrong types, copy-paste descriptions —
with the counts); `metric.md`'s stream-level toggle; the service-latency subject if the run
contradicts it. **Bank**: row 82 and 54 gain the page; a posed row — "Which `$SYS` subjects exist,
which are request-only with no HTTP form, and what may a monitoring user be granted?" — after a
search of `local/scratch/gh-index/threads-2026-09-03.md` for a URL (`nats server request`,
`STATSZ`, `$SYS.REQ`), `own` if none. Index, log, lint. Report the endpoint list the run produced,
the `CONNS` finding, the sweep's counts, and lint before and after.

## Step 2 — `reference/stream-and-consumer-config` · status: done 2026-09-03 — the extract (27 ranges), three passes of raw API updates on the lab (`config-mutability-observed-v2.14.6.md`), `raw/jsm-go/` and `raw/nats-cli/` created, gh#3944 fetched, eight summaries (ADRs 9, 33, 34 marked), the page (38 + 35 fields, every refusal string), 18 pages rippled; docs issues **#73–#75**; row 140 settled from the source (the leader's clock), row 146 filled, row 164 added (own); the `(unverified)` batch limits on `defaults-and-limits` verified from `stream.go:446–455`; `batch: 300` served in full (the docs' 256 is not a server limit). Bank 127 / 164; lint 335 pages, 0 · 0

*Operation: ingest*, eight summaries at most. **Extract** `raw/nats-server-src/stream-consumer-config-v2.14.6.md`:
`stream.go` — `StreamConfig` (the struct), `StreamConsumerLimits` (168–171),
`SubjectTransformConfig` (174–177), `RePublish` (180–184), `Placement`, `StreamSource` (406–417),
`ExternalStream` (426–429), `StreamConsumerSource`; the defaults `checkStreamCfg` applies
(`1640–1760`: the 2-minute duplicate window, `-1` limits, `num_replicas` 1) and the validation
strings (`1664–2276`); the update rule (`2300–2370`: storage, retention to/from `workqueue`, unseal,
`deny_delete`, `deny_purge`, mirror, `allow_msg_ttl` one-way, `allow_msg_counter`,
`allow_msg_schedules` one-way, `persist_mode`); `consumer.go` — `ConsumerConfig` (88–141), the
defaults (`573–593`), the validation (`720–1000`), `checkNewConsumerConfig` (2481–2549) and what
`updateConfig` (2551–) actually applies; `jetstream.go` — `JSLimitOpts` and `JetStreamAccountLimits`
(the server, account and stream limits that clamp a consumer: `max_ack_pending`,
`max_request_batch`, `max_ha_assets`, `duplicate_window`, `consumer_limits`); any `256` in the
get-next path. **Fetch** into `raw/jsm-go/` (new collection, manifest row) the two JSON schemas the
docs were generated from, at jsm.go **v0.4.1** (the latest release in `raw/github-repos/`):
`schemas/jetstream/api/v1/stream_configuration.json` and `consumer_configuration.json` — the field
descriptions the consumer page never rendered. **Capture** `nats stream add --help`, `nats stream
edit --help`, `nats consumer add --help`, `nats consumer edit --help` at CLI 0.4.0 into
`raw/nats-cli/help-0.4.0.md` (new collection, manifest row) for the flag column. **Fetch** gh#3944
(row 146) with `tools/fetch-discussion.py 3944 --out raw/gh-discussions`. **Run** on the lab,
recorded in `raw/nats-server-src/config-mutability-observed-v2.14.6.md` with its script: `nats
stream edit` / `nats req '$JS.API.STREAM.UPDATE.<s>'` attempts against every fixed and one-way field
(the exact refusal strings on 2.14.6, and which pass silently); `nats consumer edit` / `$JS.API.CONSUMER.CREATE`
with `action: update` for each of the twelve consumer refusals (deliver policy, storage, start seq,
start time, ack policy, replay, heartbeat, flow control, pull↔push, max waiting, and the
`backoff`/`max_deliver` rule); `nats req '$JS.API.STREAM.NAMES' '{}'` (proves `streams`);
`$JS.API.STREAM.INFO.<s>` with `subjects_filter` (row 146); a `MSG.NEXT` with `batch: 300`
(the docs' 256). Also settle **row 140 from the source**: where `processJetStreamMsg` stamps the
message time (the leader's clock, before the proposal) and whether followers reuse it — `stream.go`,
with line numbers; a run is not needed. **Summaries**: `s-nats-server-stream-consumer-config`,
`s-nats-server-config-mutability-observed`, `s-jsm-go-config-schemas`, `s-nats-cli-help-0.4.0`,
`s-gh-3944-subjects-in-a-stream`, and the three ADRs the page needs and the wiki has not read —
`s-adr-33-metadata`, `s-adr-34-multiple-filters`, `s-adr-9-idle-heartbeats` (mark them in
`inbox/adr-toc.md`). **Page** `wiki/reference/stream-and-consumer-config.md`: one line on scope
(every field of `StreamConfig` and `ConsumerConfig` at v2.14.6; defaults for the whole server are on
[[defaults-and-limits]], the server config keys on [[config-keys]]); **the stream table** — field ·
type · default the server applies (schema default beside it where the two differ) · since (the
minor a `s-relnotes-*` or ADR summary attributes, `2.10` = present at the floor) · after creation
(*free* / **fixed** / *one-way* / *conditional*, with the refusal string) · CLI flag · the validation
rule that bites; sub-tables for `mirror` and `sources` (`StreamSource` and `external`), `placement`,
`republish`, `subject_transform`, `consumer_limits`; **the consumer table** likewise, with the clamp
column (server `jetstream { limits }`, account `max_ack_pending`, stream `consumer_limits`) and
`checkNewConsumerConfig` for mutability; *What the docs do not render*; *How this was derived*;
*Version notes*; Related; Sources. **Ripple**: `stream` (*What you cannot change later* completed
and cited — `allow_msg_counter`, `persist_mode`, the one-way `allow_msg_ttl` and
`allow_msg_schedules`, the name check; a *Which clock stamps a message* paragraph for row 140),
`consumer` (*What configures it* → the flag column and a mutability pointer), `defaults-and-limits`
(the two configuration sections keep their defaults and point across), `config-keys`
(`jetstream { limits { … } }`), `message-ttl`, `message-scheduling`, `publishing`, `mirrors-and-sources`,
`subject-transforms`, `direct-get`, `priority-groups`, `retention-policies`, `replicas`,
`stream-placement`, `key-value` (`discard_new_per_subject`), `js-api-subjects` (`subjects_filter`,
the `names.md` defect), `nats-cli` (the help capture), `jsm-go` (the schema files), the four release
entities where a field's arrival is named. **Docs issues**: `names.md` (`consumers` for `streams`);
`get-next`'s 256 if the run disproves it; `restore.md`'s label (`enhancement`); any schema default
the server contradicts (the extract will show). **Bank**: rows 140 and 146 filled; 15, 16, 17, 21,
28, 71, 88, 116, 151, 160 gain the page; a posed row — "Which stream and consumer fields can be
changed after creation, which are fixed, and which are one-way?" — with a URL from the threads cache
if one exists (`storage type`, `cannot change`, `stream edit`), `own` otherwise. ADR rows 9, 33, 34
marked ingested. Index, log, lint. Report the fixed/one-way/free counts for both tables, and what the
`batch: 300` run returned.

## Step 3 — `reference/metrics` · status: open

*Operation: ingest*, seven summaries at most. **Install** the exporter at the entity's tag:
`go install github.com/nats-io/prometheus-nats-exporter@v0.20.2`, and try
`go install github.com/nats-io/nats-surveyor@v0.9.11` once — if either fails, say so in the
`status:` line and go on with the README. **Cache** the exporter's `collector/` package at v0.20.2
(list it with `gh api repos/nats-io/prometheus-nats-exporter/contents/collector?ref=v0.20.2`, fetch
each `.go` file that is not a test) into `local/scratch/src/prometheus-nats-exporter-v0.20.2/`;
**extract** the name-building code (the `<prefix>_<endpoint>_<field>` rule, the default prefixes,
what `-prefix` replaces, how the `jsz` collector names stream and consumer series and their labels)
into `raw/prometheus-nats-exporter-src/collector-v0.20.2.md` (new collection, manifest row). **Run**
against the lab (three nodes, one file stream `R3` with a pull consumer that holds ten messages
unacked and has redelivered some — `redelivery-runG.sh` already builds that shape, one route and
`/leafz` empty) with every collector on, `-jsz=all`, once with `-prefix nats` and once without;
capture `curl -s :7777/metrics` verbatim into
`raw/prometheus-nats-exporter-src/metrics-observed-v0.20.2.md` — the `# HELP` / `# TYPE` lines are
the metric list, with the sample lines for the stream and consumer series; if surveyor installed,
the same against `--jsz all --accounts --raftz` into `raw/nats-surveyor-src/metrics-observed-v0.9.11.md`.
**Fetch** the threads the page's rows rest on and the wiki has not read: gh#2818 (row 139),
gh#3857 (83), gh#6182 (57, 129), gh#5128 (153, for `ha_assets`). **Summaries**:
`s-prometheus-nats-exporter-collector`, `s-prometheus-nats-exporter-metrics-observed`,
`s-nats-surveyor-metrics-observed` (if run), `s-gh-2818-counters-exact-or-sampled`,
`s-gh-3857-consumer-pending-series`, `s-gh-6182-what-to-alert-on`, `s-gh-5128-ha-assets`. **Page**
`wiki/reference/metrics.md`: one line on scope (the series `prometheus-nats-exporter` v0.20.2 emits
from a v2.14.6 server, mapped to the endpoint field each is read from; surveyor's names where they
differ; not the dashboards); the naming rule and the `-prefix` fact; one table per collector —
series · type (gauge/counter) · endpoint field · labels · since (when the field arrived, from
[[monitoring-endpoints]]'s version sections); **the series behind the four alerts** on
[[advisories]] (quorum, lag, disk, consumer pending and redeliveries) and what has **no series**
(advisories, `$SYS` events, per-message latency); *counters are exact* (row 139: the server
increments them atomically, the exporter re-reads them each scrape, `nats-top` reads `/varz` —
from the source and the thread); `ha_assets` and `max_ha_assets` (row 153) as far as the field and
the limit go; *How this was derived*; *Version notes*; Related; Sources. **Ripple**:
`prometheus-nats-exporter` (its series section → a pointer; a *What bites you* section from the run:
the default prefix, the unscoped `-jsz=all`), `nats-surveyor`, `monitoring-endpoints` (*From an
endpoint to a time series* → cite and point), `advisories` (*The four to alert on first* → the series
names), `slow-consumer-detected`, `consumer`, `worker-pool`, `jetstream-out-of-disk`,
`stream-has-high-message-lag`, `nats-helm-charts` (the chart's exporter sidecar flags, if the values
file in `raw/github-repos/` states them), `nats-top`, `jetstream-sizing` (`ha_assets`). **Docs
issues**: whatever the exporter's README or `learn/monitoring/prometheus-and-dashboards.md` states
that the run contradicts (metric names, the prefix). **Bank**: rows 139 filled; 22, 57, 59, 60, 83,
84, 85, 153 gain the page; **row 129**: filled by this page only if it states the minimum alert set
with a series and a version for each — otherwise the `status:` line says it stays with G6's
`production-alerting`. Index, log, lint. Report the series count per collector, whether surveyor
ran, and the row-129 decision.

## Step 4 — close the phase · status: open

Index (the Reference group gains three lines), `inbox/docs-issues.md`'s *Where the wiki records each
of these* rows for every issue the plan added, the bank cells re-checked against *Done when*,
`python3 tools/check-staleness.py` (0 behind 2.14.6), `python3 tools/lint.py` (0 · 0, wanted 0),
the docs coverage for the two trees stated in `wiki/log.md` (pages read / summarised / skipped with
reason), the result line at the top of this file, `local/megaplan.md`'s phase E `status:` / `next:` /
session-log row and the overlay's *now working* line, `local/scratch/INDEX.md` pruned. Propose
phase F's first plan.
