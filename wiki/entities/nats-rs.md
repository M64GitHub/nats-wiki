---
title: nats.rs
type: entity
kind: client
area: [clients, jetstream]
verified-against: async-nats v0.50.0
verified-on: 2026-09-04
tags: [client, tier-1, rust, async-nats, tokio, chrono, deprecated-crate]
aliases: [nats.rs, "nats-io/nats.rs", rust client, async-nats]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-client-releases-and-issues, s-docs-resilient-clients-drain-and-shutdown, s-docs-resilient-clients-reconnection-and-events]
created: 2026-08-31
updated: 2026-09-04
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


## What bites you

The `chrono` trap above is the build-time one. These are the run-time ones, read from the last ten
releases (`async-nats/v0.44.0` 2025-10-02 → `v0.50.0` 2026-07-20) and the open issues at 2026-09-04
(source: [[s-client-releases-and-issues]]), with the documented per-client behaviours marked as the
documentation's word (source: [[s-docs-resilient-clients-drain-and-shutdown]],
[[s-docs-resilient-clients-reconnection-and-events]]).

- **`client.flush()` is not a delivery confirmation.** It "resolves once the buffered writes have
  reached the socket, without waiting for the server's PONG", unlike every other client's flush —
  it confirms the bytes left the process, not that the server has them. And there is **no RTT probe**
  at all (the documentation's word). A Rust service that flushes before exiting has not established
  that anything arrived — [[client-connection-lifecycle]].
- **`subscription_capacity` is one number for the whole connection**, not per subscription: 65,536
  messages, set on the connect options. Open issue **#1276** (2024-06-07) asks for per-subscription
  capacity, and **#1261** (2024-05-13) is titled "Hard to debug slow consumers with Rust client" —
  which is the operator-facing summary ([[slow-consumer-in-the-client]]).
- **Some publish paths did not check `max_payload` until v0.49.0** (2026-05-25): the release "adds
  missing client-side max-payload validations for some methods". Below it, an oversize message on
  those paths reached the server and came back as `-ERR 'Maximum Payload Violation'` with the
  connection closed, rather than as a client-side error — [[wire-protocol]].
- **Subject validation only since v0.47.0** (2026-03-31, #1525), with an opt-out —
  [[subjects-and-wildcards]].
- **An `unsubscribe_after` limit was lost across reconnects until v0.48.0** (#1560, "Preserve
  unsubscribe_after limit across reconnects"). An auto-unsubscribe of N messages silently became
  unbounded after a failover.
- **The ping interval did not reset correctly until v0.49.1** (#1594), and an ordered consumer was not
  recreated properly on server restart until the same release (#1599) — both squarely in the failover
  path, both within the last four months ([[consumer]]).
- **Reconnect grows its delay with no jitter and never gives up** (unlimited `max_reconnects`, the
  documentation's word) — so a Rust fleet reconnecting after a cluster restart is the one that
  synchronises its retries, and the one that never closes a connection you might have wanted closed.
- **Dropping a `Subscriber` outside a Tokio runtime panics.** Open issue **#1607** (2026-07-01) —
  it bites at shutdown, when the runtime is already gone.

## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[key-value]] · [[object-store]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-client-releases-and-issues]] · [[s-docs-resilient-clients-drain-and-shutdown]] · [[s-docs-resilient-clients-reconnection-and-events]]
