---
title: Rotate TLS certificates
type: operation
kind: runbook
area: [security, deploy, monitoring]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [tls, certificates, rotation, expiry, tls_cert_not_after, nats-account-tls, reload, SIGHUP]
aliases: [certificate rotation, cert rotation, certificate expiry, tls renewal, rotate certs]
sources: [s-docs-encryption-and-tls, s-gh-7684-certificate-expiry, s-natscli-account-tls, s-nats-server-auth-and-tls, s-docs-config-management, s-nats-server-systemd-units, s-docs-hardening, s-nats-server-tls-reload, s-docs-security-checklist]
created: 2026-08-31
updated: 2026-09-03
---

# Rotate TLS certificates

**Goal.** Replace a server's certificate before it expires, without dropping clients — and know how
many days you have left, on every listener, without opening a TLS connection by hand.

Two facts shape the whole procedure: the server reads its certificate files **once, at startup**, and
a rotated certificate reaches **only new connections** (source: [[s-docs-encryption-and-tls]]).

The docs' security checklist compresses this whole runbook into one line — "**Rotate certificates
ahead of expiry and send `nats-server --signal reload` afterwards; certificate files are read once at
startup**" — and the four preconditions below are the checklist's other TLS items read as
prerequisites rather than as review questions: TLS on the cluster, leafnode and gateway blocks too;
both `serverAuth` and `clientAuth` on a cluster certificate; the mapped user string matched against
the certificate identity (`openssl x509 -noout -subject`); and a TLS-first migration done with a
duration before `true` (source: [[s-docs-security-checklist]]). Nothing on this page contradicts it;
what the page adds is what each of those costs when you are the one doing it at 2am.

## Preconditions

- A server with a `tls {}` block on at least one listener; see [[tls-in-nats]] for which blocks
  exist and why they do not inherit.
- **The new certificate's SANs cover every name and address clients dial**, including the loopback
  address if anything connects that way. A SAN mismatch fails the handshake, not authentication.
- **On a cluster or gateway, the certificate carries both `serverAuth` and `clientAuth`** extended key
  usages. Route TLS is always mutual and each node presents its one certificate in both roles.
- Know whether anything maps identities out of certificates (`verify_and_map`). If so, the new
  certificate must keep the **same** subject or SAN that the user entry names, or every mapped client
  becomes an authentication failure at once.
- Write access to the certificate paths, and the ability to signal the process
  ([[reload-server-config]]).

## Steps

### 1 · Find out what is actually deployed and when it expires

Two views, and you want both — they answer different questions.

**The server's own view, per listener** — `/varz` carries `tls_cert_not_after` at v2.14.6, top level
and on the `cluster`, `gateway`, `leafnode`, `mqtt` and `websocket` objects
(`monitor.go:1838–1845`):

```
curl -s http://127.0.0.1:8222/varz | jq '{client: .tls_cert_not_after, cluster: .cluster.tls_cert_not_after, leaf: .leafnode.tls_cert_not_after, gateway: .gateway.tls_cert_not_after}'
```

