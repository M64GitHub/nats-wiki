---
title: "docs.nats.io — Create Stream (StreamConfig reference)"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/reference/jetstream/api/stream/create.md
source-path: raw/nats-docs/reference/jetstream/api/stream/create.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the JetStream JSON schemas
article: Create Stream
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [streamconfig, defaults, js-api]
aliases: [streamconfig]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Create Stream (StreamConfig reference)

The generated schema reference for the stream-create API. Used here as the **authority for stream
field defaults and ranges**, which the prose learn pages state only in passing.

## Subject

`$JS.API.STREAM.CREATE.<stream>`

## Key claims — fields, ranges and defaults

| field | type | range | default |
|---|---|---|---|
| `name` | string | pattern `^[^.*>]*$` | — |
| `description` | string | max length 4096 | — |
| `subjects` | string[] | supports wildcards; must be empty when a mirror is configured, may be empty when sources are configured | — |
| `retention` | string | `limits` \| `interest` \| `workqueue` | `limits` |
| `max_consumers` | integer | −1 for unlimited | `-1` |
| `max_msgs` | integer | −1 for unlimited | `-1` |
| `max_msgs_per_subject` | integer | −1 for unlimited | `-1` |
| `max_bytes` | integer | −1 for unlimited | `-1` |
| `max_age` | integer (nanoseconds) | 0 for unlimited | `0` |
| `max_msg_size` | integer (signed 32-bit) | −1 for unlimited, max `2147483647` | `-1` |
| `storage` | string | `file` \| `memory` | `file` |
| `compression` | string | `none` \| `s2` | `none` |
| `num_replicas` | integer | **minimum 1, maximum 5** | `1` |
| `no_ack` | boolean | disables acknowledging messages received by the stream | `false` |
| `discard` | string | `old` \| `new` | `old` |
| `duplicate_window` | integer (nanoseconds) | "0 for default" | `0` |
| `placement` | object | cluster + tags; random placement when unset | unset |
| `mirror` | object | 1:1 mirror of another stream; `subjects` and `sources` must then be empty | unset |
| `sources` | object[] | streams replicated into this stream | unset |
| `sealed` | boolean | messages cannot be deleted via limits or API; cannot be unsealed; settable only on an existing stream via Update | `false` |
| `deny_delete` | boolean | cannot be changed once `true` | `false` |
| `deny_purge` | boolean | cannot be changed once `true` | `false` |
| `allow_rollup_hdrs` | boolean | enables the `Nats-Rollup` header | `false` |
| `allow_direct` | boolean | direct access to get individual messages | `false` |
| `allow_atomic` | boolean | atomic batched publishes | `false` |
| `allow_msg_counter` | boolean | stream is a counter and rejects all other messages | `false` |
| `allow_msg_schedules` | boolean | message scheduling | `false` |
| `mirror_direct` | boolean | direct access for mirrors | `false` |
| `discard_new_per_subject` | boolean | with `discard: new` and `max_msgs_per_subject` set, applies the discard-new behaviour per subject | `false` |
| `allow_msg_ttl` | boolean | per-message TTL via headers | `false` |
| `subject_delete_marker_ttl` | integer (nanoseconds) | duration for server delete/purge/max-age markers | — |
| `persist_mode` | string | `""` (server default) \| `default` (flush before PubAck) \| `async` (flush in background) | `""` |
| `allow_batched` | boolean | fast batch publishing | `false` |
| `pedantic` | boolean | server applies no defaults and does not change the request | `false` |

The page also describes the three `retention` values inline, matching
[[s-docs-retention-policies]]: `limits` keeps messages until `max_msgs`, `max_bytes` or `max_age`
removes them; `interest` removes a message once every consumer whose filter matches it has acked
it, and **drops a message with no matching consumer immediately**; `workqueue` removes a message
as soon as one consumer acks it and **requires non-overlapping subject filters**.

## Notable

- `num_replicas` maximum is **5**, confirming the R=5 ceiling stated in
  [[s-docs-surviving-node-loss]].
- `duplicate_window` defaults to `0`, which the schema describes as "0 for default" — the *value*
  the server substitutes is **not stated on this page**.

## Relevance to the wiki

The citation anchor for every stream default in [[stream]], and the field list the
`reference/config-keys` and `reference/defaults-and-limits` pages of the plan will be checked
against.

## Questions it answers

None on its own; it grounds the numbers other pages state.

## Pages touched

[[stream]] · [[retention-policies]] · [[replicas]]
