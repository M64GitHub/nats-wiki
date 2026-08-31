---
title: "docs — WebSocket: Leaf nodes over WebSocket"
type: summary
area: [interop, topology, security]
source-url: https://docs.nats.io/learn/websocket/leaf-nodes-over-websocket.md
source-path: raw/nats-docs/learn/websocket/leaf-nodes-over-websocket.md
author: nats-io docs
article: "learn/websocket/leaf-nodes-over-websocket.md"
date: 2026-09-01
version: ""
tags: [websocket, leafnode, LEAFNODE_WS, ws_compression, ws_no_masking, leafnode-path, wss]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — WebSocket: Leaf nodes over WebSocket

A leaf node dialling its hub through the HTTPS ingress instead of the leafnode port. [[leafnode]] does
not mention this transport at all.

## Key claims

**The hub needs both blocks, and one of them is never dialled.** `leafnodes { port: 7422 }` "is the
switch that makes this server willing to accept leaf nodes **at all**"; `websocket {}` "is the door
the branch actually arrives through". "Drop the `leafnodes` block, or write it empty as `leafnodes {}`
with no port, and the branch's connection is accepted by the WebSocket listener and then closed."

And the consequence: "7422 is a real listener, open to whatever can reach it, even though no WebSocket
leaf node uses it. Treat it like the other server ports and restrict it."

**Clients and leaf nodes are told apart by the request path.** "A leaf node asks for `/leafnode`, a
client asks for `/`… You never write `/leafnode` yourself — the branch's remote URL stays
`wss://host:443` and the server appends it." Behind a path-routing proxy, "give the remote the proxy's
prefix (`wss://host:443/nats`) and the request becomes `GET /nats/leafnode`".

**The branch side is one line**: `remotes [ { urls: ["wss://nats.acme.example:443"] } ]`.

**Two independent things turn TLS on** — the scheme, or a `tls {}` block:

| remote | TLS handshake | result |
|---|---|---|
| `ws://` alone | no | fails against a TLS hub |
| `ws://` with `tls {}` | yes | connects |
| `wss://` alone | yes | connects if the hub's certificate is publicly trusted |
| `wss://` with `tls {}` | yes | connects |

A `wss://` remote against an untrusted CA gives:

```
[ERR] TLS leafnode handshake error: tls: failed to verify certificate:
      x509: certificate signed by unknown authority
```

"What fixes it is a `tls {}` block carrying the right CA, rather than one added to turn TLS on."

**So the scheme does not tell you whether a link is encrypted.** "A remote written `ws://` with a
`tls {}` block beside it is a TLS connection." The page's advice: write `wss://` so the config says so.

**One scheme per remote**, enforced at startup:

```
nats-server: remote leaf node configuration cannot have a mix of websocket and non-websocket urls:
["wss://nats.acme.example:443" "nats://n2-east:7422"]
```

"This bites when adding a second hub address for redundancy… you can't list the ingress and a direct
leafnode port as alternatives to each other."

**Write the port on every remote URL.** "A leafnode URL without a port gets `:7422` appended whatever
its scheme, so `wss://nats.acme.example` quietly dials the leafnode port rather than 443 — and then
fails, because that port doesn't speak WebSocket."

**Two WebSocket-only remote settings.** `ws_compression: true` (alias `websocket_compression`) asks
the hub to negotiate compression. `ws_no_masking: true` (alias `websocket_no_masking`) asks the hub to
accept unmasked frames — "The WebSocket specification requires clients to mask what they send, which
exists to stop a browser being used to poison intermediary caches — a concern that doesn't apply to a
server-to-server link." "Both are requests: the hub decides, and the link works either way if it
declines."

**The connection type is `LEAFNODE_WS`, not `LEAFNODE`.** "Using `LEAFNODE` here refuses the branch,
because the transport it arrives on is part of what the value names."

## Practical takeaways

- This is the answer to "the only way into the network is the HTTPS ingress" — a leaf joins through
  the same endpoint a browser dashboard uses.
- The `leafnodes { port: 7422 }` block that is required but never dialled is a firewall item people
  will miss precisely because nothing connects to it.

## Notable quotes

> "The URL scheme doesn't tell you whether a link is encrypted."

> "7422 is a real listener, open to whatever can reach it, even though no WebSocket leaf node uses
> it."

## Relevance to the wiki

[[leafnode]] covers the model and never this transport; [[choosing-a-topology]] never mentions that an
HTTPS ingress can carry a leaf link.

## Questions it answers

Q79 (partly).

## Pages touched

[[websocket]] · [[leafnode]] · [[run-nats-behind-a-proxy]] · [[tls-in-nats]]

## Sources

`raw/nats-docs/learn/websocket/leaf-nodes-over-websocket.md` · the mixed-scheme refusal reproduced in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
