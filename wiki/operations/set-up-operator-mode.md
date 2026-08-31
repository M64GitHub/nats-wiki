---
title: Set up operator mode
type: operation
kind: runbook
area: [security]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [operator, jwt, nats-auth, nsc, resolver, account-push, creds, scoped-signing-key]
aliases: [operator mode setup, jwt setup, nsc setup, nats auth setup, account resolver setup]
sources: [s-docs-operator-mode, s-docs-decentralized-auth, s-gh-7854-jwt-push-timeout, s-nats-server-auth-and-tls]
created: 2026-08-31
updated: 2026-08-31
---

# Set up operator mode

**Goal.** Stand up an operator, its accounts and its users so that a client connects with a `.creds`
file and the server holds **no user list at all** — then leave the deployment in a state where a
tenant team can issue its own credentials without touching the server.

Every command here is quoted from [[s-docs-operator-mode]], [[s-docs-decentralized-auth]] or the
maintainer's sequence in [[s-gh-7854-jwt-push-timeout]]. The model behind them is [[operator-mode]];
read that first if you want to know *why* each step exists.

## Preconditions

- **A server at 2.2.0 or later.** The tooling says so when you create an operator —
  `When running your own nats-server, make sure they run at least version 2.2.0` — and an older one
  produces a push that times out with nothing in the log. Verified against **2.14.6**.
- **A trusted workstation.** The `nats auth` store under `$XDG_DATA_HOME/nats` holds "every private
  key in the trust chain, which is why you run the tool on a trusted machine and never on the
  server."
- **`nats` CLI v0.4.0 or later** ([[nats-cli]]). `nsc` ([[nsc]]) reads the same store and is still
  needed for activation tokens and for importing an account into an existing operator.
- **A decision about the resolver.** This runbook uses `type: full`, the recommended type and the only
  one `nats auth account push` can write to.
- Decide **before step 1** whether this operator is a throwaway. Migrating accounts between operators
  later "is not easy and there are no current affordances in the tooling".

## Steps

### 1 · Create the operator, and back it up immediately

```
nats auth operator add ACME
nats auth operator select ACME
```

```
Operator ACME (OBZITYNM2EAIJ4G5PZTH3XIRUIEIZH63YSFO2JKPNGWVFBGKBPEJP5WS)
  System Account: SYSTEM (ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46)
    Signing Keys: OABMS7LJRLJ7RX3SMV7AK3MRTJHYFN4EY5ARSMR5SKZBTOWAKPCTKVO3
```

`operator add` never prompts and always creates two extras: a **`SYSTEM` account** and **one operator
signing key**. Both matter later — the resolver needs the system account, and the signing key is what
you keep online while the operator's own seed goes in a drawer.

**Back it up now, before anything is built on it.** The operator seed is the only thing that can sign
an account, and there is no recovery:

```
nats auth nkey gen curve --output backup-curve.nk
nats auth operator backup ACME acme-operator.backup --key backup-curve.nk
nats auth operator restore ACME acme-operator.backup
```

Without `--key` the backup is "a JSON document holding the operator's keys and JWTs, so an
unencrypted backup contains the operator seed in cleartext". Store it offline. See
[[backup-and-restore-identity]] for what else belongs in that archive.

### 2 · Create the accounts

```
nats auth account add ORDERS --defaults
nats auth account add ANALYTICS --defaults
nats auth account info ORDERS
```

```
Account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU)
                 Issuer: OBZITYNM2EAIJ4G5PZTH3XIRUIEIZH63YSFO2JKPNGWVFBGKBPEJP5WS
```

`--defaults` "skips the interactive prompts for connection and subscription limits". The **`Issuer`**
line is the operator key that signed the account — the link the server verifies at connect time.

### 3 · Create a scoped signing key per role, before creating any user

Do this before step 4. A plain `nats auth user add` signs with the account's identity key and leaves
the user unrestricted; re-issuing later means revoking and redistributing credentials.

```
nats auth account keys add ORDERS order-writer --pub-allow 'orders.>' --sub-allow '_INBOX.>'
```

```
Scoped Signing Key ACQFRPTMQBCYT7QB2PRHW3XEMBZYXLOXT5V7IBYTZP3CBPV6VCW2ME5E
               Role: order-writer
```

"A scoped key pins the permissions up front, so a leaked signing key can only issue users with the
scope you already chose." The permission lists are the same two lists as
[[subject-permissions]] — `_INBOX.>` on the subscribe side for any user that makes requests, and never
`>`.

### 4 · Create the users and their credentials

```
nats auth user add order-svc ORDERS --key order-writer --defaults --credential order-svc.creds
nats auth user credential order-svc.creds order-svc ORDERS --expire 720h -f
nats auth user info order-svc ORDERS
```

```
             Issuer: ACQFRPTMQBCYT7QB2PRHW3XEMBZYXLOXT5V7IBYTZP3CBPV6VCW2ME5E
             Scoped: true
Permissions:
  Publish:      Allow: orders.>
  Subscribe:    Allow: _INBOX.>
```

`--key` takes the **role name**. `Scoped: true` and an `Issuer` that is the *signing* key rather than
the account key are the two things to check.

**Expiry lives on the minted credential, not the stored user.** A JWT from `user add` never expires;
only `nats auth user credential … --expire 720h` produces one that lapses. Pair a short expiry with a
renewal step — a lapsed client is rejected with a plain `Authorization Violation`.

Create the system user too — `SYSTEM` exists but has no user, and without one you cannot push
anything:

```
nats auth user add admin SYSTEM --defaults --credential sys.creds
```

### 5 · Generate the server config

```
nats server generate ./acme-server
```

Interactive: choose the template **`'nats auth' managed NATS Server configuration`** and answer the
prompts. It writes `./acme-server/server.conf`:

```
server_name: acme-1
listen: 0.0.0.0:4222
monitor_port: 8222

operator: eyJ0eXAiOiJKV1QiLCJhbGciOiJ…
system_account: ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46

resolver_preload {
    ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46: eyJ0eXAiOiJKV1QiLCJhbGciOiJ…
}

resolver {
   type: full
   dir: /var/lib/nats/resolver
   allow_delete: true
   interval: "2m"
   limit: 1000
}
```

Check three things by eye before you ship it: `operator` is a **JWT**, not a bare key; `system_account`
is present; and nothing in the file starts with `S`. "Server config and JWT fields only ever take
public NKeys."

`resolver.dir` must be writable and should be on the same durable volume as the rest of the server's
state — it is the only copy of every account definition the server has.

### 6 · Start the server and confirm the trust anchor

```
nats-server -c ./acme-server/server.conf
```

```
[INF] Trusted Operators
[INF]   Operator: "ACME"
[INF]   Issued  : 2026-07-03 14:18:32 +0200 CEST
[INF]   Expires : Never
[INF] Server is ready
```

If instead the server exits with

```
using nats based account resolver - the system account needs to be specified in configuration or the operator jwt
```

the `system_account` line is missing or the operator JWT was built without one.

### 7 · Push each account

The resolver directory starts empty, so until this step every client is rejected with
`nats: error: nats: Authorization Violation`.

```
nats auth account push ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth account push ANALYTICS -s nats://127.0.0.1:4222 --creds sys.creds
```

```
Updating account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU) on 1 server(s)
✓ Update completed on acme-1
Success 1 Failed 0 Expected 1
```

**Push is per account.** User JWTs are never pushed — "User definitions do not live in the server."

## Verify

**1 · The server holds what you think it holds.** Not the local store — the server's copy:

```
nats auth account query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
```

**2 · The count matches your cluster.** `Expected` is the number of servers that answered; on a
three-node cluster expect `Success 3 Failed 0 Expected 3`. A lower number means some nodes have an
older account definition and will authenticate differently from the rest.

**3 · A user connects, and the scope holds.**

```
nats pub --creds order-svc.creds orders.created '{"order_id":"ord_8w2k"}'
```

```
14:19:47 Published 24 bytes to "orders.created"
```

**4 · The scope actually denies.** This is the check people skip, and it is the one that proves the
signing key was used:

```
nats pub --creds order-svc.creds billing.charge 'x'
```

```
nats: error: nats: permissions violation: Permissions Violation for Publish to "billing.charge"
```

A **`permissions violation`** means the chain verified and the scope applied. If you get
`Authorization Violation` instead, the chain did not verify — most often the account was not pushed
after the signing key was added.

## Rollback

Operator mode is a whole-server switch, not a per-account one: a server config either has an
`operator` line or it does not.

- **To back out entirely**, restore the previous `server.conf` (accounts and users in config form) and
  restart. Reload will not do it — `no_auth_user` and trusted-operator changes are restart-only, and
  the server keeps the old config when such a reload fails ([[reload-server-config]]).
- **JetStream state does not follow.** Assets created under a config-mode account do not appear under
  a JWT account of the same name; they are different accounts to the server. Treat the switch as a
  migration and plan it with [[backup-and-restore-jetstream]].
- **To undo one account change**, edit it back in the store and push again. There is no "revert" —
  the server holds whatever was pushed last.
- **To cut off a leaked credential**, `nats auth user rm <user> <account> --revoke -f` then push. The
  push disconnects clients currently using it.

## Pitfalls

- **An edit without a push does nothing, and nothing tells you.** "The running server keeps validating
  against the copy it holds, so the edit silently has no effect: existing credentials keep connecting,
  and the old limits stay in force." This covers permissions, limits, revocations, signing keys and
  exports. Make `account push` the last line of every change, and `account query` the verification.
- **A push that times out is the operator-mode failure mode.** It publishes to
  `$SYS.REQ.CLAIMS.UPDATE` and waits:

  ```
  [ERR ] failed to get response to push account: nats: timeout
         [ OK ] pushed to a total of 0 nats-server
  ```

  **The server logs nothing, even at `-DV`** — the request arrives and nobody answers. Check, in
  order: the server is actually in operator mode, `system_account` is set, the resolver is
  `type: full`, and you are pushing at the **client** port. A too-old server gives the identical
  message (source: [[s-gh-7854-jwt-push-timeout]]).
- **A `.creds` file is a complete identity.** "There's no password to guess and no list to revoke
  against." `0600`, one client, never in an image, a log or a commit.
- **Removing a scoped key is mass revocation.** The CLI cannot edit a scope in place at v0.4.0; you
  must remove the key and re-add the role, "and every user signed by the old one is locked out at the
  next push".
- **Signing users with the account identity key works and is a trap.** Permissions then live on each
  user, and whoever holds the account seed can mint a user with any permissions at all.
- **`no_auth_user` does not exist here.** The server "rejects it alongside a trusted operator" —
  see [[account]].
- **Watch the JWTs you gave a lifetime.** Expiring credentials reduce the blast radius of a leak and
  add "a set of objects to monitor for expiration". A lapsed client's real reason, `claim is expired`,
  appears only in the **debug** log.

## Related

[[operator-mode]] · [[account]] · [[subject-permissions]] · [[backup-and-restore-identity]] ·
[[cross-account-sharing]] · [[auth-callout]] · [[nsc]] · [[nk]] · [[nats-cli]] ·
[[reload-server-config]] · [[install-nats-server]] · [[tls-in-nats]]

## Sources

[[s-docs-operator-mode]] · [[s-docs-decentralized-auth]] · [[s-gh-7854-jwt-push-timeout]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-security-checklist]]
