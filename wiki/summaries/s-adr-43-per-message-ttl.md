---
title: "ADR-43 — JetStream Per-Message TTL"
type: summary
area: [jetstream, kv]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-43.md
source-path: raw/adr/ADR-43.md
author: "@ripienaar"
article: "ADR-43: JetStream Per-Message TTL"
date: 2024-07-11
version: "2.11"           # ADR tags: jetstream, client, server, 2.11
tags: [ttl, Nats-TTL, subject_delete_marker_ttl, tombstone, error-codes]
aliases: [ADR-43, per-message TTL, Nats-TTL]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-43 — JetStream Per-Message TTL

Status **Implemented**, tagged `2.11`. Gives an individual message its own expiry, instead of the
stream-wide `max_age`.

## Key claims

### The header

- **`Nats-TTL`** carries a duration as **seconds or a Go duration string** (`1h`).
- The server computes the deadline from the message's **stream timestamp** plus the duration.
- **`Nats-TTL: never`** means the message is never expired — **and it is not removed by the
  stream's `MaxAge` either**.
- **No `Nats-TTL` header** = no per-message TTL applies.
- **Minimum is 1 second.** Any unparsable value, or one below 1 second **including a literal `0`**,
  is **an error in the PubAck and the message is discarded**.
- Publishing `Nats-TTL` to a stream with the feature **disabled rejects the message**.

### Stream configuration

```go
AllowMsgTTL            bool          `json:"allow_msg_ttl"`
SubjectDeleteMarkerTTL time.Duration `json:"subject_delete_marker_ttl,omitempty"`
```

Restrictions, verbatim in substance:

- **`AllowMsgTTL` can be enabled on an existing stream but never disabled.**
- `Nats-TTL` and `SubjectDeleteMarkerTTL` both have a **1-second minimum**.
- **`SubjectDeleteMarkerTTL` may not be set on a mirror stream.**
- Setting either **requires stream API level `1`**.
- **`AllowRollup` must be `true`** and **`DenyPurge` must be `false`**; create and update set these
  automatically **unless pedantic mode is on**.
- **Unless `MaxMsgsPer` equals 1, the server treats `SubjectDeleteMarkerTTL` as the minimum
  effective `Nats-TTL`.** A publish below that floor is **not rejected** — the server **raises the
  effective TTL to the floor and rewrites the stored `Nats-TTL` header** to the clamped value, as
  integer seconds.

### Limit markers (tombstones)

When the server removes a message and it was **the last one in its subject**, it places a marker
message carrying **`Nats-Marker-Reason`** and a **`Nats-TTL` set to the stream's
`SubjectDeleteMarkerTTL`**, formatted as a Go duration string (`1m0s` for 60s).

- **`MaxAge`** is the reason for **any age-based removal of a subject's last value** — whether the
  trigger was the stream-wide `MaxAge` or a per-message `Nats-TTL`.
- **Off by default**; opt in via `SubjectDeleteMarkerTTL`.
- **`Remove` (delete API) and `Purge` (purge-subject API) markers are documented but carry an
  explicit note: "As of Server version 2.14 this feature is not currently implemented."**

### Sources and mirrors

Sources and mirrors **always accept and store** messages carrying `Nats-TTL`, even with
`AllowMsgTTL` disabled — with the setting off they are simply stored and never expire. **Sources
may set `SubjectDeleteMarkerTTL`; mirrors may not**, because inserting new messages would break
sequence matching against the mirrored stream.

### Error codes

| rejection path | `err_code` | description |
|---|---:|---|
| `Nats-TTL` published to a stream with `AllowMsgTTL: false` | **10166** | `per-message TTL is disabled` |
| `Nats-TTL` unparsable, sub-second, or literal `0` | **10165** | `invalid per-message TTL` |
| `SubjectDeleteMarkerTTL` below `1s` | **10052** | `subject delete marker TTL must be at least 1 second` |
| `SubjectDeleteMarkerTTL` on a mirror | **10052** | `subject delete markers forbidden on mirrors` |
| `SubjectDeleteMarkerTTL` with `AllowRollup: false` in pedantic mode | **10052** | `subject delete marker cannot be set if roll-ups are disabled` |
| `SubjectDeleteMarkerTTL` with `AllowRollup: true` and `DenyPurge: true` | **10052** | `roll-ups require the purge permission` |
| update setting `AllowMsgTTL: false` after it was `true` | **10052** | `message TTL status can not be disabled` |

All `10052` responses are `JSStreamInvalidConfigF` and share one shape, with the reason in the
description.

## Why an operator cares

- **The motivating use case is KV tombstones** — "KV tombstones are a problem in that they forever
  clog up the buckets with noise". This is the mechanism behind KV per-key TTL.
- **Two documented behaviours are not implemented as of 2.14** (the `Remove` and `Purge` markers) —
  the ADR describes them in the present tense and only the admonition says otherwise.
- **The silent TTL clamp** is the subtle one: with `MaxMsgsPer != 1`, a `Nats-TTL` shorter than
  `SubjectDeleteMarkerTTL` is quietly raised and the stored header rewritten. A message you asked to
  live 5 seconds may live as long as the marker TTL, with no error anywhere.

## Relevance to the wiki

The source for [[message-ttl]], and the version answer for KV per-key TTL (2.11) in
[[key-value]].

## Questions it answers

Q28 (how per-message TTLs and subject delete markers behave), Q71 (KV per-key TTL and since which
version — 2.11).

## Pages touched

[[message-ttl]] · [[stream]] · [[key-value]] · [[error-codes]]
