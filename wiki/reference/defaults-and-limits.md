---
title: Defaults and limits
type: reference
area: [core, jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [defaults, limits, max_payload, ack_wait, duplicate_window, sync_interval]
aliases: [defaults, limits, default values]
sources: [s-nats-server-constants-2.14.6, s-docs-stream-config, s-docs-sizing-and-resources, s-docs-connection-limits-config, s-docs-acknowledgment, s-docs-pull-consumers]
created: 2026-08-31
updated: 2026-08-31
---

# Defaults and limits

The values `nats-server` uses when you set nothing. **Every row is either read from the tagged
source at v2.14.6 with its file and line, or stated by a docs page that is cited.** Nothing here is
inferred, and a value neither source states is not on this page.

This page states values; it does not explain them — follow the link in the last column.

## Core server

From `server/const.go` at **v2.14.6** (source: [[s-nats-server-constants-2.14.6]]).

| setting | default | source | explained by |
|---|---|---|---|
| `port` | `4222` | `const.go:78` | — |
| `host` | `0.0.0.0` | `const.go:86` | — |
| `http_port` (monitoring) | `8222` — **off unless set** | `const.go:135` | [[monitoring-endpoints]] |
| `max_control_line` | `4096` | `const.go:90` | — |
| **`max_payload`** | **1 MB** | `const.go:94` | [[jetstream-sizing]] |
| `max_payload` warning threshold | **8 MB** | `const.go:99` | see *the 8 MB question* below |
| **`max_pending`** | **64 MB** | `const.go:102` | [[jetstream-sizing]] |
| **`max_connections`** | **65,536** (`64 * 1024`) | `const.go:105` | [[jetstream-sizing]] |
| `max_subscriptions` | **unlimited** (`0` means unlimited) | docs: [[s-docs-sizing-and-resources]], [[s-docs-connection-limits-config]] | — |
| TLS handshake timeout | `2s` | `const.go:108` | — |
| authorization timeout | `2s` | `const.go:117` | — |
| ping interval | `2m` | `const.go:120` | — |
| max pings outstanding | `2` | `const.go:123` | — |
| **`write_deadline`** | **`10s`** (`DEFAULT_FLUSH_DEADLINE`) | `const.go:132` | [[slow-consumer-detected]] |
| max closed clients retained | `10000` | `const.go:192` | — |

### The 8 MB question

`max_payload` has **two** numbers and they are different things
(source: [[s-nats-server-constants-2.14.6]]):

- **1 MB** is the default.
- **64 MB** is the documented ceiling — "`max_payload` can be set up to 64MB"
  (source: [[s-docs-connection-limits-config]]).
- **8 MB is a warning threshold, not a limit.** Above it the server logs, at startup:

  ```
  Maximum payloads over 8.0MB are generally discouraged and could lead to poor performance
  ```

  and keeps running (`server/server.go:2342`). The constant's own comment adds: *"In the future, the
  server may enforce/reject max_payload above this value."*

**`max_payload` must be `≤ max_pending`, and the server refuses to start otherwise**
(source: [[s-docs-sizing-and-resources]]). With the defaults, 1 MB against 64 MB, there is a lot of
headroom — but `max_pending` **requires a restart** to change while `max_payload` is **hot
reloadable**, so raising the payload ceiling past 64 MB is a two-stage change.

## JetStream — server

| setting | default | source | explained by |
|---|---|---|---|
| **`jetstream.sync_interval`** | **`2m`** | `filestore.go:333`; docs agree | [[replicas]] |
| `jetstream.max_memory_store` | **75% of system RAM**, capped by `GOMEMLIMIT`; falls back to `256MB` only when system memory cannot be read | [[s-docs-sizing-and-resources]] | [[jetstream-sizing]] |
| `jetstream.max_file_store` | **75% of disk available under `store_dir`**; falls back to `1TB` only when the platform cannot report disk size | [[s-docs-sizing-and-resources]] | [[jetstream-sizing]] |
| `jetstream.store_dir` | `/tmp/nats/jetstream` | docs config reference | — |
| `jetstream.strict` | **`true` since 2.12** — invalid API requests are rejected, not just logged | [[s-docs-upgrade-to-2.12]] | [[js-api]] |
| filestore cache buffer expiration | `10s` | `filestore.go:331` | — |
| filestore idle FD close | `30s` | `filestore.go:335` | — |

**`256MB` and `1TB` are fallbacks, not defaults.** They apply only when the server cannot read the
system's memory or disk size. This is the most commonly mis-stated pair of numbers in NATS sizing.

## Stream configuration

Defaults from the generated `StreamConfig` schema unless a line reference is given
(source: [[s-docs-stream-config]]).

| field | default | range |
|---|---|---|
| `retention` | `limits` | `limits` \| `interest` \| `workqueue` |
| `storage` | `file` | `file` \| `memory` |
| `num_replicas` | `1` | **min 1, max 5** |
| `discard` | `old` | `old` \| `new` |
| `compression` | `none` | `none` \| `s2` |
| `max_msgs` | `-1` (unlimited) | |
| `max_msgs_per_subject` | `-1` | |
| `max_bytes` | `-1` | |
| `max_age` | `0` (unlimited) | **must be ≥ `100ms` if set** (`stream.go:1746`) |
| `max_msg_size` | `-1` | signed 32-bit, max `2147483647` |
| `max_consumers` | `-1` | |
| **`duplicate_window`** | schema says `0` = "use default"; **the server substitutes `2m`** | `stream.go:1658` |
| `persist_mode` | `""` (server default) | `""` \| `default` \| `async` |
| `no_ack`, `sealed`, `deny_delete`, `deny_purge`, `allow_rollup_hdrs`, `allow_direct`, `mirror_direct`, `allow_atomic`, `allow_batched`, `allow_msg_counter`, `allow_msg_schedules`, `allow_msg_ttl`, `discard_new_per_subject`, `pedantic` | all `false` | |
| `description` | — | max 4096 characters |
| `name` | — | pattern `^[^.*>]*$` |

### When the 2-minute duplicate window applies

`StreamDefaultDuplicatesWindow` is used **only** when the stream sets no window of its own **and is
neither a mirror nor a source** — `if cfg.Duplicates == 0 && cfg.Mirror == nil &&
len(cfg.Sources) == 0` (`stream.go:1750`). It is then clamped down by the account or server
`Duplicates` limit if that is lower, and by `max_age` if `max_age` is smaller. **In pedantic mode
both clamps become errors instead of silent adjustments**
(source: [[s-nats-server-constants-2.14.6]]).

## Consumer configuration

`ConsumerConfig` defaults are **not readable from the docs** — the reference renders the config
object as a collapsed schema node (source: [[s-docs-consumer-config]]). These come from the source
at v2.14.6 (source: [[s-nats-server-constants-2.14.6]]) and are corroborated by the learn pages.

| field | CLI flag | default | source |
|---|---|---|---|
| **`ack_wait`** | `--wait` | **`30s`** — explicit-ack consumers only | `consumer.go:573` |
| **`max_deliver`** | `--max-deliver` | **`-1`** (unlimited) | `consumer.go:589–593` |
| **`max_ack_pending`** | `--max-pending` | **`1000`** — for explicit-ack consumers that set none | `consumer.go:580` |
| `inactive_threshold` (ephemerals) | | **`5s`** before a non-durable consumer is deleted | `consumer.go:576` |
| flow-control max pending | | `32 MB` | `consumer.go:578` |
| **`PriorityTimeout`** | | **`2m`** — grace period before the server picks a new pinned client | `consumer.go:582` |
| `ack_policy` | `--ack` | `explicit` in the docs' walkthrough | [[s-docs-acknowledgment]] |
| `deliver_policy` | `--deliver` | `all` | [[s-docs-policies]] |
| `replay_policy` | | `instant` | [[s-docs-policies]] |
| `priority_policy` | | `none` | [[s-docs-policies]] |
| pull `expires` | | **client-side ~30s**; `0` on the wire never times out | [[s-docs-pull-consumers]] |

In **pedantic mode**, a `max_deliver` below `-1` is an error rather than being corrected to `-1`.

## Cluster and RAFT

| behaviour | value | source |
|---|---|---|
| leader heartbeat | "about once a second" | [[s-docs-raft-and-leaders]] |
| election timer | **4–9 seconds** after the last heartbeat, staggered | [[s-docs-raft-and-leaders]] |
| quorum | `(N+1)/2` | [[s-docs-raft-and-leaders]] |
| `connect_backoff` (routes/gateways, 2.12+) | when `true`: **1s growing to 30s** | [[s-docs-upgrade-to-2.12]] |

## Guidance thresholds — not server limits

These are recommendations from Synadia, explicitly **not enforced by the server**, and the source
states neither the version they were measured against nor the method
(source: [[s-synadia-jetstream-anti-patterns]]).

| guidance | value |
|---|---|
| total consumers before instability becomes likely | **~100,000** |
| disjoint subject filters on one consumer | **~300** |
| CPU headroom above steady state | **20–30%** ([[s-docs-sizing-and-resources]]) |
| file descriptors per stream | **~2** ([[s-docs-sizing-and-resources]]) |
| `max_pending` relative to peak message size | **≥ 10×** ([[s-docs-sizing-and-resources]]) |

## How this was derived

- **Source values** were read from `nats-io/nats-server` at tag **v2.14.6**, files
  `server/const.go`, `server/consumer.go`, `server/stream.go`, `server/filestore.go` and
  `server/server.go`. The exact quoted line ranges are stored verbatim in
  `raw/nats-server-src/constants-v2.14.6.md`, so each row links to
  `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.
  To regenerate: fetch those files at the new tag and re-read the constants.
- **Schema values** come from `raw/nats-docs/reference/jetstream/api/stream/create.md`, the
  generated `StreamConfig` reference in the docs' 2.14 tree.
- **Docs-only values** (the JetStream storage percentages, `max_subscriptions`, the CPU and FD rules
  of thumb) come from `raw/nats-docs/learn/deployment/sizing-and-resources.md` and
  `raw/nats-docs/reference/config/`.
- **A value stated by neither is absent from this page**, not guessed.

## What is deliberately not here

- **Consumer `ConsumerConfig` fields with no named constant and no docs statement.** Only the ones
  above are established.
- **Account and tier limits** (`MaxMemory`, `MaxStore`, `MaxStreams`, `MaxConsumers`) — these have no
  universal default; they come from the account or its JWT. Read them live with
  `nats account info` ([[jetstream-sizing]]).
- **Per-block config keys** — the full 621-key table with type and reload behaviour is
  [[config-keys]] and `inbox/config-keys-table.md`.

## Related

[[config-keys]] · [[jetstream-sizing]] · [[stream]] · [[consumer]] · [[ack-and-redelivery]] ·
[[replicas]] · [[priority-groups]] · [[slow-consumer-detected]] · [[js-api]]

## Sources

[[s-nats-server-constants-2.14.6]] · [[s-docs-stream-config]] · [[s-docs-sizing-and-resources]] ·
[[s-docs-connection-limits-config]] · [[s-docs-acknowledgment]] · [[s-docs-pull-consumers]] ·
[[s-docs-policies]] · [[s-docs-raft-and-leaders]] · [[s-docs-upgrade-to-2.12]] ·
[[s-synadia-jetstream-anti-patterns]] · [[s-docs-consumer-config]]
