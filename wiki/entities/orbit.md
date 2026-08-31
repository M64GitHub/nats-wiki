---
title: Orbit (synadia-io/orbit.*)
type: entity
kind: repo
area: [clients, jetstream, kv]
verified-against: synadia-io/orbit.* as of 2026-08-31
verified-on: 2026-08-31
tags: [orbit, extensions, incubator, partitioned-consumer-groups, kv-codecs, counters]
aliases: [orbit, orbit.go, orbit.js, orbit.py, orbit.java, orbit.rs, orbit.net, orbit.c, "synadia-io/orbit"]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
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

- **An Orbit dependency is not covered by the client's stability promise.** Sub-1.0 modules may break
  between releases; the core client will not. Pin Orbit modules individually.
- **`pcgroups` is a client-side construct.** Partitioned consumer groups are implemented in the
  library, not in the server — the server sees ordinary consumers. That matters when you are reading
  `nats consumer info` and trying to reconcile it with the application's model.
- **`natssysclient` and `natscontext` are the two most operations-relevant modules**: they let a Go
  service read the same monitoring surface an operator reads by hand, using the same context files.

## Related

[[nats-go]] · [[nats-rs]] · [[nats-java]] · [[nats-cli]] · [[key-value]] · [[monitoring-endpoints]] ·
[[synadia]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
