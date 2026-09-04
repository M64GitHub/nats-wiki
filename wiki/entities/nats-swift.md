---
title: nats.swift
type: entity
kind: client
area: [clients, core, jetstream]
verified-against: nats.swift v0.4.0
verified-on: 2026-09-04
tags: [client, tier-2, swift, ios, macos, jetstream, no-kv, no-objectstore, no-services]
aliases: [nats.swift, "nats-io/nats.swift", swift client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-client-releases-and-issues]
created: 2026-08-31
updated: 2026-09-04
---

# nats.swift

The **Swift client** — "iOS, macOS, and server-side Swift" (source: [[s-docs-ecosystem]]). Core NATS
plus JetStream since v0.4.0; **no KV, no Object Store, no Services**. Its own README still says
JetStream is on the roadmap, which is wrong — see *What bites you*.

## Where it fits

Tier 2, and the sharpest illustration of why tier is a support statement rather than a capability
one: the gaps here are named per feature in the repo, not implied by the tier — and, as it turns out,
named wrongly.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.swift` |
| tier | **2** |
| latest release | **v0.4.0**, **2024-10-31** — the oldest current release of any non-legacy official client |
| licence | Apache-2.0 |
| supported | **Core NATS** with auth, TLS, lame duck mode, WebSocket, suspend/resume — **and JetStream** since v0.4.0: stream and consumer management, publish, get and delete individual messages, pull consumers with `fetch()` |
| the README says "on the roadmap" | **JetStream, KV, Object Store, Service API** — wrong for JetStream since 2024-10-31; see *What bites you* |
| genuinely absent | **KV, Object Store, Service API** |
| install | Swift Package Manager, `.package(name: "Nats", url: "https://github.com/nats-io/nats.swift.git", from: "0.1")` |
| support channel | `#swift` on the NATS Slack |

## What an operator needs to know

- **Design around it for KV and Object Store, not for JetStream.** A device can publish into a
  stream, manage streams and consumers, and pull with `fetch()` — the v0.4.0 release notes and the
  `Sources/JetStream/` tree both say so. A KV bucket or an object read still has to be done by a
  service on the other side of a subject.
- **It does handle lame duck mode**, so a rolling upgrade will not strand connections; that is the
  one operations-facing feature the README names.
- **The release date is the fact to re-check.** v0.4.0 is from 2024-10-31 — no release in nearly two
  years, so nothing the server added in 2.12 or 2.14 is exposed here. Re-run
  `tools/fetch-repo-facts.py --refresh` before relying on the gap list.


## What bites you

Read from its four release bodies (v0.1.0 2024-03-19 → v0.4.0 2024-10-31) and its open issues at
2026-09-04 (source: [[s-client-releases-and-issues]]).

- **The README understates the client by a whole subsystem.** It says "JetStream, KV, Object Store,
  Service API are on the roadmap"; the **v0.4.0** notes of 2024-10-31 say "This release introduces
  JetStream support, including: JetStream management API support (Streams and Consumers); Publishing
  messages to streams and getting/deleting individual messages; Pull consumer support with
  `fetch()`", and `Sources/JetStream/` exists at that tag and on the default branch. Two public
  statements from one project disagree and the README is the stale one — recorded as
  `inbox/docs-issues.md` #122. An architecture that ruled Swift out for JetStream on the README's
  word ruled it out wrongly.
- **An abandoned connection is never released.** Open issue **#122** (2026-07-01): "NatsClient
  abandoned mid-reconnect is never released (reconnect task and subscriptions retain the connection
  handler forever)". On an app that opens a connection per screen and drops it on dismissal, that is
  an unbounded leak of both memory and reconnect tasks — and the server sees the connections too, in
  `/connz` ([[monitoring-endpoints]]).
- **`suspend` and `resume` are the API this client exists for.** Added in **v0.3.0** (2024-04-17),
  "useful for gracefully pausing consumer when IOS device goes to sleep & wakes up". Without them a
  backgrounded app comes back to a connection the server already dropped — and reconnect storms from
  a fleet of phones waking together are a cluster-side problem, not a device-side one.
- **`force reconnect` and NKEY-without-JWT auth are also v0.3.0**; WebSocket arrived there too, which
  matters when the device's network only allows 443 ([[websocket]]).
- **No release in nearly two years.** Nothing from nats-server 2.11, 2.12 or 2.14 is exposed —
  per-message TTL, priority groups, batch publish, message schedules.

## Related

[[nats-zig]] · [[nats-js]] · [[nats-server]] · [[stream]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-client-releases-and-issues]]
