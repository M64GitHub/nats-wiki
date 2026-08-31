---
title: "ADR-59 — JetStream Stream Sourcing and Mirroring"
type: summary
area: [jetstream, topology, deploy]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-59.md
source-path: raw/adr/ADR-59.md
author: "@ripienaar"
article: ADR-59 JetStream Stream Sourcing and Mirroring
date: 2026-03-03
version: "2.12.5"
tags: [mirror, sources, StreamSource, external, subject_transforms, cycle-detection, 10029, 10045, Nats-Stream-Source, jsz]
aliases: [ADR-59]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-59 — sourcing and mirroring, the authoritative spec

Written to be the single document for a pair of features that had none: "While these features have
been available since the introduction of JetStream, there is no single document that describes their
complete behavior. This ADR serves as the authoritative reference." Status **Implemented**, revision
1 documents behaviour up to **2.12.5**, revision 2 (2026-04-29) aligns the Direct Get section with
ADR-31 revision 3. Refined for WorkQueue and Interest upstreams by [[s-adr-60-reliable-sourcing]].

## Key claims

### One config type, `StreamSource`, for both

`name` (required) · `opt_start_seq` · `opt_start_time` · `filter_subject` · `subject_transforms` ·
`external`. Defaults: `0` / `null` / `""` (all subjects) / `[]` / `null` (local).

- `opt_start_seq` and `opt_start_time` are documented as mutually exclusive, but "if both happen to
  be set, `opt_start_seq` takes precedence in the internal consumer creation logic".
- `filter_subject` and `subject_transforms` are mutually exclusive **per entry**. Use the first to
  select a subset, the second when you also need to rename or need several filters.
- Both start settings "only take effect on first creation. On restart, the mirror resumes from its
  last known position."

### What a mirror may not be combined with

`subjects`, `sources`, `first_seq`, `allow_msg_counter`, `allow_atomic`, `allow_msg_schedules`, and
`subject_delete_marker_ttl` — the last because "delete markers would insert new messages and break
sequence alignment". A mirror **can** use `subject_transform` (stream level), `republish`,
`compression` and `allow_msg_ttl`. A **sourced** stream is only barred from `mirror` and
`allow_msg_schedules`; it may have its own `subjects` and take direct publishes.

### Two source entries are duplicates on four fields

Stream name, filter subject, subject transforms and external API prefix. So the same upstream can be
sourced twice as long as the filter or transform differs.

### Transforms apply in a fixed order

Source-level `filter_subject`/`subject_transforms` as messages are selected from the upstream, then
the stream-level `subject_transform` on everything entering the stream — including direct publishes.

### Cycle detection stops at the account boundary

"The server automatically detects and prevents cycles in source and mirror relationships within the
same account." But: "Cycle detection **does not** apply across external streams in different domains.
It is the operator's responsibility to ensure that cross-domain configurations do not create
replication cycles."

### Cross-account replication needs three subjects with the right *types*

| subject | type | purpose |
|---|---|---|
| `$JS.API.CONSUMER.>` | **service** | consumer create/delete (request/reply) |
| `deliver.mirror.>` | **stream** | one-way delivery of replicated messages |
| `$JS.FC.>` | **service** | flow control back to the origin |

"Getting the type wrong (e.g., using a stream import for the API subject) will cause silent
failures."

### Two error codes, and three places to read them

`10029` mirror consumer setup failed, `10045` source consumer setup failed — each wrapping the real
cause: "the upstream stream not existing, permission denied, the external domain being unreachable, a
subscription failure, or a timeout waiting for the consumer creation response (**30 seconds**)". The
error clears itself on reconnection and is visible in `$JS.API.STREAM.INFO.<stream>`
(`mirror.error`, `sources[].error`), in `/jsz`, and over `$SYS.REQ.SERVER.PING.JSZ`. The server also
logs `JetStream error response for create mirror consumer` /
`JetStream error response for stream <name> create source consumer <source>`.

*Checked against the server:* both codes exist at v2.14.6 with **HTTP 500** and the description
template `{err}` — `JSMirrorConsumerSetupFailedErrF` and `JSSourceConsumerSetupFailedErrF`,
`jetstream_errors_generated.go:381` and `:477`. The friendly names in the ADR's table are labels, not
the wire text.

