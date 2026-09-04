---
title: "docs — Resilient Clients: TLS & Auth"
type: summary
area: [clients, security]
source-url: https://docs.nats.io/learn/resilient-clients/tls-and-auth.md
source-path: raw/nats-docs/learn/resilient-clients/tls-and-auth.md
author: NATS documentation
article: "learn/resilient-clients/tls-and-auth.md, fetched 2026-08-31"
date: 2026-08-31
version: "unversioned by design"
tags: [creds, tls, tlsca, tlsfirst, handshake_first, mtls, nonce, auth-error-abort, IgnoreAuthErrorAbort, credential-rotation]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs — Resilient Clients: TLS & Auth

The last mechanism page of the `learn/resilient-clients` chapter, and the only place in the docs
tree that states the **per-client auth-error abort rules** side by side. Like the rest of the
chapter it names no version (`where-next.md:20`), so every version-bearing claim on the pages it
feeds comes from [[s-nats-go-subscription]], [[s-nats-server-client-errors]] and
[[s-nats-server-client-faults-observed]].

## Key claims

### Consuming a `.creds` file

- The file "holds two things: a user JWT that names the `order-svc` user, and an nkey seed, a
  private key the client uses to sign a challenge" (`:10`). The client is handed a *path*; it reads
  both itself.
- The handshake: the server's `INFO` carries `auth_required` and a one-time **nonce**; the client
  signs the nonce with the seed and sends the signature with the JWT in `CONNECT`; "A valid
  signature proves the client holds the seed… with no password ever sent over the wire" (`:12`).
- The CLI flag is `--creds`; "nats.js takes the file's contents as bytes instead" (`:14`).
- "The creds file is the whole identity. There's no `--user` and no `--password`" (`:92`).

### The CA, and the two handshake orders

- One input for the client: the CA certificate. "if it doesn't, the client aborts before sending
  any credentials" (`:98`).
- The default order: plaintext `INFO` (carrying `tls_required`) → TLS upgrade and CA validation →
  `CONNECT` with the creds. "TLS proves the server, then the creds prove the client, and no
  credential is ever sent before TLS is established" (`:100`).
- `handshake_first` "in the server's `tls` block — the CLI's `--tlsfirst` — moves the TLS handshake
  ahead of that first `INFO`" (`:100`).
- **Both sides must opt in**: "a `--tlsfirst` client fails its TLS handshake against a server that
  still sends the plaintext `INFO`, and a client expecting `INFO` gets nothing from a
  handshake-first server until the attempt fails with a timeout or EOF error" (`:100`). Confirmed
  for `handshake_first: true` — 2.055 s to an `i/o timeout` — and **wrong for the fallback
  settings**, which the page never mentions: `handshake_first: "auto"` (a 50 ms fallback) and a
  duration both let a plain client connect ([[s-nats-server-client-faults-observed]] C3, C4). Docs
  issue #98; the sibling `learn/security/encryption.md:281` does document the fallback.
- CLI flags: `--tlsca`, and the `tls://` URL scheme (`:102`). Client libraries "load the same CA
  through their TLS options — most take the PEM path directly, and nats.py and nats.java take a TLS
  context you build with the CA loaded into it".
- `wss://` is the WebSocket equivalent (`:188`) — the only mention of the scheme in this chapter.
- mTLS is "symmetric, a certificate path and a key path alongside the CA" (`:198`).

### The auth-error abort, per client

`:206`, in one paragraph — the wiki's source for these rows on [[client-defaults]]:

| client | rule |
|---|---|
| nats.go | closes when **the same server** returns the same auth error twice in a row; `IgnoreAuthErrorAbort()` opts out |
| nats.js | aborts after two auth errors in a row unless `ignoreAuthErrorAbort` |
| nats.net | stops when the same auth error repeats twice, same-named opt-out |
| nats.java | closes when the same server returns the same auth error twice |
| nats.py | **no abort rule** — cycles until every server exceeds `max_reconnect_attempts` (60 by default) |
| nats.rs | **no abort rule** — cycles until `max_reconnects` runs out (unlimited by default) |

