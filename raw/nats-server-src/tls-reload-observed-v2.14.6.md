<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-08-31 · configs and output verbatim below.
     The machine's LAN address is written as <host-ip> throughout; scratch paths are written
     as relative paths. Nothing else is edited. -->

# Observed on nats-server v2.14.6 — does a config reload pick up a renewed certificate?

Eight experiments plus two controls, run to settle question-bank row **Q97** — *"Does a config
reload actually pick up a renewed certificate file, or do I need a restart?"* — which
`wiki/operations/rotate-tls-certificates.md` carried as an open `## To verify` item, and to test the
docs' own caveat that a **leafnode remote's** certificate reload does not take.

Everything below was run on **nats-server v2.14.6** with **nats CLI 0.4.0** on darwin/arm64,
2026-08-31.

**The short answer: the reload picks it up, on both surfaces, in both shapes.** What does not work is
telling from the outside whether it did.

---

## Certificates used

One CA (`ca-one`) signs everything except where noted; a second CA (`ca-two`) exists only for the
`ca_file` experiment. All leaf certificates carry
`subjectAltName=DNS:localhost,IP:127.0.0.1` and `extendedKeyUsage=serverAuth,clientAuth`.

| name | subject | issuer | notAfter |
|---|---|---|---|
| `cert-A` | `CN=localhost` | `ca-one` | `Sep 30 20:18:19 2026 GMT` |
| `cert-B` | `CN=localhost` | `ca-one` | `Feb 16 20:18:19 2029 GMT` |
| `cert-C` | `CN=localhost` | `ca-one` | `Aug  5 20:19:24 2031 GMT` |
| `leafA-cert` | `CN=leaf-A` | `ca-one` | `Oct 10 20:21:00 2026 GMT` |
| `leafB2-cert` | `CN=leaf-B` | `ca-one` | `Oct  9 20:22:56 2030 GMT` |

`cert-A` and `cert-B` share one key (`server-key.pem`); `cert-C` has its own new key, which is the
shape a real renewal takes. Each leaf certificate has its own key.

---

## 1 · Client listener: replacing the certificate file in place

### Setup

```
port: 4322
http: 8322
server_name: tlsreload

tls {
  cert_file: "certs/server-cert.pem"
  key_file:  "certs/server-key.pem"
  ca_file:   "certs/ca.pem"
  timeout: 5
}
```

`certs/server-cert.pem` starts as a copy of `cert-A`.

```
$ curl -s http://127.0.0.1:8322/varz | jq '{version, tls_cert_not_after, config_digest}'
{
  "version": "2.14.6",
  "tls_cert_not_after": "2026-09-30T20:18:19Z",
  "config_digest": "sha256:fb55f1953de03d0d18076928f8aba67de6f43f465b04ac80cf94e7526d340276"
}
```

### Control — reload with nothing changed

```
$ nats-server --signal reload=96322
[96322] 2026/08/31 22:19:05.413084 [INF] Reloaded: authorization users
[96322] 2026/08/31 22:19:05.413289 [INF] Reloaded: accounts
[96322] 2026/08/31 22:19:05.413296 [INF] Reloaded: tls = enabled
[96322] 2026/08/31 22:19:05.413489 [INF] Reloaded server configuration (sha256:fb55f195…)
```

```
tls_cert_not_after 2026-09-30T20:18:19Z      # unchanged, as expected
```

**`Reloaded: tls = enabled` is printed by a reload that changed nothing.** It is not evidence that a
certificate was picked up.

### The swap

```
$ cp certs/cert-B.pem certs/server-cert.pem
$ openssl x509 -in certs/server-cert.pem -noout -enddate
notAfter=Feb 16 20:18:19 2029 GMT

# before the signal — the file on disk is new, the server is not
tls_cert_not_after 2026-09-30T20:18:19Z

$ nats-server --signal reload=96322
[96322] 2026/08/31 22:19:06.508879 [INF] Trapped "hangup" signal
[96322] 2026/08/31 22:19:06.509193 [INF] Reloaded: authorization users
[96322] 2026/08/31 22:19:06.509198 [INF] Reloaded: accounts
[96322] 2026/08/31 22:19:06.509201 [INF] Reloaded: tls = enabled
[96322] 2026/08/31 22:19:06.509218 [INF] Reloaded server configuration (sha256:fb55f195…)
```

