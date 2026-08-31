---
title: "natscli v0.4.0 — nats account tls, nats account backup / restore"
type: summary
area: [security, monitoring, jetstream]
source-url: https://github.com/nats-io/natscli/tree/v0.4.0/cli
source-path: raw/github-repos/nats-io__natscli.account-tls-v0.4.0.md
author: nats-io/natscli contributors
article: "cli/account_tls_command.go and cli/account_command.go at v0.4.0"
date: 2026-08-31
version: ""              # a CLI version, not a server version
tags: [nats-account-tls, expire-warn, ocsp, account-backup, account-restore]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# natscli v0.4.0 — `nats account tls` and `nats account backup` / `restore`

Read because two public threads needed a command neither of them named: a certificate-expiry check
([[s-gh-7684-certificate-expiry]]) and a way to move JetStream assets between accounts
([[s-gh-4535-unauthenticated-connections]]). Both exist in the CLI and neither is in the docs.

## Key claims

### `nats account tls` — "Report TLS chain for connected server"

```
nats account tls
nats account tls --expire-warn 30d
nats account tls --ocsp --no-pem
```

| flag | default | what it does |
|---|---|---|
| `--expire-warn` | **`1w`** | "Warn about certs expiring this soon, 0 to disable" |
| `--ocsp` | off | "Report OCSP information, if any" |
| `--pem` | **`true`** | "Show PEM Certificate blocks" |

**It reads the chain off the CLI's own NATS connection** — `nc.TLSConnectionState()` — so it needs
no `handshake_first`, no monitoring port and no `openssl`. It walks **every verified chain**, and
every certificate in each chain, not just the leaf.

**It is built to be a monitoring check.** Per certificate:

```
# chain=1 cert=1 isCA=false Subject="CN=order-svc,O=Acme"
#   Expiration: 2026-03-08 09:34:31 +0000 UTC
#   SAN: DNS Names: [nats.acme.internal]
#   Serial: …
#   Signed-with: ECDSA-SHA256
```

and, when a certificate is past or nearing its date:

```
# EXPIRED after 2026-03-08 09:34:31 +0000 UTC
# EXPIRING SOON: within 168h0m0s of 2026-03-08 09:34:31 +0000 UTC
```

The `Expiration:` line is emitted unconditionally and deliberately: *"Always show expiration in this
form, even if already shown, to have a stable grep pattern."*

**The command exits non-zero** on an expired or soon-to-expire certificate — it returns the first
such error, e.g. `cert expiring soon chain=1 cert=1 expiration="…" subject="…"` — which is what makes
it usable straight from cron or a health check. A source comment records what is still missing:
*"TODO: consider NAGIOS-compatible option (output format, exit statuses)."*

Two failure shapes of its own: `no verified chains found in TLS` (returned when the connection has no
verified chain), and, with `--ocsp` on a server that sends none,
`# No OCSP Response found in TLS connection`. OCSP reporting is skipped for a one-certificate chain
("Skipping OCSP verification for solo end-entity cert chain").

### `nats account backup` / `nats account restore`

```
nats account backup <target-directory>
nats account restore <directory>
```

`backup` (alias `snapshot`) — "Creates a backup of all JetStream Streams over the NATS network":

| flag | default | |
|---|---|---|
| `--check` | off | "Checks the Stream for health prior to backup" |
| `--consumers` | **`true`** | "Enable or disable consumer backups" |
| `--force` / `-f` | off | "Perform backup without prompting" |
| `--critical-warnings` / `-w` | off | "Treat warnings as failures" |

`restore` — "Restore an account backup over the NATS network", taking `--cluster` and `--tag` for
placement. The target directory must already exist.

The rest of `nats account` at v0.4.0: `info`, `report connections` (aliases `conn`/`connz`/`conns`)
and `report statistics` (`stats`/`statsz`), plus `tls`.

## Practical takeaways

- **`nats account tls --expire-warn 30d` is the certificate check to run**, not an `openssl s_client`
  pipeline: it works against a stock NATS port, covers intermediates and the CA, and fails the shell.
- **`/varz`'s `tls_cert_not_after` and `nats account tls` answer different questions.** `/varz` is the
  server's own view of the certificate *it is configured with* (leaf only, per listener); the CLI
  sees the chain *as a client verifies it*. Watch both if the CA is close to expiry.
- **`nats account backup` is the account-level analogue of `nats stream backup`** and is the
  documented-by-a-maintainer route for moving JetStream assets into a newly created account. It is
  not a cross-account *sharing* mechanism — it is a copy.
- These commands are **per connected account**: they act on whatever account the current context
  authenticates into.

## Relevance to the wiki

The verification behind [[rotate-tls-certificates]]'s monitoring section, and the reason
[[unauthenticated-clients-still-connect]] can state a migration path rather than just a warning.

## Questions it answers

Q50 (the detection half).

## Pages touched

[[rotate-tls-certificates]] · [[tls-in-nats]] · [[nats-cli]] · [[monitoring-endpoints]] ·
[[unauthenticated-clients-still-connect]] · [[backup-and-restore-jetstream]]
