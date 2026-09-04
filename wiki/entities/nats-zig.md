---
title: nats.zig
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.zig v0.1.0
verified-on: 2026-09-04
tags: [client, tier-2, zig, pre-1.0, no-object-store, no-mtls]
aliases: [nats.zig, "nats-io/nats.zig", zig client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-client-releases-and-issues]
created: 2026-08-31
updated: 2026-09-04
---

# nats.zig

The **Zig client**, tier 2 and pre-1.0 — "Newer addition" in the docs' words (source:
[[s-docs-ecosystem]]), with two capability gaps its README names explicitly.

## Where it fits

Tier 2: "Synadia-maintained, may lag behind on new server features." Its own README is more specific
than the tier label, which is exactly what the docs tell you to rely on.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.zig` |
| tier | **2** |
| latest release | **v0.1.0**, 2026-04-28 |
| licence | Apache-2.0 |
| language version | badged **Zig 0.16.0** |
| supported | core pub/sub, server-authenticated TLS, JetStream (pull **and** push consumers), Key-Value, Micro Services API — "covered by integration tests" |
| **not implemented** | **Object Store**, **mTLS** |
| status | "**Pre-1.0** — This library is under active development … The API may change before 1.0." |

## What an operator needs to know

- **mTLS is missing.** If a deployment authenticates clients with certificates rather than
  credentials, this client cannot join it today. That is a topology decision, not a code change.
- **Object Store is missing**, though KV is present. Both are streams underneath
  ([[key-value]], [[object-store]]), so the gap is client-side, not server-side.
- **The runtime shape is unusual and stated.** The public API is `std.Io`-idiomatic, but internally
  "the client uses a background I/O thread with direct `poll(2)`", which "currently requires
  `std.Io.Threaded` as the host runtime". An application built on a fully evented runtime cannot use
  it yet.
- **Pre-1.0 means the API moves.** Pin the version.


## What bites you

There is one release and two open issues, so this section is short by necessity — and the shortness
is itself the finding (source: [[s-client-releases-and-issues]]).

- **One release, and the API is not frozen.** The v0.1.0 notes (2026-04-28) say it plainly: "As this
  is a 0.x release, the public API may still evolve before 1.0." Pin the exact version; a
  `zig fetch --save` of a moving branch will not stay compiling.
- **Object Store is absent, and the release notes say so** — "Object Store support is not included in
  this initial release" — confirming the README rather than only repeating it. KV **is** present, and
  both are streams underneath ([[key-value]], [[object-store]]), so the gap is entirely client-side.
- **mTLS is missing** (README). If the deployment authenticates clients with certificates rather than
  credentials, this client cannot join it — a topology decision, not a code change
  ([[tls-in-nats]]).
- **It pins a Zig version, and Zig moves its standard library every release.** v0.1.0 is badged
  **Zig 0.16.0** and built on `std.Io`; the usable Zig range is effectively one version wide.
- **The runtime shape is fixed**: the client "uses a background I/O thread with direct `poll(2)`",
  which "currently requires `std.Io.Threaded` as the host runtime". An application on a fully evented
  runtime cannot use it yet.
- **Neither of its two open issues concerns the connection.** Nothing about slow consumers, reconnect,
  drain or no-responders has been reported — which for a client this new means untested in
  production, not proven in it.

## Related

[[nats-swift]] · [[key-value]] · [[object-store]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-client-releases-and-issues]]
