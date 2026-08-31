---
title: "docs.nats.io — max_payload, max_pending, max_connections, max_subscriptions"
type: summary
area: [core, deploy]
source-url: https://docs.nats.io/reference/config/max_payload.md
source-path: raw/nats-docs/reference/config/max_payload.md
author: NATS documentation (Synadia Communications, Inc.) — generated config reference
article: "reference/config: max_payload, max_pending, max_connections, max_subscriptions"
date: 2026-08-31          # the pages are undated; this is the fetch date
version: "2.14"
tags: [max_payload, max_pending, max_connections, max_subscriptions, reload]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — the four connection and payload limit keys

Four per-key pages of the generated config reference, ingested together because
[[jetstream-sizing]] states values for all of them. Companion pages:
`reference/config/max_pending.md`, `max_connections.md`, `max_subscriptions.md`.

## Key claims

| key | aliases | reload | what the reference says |
|---|---|---|---|
| `max_payload` | — | **hot reloadable** | Maximum number of bytes in a message payload. **"It is not recommended to use values over 8MB but `max_payload` can be set up to 64MB."** Applies to client and leafnode payloads. **"The max payload must be equal or smaller to the `max_pending` value."** Reducing it may force chunking in clients. |
| `max_pending` | — | **requires restart** | Maximum number of bytes buffered for a connection. Applies to client connections. Applications can also set `PendingLimits` (message count and total size) for their subscriptions. |
| `max_connections` | `max_conns` | **hot reloadable** | Maximum number of active client connections. |
| `max_subscriptions` | `max_subs` | **requires restart** | Per-client limit — maximum subscriptions per client and per leafnode account connection. **`0` means unlimited.** Explicitly: *"the per-account `max_subscriptions` under `accounts` is a different key and does reload."* |

**None of these four pages states a default value.** The defaults quoted elsewhere in this wiki —
`max_payload` 1 MB, `max_connections` 64K (65,536), `max_subscriptions` unlimited — come from
`learn/deployment/sizing-and-resources.md` ([[s-docs-sizing-and-resources]]), not from the
reference.

## Practical takeaways

- **`max_payload` has a hard ceiling of 64MB and a recommended ceiling of 8MB.** The two are
  different numbers and the reference is explicit about both.
- **`max_payload` > `max_pending` prevents the server from starting** (stated on the sizing page;
  the reference states only the `≤` constraint).
- **`max_payload` reloads; `max_pending` does not.** Raising `max_payload` toward `max_pending` is
  a hot change, but making room by raising `max_pending` first requires a restart — so the two
  halves of that change land differently.
- The per-client and per-account `max_subscriptions` are **different keys with different reload
  behaviour**; naming the block matters.

## Relevance to the wiki

Grounds the payload and connection limits [[jetstream-sizing]] states, and supplies the real answer
to "what is the actual `max_payload` limit" — a question the docs' prose pages only gesture at.

## Questions it answers

Q12 (what breaks above 8MB and what the real limit is), Q55 in part (three of these four keys carry
an explicit reload marker, and one carries an explicit warning that a same-named key in another
block behaves differently).

## Pages touched

[[jetstream-sizing]] · [[config-keys]]
