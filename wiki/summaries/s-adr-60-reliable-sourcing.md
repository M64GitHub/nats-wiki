---
title: "ADR-60 — reliable sourcing and mirroring of WorkQueue and Interest streams"
type: summary
area: [jetstream, topology]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-60.md
source-path: raw/adr/ADR-60.md
author: "@MauriceVanVeen"
article: ADR-60 JetStream reliable stream sourcing/mirroring on WQ/Interest streams
date: 2026-03-11
version: "2.14"
tags: [mirror, sources, workqueue, interest, AckFlowControl, JS_MIRROR, JS_SRC, consumer-reset, durable-sourcing, api-level]
aliases: [ADR-60]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-60 — what 2.14 changed about mirroring a WorkQueue or Interest stream

Updates [[s-adr-59-sourcing-and-mirroring]]. Status **Implemented**, tagged **2.14**. The problem it
fixes is the one ADR-59 documents as "not recommended": an ephemeral `AckNone` push consumer loses
messages on a WorkQueue or Interest upstream, because "any messages that are sent are immediately
acknowledged and removed", and because an ephemeral consumer's interest disappears whenever the link
is down.

## Key claims

### The server now upgrades the replication consumer to a durable — and you can see it

"The server should recognize when a stream that's being sourced is a WorkQueue or Interest stream. In
that case it should 'upgrade' the consumer to become a durable consumer." Those consumers are
deliberately identifiable:

| | name | metadata |
|---|---|---|
| mirroring | `JS_MIRROR_<suffix>` | `_nats.mirror.stream`, `_nats.mirror.acc`, `_nats.mirror.domain` |
| sourcing | `JS_SRC_<suffix>` | `_nats.src.stream`, `_nats.src.acc`, `_nats.src.domain` |

*Checked against the server:* both name forms are built at `stream.go:2797` and `:2805` (and
`JS_MIRROR_<id>_<name>` at `:3741`), and the metadata keys are set at `stream.go:3552–3555` and
`4010–4013`, v2.14.6. The domain key appears only when a domain is configured.

**They are visible in `nats consumer ls`** — unlike the hidden `Direct` consumers used for Limits
upstreams. The ADR is explicit that deletion is only best-effort: the consumer "is deleted on a
best-effort basis if the mirror/source config is removed, however the user may need to manually
delete this durable consumer if this fails."

### A new ack policy, `AckFlowControl`

"`AckPolicy=AckFlowControl` will function like `AckAll`. The flow control messages … will ack
messages rather than the current ack reply format." The receiving server answers with a flow-control
message carrying `Nats-Last-Stream` (stream sequence) and `Nats-Last-Consumer` (delivery sequence)
headers to say what it has stored; the sending side acks up to those, "which for WorkQueue and
Interest streams may result in messages deletion".

Constraints the server enforces on such a consumer:

- `FlowControl` and `Heartbeat` required; the heartbeat also moves the ack floor while the stream is idle.
- `MaxAckPending` bounds the in-flight window and forces a flow-control message when reached.
- `AckWait` and `BackOff` **must be unset** — "or an error will be returned" — because acknowledgement
  is driven by flow control, not by time.
- `MaxDeliver` must be `-1`, so anything lost in transit can still be redelivered.

*Checked against the server:* `AckFlowControl` exists at v2.14.6 (`store.go:646`, `:662`) and is set
for these consumers in `jetstream_cluster.go:9520`; `Nats-Last-Stream` is `JSLastStreamSeq`,
`stream.go:647`.

### Durable sourcing: bring your own consumer

A user may pre-create the durable consumer and point the source at it:

```json
{"stream": "aggregate",
 "sources": [{"name": "source",
              "consumer": {"name": "source-consumer",
                           "deliver_subject": "source.consumer.deliver.subject"}}]}
```

Then `opt_start_seq`, `opt_start_time` and `filter_subject` **are not allowed on the source** — they
move onto the consumer. In exchange you get lifecycle control (the consumer can be paused and
resumed, which pauses replication) and two configurations the built-in path cannot express:
`DeliverPolicy=last_per_subject` and `ReplayPolicy=original`.

The WorkQueue overlap rule still bites: "WorkQueue streams don't allow having multiple consumers with
overlapping filter subjects", so a durable sourcing consumer blocks any other overlapping consumer —
"in that case, an Interest or Limits stream should be used".

### `$JS.API.CONSUMER.RESET.<STREAM>.<CONSUMER>`

A durable consumer cannot be deleted and recreated on a gap — that would lose interest on an Interest
stream — so 2.14 adds a reset API instead. It resets pending, redelivered, delivered and ack-floor
consumer sequences; an **empty payload** leaves the ack-floor *stream* sequence where it is (this is
what the sourcing consumer uses after a gap), while `{"seq":<seq>}` moves it to one below `seq`.
Allowed only on `DeliverPolicy=all`, `by_start_sequence` and `by_start_time`, and for the latter two
only if the target is not before what the consumer's own start policy allowed. The response is shaped
like a consumer-create response plus the `ResetSeq` actually used.

The server also has to survive a **human** calling it: a manual reset forward makes the server skip
the intervening messages, and a reset backward must not produce duplicates in the mirror.

### Mixed-version clusters: API level 4

*Checked against the server, not stated in the ADR:* the consumer-create request the sourcing server
sends carries `Nats-Required-Api-Level: 4` — "Confirm the server supports API level 4, which contains
durable sourcing, AckFlowControl, and consumer reset" (`stream.go:3679`, v2.14.6). An upstream server
below that level will not serve reliable WQ/Interest sourcing, which matters while a cluster or a
leafnode pair is mid-upgrade.

### What clients must not do

"Clients should not fail when the consumer delivery sequence is not monotonic, except when needed for
the 'ordered consumer' implementations" — because a reset may be triggered by another process, the
CLI included.

## Practical takeaways

- **A `JS_SRC_*` or `JS_MIRROR_*` consumer in `nats consumer ls` is not junk** — it is the
  replication consumer for a WorkQueue or Interest upstream. Read `_nats.src.stream` to see who owns
  it before deleting it.
- **But a leftover one after removing a source is junk**, and deleting it is a manual job: removal is
  best-effort by design.
- **Pausing a pre-created durable sourcing consumer pauses replication** — the only supported way to
  stop a source without editing the stream.
- **Do not upgrade half a cluster and expect this to work**: it needs API level 4 on the upstream.

## Relevance to the wiki

Closes the second half of [[mirrors-and-sources]]'s `## To verify`, adds the `AckFlowControl` policy
to [[consumer]] and the reset API's semantics to [[js-api-subjects]], and gives
[[retention-policies]] the reason WorkQueue and Interest upstreams changed status in 2.14.

## Questions it answers

None in `inbox/question-bank.md` directly; it answers the operational question the wiki raised
itself — what those `JS_SRC_*` consumers are and whether they can be deleted.

## Pages touched

[[mirrors-and-sources]] · [[retention-policies]] · [[consumer]] · [[js-api-subjects]] ·
[[nats-server-2.14]]
