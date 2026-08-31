---
title: "docs.nats.io — Authentication basics"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/authentication-basics.md
source-path: raw/nats-docs/learn/security/authentication-basics.md
author: NATS documentation (Synadia Communications, Inc.)
article: Authentication basics
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [authorization, users, password, bcrypt, nkey, token, no_auth_user, context]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Authentication basics

Config-mode authentication: the whole user list lives in `nats.conf` and the server never asks
anyone else. The first page of the docs' security chapter, and the baseline every later page
replaces.

## Key claims

**The user list is the `users` array of the top-level `authorization` block.** Both users below
land in the global account `$G`:

```
authorization {
  users: [
    { user: order-svc, password: s3cr3t }
    { user: analytics-reader, password: an4lytics }
  ]
}
```

"For a server with exactly one user, you can skip the array and put a single `user` and `password`
pair directly in the `authorization` block."

**Three credential styles, one model.** Only the field changes:

| style | config | what crosses the wire |
|---|---|---|
| user/password | `{ user: order-svc, password: s3cr3t }` | the password, in the clear |
| **NKey** | `{ nkey: UAPZQH4M… }` — the **public** key only | a signature over a server nonce; "nothing secret crosses the wire" |
| **token** | `authorization { token: "shared-secret-rotate-me" }` | the token; server-wide, "the one style that can't be per-user" |

The server "rejects an entry that mixes" an nkey with a user/password pair. When the chapter says
"token" it "always means this, never a JWT".

**`authorization { timeout }` is documented here as "how long the server gives a client to finish
authenticating, 2 seconds by default".** The page adds a parsing trap: "Plain numbers are seconds;
duration strings need quotes (`timeout: "500ms"` — an unquoted `1m` parses as a number, not a
minute)." *(The 2-second figure is only correct when TLS is off — see docs issue #19.)*

**Every authentication failure is the same error.** A wrong password, an unknown user and an
unauthenticated connect all produce:

```
nats: error: nats: Authorization Violation
```

"The server gives the same answer for a wrong password and an unknown user, so a failed login
doesn't reveal which half was wrong."

**Credentials are offered once per connection, and re-offered on every reconnect:** "The
authentication happens again, midway through a session, to authenticate this new connection."

**Plaintext passwords are flagged by the server itself** at startup:

```
[WRN] Plaintext passwords detected, use nkeys or bcrypt
```

The fix is a bcrypt hash from `nats server passwd`:

```
 nats server passwd --pass "s3cr3t-rotate-me-later"
```

```
$2a$11$4I9tIK1JVbttZYtn.F.Jse5iY5ves4EtYWIpjlwyvgVYHJc8yTvk.
```

Facts stated about the command and the stored value:

- without `--pass` it prompts; `--generate` invents and hashes a passphrase; `--cost` raises the
  cost above **the default 11**;
- it "refuses passwords shorter than 10 characters (`password should be at least 10 characters
  long`)";
- the prefix `$2a$11$` is "Go's bcrypt prefix at cost 11";
- "a trailing full stop, if present, is part of the value";
- the server "reserves the right to use any string starting `$` as a hash indicator, so don't use
  plaintext starting with a dollar sign";
- **the client still sends the plaintext** — "bcrypt protects only the config file at rest".
- Tokens hash the same way.

**NKey generation and display:**

```
nats auth nkey gen user --output user.nk
nats auth nkey show user.nk
```

`gen` "writes the private seed to `user.nk` and prints nothing"; `show` prints the public key the
config entry holds. Connect with `nats pub … --nkey user.nk`.

**A CLI trap:** "the `--user` flag doubles as a token field — its help text reads 'Username or
Token'. A lone `--user` with no `--password` is sent as a token, so it can appear to work against a
token-configured server and mask a misconfiguration."

## Practical takeaways

- **A server with no `authorization` block admits everyone.** The page's first pitfall: "on a shared
  network anyone who can reach the port can publish and subscribe, so don't ship it."
- **`no_auth_user` undoes the lockdown** even when a user list exists — "Set it only on purpose."
- **Keep the credential out of the URL.** `nats://order-svc:s3cr3t@localhost:4222` "puts the
  credential into shell history, process listings, and any log that records the connection string."
  Use a named context instead:

  ```
  nats context add orders --server localhost:4222 --user order-svc --password "$NATS_PASSWORD" \
    --description "ORDERS platform, order-svc user"
  nats context select orders
  ```

  If `NATS_PASSWORD` stays exported the CLI prints
  `WARNING: Shell environment overrides in place using NATS_PASSWORD`.
- **A committed config is a leaked credential**, hash or not: "Once it lands in history, rotating
  the password is the only real fix, because the old value lives in every clone."
- `include` splits the user list across files but "treat it only as buying time before you move away
  from centralized configuration".

## Notable quotes

> "Centralized authentication is the right tool when one team owns the server config and the user
> list is small and slow to change."

> "A client certificate can also be a credential: the server can map a certificate identity straight
> to a user with mTLS, so the cert *is* the credential."

## Relevance to the wiki

The floor of the whole security area: the smallest configuration that stops an open server, the
three credential styles every later model reuses, and the one error string that covers every
authentication failure. Feeds [[subject-permissions]] (which adds the *what*), [[account]] (which
adds the *where*) and [[tls-in-nats]] (which encrypts the wire the password crosses).

## Questions it answers

Q56 (partly — the `$G` half is in [[unauthenticated-clients-still-connect]]).

## Pages touched

[[subject-permissions]] · [[account]] · [[tls-in-nats]] · [[operator-mode]] · [[auth-callout]] ·
[[nats-cli]] · [[config-keys]] · [[defaults-and-limits]]
