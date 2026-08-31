---
title: "GitHub — repo facts for every NATS client and tool"
type: summary
area: [clients, deploy, monitoring, security]
source-url: https://api.github.com/repos/nats-io/
source-path: raw/github-repos/
author: GitHub REST API v3 (repository metadata) and the repositories' own READMEs
article: 32 repositories — metadata and READMEs
date: 2026-08-31
version: "2.14"
tags: [clients, tools, releases, licences, feature-coverage, archived]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# GitHub — repo facts for every NATS client and tool

[[s-docs-ecosystem]] names the official clients and tools but states no version, licence or feature
coverage, and explicitly delegates coverage to "each repo's README". This is that reading: the
GitHub API record for all **32 repos** plus **24 READMEs**, fetched 2026-08-31 by
`tools/fetch-repo-facts.py` and stored verbatim under `raw/github-repos/`.

Everything here is a **dated snapshot**. A client's latest release moves; the shape of the facts
(who is archived, who covers JetStream) moves much more slowly.

## Key claims

### The record, as fetched

| repo | role | language | licence | archived | latest release | date |
|---|---|---|---|---|---|---|
| `nats-io/nats.go` | client, tier 1 | Go | Apache-2.0 | no | `v1.53.1` | 2026-08-11 |
| `nats-io/nats.js` | client, tier 1 | TypeScript | Apache-2.0 | no | `v3.4.0` | 2026-05-08 |
| `nats-io/nats.py` | client, tier 1 | Python | Apache-2.0 | no | `v2.15.0` | 2026-06-05 |
| `nats-io/nats.java` | client, tier 1 | Java | Apache-2.0 | no | `2.26.2` | 2026-08-13 |
| `nats-io/nats.rs` | client, tier 1 | Rust | Apache-2.0 | no | `async-nats/v0.50.0` | 2026-07-20 |
| `nats-io/nats.net` | client, tier 1 | C# | Apache-2.0 | no | `v3.2.0` | 2026-08-29 |
| `nats-io/nats.c` | client, tier 1 | C | Apache-2.0 | no | `v3.13.0` | 2026-06-01 |
| `nats-io/nats.zig` | client, tier 2 | Zig | Apache-2.0 | no | `v0.1.0` | 2026-04-28 |
| `nats-io/nats.swift` | client, tier 2 | Swift | Apache-2.0 | no | `v0.4.0` | 2024-10-31 |
| `nats-io/nats-pure.rb` | client, tier 2 | Ruby | Apache-2.0 | no | `v2.5.0` | 2025-02-21 |
| `nats-io/nats.rb` | client, tier 2 (legacy) | Ruby | Apache-2.0 | no | `v0.11.0` | **2019-06-11** |
| `nats-io/nats.ex` | client, tier 2 | Elixir | **MIT** | no | `v1.16.0` | 2026-07-10 |
| `nats-io/natscli` | tool | Go | Apache-2.0 | no | `v0.4.0` | 2026-05-01 |
| `nats-io/nsc` | tool | Go | Apache-2.0 | no | `v2.15.0` | 2026-06-02 |
| `nats-io/nkeys` | tool + library | Go | Apache-2.0 | no | `v0.4.16` | 2026-06-02 |
| `nats-io/nats-top` | tool | Go | **MIT** | no | `v0.6.4` | 2026-03-26 |
| `nats-io/nats-box` | tool | HCL | Apache-2.0 | no | `v0.19.7` | 2026-06-02 |
| `nats-io/prometheus-nats-exporter` | tool | Go | Apache-2.0 | no | `v0.20.2` | 2026-08-19 |
| `nats-io/nats-surveyor` | tool | Go | Apache-2.0 | no | `v0.9.11` | 2026-07-23 |
| `nats-io/k8s` | tool | Go | Apache-2.0 | no | `nats-2.14.6` | 2026-08-28 |
| `nats-io/nack` | tool | Go | Apache-2.0 | no | `v0.24.0` | 2026-08-18 |
| `nats-io/nats-server` | repo | Go | Apache-2.0 | no | `v2.14.6` | 2026-08-27 |
| `nats-io/nats-architecture-and-design` | repo | — | Apache-2.0 | no | *no releases* | pushed 2026-08-27 |
| `nats-io/jsm.go` | repo | Go | Apache-2.0 | no | `v0.4.1` | 2026-05-01 |
| `nats-io/nats-streaming-server` | repo | Go | Apache-2.0 | **yes** | `v0.25.6` | 2023-11-17 |
| `synadia-io/orbit.go` | orbit | Go | Apache-2.0 | no | `ntf-client/v0.0.3` | 2026-07-28 |
| `synadia-io/orbit.js` | orbit | TypeScript | Apache-2.0 | no | `fastingest/v1.0.0` | 2026-05-08 |
| `synadia-io/orbit.java` | orbit | Java | Apache-2.0 | no | `counters/0.2.3` | 2026-08-28 |
| `synadia-io/orbit.rs` | orbit | Rust | Apache-2.0 | no | `jetstream-extra/v0.3.0` | 2026-05-11 |
| `synadia-io/orbit.py` | orbit | Python | Apache-2.0 | no | *no releases* | pushed 2026-07-30 |
| `synadia-io/orbit.net` | orbit | C# | Apache-2.0 | no | *no releases* | pushed 2026-08-28 |
| `synadia-io/orbit.c` | orbit | C | Apache-2.0 | no | *no releases* | pushed 2026-08-06 |

