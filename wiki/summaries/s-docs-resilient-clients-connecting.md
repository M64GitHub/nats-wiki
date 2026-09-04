---
title: "docs — Resilient Clients: the chapter's state machine, and connecting"
type: summary
area: [clients, core]
source-url: https://docs.nats.io/learn/resilient-clients.md
source-path: raw/nats-docs/learn/resilient-clients/connecting.md
author: nats-io docs
article: "learn/resilient-clients.md (index) and learn/resilient-clients/connecting.md"
date: 2026-08-31
version: ""
tags: [connection, connection-name, server-pool, no-randomize, discovery, connect_urls, no_advertise, connect-timeout, handshake, INFO, CONNECT, max_payload, auth]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — Resilient Clients: the chapter's state machine, and connecting

The chapter's frame plus its first page. The frame is the one idea the whole chapter rests on: **a
client connection is a state machine**, and every fault is one edge of it. The page then opens the
connection deliberately — a name, a pool, a connect timeout — and describes the four-step handshake
that every later mechanism assumes has completed.

**Unversioned by design**: "The chapter is unversioned and concept-first" (`where-next.md:20`). No
nats-server, client or ADR version appears anywhere in the eight pages; the only version string in
the whole chapter is `"version":"2.14.0"` inside a sample `INFO` line (`connecting.md:59`). Every
value this wiki states from the chapter is therefore re-pinned against
[[s-nats-go-connection]] (nats.go v1.53.1), [[s-nats-cli-reconnect]] (natscli 0.4.0) or the server
at v2.14.6 — see [[s-nats-server-client-lifecycle-observed]].

## Key claims

### The state machine (index)

- The states are **`DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING, DRAINING, CLOSED`**, and
  "every fault this chapter survives is one well-defined edge between them" (`where-next.md:14`).
  A server dying is CONNECTED → RECONNECTING; a SIGTERM is → DRAINING → CLOSED; a blocked dial
  keeps a client in CONNECTING "until the timeout fires".
- The index says the CLI "can't express" pending limits or reconnect callbacks, so those appear as
  named library calls only. Every page carries exactly two code languages, `#### CLI` (`nats …`)
  and `#### C` (nats.c); Go, Java, Python, JavaScript, Rust and C# appear in prose, by option name.

### Connection options fixed at connect time (`connecting.md`)

- **Connection name.** Without one "the server sees a client, but can't tell which application it
  is" (L14); it is what makes a connection findable in `nats server report connections` and in the
  server logs. The CLI's own default name is `NATS CLI Version <version>` (L31).
- **The server pool** is the list of URLs the client may dial. "With one URL, a client has one place
  to go" (L16); several URLs are "failover at connect time, before a single message is sent".
- The pool is **randomised before it dials** by default, so "a restart of every `order-svc` instance
  doesn't overload one server" (L88–90). The opt-out is "some variant of `NoRandomize`"; Python
  calls it `dont_randomize`, Rust `retain_servers_order`.
- **Connect timeout: "two seconds in most clients — five in Rust, twenty in JavaScript"** (L334).
  It is described as bounding the TCP dial (L346).
- The C examples name the calls: `natsOptions_SetName`, `natsOptions_SetServers(opts, servers, 3)`,
  `natsOptions_SetTimeout(opts, 2000)`, `natsOptions_SetNoRandomize`,
  `natsOptions_SetDiscoveredServersCB`, `natsConnection_GetServers`; a connect that reaches nobody
  is status `NATS_NO_SERVER`, and "anything else is a rejected connect" (L445–449).

### Discovered servers

- The server's `INFO` carries **`connect_urls`**, and a fresh `INFO` is sent on every change; the
  URLs you configured stay for the life of the connection, while **discovered ones may be dropped**
  (L188–190).
- **Per-client opt-outs**: Go `IgnoreDiscoveredServers`, Java `ignoreDiscoveredServers()`, Rust
  `ignore_discovered_servers`, JavaScript `ignoreClusterUpdates`; **Python and C# have none** (L192).
- **Per-client signals**: Go `DiscoveredServersCB`, Python `discovered_server_cb`, Java's
  `DISCOVERED_SERVERS` event, JavaScript's `update` status with the added and deleted URLs; **Rust
  and C# report none** (L194). The CLI prints `>>> Discovered new servers, known servers are now …`
  under `--trace` (L196).
- Server side, **`no_advertise` in the `cluster` block empties `connect_urls`** (L328, L370), which
  is what turns a one-URL client that leans on gossip back into a single point of failure.

### The connect handshake (L344–349)

1. the client dials TCP, bounded by the connect timeout;
2. the server sends `INFO` — `server_id`, `max_payload`, `auth_required`, `tls_required`;
3. the client sends `CONNECT` and a `PING`;
4. the server answers `PONG`, or `-ERR` (for example `Authorization Violation`) and closes.

`+OK` appears only in verbose mode, "which clients turn off by default".

### Connect-time failure modes

- No server reachable → a connect error (`NATS_NO_SERVER` in C); a server reached but rejecting →
  `-ERR` and a socket close, so **a connect-retry loop needs a wait of its own** "just like the
  reconnect backoff" (L366).
- `max_payload` is "one megabyte by default" and is enforced **client-side before the send**, so an
  oversized publish fails locally and the connection is unaffected (L362, L374).
- A full server answers `-ERR … maximum connections exceeded` (L366).
- A stalled dial with no timeout "hangs startup" (L372).

## Practical takeaways

- Name every connection; it is the only thing that makes `nats server report connections` readable
  under pressure.
- Configure the whole pool. Discovery is an addition, never the plan: `no_advertise`, or advertised
  addresses the client cannot route to, silently removes the failover a one-URL client depends on.
- A rejected connect and an unreachable pool are different failures and need different handling —
  one is a credential or a limit, the other is a wait-and-retry.

## Notable quotes

- "The very first thing a connection does is also the part most likely to fail: the client has to
  reach a server and pass authentication before anything else works." (L6)
- "The exact option names and defaults live in your client's API reference." (L338 — the boilerplate
  that recurs on every page of the chapter, and the reason [[client-defaults]] had to be built from
  the client source rather than from the docs.)

## Relevance to the wiki

The source of the state-machine vocabulary [[client-connection-lifecycle]] uses, and of the
per-client connect-timeout and discovery columns in [[client-defaults]]. The `no_advertise` sentence
lands on [[how-clients-reach-a-cluster]], which already owns the three cluster-advertisement designs.

## Questions it answers

Bank rows 175 (what a client does at connect time when the server it names is unreachable) and 176
(what a client learns about the other servers, and when that fails).

## Pages touched

[[client-connection-lifecycle]] · [[client-defaults]] · [[how-clients-reach-a-cluster]] ·
[[core-nats-delivery]] · [[nats-cli]]
