---
title: NATS Streaming (STAN) — deprecated
type: entity
kind: repo
area: [jetstream]
deprecated: true
verified-against: nats-streaming-server v0.25.6
verified-on: 2026-08-31
tags: [repo, deprecated, archived, stan, nats-streaming, jetstream-replacement]
aliases: [stan, nats-streaming, nats streaming, "nats-io/nats-streaming-server", nats-streaming-server]
sources: [s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# NATS Streaming (STAN) — deprecated

**Dead, archived, and replaced by JetStream.** NATS Streaming was a separate server process that
added persistence on top of core NATS. It is kept as a page here only so that a search for "STAN"
lands on the replacement instead of on a 2019 tutorial.

> **The replacement is [[stream]] — JetStream, built into [[nats-server]].**

## Facts

| | |
|---|---|
| repo | `nats-io/nats-streaming-server` — **archived** |
| last release | **v0.25.6**, **2023-11-17** |
| licence | Apache-2.0 |
| deprecation notice | "Critical bug fixes and security fixes will be applied **until June of 2023**" |
| replacement | JetStream, in the same binary as the server |
| docs | moved to a "legacy NATS docs" space; not part of docs.nats.io |

## What an operator needs to know

- **Support ended before the archive did.** The README's window — critical fixes until June 2023 —
  has passed, and the repository is archived, so nothing further will ship, including security fixes.
- **It was a separate process; JetStream is not.** Migrating is not a version upgrade: STAN channels
  become [[stream]]s, STAN durable subscriptions become [[consumer]]s, and the client API changes
  entirely. There is no in-place path.
- **The C client can still be built with Streaming support** ([[nats-c]]), which is compatibility,
  not endorsement.
- **"STAN" still appears in old blog posts and Stack Overflow answers.** Anything that mentions
  `stan.Connect`, channels, or a separate streaming binary is about this system and does not apply to
  JetStream.

## Related

[[stream]] · [[consumer]] · [[nats-server]] · [[nats-c]] · [[retention-policies]]

## Sources

[[s-github-repo-facts]]
