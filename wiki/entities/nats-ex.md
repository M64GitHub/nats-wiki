---
title: nats.ex (Gnat)
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.ex v1.16.0
verified-on: 2026-09-04
tags: [client, tier-2, elixir, gnat, mit, hex]
aliases: [nats.ex, "nats-io/nats.ex", gnat, elixir client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-client-releases-and-issues]
created: 2026-08-31
updated: 2026-09-04
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


## What bites you

The Elixir client appears in no `learn/` page and in no per-client table, so everything below is read
from its own release bodies (v1.9.0 → v1.16.0) and open issues at 2026-09-04 (source:
[[s-client-releases-and-issues]]).

- **Before v1.14.0 a slow KV watch handler was dropped as a slow consumer.** That release (2026-04-23)
  gave `KV.Watcher`'s push consumer "server-driven flow control and a 5s idle heartbeat (matching
  nats.go's ordered-consumer defaults), so slow handlers apply backpressure instead of being dropped
  as slow consumers". A cache built on `KV.Watcher` on an older version silently missed updates under
  load — see [[key-value]] and [[slow-consumer-detected]].
- **`PullConsumer` used to hand you messages you cannot ack.** Also v1.14.0, as a stated behaviour
  change: "`PullConsumer` no longer forwards JetStream informational status messages (e.g. `100` idle
  heartbeat, `409` leadership change) to `c:handle_message/2`. These are not stream records and cannot
  be acked." A handler that acked everything it was given raised on those; the new place to see them
  is the optional `handle_status/2`. `409` is a leadership change — [[consumer]].
- **Connections had no name until v1.16.0** (2026-07-10, #227, "Add client name to NATS CONNECT
  settings"). Every Elixir connection before that shows blank in `/connz`, which is the field an
  operator sorts by when a cluster has too many connections — [[monitoring-endpoints]].
- **v1.14.1 stopped the client sending its own consumer defaults**: "use server defaults and omit any
  non-user-specified options". Before it, creating a consumer from Gnat overrode server-side defaults
  with the library's.
- **A credential can end up in the log.** Open issue #160 (2024-05-28), "Connection credential is
  printed out in error log" — worth knowing before you ship Elixir logs to a shared collector. See
  [[operator-mode]].
- **The package is `gnat`, and the licence is MIT** — both stated above, both the kind of thing a
  dependency audit misses.

## Related

[[nats-pure-rb]] · [[nats-server]] · [[nk]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-client-releases-and-issues]]
