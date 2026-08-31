---
title: "docs.nats.io — Operator mode"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/operator-mode.md
source-path: raw/nats-docs/learn/security/operator-mode.md
author: NATS documentation (Synadia Communications, Inc.)
article: Operator mode
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [operator, jwt, nkeys, resolver, resolver_preload, account-push, creds, nats-auth, nsc]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Operator mode

The build: an operator, two accounts, two users and a resolver, with **no user list on the server**.
The commands are `nats auth`; the page that explains what they prove is
[[s-docs-decentralized-auth]].

## Key claims

**The whole chain in six commands**, run "on a trusted machine":

```
nats auth operator add ACME
nats auth account add ORDERS --defaults
nats auth account add ANALYTICS --defaults
nats auth user add order-svc ORDERS --defaults --credential order-svc.creds
nats auth user add analytics-reader ANALYTICS --defaults --credential analytics-reader.creds
nats auth account info ORDERS
```

- `operator add` "never prompts, and it always creates two extras: a `SYSTEM` account and one
  operator signing key." The server "uses the `SYSTEM` account to answer its own internal JWT-lookup
  requests, and the resolver needs it later."
- `--defaults` "skips the interactive prompts for connection and subscription limits" and "bakes a
  1 MiB payload limit into each user JWT" (`Max Payload: 1,048,576`).
- Users get **no permissions** from `user add`: "both users can publish and subscribe anywhere in
  their own account for now."

**The store is on your workstation, not the server:** `$XDG_DATA_HOME/nats` — "JWTs in a `stores`
directory, private seeds in a `keys` directory. That store holds every private key in the trust
chain, which is why you run the tool on a trusted machine and never on the server."

**`nats auth` and `nsc` share the store on disk.** "Both tools read the same tree, so you can point
`nsc` at it and keep working." Missing from `nats auth` **v0.4.0**: "activation tokens and importing
a single account into an existing operator among them. For those, keep using `nsc` on the same
store."

**The prefix letter names the role.** `O` operator, `A` account, `U` user — "This is a guarantee and
is designed to allow a human to immediately tell what they're looking at. If you ever see an ID
which starts with an `S` (`SO`, `SA`, `SU`) then *be very careful* because you're looking at the
NKey Seed."

**A creds file is two blocks and is a secret:**

```
-----BEGIN NATS USER JWT-----
eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.…
------END NATS USER JWT------

-----BEGIN USER NKEY SEED-----
SUAHXZJM6LTGNPTO34IWIJYDYT2PLJGEYRMASUR4E33NR4RNKZY3KZ3RGU
------END USER NKEY SEED------
```

"The first section is the public claim the server reads. The second is the private half the client
signs with; it never leaves the client." Re-issue a copy with
`nats auth user credential order-svc.creds order-svc ORDERS`.

**The resolver is what the server needs and the user JWT is not.** Without it the server "has never
seen the `ORDERS` JWT, so it can't finish the chain and the connection fails" with
`nats: error: nats: Authorization Violation`.

`nats server generate ./acme-server` is interactive — pick the template
`'nats auth' managed NATS Server configuration`. It writes:

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

- `operator` is "the full operator JWT, not a bare key: the one thing the server trusts".
- `resolver_preload` "bakes the `SYSTEM` account JWT directly into the config; that's what lets a
  system user connect before you've pushed anything."
- `resolver.dir` is "where account JWT files land, one per account."
- **The recommended type is `full`** — "Memory, cache, and URL resolvers also exist… but `nats auth`
  can only push to a full resolver."

**Boot log confirms the anchor:**

```
[INF] Trusted Operators
[INF]   System  : ""
[INF]   Operator: "ACME"
[INF]   Issued  : 2026-07-03 14:18:32 +0200 CEST
[INF]   Expires : Never
[INF] Server is ready
```

**Filling the resolver is one push per account**, authorized by a `SYSTEM` user:

```
nats auth user add admin SYSTEM --defaults --credential sys.creds
nats auth account push ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
```

```
Updating account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU) on 1 server(s)
✓ Update completed on acme-1
Success 1 Failed 0 Expected 1
```

Read back what the server holds with
`nats auth account query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds`.

**User JWTs are never pushed.** "User definitions do not live in the server. A client presents its
own user JWT at connect time, inside the credentials file; the server will remember the JWT details
for the life of the connection."

## Practical takeaways

- **`nats auth account edit` changes nothing until you push.** "The running server keeps validating
  against the copy it holds, so the edit silently has no effect: existing credentials keep
  connecting, and the old limits stay in force." Confirm with `account query`, which "shows what the
  server actually holds" — `Connections: 50` after the push, `unlimited` before it.
- **A nats-based resolver refuses to boot with no system account:**

  ```
  using nats based account resolver - the system account needs to be specified in configuration or the operator jwt
  ```

  "It bites when the operator JWT was built by hand or imported from a tool that didn't set a system
  account."
- **A leaked `.creds` is a full identity.** "There's no password to guess and no list to revoke
  against… give it `0600` permissions and mount it to the one client that needs it."
- **Credential expiry cuts both ways:** "You can reduce the impact of credential compromise without
  needing a signing key rotation; but now you potentially have a set of objects to monitor for
  expiration."
- **Bearer JWTs are the exception to needing a seed** — "You should avoid them unless you need them
  for WebSockets connections."

## Notable quotes

> "Do it manually and one wrong seed produces a JWT the server silently rejects at connect time."

> "That's the shift from config mode: the server holds one trusted key, not a list of users."

## Relevance to the wiki

The build half of Q49 and the source for [[set-up-operator-mode]]. Every command here was quoted
into that runbook; the failure modes came from [[s-gh-7854-jwt-push-timeout]], which shows what the
same procedure looks like when it does not work.

## Questions it answers

Q49 (with [[s-docs-decentralized-auth]] and [[s-gh-7854-jwt-push-timeout]]).

## Pages touched

[[set-up-operator-mode]] · [[operator-mode]] · [[account]] · [[nsc]] · [[nk]] · [[nats-cli]] ·
[[config-keys]] · [[backup-and-restore-identity]]
