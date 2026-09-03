---
title: "docs.nats.io — JetStream advisory and metric reference (24 pages), swept against the server"
type: summary
area: [monitoring, jetstream]
source-url: https://docs.nats.io/reference/jetstream/advisory.md
source-path: raw/nats-docs/reference/jetstream/advisory.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the jsm.go event JSON schemas
article: "reference/jetstream/advisory.md and its 22 pages; reference/jetstream/metric.md and metric/consumer-ack.md"
date: 2026-08-31          # the pages are undated; this is the fetch date
version: "2.14"
tags: [advisories, "$JS.EVENT.ADVISORY", "$JS.EVENT.METRIC", generated, sweep]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs.nats.io — JetStream advisory and metric reference, swept against the server

The 24 generated pages read together for phase E step 1 and **checked field by field against
`server/jetstream_events.go` at v2.14.6** (quoted whole in `raw/nats-server-src/system-subjects-v2.14.6.md`,
[[s-nats-server-system-subjects]]). Docs issues #1–#3 already record three wrong *subjects* on this
tree; this pass is about the *bodies*.

## Key claims

- `advisory.md` tables 21 subjects under `$JS.EVENT.ADVISORY.` — `API`, `API.LIMIT_REACHED.{account}`,
  `CONSUMER.CREATED` / `DELETED`, `CONSUMER.GROUP_PINNED` / `GROUP_UNPINNED` (wrong, #2 #3),
  `CONSUMER.LEADER_ELECTED`, `CONSUMER.PAUSE`, `CONSUMER.QUORUM_LOST`, `DOMAIN.LEADER_ELECTED.{domain}`,
  `CONSUMER.MAX_DELIVERIES`, `CONSUMER.MSG_NAK` (wrong, #1), `CONSUMER.MSG_TERMINATED`,
  `STREAM.RESTORE_COMPLETE` / `RESTORE_CREATE`, `SERVER.OUT_OF_STORAGE`, `SERVER.REMOVED`,
  `STREAM.SNAPSHOT_COMPLETE` / `SNAPSHOT_CREATE`, `STREAM.CREATED` / `DELETED` / `UPDATED`,
  `STREAM.LEADER_ELECTED`, `STREAM.QUORUM_LOST` — and, on its own page only,
  `STREAM.BATCH_ABANDONED.{stream}`. `metric.md`: `$JS.EVENT.METRIC.CONSUMER.ACK.{stream}.{consumer}`,
  and the claim that metrics "can be enabled or disabled at the stream or consumer level".
- Every page: `type` (the `io.nats.jetstream.advisory.v1.*` string), `id`, `timestamp`, then the
  event's fields with type and one line.

## The sweep — 24 pages against `jetstream_events.go`

| page | server struct | finding |
|---|---|---|
| `nak.md`, `terminated.md` | `JSConsumerDeliveryNakAdvisory`, `…TerminatedAdvisory` | **`consumer_seq` typed `string`; the server sends `uint64`** (`ConsumerSeq uint64`) |
| `snapshot-create.md` | `JSSnapshotCreateAdvisory` | **documents `blocks` and `block_size`; the server sends `state` (a `StreamState`) and `domain`** — neither documented field exists |
| `stream-action.md` | `JSStreamActionAdvisory` | **documents `template` ("The Stream Template that manages the Stream"); no such field** — the struct is `stream`, `action`, `domain` |
| `stream-batch-abandoned.md` | `JSStreamBatchAbandonedAdvisory` | `reason` allowed values `timeout`, `large`, `incomplete`; the server also sends **`unsupported`** (`BatchRequirementsNotMet`) |
| `consumer-pause.md` | `JSConsumerPauseAdvisory` | `consumer` described as "the Consumer that elected a new leader" (copied from the leader page) |
| `consumer-group-pinned.md` | `JSConsumerGroupPinnedAdvisory` | `group` described as "The group that unpinned a client" (copied from the unpinned page) |
| `api-limit-reached.md`, `nak.md` | — | `domain`, a string, given "Minimum: 1" |
| `api-audit.md`, `consumer-action.md`, `max-deliver.md`, `consumer-leader-elected.md`, `consumer-quorum-lost.md`, `stream-leader-elected.md`, `stream-quorum-lost.md`, `restore-create.md`, `restore-complete.md`, `snapshot-complete.md`, `server-out-of-space.md`, `consumer-ack.md` | the matching structs | **`domain` (and, for the four leader/quorum pages, `account`) missing** — every struct carries `Domain string json:"domain,omitempty"`, the leader/quorum ones `Account` too |
| `api-limit-reached.md`, `consumer-group-unpinned.md`, `consumer-leader-elected.md` (fields), `domain-leader-elected.md`, `server-removed.md`, `consumer-pause.md` (fields), `stream-leader-elected.md` (fields), `stream-quorum-lost.md` (fields), `consumer-quorum-lost.md` (fields), `max-deliver.md` (fields), `restore-*.md` (fields), `snapshot-complete.md` (fields), `server-out-of-space.md` (fields) | | fields and types agree apart from the omissions above |

**Count: 24 pages checked; 4 with a wrong type or a nonexistent field (`nak`, `terminated`,
`snapshot-create`, `stream-action`), 1 with a missing enum value, 2 with a copy-pasted description,
2 with a bogus numeric bound on a string, 12 missing `domain` and 4 of those also `account`; 3 pages
(`consumer-group-unpinned`, `domain-leader-elected`, `server-removed`) fully agree.** The subjects
are not re-checked here (#1–#3 hold; the `MSG_NAKED` and `MAX_DELIVERIES` subjects were seen on the
wire, [[s-nats-server-monitoring-observed]]).

**`metric.md`'s toggle.** There is no stream-level switch: the ack metric is emitted when the
consumer's `sample_freq` says so (`ConsumerConfig.SampleFrequency`, `consumer.go:103`); nothing in
`StreamConfig` enables or disables a metric.

## Practical takeaways

- A consumer of `nak` / `terminated` advisories that parses `consumer_seq` as a string breaks on
  the wire; a parser of `snapshot_create` waiting for `blocks` never sees it.
- Every JetStream advisory carries `domain` when a domain is configured — the field to route on in
  a multi-domain deployment, absent from half the pages.

## Notable quotes

- "The Stream Template that manages the Stream" — `stream-action.md`, for a field the server no
  longer has.
- "Metrics can be enabled or disabled at the stream or consumer level" — `metric.md`.

## Relevance to the wiki

Docs issues #70 (the four wrong bodies and the enum), #71 (the descriptions, bounds and missing
`domain`/`account` — one `enhancement` row), #72 (`metric.md`'s stream-level toggle). The
*Per-advisory payload fields* item under *To verify* on [[advisories]] is answered: the bodies are
now on this summary and `jetstream_events.go` is in `raw/`. Completes the docs coverage of
`reference/jetstream/` (59 of 59 read, with [[s-docs-jetstream-api-index]]).

## Questions it answers

Row 59 in part (the ack metric's fields and its `sample_freq` switch), row 162.

## Pages touched

[[advisories]] · [[system-subjects]]
