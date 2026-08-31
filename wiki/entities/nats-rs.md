---
title: nats.rs
type: entity
kind: client
area: [clients, jetstream]
verified-against: async-nats v0.50.0
verified-on: 2026-08-31
tags: [client, tier-1, rust, async-nats, tokio, chrono, deprecated-crate]
aliases: [nats.rs, "nats-io/nats.rs", rust client, async-nats]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started]
created: 2026-08-31
updated: 2026-08-31
---

# nats.rs

The **Rust client**. The crate to use is **`async-nats`**, Tokio-based; the repo also holds a
deprecated synchronous `nats` crate (source: [[s-docs-ecosystem]], [[s-github-repo-facts]]).

## Where it fits

Tier 1, and the client whose README states the **core-vs-[[orbit]] contract** most explicitly — this
wiki cites it for that boundary across all languages.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.rs` |
| tier | **1** |
| latest release | **`async-nats/v0.50.0`**, 2026-07-20 |
| licence | Apache-2.0 |
| crate | **`async-nats`** (docs.rs/async-nats) |
| deprecated crate | `nats` — "only receives critical security fixes" |
| coverage | Core NATS, JetStream, JetStream management, KV, Object Store, Service API |

```toml
[dependencies]
async-nats = "0.50"
tokio = { version = "1", features = ["full"] }
```

The docs' install snippet pins `async-nats = "0.47.0"` (source: [[s-docs-getting-started]]).

## What an operator needs to know

- **0.x versioning does not mean unstable.** "The API is stable, however it remains on 0.x.x
  versioning, as async ecosystem is still introducing a lot of ergonomic improvements." Some
  dependencies (`rustls` is named) are themselves pre-1.0 and can break consumers.
- **A `chrono` feature flag anywhere poisons the whole build.** JetStream and Service datetime fields
  use `time::OffsetDateTime` by default; the optional `chrono` feature switches them to
  `chrono::DateTime<Utc>`. "Because Cargo unifies features across the whole dependency graph,
  enabling `chrono` *anywhere* in the graph selects it for every consumer of `async-nats` in that
  build" — so an unexplained `time` vs `chrono` type mismatch means some dependency turned it on.
  This is the single most operator-visible Rust-specific trap in the client.
- **The `nats` crate is a dead end.** New work goes to `async-nats`; the old crate gets security
  fixes only.

## The core / Orbit boundary, in this client's words

| concern | core (`async-nats`) | Orbit |
|---|---|---|
| connect, publish, subscribe, request/reply | ✅ | |
| JetStream publish, consumers, streams, KV, OS | ✅ | |
| Service API | ✅ | |
| wire protocol, auth, TLS, reconnection | ✅ | |
| cross-client parity, conservative semver | ✅ | |
| opinionated helpers, experimental patterns | | ✅ |
| KV codecs, distributed counters, contexts | | ✅ |
| per-utility versioning, faster churn | | ✅ |

> "If it is a thin mapping of something `nats-server` already speaks and every official client must
> expose it, it belongs in core. If it is a pattern, helper, or abstraction layered on top, it
> belongs in Orbit."

## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[key-value]] · [[object-store]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]]
