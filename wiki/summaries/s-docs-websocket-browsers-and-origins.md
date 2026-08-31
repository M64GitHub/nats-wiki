---
title: "docs — WebSocket: Browsers and origins"
type: summary
area: [interop, security]
source-url: https://docs.nats.io/learn/websocket/browsers-and-origins.md
source-path: raw/nats-docs/learn/websocket/browsers-and-origins.md
author: nats-io docs
article: "learn/websocket/browsers-and-origins.md"
date: 2026-09-01
version: ""
tags: [websocket, allowed_origins, same_origin, jwt_cookie, user_cookie, bearer, no_auth_user, compress]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — WebSocket: Browsers and origins

The security surface a browser adds: which pages may open a connection, and how one proves identity
without a credentials file. The page is unusually careful about what origin checking is **not**, and
the running server bears that out exactly.

## Key claims

**`allowed_origins` is an exact string match on scheme, host and port.** Against
`allowed_origins ["http://localhost:8000"]`:

| `Origin` the browser sends | handshake |
|---|---|
| `http://localhost:8000` | `101 Switching Protocols` |
| `http://127.0.0.1:8000` | `403 Forbidden` |
| `https://localhost:8000` | `403 Forbidden` |
| `http://localhost:8001` | `403 Forbidden` |
| `http://localhost` | `403 Forbidden` |

"The match is exact on scheme, host and port, and it's a string comparison, not a name resolution."
A URL with no port means 80 or 443, "so `https://ops.acme.example` and `https://ops.acme.example:8443`
are different origins". Aliases: `origins`, `origin`, `allowed_origin`, `allow_origins`,
`allow_origin`.

**`same_origin: true`** "requires the `Origin` header to match the host the request arrived on… and
gets in the way as soon as [the page and the endpoint] aren't [one hostname]." Set both and a request
must pass both. Leave both unset — the default — and any origin is accepted.

**The check is skipped when there is no `Origin` header**, and this is the page's central point. The
`nats` CLI connects straight through an origin-restricted listener because "it sends no `Origin`
header at all, and the server only runs the check when the header is present."

> "That is not a bug, and it isn't something you can configure away. The `Origin` header is set by the
> browser, not by the person using it, which is exactly what makes it useful: a page on `evil.example`
> cannot lie about being `https://ops.acme.example`. Anything that isn't a browser sets its own
> headers, so an attacker writing a client simply omits it."

"So `allowed_origins` answers one question: *may this web page open a connection using a visitor's
browser?* It does not answer *may this connection reach my subjects?* — permissions do that."

**Two ways to give a browser credentials.** A **bearer JWT** in the connection ("the page never holds
a signing key — only a token that expires"), or **a cookie** the page cannot read: "The HTTP server
that authenticated the user sets a cookie with `HttpOnly`, so scripts on the page can't read it, and
the browser attaches it to the WebSocket handshake."

**Four cookie settings**, matching the four things a client can present:

| setting | cookie holds |
|---|---|
| `jwt_cookie` | a NATS user JWT |
| `user_cookie` | the user name |
| `pass_cookie` | the password |
| `token_cookie` | the auth token |

"`jwt_cookie` has always been available. The other three arrived in `nats-server` **2.11**."
"Each one is only consulted when the client didn't supply that field itself. A JWT in the `CONNECT`
protocol wins over `jwt_cookie`."

**`jwt_cookie` only works in operator mode**, and the server refuses to start otherwise:
`trusted operators or trusted keys configuration is required for JWT authentication via cookie
"acme_nats_jwt"`.

**`no_auth_user`** "names a user that unauthenticated WebSocket connections bind to… It doesn't work
in operator mode."

**`allowed_connection_types: ["WEBSOCKET"]`** binds a credential to the transport; `LEAFNODE_WS` for a
leaf dialling in over WebSocket.

**`compress: true`** offers `permessage-deflate`, negotiated per connection — "a client that doesn't
ask for it gets an uncompressed connection, and the setting costs nothing on those". "It's a
measurement rather than a default." Alias: `compression`.

## Practical takeaways

- The single most important sentence for an operator: origin checking constrains browsers and nothing
  else. Any deployment that treats it as access control is unprotected against anything that isn't a
  browser.
- A dashboard credential should be `WEBSOCKET`-only and subscribe-only.

## Notable quotes

> "Anything that isn't a browser sets its own headers, so an attacker writing a client simply omits
> it."

> "Anything the page can read, a visitor can read."

## Relevance to the wiki

[[subject-permissions]] and [[tls-in-nats]] never touched origin checking, and the four cookie
settings appear nowhere in this wiki. This is the security half of [[websocket]].

## Questions it answers

Q79 (partly).

## Pages touched

[[websocket]] · [[subject-permissions]] · [[operator-mode]] · [[defaults-and-limits]]

## Sources

`raw/nats-docs/learn/websocket/browsers-and-origins.md` · reproduced against the server in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