"In all four, the abort applies regardless of the retry budget: unlimited reconnects don't override
it."

- "You won't see the abort from the `nats` CLI, which sets `IgnoreAuthErrorAbort` and unlimited
  reconnects, so a CLI command keeps retrying where a library client closes" (`:208`). Measured: the
  CLI printed two lines in 45 s while the server rejected it eleven times
  ([[s-nats-server-client-faults-observed]] B2).
- The credential callback, per client (`:210`): nats.go `UserJWT(userCB, sigCB)` or `Nkey`; nats.js
  an authenticator function called with the nonce per attempt; nats.py `user_jwt_cb` and
  `signature_cb`; nats.java an `AuthHandler`; nats.rs `ConnectOptions::with_auth_callback`; nats.net
  `NatsAuthOpts.AuthCredCallback`.
- **Which clients re-read the file**: "nats.go, nats.java, nats.py" re-read on every attempt; "the
  load-once clients (nats.js, nats.rs, nats.net) need the callback form for a rotation to reach a
  reconnect at all" (`:210`, `:222`).

### Expiry, and rotation

- "The server arms a timer at the JWT's expiry time; when it fires, the server sends `-ERR 'User
  Authentication Expired'` and closes the connection. The client then tries to reconnect, and the
  server rejects each attempt with an authorization violation" (`:220`). Both strings confirmed on
  the wire; the second is right **from the second attempt on** — a reconnect inside the expiry
  second gets `User Authentication Expired` again
  ([[s-nats-server-client-faults-observed]] B3, B6). The page never mentions
  `-ERR 'Account Authentication Expired'`, which the same mechanism produces when the *account* JWT
  expires (B5) — docs issue #99.
- Rotation: "A live connection keeps the identity it authenticated with, so overwriting the `.creds`
  file on disk changes nothing on the wire while the link stays up" (`:222`). A reconnect mid-write
  "can read a half-written file… nats.go never sends a `CONNECT`, treats the attempt as a transient
  failure, and keeps retrying" — write to a temp path and rename. "To rotate safely, open a new
  connection with the new creds and drain the old one."
- The two failure kinds at connect are to be handled separately: CA validation vs authorization
  (`:224`). In nats.go the authorization side "arrives as one of `ErrAuthorization`,
  `ErrAuthExpired`, `ErrAuthRevoked`, `ErrPermissionViolation`, or `ErrMaxConnectionsExceeded`"
  (`:257–259`); nats.py "raises `AuthorizationError` only for an authorization violation and reports
  expired, revoked, and connection-limit errors as a generic error"; nats.rs "reports an
  authorization-violation kind and passes the rest through as server error strings" (`:261–269`).

## Practical takeaways

- The abort is about *repetition*, not about a count of failures; two different auth errors do not
  trip it.
- An expired credential is terminal in four of six clients — plan for the closed handler, not for a
  retry that eventually succeeds.
- Rotate by temp-file-and-rename, and prefer draining onto a fresh connection over swapping a file
  under a live one.
- `handshake_first` is a both-sides change unless you use its fallback form.

## Notable quotes

> "An unmonitored credential expiry drops a live connection." (`:220`)

> "the load-once clients (nats.js, nats.rs, nats.net) need the callback form for a rotation to reach
> a reconnect at all" (`:222`)

## Relevance to the wiki

The source of the auth-abort and credential-callback rows on [[client-defaults]], of
[[connection-closed-after-auth-error]], and of the client half of `handshake_first` on
[[tls-in-nats]].

## Questions it answers

181, 182; supports 175–179.

## Pages touched

[[connection-closed-after-auth-error]], [[client-defaults]], [[tls-in-nats]], [[operator-mode]],
[[rotate-tls-certificates]], [[set-up-operator-mode]], [[client-connection-lifecycle]],
[[websocket]], [[nats-cli]]