Regenerate with `python3 tools/fetch-repo-facts.py --refresh`; the table above is
`raw/github-repos/_index.md`.

### What the READMEs say that the docs do not

- **`nats.swift` covers Core NATS only.** "Currently, the client supports **Core NATS** with auth,
  TLS, lame duck mode and more. JetStream, KV, Object Store, Service API are on the roadmap." Its
  last release is `v0.4.0`, 2024-10-31.
- **`nats.zig` is pre-1.0 and has two named gaps.** "Core pub/sub, server-authenticated TLS,
  JetStream (pull + push consumers), Key-Value Store, and the Micro Services API are supported and
  covered by integration tests. **Object Store and mTLS are not yet implemented.** The API may
  change before 1.0." Badged for Zig 0.16.0.
- **`nats.net` v3 dropped .NET 6.** "3.0 targets `netstandard2.0`, `netstandard2.1`, `net8.0`, and
  `net10.0`. `net6.0` has been dropped" (v3.0.0 release notes, 2026-07-10), which also added
  OpenTelemetry tracing and metrics. The docs still say ".NET 6+" — see `inbox/docs-issues.md` #8.
- **`nats.rs` keeps a stable API on 0.x versions.** "The API is stable, however it remains on 0.x.x
  versioning, as async ecosystem is still introducing a lot of ergonomic improvements." The old
  `nats` crate is **deprecated** and "only receives critical security fixes". A named build hazard:
  enabling the optional `chrono` feature "*anywhere* in the graph selects it for every consumer of
  `async-nats` in that build", so a `time` vs `chrono` type mismatch means a dependency turned it on.
- **`nats.rs` states the core/Orbit contract explicitly** — see [[orbit]]. Core is "kept in
  **parity** with other official NATS clients (Go, .NET, Java, JS, Python, C). A feature shipped here
  should look the same shape everywhere"; Orbit is "per-crate (per-API) versioning", "free to be
  language-specific" and "may lag, omit, or extend cross-client parity items". The rule of thumb:
  "if it is a thin mapping of something `nats-server` already speaks and every official client must
  expose it, it belongs in core."
- **`nats.js` v3 is a mono-repo that split the base client into modules** — Core, JetStream, Kv, Obj,
  Services — plus transports for Deno, Node/Bun and browsers. "This repository now supersedes:
  nats.deno, nats.ws" and the old `nats.js` "has been renamed to nats.node".
