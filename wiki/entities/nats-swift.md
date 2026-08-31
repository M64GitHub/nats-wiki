---
title: nats.swift
type: entity
kind: client
area: [clients, core]
verified-against: nats.swift v0.4.0
verified-on: 2026-08-31
tags: [client, tier-2, swift, ios, macos, core-nats-only, no-jetstream]
aliases: [nats.swift, "nats-io/nats.swift", swift client]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nats.swift

The **Swift client** — "iOS, macOS, and server-side Swift" (source: [[s-docs-ecosystem]]). The one
official client that is **Core NATS only**: no JetStream, no KV, no Object Store, no Services.

## Where it fits

Tier 2, and the sharpest illustration of why tier is a support statement rather than a capability
one. An architecture that assumes "every official client speaks JetStream" is wrong here.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.swift` |
| tier | **2** |
| latest release | **v0.4.0**, **2024-10-31** — the oldest current release of any non-legacy official client |
| licence | Apache-2.0 |
| supported | **Core NATS** with auth, TLS, lame duck mode |
| on the roadmap, not shipped | **JetStream, KV, Object Store, Service API** |
| install | Swift Package Manager, `.package(name: "Nats", url: "https://github.com/nats-io/nats.swift.git", from: "0.1")` |
| support channel | `#swift` on the NATS Slack |

## What an operator needs to know

- **Design around it, not with it.** A mobile or Apple-platform client using this library can publish
  and subscribe on core subjects. Anything durable — a stream, a KV bucket, an ack — has to be done
  by a service on the other side of a subject, not by the device.
- **It does handle lame duck mode**, so a rolling upgrade will not strand connections; that is the
  one operations-facing feature the README names.
- **The release date is the fact to re-check.** v0.4.0 is from 2024-10-31; the roadmap items above
  are what the README claimed as of 2026-08-31. Re-run `tools/fetch-repo-facts.py --refresh` before
  relying on the gap list.

## Related

[[nats-zig]] · [[nats-js]] · [[nats-server]] · [[stream]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
