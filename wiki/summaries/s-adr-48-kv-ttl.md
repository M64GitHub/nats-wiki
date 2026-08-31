---
title: "ADR-48 — TTL support for Key-Value buckets"
type: summary
area: [kv, jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-48.md
source-path: raw/adr/ADR-48.md
author: "@ripienaar, @scottf"
article: ADR-48 TTL Support for Key-Value Buckets
date: 2025-04-09
version: "2.11"
tags: [kv, ttl, limit-markers, subject_delete_marker_ttl, allow_msg_ttl, Nats-Marker-Reason, api-level]
aliases: [ADR-48]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-48 — per-key TTL and limit markers in KV

A refinement of ADR-8 that exposes ADR-43's per-message TTL through the KV API. Status
**Implemented**, tagged **2.11**. Short, and three of its rules are operational rather than
client-shaped.

## Key claims

### "Limit Markers" is one setting that sets two stream fields

The KV configuration gains "a single extra property in a language idiomatic version of `Limit
Markers` that will set `allow_msg_ttl` to `true` and `subject_delete_marker_ttl` to the supplied
duration". So on the stream a KV bucket with markers is simply a stream with those two fields set —
visible in `nats stream info KV_<bucket>`.

### The duration floor is one second, and the setting is one-way

"This duration value must larger than or equal to 1 second." And: "The configuration item can be
enabled for buckets that have it disabled but should not support disabling it as today the Server
would handle old TTLs correctly should it again be enabled later." Enabling later is supported;
turning it off is not offered.

### Check API level, not the version string

"This should only be set on a server with API level 1 or newer. At the moment the only way this is
exposed is via the `$JS.API.INFO` API call, clients should check this when this feature is
requested."

### A TTL is accepted on exactly two operations

`Create()` and `Purge()`. Everything else is refused deliberately: "do not accept a TTL for other
API. Some are currently undefined, and some are understood to create improper state. For instance a
TTL on `Put()` might mean older revisions could come back from the dead once the TTL expires." That
last sentence is the reason KV has no expiring `Put`.

### `Purge()` with a TTL replaces compaction

One of the ADR's three stated goals: "Improve Purge so that old subjects can be permanently removed,
removing the need for costly compacts, while still supporting Watchers."

### The status surface

`LimitMarkerTTL()` reports the configured duration, "0 meaning markers are not supported".

### Watchers must map three marker reasons

`Nats-Marker-Reason: MaxAge` → treat as `PURGE`; `Purge` → `PURGE`; `Remove` → `DEL`. "Watchers
should be updated to handle these values also."

## Practical takeaways

- **A KV bucket with markers is auditable from the stream**: `allow_msg_ttl: true` plus a
  `subject_delete_marker_ttl` ≥ 1s.
- **Markers can be switched on for an existing bucket and not off again** — treat it as a one-way
  decision.
- **There is no TTL on `Put`**, by design; a per-key lifetime means `Create` (or an explicit
  `Purge` with a TTL).

## Relevance to the wiki

Closes the ADR-48 item on [[message-ttl]]'s and [[key-value]]'s `## To verify`, corrects the floor
wording (≥ 1s, not "longer than a second"), and adds the two-operations rule and the one-way
enabling.

## Questions it answers

Q71 (does KV support a TTL per key, and since when) — already answered by [[message-ttl]] and
[[key-value]]; this is the spec behind it.

## Pages touched

[[key-value]] · [[message-ttl]]
