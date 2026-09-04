<!-- source: https://github.com/nats-io/nats.swift through the GitHub REST API (`gh api repos/nats-io/nats.swift/releases?per_page=10` and `gh api repos/nats-io/nats.swift/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.swift — the last 4 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v0.4.0` — v0.4.0 — published 2024-10-31

https://github.com/nats-io/nats.swift/releases/tag/v0.4.0

## Overview

This release introduces JetStream support, including:
- JetStream management API support (Streams and Consumers)
- Publishing messages to streams and getting/deleting individual messages
- Pull consumer support with `fetch()`

It also features reworked errors, all namespaced under `NatsError` and `JetStreamError`.

## What's Changed
* Add basic JetStream context by @Jarema in https://github.com/nats-io/nats.swift/pull/67
* Fix another promise leak by @mtmk in https://github.com/nats-io/nats.swift/pull/69
* Fixed websocket path by @mtmk in https://github.com/nats-io/nats.swift/pull/68
* Add jetstream request by @Jarema in https://github.com/nats-io/nats.swift/pull/71
* Add CRUD operation on streams by @piotrpio in https://github.com/nats-io/nats.swift/pull/72
* Additional stream APIs by @piotrpio in https://github.com/nats-io/nats.swift/pull/73
* Fixed missing public access modifiers by @piotrpio in https://github.com/nats-io/nats.swift/pull/74
* Add fetching individual messages from stream by @piotrpio in https://github.com/nats-io/nats.swift/pull/75
* Fix race in Connect by @piotrpio in https://github.com/nats-io/nats.swift/pull/77
* Add deleting messages and purging a stream by @piotrpio in https://github.com/nats-io/nats.swift/pull/76
* Refactor core nats errors by @piotrpio in https://github.com/nats-io/nats.swift/pull/78
* Change NatsSubscription to a throwing AsyncSequence by @piotrpio in https://github.com/nats-io/nats.swift/pull/79
* Refactor JetStream errors, add docs by @piotrpio in https://github.com/nats-io/nats.swift/pull/80
* Add queue subscribe by @piotrpio in https://github.com/nats-io/nats.swift/pull/81
* Add jetstream consumer management by @piotrpio in https://github.com/nats-io/nats.swift/pull/83
* Add fetching messages from JetStream by @piotrpio in https://github.com/nats-io/nats.swift/pull/87


**Full Changelog**: https://github.com/nats-io/nats.swift/compare/v0.3.0...v0.4.0

---

### `v0.3.0` — v0.3.0 — published 2024-04-17

https://github.com/nats-io/nats.swift/releases/tag/v0.3.0

## Overview

**This release introduces:**
- WebSocket support
- suspend & resume (useful for gracefully pausing consumer when IOS device goes to sleep & wakes up)
- force reconnect
- plain NKEYs (without JWT) support

## What's Changed
* Refactor buffering and clean up writes by @piotrpio in https://github.com/nats-io/nats.swift/pull/61
* add websocket support by @mtmk in https://github.com/nats-io/nats.swift/pull/62
* Add NKEY auth options by @Jarema in https://github.com/nats-io/nats.swift/pull/65
* Fix upgradePromise leak (thanks @dmaulikr for reporting!) by @mtmk in https://github.com/nats-io/nats.swift/pull/66
* Add suspend, resume and reconnect methods by @piotrpio in https://github.com/nats-io/nats.swift/pull/64


**Full Changelog**: https://github.com/nats-io/nats.swift/compare/v0.2.0...v0.3.0

---

### `v0.2.0` — Release 0.2.0 — published 2024-03-29

https://github.com/nats-io/nats.swift/releases/tag/v0.2.0

## Overview
This is a small release that lowers the IOS platform requirements to v13.

## What's Changed
* Refactor RttCommand to work with ios 13 by @piotrpio in https://github.com/nats-io/nats.swift/pull/60


**Full Changelog**: https://github.com/nats-io/nats.swift/compare/v0.1.0...v0.2.0

---

### `v0.1.0` — Release 0.1.0 — published 2024-03-19

https://github.com/nats-io/nats.swift/releases/tag/v0.1.0

## Overview

**This is the first release of our new NATS Swift client.**

It provides support for set of features around Core Nats:
* Pub / Sub
* Requst / Reply
* Auth methods, including username/passord, tokens, JWT and NKEYS
* TLS support
* Lame Duck Mode
* Event callbakcs
* Async API

The client leverages Swift Concurrency and NIO as base building blocks.

## Next Steps

Our goal is to deliver a feature-rich Swift client that offers full parity with other NATS clients.
Stay tuned for future releases that will bring performance enhancements, improved device compatibility, and features.

---

## Open issues at 2026-09-04 (14) — number, opened, title

- #123 — 2026-07-01 — Linux support: the official Swift client should run where Swift servers run
- #122 — 2026-07-01 — NatsClient abandoned mid-reconnect is never released (reconnect task and subscriptions retain the connection handler forever)
- #114 — 2026-03-09 — nats.swift — Community Roadmap Proposal
- #107 — 2026-02-18 — KV Store Support
- #106 — 2026-02-02 — Memory corruption crash in ConnectionHandler.channelReadComplete - ServerInfo deallocation on v0.4.0
- #102 — 2025-10-04 — Demo code does not run
- #100 — 2025-09-12 — Configuring an auth method and connecting to a server not requiring authentication causes crash
- #95 — 2025-08-25 — Small typo on Read.me code example
- #92 — 2025-08-04 — Random Crash
- #90 — 2025-04-13 — Push Based Consumers
- #82 — 2024-09-03 — Implement Swift Service Lifecycle
- #49 — 2024-03-15 — Have more fine grained errors
- #48 — 2024-03-15 — Consider exposing Client methods via protocols
- #43 — 2024-03-13 — Disallow creating Client instance without initializing connection
