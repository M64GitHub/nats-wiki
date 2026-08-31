---
title: Index
type: index
created: 2026-08-31
updated: 2026-08-31
---

# NATS Wiki — Index

Catalog of every page. Read this first on any query. Pages link by slug (filename without
`.md`); folders are only layers. Operations are logged in [[log]]. The questions this wiki
exists to answer live in `inbox/question-bank.md`.

## Concepts

*What a thing is and how it behaves — streams, consumers, accounts, topology primitives.*

## Internals

*How the server does it, included only where it explains something you can observe.*

## Operations

**Runbooks**

**Sizing**

**Patterns**

## Gotchas

*Symptom-first: what you see → why → the fix.*

## Reference

*Lookup tables: defaults and limits, config keys, `$JS.API` subjects, monitoring endpoints.*

## Entities

**Repos**

**Clients**

**Tools**

**Releases**

**Products**

**Organisations**

**People**

## Summaries (one per ingested source)

## Wanted pages (topics with no source yet)

These are deliberately unresolved links; ingest a source to fill them.

Concepts: [[stream]] · [[consumer]] · [[ack-and-redelivery]] · [[retention-policies]] ·
[[replicas]] · [[account]] · [[leafnode]] · [[gateway]]

Internals: [[raft-in-nats]] · [[filestore-layout]] · [[meta-layer]] · [[stream-placement]]

Operations: [[install-nats-server]] · [[build-a-3-node-cluster]] · [[jetstream-sizing]] ·
[[rotate-tls-certificates]] · [[backup-and-restore-jetstream]] · [[upgrade-a-cluster]]

Gotchas: [[consumer-keeps-redelivering]] · [[jetstream-out-of-disk]] ·
[[stream-leader-keeps-moving]] · [[kv-watcher-misses-updates]]

Reference: [[defaults-and-limits]] · [[js-api-subjects]] · [[config-keys]] ·
[[monitoring-endpoints]]

Entities: [[nats-server]] · [[nats-cli]] · [[nsc]] · [[nats-architecture-and-design]] ·
[[nats-go]] · [[nats-streaming]] · [[synadia]]

## Inbox

- `inbox/question-bank.md` — the questions this wiki must answer, with the page that answers each
- `inbox/adr-toc.md` — one row per ADR of `nats-architecture-and-design`
- `inbox/config-keys-table.md` — 621 config keys with type, default and reload behaviour
- `inbox/plan-first-ingests-2026-08-31.md` — the current plan; say `start the plan`
- `inbox/` also holds scout files and plans; nothing there is a wiki page.
