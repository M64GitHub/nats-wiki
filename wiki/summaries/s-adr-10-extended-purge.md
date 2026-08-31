---
title: "ADR-10 — JetStream extended purge"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-10.md
source-path: raw/adr/ADR-10.md
author: "@aricart"
article: ADR-10 JetStream Extended Purge
date: 2021-06-30
version: ""
tags: [purge, stream, filter, keep, seq, 10003, 10110, discard-new]
aliases: [ADR-10, extended purge, "$JS.API.STREAM.PURGE"]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-10 — purge is three operations, not one

Two pages of spec for the request body of `$JS.API.STREAM.PURGE.<stream>`. Small, old (2021-06-30)
and **still exactly what nats-server 2.14.6 implements** — the request struct, the field names and
the mutual exclusion were checked against the source, and the behaviour was run on the binary.

## Key claims

### The request

`$JS.API.STREAM.PURGE.<stream>` with **no payload purges the whole stream**. With a JSON body it
takes three optional fields:

```json
{ "seq": 0, "keep": 0, "filter": "" }
```

- **`seq`** — "the optional upper-bound sequence for messages to be deleted (non-inclusive)".
- **`keep`** — "the maximum number of messages to be retained (might be less depending on whether
  the specified count is available)".
- **`filter`** — "an optional subject (may include wildcards) to filter on. Only messages matching
  the filter will be purged."

`seq` and `keep` are **mutually exclusive**. `filter` combines with either: `filter` + `seq` purges
matching messages below that sequence, `filter` + `keep` keeps at most that many of the matching
messages. "To `keep` _N_ number of messages for multiple subjects, invoke `purge` with different
`filter`s" — there is no per-subject keep in one call.

### The response

```json
{ "type": "io.nats.jetstream.api.v1.stream_purge_response", "success": true, "purged": 0 }
```

`purged` is the number of messages removed; `error` is an [ADR-7](s-adr-7-server-error-codes)
`ApiError` when it failed.

### Verified against nats-server 2.14.6

The struct is unchanged, and note that the JSON name of the filter is `filter` while the Go field is
`Subject` (`server/jetstream_api.go:495`):

```go
type JSApiStreamPurgeRequest struct {
	Sequence uint64 `json:"seq,omitempty"`
	Subject  string `json:"filter,omitempty"`
	Keep     uint64 `json:"keep,omitempty"`
}
```

The mutual exclusion is enforced by the server, not left to the client
(`jetstream_api.go:3726`) — sending both returns **`10003 bad request`**, observed:

```
$ nats req '$JS.API.STREAM.PURGE.FULL' '{"seq":10,"keep":1}'
{"type":"io.nats.jetstream.api.v1.stream_purge_response","error":{"code":400,"err_code":10003,"description":"bad request"},"purged":0}
```

Two refusals the ADR does not mention, both in the same handler:

- a **sealed** stream returns `10109 invalid operation on sealed stream`;
- a stream configured `deny_purge: true` returns **`10110`** with `stream purge not permitted`
  (`jetstream_api.go:3748`). `deny_purge` is chosen by whoever creates the stream — in 2.14.6
  neither a KV bucket nor an Object Store bucket sets it (both report `deny_purge: false`; KV sets
  `deny_delete: true` instead).

### The CLI exposes all three, and purge does not reset sequences

```
nats stream purge <stream> --subject=<subject> --seq=<sequence> --keep=<messages>
```

Observed on nats CLI 0.4.0 against 2.14.6: `nats stream purge FULL --force --keep=1` kept the
**newest** message and left the stream at `First Sequence: 3`, `Last Sequence: 3`. A purge removes
messages; it does not renumber the stream.

## Practical takeaways

- **`--keep` is the recovery tool for a stream at its limit.** It is the only form that guarantees
  the stream is still usable afterwards, and unlike raising `max_msgs` it takes effect immediately.
- **`--subject` is how you evict one tenant, key space or partition** out of a shared stream without
  touching the rest.
- **`--seq` is the "everything before the checkpoint" form** — pair it with the sequence a consumer
  or a backup reports rather than with a wall-clock guess.
- Purge is a **stream-level** operation with no consumer awareness: consumers whose next sequence was
  purged away simply skip forward. It is not a substitute for a retention policy.

## Notable quotes

> "Tooling and services can use this endpoint to remove messages in creative ways. For example, a
> stream may contain a number of samples, at periodic intervals a service can sum them all and
> replace them with a single aggregate."

## Relevance to the wiki

The recovery half of [[maximum-messages-exceeded]], and the operation [[retention-policies]] points
at when a limit has already been hit. Fills in the request body that
[[js-api-subjects]] lists only as a subject.

## Questions it answers

Q27 (recovering a stream that is full under `DiscardNew`), with
[[maximum-messages-exceeded]] carrying the answer.

## Pages touched

[[maximum-messages-exceeded]] · [[js-api-subjects]] · [[retention-policies]] · [[stream]] ·
[[error-codes]]
