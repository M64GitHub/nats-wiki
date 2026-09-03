---
title: "ADR-33 — Metadata for Stream and Consumer"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-33.md
source-path: raw/adr/ADR-33.md
author: "@Jarema"
article: ADR-33
date: 2023-01-23
version: "2.10"           # shipped in 2.10.0 (#3797)
tags: [adr, metadata, stream-config, consumer-config]
aliases: [ADR-33]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# ADR-33 — Metadata for Stream and Consumer

Approved, 2023-01-23; server PR #3797, shipped in 2.10.0 ([[s-relnotes-2.10]]). Adds a `metadata`
field — a map of string keys to string values — to both `StreamConfig` and `ConsumerConfig`, because
"the only solution was using `Description` field, which is a not ergonomic workaround".

## Key claims

- JSON: an object of string pairs. **Size limit 128 KB**, "equal to len of all keys and values
  summed" — the server's `JSMaxMetadataLen = 128 * 1024` (`jetstream_api.go:359`), refused with
  `stream metadata exceeds maximum size of 131072 bytes` / consumer code 10135.
- **`_nats` is a reserved prefix** "for any potential internals of server or clients"; the server
  "can lock its metadata to be immutable and deny any changes". The example shows
  `_nats.mirror.domain`. (On 2.14.6 the server writes `_nats.ver`, `_nats.level`, `_nats.req.level`
  and `_nats.created.version` into consumer metadata — [[consumer]].)
- Updatable: `metadata` is applied by `updateConfig` on a consumer and by a stream update.

## Practical takeaways

- Put ownership and provenance (`owner`, `domain`, a deploy id) in `metadata`, not in `description`;
  keep the total under 128 KB and never write under `_nats`.

## Relevance to the wiki

The `metadata` rows of [[stream-and-consumer-config]].

## Questions it answers

Row 164 in part.

## Pages touched

[[stream-and-consumer-config]]
