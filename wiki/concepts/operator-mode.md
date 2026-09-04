---
title: Operator mode
type: concept
area: [security]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [operator, jwt, nkeys, ed25519, signing-keys, scoped, revocation, bearer, resolver, creds]
aliases: [decentralized auth, decentralized authentication, jwt auth, operator, trust chain, nkeys, scoped signing key, resolver]
sources: [s-docs-operator-mode, s-docs-decentralized-auth, s-gh-7854-jwt-push-timeout, s-nats-server-auth-and-tls, s-docs-security-checklist, s-docs-mqtt-auth-and-clustering, s-docs-websocket-browsers-and-origins, s-docs-authentication-basics, s-docs-authorization, s-docs-cross-account, s-gh-5941-restrict-leafnode-subjects, s-gh-7834-leafnode-same-js-domain, s-relnotes-2.11, s-jwt-imports-exports-activation, s-nsc-imports-exports-activation, s-nats-server-client-errors, s-nats-server-client-faults-observed, s-docs-resilient-clients-tls-and-auth, s-nats-go-subscription]
created: 2026-08-31
updated: 2026-09-04
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

**What this replaces.** Config mode has three credential styles — a password on the wire, an
**NKey** (the public key in the config, a signature over a server nonce on the wire, "nothing secret
crosses the wire") and a server-wide **token** — plus a fourth that is easy to forget: with mTLS the
server can map a certificate identity straight to a user, so "the cert *is* the credential". Operator
mode keeps the nonce-signature idea and moves the identity itself into a signed JWT, which is why the
NKey style is the one that translates directly. And when the chapter on the other side says "token",
it "always means this, never a JWT" (source: [[s-docs-authentication-basics]]).

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

**A scoped signing key is how permissions arrive**, and the permission model itself does not change:
the same two lists, the same "allow closes everything else" and "deny beats allow" rules, "the server
enforces the same two rules either way" (source: [[s-docs-authorization]]; [[subject-permissions]]).
A signing key carries a role name and a fixed permission set; every user it issues gets exactly
those. The user's own JWT then carries an empty
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

### What expiry looks like on the wire, and when

The page above says a lapsed client "gets plain `Authorization Violation`". That is true of a
*connect* with an already-expired JWT; a credential that lapses **under a live connection** gets a
different, more useful string. The server arms a timer at the JWT's expiry (`setExpiration` →
`time.AfterFunc(d, c.authExpired)`) and, when it fires, sends the connected client
(source: [[s-nats-server-client-errors]], measured in
[[s-nats-server-client-faults-observed]] B1/B5):

```
-ERR 'User Authentication Expired'
```

and closes with the reason `Authentication Expired` — visible on `/connz?state=closed`. When it is
the **account** JWT that lapses, the string is `-ERR 'Account Authentication Expired'` and the
account's `expiredTimeout` walks *every* client in the account and closes them all at once. A
revoked user gets `-ERR 'User Authentication Revoked'` and the reason `Revocation`.

The boundary between the two answers is one second wide, and it is worth knowing because it decides
how many reconnects a client gets. `jwt/v2` checks `now > Expires` at **one-second resolution**, so a
CONNECT arriving inside the expiry second is *accepted* — `setExpiration` computes a zero-length
timer and fires it immediately, producing `User Authentication Expired` again. From the next second
the JWT fails validation and the answer becomes `Authorization Violation`
(source: [[s-nats-server-client-errors]]).

That matters because nats.go, nats.js, nats.java and nats.net abort reconnecting when **the same
error arrives from the same server twice in a row** (source: [[s-nats-go-subscription]]). Measured
against a JWT that lapsed under load: **CLOSED 0.51 s after expiry at `ReconnectWait 500ms`, 4.12 s
at the default 2 s** — one attempt in the first case, two in the second, because the error changed
in between (B3, B6). The retry window the chapter describes is therefore one or two attempts wide;
it is not somewhere a rotation can be slotted in. Plan a credential callback or a longer expiry
instead — [[connection-closed-after-auth-error]].

Two operational corollaries:

- **The `nats` CLI will not tell you.** It sets `IgnoreAuthErrorAbort` and unlimited reconnects, so
  it retries forever; in 45 s over an expired credential it printed two lines while the server
  rejected it eleven times (B2). "The CLI still works" is not evidence the credential is valid.
- **`Authorization Violation` is deliberately uninformative.** `authViolation` sends that one string
  "regardless of the authErr override" (`client.go:2529–2530`); the real reason is in the server's
  debug log and in `/connz`'s close reason, not on the wire.


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
  activation tokens, and importing a single account into an existing operator. The substitute offered
  for private exports is **`--token-position`**, "which keys a wildcard export so each importing
  account can only import the subject carrying its own account key". And the asymmetry worth planning
  around: in config mode an unmatched import stops the server at boot, while **in operator mode both
  a dangling import and a dangling export are silent**, because "JWT mode has no startup check to
  catch a mismatch" — a real reason to wire shares in config first (source:
  [[s-docs-cross-account]]; [[cross-account-sharing]]).
- **Auth callout is configured differently here** — on the account's JWT rather than the server
  config, with the account declaring which other accounts the service may bind clients to (see
  [[auth-callout]]).
- **Leafnode permissions only exist here.** In config mode a `leafnodes { authorization }` user
  cannot carry a `permissions` block at all — `parseLeafUsers` accepts four fields and `permissions`
  is a parse error — so the only lever is the account it binds to. In operator mode the leaf presents
  a `.creds` file, the permissions travel in its user JWT, and they are reversed on the hub side and
  pushed back to the leaf for local enforcement. If you need per-subject control on a leaf link, this
  is the mode that has it (source: [[s-gh-5941-restrict-leafnode-subjects]]; [[leafnode]]).
