---
title: "nats-server v2.14.6 — server constants"
type: summary
area: [core, jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/constants-v2.14.6.md
author: nats-io/nats-server maintainers
article: "server/const.go, consumer.go, stream.go, filestore.go, server.go at tag v2.14.6"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [defaults, constants, source, max_payload, ack_wait, duplicate_window]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — server constants

Read directly from the tagged source, because several defaults this wiki needs are stated
**nowhere in the docs**. Each value below carries its file and line at **v2.14.6**, and the quoted
ranges are stored verbatim in `raw/nats-server-src/constants-v2.14.6.md`.

## Core server — `server/const.go`

| constant | value | line |
|---|---|---|
| `DEFAULT_PORT` | `4222` | 78 |
| `DEFAULT_HOST` | `"0.0.0.0"` | 86 |
| `MAX_CONTROL_LINE_SIZE` | `4096` | 90 |
| **`MAX_PAYLOAD_SIZE`** | `(1024 * 1024)` = **1 MB** | 94 |
| **`MAX_PAYLOAD_MAX_SIZE`** | `(8 * 1024 * 1024)` = **8 MB** | 99 |
| **`MAX_PENDING_SIZE`** | `(64 * 1024 * 1024)` = **64 MB** | 102 |
| **`DEFAULT_MAX_CONNECTIONS`** | `(64 * 1024)` = **65,536** | 105 |
| `TLS_TIMEOUT` | `2 * time.Second` | 108 |
| `AUTH_TIMEOUT` | `2 * time.Second` | 117 |
| `DEFAULT_PING_INTERVAL` | `2 * time.Minute` | 120 |
| `DEFAULT_PING_MAX_OUT` | `2` | 123 |
| **`DEFAULT_FLUSH_DEADLINE`** | `10 * time.Second` | 132 |
| `DEFAULT_HTTP_PORT` | `8222` | 135 |
| `DEFAULT_MAX_CLOSED_CLIENTS` | `10000` | 192 |

## What the 8 MB `max_payload` figure actually is

The docs say values over 8MB are "not recommended" without saying what happens. The source says
exactly what happens — **a startup warning, and nothing else**
(`server/server.go:2342`):

```go
if opts.MaxPayload > MAX_PAYLOAD_MAX_SIZE {
    s.Warnf("Maximum payloads over %v are generally discouraged and could lead to poor performance",
        friendlyBytes(int64(MAX_PAYLOAD_MAX_SIZE)))
}
```

and the constant's own comment (`const.go:96–98`) records the intent:

```go
// MAX_PAYLOAD_MAX_SIZE is the size at which the server will warn about
// max_payload being too high. In the future, the server may enforce/reject
// max_payload above this value.
```

So: **8 MB is a warning threshold, not a limit, as of 2.14.6** — and the comment flags that a future
server may start rejecting above it.

## JetStream consumer — `server/consumer.go`

| constant | value | line |
|---|---|---|
| **`JsAckWaitDefault`** | `30 * time.Second` — "only applicable on explicit ack policy consumers" | 573 |
| `JsDeleteWaitTimeDefault` | `5 * time.Second` — how long a **non-durable** consumer may be inactive before deletion | 576 |
| `JsFlowControlMaxPending` | `32 * 1024 * 1024` = 32 MB | 578 |
| **`JsDefaultMaxAckPending`** | `1000` — "set for consumers with explicit ack that do not set the max ack pending" | 580 |
| **`JsDefaultPinnedTTL`** | `2 * time.Minute` — "the default grace period for the pinned consumer to send a new request before a new pin is picked by a server" | 582 |

`MaxDeliver` has no named constant; the default is applied in `setConsumerConfigDefaults`
(`consumer.go:589–593`):

```go
// Setup default of -1, meaning no limit for MaxDeliver.
if config.MaxDeliver == 0 || config.MaxDeliver < -1 {
    if pedantic && config.MaxDeliver < -1 {
        return NewJSPedanticError(errors.New("max_deliver must be set to -1"))
    }
    config.MaxDeliver = -1
}
```

Note the pedantic-mode branch: with `pedantic` on, a `max_deliver` below `-1` is an **error**
rather than being corrected.

## JetStream stream — `server/stream.go`

| constant | value | line |
|---|---|---|
| **`StreamDefaultDuplicatesWindow`** | `2 * time.Minute` | 1658 |

It is applied only when the stream sets no window of its own and is neither a mirror nor a source
(`stream.go:1750`): `if cfg.Duplicates == 0 && cfg.Mirror == nil && len(cfg.Sources) == 0`. The
resulting window is then clamped down by the account/server `Duplicates` limit if that is lower, and
by `MaxAge` if `MaxAge` is smaller — in pedantic mode both clamps become errors instead.

## Filestore — `server/filestore.go`

| constant | value | line |
|---|---|---|
| **`defaultSyncInterval`** | `2 * time.Minute` | 333 |
| `defaultCacheBufferExpiration` | `10 * time.Second` | 331 |
| `closeFDsIdle` | `30 * time.Second` | 335 |

## What this settles

Four values this wiki previously carried as unresolved or second-hand are now confirmed against the
tagged source:

- **`duplicate_window` defaults to 2 minutes** — the `StreamConfig` schema only says "0 for default"
  and the number came from a Synadia blog post dated 2025-08-08
  ([[s-synadia-jetstream-memory-patterns]]). Confirmed at `stream.go:1658` on 2.14.6.
- **`write_deadline` defaults to 10 seconds** (`DEFAULT_FLUSH_DEADLINE`), which is exactly the `10s`
  in the slow-consumer log line of [[s-gh-6605-which-consumer-is-slow]].
- **What "8MB not recommended" means**: a startup warning, not an enforced limit.
- **`PriorityTimeout` has a server default of 2 minutes** (`JsDefaultPinnedTTL`), which ADR-42 only
  showed as an example value ([[s-adr-42-priority-groups]]).

## Caveat

These are the **compiled-in defaults**. A running server reports what it actually has via `/varz`
and `nats server info`, and account-level limits or an account JWT can be lower. Read the live value
before sizing against any of them — see [[jetstream-sizing]].

## Questions it answers

Q12 (what the real `max_payload` limit is and what happens above 8MB), Q16 in part (the duplicate
window's actual default), Q23 in part (same).

## Pages touched

[[defaults-and-limits]] · [[stream]] · [[consumer]] · [[ack-and-redelivery]] ·
[[priority-groups]] · [[slow-consumer-detected]] · [[jetstream-sizing]]
