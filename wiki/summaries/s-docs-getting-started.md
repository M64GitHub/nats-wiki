---
title: "docs.nats.io — Getting Started"
type: summary
area: [core, deploy, clients]
source-url: https://docs.nats.io/concepts/getting-started.md
source-path: raw/nats-docs/concepts/getting-started.md
author: NATS documentation (Synadia Communications, Inc.)
article: Getting Started with NATS
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [install, docker, homebrew, binaries.nats.dev, packages, ports]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Getting Started

The install page. Read here for the **package coordinates and install commands** the entity pages
quote — not for the tutorial, which this wiki does not carry.

## Key claims

**Server install**

```
docker run -p 4222:4222 -p 8222:8222 nats:latest      # client 4222, HTTP monitoring 8222
brew install nats-server                              # macOS
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh   # Linux
sudo mv nats-server /usr/local/bin/
```

Windows is a manual download from GitHub Releases. Verify with `nats-server --version`.

**Server start**

```
nats-server              # core only
nats-server -m 8222      # with the HTTP monitoring port
nats-server -js          # with JetStream
```

The monitoring port serves at `http://localhost:8222`. JetStream is **off unless `-js` (or config)
turns it on** — the flag is the whole difference between a core broker and a persistence engine.

**CLI install**

```
brew install nats-io/nats-tools/nats                              # macOS
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh   # Linux
sudo mv nats /usr/local/bin/
```

**Client package coordinates**, as the page gives them:

| language | install | note |
|---|---|---|
| JavaScript/TypeScript | `npm install nats` | the v3 modular packages are `@nats-io/…` — see [[nats-js]] |
| Go | `go get github.com/nats-io/nats.go` | |
| Java | `io.nats:jnats` — Gradle `implementation 'io.nats:jnats:2.25.2'`, or the equivalent Maven `<dependency>` | the page pins 2.25.2; the current release is 2.26.2 |
| Rust | `async-nats = "0.47.0"` in `Cargo.toml`, with `tokio` | the page pins 0.47.0; the current release is `async-nats/v0.50.0` |
| C#/.NET | `dotnet add package NATS.Net` | "See NATS.Net on NuGet for the latest version" |

The page gives **no Python install line**, and none for C, Zig, Swift, Ruby or Elixir, though it
links Python, C and .NET repos in its closing "Client Libraries" list.

**Ports named**: 4222 clients, 8222 HTTP monitoring.

## Practical takeaways

- **`binaries.nats.dev/<org>/<repo>[/<binary>]@latest | sh` is the house install pattern** — the same
  shape works for `nats-server`, `natscli` and [[nats-top]].
- **Pinned example versions in docs age.** Both the Java and Rust snippets are behind the current
  releases recorded in [[s-github-repo-facts]]. Quote them as *examples*, never as "the current
  version".
- The docs' own client-install coverage is partial: five languages get an install line, twelve are
  official. The gap is why this wiki's client pages carry install lines read from the repos.

## Relevance to the wiki

The install commands cited by the tool and client entity pages, and the raw material for the wanted
runbook [[install-nats-server]].

## Questions it answers

None outright; it supplies the commands other pages need.

## Pages touched

[[nats-server]] · [[nats-cli]] · [[nats-go]] · [[nats-js]] · [[nats-java]] · [[nats-rs]] ·
[[nats-net]] · [[nats-py]]
