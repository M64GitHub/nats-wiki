---
title: "nats-server v2.2.0 — the release body, and where headers and no_responders actually arrived"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.2.0
source-path: raw/release-notes/v2.2.0.md
author: nats-io (GitHub release body)
date: 2021-03-15
version: "2.2.0"
article: "the v2.2.0 release body, read with raw/nats-server-src/headers-arrival-v2.2.0.md — server/server.go and server/client.go at tags v2.1.9 and v2.2.0"
tags: [release, 2.2.0, headers, HPUB, HMSG, no_responders, 503, jetstream-arrival, websocket, mqtt, before-the-range]
aliases: [v2.2.0, nats-server 2.2.0]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.2.0 — the release body, and where headers and `no_responders` actually arrived

The oldest release body in `raw/release-notes/`, eight minors before this wiki's range, kept for one
question: **since when does a client get headers, `HPUB`/`HMSG` and the no-responders `503`?** The
body does not say. The source at the tag does.

## Key claims

### What the body says (2021-03-15)

- *Added*: "JetStream, our new persistence offering", WebSocket support and WebSocket leafnodes, MQTT,
  the `/jsz` and `/accountz` endpoints, `lame_duck_grace_period`, `allowed_connection_types`,
  `account_token_position`, JWT bearer tokens, "Support for wildcard services and import remapping by
  JWT" (#1790), "Support for JWT based account mappings" (#1897) — thirty-odd lines, **none of them
  headers or no responders**.
- *Changed*: "Default TLS and Authentication timeouts, to 2 seconds and TLS timeout + 1 second
  respectively (#1633)"; "Enforce `max_control_line` for client connections only" (#1850); gateways
  "now always send PINGs" (#1692).
- *Fixed*, among the leafnode and gateway items: "Duplicate queue messages in complex routing setup
  (#1725)" and "Queue subscriptions not able to receive system events (#1530)".

### What the source says (`headers-arrival-v2.2.0.md`)

- At **v2.1.9** (2020-11-02) `server/server.go` and `server/client.go` contain no `headers`, `Headers`,
  `HPUB`, `HMSG` or `503`.
- At **v2.2.0** the `INFO` struct carries `Headers bool json:"headers"` (`server.go:68`); the client
  options carry `Headers` and `NoResponders` (`client.go:525–526`); a `CONNECT` asking for
  `no_responders` without `headers` gets `ErrNoRespondersRequiresHeaders` and is closed
  (`client.go:1764–1769`); and a request nobody could receive is answered with
  `HMSG %s %s 16 16\r\nNATS/1.0 503\r\n\r\n\r\n` (`client.go:3498`) — **no `Nats-Subject` header**. That
  header is the v2.12.0 body's "No responders errors from the server now include the original subject
  in the `Nats-Subject` header (#5250)" ([[s-relnotes-2.12]]), and at v2.14.6 the send is the
  `hdrLen := 32 + len(subject)` form in [[s-nats-server-request-reply]].

### The version this wiki quotes it for

- Headers, `HPUB`/`HMSG`, `no_responders` and the `503`: **since 2.2.0** (2021-03-15), read from the
  source at the tag, not from the body.
- The 2.10.27 security release names 2.2.0 as the floor of its vulnerable range — "affecting all NATS
  Server versions from v2.2.0" ([[s-relnotes-2.10]]) — because that is where JetStream arrived.

## Practical takeaways

- Every server this wiki covers (2.10 and later) sends the 503; a client that does not set `headers`
  and `no_responders` in its `CONNECT` simply never receives it and times out instead.
- A 2.2.0–2.11 server's 503 has no `Nats-Subject`; a client that reads the header must tolerate its
  absence.

## Notable quotes

- `HMSG %s %s 16 16\r\nNATS/1.0 503\r\n\r\n\r\n` — the whole no-responders reply at 2.2.0.

## Relevance to the wiki

The `since` line on [[request-reply]] and the header negotiation on [[core-nats-delivery]]; a row of
`raw/release-notes/` outside `inbox/relnotes-toc.md`'s 2.10+ range, by design.

## Questions it answers

150 (since when the signal exists).

## Pages touched

[[request-reply]] · [[core-nats-delivery]] · [[nats-server-2.12]]