```
$ curl -s http://127.0.0.1:8322/varz | jq '{tls_cert_not_after, config_digest, config_load_time}'
{
  "tls_cert_not_after": "2029-02-16T20:18:19Z",
  "config_digest": "sha256:fb55f1953de03d0d18076928f8aba67de6f43f465b04ac80cf94e7526d340276",
  "config_load_time": "2026-08-31T20:19:06.509221Z"
}
```

**The reload picked the new certificate up.** Two things about the evidence:

- **`config_digest` did not move.** It is the digest of the configuration *text*, which did not
  change — only the file it points at did. A monitoring check that watches `config_digest` to decide
  whether a rotation landed will never fire.
- **The log lines are byte-for-byte the ones the control printed.** `config_load_time` moved, but it
  moves for the control too. `tls_cert_not_after` is the only field that distinguishes the two.

## 2 · Client listener: a new key as well as a new certificate

The realistic renewal — certbot and friends write a fresh keypair.

```
$ cp certs/cert-C.pem certs/server-cert.pem
$ cp certs/key-C.pem  certs/server-key.pem
$ nats-server --signal reload=96322
$ curl -s http://127.0.0.1:8322/varz | jq .tls_cert_not_after
"2031-08-05T20:19:24Z"
```

Works. No restart.

## 3 · What a client sees

Between experiments 1 and 2, with `cert-B` live:

```
$ nats --server tls://localhost:4322 --tlsca=certs/ca.pem account tls --no-pem
# TLS Verified Chains count: 1

# chain: 1
# chain=1 cert=1 isCA=false Subject="CN=localhost"
#   Expiration: 2029-02-16 20:18:19 +0000 UTC
#   SAN: DNS Names: [localhost]
#   SAN: IP Addresses: [127.0.0.1]
#   Serial: 391616146607954062661277814658098414747163876298
#   Signed-with: SHA256-RSA
# chain=1 cert=2 isCA=true Subject="CN=wiki-test-ca"
#   Expiration: 2036-08-28 20:18:19 +0000 UTC
#   Serial: 200717926799124199811543587982216608012470419167
#   Signed-with: SHA256-RSA
```

Serial `3916161466…876298` is `0x4498ACE412340E9A8DC3ABB3CF8000F0CA24DBCA`, i.e. `cert-B`. The client
gets the rotated certificate on a **new** connection; the `/varz` field and the client's view agree.

## 4 · A half-finished renewal: certificate and key that do not match

The common incident — the renewal wrote one file and not the other.

```
$ cp certs/cert-B.pem certs/server-cert.pem      # key on disk is still key-C

$ nats-server -t -c nats.conf
nats-server: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key
$ echo $?
1

$ nats-server --signal reload=96322
$ echo $?
0
```

The server log:

```
[96322] 2026/08/31 22:19:37.955475 [INF] Trapped "hangup" signal
[96322] 2026/08/31 22:19:37.955796 [ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key
```

**`nats-server --signal reload` exits 0 even when the reload it asked for failed.** The signal
sender learns nothing; the failure is in the server's log and nowhere else.

The old certificate stays live and clients keep working:

```
$ curl -s http://127.0.0.1:8322/varz | jq .tls_cert_not_after
"2031-08-05T20:19:24Z"                      # cert-C, the last good one

$ nats --server tls://localhost:4322 --tlsca=certs/ca.pem rtt
tls://localhost:4322:
       tls://[::1]:4322: 114µs
```

## 5 · The certificate file missing entirely

```
$ mv certs/server-cert.pem certs/parked.pem
$ nats-server --signal reload=96322 ; echo $?
0
[96322] 2026/08/31 22:19:52.514442 [ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: open certs/server-cert.pem: no such file or directory
$ curl -s http://127.0.0.1:8322/varz | jq .tls_cert_not_after
"2031-08-05T20:19:24Z"
```

