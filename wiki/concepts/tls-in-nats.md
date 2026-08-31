---
title: TLS in NATS
type: concept
area: [security, deploy, topology]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [tls, mtls, verify, verify_and_map, handshake_first, tls_timeout, encryption-at-rest, prev_key, tls_cert_not_after]
aliases: [tls, mtls, mutual tls, verify_and_map, handshake_first, encryption at rest, tls block, certificates]
sources: [s-docs-encryption-and-tls, s-nats-server-auth-and-tls, s-gh-7684-certificate-expiry, s-docs-hardening, s-adr-40-nats-connection, s-docs-security-checklist, s-nats-server-tls-reload, s-docs-websocket-tls-and-proxies, s-docs-websocket-leaf-nodes-over-websocket, s-natscli-account-tls]
created: 2026-08-31
updated: 2026-08-31
---

# TLS in NATS

**TLS is configured per connection type, and the blocks do not inherit from each other.** The
top-level `tls {}` block secures client connections only; cluster routes, leafnodes, gateways,
monitoring, websocket and MQTT each have their own (source: [[s-docs-encryption-and-tls]]).

Four separate controls hide behind the word "TLS" here, and they are independent: encrypting the
link, *authenticating* the client on it, moving the handshake in front of the protocol, and
encrypting the JetStream store on disk.

## How it behaves

**Turning on TLS for clients leaves everything else plaintext.** The named failure: "An operator
secures clients and sees the encrypted client connection, then ships a cluster whose inter-node Raft
traffic, including replicated `ORDERS` data, is still unencrypted" (source: [[s-docs-hardening]]).
"This independence is deliberate: a laptop client and an inter-datacenter gateway have different
threat models."

**TLS terminates at the server you dial.** "The server which you talk to is itself the TLS end-point
and so sees the plaintext traffic; any routed copies of the traffic will happen outside of your TLS
connection" — so a message's protection on the second hop is the *cluster* block's business.

**Encryption is not authentication.** A `tls {}` block with the three files proves the *server* to the
client and encrypts the link. It does not ask the client for a certificate. Until `verify: true` (or
`verify_and_map: true`) is set, "any client that trusts your CA connects without presenting one".

**By default the handshake comes second.** The server sends its `INFO` line in the clear first —
version, connect URLs — and both sides then upgrade. Credentials never cross unencrypted, but the
`INFO` does. `handshake_first` reverses it.

## What configures it

```
tls {
  cert_file:       "/etc/nats/certs/server-cert.pem"
  key_file:        "/etc/nats/certs/server-key.pem"
  ca_file:         "/etc/nats/certs/ca.pem"
  timeout:         2
  verify_and_map:  true
  handshake_first: "300ms"
}
```

| key | what it does |
|---|---|
| `cert_file`, `key_file` | this server's certificate and its private key |
| `ca_file` | the authority trusted to have signed **peer** certificates |
| `timeout` | the handshake budget. **Default 2 seconds** — read from the server, not the docs; see below |
| `verify` | require and verify a client certificate (mTLS) |
| `verify_and_map` | everything `verify` does, **plus** mapping the certificate to a NATS user. "You don't set both" |
| `handshake_first` | `true`, a duration, or `"auto"` / `"auto_fallback"` |

**`tls { timeout }` defaults to 2 seconds** on every listener that has one — client, cluster,
leafnode, gateway, MQTT, and a leafnode remote (`TLS_TIMEOUT`, `const.go:108`;
`DEFAULT_LEAF_TLS_TIMEOUT`, `const.go:165`). The generated reference pages state `500ms` for all nine
`tls.timeout` keys, which is wrong — docs issue #19. The value parses as a float in seconds **or** a
duration string. `WebsocketOpts` has no TLS timeout at all; it carries a whole-handshake
`HandshakeTimeout`.

Validate the config before restarting anything: `nats-server -t -c nats.conf`. The boot log then says
`TLS required for client connections`, and "A plaintext client gets refused at the handshake; it never
reaches authentication."

### The certificate as the identity

With `verify_and_map: true` the certificate *is* the credential — no password, no creds file. The
server reads an identity out of it in a fixed order (`auth.go:1345–1395`):

1. **email SANs** → 2. **DNS SANs** → 3. **URI SANs** → 4. the **subject** DN in RFC 2253 form.

