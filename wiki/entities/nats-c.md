---
title: nats.c
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.c v3.13.0
verified-on: 2026-08-31
tags: [client, tier-1, c, ffi, embedded, libsodium, streaming]
aliases: [nats.c, "nats-io/nats.c", c client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-core-nats-subjects-and-mapping, s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events, s-docs-resilient-clients-drain-and-shutdown]
created: 2026-08-31
updated: 2026-09-04
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

## What the core-NATS chapter says about this client

- **`natsConnection_PublishString` with a space in the subject "does NOT fail"** — the C client's publish
  skips the subject check, so the space "goes straight into the `PUB` line and the server silently
  misroutes" it (`learn/core-nats/subjects-and-wildcards.md:493–503`; source:
  [[s-docs-core-nats-subjects-and-mapping]]). The docs' word, to be confirmed against the client's
  source in step 8 of `inbox/plan-the-client-side-2026-09-03.md`; the server's half is reproduced and
  the rule is on [[subjects-and-wildcards]].


## What the resilient-clients chapter says about this client

The C client is one of only two languages the chapter shows in code (the other is the `nats` CLI), so
its call names are the ones stated most explicitly. All of the following is the documentation's word,
carrying no version — the C source has not been read here (sources:
[[s-docs-resilient-clients-connecting]], [[s-docs-resilient-clients-reconnection-and-events]],
[[s-docs-resilient-clients-drain-and-shutdown]]). The mechanisms are on
[[client-connection-lifecycle]]; the values per client are in [[client-defaults]].

| what | the call |
|---|---|
| connection name, pool, dial timeout | `natsOptions_SetName`, `natsOptions_SetServers(opts, servers, 3)`, `natsOptions_SetTimeout(opts, 2000)` |
| pool order | `natsOptions_SetNoRandomize(opts, true)` |
| discovery | `natsOptions_SetDiscoveredServersCB`, `natsConnection_GetServers` |
| reconnect | `natsOptions_SetMaxReconnect(opts, -1)`, `natsOptions_SetReconnectWait(opts, 2000)` |
| events | `natsOptions_SetDisconnectedCB` / `ReconnectedCB` / `ClosedCB` / `LameDuckModeCB` |
| state | `natsConnection_Status` → `NATS_CONN_STATUS_CONNECTED / RECONNECTING / CLOSED`, `natsConnection_IsClosed`, `natsConnection_GetLastError`, `natsConnection_GetRTT` (ns) |
| drain | `natsConnection_Drain`, `natsConnection_DrainTimeout(conn, 10000)`, `natsSubscription_Drain`, `natsSubscription_WaitForDrainCompletion`, `natsSubscription_DrainCompletionStatus` |
| flush | `natsConnection_FlushTimeout(conn, 5000)`, `natsConnection_Flush()` (10 s) |
| pending limits | `natsSubscription_SetPendingLimits(sub, 10000, 8 * 1024 * 1024)`, `natsSubscription_GetDropped`, `natsOptions_SetErrorHandler` |

Two behaviours worth calling out:

- **`natsConnection_Drain` returns immediately**, exactly as in Go: the chapter's own C example loops
  on `natsConnection_IsClosed(conn)` before exiting, because "exiting on `Drain()`'s return abandons
  the work drain was meant to save". The drain timeout defaults to **30 s** and surfaces
  `NATS_TIMEOUT`.
- **The C client has no per-attempt reconnect-error callback** — the other clients' "reconnect error"
  event has no C equivalent, so a long outage is quieter here than elsewhere.

Status codes the chapter names: **`NATS_NO_SERVER`** ("no server in the pool answered; anything else
is a rejected connect"), `NATS_DRAINING`, `NATS_CONNECTION_CLOSED`, `NATS_SLOW_CONSUMER`.


## Related

[[nats-go]] · [[nats-streaming]] · [[nk]] · [[orbit]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-core-nats-subjects-and-mapping]] · [[s-docs-resilient-clients-connecting]] · [[s-docs-resilient-clients-reconnection-and-events]] · [[s-docs-resilient-clients-drain-and-shutdown]]
