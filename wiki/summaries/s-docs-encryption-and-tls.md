---
title: "docs.nats.io — Encryption & TLS"
type: summary
area: [security, deploy, topology]
source-url: https://docs.nats.io/learn/security/encryption.md
source-path: raw/nats-docs/learn/security/encryption.md
author: NATS documentation (Synadia Communications, Inc.)
article: Encryption & TLS
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [tls, mtls, verify, verify_and_map, handshake_first, encryption-at-rest, prev_key, ChaCha20]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Encryption & TLS

TLS on the client link, the client certificate as an identity, the handshake moved in front of the
first protocol byte, and the JetStream store encrypted on disk. Four independent controls.

## Key claims

**TLS is per connection type, and the blocks do not inherit.** "The top-level `tls {}` block secures
client connections. It doesn't touch the others." Separate `tls {}` sub-blocks exist for monitoring,
websocket, mqtt, leafnode, cluster and gateway. "Turning on TLS for clients leaves cluster routes
plaintext until you configure the cluster block too."

**Three files and a budget:**

```
tls {
  cert_file: "/etc/nats/certs/server-cert.pem"
  key_file:  "/etc/nats/certs/server-key.pem"
  ca_file:   "/etc/nats/certs/ca.pem"
  timeout:   2
}
```

"`timeout` is the handshake budget in seconds. The default is `2`… Too short and a slow client can't
finish the negotiation; too long and a stalled handshake holds a slot open." *(The generated
reference page for the same key states `500ms` — docs issue #19.)*

Validate before starting: `nats-server -t -c nats.conf`. The boot log prints
`TLS required for client connections`, and "A plaintext client gets refused at the handshake; it
never reaches authentication."

**The client must trust the CA** — CLI flag `--tlsca`. "A certificate issued for
`nats.acme.internal` rejects a client that specifies to connect to `127.0.0.1`, because the address
isn't listed in the certificate."

**TLS terminates at the server it dials.** "The server which you talk to is itself the TLS end-point
and so sees the plaintext traffic; any routed copies of the traffic will happen outside of your TLS
connection."

**Client advertise and hostname verification:** if a NATS client "sees an IP address in the
advertised server lists, then that is treated as equivalent to an updated DNS entry, and when
reconnecting the NATS client should use the original DNS hostname as the server identity to verify
even as it connects to a specific different IP."

**`verify_and_map: true` makes the certificate the credential.** It "requires and verifies the client
certificate, then reads an identity out of it and uses that as the NATS user." The lookup order:
"the certificate's **email SANs** first, then **DNS SANs**, then **URI SANs**, and only then the
**subject** — the certificate's distinguished name in RFC 2253 form. A SAN is used only if it matches
a user; when none does, the server falls back to the subject."

```
tls { …  verify_and_map: true }

accounts {
  ORDERS {
    jetstream: enabled
    users: [ { user: "CN=order-svc,O=Acme"
               permissions: { publish: { allow: ["orders.>"] }, subscribe: { allow: ["_INBOX.>"] } } } ]
  }
}
```

The client then presents `--tlscert` and `--tlskey` and sends no password at all. Matching is
"DN-aware… not a plain string compare, so differences in attribute spacing and ordering don't
matter", and "the NATS server handles the rules and can deal with DNs which contain sets".
"`verify_and_map` includes everything `verify: true` does and adds the mapping step, so you don't set
both."

**`handshake_first` moves TLS in front of `INFO`.** By default "the server sends its `INFO` line
first, and only then do both sides upgrade to TLS. The upgrade happens before any credentials flow,
but the `INFO` itself — server version, connect URLs — crosses the wire unencrypted."

```
[WRN] Clients that are not using "TLS Handshake First" option will fail to connect
```

A client expecting plaintext `INFO` "hangs until its read timeout and fails with
`nats: error: read tcp ...: i/o timeout`". The CLI opts in with `--tlsfirst` (also on
`nats context save`). For migration the key "also accepts `"auto"` (or `"auto_fallback"`) — fall back
to plaintext `INFO` if no TLS bytes arrive within **50 ms** — or a duration like `"300ms"` for a
custom fallback delay."

