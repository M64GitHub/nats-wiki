---
title: "docs — WebSocket: TLS and proxies"
type: summary
area: [interop, deploy, security]
source-url: https://docs.nats.io/learn/websocket/tls-and-proxies.md
source-path: raw/nats-docs/learn/websocket/tls-and-proxies.md
author: nats-io docs
article: "learn/websocket/tls-and-proxies.md"
date: 2026-09-01
version: ""
tags: [websocket, nginx, proxy, advertise, handshake_timeout, ping_interval, ingress, reload]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — WebSocket: TLS and proxies

The page question-bank row **Q79** asks for: running NATS WebSocket behind nginx or another proxy.
It answers it completely, with the nginx block, the two timeouts, and the Kubernetes annotations.

## Key claims

**Two shapes, both normal.** A certificate on the NATS listener, or TLS terminated in front of it.
"Which one you want depends on whether NATS sits behind the same edge as your web traffic."

**On the listener**, the `websocket {}` block "takes the same `tls {}` fields as every other listener",
and the log names the scheme: `[INF] Listening for websocket clients on wss://0.0.0.0:443`.

**Only certificate material reloads.** "Changing `cert_file` or `key_file` and sending the server a
reload picks up the new certificate for connections made afterwards; existing connections keep the one
they negotiated. **Any other change in the block — `verify_and_map`, `pinned_certs`,
`allowed_origins`, the timeouts — is rejected, and a rejected field aborts the entire reload,
including changes in the same edit that would have been accepted.**"

**Terminated in front** is "the more common shape when NATS lives behind an existing edge":

```
websocket {
  listen: 0.0.0.0:8080
  no_tls: true
  advertise: "nats.acme.example:443"
  jwt_cookie: "acme_nats_jwt"
  allowed_origins [ "https://ops.acme.example" ]
}
```

"`no_tls: true` is correct only in this shape. The hop between the proxy and the server carries
unencrypted traffic, so that hop has to be a network you trust." And "`advertise` is what the server
tells clients about itself. Without it a server behind NAT or a proxy hands out the address it sees
locally, which clients can't reach."

**Scheme and server config are independent.** "The client connects with `wss://` because the *proxy*
is presenting a certificate. Whether the NATS listener itself uses TLS is decided by its own
configuration, not by what the client typed."

**What the proxy must do**, verbatim:

```
location / {
    proxy_pass http://nats-backend:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade    $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host       $host;
    proxy_read_timeout  1h;
    proxy_send_timeout  1h;
}
```

"A proxy that strips those headers doesn't fail loudly. The client sends a handshake and gets an
ordinary HTTP response back, so the error surfaces as a connection that never establishes rather than
anything naming the proxy."

**The idle timeout is the second half.** "A NATS connection is idle between messages, and a proxy that
closes idle connections after 60 seconds will close a working subscription that has nothing to
deliver. Set the proxy's idle timeout longer than the interval at which the server pings its WebSocket
clients — **`ping_interval` in the `websocket {}` block from 2.12**, and the server-wide ping interval
before that."

**Path prefixes reach leaf nodes too.** "If you publish NATS under a prefix instead, the prefix has to
appear in the client URL too… Leaf nodes need care here: the server appends `/leafnode` to whatever
path the remote URL carries, so a `location /nats` rule has to match `/nats/leafnode` as well."

**On Kubernetes the two timeouts are ingress annotations:**

```
nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

**`handshake_timeout`** "bounds the whole setup: reading the client's request, running the TLS
handshake, and writing the response… Behind a slow or overloaded proxy the handshake takes longer than
it does on a direct connection, and a value tuned on a laptop can start rejecting real clients under
load."

**`headers`** "adds fixed HTTP headers to the upgrade response, which is how you attach something like
`Strict-Transport-Security` at the NATS listener when there's no proxy in front to add it."

## Practical takeaways

- The diagnostic that separates the two common failures: if `ws://` works against the server directly
  and fails through the proxy, the proxy is dropping `Upgrade`/`Connection`. If connections drop "at a
  suspiciously round interval", it is the idle timeout.
- The reload rule is a real operational hazard: editing `allowed_origins` and a certificate path in one
  change loses **both**.

## Notable quotes

> "A proxy that strips those headers doesn't fail loudly."

> "The pattern to look for is disconnects at a suspiciously round interval."

## Relevance to the wiki

Answers Q79 outright, and is the whole substance of [[run-nats-behind-a-proxy]]. The reload rule also
belongs on [[reload-server-config]], which has no WebSocket entry.

## Questions it answers

Q79.

## Pages touched

[[run-nats-behind-a-proxy]] · [[websocket]] · [[reload-server-config]] · [[tls-in-nats]] ·
[[how-clients-reach-a-cluster]]

## Sources

`raw/nats-docs/learn/websocket/tls-and-proxies.md`
