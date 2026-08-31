---
title: Back up and restore identity
type: operation
kind: runbook
area: [security, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [jwt, nkey, seed, creds, operator, resolver, resolver_preload, nats-auth, curve-key, backup]
aliases: ["backup JWTs", "backup nkeys", "operator backup", "restore the operator", "identity backup", "clean-room rebuild"]
sources: [s-docs-config-and-jwt-backup, s-docs-accounts-and-multitenancy, s-docs-disaster-recovery]
created: 2026-08-31
updated: 2026-08-31
---

# Back up and restore identity

A restored stream nobody is allowed to read is not a recovery. This runbook copies the **identity
plane** — the operator, the account and user JWTs, the private seeds and the `server.conf` that
anchors them — off-site and encrypted, and puts it back in a clean-room rebuild (source:
[[s-docs-config-and-jwt-backup]]).

What an operator, account and user *are* is [[account]] and step 4 of the current plan; this page
only covers which files carry them.

## Goal

A sealed, dated, off-site copy of the whole operator subtree, plus the server config, and a restore
procedure you have **rehearsed once** — because a backup you cannot open is not a backup.

## Preconditions

- **Operator mode.** In config-mode deployments identity lives in `server.conf` itself and is backed
  up with the config ([[reload-server-config]]).
- The `nats` CLI ([[nats-cli]]) or [[nsc]] against the same on-disk store.
- Somewhere to keep the archive, and **somewhere different** to keep the key that opens it.

## What has to be backed up

| group | where | why it matters |
|---|---|---|
| **the `nats auth` store** | `$XDG_DATA_HOME/nats` (default `~/.local/share/nats`), nsc-compatible layout | `stores/…` holds the **JWTs** (public — they assert identity, they sign nothing); `keys/keys/{O,A,U}/…/*.nk` holds the **seeds** (secret) |
| **creds files** | wherever `--credential` wrote them, plus every client machine | a `.creds` file is a user's JWT and seed concatenated — the thing a client presents. **Not inside the store** |
| **`server.conf`** | the servers | not identity, but the anchor: the `operator` JWT the server trusts, `system_account`, the `resolver_preload` of the SYSTEM account, and the resolver `dir` |

**The `keys` subtree is the crown jewels.** An operator or account seed can forge identity, because
those keys sign the JWTs one level down. Treat it like stored passwords ([[nk]]).

## Steps

### 1. Seal a backup of the operator subtree

```
nats auth nkey gen curve --output backup-curve.nk
nats auth operator backup ACME acme-operator.backup --key backup-curve.nk
```

`--key` takes a **file path, not the key string**. Without it the command writes an unencrypted file
and says so:

```
WARNING: The output file is unencrypted and contains secrets,
consider encrypting it with 'nats auth nkey seal'
```

Read that literally: the file holds the operator's private seed, every signing key and every account
and user seed. **Whoever holds it is the operator.**

**Store `backup-curve.nk` somewhere other than the backups it opens.** An archive and its key in one
place is a single point of failure that defeats the backup.

### 2. Back up `server.conf` alongside it, dated

```
aws s3 cp acme-operator.backup s3://acme-dr/identity/acme-operator-2026-07-04.backup
aws s3 cp ./acme-server/server.conf s3://acme-dr/identity/server-2026-07-04.conf
```

The date is not decoration: **if you rotate the operator key, an older backup restores the previous
operator**, and a server rebuilt from it trusts a chain nobody signs under any more. Tag every
archive with the operator version it belongs to, and take a fresh backup immediately after any
rotation.

Run it on a schedule, the same way as the stream snapshot
([[backup-and-restore-jetstream]]):

```
# /etc/cron.d/acme-identity-backup — daily at 02:30
30 2 * * *  nats  /usr/local/bin/backup-identity.sh
```

### 3. Restore the store

```
nats auth operator restore ACME acme-operator.backup --key backup-curve.nk
```

**Restore brings back the original keys — it does not mint new ones.** The operator's `Subject` is
the same public key as before, so **every creds file handed out before the disaster still works**.

It refuses to overwrite: `nats: error: operator ACME already exist`. To restore over a corrupted
store, move the old store directory aside first.

### 4. Re-push the accounts into the server's resolver

**This is the step a naive restore skips, and the one that wastes an hour.** Your workstation's store
and the server's resolver directory are *separate copies* of the account JWTs. `operator restore`
rebuilds only yours. A server that lost its resolver `dir` still rejects everyone:

```
nats pub orders.new "hello" --creds order-svc.creds
nats: error: nats: Authorization Violation
```

Everything local looks correct — `nats auth account ls` lists the accounts — and no user can connect,
because the server cannot find the account JWT. Fill it:

```
nats auth account push ORDERS    --operator ACME --creds sys.creds
nats auth account push ANALYTICS --operator ACME --creds sys.creds
```

The push authenticates with the **SYSTEM** creds and gets in against an empty resolver **only
because `server.conf` preloads the SYSTEM account JWT**. That `resolver_preload` is the bootstrap
path for the whole recovery — which is why the config file belongs in the backup set.

### 5. Re-mint any creds that were lost with their machine

```
nats auth user credential order-svc.creds order-svc ORDERS
```

## Verify

```
nats auth account ls                 # every account, with its users
nats auth user ls ORDERS             # the users under one account
```

Then prove it end to end — identity plane and data plane together:

```
nats pub orders.new "back" --creds order-svc.creds
nats stream info ORDERS --creds order-svc.creds
```

If a **pre-disaster** creds file authenticates and the restored stream is readable, the platform is
back.

## Rollback

There is nothing to roll back — a restore into a clean store either works or refuses. The dangerous
direction is the other one: **moving a live store aside to restore over it**. Copy it somewhere safe
first; a store you have displaced and a backup you cannot open is the one unrecoverable state on this
page.

## Pitfalls

**The curve seed is load-bearing, and there is no recovery path.** Restoring without it fails with

```
nats: error: unmarshal failed: invalid character 'e' looking for beginning of value
```

— "no reset link, no support ticket that regenerates a seed". **Test-restore on a spare machine
once**, so you know the archive and the key actually pair up.

**A restored store does not refill the server's resolver.** Step 4. The symptom is
`Authorization Violation` while every local listing looks perfect.

**An operator rotation orphans an older archive.** Date the backups; re-take one right after any
rotation.

**The backup contains no creds files and nothing server-side.** Creds are re-minted from the restored
store; `server.conf` must be backed up separately. The resolver directory itself needs no backup —
re-pushing rebuilds it.

**An unencrypted backup in object storage is a full compromise**, not a leak. Always `--key`.

## Related

[[backup-and-restore-jetstream]] · [[disaster-recovery]] · [[account]] · [[nsc]] · [[nk]] ·
[[nats-cli]] · [[reload-server-config]] · [[install-nats-server]] · [[rotate-tls-certificates]] ·
[[operator-mode]] · [[set-up-operator-mode]]

## Sources

[[s-docs-config-and-jwt-backup]] · [[s-docs-accounts-and-multitenancy]] · [[s-docs-disaster-recovery]]
