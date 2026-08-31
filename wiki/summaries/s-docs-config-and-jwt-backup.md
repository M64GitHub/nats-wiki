---
title: "docs.nats.io — Config and JWT backup"
type: summary
area: [security, deploy]
source-url: https://docs.nats.io/learn/backup-recovery/config-and-jwt-backup.md
source-path: raw/nats-docs/learn/backup-recovery/config-and-jwt-backup.md
author: NATS documentation (Synadia Communications, Inc.)
article: Config and JWT backup
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [jwt, nkey, seed, creds, operator, resolver, nats-auth, backup, curve-key]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Config and JWT backup

Backing up the **identity plane**: the JWTs and seeds that decide who may touch the platform, the
`server.conf` that anchors them, and the one restore step teams miss. The data half of recovery is
useless without this half — "a restored `ORDERS` stream is useless if nobody is allowed to read it".

## Key claims

**Three groups of files carry identity**, and losing each breaks the platform differently:

1. **The `nats auth` store** under `$XDG_DATA_HOME/nats` (default `~/.local/share/nats`), whose
   on-disk layout "is nsc-compatible": `stores/<OPERATOR>/…` holds **JWTs** (public: "they assert
   identity, they sign nothing"), `keys/keys/O|A|U/…/*.nk` holds **seeds** (secret). "A leaked
   operator or account seed lets identity be forged … a lost seed means that identity is lost."
2. **The creds files** — "a user's JWT and seed concatenated into one file", living wherever
   `--credential` wrote them and on the client machines. **Not inside the store.**
3. **The server config** — "It isn't identity itself, but it anchors it: the operator JWT the server
   trusts, the `SYSTEM` account preload, and the resolver directory where account JWTs land."

```
operator: eyJ0eXAiOiJKV1Qi...
system_account: AAW27T5RB3M5GNDKLGEZ...
resolver_preload {
    AAW27T5RB3M5GNDKLGEZ...: eyJ0eXAiOiJKV1Qi...
}
resolver {
   type: full
   dir: /var/lib/nats/resolver
}
```

**One command backs up the whole subtree:**

```
nats auth operator backup ACME acme-operator.backup
```

```
Wrote backup for ACME to acme-operator.backup

WARNING: The output file is unencrypted and contains secrets,
consider encrypting it with 'nats auth nkey seal'
```

> "Whoever holds this one file *is* the `ACME` operator. Never ship it anywhere unencrypted."

**Sealed with a curve key** — and the flag takes a **file path, not the key string**:

```
nats auth nkey gen curve --output backup-curve.nk
nats auth operator backup ACME acme-operator.backup --key backup-curve.nk
```

> "Store it somewhere other than the location holding the backups; keeping an archive and its key in
> the same place is a single point of failure that defeats the backup."

**Two things the backup does not contain**: creds files ("re-minted from the restored store") and
anything server-side — "back up `server.conf` alongside it". The resolver directory needs no backup:
"re-pushing the accounts rebuilds it."

**Restore is one command, and it keeps the original keys:**

```
nats auth operator restore ACME acme-operator.backup --key backup-curve.nk
```

> "The `Subject` is the same operator public key as before the loss: restore brings back the original
> keys, it doesn't mint new ones. That has a useful consequence — **every creds file you handed out
> before the disaster keeps working**."

It "refuses to run if the operator already exists in the store
(`nats: error: operator ACME already exist`) … to restore over a corrupted store, move the old store
directory aside first."

**The step a naive restore skips.** The workstation store and the server's resolver directory are
**separate copies**:

```
nats pub orders.new "hello" --creds order-svc.creds
nats: error: nats: Authorization Violation
```

> "The resolver directory is empty, so the server can't find the `ORDERS` account JWT."

```
nats auth account push ORDERS --operator ACME --creds sys.creds
```

> "The push itself authenticates with the `SYSTEM` creds, and it can get in even though the resolver
> is empty **because `server.conf` preloads the `SYSTEM` account JWT**. That preload is the bootstrap
> path for the whole recovery."

Re-mint a lost creds file: `nats auth user credential order-svc.creds order-svc ORDERS`.

**Three pitfalls:**

1. **The backup file is the whole authority**, and the curve seed is now load-bearing: restoring
   without it fails with `unmarshal failed: invalid character 'e' looking for beginning of value`,
   and "there's no recovery path: no reset link, no support ticket that regenerates a seed.
   **Test-restore on a spare machine once** so you know the file and the key actually pair up."
2. **A restored store does not refill the server's resolver** — the `Authorization Violation` above.
3. **An operator rotation orphans an older archive**: a backup predating the rotation "restores an
   operator nobody signs accounts under anymore". Date every backup; take a fresh one right after any
   rotation.

## Practical takeaways

- **Two copies of the account JWTs exist, and only one is yours.** The store is your workstation's;
  the resolver `dir` is the server's. A restore that stops at the store leaves a cluster that rejects
  every user while every local check looks correct — the most confusing failure on this page.
- **`resolver_preload` of the SYSTEM account is the bootstrap.** Without `server.conf` in the backup
  set there is no way in to push the other accounts.
- **The backup file outranks any single key.** Seal it, and store the curve seed elsewhere.
- **Restore preserves identity, so nothing has to be re-issued** — the reason a clean-room rebuild
  can be invisible to clients.
- **Date the backup against the operator version**, because identity rotation is the one change that
  silently invalidates an archive.

## Notable quotes

> "Whoever holds this one file *is* the `ACME` operator."

> "A restored store doesn't refill the server's resolver."

## Relevance to the wiki

The whole of [[backup-and-restore-identity]]. The identity model it deliberately does not teach is
step 4's ([[account]], [[nsc]], [[nk]]).

## Questions it answers

Contributes to **Q32** (the half of "back up JetStream" that is not the stream) and to **Q49**.

## Pages touched

[[backup-and-restore-identity]] · [[account]] · [[nsc]] · [[nk]] · [[nats-cli]] ·
[[disaster-recovery]] · [[config-keys]]
