---
title: nats.c
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.c v3.13.0
verified-on: 2026-08-31
tags: [client, tier-1, c, ffi, embedded, libsodium, streaming]
aliases: [nats.c, "nats-io/nats.c", c client]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nats.c

The **C client** — "Embedded systems and FFI consumers" (source: [[s-docs-ecosystem]]). Also the
client the docs' own multi-language examples fall back to, so it appears in more doc pages than its
user base would suggest.

## Where it fits

Tier 1. It is the client other languages bind to when no native client exists, which makes its build
options — TLS backend, static linking, libsodium — an integration concern rather than a detail.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.c` |
| tier | **1** |
| latest release | **v3.13.0**, 2026-06-01 |
| licence | Apache-2.0 |
| platforms | "Mac OS/X, Linux and Windows (although we don't have specific platform support matrix)" |
| built from | CMake; documented build options for TLS, static linking, an experimental API, Streaming, and libsodium |
| API docs | Doxygen at `nats-io.github.io/nats.c` |

## What an operator needs to know

- **It is a port of the Go client's semantics**: "This NATS Client implementation is heavily based on
  the NATS GO Client." When a behaviour is described in this wiki in Go terms, C usually matches.
- **There is no support matrix.** The README says so outright — platform support is "works, as far as
  we know", not a tested grid. Treat an unusual target as something you validate.
- **It still ships NATS Streaming support as a build option**, for the deprecated
  [[nats-streaming]] system. Building with Streaming is not evidence that Streaming is a live choice
  — it is not (source: [[s-github-repo-facts]]).
- **Two builds worth knowing about**: `EXPERIMENTAL API` (opt-in, unstable surface) and libsodium
  (faster Ed25519 for nkey-authenticated connections; see [[nk]]).

## Related

[[nats-go]] · [[nats-streaming]] · [[nk]] · [[orbit]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
