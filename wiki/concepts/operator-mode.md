---
title: Operator mode
type: concept
area: [security]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [operator, jwt, nkeys, ed25519, signing-keys, scoped, revocation, bearer, resolver, creds]
aliases: [decentralized auth, decentralized authentication, jwt auth, operator, trust chain, nkeys, scoped signing key, resolver]
sources: [s-docs-operator-mode, s-docs-decentralized-auth, s-gh-7854-jwt-push-timeout, s-nats-server-auth-and-tls]
created: 2026-08-31
updated: 2026-08-31
---

# Operator mode

**The server holds one trusted key instead of a list of users.** An operator signs accounts, an
account signs its users, and the server verifies that chain when a client connects — so a user the
server has never heard of can connect, and adding one touches no server config
(source: [[s-docs-decentralized-auth]]).

This is the same runtime model as config mode: an authenticated user, scoped to an [[account]], bound
by [[subject-permissions]]. What changes is where the identity lives and who signs it. For the build,
see [[set-up-operator-mode]].

## How it behaves

**Three identities, two signatures.** "The operator signs the account. The account signs the user."
One operator per deployment; the operator is the only thing the server is told to trust.

**NKeys are Ed25519 keypairs**, a public NKey to verify with and a private **seed** to sign with. The
server "only ever handles public NKeys and signatures, never anyone's seed". The first letter names
the role and this is guaranteed:

| prefix | identity |
|---|---|
| `O…` | operator |
| `A…` | account |
| `U…` | user |
| **`S…`** (`SO`, `SA`, `SU`) | **a seed — the private half** |

"If you ever see an ID which starts with an `S` … *be very careful*."

**The server performs exactly three checks per connection:**

1. the **nonce signature** verifies against the user's public key — this "proves the client holds the
   seed right now, not just a copy of the JWT";
2. the **user JWT** was signed by its account's identity key or one of its signing keys;
3. the **account JWT**, fetched from the resolver, was signed by the operator.

Each check defeats one forgery: a stolen JWT with no seed fails 1, a homemade user JWT fails 2, a
homemade account JWT fails 3.

**Signing keys are additional valid issuers.** An account can hold extra signing keys, and so can the
operator. "A user signed by an account signing key carries an `issuer_account` field in its JWT naming
the account it belongs to."

**A scoped signing key is how permissions arrive.** A signing key with a role name and a fixed
permission set; every user it issues gets exactly those. The user's own JWT then carries an empty
permission set (`"pub": {}, "sub": {}`) and "the server applies the key's template at connect time, so
a change to the template reaches every user signed by that key on the next account push, with no creds
re-issued".

**Nothing takes effect until the account is pushed.** Local edits — permissions, limits, revocations,
signing keys, exports and imports — all live in the account JWT, and the running server keeps using
the copy its resolver holds. This is the single most common operator-mode surprise.

## What configures it

**On the server**, three lines and a resolver — and no users at all:

