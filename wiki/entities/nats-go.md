---
title: nats.go
type: entity
kind: client
area: [clients, jetstream, core]
verified-against: nats.go v1.53.1
verified-on: 2026-08-31
tags: [client, tier-1, go, reference-implementation]
aliases: [nats.go, "nats-io/nats.go", go client, golang client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-nats-go-kv-object-mirror, s-issue-5106-object-store-mirror-list, s-nats-server-mirrors-observed]
created: 2026-08-31
updated: 2026-09-02
---

# nats.go

The **Go client, and the reference implementation** — the docs' own word for it (source:
[[s-docs-ecosystem]]). New server features generally appear here first, so it is the client this
wiki treats as the behavioural baseline when a source describes "what the client does".

## Where it fits

Tier 1. It is also the client `nats-server`'s own tests and much of the tooling are written
against — [[nats-cli]] and [[nack]] reach JetStream through [[jsm-go]], which sits on `nats.go`.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.go` |
| tier | **1** — "track new server features at release" |
| latest release | **v1.53.1**, 2026-08-11 |
| licence | Apache-2.0 |
| module | `github.com/nats-io/nats.go` |
| JetStream API | the `jetstream` sub-package (`github.com/nats-io/nats.go/jetstream`) |

```
go get github.com/nats-io/nats.go@latest
go get github.com/nats-io/nats.go@v1.53.1
```

Facts from the GitHub API record in `raw/github-repos/`, fetched 2026-08-31
(source: [[s-github-repo-facts]]).

## What an operator needs to know

- **It is the parity target.** Other tier 1 clients state their goal as matching Go's API shape —
  `nats.rs` puts it as "API surface kept in **parity** with other official NATS clients (Go, .NET,
  Java, JS, Python, C)". When a feature exists in Go and not elsewhere, that is a lag, not a design
  difference (source: [[s-github-repo-facts]]).
- **Two JetStream API generations coexist in the module.** The `jetstream` sub-package is the newer
  surface; the older `nats.JetStreamContext` API remains importable from the root package. Which one
  an application uses changes which consumer behaviours it gets — [[ordered-consumer]] in particular
  is a client-side construct, not a server one.
- **The server imports it too.** `go get github.com/nats-io/nats-server/v2@latest` is documented
  alongside the client in the same README, because embedding the server is a supported test pattern.

## What bites you

Behaviours of this client — and therefore of the `nats` CLI built on it — that an operator meets
through the server's symptoms (sources: [[s-nats-go-kv-object-mirror]],
[[s-issue-5106-object-store-mirror-list]], [[s-nats-server-mirrors-observed]]):

- **A same-domain KV mirror is not readable by its own bucket name.** `CreateKeyValue` with `Mirror`
  set adds no subject transform (per ADR-57), and `mapStreamToKVS` keeps the read prefix on the
  mirror's own name — `$KV.<mirror>.` — unless the mirror has an `external` prefix, in which case it
  is rewritten to the origin's (`jetstream/kv.go:1610–1618`, v1.53.1). So `kv.Get` on a same-domain
  mirror returns *key not found* for every key while a cross-domain mirror works. Read the origin's
  name, or build the mirror with the transform yourself.
- **No mirrored object store.** `ObjectStoreConfig` has no `Mirror`; the request is nats.go #1874,
  open since 2025-05-15 with the maintainers saying the store needs a rethink first. A hand-built
  `OBJ_<name>` mirror with `$O.<origin>.>` → `$O.<name>.>` works with this client since #1568
  (2024-02-26), which made `ObjectStore()` bind the stream **by name** instead of by subject.
- **Two API generations.** The older `nats.JetStreamContext` KV and object code paths carry the same
  mirror rules; which one an application uses changes nothing here.


## Related

[[orbit]] · [[jsm-go]] · [[nats-cli]] · [[ordered-consumer]] · [[nats-js]] · [[nats-rs]] ·
[[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-nats-go-kv-object-mirror]] · [[s-issue-5106-object-store-mirror-list]] · [[s-nats-server-mirrors-observed]]
