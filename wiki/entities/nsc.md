---
title: nsc
type: entity
kind: tool
area: [security, deploy]
verified-against: nsc v2.15.0
verified-on: 2026-08-31
tags: [tool, nsc, operator-mode, jwt, nkeys, accounts, users]
aliases: [nsc, "nats-io/nsc"]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nsc

The **standalone identity CLI**: operators, accounts, users, signing keys and the JWTs that carry
them. It is "An alternative to the `nats auth` commands built into the `nats` CLI; **reads the same
on-disk store** and covers operations `nats auth` doesn't yet" (source: [[s-docs-ecosystem]]).

## Where it fits

Operator mode — the decentralized, JWT-based authentication model — is configured entirely with this
tool or with [[nats-cli]]'s `nats auth`. Nothing else in the ecosystem creates an operator.

## Facts

| | |
|---|---|
| repo | `nats-io/nsc` |
| latest release | **v2.15.0**, 2026-06-02 |
| licence | Apache-2.0 |
| store root | `$XDG_DATA_HOME/nats/nsc/` — "the on-disk layout is nsc-compatible" with `nats auth` |
| store shape | `accounts/` (JWTs, `nsc.json`) and `nkeys/` (`creds/`, `keys/`) |
| docs | `https://nats-io.github.io/nsc/` |
| bundled in | [[nats-box]] |

```
curl -sf https://binaries.nats.dev/nats-io/nsc/v2@latest | sh    # latest binary here
brew tap nats-io/nats-tools && brew install nats-io/nats-tools/nsc
nsc update                                                       # self-update
```

## What an operator needs to know

- **One store, two front ends.** `nsc` and `nats auth` read and write the same tree, so you can move
  between them command by command. The docs' own examples use `nats auth`; `nsc` is what you fall
  back to.
- **Two things `nats auth` v0.4.0 cannot do yet**, named by the docs: **activation tokens** and
  **importing a single account into an existing operator**. Both are cross-account operations, which
  is exactly where multi-tenant deployments end up.
- **The store is the crown jewels.** `nkeys/keys/` holds seeds. Back it up encrypted — the docs'
  backup path is `nats auth operator backup ACME acme-operator.backup --key backup-curve.nk`, where
  the curve key encrypts the archive.
- **Creating an account is not deploying it.** Account JWTs must be **pushed** to the server
  (`nats auth account push … --creds sys.creds`) or served by a resolver; a locally created account
  the cluster has never seen does not exist.

## Cheat sheet

The docs' worked examples use `nats auth`; the equivalents map roughly one to one onto `nsc`.

```
# in the nats-box container, with the store mounted
docker run --rm -it -v $(pwd)/nsc:/nsc natsio/nats-box:latest
nsc init -d /nsc
```

```
# the same lifecycle through the nats CLI, as the docs write it
nats auth operator add ACME
nats auth account  add ORDERS --defaults
nats auth account  keys add ORDERS order-writer
nats auth user     add order-svc ORDERS --key order-writer --defaults
nats auth user     credential order-svc.creds order-svc ORDERS --expire 720h -f
nats auth user     info order-svc ORDERS
nats auth user     rm  order-svc ORDERS --revoke -f
nats auth account  edit ORDERS --connections 50
nats auth account  push  ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth account  query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth account  ls
nats auth user     ls ORDERS
nats auth nkey     gen user  --output user.nk
nats auth nkey     gen curve --output backup-curve.nk
nats auth operator backup  ACME acme-operator.backup --key backup-curve.nk
nats auth operator restore ACME acme-operator.backup --key backup-curve.nk
```

## Related

[[nats-cli]] · [[nk]] · [[nats-box]] · [[account]] · [[nats-server]] · [[rotate-tls-certificates]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
