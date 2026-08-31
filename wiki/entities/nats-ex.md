---
title: nats.ex (Gnat)
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.ex v1.16.0
verified-on: 2026-08-31
tags: [client, tier-2, elixir, gnat, mit, hex]
aliases: [nats.ex, "nats-io/nats.ex", gnat, elixir client]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nats.ex (Gnat)

The **Elixir client**, published to hex.pm as **`gnat`** — the repository name and the package name
differ, which is the first thing to know about it. "Replaces the archived `elixir-nats`" (source:
[[s-docs-ecosystem]]).

## Where it fits

Tier 2. Stated goals: "resiliency, performance, and ease of use."

## Facts

| | |
|---|---|
| repo | `nats-io/nats.ex` |
| tier | **2** |
| latest release | **v1.16.0**, 2026-07-10 |
| licence | **MIT** — one of only two NATS repos read here that is not Apache-2.0 (the other is [[nats-top]]) |
| hex package | **`gnat`** |
| replaces | `nats-io/elixir-nats` (archived, last pushed 2021-01-07) |

```elixir
{:ok, gnat} = Gnat.start_link(%{host: "127.0.0.1", port: 4222})
{:ok, sub}  = Gnat.sub(gnat, self(), "pawnee.*")
:ok = Gnat.pub(gnat, "pawnee.news", "…")
```

## What an operator needs to know

- **Search for `gnat`, not `nats`.** Dependency audits, licence scans and hex searches all key on the
  package name.
- **The licence differs from the rest of the ecosystem.** MIT rather than Apache-2.0 — relevant only
  if your legal review treats the two differently, but it is the kind of thing that surfaces late.
- **All four auth modes are supported from the connection map**: user/password, token, nkey seed, and
  decentralized JWT credentials (`nkey_seed` + `jwt`), plus `tls: true`. That covers every
  authentication model this wiki's security pages describe.

## Related

[[nats-pure-rb]] · [[nats-server]] · [[nk]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