- **`nats.py` is becoming a workspace of packages.** Its README documents `nats-py` ("compatible
  with at least Python +3.8") and `nats-server` (a test-harness library), but the repository root
  also holds `nats-core/`, `nats-jetstream/` and `nats-key-value/` directories, and PyPI carries
  **`nats-core` 0.2.0, `requires_python >=3.13`**, "NATS core implementation in Python", pointing at
  the same repo. See `inbox/docs-issues.md` #10.
- **`nats.ex` publishes as `gnat`,** not as `nats.ex` — the hex.pm package is
  [`gnat`](https://hex.pm/packages/gnat).
- **`nats.rb` is EventMachine-based** and its README itself points at `nats-pure` "If you're looking
  for a non-EventMachine alternative".
- **`nats.c` is "heavily based on the NATS GO Client"** with "support for Mac OS/X, Linux and
  Windows (although we don't have specific platform support matrix)", and can be built with
  Streaming and libsodium support.
- **`nats-io/nats-streaming-server` is archived** and carries a deprecation notice: "Critical bug
  fixes and security fixes will be applied until June of 2023. NATS enabled applications requiring
  persistence should use JetStream."
- **`nats-box` bundles four tools, not three** — its README lists `nats`, `nsc`, **`nats-top`** and
  `nk`; the docs' ecosystem page names three. Image: `natsio/nats-box`.
- **The `nk` command-line utility lives in `nats-io/nkeys`**, "Located under the nk directory". NKeys
  are Ed25519; the prefix letters are documented there: `N` server, `C` cluster, `O` operator,
  `A` account, `U` user, `P` private, `S…` seeds.
- **`jsm.go` is the layer under the tooling**: "This package is the underlying library for the `nats`
  CLI, our Terraform provider, GitHub Actions and Kubernetes CRDs … For typical end users we suggest
  the nats.go package."
- **`nats-surveyor` requires the system account** ("System accounts must be enabled to use
  surveyor") and can export `--raftz` metalayer Raft metrics; it names Synadia Insights as the
  commercial alternative.
- **`nack` gates KV and Object Store behind control-loop mode**: "Key/Value stores and Object stores
  are **only supported in control-loop mode**. If you create KeyValue or ObjectStore resources
  without enabling control-loop mode, they will not be reconciled."

### Install lines, verbatim

| tool / client | install |
|---|---|
| `nats` CLI | `brew install nats-io/nats-tools/nats` · `go install github.com/nats-io/natscli/nats@latest` · scoop `extras/natscli` · AUR `yay natscli` |
| `nsc` | `curl -sf https://binaries.nats.dev/nats-io/nsc/v2@latest \| sh` · `brew install nats-io/nats-tools/nsc` · `nsc update` self-updates |
| `nats-top` | `curl -sf https://binaries.nats.dev/nats-io/nats-top@latest \| sh` · `go install github.com/nats-io/nats-top@latest` |
| `nats-box` | `docker run --rm -it natsio/nats-box:latest` |
| exporter | `docker run natsio/prometheus-nats-exporter:latest` |
| Helm charts | `helm repo add nats https://nats-io.github.io/k8s/helm/charts/` |
| Go | `go get github.com/nats-io/nats.go@latest` |
| Rust | `async-nats` on crates.io |
| .NET | `dotnet add package NATS.Net` |
| Java | `io.nats:jnats` on Maven Central |
| Python | `pip install nats-py` (and `pip install nats-server` for the test harness) |
| Ruby | `gem install nats-pure` (legacy: `gem install nats`) |
| Elixir | hex package `gnat` |

## Practical takeaways

- **Two official clients are not JetStream-complete**: Swift (Core NATS only) and Zig (no Object
  Store, no mTLS). If a deployment's design assumes every language can drive JetStream, check these
  two first.
- **Two repos are not Apache-2.0**: `nats-top` and `nats.ex` are MIT. Everything else read here is
  Apache-2.0.
- **One client is effectively dormant**: `nats.rb`'s last release is 2019-06-11, and the docs and its
  own README both point new work at `nats-pure.rb`.
- **A latest release is not a heartbeat.** `synadia-io/orbit.*` release *per module*, so "latest
  release: `counters/0.2.3`" says a module shipped, not that the repo is at 0.2.3.

## Notable quotes

> "Object Store and mTLS are not yet implemented. The API may change before 1.0." — `nats.zig`

> "JetStream, KV, Object Store, Service API are on the roadmap." — `nats.swift`

> "If it is a thin mapping of something `nats-server` already speaks and every official client must
> expose it, it belongs in core." — `nats.rs`, on the Orbit boundary

## Relevance to the wiki

This is the factual backing for every `kind: client` and `kind: tool` entity page: version, licence,
archived state and feature coverage. It is also what makes those pages **falsifiable** — re-run
`tools/fetch-repo-facts.py --refresh` and the claims can be re-checked in one pass.

## Questions it answers

Q67 (which client and how it reaches a cluster) partly; the client-choice half of the ecosystem.

## Pages touched

Every entity page written in step 7 of `inbox/plan-first-ingests-2026-08-31.md`: the twelve clients,
[[orbit]], the nine tools, [[nats-server]], [[nats-architecture-and-design]], [[jsm-go]],
[[nats-streaming]], [[synadia]], [[cncf]].
