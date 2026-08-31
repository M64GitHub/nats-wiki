---
title: "nats-server v2.14.6 — does a reload pick up a renewed certificate?"
type: summary
area: [security, deploy, topology, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/tls-reload-observed-v2.14.6.md
author: nats-io/nats-server contributors (the binary); this wiki (the experiments)
article: "Eight experiments and two controls run on the v2.14.6 binary with nats CLI 0.4.0"
date: 2026-08-31
version: "2.14.6"
tags: [tls, reload, SIGHUP, cert_file, key_file, ca_file, tls_cert_not_after, config_digest, verify_and_map, leafnode-remote]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — does a reload pick up a renewed certificate?

Run to settle question-bank row **Q97** — *"Does a config reload actually pick up a renewed
certificate file, or do I need a restart?"* — which [[rotate-tls-certificates]] carried as an open
`## To verify` item after [[s-gh-7684-certificate-expiry]] reported a reload that appeared not to
take and nobody diagnosed it. It also tests the generated reference's claim that a **leafnode
remote's** certificate reload does not work.

Everything below was **run on the v2.14.6 binary** with **nats CLI 0.4.0**, darwin/arm64,
2026-08-31. Configs and verbatim output in `raw/nats-server-src/tls-reload-observed-v2.14.6.md`.

## Key claims

**1 · The reload picks the certificate up.** A client listener's `cert_file` replaced in place, same
key, then `nats-server --signal reload=<pid>`:

```
tls_cert_not_after 2026-09-30T20:18:19Z    ->    2029-02-16T20:18:19Z
```

A **new keypair** (both files replaced, the shape a real renewal takes) works too:
`2031-08-05T20:19:24Z`. No restart in either case. `nats account tls` confirms it from the client
side — the serial and expiry a new connection sees are the new certificate's.

**2 · Nothing in the log or the config digest tells you it happened.** The reload prints

```
[INF] Reloaded: authorization users
[INF] Reloaded: accounts
[INF] Reloaded: tls = enabled
[INF] Reloaded server configuration (sha256:fb55f195…)
```

and prints **exactly the same four lines for a reload that changed nothing** — the control was run
first for this reason. `config_digest` is the digest of the configuration *text*, which does not
change when only the file behind `cert_file` does; it was byte-identical before and after a
successful rotation. `config_load_time` moves for the no-op reload too. **`tls_cert_not_after` is the
only field that distinguishes a landed rotation from a no-op.**

**3 · `nats-server --signal reload` exits 0 even when the reload failed.** With a certificate and key
that do not match — the half-finished-renewal shape — the server logs

```
[ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key
```

while the signal command exits **0**. A missing certificate file behaves identically
(`open certs/server-cert.pem: no such file or directory`). In both cases the **old certificate stays
live** and clients keep connecting; `nats account tls` and `nats rtt` still work. `nats-server -t`
catches both before the signal, exits **1**, and names the file and line.

**4 · A leafnode remote's TLS material reloads at v2.14.6.** The generated reference carries this on
six keys under `reference/config/leafnodes/remotes/tls/`:

> "On 2.11/2.12 the reload succeeds but the old certificate keeps being used." (`cert_file`)
> "On 2.11/2.12 the reload succeeds but nothing changes." (`ca_file`, `key_file`, `cipher_suites`,
> `curve_preferences`, `insecure`)

Three of the six were tested with a hub that accepts exactly one certificate identity
(`verify_and_map: true` plus `leafnodes { authorization { users: [ { user: "CN=leaf-A" } ] } }`), so
the hub says out loud which certificate the leaf presented:

| change | result after re-handshake |
|---|---|
| `cert_file`+`key_file` files replaced in place | leaf presents `CN=leaf-B` — the **new** certificate |
| `cert_file`+`key_file` **paths** changed in the config | leaf presents `CN=leaf-B` |
| `ca_file` repointed to a CA that did not sign the hub | `x509: certificate signed by unknown authority` |

Both controls are clean: a hub restart with no reload, and a reload with no file change, both leave
the leaf connected. **`cipher_suites`, `curve_preferences` and `insecure` were not tested.**

**5 · The existing connection keeps its certificate, on both surfaces.** Immediately after the leaf's
reload the hub still counted the leafnode as connected under the *old* identity; only the
re-handshake (forced by restarting the hub) showed the new one. This is the behaviour the docs state
generally, now observed on a leafnode remote.

**6 · `verify_and_map` matches the RFC 2253 DN, not the bare CN** — confirmed the hard way. A user
entry of `leaf-A` against a certificate whose subject is `CN=leaf-A` fails:

```
[DBG] DistinguishedNameMatch could not be used for auth ["CN=leaf-A"]
[DBG] User in cert ["CN=leaf-A"], not found
[ERR] authentication error
[INF] Leafnode connection closed: Authentication Failure
```

The entry has to read `user: "CN=leaf-A"`. This is the order [[tls-in-nats]] already describes from
`auth.go:1345–1395`, observed on a **leafnode listener**, where the trimmed
`leafnodes { authorization { users } }` parser accepts it.

**7 · `nats server check` has no certificate-expiry check at CLI v0.4.0.** The ten subcommands are
`connection`, `stream`, `consumer`, `message`, `meta`, `request`, `jetstream`, `server`, `kv`,
`credential`. `connection` carries only timing thresholds; `credential` checks a **NATS credential
file** (a user JWT) with `--validity-warn` / `--validity-critical`, not an X.509 certificate.

## Practical takeaways

- Rotation is a reload, on client listeners and on leafnode remotes alike. Restarting is the
  escalation, not the routine.
- **Verify with `tls_cert_not_after`, never with the log line or `config_digest`.** Both are
  identical for a reload that did nothing.
- **Never gate a rotation on the exit status of `nats-server --signal reload`.** Gate on
  `nats-server -t` before it and on `tls_cert_not_after` after it, and read the server log for
  `Failed to reload server configuration`.
- A failed certificate reload is safe: the running server keeps serving the last good certificate.
- On a hub-and-spoke the leaf's new certificate only reaches the hub when the leafnode connection
  re-establishes. Plan the re-handshake; do not assume the reload finished the job.

## Notable quotes

> `[ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key`

> `[DBG] User in cert ["CN=leaf-B"], not found`

## Relevance to the wiki

Closes the largest open `## To verify` item on [[rotate-tls-certificates]], supplies the reload
pitfall on [[reload-server-config]], and gives [[leafnode]] its first statement about rotating a
remote's certificate. Behind docs issue **#34**.

## Questions it answers

**Q97** — does a config reload pick up a renewed certificate file? **Yes**, on both surfaces tested,
in both shapes of the change; the trap is that nothing observable except `tls_cert_not_after` says so.

## Pages touched

[[rotate-tls-certificates]] · [[reload-server-config]] · [[tls-in-nats]] · [[leafnode]] ·
[[monitoring-endpoints]]

## Sources

The v2.14.6 binary itself. Source ranges for the mechanisms are in
[[s-nats-server-auth-and-tls]] (`Varz.TLSCertNotAfter` and the certificate-to-user mapping order);
the incident that raised the question is [[s-gh-7684-certificate-expiry]].
