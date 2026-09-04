---
title: nats.go
type: entity
kind: client
area: [clients, jetstream, core]
verified-against: nats.go v1.53.1
verified-on: 2026-08-31
tags: [client, tier-1, go, reference-implementation]
aliases: [nats.go, "nats-io/nats.go", go client, golang client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-nats-go-kv-object-mirror, s-issue-5106-object-store-mirror-list, s-nats-server-mirrors-observed, s-nats-go-relnotes-1.48.0, s-docs-core-nats-subjects-and-mapping, s-nats-server-core-delivery-observed, s-nats-go-connection, s-nats-server-client-lifecycle-observed, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown, s-nats-go-subscription, s-nats-server-client-faults-observed]
created: 2026-08-31
updated: 2026-09-04
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


## What bites you — the connection

Read from `nats.go` at **v1.53.1** (source: [[s-nats-go-connection]]) and measured on nats-server
2.14.6 (source: [[s-nats-server-client-lifecycle-observed]]). Every default is in
[[client-defaults]]; the mechanisms are on [[client-connection-lifecycle]].

- **`MaxReconnect` is a budget per server, and spending it deletes the server.** The default is 60.
  `selectNextServer` drops a server from the pool once `s.Reconnects >= MaxReconnect`
  (`nats.go:2071–2091`), and an empty pool goes straight to `close(CLOSED)` — a connection that never
  comes back, with unlimited retries never having been the default. Set `-1` on anything long-lived.
- **`Drain()` returns immediately.** It starts a goroutine. A shutdown that exits on its return
  abandons exactly the work the drain existed to save; wait on `ClosedHandler`. Measured with the
  CLI's `nats reply`, which makes this mistake by design: **four of eight** in-flight requests were
  answered and four were abandoned.
- **A drain issued while the connection is RECONNECTING closes it instead** (`:6211–6215`,
  `:6310–6314`), discarding the reconnect buffer. The documentation does not mention this.
- **`ErrDrainTimeout` is delivered to the async error callback, not returned.** A service with no
  callback never learns its shutdown was cut short and its remaining messages discarded.
- **The publish flush inside a drain has its own hardcoded 5 s** (`:6291`), whatever `DrainTimeout`
  says.
- **`ErrReconnectBufExceeded`** (`nats: outbound buffer limit exceeded`) is what a publish returns
  once 8 MB has accumulated during a reconnect. It is memory only — `Close()`, a kill, or a drain
  during the outage all drop it.
- **A custom reconnect delay replaces the jitter too** (`st = crd(wlf)`, `:3424–3427`), and the
  callback's first call carries **1**, not 0, because the sweep counter is incremented first — a
  delay table indexed from zero silently never uses its first entry.
- **The keepalive is `pout > MaxPingsOut`, so the third interval, not the second**: six minutes at
  the defaults, measured. And nats.go pings on the interval regardless of traffic — only a `PONG`
  clears the count.
- **An unset `AsyncErrorCB` does not silence errors.** nats.go installs `defaultErrHandler`, which
  writes `<err> on connection [<cid>] for subscription on "<subject>"` to **stderr** (`:1979–1981`,
  `:2006–2028`). The documentation says such reports are discarded; they are not (docs issue #92).


## What bites you — the subscription

Four things about the pending buffer and the error paths that are not what the documentation leads
you to expect, all read at **v1.53.1** and run on nats-server 2.14.6
(source: [[s-nats-go-subscription]], [[s-nats-server-client-faults-observed]]).

- **The pending default is two numbers, not one.** An async `Subscribe` starts at
  `DefaultSubPendingMsgsLimit` = **500,000** messages; a `SubscribeSync` or `ChanSubscribe` starts at
  the channel's capacity, `DefaultMaxChanLen` = **65,536**. Both are 64 MB on bytes. The docs quote
  only the first. Print `sub.PendingLimits()` after subscribing rather than assuming.
- **`SetPendingLimits(0, …)` is an error, not "unlimited".** Zero in either argument returns
  `nats: invalid argument`; **negative** means unlimited. `SetPendingLimits(200, -1)` is the idiom.
- **The async error callback fires per *transition*, not per drop — and the transition re-arms.**
  `sub.sc` is cleared by the next message that fits, so a sustained overflow fires repeatedly:
  **13 callbacks for 4,888 dropped messages** in one run. Alert on the rate; read `Dropped()` for the
  loss. A *sync* subscriber is told twice — `NextMsg` returns `ErrSlowConsumer` **as well as** the
  connection callback firing.
- **An unrecognised `-ERR` closes the connection.** `processErr` handles the stale-connection and
  connection-limit strings by reconnecting, permissions and max-subscriptions transiently, and the
  four auth strings through `processAuthError` — **everything else** falls to
  `nc.close(CLOSED, true, nil)`.

And one that is documented but easy to under-read: `UserCredentials(path)` stores **callbacks**, not
a parsed file, and `userFromFile` does `os.ReadFile` inside one of them — so the `.creds` file is
re-read on **every** connect and reconnect attempt. Rotation by temp-file-and-rename is safe;
rotation by in-place write has a window in which the client reads a partial file, fails to parse it,
and retries. See [[connection-closed-after-auth-error]].


## Publish subject validation since v1.48.0

Before **v1.48.0** (2025-12-17) the Go client wrote any subject it was given into the `PUB` line; the
release added "publish subject validation and a connection option to skip it (#1974, #1979)" (source:
[[s-nats-go-relnotes-1.48.0]]). The docs' whitespace pitfall names "nats.go before v1.48.0" as a client
that lets `orders.us created` through (source: [[s-docs-core-nats-subjects-and-mapping]]), and the
server then reads the space as the reply boundary — subject `orders.us`, reply `created` — silently
(source: [[s-nats-server-core-delivery-observed]], run A2). The CLI, built on a current client, refuses
the subject with `nats: invalid subject`. Rules on [[subjects-and-wildcards]].


## Related

[[orbit]] · [[jsm-go]] · [[nats-cli]] · [[ordered-consumer]] · [[nats-js]] · [[nats-rs]] ·
[[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-nats-go-kv-object-mirror]] · [[s-issue-5106-object-store-mirror-list]] · [[s-nats-server-mirrors-observed]] · [[s-nats-go-relnotes-1.48.0]] · [[s-docs-core-nats-subjects-and-mapping]] · [[s-nats-server-core-delivery-observed]] · [[s-nats-go-connection]] · [[s-nats-server-client-lifecycle-observed]] · [[s-docs-resilient-clients-reconnection-and-events]] · [[s-docs-resilient-clients-drain-and-shutdown]] · [[s-nats-go-subscription]] · [[s-nats-server-client-faults-observed]]
