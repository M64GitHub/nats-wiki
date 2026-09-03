---
title: WebSocket
type: concept
area: [interop, security, deploy]
since: [2.11]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [websocket, ws, wss, no_tls, allowed_origins, same_origin, jwt_cookie, compress, LEAFNODE_WS, advertise]
aliases: [WebSocket, websocket, "websocket {}", ws, wss, browser client, allowed_origins]
sources: [s-docs-websocket-your-first-websocket-connection, s-docs-websocket-browsers-and-origins, s-docs-websocket-tls-and-proxies, s-docs-websocket-leaf-nodes-over-websocket, s-nats-server-mqtt-websocket-observed, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-09-01
updated: 2026-09-03
---

# WebSocket

A WebSocket connection **is** a NATS connection. Only the first exchange is HTTP — the server answers
`101 Switching Protocols` and the same TCP connection then carries ordinary NATS protocol messages
inside binary WebSocket frames, so subjects, queue groups, request-reply, JetStream and headers all
behave exactly as on a `nats://` connection (source:
[[s-docs-websocket-your-first-websocket-connection]]).

There is no separate subject space and no bridging step: "the WebSocket listener is another door into
the same server". Reaching for it is often nothing to do with browsers — where an HTTP ingress is the
only path into a network, it is the listener that gets published through it, and a [[leafnode]] uses
that door exactly as a client does.

## What it needs before it will start

**TLS, or an explicit opt-out.** The listener requires TLS by default; with neither a `tls {}` block
nor `no_tls: true` the server refuses to start (confirmed on 2.14.6, exit 1):

```
nats-server: websocket requires TLS configuration
```

With `no_tls: true` you get a listener and exactly one warning, once, at startup:

```
[INF] Listening for websocket clients on ws://127.0.0.1:8080
[WRN] Websocket not configured with TLS. DO NOT USE IN PRODUCTION!
```

**A port. There is no default**, and the failure is silent — a block with no `listen` or `port` starts
the server with **no websocket log line at all** (confirmed). `Listening for websocket clients` is the
only confirmation the block took effect; if a client cannot connect and the log says nothing about
WebSocket, this is why.

A **FIPS-140 build** needs Go 1.26 or later. The handshake computes a SHA-1 over `Sec-WebSocket-Key`,
which earlier FIPS toolchains refuse, so the server rejects the whole listener — and the same build
rejects `ws://` and `wss://` leafnode remotes. The SHA-1 "only derives the handshake key and isn't
protecting anything".

## Connecting

Every client takes its usual server list with a different scheme: `nats -s ws://127.0.0.1:8080`,
`nats.Connect("ws://…")`, `wsconnect({servers: "ws://…"})`, `async_nats::connect("ws://…")`. The
Python client keeps its WebSocket transport behind an extra — `pip install nats-core[websocket]`, and
it needs **Python 3.13 or later**.

**Always write the scheme and the port.** nats.js fills in a port and never picks 4222:

| passed | connects to |
|---|---|
| `ws://host:8080` | `ws://host:8080` |
| `ws://host` | `ws://host:80` |
| `wss://host` | `wss://host:443` |
| `host` | `wss://host:443` |
| `nats://host:4222` | **`ws://host:4222`** — the port survives, the scheme does not |

A frame is not a message: one frame can carry part of a `MSG` or several messages at once, so a client
implementation must feed frame payloads to a parser that handles partial protocol. Frames are always
**binary**.

## Origin checking is not access control

`allowed_origins` is an **exact string match on scheme, host and port** — a comparison, not a name
resolution. Reproduced on 2.14.6 against `allowed_origins ["http://localhost:8000"]` (source:
[[s-nats-server-mqtt-websocket-observed]]):

| `Origin` sent | handshake |
|---|---|
| `http://localhost:8000` | `101 Switching Protocols` |
| `http://127.0.0.1:8000` | `403 Forbidden` |
| `https://localhost:8000` | `403 Forbidden` |
| `http://localhost:8001` | `403 Forbidden` |
| `http://localhost` | `403 Forbidden` |
| **no `Origin` header at all** | **`101 Switching Protocols`** |

`localhost` and `127.0.0.1` are different origins on the same machine. A URL with no port means 80 or
443, so `https://ops.acme.example` and `https://ops.acme.example:8443` are different origins.
Aliases: `origins`, `origin`, `allowed_origin`, `allow_origins`, `allow_origin`.

**The last row is the point.** The check runs only when the header is present, so anything that is not
a browser skips it entirely — the `nats` CLI publishes straight through an origin-restricted listener,
which was confirmed. The docs are explicit that this is by design and not configurable away: the
`Origin` header is set by the browser rather than by its user, "so an attacker writing a client simply
omits it" (source: [[s-docs-websocket-browsers-and-origins]]).

> `allowed_origins` answers *may this web page open a connection using a visitor's browser?* It does
> not answer *may this connection reach my subjects?* — [[subject-permissions]] does that, and applies
> to browser and non-browser connections alike.

`same_origin: true` is the other form: the `Origin` must match the host the request arrived on. It
suits one hostname for both page and endpoint and "gets in the way as soon as they aren't" — which is
the normal case behind an ingress. Set both and a request must pass both; leave both unset, the
default, and any origin is accepted.

## Credentials for something with no filesystem

A browser has no credentials file, and a seed in front-end code is a seed the visitor has. Two
approaches work.

**A bearer JWT** presented in the connection: the user is a bearer user so no nonce signature is
required, and the page holds only a token that expires ([[operator-mode]]).

**A cookie the page cannot read.** The HTTP server that authenticated the user sets an `HttpOnly`
cookie; the browser attaches it to the handshake and the NATS server uses it as the credential. Four
cookie settings exist, one per credential kind:

| setting | cookie holds | since |
|---|---|---|
| `jwt_cookie` | a NATS user JWT | always available |
| `user_cookie` | the user name | **2.11** |
| `pass_cookie` | the password | **2.11** |
| `token_cookie` | the auth token | **2.11** |

Each is consulted **only when the client did not supply that field itself** — a JWT in `CONNECT` beats
`jwt_cookie`. `jwt_cookie` works only in operator mode, and the server refuses to start without a
trusted operator or key:

```
trusted operators or trusted keys configuration is required for JWT authentication via cookie "acme_nats_jwt"
```

For a genuinely public read-only dashboard, `no_auth_user` names the user unauthenticated WebSocket
connections bind to — give it subscribe on exactly the subjects the page shows. It does not work in
operator mode.

**Bind the credential to the transport.** `allowed_connection_types: ["WEBSOCKET"]` stops a dashboard
credential also working from a shell on 4222; a leaf dialling in over WebSocket needs `LEAFNODE_WS`.
The full value set is on [[mqtt]].

**`compress: true`** (alias `compression`) offers `permessage-deflate`, negotiated per connection, so
it costs nothing on clients that do not ask for it. It trades CPU for bytes — "a measurement rather
than a default".

## Behind a proxy

The production shape is usually TLS terminated at an ingress with the listener plaintext on a trusted
network, plus `advertise` so clients are told an address they can reach. That, the nginx block, the
two timeouts and the Kubernetes annotations are a runbook of their own:
**[[run-nats-behind-a-proxy]]**.

One rule belongs here because it is a reload hazard rather than a proxy one: **only certificate
material in the `websocket {}` block reloads.** Changing `cert_file` or `key_file` and reloading picks
up the new certificate for later connections. Any other field in the block — `verify_and_map`,
`pinned_certs`, `allowed_origins`, the timeouts — is **rejected, and a rejected field aborts the whole
reload**, including changes in the same edit that would have been accepted (source:
[[s-docs-websocket-tls-and-proxies]]). See [[reload-server-config]].

## A leaf node over the same listener

A [[leafnode]] can dial its hub over WebSocket; only the transport differs. The hub needs **both** a
`leafnodes` block — "the switch that makes this server willing to accept leaf nodes at all" — and the
`websocket {}` listener the branch actually arrives through. Drop the `leafnodes` block and the
connection is accepted and then closed. That leaves port 7422 open and never dialled, which is a
firewall item people miss for exactly that reason.

Clients and leaf nodes are told apart by the **request path**: a leaf asks for `/leafnode`, a client
for `/`. You never write `/leafnode` — the server appends it to whatever path the remote URL carries,
which is what a path-routing proxy has to account for.

**The scheme does not tell you whether a link is encrypted.** Either `wss://` or a `tls {}` block turns
TLS on, and each is enough alone; a `tls {}` block also supplies what verification needs. A `wss://`
remote against an untrusted CA still performs a handshake and fails at verification:

```
[ERR] TLS leafnode handshake error: tls: failed to verify certificate:
      x509: certificate signed by unknown authority
```

**One scheme per remote**, enforced at startup (confirmed on 2.14.6, exit 1):

```
nats-server: remote leaf node configuration cannot have a mix of websocket and non-websocket urls:
["wss://example.com:443" "nats://example.com:7422"]
```

so you cannot list an ingress and a direct leafnode port as alternatives. And **write the port**: a
leafnode URL without one gets `:7422` appended whatever the scheme, so `wss://host` quietly dials the
leafnode port and fails.

Two WebSocket-only remote settings: `ws_compression` and `ws_no_masking` (aliases
`websocket_compression`, `websocket_no_masking`). Masking exists to stop a browser poisoning
intermediary caches, "a concern that doesn't apply to a server-to-server link". Both are requests —
the hub decides, and the link works either way.

## Version notes: the 2.11 line

- **2.11.0**: WebSocket custom response headers (#5230) (source: [[s-relnotes-2.11]]).
- **2.11.12**: **`websocket { ping_interval }`** — "WebSocket-specific ping interval configuration"
  (#7614; the body prints `ping_internal`; the config reference gives the default `2m`); the buffer
  is bounded during decompression (#7625).
- **2.11.14, CVE-2026-27889** ("systems with WebSockets enabled"): 64-bit payload lengths parsed
  correctly, compressed frames rejected when compression was not negotiated, **the `Origin` check now
  validates the scheme as well as host and port**, failed upgrades handled gracefully, `CLOSE` frame
  lengths and status codes validated, the compressor reset after a max-payload error, empty
  compressed buffers no longer panic.
- **2.11.15, CVE-2026-33219**: protocol parsing "no longer relies on potentially unbounded in-memory
  allocations from compressed or uncompressed frames". **2.11.16**: a connection with no `CONNECT`
  block uses the WebSocket-specific `no_auth_user` rather than the global one.


### The 2.12 line

**2.12.0**: WebSocket (and MQTT) clients "no longer use TCP keepalives" (#7329) — the line's
`### Changed` (source: [[s-relnotes-2.12]]). **2.12.5**: buffers reused, "reducing memory pressure"
(#7901). **2.12.10**: "potential protocol-level corruption from buffer misuse in compressed
WebSocket clients" fixed (#8244). The CVE fixes are those of 2.11.14 and 2.11.15, above.


## Related

[[mqtt]] · [[run-nats-behind-a-proxy]] · [[leafnode]] · [[subject-permissions]] · [[tls-in-nats]] ·
[[operator-mode]] · [[reload-server-config]] · [[how-clients-reach-a-cluster]] ·
[[defaults-and-limits]] · [[config-keys]]

## To verify

- **How many WebSocket connections one server sustains** (question-bank Q78) is **not answered by any
  source read so far**, and was not measured. The chapter gives no number and neither does the
  reference; `max_connections` bounds all connection kinds together and is not an answer to the
  question as asked.
- **`same_origin: true`, the four cookie settings and `compress`** were not run — they need operator
  mode or a browser — and rest on [[s-docs-websocket-browsers-and-origins]] alone.
- **A leafnode over WebSocket end to end** was not run; only the mixed-scheme startup refusal was.
- **`since: 2.11`** records the release the cookie settings arrived in, which is the earliest version
  this page can cite for anything on it. No source read so far states which release first shipped the
  WebSocket listener.

## Sources

[[s-docs-websocket-your-first-websocket-connection]] · [[s-docs-websocket-browsers-and-origins]] ·
[[s-docs-websocket-tls-and-proxies]] · [[s-docs-websocket-leaf-nodes-over-websocket]] ·
[[s-nats-server-mqtt-websocket-observed]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
