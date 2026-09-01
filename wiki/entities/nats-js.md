---
title: nats.js
type: entity
kind: client
area: [clients, jetstream, interop]
verified-against: nats.js v3.4.0
verified-on: 2026-08-31
tags: [client, tier-1, javascript, typescript, deno, bun, websocket, monorepo]
aliases: [nats.js, "nats-io/nats.js", javascript client, typescript client, nats.deno, nats.ws, nats.node]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-get-direct]
created: 2026-08-31
updated: 2026-09-01
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

## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[nats-cli]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-docs-get-direct]]