**A diagnostic consequence:** "`openssl s_client` fails immediately against a default NATS TLS port
with a `wrong version number` error, because the first bytes on the wire are the plaintext `INFO`
line rather than a TLS record — that error doesn't mean TLS is broken." With `handshake_first` on it
works; otherwise `gnutls-cli --starttls --port 4222 server.host.name`, then Ctrl-D after the `INFO`.

**Encryption at rest is server-wide and orthogonal.** "It's global, not per account, and independent
of everything above — a stream can be encrypted on disk behind a plaintext link, or plaintext on disk
behind TLS."

```
jetstream {
  store_dir: "/data/jetstream"
  key: $JS_KEY
}
```

```
JS_KEY="s3cr3t-master-key" nats-server -c nats.conf
```

```
[INF]   Encryption:      ChaCha20-Poly1305
```

**ChaCha20-Poly1305 is the default; `cipher: aes` switches to AES-GCM.** Rotation: "restart once with
the new key in `key` and the old one in `prev_key`… The server re-wraps the per-stream keys and
persists the result, so a later restart with only the new key recovers cleanly. `prev_key` is
transitional — drop it after the rotation restart."

The page also advises weighing block-layer encryption instead: "some disk controllers can handle
encryption-at-rest at the block layer, beneath the visibility of processes such as the nats-server,
and do so at high performance without impacting upon server CPU."

## Practical takeaways

- **TLS without `verify` is encryption, not authentication.** "Until you add `verify: true` (or
  `verify_and_map: true`), any client that trusts your CA connects without presenting one." The proof
  is a client with no `--tlscert`:

  ```
  nats: error: remote error: tls: certificate required
  [ERR] ... TLS handshake error: tls: client didn't provide a certificate
  ```
- **Don't hand-type the DN.** Read it with `openssl x509 -noout -subject`. A mismatch gives the
  client `Authorization Violation` and the server `[ERR] ... authentication error`.
- **Cluster and gateway certificates need both `serverAuth` and `clientAuth` key usages.** "TLS
  between cluster routes and between gateways is always mutual, and each node presents its one
  certificate both as a server (accepting routes) and as a client (dialing them)." The failure is
  logged **on the peer, not the misconfigured node**:
  `TLS route handshake error: ... certificate specifies an incompatible key usage` — and "the cluster
  can still come up through the one direction where the bad certificate acts as the server, leaving a
  mesh that works but logs the error on every reconnect attempt."
- **Certificates rotate on disk, not in the server.** "The server reads `cert_file`, `key_file`, and
  `ca_file` once at startup. Overwriting the files does nothing until you signal a reload with
  `nats-server --signal reload=<pid>` (or send SIGHUP). Even then, existing connections keep the
  certificate they handshook with; only new connections get the rotated one. A certificate that
  expires unnoticed fails as a handshake rejection, not an auth error."
- **`handshake_first: true` locks out every legacy client.** Migrate with a duration first.
- **A wrong at-rest key hides streams, it does not destroy them:**
  `Error decrypting our stream metafile: unable to recover keys` — "restart with the right one and
  the stream returns." And don't leave `prev_key` set: "leaving the old key in place keeps a retired
  secret live."

## Notable quotes

> "This independence is deliberate: a laptop client and an inter-datacenter gateway have different
> threat models, so each link gets its own configuration."

> "Security decides who may access a stream; replication decides whether it's still there to be
> accessed."  *(from the chapter's closing page)*

## Relevance to the wiki

The source of [[tls-in-nats]] and half of [[rotate-tls-certificates]]. The page states the rotation
*discipline* but names no way to see an expiry date; the server grew one — `tls_cert_not_after` in
`/varz` — which this page and the whole docs tree omit (docs issue #20, found via
[[s-gh-7684-certificate-expiry]]).

## Questions it answers

Q50 (partly — the detection half is not here).

## Pages touched

[[tls-in-nats]] · [[rotate-tls-certificates]] · [[account]] · [[monitoring-endpoints]] ·
[[build-a-3-node-cluster]] · [[install-nats-server]] · [[config-keys]] · [[defaults-and-limits]]
