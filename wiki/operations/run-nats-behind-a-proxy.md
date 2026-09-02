---
title: Run NATS WebSocket behind nginx or another proxy
type: operation
kind: runbook
area: [interop, deploy, security]
since: [2.11]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [websocket, nginx, ingress, proxy, advertise, handshake_timeout, ping_interval, kubernetes, no_tls]
aliases: [websocket behind nginx, nats behind a proxy, wss ingress, websocket proxy, proxy_read_timeout]
sources: [s-docs-websocket-tls-and-proxies, s-docs-websocket-your-first-websocket-connection, s-docs-websocket-browsers-and-origins, s-docs-websocket-leaf-nodes-over-websocket, s-nats-server-mqtt-websocket-observed]
created: 2026-09-01
updated: 2026-09-01
---

# Run NATS WebSocket behind nginx or another proxy

## Goal

Publish a NATS [[websocket]] listener through an HTTP proxy, ingress or load balancer that already
fronts your web estate, so browsers reach `wss://` and — optionally — a [[leafnode]] joins through the
same door.

## Preconditions

- A `websocket {}` block with a **port**. There is no default and a block without one starts the
  server with no listener and no log line ([[websocket]]).
- A decision on where TLS terminates. Both shapes below are normal; pick one.
- If TLS terminates at the proxy, the hop between proxy and server must be a network you trust — a
  private subnet, a service mesh, or the same host.

## Steps

### Server config — TLS on the listener

The `websocket {}` block takes the same `tls {}` fields as any other listener.

```
websocket {
  listen: 0.0.0.0:443
  tls {
    cert_file: "/etc/nats/certs/nats.example.com.pem"
    key_file:  "/etc/nats/certs/nats.example.com-key.pem"
  }
  allowed_origins [ "https://ops.example.com" ]
}
```

The log names the scheme it is serving:

```
[INF] Listening for websocket clients on wss://0.0.0.0:443
```

### Server config — TLS terminated in front

The more common shape when NATS sits behind an existing edge.

```
websocket {
  listen: 0.0.0.0:8080
  no_tls: true
  advertise: "nats.example.com:443"

  jwt_cookie: "app_nats_jwt"          # operator mode only
  allowed_origins [ "https://ops.example.com" ]
}
```

Two fields carry the weight:

- **`no_tls: true`** is correct *only* in this shape. There is no warning that distinguishes a
  trusted hop from an untrusted one — the startup line
  `Websocket not configured with TLS. DO NOT USE IN PRODUCTION!` is printed either way.
- **`advertise`** is what the server tells clients about itself. Without it a server behind NAT or a
  proxy hands out the address it sees locally, which clients cannot reach; connections succeed and
  then fail on a later reconnect to an advertised URL. See [[how-clients-reach-a-cluster]].

The client still connects with `wss://` — because the *proxy* presents the certificate. **The scheme
in the client URL and the `tls {}` block on the server are set independently**, and a mismatch fails
at the handshake.

### nginx

```
location / {
    proxy_pass http://nats-backend:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade    $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host       $host;

    # A NATS connection is idle whenever there is no traffic.
    # Outlive the ping interval or the proxy will cut it.
    proxy_read_timeout  1h;
    proxy_send_timeout  1h;
}
```

Both halves are required and they fail differently:

- **The upgrade headers.** A WebSocket connection starts as an HTTP request asking to change
  protocols. A proxy that strips `Upgrade` and `Connection` "doesn't fail loudly" — the client sends a
  handshake, gets an ordinary HTTP response, and reports a connection error that names nothing.
- **The idle timeout.** A NATS connection is idle between messages. A proxy that closes idle
  connections after 60 seconds closes a working subscription that has nothing to deliver. Set it
  longer than the interval at which the server pings its WebSocket clients — **`ping_interval` in the
  `websocket {}` block from 2.12**, and the server-wide ping interval before that.

### Kubernetes / Helm

The same two timeouts are ingress annotations rather than config directives:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

See [[kubernetes-storage]] and [[nats-helm-charts]] for the rest of the deployment.

### Path prefixes, and the one that catches leaf nodes

The rule above matches `/`, which keeps every client URL path-less. Publish NATS under a prefix
instead and the prefix must appear in the client URL too — `wss://nats.example.com:443/nats` against a
`location /nats` rule.

