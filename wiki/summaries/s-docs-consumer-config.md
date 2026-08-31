---
title: "docs.nats.io — Create Consumer (ConsumerInfo reference)"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/reference/jetstream/api/consumer/create.md
source-path: raw/nats-docs/reference/jetstream/api/consumer/create.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the JetStream JSON schemas
article: Create Consumer
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [consumerinfo, js-api]
aliases: [consumerinfo]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Create Consumer (ConsumerInfo reference)

The generated schema reference for the consumer-create API. Used here for the **subject** and for
the **observable `ConsumerInfo` fields**, which are what an operator actually reads when a
consumer misbehaves.

## Subject

`$JS.API.CONSUMER.CREATE.<stream>.<consumer>` — the consumer name is optional.

## Key claims

- The request carries `stream_name` (required), a `config` object (required), an `action` string,
  and `pedantic` (boolean, default `false`) — "the server will not apply defaults or change the
  request".
- The response's `ConsumerInfo` exposes:

| field | meaning |
|---|---|
| `stream_name` | the stream the consumer belongs to |
| `name` | unique consumer name — machine generated, or the durable name |
| `created` | RFC3339 creation timestamp |
| `config` | the active consumer configuration |
| `delivered` | the last message delivered from this consumer |
| `ack_floor` | **the highest contiguous acknowledged message** |
| `num_ack_pending` | messages pending acknowledgement |
| `num_redelivered` | redeliveries performed |
| `num_waiting` | **pull requests currently waiting for messages** |
| `num_pending` | messages left unconsumed by this consumer |
| `cluster` | the consumer's RAFT group: leader and replicas |
| `push_bound` | whether a client is connected and receiving from a push consumer |
| `paused` / `pause_remaining` | whether the consumer is paused, and for how long |
| `priority_groups` | the state of priority groups |

## Notable

- **The consumer `config` object is not expanded on this page** — the docs render it as a
  collapsed schema node, so the per-field consumer defaults (`ack_wait`, `max_deliver`,
  `max_ack_pending`, `backoff`) are **not readable from this source**. The wiki takes those from
  the learn pages ([[s-docs-acknowledgment]], [[s-docs-pull-consumers]]) instead.
- `ack_floor` is defined as *the highest contiguous acknowledged message*, which is why an
  out-of-order ack does not advance it.

## Relevance to the wiki

Supplies the `$JS.API.CONSUMER.CREATE` subject and the "what you can observe" field list for
[[consumer]], and flags a gap the future `reference/defaults-and-limits` page has to fill from
the server source rather than the docs.

## Questions it answers

Q22 in part (which messages are still pending — `num_pending`, `num_ack_pending` and `ack_floor`
are the fields, though the runbook is still open).

## Pages touched

[[consumer]] · [[ack-and-redelivery]]