"A SAN is used only if it matches a user; when none does, the server falls back to the subject."

```
accounts {
  ORDERS {
    users: [ { user: "CN=order-svc,O=Acme"
               permissions: { publish: { allow: ["orders.>"] }, subscribe: { allow: ["_INBOX.>"] } } } ]
  }
}
```

Matching is DN-aware, not a string compare: `CN=order-svc, O=Acme` and `O=Acme,CN=order-svc` both
match, and the server "can deal with DNs which contain sets". Two details the docs omit: **only the
first peer certificate is used** (`Multiple peer certificates found, selecting first`, at debug
level), and each branch logs which field matched — `Using SAN found in cert for auth`,
`Using DistinguishedNameMatch for auth`, and so on. **That debug line is the fastest way to see why a
certificate mapped to the wrong user.**

**The user entry is the whole DN, not the CN.** Worth stating plainly because getting it wrong is
silent in the config and loud only at debug level: a certificate whose subject is `CN=leaf-A` needs
`user: "CN=leaf-A"`, and `user: "leaf-A"` fails with

```
[DBG] DistinguishedNameMatch could not be used for auth ["CN=leaf-A"]
[DBG] User in cert ["CN=leaf-A"], not found
[ERR] authentication error
```

Observed at v2.14.6 on a **leafnode** listener, where the trimmed
`leafnodes { authorization { users } }` parser takes the same entry
(source: [[s-nats-server-tls-reload]]).

### TLS-first

`handshake_first: true` puts the TLS handshake before any protocol byte, "the way an HTTPS server
behaves" — available **since 2.10.4**, and it needs both sides: the server key *and* the client's
`tls_first` option (source: [[s-adr-40-nats-connection]]). The server warns at startup:

```
[WRN] Clients that are not using "TLS Handshake First" option will fail to connect
```

A client that expects the plaintext `INFO` hangs to its read timeout and fails with
`nats: error: read tcp ...: i/o timeout`. The CLI opts in with `--tlsfirst`. For migration the key
takes `"auto"` / `"auto_fallback"` — fall back to plaintext `INFO` if no TLS bytes arrive within
**50 ms** (`DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY`, `const.go:114`) — or an explicit duration
such as `"300ms"`.

One consequence worth knowing before you debug: **`openssl s_client` against a default NATS TLS port
fails with `wrong version number`**, because the first bytes are the `INFO` line, not a TLS record.
"That error doesn't mean TLS is broken." With `handshake_first` on it works; otherwise use
`gnutls-cli --starttls --port 4222 <host>` and press Ctrl-D after the `INFO`, or read
`tls_cert_not_after` from `/varz` — see [[rotate-tls-certificates]].

### Encryption at rest

Server-wide, orthogonal to everything above: "a stream can be encrypted on disk behind a plaintext
link, or plaintext on disk behind TLS".

```
jetstream {
  store_dir: "/data/jetstream"
  key: $JS_KEY
}
```

```
[INF]   Encryption:      ChaCha20-Poly1305
```

**ChaCha20-Poly1305 is the default; `cipher: aes` switches to AES-GCM.** Rotate by restarting once
with the new key in `key` and the old in `prev_key`: "The server re-wraps the per-stream keys and
persists the result, so a later restart with only the new key recovers cleanly. `prev_key` is
transitional — drop it after the rotation restart."

The docs also suggest weighing this against block-layer encryption, which runs "beneath the visibility
of processes such as the nats-server, and do so at high performance without impacting upon server
CPU".

## Limits and failure modes

- **Cluster and gateway certificates need both `serverAuth` and `clientAuth` extended key usages.**
  Route and gateway TLS is always mutual and each node presents one certificate in both roles. The
  failure is logged **on the peer, not the misconfigured node**:
  `TLS route handshake error: ... certificate specifies an incompatible key usage` — and the cluster
  may still form "through the one direction where the bad certificate acts as the server, leaving a
  mesh that works but logs the error on every reconnect attempt". See [[build-a-3-node-cluster]].
- **Hostname verification is real.** "A certificate issued for `nats.acme.internal` rejects a client
  that specifies to connect to `127.0.0.1`". When a client sees an **IP** in the advertised server
  list, it should still verify against the original DNS hostname.
