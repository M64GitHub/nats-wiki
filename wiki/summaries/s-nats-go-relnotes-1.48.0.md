---
title: "nats.go v1.48.0 — release body"
type: summary
area: [clients, core]
source-url: https://github.com/nats-io/nats.go/releases/tag/v1.48.0
source-path: raw/github-repos/nats-io__nats.go.release-v1.48.0.md
author: nats-io (nats.go maintainers)
article: "the v1.48.0 release body, 2025-12-17"
date: 2025-12-17
version: "nats.go v1.48.0"
tags: [nats-go, release, publish-subject-validation, whitespace, kv, subject-transforms]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats.go v1.48.0 — release body

One release of the Go client, read for one line: the one that dates the docs' "nats.go before v1.48.0"
claim about publish-side subject checking.

## Key claims

- **Added, Core NATS**: "Add publish subject validation and a connection option to skip it (#1974,
  #1979)". Before this release the Go client wrote whatever subject it was given into the `PUB` line,
  so a space inside a subject reached the server and was misrouted ([[s-nats-server-core-delivery-observed]]
  run A2 shows what the server does with it); from v1.48.0 the client refuses it first, and an option
  turns the check off.
- Also in the release: custom subject transforms on KV sourcing (#1960); `QueueSubscribe` when a
  `DeliverGroup` is configured on a push consumer (#1966); a data race on closing a KV watcher's updates
  channel (#1965).

## Practical takeaways

- A Go service on a client older than v1.48.0 (2025-12-17) can publish a malformed subject; the server
  will not stop it. Upgrade, or validate subjects in the application.

## Relevance to the wiki

Dates the client-side check on [[subjects-and-wildcards]] and the *What bites you* note on [[nats-go]].

## Questions it answers

169 (the client side of the whitespace rule).

## Pages touched

[[nats-go]] · [[subjects-and-wildcards]]
