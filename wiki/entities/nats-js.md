---
title: nats.js
type: entity
kind: client
area: [clients, jetstream, interop]
verified-against: nats.js v3.4.0
verified-on: 2026-09-04
tags: [client, tier-1, javascript, typescript, deno, bun, websocket, monorepo]
aliases: [nats.js, "nats-io/nats.js", javascript client, typescript client, nats.deno, nats.ws, nats.node]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-get-direct, s-adr-47-request-many, s-docs-core-nats-request-reply, s-client-releases-and-issues, s-docs-resilient-clients-connecting]
created: 2026-08-31
updated: 2026-09-04
---

# nats.js

The **JavaScript/TypeScript client**, and since v3 a mono-repo: one runtime-agnostic core plus
transports for Node/Bun, Deno and the browser (source: [[s-docs-ecosystem]]).

## Where it fits

Tier 1, and the only official client that runs **in a browser** — over WebSocket, which is why the
server's `websocket { same_origin }` option is documented in terms of it.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.js` |
| tier | **1** |
| latest release | **v3.4.0**, 2026-05-08 |
| licence | Apache-2.0 |
| runtimes | Deno, Node/Bun, browsers (W3C WebSocket) |
| supersedes | `nats.deno`, `nats.ws`, `nats.ts`; the old `nats.js` was **renamed** to `nats.node` |

```
npm install nats                                        # the single-package path (docs)
npm install @nats-io/transport-node @nats-io/jetstream   # the v3 modular path
```

## What an operator needs to know

- **v3 split the base client into modules**: Core, JetStream, Kv, Obj and Services, plus a transport
  per runtime. "You will of course need a transport which will allow you to `connect` to a NATS
  server" — the transport is a separate package from the feature modules (source:
  [[s-github-repo-facts]]).
- **Four repository names in the wild resolve here.** `nats.node`, `nats.ws` and `nats.ts` are
  archived; **`nats.deno` is not archived** despite the docs saying it is — see
  `inbox/docs-issues.md` #9. Old links and old dependency pins still work but are frozen.
- **Browser deployments are an origin problem, not a client problem.** The server option
  `websocket { same_origin: true }` (default `false`) rejects a request whose HTTP `Origin` header
  does not match the hostname; "The check only applies when the request carries an `Origin` header,
  which browsers send and non-browser clients generally do not"
  (`reference/config/websocket/same_origin.md`).
- **It is the only client that sends a batched Direct Get itself.** "`nats.js` sends a batched Direct
  Get directly; Go, Rust, Java, and C# reach it through the Synadia Orbit helper libraries"
  (source: [[s-docs-get-direct]]). So a batched point read that is one dependency here is an
  [[orbit]] dependency elsewhere — see [[direct-get]].
- **Migration between v2 and v3 is documented in-repo** (`migration.md`), which is where a version
  jump on an existing service should start.

## `requestMany`

The JavaScript client ships ADR-47's gather helper as `requestMany` — a total timeout, an optional
stall gap, a message cap, a sentinel, and a `503` that ends the gather (source:
[[s-adr-47-request-many]]; named by the docs beside orbit.go's `RequestMany` and .NET's
`RequestManyAsync`, source: [[s-docs-core-nats-request-reply]]). A plain `request()` still returns the
first reply and drops the rest; the error for a missing service is `RequestError` with
`isNoResponders()`, for a slow one `TimeoutError` — [[request-reply]].



## What bites you

Read from the last ten releases (v3.1.0 → v3.4.0, 2026-05-08) and the open issues at 2026-09-04
(source: [[s-client-releases-and-issues]]), with the two defaults from the documentation's per-client
table (source: [[s-docs-resilient-clients-connecting]]).

- **Two defaults are unlike every other client's: a 20 s connect timeout and a `MaxReconnect` of
  10.** Everyone else dials for 2 s (5 in Rust) and retries 60 times. A browser or Node service that
  looks slow to fail over and then gives up early is on those two numbers, not on the network —
  [[client-defaults]], [[client-connection-lifecycle]].
- **The client-side buffer is unbounded and never drops.** Its slow-consumer option only raises a
  status. So the failure mode here is not the missing messages other clients report but **memory
  growth in the process** — [[slow-consumer-in-the-client]].
- **The inbox shape changed in v3.4.0.** "inboxes match go client `_INBOX.<nuid>.<token>` (was
  `_INBOX.<nuid>.<nuid>`); nuids now base62" (#398). Both are two tokens after the prefix, so a
  `_INBOX.>` permission is unaffected, but anything matching on the token's character set is —
  [[subject-permissions]], [[request-reply]].
- **A truncated KV history can look complete.** Open issue **#426** (2026-08-10): "kv: history()
  reports a truncated read as a complete one when the link drops". A watcher rebuilt after a
  reconnect can therefore start from a partial view with no error — [[key-value]].
- **`status()` yields a `reconnect` status per retry**, not per reconnection — open issue **#423**
  (2026-06-12). Anything counting reconnects from the iterator over-counts them.
- **Object-store digest validation was wrong before v3.3.1** (2026-02-11): "Fixes a check on the
  validation of the digest. This is an important integrity fix." A `get` before that release could
  accept an object whose digest did not match — [[object-store]].
- **Subject validation only since v3.3.0** (2025-12-16, #348, "Validate subjects for illegal
  whitespace characters") — [[subjects-and-wildcards]].
- **`getServers()`/`setServers()` and `reconnectToServer` are v3.4.0** (#400, #403). Pinning a client
  to a particular server, or listing what it discovered, is not available below it.

## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[nats-cli]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-docs-get-direct]] · [[s-adr-47-request-many]] · [[s-docs-core-nats-request-reply]] · [[s-client-releases-and-issues]] · [[s-docs-resilient-clients-connecting]]