- **A `verify_and_map` mismatch looks like a password failure**: the client gets
  `nats: error: nats: Authorization Violation`, the server logs `[ERR] ... authentication error`.
  Read the DN with `openssl x509 -noout -subject` rather than typing it.
- **Certificates are read once, at startup.** Overwriting the files changes nothing until a reload,
  and even then "existing connections keep the certificate they handshook with; only new connections
  get the rotated one". An expiry that slips past fails as a handshake rejection, not an auth error.
  The reload itself does work — measured on the v2.14.6 binary, on a client listener and on a
  leafnode remote — but it gives **no positive signal**: the log lines and `config_digest` are the
  same as a reload that changed nothing, and `nats-server --signal reload` exits 0 even when the
  server refused the new material. Confirm with `/varz`'s `tls_cert_not_after`
  (source: [[s-nats-server-tls-reload]]; procedure in [[rotate-tls-certificates]]).
- **`handshake_first: true` locks out every client that has not opted in.** Migrate with a duration
  value first.
- **A wrong at-rest key hides streams; it does not destroy them.**
  `Error decrypting our stream metafile: unable to recover keys` — restart with the right key and the
  streams return. Do not leave `prev_key` set after the rotation restart: it "keeps a retired secret
  live".

## Why an operator cares

The two things that actually bite are both invisible until they matter: a cluster whose routes were
never given a `tls {}` block, and a certificate nobody was watching. The first is a config review; the
second has a mechanical answer the docs do not mention — `/varz` carries **`tls_cert_not_after`** for
every listener at v2.14.6, and `nats account tls` walks the whole verified chain, warning on anything
expiring within **`--expire-warn`, default `1w`**, and exiting non-zero so it can be a monitoring check
(source: [[s-natscli-account-tls]]). Both are in [[rotate-tls-certificates]].

## The WebSocket listener is the odd one out

Three ways the `websocket {}` block differs from every other listener's TLS
(sources: [[s-docs-websocket-tls-and-proxies]], [[s-docs-websocket-leaf-nodes-over-websocket]]):

- **TLS is required by default and must be opted out of explicitly.** With neither a `tls {}` block
  nor `no_tls: true` the server exits 1 with `websocket requires TLS configuration` — the only
  listener that refuses to run in the clear without being told to.
- **Almost nothing in the block reloads.** `cert_file` and `key_file` do, for connections made
  afterwards. Every other field — `verify_and_map`, `pinned_certs`, `allowed_origins`, the timeouts —
  is **rejected, and a rejected field aborts the entire reload**, including changes in the same edit
  that would have been accepted. See [[reload-server-config]] and [[run-nats-behind-a-proxy]].
- **The client's scheme says nothing about the server's TLS.** `wss://` describes what the *client*
  will do; behind a terminating proxy the listener itself may be plaintext with `no_tls: true`. The
  two are configured independently and a mismatch fails at the handshake.

**On a leafnode remote, `wss://` and a `tls {}` block are two independent ways to turn TLS on**, and
either is enough alone — so a remote written `ws://` with a `tls {}` block beside it *is* encrypted,
and the scheme is not a reliable reading of a config. A `wss://` remote whose hub certificate is not
publicly trusted still performs a handshake and fails at verification:

```
[ERR] TLS leafnode handshake error: tls: failed to verify certificate:
      x509: certificate signed by unknown authority
```

What fixes that is a `tls {}` block carrying the right `ca_file`, not one added to turn TLS on.

## Related

[[rotate-tls-certificates]] · [[account]] · [[subject-permissions]] · [[operator-mode]] ·
[[auth-callout]] · [[monitoring-endpoints]] · [[build-a-3-node-cluster]] · [[install-nats-server]] ·
[[reload-server-config]] · [[config-keys]] · [[defaults-and-limits]] · [[leafnode]] · [[gateway]] ·
[[how-clients-reach-a-cluster]]

## Sources

[[s-docs-encryption-and-tls]] · [[s-nats-server-auth-and-tls]] · [[s-gh-7684-certificate-expiry]] ·
[[s-docs-hardening]] · [[s-docs-security-checklist]] · [[s-adr-40-nats-connection]] ·
[[s-nats-server-tls-reload]] ·
[[s-docs-websocket-tls-and-proxies]] · [[s-docs-websocket-leaf-nodes-over-websocket]] ·
[[s-natscli-account-tls]]