```
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

- **`operator`** takes "the full operator JWT, not a bare key". Public material only — never a seed.
- **`system_account`** is required: the nats-based resolver "refuses to start without one".
- **`resolver_preload`** bakes the system account's JWT into the config so a system user can connect
  before anything has been pushed. "This only applies to the system account"
  (source: [[s-gh-7854-jwt-push-timeout]]).
- **`resolver { type: full }`** keeps one JWT file per account under `dir`. Memory, cache and URL
  resolvers exist, but "`nats auth` can only push to a full resolver".

The server prints its anchor at boot:

```
[INF] Trusted Operators
[INF]   Operator: "ACME"
[INF]   Expires : Never
```

**On the workstation**, the `nats auth` store lives under `$XDG_DATA_HOME/nats` — JWTs in `stores`,
seeds in `keys`. "That store holds every private key in the trust chain, which is why you run the tool
on a trusted machine and never on the server." It is **nsc-compatible on disk**: both tools read the
same tree.

**On the client**, a `.creds` file with two blocks — the user JWT and the user's seed. It is a
password: `0600`, never in an image, a log or a commit.

## Revocation, expiry and bearer tokens

**Revocation writes into the account JWT.** `nats auth user rm … --revoke` "writes an entry into the
`ORDERS` account JWT: a `revocations` map from the user's public key to a timestamp. Any user JWT for
that key issued at or before that time is rejected." Without `--revoke` the user is only deleted
locally and its handed-out credentials keep working.

Two mechanics matter operationally:

- **There is a window.** Between the revoke and the push, the revoked credentials still connect. The
  push closes it and disconnects live clients (`>>> Disconnected due to: EOF, will attempt reconnect`).
- **Revocation pins the key, not the name.** Re-issuing the same username creates a new key and works
  again after the next push.

**Expiry lives on the minted credential, not the stored user.** A user JWT from `nats auth user add`
**never expires**. Only `nats auth user credential … --expire 720h` mints one that lapses; "there's no
expiry flag on `user add` or `user edit`". A lapsed client gets plain `Authorization Violation`, and
the reason — `claim is expired` — appears only in the **debug** log.

**Bearer users waive check 1.** Two independent switches, both needing a push: the account must allow
bearer tokens (`--bearer` on `account add`/`account edit`; `Bearer Tokens Allowed: false` by default)
and the user must be marked (`--bearer` on `user add`). Marking only the user still gives
`Authorization Violation`. It exists "for browser and websocket clients that have nowhere safe to keep
a seed, and it reduces the credential to a single document that must never leak".

## Limits and failure modes

- **Losing the operator seed is unrecoverable.** It is the only thing that can sign an account. Back
  it up before building anything: `nats auth operator backup ACME acme-operator.backup` — a JSON
  document that "contains the operator seed in cleartext" unless `--key` encrypts it with a curve
  NKey. Store it offline. See [[backup-and-restore-identity]].
- **A scope cannot be edited in place at `nats auth` v0.4.0.** The only way to change one is to remove
  the key and re-add the role, which creates a *new* key and locks out every user signed by the old
  one at the next push. "Treat key removal as mass revocation, not as an edit."
- **A push that times out looks like nothing at all.** It publishes to `$SYS.REQ.CLAIMS.UPDATE` and
  waits; when nothing is subscribed there the CLI reports `nats: timeout` and
  `pushed to a total of 0 nats-server`, and **the server logs nothing, even at `-DV`**
  (source: [[s-gh-7854-jwt-push-timeout]]).
- **Multiple operators are supported and share a flat account namespace.** Rotating between them is
  "technically possible… It is not easy and there are no current affordances in the tooling." Plan
  around operator *signing keys* instead — "keep at least one off-line, and only keep one operator
  signing key exposed to risk".
- **Two things `nats auth` v0.4.0 cannot do**, for which `nsc` still works on the same store:
  activation tokens, and importing a single account into an existing operator.
- **Auth callout is configured differently here** — on the account's JWT rather than the server
  config, with the account declaring which other accounts the service may bind clients to (see
  [[auth-callout]]).

## Why an operator cares

Choose operator mode when tenants must issue their own credentials, or when the user list would
otherwise become a config-reload bottleneck. Choose config mode when one team owns the server and the
user list is small — the runtime model is identical, and config mode has a startup check that JWT
mode does not (an unmatched import stops the server in config mode and is silent in operator mode;
see [[cross-account-sharing]]).

The operational cost is a second source of truth. Every account change needs a push, nothing warns you
when you forget, and the only way to see what the server actually holds is
`nats auth account query`.

## Related

[[account]] · [[subject-permissions]] · [[set-up-operator-mode]] · [[auth-callout]] ·
[[cross-account-sharing]] · [[backup-and-restore-identity]] · [[nsc]] · [[nk]] · [[nats-cli]] ·
[[js-api-subjects]] · [[config-keys]]

## Sources

[[s-docs-operator-mode]] · [[s-docs-decentralized-auth]] · [[s-gh-7854-jwt-push-timeout]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-security-checklist]]