- **A certificate-mapped system user has no password to give a leafnode remote.** With
  `verify_and_map` the certificate *is* the identity, which an operator hit head-on: "it seems
  impossible to be able to specify a password for a user on the `system_account` when using TLS."
  Since extending JetStream over a leafnode needs the connection to be on the **system account**, a
  remote that can only authenticate by certificate has to be wired accordingly — the account can hold
  both a password user and a certificate-mapped one (source:
  [[s-gh-7834-leafnode-same-js-domain]]; [[streams-not-visible-across-a-leafnode]],
  [[tls-in-nats]]).

## Private exports and activation tokens

The JWT form of "who may import" is not an account list — an account JWT's export has no such field —
but `token_req: true` plus an **activation token** per importer: a JWT the exporting account (or a
signing key of it) issues for one importing account, one subject and one kind, which the importer
carries in its import's `token`. The exporter's JWT does not change when an importer joins; it does
when one is revoked, because `revocations` live on the export (source:
[[s-jwt-imports-exports-activation]]). `nsc add export --private` and `nsc generate activation
--target-account <key> --subject <subject>` mint them (source: [[s-nsc-imports-exports-activation]]);
the commands, the check order and the alternative `account_token_position` are on
[[cross-account-sharing]], and the requester identity the exporter sees on
[[service-import-request-info]].


## Why an operator cares

Choose operator mode when tenants must issue their own credentials, or when the user list would
otherwise become a config-reload bottleneck. Choose config mode when one team owns the server and the
user list is small — the runtime model is identical, and config mode has a startup check that JWT
mode does not (an unmatched import stops the server in config mode and is silent in operator mode;
see [[cross-account-sharing]]).

The operational cost is a second source of truth. Every account change needs a push, nothing warns you
when you forget, and the only way to see what the server actually holds is
`nats auth account query`.

## Clients that cannot sign a nonce: MQTT and the browser

Operator mode authenticates by challenge — the server sends a nonce and the client signs it with the
private key in its credentials file. **Two kinds of client cannot do that**, and both are handled the
same way: with a **bearer** user, where the JWT itself is the credential and no signature is required.

**MQTT devices.** "There's nothing in the MQTT protocol that signs a server-supplied nonce", so the
device sends **the JWT as the MQTT password**, with any non-empty username. That needs the user *and*
the account marked bearer, because accounts disallow bearer tokens by default:

```
nats auth account edit SENSORS --bearer
nats auth user add sensor SENSORS --bearer
```

Miss either and the device sees **CONNACK return code 5** — MQTT clients never receive the
`Authorization Violation` string a NATS client would get, so check the CONNACK code
(source: [[s-docs-mqtt-auth-and-clustering]]).

**Browsers**, which have no filesystem to keep a credentials file in. A [[websocket]] listener can
take the JWT from an `HttpOnly` cookie the page cannot read, via `jwt_cookie` — **which only works in
operator mode**, and the server refuses to start when it is set without a trusted operator or key:

```
trusted operators or trusted keys configuration is required for JWT authentication via cookie "acme_nats_jwt"
```

`user_cookie`, `pass_cookie` and `token_cookie` arrived in **2.11**; each is consulted only when the
client did not supply that field itself (source: [[s-docs-websocket-browsers-and-origins]]).

**The cost of both is the same**: a bearer credential proves nothing beyond possession, so anyone
holding the JWT can connect as that user. Treat it like a password, put TLS in front of it, and keep
its expiry short. And `no_auth_user` is not available in operator mode at all — every connection needs
a JWT.

## Version notes: the 2.11 line

- **`default_sentinel`** (2.11.2, #6577): "a default sentinel JWT, which is used in operator mode
  when none is specified, has been added making it possible to have default users" — it must be a
  bearer token (2.11.7, #7074), or may come from a scoped signing key (2.11.9, #7217) (source:
  [[s-relnotes-2.11]]).
- **2.11.9**: an account JWT update with a reduced connection limit disconnects the newest clients
  (#7181, #7185); `cluster_traffic` restored correctly in operator mode when JetStream is enabled at
  startup (#7191). **2.11.15**: **JWTs are limited to 1 MB** (#7960). **2.11.17**: claims whose
  validity crosses midnight are validated correctly.


## Related

[[account]] · [[subject-permissions]] · [[set-up-operator-mode]] · [[auth-callout]] ·
[[cross-account-sharing]] · [[backup-and-restore-identity]] · [[nsc]] · [[nk]] · [[nats-cli]] ·
[[js-api-subjects]] · [[config-keys]] · [[leafnode]] · [[tls-in-nats]] ·
[[streams-not-visible-across-a-leafnode]]

## Sources

[[s-docs-operator-mode]] · [[s-docs-decentralized-auth]] · [[s-gh-7854-jwt-push-timeout]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-security-checklist]] ·
[[s-docs-mqtt-auth-and-clustering]] · [[s-docs-websocket-browsers-and-origins]] ·
[[s-docs-authentication-basics]] · [[s-docs-authorization]] · [[s-docs-cross-account]] ·
[[s-gh-5941-restrict-leafnode-subjects]] · [[s-gh-7834-leafnode-same-js-domain]] · [[s-relnotes-2.11]] · [[s-jwt-imports-exports-activation]] · [[s-nsc-imports-exports-activation]] · [[s-nats-server-client-errors]] · [[s-nats-server-client-faults-observed]] · [[s-docs-resilient-clients-tls-and-auth]] · [[s-nats-go-subscription]]
