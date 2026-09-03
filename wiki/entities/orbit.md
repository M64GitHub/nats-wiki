---
title: Orbit (synadia-io/orbit.*)
type: entity
kind: repo
area: [clients, jetstream, kv]
verified-against: synadia-io/orbit.* as of 2026-08-31
verified-on: 2026-08-31
tags: [orbit, extensions, incubator, partitioned-consumer-groups, kv-codecs, counters]
aliases: [orbit, orbit.go, orbit.js, orbit.py, orbit.java, orbit.rs, orbit.net, orbit.c, "synadia-io/orbit"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-advanced-publishing, s-docs-get-direct, s-adr-47-request-many, s-docs-core-nats-request-reply]
created: 2026-08-31
updated: 2026-09-03
---

# Orbit (synadia-io/orbit.*)

**Seven repositories, one per tier 1 client, holding the utilities that deliberately do not belong in
the client.** Orbit is where opinionated helpers and experimental patterns live so the core clients
can stay small and identical across languages (source: [[s-docs-ecosystem]]).

## Where it fits

One layer above the clients: application code → Orbit module → core client → `nats-server`. The
split is a versioning contract, not a packaging accident, and it is the reason a feature can exist in
Go and not in Java without that being a client bug.

## Facts

| | |
|---|---|
| org | **`synadia-io`**, not `nats-io` — the boundary is visible in the URL |
| repos | `orbit.go`, `orbit.js`, `orbit.py`, `orbit.java`, `orbit.rs`, `orbit.net`, `orbit.c` |
| licence | Apache-2.0 across all seven |
| versioning | **per module**, not per repo — `orbit.go`'s latest tag is `ntf-client/v0.0.3`, `orbit.java`'s is `counters/0.2.3` |
| stability | "these libraries will evolve rapidly and **API guarantees are not made until the specific project has a v1.0.0 version**" |
| with no releases yet | `orbit.py`, `orbit.net`, `orbit.c` |

## The contract, as the clients state it

`nats.rs` documents the boundary most explicitly (source: [[s-github-repo-facts]]):

- **Core** — thin mapping of what `nats-server` speaks, kept in **parity** across Go, .NET, Java, JS,
  Python and C; conservative semver; breaking changes rare and deliberate.
- **Orbit** — opinionated abstractions on top; **per-crate versioning**; free to be
  language-idiomatic; "may lag, omit, or extend cross-client parity items".

> "If it is a thin mapping of something `nats-server` already speaks and every official client must
> expose it, it belongs in core. If it is a pattern, helper, or abstraction layered on top, it
> belongs in Orbit."

The docs add the other direction: "Successful patterns may eventually **graduate into the core
client**" (source: [[s-docs-ecosystem]]).

## What is in it

The docs list the typical contents as "extra JetStream helpers (request-many, batch publish,
scheduled messages), partitioned consumer groups, encoded KV / KV codecs, distributed counters, and
retry / chaos utilities", and warn that the "Exact module set differs per language".
`orbit.go`'s modules, as an example of the shape:

| module | what it does |
|---|---|
| `natsext` | core NATS extensions |
| `jetstreamext` | JetStream extensions |
| `natscontext` | connect using **`nats` CLI contexts** — the same files [[nats-cli]] writes |
| `natssysclient` | a client for the **monitoring / system APIs** ([[monitoring-endpoints]]) |
| `pcgroups` | client-side **partitioned consumer groups** |
| `kvcodec` | transparent encode/decode for KV values ([[key-value]]) |
| `counters` | distributed counters on JetStream streams |
| `ntf-client` | client for the NATS Testing Framework service |

## What an operator needs to know

**Three server features are reachable only through Orbit in most clients**, and the oldest of them is
not new at all: **batched Direct Get**, a 2.11 mechanism. "`nats.js` sends a batched Direct Get
directly; Go, Rust, Java, and C# reach it through the Synadia Orbit helper libraries"
(source: [[s-docs-get-direct]]) — so the gap Orbit fills is not only a lag behind the newest release
but a standing difference in what each core client considers its own job ([[direct-get]]). The other
two are newer:

**Two 2.12/2.14 publishing features are reachable only through Orbit in most clients.** Atomic batch
publishing (`allow_atomic`, 2.12) is in the core client for the `nats` CLI and nats.js; **Go, Java,
Rust and .NET reach it through Orbit**, and nats.py has to drive the `Nats-Batch-*` headers itself.
Fast-ingest batch publishing (`allow_batched`, 2.14) is worse served: `jetstreamext.NewFastPublisher`
in Go, `fast_publish` in Rust and `@synadiaorbit/fastingest` (`startFastIngest`) in JavaScript are the
only publishers that exist, with Python, Java and .NET still catching up
(source: [[s-docs-advanced-publishing]]). **That makes Orbit a dependency of the feature, not an
optional extra** — worth knowing before designing around either mode ([[publishing]]).

- **An Orbit dependency is not covered by the client's stability promise.** Sub-1.0 modules may break
  between releases; the core client will not. Pin Orbit modules individually.
- **`pcgroups` is a client-side construct.** Partitioned consumer groups are implemented in the
  library, not in the server — the server sees ordinary consumers. That matters when you are reading
  `nats consumer info` and trying to reconcile it with the application's model.
- **`natssysclient` and `natscontext` are the two most operations-relevant modules**: they let a Go
  service read the same monitoring surface an operator reads by hand, using the same context files.

## `RequestMany`

ADR-47's request-many helper for Go lives in orbit.go, not in nats.go: a total timeout, an optional
stall gap, an optional message cap, a sentinel — and a `503` in place of a reply is terminal (source:
[[s-adr-47-request-many]]; the docs name orbit.go's `RequestMany` beside nats.js's `requestMany` and
.NET's `RequestManyAsync`, source: [[s-docs-core-nats-request-reply]]). What each stop condition does,
measured through the CLI's flags, is on [[request-reply]].


## Related

[[nats-go]] · [[nats-rs]] · [[nats-java]] · [[nats-cli]] · [[key-value]] · [[monitoring-endpoints]] ·
[[synadia]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-advanced-publishing]] ·
[[s-docs-get-direct]] · [[s-adr-47-request-many]] · [[s-docs-core-nats-request-reply]]