### Sourced messages carry their origin in a header

`Nats-Stream-Source: <stream-index> <sequence> <filter-subject> <dest-subject> <original-subject>`,
e.g. `ORDERS 42 > > orders.us.new`, where `>` stands for "none". The stream index carries `:<hash>`
when sourcing through an external API prefix, multiple transform destinations are joined with `\f`,
and when sourcing is daisy-chained "the server replaces any existing `Nats-Stream-Source` header so
the header always reflects the immediate upstream origin".

### The replication consumers are real consumers, and `/jsz` can show them

They are hidden from the consumer API by a `Direct` flag, use `AckNone`, flow control and heartbeats,
and are named `mirror-<id>` / `src-<id>` when a single filter is in play (created through the
extended create API); with no filter, or several transforms, the name is server-generated.
`GET /jsz?streams=true&consumers=true&direct-consumers=true&config=true&acc=<account>` returns them
under `direct_consumer_detail`, whose delivered and ack-floor positions can be compared against the
upstream's state — "the `StreamSourceInfo` fields (`lag`, `active`, `error`) provide a higher-level
summary of the same state".

### Gap handling is only reliable on Limits upstreams

The server tracks the upstream sequence (`sseq`) and the consumer delivery sequence (`dseq`). "When a
gap appears in `sseq` but `dseq` is contiguous, it means the upstream stream had messages removed —
the server records skip markers for the missing range and continues. When `dseq` itself has a gap,
the consumer itself missed messages and must be recreated." And: "This gap detection is reliable only
for streams using the **Limits** retention policy but not for **Work Queue** or **Interest**."

### WorkQueue and Interest upstreams are "not recommended" — for two different reasons

- **WorkQueue**: the internal replication consumers "are direct consumers that bypass the work
  queue's subject overlap validation", so a work queue can have both a normal consumer and a
  replication consumer on the same subjects, "breaking the single-consumer-per-subject-partition
  guarantee".
- **Interest**: the internal consumer has a short inactive threshold (**10 seconds**), so while it is
  absent "there may be no consumer to express interest in new messages, causing them to be removed
  before they can be replicated".

*Checked against the server:* that threshold is `sourceHealthCheckInterval = 10 * time.Second`
(`stream.go:3121` at v2.14.6), used both as the health-check tick and as the `InactiveThreshold` of
the consumer. [[s-adr-60-reliable-sourcing]] is the 2.14 answer to both problems.

### Recovery and cluster behaviour

Reconnection is automatic with "exponential backoff with jitter"; replication resumes "from the last
successfully stored sequence — no manual intervention is required". In a cluster "only the stream
leader manages the replication consumers", and a new leader takes over from the last known position.

### Mirror Direct Access

The `mirror_direct` rules are ADR-31's, restated: aligned to the upstream's `allow_direct` at create
time when the upstream is visible (rejected in pedantic mode, silently aligned otherwise), preserved
when it is not, joined only after catch-up, **never refreshed** when the upstream changes later, and
surfaced through `alternates` on the upstream's `StreamInfo`, sorted by RTT.

## Practical takeaways

- **Alert on `error` as well as `lag`** — `10029`/`10045` are the only signal that a mirror never
  started, and they are readable from `/jsz` without a client.
- **Across domains, cycles are yours to prevent.** Nothing in the server will stop A→B→A.
- **`direct-consumers=true` is the debugging switch** when `lag` is high and nothing else explains it.
- **Do not mirror a WorkQueue or Interest stream on a pre-2.14 server**; see ADR-60 for what changed.

## Relevance to the wiki

The authoritative source [[mirrors-and-sources]] was missing and its `## To verify` named. Fills in
the config surface, the two error codes, the origin header, the `/jsz` switches and the retention
caveats.

## Questions it answers

Q76 partially (mirror behaviour), and the standing "why is my mirror not catching up" that
[[mirrors-and-sources]] answers.

## Pages touched

[[mirrors-and-sources]] · [[retention-policies]] · [[error-codes]] · [[monitoring-endpoints]] ·
[[cross-domain-sourcing]] · [[js-api-subjects]]