Same shape: loud in the log, silent to the caller, old certificate retained. Restoring a matching
pair and reloading again returns the server to normal with no restart.

---

## Leafnode remotes

The generated reference carries a caveat on six keys under
`reference/config/leafnodes/remotes/tls/` — *"On 2.11/2.12 the reload succeeds but the old
certificate keeps being used"* (`cert_file`) and *"…but nothing changes"* (`ca_file`, `key_file`,
`cipher_suites`, `curve_preferences`, `insecure`). None of the six says whether this still holds on
2.14. Three of them were tested here.

### Setup

Hub, with a mutual-TLS leafnode listener that maps the peer certificate to a user:

```
port: 4400
http: 8400
server_name: hub
leafnodes {
  port: 7422
  authorization {
    users: [ { user: "CN=leaf-A" } ]
  }
  tls {
    cert_file: "c/hub-cert.pem"
    key_file:  "c/hub-key.pem"
    ca_file:   "c/ca1.pem"
    verify_and_map: true
    timeout: 5
  }
}
```

Leaf:

```
port: 4401
http: 8401
server_name: leaf
leafnodes {
  remotes: [
    {
      url: "tls://localhost:7422"
      tls {
        cert_file: "c/leaf-live-cert.pem"
        key_file:  "c/leaf-live-key.pem"
        ca_file:   "c/ca1.pem"
        timeout: 5
      }
    }
  ]
}
```

**Why this rig.** The hub accepts exactly one identity, `CN=leaf-A`. Swapping the leaf's certificate
for `CN=leaf-B` — same CA, so the leaf's own TLS stack still offers it — makes the hub say out loud
which certificate the leaf presented. A leafnode connection only re-handshakes when it is
re-established, so each measurement is taken after restarting the **hub**, which forces the leaf to
re-dial.

### The identity `verify_and_map` matches is the DN string, not the CN

First attempt used `users: [ { user: "leaf-A" } ]` and every connection was rejected:

```
[98987] … [DBG] … DistinguishedNameMatch could not be used for auth ["CN=leaf-A"]
[98987] … [DBG] … User in cert ["CN=leaf-A"], not found
[98987] … [ERR] … authentication error
[98987] … [INF] … Leafnode connection closed: Authentication Failure
```

The user entry has to be the RFC 2253 distinguished name, `CN=leaf-A`. With that, the leaf connects:

```
leafz leafnodes: 1
[99270] 2026/08/31 22:23:19.519609 [INF] 127.0.0.1:60403 - lid:5 - Leafnode connection created
```

### Control 1 — restart the hub, no reload anywhere

```
leafz initial:                          1
leafz after hub restart, NO reload:     1
[98477] 2026/08/31 22:22:04.270379 [INF] Listening for leafnode connections on 0.0.0.0:7422
[98477] 2026/08/31 22:22:06.065195 [INF] 127.0.0.1:60364 - lid:5 - Leafnode connection created
```

A hub restart by itself does not disturb the leaf's certificate.

### Control 2 — reload the leaf with no file change, then restart the hub

```
leafz after reload(no change) + hub restart:   1
[98676] 2026/08/31 22:22:23.123341 [INF] 127.0.0.1:60369 - lid:5 - Leafnode connection created
```

A reload by itself does not disturb it either. So anything the next two experiments show is caused
by the change, not by the reload or the restart.

### 6 · Leafnode remote, file replaced in place

```
$ cp c/leafB2-cert.pem c/leaf-live-cert.pem
$ cp c/leafB2-key.pem  c/leaf-live-key.pem
$ nats-server --signal reload=<leaf-pid>
[734] … [INF] Reloaded: cluster
[734] … [INF] Reloaded server configuration (sha256:1f458bc2…)

leafz immediately after the reload:   1        # the open connection keeps CN=leaf-A
```

Then the hub is restarted to force a re-handshake:

```
leafz after reload + re-handshake:    0
[99494] 2026/08/31 22:23:40.971524 [DBG] 127.0.0.1:60413 - lid:9 - User in cert ["CN=leaf-B"], not found
[99494] 2026/08/31 22:23:40.971569 [INF] 127.0.0.1:60413 - lid:9 - Leafnode connection closed: Authentication Failure
```

