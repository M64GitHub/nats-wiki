---
title: "docs — WebSocket: Your first WebSocket connection"
type: summary
area: [interop, deploy, clients]
source-url: https://docs.nats.io/learn/websocket/your-first-websocket-connection.md
source-path: raw/nats-docs/learn/websocket/your-first-websocket-connection.md
author: nats-io docs
article: "learn/websocket/your-first-websocket-connection.md"
date: 2026-09-01
version: ""
tags: [websocket, no_tls, ws, wss, binary-frames, FIPS, nats.js]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — WebSocket: Your first WebSocket connection

The listener, and the two ways to configure it into non-existence. Previously quoted by this wiki as
one of the `where` paths on docs issue **#10**, but never ingested.

## Key claims

**The listener requires TLS by default.** With neither a `tls {}` block nor `no_tls: true` the server
refuses to start: `nats-server: websocket requires TLS configuration`. With `no_tls: true`:

```
[INF] Listening for websocket clients on ws://127.0.0.1:8080
[WRN] Websocket not configured with TLS. DO NOT USE IN PRODUCTION!
```

"The warning is accurate. A WebSocket client sending a bearer token over `ws://` sends it in the
clear."

**There is no default port, and the failure is silent.** "Write the block without one and the server
starts, logs nothing about WebSocket, and listens on 4222 only… **No error, no warning, no listener.**
If a WebSocket client can't connect and the log says nothing about WebSocket at all, this is why."

**It is the same protocol over a different transport.** "Neither side knows or cares which transport
the other used. There's no bridging step and no separate subject space — the WebSocket listener is
another door into the same server." Subjects, queue groups, request-reply, JetStream and headers all
behave identically.

**Only the first exchange is HTTP.** The server answers `101 Switching Protocols` and "from that point
the same TCP connection carries ordinary NATS protocol messages inside binary WebSocket frames".

**Client URLs, per client**: `nats -s ws://…`, Go `nats.Connect("ws://…")`, JS
`wsconnect({servers: "ws://…"})`, Python `nats.client.connect("ws://…")` — "needs
`pip install nats-core[websocket]`… It's the new Python client and needs **Python 3.13 or later**" —
Java `Nats.connect("ws://…")`, Rust `async_nats::connect("ws://…")`, C# `new NatsOpts { Url = "ws://…" }`.

**nats.js fills in a port and never picks 4222:**

| passed | connects to |
|---|---|
| `ws://host:8080` | `ws://host:8080` |
| `ws://host` | `ws://host:80` |
| `wss://host` | `wss://host:443` |
| `host` | `wss://host:443` |
| `nats://host:4222` | **`ws://host:4222`** |

"The last row is a trap of its own: the port survives but the scheme doesn't." Write the scheme and
the port every time.

**Frames are binary, and a frame is not a message.** "The server always sends binary, and clients are
expected to do the same." For client authors: "a WebSocket frame is not guaranteed to contain a whole
NATS protocol message, and generally won't. One frame can carry part of a `MSG`, or several messages
at once."

**FIPS-140 builds need Go 1.26 or later.** "The WebSocket handshake computes a SHA-1 over
`Sec-WebSocket-Key`, which a FIPS build from Go 1.25 or earlier won't permit, so the server refuses
the whole listener… The same build rejects `ws://` and `wss://` leafnode remotes for the same reason."
The message: `websocket: cannot be used in FIPS-140 mode when built with this Go version, use Go 1.26
or later`. "SHA-1 here only derives the handshake key and isn't protecting anything."

## Practical takeaways

- Both no-listener cases — MQTT's and WebSocket's — are silent. `Listening for websocket clients` in
  the log is the only confirmation the block took effect.
- `no_tls: true` gets exactly one warning line, at startup, and nothing thereafter.

## Notable quotes

> "The WebSocket listener is another door into the same server."

> "No error, no warning, no listener."

## Relevance to the wiki

The wiki's `interop` area had one page (the `nats-js` entity) and no explanation of the transport.
This is the base of [[websocket]].

## Questions it answers

Q79 (background).

## Pages touched

[[websocket]] · [[defaults-and-limits]] · [[config-keys]] · [[how-clients-reach-a-cluster]]

## Sources

`raw/nats-docs/learn/websocket/your-first-websocket-connection.md` · verified against the server in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
