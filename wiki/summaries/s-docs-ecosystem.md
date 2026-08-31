---
title: "docs.nats.io — The NATS Ecosystem"
type: summary
area: [clients, deploy, monitoring, security]
source-url: https://docs.nats.io/concepts/ecosystem.md
source-path: raw/nats-docs/concepts/ecosystem.md
author: NATS documentation (Synadia Communications, Inc.)
article: The NATS Ecosystem
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [ecosystem, clients, tiers, orbit, tooling, nkeys, jwt, kubernetes, bridges]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — The NATS Ecosystem

The docs' own map of everything around the `nats-server` binary: which clients are official and how
far behind they may lag, which CLI and Kubernetes tools are maintained, and where the identity
libraries live. It is the **naming authority** for this wiki's entity pages — every client and tool
page here exists because this page lists it.

## Key claims

**The server is one binary.** Clustering, JetStream, leafnodes, MQTT and WebSocket "are all enabled
through configuration on the same `nats-server` — there are no separate components to install."

**Clients come in three categories, not two.**

| category | definition, verbatim | members |
|---|---|---|
| **Tier 1** | "Synadia-maintained, track new server features at release" | `nats.go` (Go, "Reference implementation"), `nats.js` (JS/TS), `nats.py` (Python), `nats.java` (Java), `nats.rs` (Rust, "The `async-nats` crate"), `nats.net` (C#/.NET), `nats.c` (C) |
| **Tier 2** | "Synadia-maintained, may lag behind on new server features" | `nats.zig`, `nats.swift`, `nats-pure.rb`, `nats.rb` (legacy), `nats.ex` |
| **community** | third-party | "Crystal, Dart, Kotlin, and PHP" among others — "These docs do not cover community clients." |

- Tier 1 is defined by release cadence: "the ones the NATS team ships first when a new server
  feature lands. If a tier 1 client is available for your language, prefer it."
- Tier 2 is "Production-ready for the features they do cover; check each repo's README for current
  feature coverage" — the docs explicitly delegate feature coverage to the repos.
- Per-client notes given: `nats.js` "Node, Deno, Bun, browser (WebSocket). Supersedes the archived
  `nats.node`, `nats.deno`, `nats.ws`, `nats.ts`"; `nats.py` "asyncio-based, Python 3 only";
  `nats.java` "JVM; usable from Kotlin and Scala"; `nats.net` "**.NET 6+**. Modern async client";
  `nats.c` "Embedded systems and FFI consumers"; `nats-pure.rb` "Pure Ruby — preferred Ruby
  client"; `nats.rb` "EventMachine-based; use `nats-pure.rb` for new code"; `nats.ex` "Replaces the
  archived `elixir-nats`".

**Orbit is a separate org and a separate contract.** The `synadia-io/orbit.*` repos hold "optional
higher-level utilities and experimental features built on top of the matching tier 1 client. Pull in
only the modules you need." Typical contents: "extra JetStream helpers (request-many, batch publish,
scheduled messages), partitioned consumer groups, encoded KV / KV codecs, distributed counters, and
retry / chaos utilities. Successful patterns may eventually graduate into the core client. Exact
module set differs per language." Seven repos, one per tier 1 language.

**Tooling.**

- `natscli` — "The everyday `nats` CLI. Publish, subscribe, manage streams and consumers, inspect a
  running server, manage operators, accounts, and users with `nats auth`. Most examples in these
  docs use it."
- `nats-top` — "`top`-style live view of server activity."
- `nats-box` — "Container image bundling the common NATS utilities (`nats`, `nsc`, `nk`) for ad-hoc
  shells in Kubernetes."
- `nsc` — "Standalone CLI for managing operators, accounts, and users. An alternative to the
  `nats auth` commands built into the `nats` CLI; **reads the same on-disk store** and covers
  operations `nats auth` doesn't yet."
- `synadia-io/jwt-auth-builder.go` (programmatic account/user builder), `synadia-io/callout.go` and
  `synadia-io/callout.net` (auth-callout SDKs).
- NKey libraries in 8 languages (`nkeys`, `nkeys.js`, `.java`, `.net`, `.py`, `.rb`, `.swift`,
  `.ex`); JWT libraries in 4 (`jwt`, `jwt.js`, `jwt.java`, `jwt.net`).

**Kubernetes and observability.**

- `nats-io/k8s` — "Official Helm charts for deploying `nats-server` clusters, surveyor, and related
  components."
- `nats-io/nack` — "Kubernetes controllers and CRDs for managing JetStream streams, consumers, and
  KV / Object stores declaratively."
- `prometheus-nats-exporter` — "Prometheus exporter for `varz`, `connz`, `routez`, and JetStream
  stats."
- `nats-surveyor` — "Cluster-wide monitoring; aggregates stats across servers … Pairs with the
  exporter for full-cluster observability."

**Schemas.** `nats-io/jsm.go` is the "Canonical source of JetStream API JSON schemas used by tooling
and the reference docs in this site" — i.e. the docs' own `reference/jetstream/` tree is generated
from it. It also ships a Go JetStream management library "with a different API surface" from
`nats.go`.

**Bridges.** `nats-kafka`, `nats-spark-connector`, `synadia-io/flink-connector-nats`,
`nats-java-vertx-client`, `terraform-provider-jetstream`.

## Practical takeaways

- **Tier is a support statement, not a quality one.** The question a tier 2 client raises for an
  operator is "will it have the feature my server version just gained", and the docs answer: maybe
  not, read the repo.
- **The docs delegate feature coverage to the READMEs**, which is why this wiki's client pages carry
  the coverage claims read from those READMEs (see [[s-github-repo-facts]]) rather than from here.
- **`nsc` and `nats auth` share one store**, so the choice between them is per-command, not
  per-deployment.

## Notable quotes

> "If a tier 1 client is available for your language, prefer it."

> "Successful patterns may eventually graduate into the core client."

## Relevance to the wiki

This is the source of record for **who is official**. Everything in `wiki/entities/` under
`kind: client` and `kind: tool` traces its existence and its tier to this page; the versions, licences
and feature coverage come from [[s-github-repo-facts]], because this page states none of them.

## Questions it answers

Q67 partly (which client reaches a cluster) — indirectly. Its main job is scope, not question rows.

## Pages touched

[[nats-go]] · [[nats-js]] · [[nats-py]] · [[nats-java]] · [[nats-rs]] · [[nats-net]] · [[nats-c]] ·
[[nats-zig]] · [[nats-swift]] · [[nats-pure-rb]] · [[nats-rb]] · [[nats-ex]] · [[orbit]] ·
[[nats-cli]] · [[nsc]] · [[nk]] · [[nats-top]] · [[nats-box]] · [[prometheus-nats-exporter]] ·
[[nats-surveyor]] · [[nats-helm-charts]] · [[nack]] · [[jsm-go]] · [[nats-server]] · [[synadia]]