**The leaf presented `CN=leaf-B` — the new certificate.** The reload took. The existing connection
kept the old one until it re-handshook, which is the documented behaviour everywhere else.

### 7 · Leafnode remote, `cert_file`/`key_file` repointed in the config text

The files are left alone and the config is edited to name `c/leafB2-cert.pem` and
`c/leafB2-key.pem` instead:

```
leafz after path change + reload + re-handshake:   0
[878] 2026/08/31 22:24:46.152150 [DBG] <host-ip>:60447 - lid:10 - User in cert ["CN=leaf-B"], not found
[878] 2026/08/31 22:24:46.152183 [INF] <host-ip>:60447 - lid:10 - Leafnode connection closed: Authentication Failure
```

Same result. Both shapes of the change — new bytes behind the same path, and a new path — reach the
running server.

### 8 · Leafnode remote, `ca_file` repointed

Restored to `CN=leaf-A` (leafz back to 1), then the remote's `ca_file` is pointed at `ca-two`, which
did not sign the hub's certificate:

```
leafz right after reload (existing conn):   1
leafz after re-handshake:                   0

[734] 2026/08/31 22:25:13.979743 [ERR] 127.0.0.1:7422 - lid:33 - TLS leafnode handshake error: tls: failed to verify certificate: x509: certificate signed by unknown authority (CN=localhost SHA-256: c21dd8faf081da032d545d0f54ba93e7a2ed8f2bc4bac181819a963968ff9c61)
[734] 2026/08/31 22:25:12.969976 [INF] <host-ip>:7422 - lid:32 - Leafnode connection closed: TLS Handshake Failure
```

The new trust store is in force. `ca_file` reloads on a leafnode remote at v2.14.6.

**Three of the six caveated keys were tested — `cert_file`, `key_file` and `ca_file` — and all three
reload.** `cipher_suites`, `curve_preferences` and `insecure` were not tested.

### A note on how not to test this

The first attempt used a leaf certificate signed by a CA the hub did **not** trust, expecting a
handshake rejection to prove the swap had landed. The hub instead logged
`tls: client didn't provide a certificate`: Go's TLS client filters its own certificates against the
acceptable-CA list in the server's `CertificateRequest`, so a certificate under an unknown CA is
never offered at all. The outcome still pointed the right way — had the reload *not* taken, the
trusted `CN=leaf-A` would have been offered and accepted — but it cannot distinguish "the new
certificate was rejected" from "no certificate was sent". Keeping both certificates under one CA and
identifying them by subject is the design that answers the question.

---

## 9 · `nats server check` has no certificate-expiry check at CLI v0.4.0

Checked because `wiki/operations/rotate-tls-certificates.md` asked whether one exists to pair with
`nats account tls` in a monitoring pipeline.

```
$ nats --version
0.4.0
$ nats server check --help
Subcommands:
  server check connection  Checks basic server connection
  server check stream      Checks the health of mirrored streams, streams with sources or clustered streams
  server check consumer    Checks the health of a consumer
  server check message     Checks properties of a message stored in a stream
  server check meta        Check JetStream cluster state
  server check request     Checks a request-reply service
  server check jetstream   Check JetStream account state
  server check server      Checks a NATS Server health
  server check kv          Checks a NATS KV Bucket
  server check credential  Checks the validity of a NATS credential file
```

`server check connection` carries only timing thresholds (`--connect-warn`, `--rtt-warn`,
`--req-warn` and their `-critical` twins). `server check credential` checks a **NATS credential
file** — `--credential`, `--validity-warn`, `--validity-critical`, `--require-expiry` — which is a
user JWT, not an X.509 certificate. Nothing under `nats server check` reads a TLS certificate.

So the only two X.509 expiry surfaces at v2.14.6 / CLI v0.4.0 remain `/varz`'s `tls_cert_not_after`
(leaf certificate, per listener) and `nats account tls --expire-warn` (the whole verified chain, but
with no `--format=nagios|prometheus` support, since it is not a `check` subcommand).
