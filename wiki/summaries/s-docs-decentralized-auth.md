---
title: "docs.nats.io — Decentralized authentication"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/decentralized-auth.md
source-path: raw/nats-docs/learn/security/decentralized-auth.md
author: NATS documentation (Synadia Communications, Inc.)
article: Decentralized authentication
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [jwt, nkeys, ed25519, signing-keys, scoped, revocation, bearer, expiry, ADR-14]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Decentralized authentication

What the server actually verifies when a creds file connects, and the three things that make the
model workable in production: scoped signing keys, revocation and expiry.

## Key claims

**Three identities, two signatures.** "The operator signs the account. The account signs the user."
One operator per deployment; each account is its own identity; each user belongs to an account.

**NKeys are Ed25519**, "the same elliptic-curve signature scheme used for SSH and modern code
signing". Public NKey to verify, private seed to sign; "The server only ever handles public NKeys
and signatures, never anyone's seed."

**Signing keys are extra valid issuers.** "An account can hold extra **signing keys** that also count
as valid issuers for its users… and the operator can hold signing keys for accounts the same way. A
user signed by an account signing key carries an `issuer_account` field in its JWT naming the account
it belongs to."

**The server performs exactly three checks per connection:**

1. "The nonce signature verifies against the user's public key named in the user JWT. This proves
   the client holds the seed right now, not just a copy of the JWT."
2. "The user JWT was signed by the account that issued it… against the account's identity key or one
   of its signing keys."
3. "The account JWT, fetched from the resolver, was signed by the operator… against the keys in the
   operator JWT it was configured with."

Each check maps to a forgery: a copied JWT without the seed fails 1; a homemade user JWT fails 2; a
homemade account JWT fails 3.

**A user JWT is not the config "token".** "That token is a password-style secret the server compares
against its config, while a user JWT is a signed document anyone can inspect but only the right
account (signing) key can produce."

**Scoped signing keys are how permissions arrive.** A signing key with a role name and a fixed
permission set; "Every user issued by that key gets exactly those permissions."

```
nats auth account keys add ORDERS order-writer --pub-allow 'orders.>' --sub-allow '_INBOX.>'
nats auth user rm order-svc ORDERS --revoke -f
nats auth user add order-svc ORDERS --key order-writer --defaults --credential order-svc.creds -f
nats auth user credential order-svc.creds order-svc ORDERS --expire 720h -f
nats auth user info order-svc ORDERS
```

`user info` then shows `Issuer: ACQFRPTM…` (the scoped key, not the account identity key) and
`Scoped: true`.

**A scoped user's own JWT is empty.** "The scoped user's own JWT carries an empty permission set
(`"pub": {}, "sub": {}`). The server applies the key's template at connect time, so a change to the
template reaches every user signed by that key on the next account push, with no creds re-issued."

**A scoped key is invisible until the account is pushed** — before the push the new creds fail with
`Authorization Violation`; after it, an out-of-scope publish fails differently, with
`nats: error: nats: permissions violation: Permissions Violation for Publish to "billing.charge"`.
"This time it's a permission error rather than an authentication one."

**Revocation is an entry in the account JWT.** `nats auth user rm … --revoke` "writes an entry into
the `ORDERS` account JWT: a `revocations` map from the user's public key to a timestamp. Any user JWT
for that key issued at or before that time is rejected." Without `--revoke` the command "only deletes
the user from your local store; credentials already handed out keep working, because the server never
consults your store."

Two mechanics the page demonstrates end to end:

- **There is a window.** "Between `user rm --revoke` and the push, the revocation exists only in your
  local store, so the revoked creds still connect and publish." The push closes it and disconnects
  live clients: `>>> Disconnected due to: EOF, will attempt reconnect`.
- **Revocation pins the key, not the name.** "Re-issuing `order-svc` creates a new key, so the new
  creds work after the next push."

**Expiry lives on the minted credential, not the stored user.** `--expire 720h` on
`nats auth user credential`; "there's no expiry flag on `user add` or `user edit`." A lapsed client
gets plain `Authorization Violation`; "The server's default log records only an `authentication
error`; the underlying reason, `claim is expired`, appears in its debug log."

**Bearer tokens are check 1, waived.** Two switches are needed, both pushed:

- the account must allow it — `--bearer` on `nats auth account add`/`account edit`
  (`Bearer Tokens Allowed: false` by default);
- the user must be marked — `--bearer` on `nats auth user add` (`Bearer Token: true`).

"Marking the user isn't enough" — both rejections print the same `Authorization Violation`. It is
"a convenience for browser and websocket clients that have nowhere safe to keep a seed, and it
reduces the credential to a single document that must never leak."

**Multiple operators are supported and are a flat namespace.** "They are equivalent, and the
namespace of accounts is flat across all operators." Rotating operators is "technically possible…
It is not easy and there are no current affordances in the tooling to assist with such a migration."
The advice: "Use operator signing keys and keep at least one off-line, and only keep one operator
signing key exposed to risk."

## Practical takeaways

- **Back up the operator before building on it:** `nats auth operator backup ACME
  acme-operator.backup` writes "a JSON document holding the operator's keys and JWTs, so an
  unencrypted backup contains the operator seed in cleartext"; `--key` encrypts it with a curve NKey.
  Restore with `nats auth operator restore ACME acme-operator.backup`. "Store the file offline."
- **Never paste an `S…` string anywhere.** "Treat every `S`-prefixed string like a password."
- **Prefer a scoped key to the account identity key.** With the identity key "whoever holds the
  account's seed can issue a user with any permissions" (see
  [ADR-14](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-14.md)).
- **Removing a scoped key is mass revocation, not an edit.** "The CLI has no command to edit a scope
  in place, so the only way to change one is to remove its key… That creates a new key, and every
  user signed by the old one is locked out at the next push."
- **A `user add` JWT never expires**, so a leaked creds file "is valid until you revoke it".

## Notable quotes

> "'Vouches for' has a precise meaning here: it means signs."

> "A signature check works for a user the server has never seen — no config entry has to exist
> before the user connects."

## Relevance to the wiki

The model half of Q49, and the whole of what [[operator-mode]] states about revocation, expiry and
scoped keys. It also explains why [[backup-and-restore-identity]] exists: the operator seed is the
one thing with no recovery path.

## Questions it answers

Q49 (with [[s-docs-operator-mode]]).

## Pages touched

[[operator-mode]] · [[set-up-operator-mode]] · [[account]] · [[subject-permissions]] · [[nk]] ·
[[nsc]] · [[nats-cli]] · [[backup-and-restore-identity]]