The value is the `NotAfter` of the **leaf certificate of the first configured certificate**, and the
field is **omitted entirely** when that listener has no TLS — an absent key means "no certificate
here", not "no expiry". This is the field [[s-gh-7684-certificate-expiry]] asked for; it shipped in
[PR #7709](https://github.com/nats-io/nats-server/pull/7709), and no docs page mentions it.

**A client's view of the whole chain** — `nats account tls` walks every verified chain, every
certificate in it, and exits non-zero when anything is expired or expiring:

```
nats account tls --expire-warn 30d
```

```
# TLS Verified Chains count: 1

# chain: 1
# chain=1 cert=1 isCA=false Subject="CN=nats.acme.internal"
# EXPIRING SOON: within 720h0m0s of 2026-03-08 09:34:31 +0000 UTC
#   Expiration: 2026-03-08 09:34:31 +0000 UTC
#   SAN: DNS Names: [nats.acme.internal]
```

`--expire-warn` defaults to **`1w`**; `0` disables the warning. Add `--ocsp` for OCSP information and
`--no-pem` to drop the PEM blocks. It reads the chain off the CLI's own NATS connection, so it needs
no `handshake_first` and no monitoring port. The `Expiration:` line is emitted for every certificate
deliberately, "to have a stable grep pattern" (source: [[s-natscli-account-tls]]).

**Do not reach for `openssl s_client` against port 4222.** It fails with `wrong version number`,
because the first bytes on a default NATS TLS port are the plaintext `INFO` line. That is expected
behaviour, not a broken server. If you must use `openssl`, point it at the **HTTPS monitoring port**,
or set `handshake_first: true` on the client listener first.

### 2 · Stage the new files

Write the new certificate and key next to the old ones and switch the paths atomically, so a
half-written file is never what the server reads:

```
install -m 0600 -o nats -g nats new-server-cert.pem /etc/nats/certs/server-cert.pem.new
install -m 0600 -o nats -g nats new-server-key.pem  /etc/nats/certs/server-key.pem.new
mv /etc/nats/certs/server-cert.pem.new /etc/nats/certs/server-cert.pem
mv /etc/nats/certs/server-key.pem.new  /etc/nats/certs/server-key.pem
```

**If the CA is changing too, add the new CA to `ca_file` before you swap the leaf**, and remove the
old one only after every peer presents a certificate under the new authority. A `ca_file` holding
both roots is valid and is what makes a CA migration survivable.

### 3 · Validate, then signal

```
nats-server -t -c /etc/nats/nats.conf
```

`-t` parses the config and reads the certificate files, so a malformed or unreadable PEM is caught
before it reaches a running server ([[s-docs-config-management]]).

```
nats-server --signal reload=<pid>
```

or `systemctl reload nats-server` — both units the repo ships set
`ExecReload=/bin/kill -s HUP $MAINPID` (source: [[s-nats-server-systemd-units]]). The server logs:

```
[INF] Reloaded: tls = enabled
```

The reload is driven by a diff of the parsed options, so a certificate whose **content** changed
produces a `tlsconfig` change even though the path did not. What the reload cannot do is reach a
connection that has already handshaken.

**The reload does pick the new file up — measured, not assumed.** On the v2.14.6 binary, replacing
`cert_file` in place and signalling moved `/varz`'s `tls_cert_not_after` from `2026-09-30T20:18:19Z`
to `2029-02-16T20:18:19Z`; replacing **both** files with a fresh keypair, the shape a real renewal
takes, worked the same way (source: [[s-nats-server-tls-reload]]). No restart is needed on either
surface tested — a client listener or a leafnode remote.

**But the reload tells you nothing.** Those four `Reloaded:` lines, including `Reloaded: tls =
enabled`, are printed **verbatim by a reload that changed nothing** — the no-op control was run first
for exactly this reason. `config_digest` does not move either: it digests the configuration *text*,
which is unchanged when only the file behind the path is new. So a monitoring check watching the log
or the digest will never see a rotation, and will never see one fail. **`tls_cert_not_after` is the
only field that distinguishes a landed rotation from a no-op** — which is why *Verify* below leads
with it.

**And `nats-server --signal reload` exits 0 even when the reload failed.** With a certificate and key
that do not match — a renewal that wrote one file and not the other — the server logs

```
[ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key
```

and the signal command still exits **0**. A missing certificate file behaves identically
(`open certs/server-cert.pem: no such file or directory`). This is why step 3 starts with
`nats-server -t`, which catches both, exits **1** and names the file and line. The consolation is
that a failed reload is safe: the **old certificate stays live** and clients keep connecting and
handshaking normally (source: [[s-nats-server-tls-reload]]).

### 4 · Roll the connections that still hold the old certificate

Existing connections keep the certificate they negotiated for their whole life. Whether you need to
force them depends on the certificate:

- **A renewal from the same CA, same names** — let clients pick it up on their next reconnect. Nothing
  to do.
- **A revoked or compromised certificate** — the old one must stop being used *now*. Drain each server
  in turn so clients reconnect and re-handshake: the lame-duck procedure in
  [[upgrade-a-cluster]], one node at a time, gated on the cluster staying healthy.
- **A cluster or gateway certificate** — the routes themselves are long-lived connections. They
  re-handshake when the route is re-established, so the same one-node-at-a-time drain applies, and
  [[build-a-3-node-cluster]]'s checks are the ones to gate on.
- **A leafnode remote's certificate** — the same, and it is the case most likely to be missed,
  because the leaf holds *one* long-lived connection to the hub. The reload does replace the
  certificate the leaf will present, but the hub keeps seeing the **old** identity until that
  connection re-establishes: observed at v2.14.6, where the hub still counted the leaf as connected
  under the previous certificate immediately after the reload and only saw the new one after a
  re-handshake (source: [[s-nats-server-tls-reload]]). See [[leafnode]].

## Verify

**1 · The server reports the new date, on the listener you changed:**

```
curl -s http://127.0.0.1:8222/varz | jq .tls_cert_not_after
```

**This is the check, not a nicety.** The reload's log lines and `config_digest` are identical whether
the rotation landed or did nothing, and the signal command exits 0 either way — so a date that has
*not* moved means the reload did not take the new file, and the server log will say why
(source: [[s-nats-server-tls-reload]]). Compare against the file you just installed:

```
openssl x509 -in /etc/nats/certs/server-cert.pem -noout -enddate
```

**2 · A client verifies the new chain end to end:**

```
nats account tls --expire-warn 30d
```

Exit status 0 and no `EXPIRING SOON` line. A non-zero exit names the offending chain and certificate.

**3 · Nothing regressed on the routes.** After a cluster-certificate change, check the peer's log,
not the node you touched — a wrong key usage is reported by the *other* side:

```
TLS route handshake error: ... certificate specifies an incompatible key usage
```

and the mesh may still look up while logging this on every reconnect. `nats server list` showing every
node with the same `Routes` count is the check ([[build-a-3-node-cluster]]).

**4 · Mapped identities still map.** If `verify_and_map` is on, connect one mapped client. A mismatch
gives the client `nats: error: nats: Authorization Violation` and the server
`[ERR] ... authentication error`; debug logging names which certificate field was tried
(`Using SAN found in cert for auth`, `Using DistinguishedNameMatch for auth`).

## Rollback

- **Before the signal**: move the old files back. Nothing has changed in the running server.
- **After the signal**: restore the old certificate and key, `nats-server -t`, signal again. New
  connections revert immediately; connections made in between keep the newer certificate until they
  reconnect.
- **If the server refuses to reload**, the old configuration stays active — a failed reload does not
  take the server down. Fix the file and signal again.
- **If a rotation left clients failing anyway**, restarting the server is the blunt instrument that
  is known to work: the incident in [[s-gh-7684-certificate-expiry]] was resolved that way after a
  reload appeared not to take effect. Nobody in that thread diagnosed why, and this wiki cannot
  reproduce it: at v2.14.6 the reload picks the file up on every shape tested
  (source: [[s-nats-server-tls-reload]]). Before restarting, read the server log for
  `Failed to reload server configuration` — a reload that was **refused** looks from the outside
  exactly like one that did nothing, and is by far the likelier explanation. Treat a restart as the
  escalation, not the routine.

## Pitfalls

- **Overwriting the files does nothing on its own.** No watcher, no timer. The reload signal is the
  whole mechanism, and forgetting it is the classic Let's Encrypt-renewal failure: the certificate on
  disk is valid and the one in memory is not.
- **Do not gate a rotation script on the exit status of `nats-server --signal reload`.** It exits 0
  whether the reload was applied or refused. Gate on `nats-server -t` before it (exit 1 on a bad
  pair, with the file and line) and on `tls_cert_not_after` after it.
- **Do not alert on `config_digest` to catch a rotation.** Rotating a certificate does not change the
  configuration text, so the digest is unchanged — a landed rotation and a forgotten one look
  identical through that field.
- **`/varz` shows the leaf only.** An expiring **intermediate or root** fails the handshake exactly
  the same way and does not appear there. `nats account tls` walks the chain; alert on both.
- **An expired certificate is a handshake rejection, not an auth error.** Clients report
  `x509: certificate has expired or is not yet valid` and never reach authentication, so nothing shows
  up in your auth metrics.
- **Rotating a cluster certificate is a cluster operation.** Do one node at a time and confirm the
  mesh between each, or you can end up with a partially re-formed cluster that logs errors on the
  peers and looks healthy on the node you are watching.
- **Do not turn on `handshake_first: true` just to make `openssl` work.** It locks out every client
  that has not opted in. If you want the port to behave like an ordinary TLS endpoint, migrate with a
  duration (`handshake_first: "300ms"`) and flip to `true` only after the last client has opted in.
- **Encryption at rest is a different key with a different procedure.** The JetStream `key` /
  `prev_key` rotation needs a **restart**, not a reload, and `prev_key` must be dropped afterwards —
  see [[tls-in-nats]].

## Settled by running it

Both of this page's open questions were answered on the v2.14.6 binary on 2026-08-31; the runs are in
`raw/nats-server-src/tls-reload-observed-v2.14.6.md` and summarised in [[s-nats-server-tls-reload]].

- **Does a reload pick up changed certificate files? Yes** — on a client listener and on a leafnode
  remote, with the file replaced in place and with the path changed in the config, and with a fresh
  keypair as well as a fresh certificate. The failure reported in
  [[s-gh-7684-certificate-expiry]] did not reproduce. What did emerge is that a reload gives no
  positive signal, and that a *refused* reload is indistinguishable from a successful one anywhere
  except the server log — which is a sufficient explanation for an operator concluding "the reload
  didn't work", without the reload being broken.
- **`nats server check` has no certificate-expiry check** at natscli **v0.4.0**. Its ten subcommands
  are `connection`, `stream`, `consumer`, `message`, `meta`, `request`, `jetstream`, `server`, `kv`
  and `credential`; `connection` carries only timing thresholds, and `credential` checks a NATS
  **credential file** — a user JWT, with `--validity-warn` / `--validity-critical` — not an X.509
  certificate. So a Nagios or Prometheus pipeline gets its certificate expiry from `/varz`'s
  `tls_cert_not_after` (leaf certificate, per listener) or from `nats account tls --expire-warn`'s
  exit status (whole chain, but no `--format` support, since it is not a `check` subcommand).

## To verify

- The three remaining caveated leafnode-remote keys — `cipher_suites`, `curve_preferences` and
  `insecure` — which the generated reference says reload without effect on 2.11/2.12 and which were
  **not** tested here. `cert_file`, `key_file` and `ca_file` were, and all three reload.

## Related

[[tls-in-nats]] · [[reload-server-config]] · [[monitoring-endpoints]] · [[upgrade-a-cluster]] ·
[[build-a-3-node-cluster]] · [[install-nats-server]] · [[nats-cli]] · [[account]] ·
[[subject-permissions]] · [[config-keys]]

## Sources

[[s-docs-encryption-and-tls]] · [[s-gh-7684-certificate-expiry]] · [[s-natscli-account-tls]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-config-management]] · [[s-docs-hardening]] ·
[[s-nats-server-systemd-units]] · [[s-nats-server-tls-reload]] ·
[[s-docs-security-checklist]]