**A leaf node needs one more step.** The server appends **`/leafnode`** to whatever path the remote
URL carries, so a `location /nats` rule has to match `/nats/leafnode` as well. Give the remote the
prefix and the request becomes `GET /nats/leafnode`, which the rule matches:

```
leafnodes {
  remotes [ { urls: ["wss://nats.example.com:443/nats"] } ]
}
```

A proxy publishing only `/nats` never sees a bare `/leafnode`, and the branch cannot connect
([[s-docs-websocket-leaf-nodes-over-websocket]]).

### Server-side timeout

`handshake_timeout` bounds the whole setup — reading the request, the TLS handshake, and writing the
response. Behind a slow or overloaded proxy the handshake takes longer than on a direct connection, so
a value tuned on a laptop can start rejecting real clients under load. If connections fail during the
handshake **only when the system is busy**, this is the setting.

`headers` adds fixed HTTP headers to the upgrade response — how you attach something like
`Strict-Transport-Security` at the listener when no proxy is in front to add it.

## Verify

Through the proxy, with the CLI:

```
nats -s wss://nats.example.com:443 pub probe.proxy "hello"
```

Then check the listener exists at all and the origin rule behaves. A raw handshake shows the status
line directly — and note that the CLI and `curl` send **no `Origin` header**, so they are admitted
whatever `allowed_origins` says (confirmed on 2.14.6, source:
[[s-nats-server-mqtt-websocket-observed]]):

```
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: $(head -c 16 /dev/urandom | base64)" \
     -H "Origin: https://ops.example.com" \
     https://nats.example.com/
```

Expected: `HTTP/1.1 101 Switching Protocols` for a listed origin, `HTTP/1.1 403 Forbidden` for one
that is not. Use a **fresh `Sec-WebSocket-Key` per request** — reusing one draws
`websocket handshake error: invalid websocket key` in the server log.

Server side, confirm the listener came up:

```
[INF] Listening for websocket clients on wss://0.0.0.0:443
```

If that line is absent, the block set no port ([[websocket]]).

## Rollback

Everything here is config. Restore the previous `websocket {}` block and the previous proxy rule, then
reload — but see the pitfall below: a `websocket {}` reload is nearly all-or-nothing, so a rollback of
anything except certificate paths means a **restart**, not a reload ([[reload-server-config]]).

## Pitfalls

- **A proxy that drops `Upgrade` and `Connection`.** The handshake fails and the client reports a
  connection error, not a protocol error. Diagnostic: if `ws://` works against the server directly and
  fails through the proxy, this is it.
- **A proxy idle timeout shorter than the ping interval.** Connections drop on a timer with no error on
  either side. The tell is disconnects at a suspiciously round interval.
- **Only certificate material reloads.** Changing `cert_file` or `key_file` and reloading works for
  connections made afterwards. Any other field in the block — `verify_and_map`, `pinned_certs`,
  `allowed_origins`, the timeouts — is rejected, **and a rejected field aborts the entire reload**,
  including changes in the same edit that would have been accepted. Editing `allowed_origins` and a
  certificate path together loses both.
- **`no_tls: true` on a hop that is not private.** Correct behind a terminating proxy on a trusted
  network, wrong the moment that traffic crosses anything else, and there is no warning distinguishing
  the two.
- **Forgetting `advertise` behind NAT.** The server hands clients an address it can see and they
  cannot; failures appear on reconnect, not on first connect.
- **Treating `allowed_origins` as access control.** It is skipped entirely when no `Origin` header is
  present. Permissions do the real work — [[subject-permissions]].
- **A path rule that does not cover `/leafnode`.** Browsers work, the leaf never connects.

## Related

[[websocket]] · [[leafnode]] · [[tls-in-nats]] · [[reload-server-config]] ·
[[how-clients-reach-a-cluster]] · [[subject-permissions]] · [[mqtt]]

## Sources

[[s-docs-websocket-tls-and-proxies]] · [[s-docs-websocket-your-first-websocket-connection]] ·
[[s-docs-websocket-browsers-and-origins]] · [[s-docs-websocket-leaf-nodes-over-websocket]] ·
[[s-nats-server-mqtt-websocket-observed]]
