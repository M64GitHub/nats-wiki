<!-- source: https://docs.nats.io/learn/security/operator-mode.md · fetched 2026-08-31 · section: operator-mode -->
# Operator mode

The config-mode world is complete. `ORDERS` and `ANALYTICS` live as account blocks in the server config, `order-svc` is scoped to `orders.>`, and one deliberate bridge carries `orders.shipped` from one account to the other. Every user, password, and permission in that world sits in a file the server reads.

**Operator mode** removes that file. An operator signs each account, an account signs its users, and the server, which trusts only the operator, verifies those signatures when a client connects. That's the whole idea for now; the next page walks through what each signature proves. This page builds the setup: an operator named `ACME`, the same two accounts, users `order-svc` and `analytics-reader`, and the credentials they connect with. No user lives in the server config.

## Why you use a tool

What happens if you try to build the chain by hand? You generate an operator NKey, then an account NKey, then sign the account JWT with the operator's private seed, then a user NKey, then sign the user JWT with the account's seed. Each step uses a different key, and each signature has to be exact or the whole chain breaks. Do it manually and one wrong seed produces a JWT the server silently rejects at connect time.

The **`nats auth`** commands, part of the same `nats` CLI you've used all chapter, do this for you. They generate the NKeys, build the JWTs, sign each one with the correct key in the chain, and store everything in a local directory tree under `$XDG_DATA_HOME/nats` — JWTs in a `stores` directory, private seeds in a `keys` directory. That store holds every private key in the trust chain, which is why you run the tool on a trusted machine and never on the server. It produces two kinds of output: account JWTs the server fetches, and credentials which clients connect with.

**Coming from nsc?** The `nats auth` store is nsc-compatible on disk: both tools read the same tree, so you can point `nsc` at it and keep working. The commands you run day to day map roughly one to one between the two tools. A few `nsc` capabilities aren't in `nats auth` v0.4.0 yet — activation tokens and importing a single account into an existing operator among them. For those, keep using `nsc` on the same store.

## Building the chain

One sequence creates the whole chain:

#### CLI

```
#!/bin/sh

# Build the ACME trust chain: operator -> accounts -> users -> creds.

# Run once on a trusted machine. nats auth generates the nkeys and

# signs every JWT with the correct key in the chain.



# Create the operator ACME. A SYSTEM account and one operator signing

# key are created automatically; the resolver needs SYSTEM later.

nats auth operator add ACME

# Operator ACME (OBZITYNM2EAIJ4G5PZTH3XIRUIEIZH63YSFO2JKPNGWVFBGKBPEJP5WS)

#   System Account: SYSTEM (ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46)



# Create the two tenant accounts, each signed by ACME.

# --defaults skips the interactive limit prompts.

nats auth account add ORDERS --defaults

# Account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU)

nats auth account add ANALYTICS --defaults

# Account ANALYTICS (AALQ2LGPK55V7AOZWO6ODKFFX7HI6QHJ2MNYKZ6FFNAVZJB2J2WB4UFD)



# Create one user per account and write its creds file in the same step.

nats auth user add order-svc ORDERS --defaults --credential order-svc.creds

# User order-svc (UAKAFPCC4KDEKCAKP47VXHEYGHSL4GDET65EE7LMHMD2PCRAAWP37U2B)

nats auth user add analytics-reader ANALYTICS --defaults --credential analytics-reader.creds



# Inspect what was built. The issuer is the operator key that signed it.

nats auth account info ORDERS
```

```
Operator ACME (OBZITYNM2EAIJ4G5PZTH3XIRUIEIZH63YSFO2JKPNGWVFBGKBPEJP5WS)

  System Account: SYSTEM (ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46)

    Signing Keys: OABMS7LJRLJ7RX3SMV7AK3MRTJHYFN4EY5ARSMR5SKZBTOWAKPCTKVO3



Account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU)

                 Issuer: OBZITYNM2EAIJ4G5PZTH3XIRUIEIZH63YSFO2JKPNGWVFBGKBPEJP5WS



User order-svc (UAKAFPCC4KDEKCAKP47VXHEYGHSL4GDET65EE7LMHMD2PCRAAWP37U2B)

        Max Payload: 1,048,576
```

`nats auth operator add ACME` creates the root of trust. It never prompts, and it always creates two extras: a `SYSTEM` account and one operator signing key. `SYSTEM` plays the role the hand-made `SYS` account played in config mode, under a name the tooling fixes. The server uses the `SYSTEM` account to answer its own internal JWT-lookup requests, and the resolver needs it later.

The two `account add` lines create `ORDERS` and `ANALYTICS`, each signed by `ACME`. These are the same two tenants from the [Accounts and multitenancy](/learn/security/accounts-and-multitenancy.md) page, now living as signed JWTs instead of config blocks. The `Issuer` in the output is the operator key that signed the account: the link in the chain the server will verify. `--defaults` skips the interactive prompts for connection and subscription limits.

The two `user add` lines create one user per account and, through `--credential`, write each user's credentials file in the same step. The output's `Max Payload: 1,048,576` line shows that `--defaults` bakes a 1 MiB payload limit into each user JWT. What it doesn't bake in is permissions: both users can publish and subscribe anywhere in their own account for now. Permissions arrive on the next page through scoped signing keys.

Notice that the long IDs for each Operator, Account, or User, each starts with `O`, `A`, or `U`, respectively. This is a guarantee and is designed to allow a human to immediately tell what they're looking at. If you ever see an ID which starts with an `S` (`SO`, `SA`, `SU`) then *be very careful* because you're looking at the NKey Seed (roughly the private key).

## The credentials the client presents

A user JWT alone can't connect. The JWT is a public claim; to prove it owns that identity, the client also needs the user's private NKey seed to sign the server's challenge. That's why `--credential` packaged both into a single file.

(There's an exception to this, Bearer JWTs, which you have to explicitly opt into. You should avoid them unless you need them for WebSockets connections.)

Open `order-svc.creds` and you see two labeled sections:

```
-----BEGIN NATS USER JWT-----

eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiJDSzNRR1M3...

------END NATS USER JWT------



-----BEGIN USER NKEY SEED-----

SUAHXZJM6LTGNPTO34IWIJYDYT2PLJGEYRMASUR4E33NR4RNKZY3KZ3RGU

------END USER NKEY SEED------
```

The first section is the public claim the server reads. The second is the private half the client signs with; it never leaves the client. So a credentials file is a secret: treat it like a password, readable by the one client that uses it and nothing more. If you ever need a fresh copy, `nats auth user credential order-svc.creds order-svc ORDERS` writes one from the store.

## Why the server needs a resolver

The server now trusts `ACME`. When `order-svc` connects, the client library signs the server's presented nonce with the private key, and presents both the signature and the user JWT to the server as part of the authentication step. The server parses that user JWT, sees it was signed by a key for the `ORDERS` account, and tries to verify that `ORDERS` was in turn signed by the operator. It has never seen the `ORDERS` JWT, so it can't finish the chain and the connection fails.

The **account resolver** closes that gap. It's the part of the server config that tells `nats-server` where to find account JWTs at connect time. The recommended type is the full nats-based resolver: the server keeps every account JWT in a local directory, and you deliver new ones over a NATS connection. Memory, cache, and URL resolvers also exist (see [Reference](/reference/config/resolver/.md)), but `nats auth` can only push to a full resolver.

`nats server generate ./acme-server` scaffolds the config. The command is interactive: pick the template `'nats auth' managed NATS Server configuration` and answer the prompts. It writes `./acme-server/server.conf`:

```
# Generated NATS Server configuration operated by operator ACME

server_name: acme-1

listen: 0.0.0.0:4222

monitor_port: 8222



# The JWT token of the operator running the server (ACME)

operator: eyJ0eXAiOiJKV1QiLCJhbGciOiJ...



# The JWT token of the system account managing the server (ACME)

system_account: ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46



resolver_preload {

    // Account: SYSTEM

    ADAHVYCRL72B3US4VANPUIQXCNHFCQWFOCPOG7YDPPX36Z3DCJTHZP46: eyJ0eXAiOiJKV1QiLCJhbGciOiJ...

}



# Configures the Full NATS Resolver

resolver {

   type: full

   dir: /var/lib/nats/resolver

   allow_delete: true

   interval: "2m"

   limit: 1000

}
```

`operator` is the full operator JWT, not a bare key: the one thing the server trusts and the anchor of the whole chain. `system_account` names the account `operator add` created. The `resolver_preload` block bakes the `SYSTEM` account JWT directly into the config; that's what lets a system user connect before you've pushed anything. `resolver.dir` is where account JWT files land, one per account.

Start the server with it and the boot log shows the trust anchor:

```
nats-server -c ./acme-server/server.conf
```

```
[INF] Trusted Operators

[INF]   System  : ""

[INF]   Operator: "ACME"

[INF]   Issued  : 2026-07-03 14:18:32 +0200 CEST

[INF]   Expires : Never

[INF] Server is ready
```

## Filling the resolver

The resolver directory is still empty, so the chain can't complete yet. Try to connect and the server rejects it:

```
nats pub orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' --creds order-svc.creds
```

```
nats: error: nats: Authorization Violation
```

Push the account JWTs to the running server:

#### CLI

```
#!/bin/sh

# Start the server with the generated resolver config, then push the

# ACME accounts so it can validate users in ORDERS and ANALYTICS.



# nats server generate is interactive: pick the template

# "'nats auth' managed NATS Server configuration" and answer the

# prompts. It writes ./acme-server/server.conf.

nats server generate ./acme-server



# Start the server. Its resolver directory begins empty.

# Leave it running; the commands below go in a second terminal.

nats-server -c ./acme-server/server.conf



# Create a SYSTEM user. Its creds are what authorizes a push.

nats auth user add admin SYSTEM --defaults --credential sys.creds



# Push each account JWT to the running server. Push is per account.

nats auth account push ORDERS -s nats://127.0.0.1:4222 --creds sys.creds

# Updating account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU) on 1 server(s)

# ✓ Update completed on acme-1

# Success 1 Failed 0 Expected 1

nats auth account push ANALYTICS -s nats://127.0.0.1:4222 --creds sys.creds

# Success 1 Failed 0 Expected 1
```

```
Updating account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU) on 1 server(s)



✓ Update completed on acme-1



Success 1 Failed 0 Expected 1
```

The `admin` user lives in `SYSTEM`, the one account the config already preloads, so its creds can connect and authorize the push. Each `account push` sends one account JWT to the server, which writes it into the resolver directory; `Success 1 Failed 0 Expected 1` means your single server confirmed the update. Push is per account: run it once for `ORDERS` and once for `ANALYTICS`. You can read an account back from the server with `nats auth account query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds`, which pulls the copy the resolver holds.

The user JWTs weren't pushed. User definitions do not live in the server. A client presents its own user JWT at connect time, inside the credentials file; the server will remember the JWT details for the life of the connection.

## Connecting with the credentials

The server trusts `ACME` and holds the account JWTs, and `order-svc` has its credentials, so it can now publish an order.

#### CLI

```
#!/bin/sh

# Publish an order as order-svc using the generated creds file.

# The creds file is the identity: no --user or --password is needed.

# The client presents the user JWT and signs the server's challenge with the nkey seed.

nats pub --creds order-svc.creds orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

```
14:19:47 Published 91 bytes to "orders.created"
```

The client reads the credentials file, presents the user JWT, and signs the server's challenge with the NKey seed. The server verifies the JWT was signed by `ORDERS`, that `ORDERS` was signed by `ACME`, and that the challenge signature matches the JWT's public key. The whole chain checks out, and the 91-byte order lands on `orders.created`.

**Message flow — Push an account, then connect (animated):** Operator mode in two beats. First, nats auth account push sends the ORDERS account JWT — signed by operator ACME — to the server over the SYSTEM account, and acme-1 stores it in its resolver directory next to the preloaded SYSTEM JWT. Then order-svc connects with a creds file: it presents its user JWT and signs the server's challenge, the server verifies the user JWT against the stored ORDERS JWT and ORDERS against the one trusted operator key, and the client is admitted. Account JWTs live on the server; user JWTs never do.

* workstation → acme-1 (subject: account push — ORDERS JWT (signed by ACME), over SYSTEM)
* workstation → acme-1
* order-svc → acme-1 (subject: user JWT + signed challenge)
* acme-1 → order-svc (subject: admitted → ORDERS)
* order-svc → acme-1

Step through the two beats: the push stores the `ORDERS` account JWT in the server's resolver directory, and the connect verifies the user's chain against it.

No `--user` or `--password` appears anywhere; the credentials file carries the identity. That's the shift from config mode: the server holds one trusted key, not a list of users. The `orders.shipped` bridge carries over in concept too — in operator mode, exports and imports move into the account JWTs, as the [Cross-account](/learn/security/cross-account.md) page noted.

## Pitfalls

Most operator-mode failures come from the `nats auth` store on your workstation and the server's resolver drifting apart, or from a `.creds` file ending up where it shouldn't.

**Editing an account without pushing it.** `nats auth account edit` changes only the local JWT in your store. The running server keeps validating against the copy it holds, so the edit silently has no effect: existing credentials keep connecting, and the old limits stay in force. Push after every account change, and confirm with `nats auth account query`, which shows what the server actually holds.

#### CLI

```
#!/bin/sh

# An edit only changes the local JWT in the nats auth store. The server

# keeps validating against its stored copy, so until you push, the edit

# silently has no effect: existing creds still connect, old limits hold.



# Edit the ORDERS account locally (here: a connection-count limit).

nats auth account edit ORDERS --connections 50



# No push yet: the server still enforces the previous, unlimited value.

# Nothing errors -- the change just hasn't happened on the server.



# Deliver the updated JWT to the running server.

nats auth account push ORDERS -s nats://127.0.0.1:4222 --creds sys.creds

# Success 1 Failed 0 Expected 1



# Confirm the server's copy matches: it now shows Connections: 50.

nats auth account query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
```

```
Updating account ORDERS (AC6S25M37MU5PJGKYF5QPJPJ6XDQZXJPIPTMCR5MK7ZALYQGX6MH4IRU) on 1 server(s)



✓ Update completed on acme-1



Success 1 Failed 0 Expected 1
```

After the push, `account query ORDERS` reports `Connections: 50`; before it, the same query still showed `unlimited`.

**System account missing under a nats-based resolver.** The server uses the system account to answer its own JWT-lookup requests, so the nats-based resolver refuses to start without one: if neither the config nor the operator JWT names a system account, `nats-server` exits at boot with `using nats based account resolver - the system account needs to be specified in configuration or the operator jwt`. With this chapter's setup you won't hit it — `nats auth operator add` embeds the `SYSTEM` account in the operator JWT, and `nats server generate` writes the `system_account` line as well. It bites when the operator JWT was built by hand or imported from a tool that didn't set a system account.

**Leaking the `.creds` file.** The credentials file carries the user's private NKey seed, so anyone holding it can connect as `order-svc`. There's no password to guess and no list to revoke against. Never bake it into an image, log it, or commit it; give it `0600` permissions and mount it to the one client that needs it. To cut off a leaked credential, revoke the user and re-push the account; the next page, [Decentralized authentication](/learn/security/decentralized-auth.md), shows the command and why the revocation sticks.

**Credential expiration.** User credentials can have an expiration time associated with them. This has operational benefits paired with operational costs. You can reduce the impact of credential compromise without needing a signing key rotation; but now you potentially have a set of objects to monitor for expiration.

## Where you are

You've rebuilt the config-mode world without a user list:

* An operator `ACME` is the root of trust; its store lives on your machine, not on the server.
* Accounts `ORDERS` and `ANALYTICS` are signed by `ACME` and pushed to the server's full resolver.
* Users `order-svc` and `analytics-reader` connect with credentials files. Neither carries permissions yet.
* The server config holds the operator JWT, the system account, and a resolver — no user list.

Both setups reach the same place: `order-svc` connects and publishes orders. The difference is how the server decides to trust it.

## What's next

You've run the commands; the next page explains what the server verified when `order-svc` connected, and adds what makes this mode workable day to day: scoped permissions, revocation, and expiry.

Continue to [Decentralized authentication](/learn/security/decentralized-auth.md).

## See also

* [Reference → resolver](/reference/config/resolver/.md) — all resolver types and their options
* [Reference → operator](/reference/config/operator.md) — the field holding the operator JWT the server trusts
* [Decentralized authentication](/learn/security/decentralized-auth.md) — what the signatures in this chain prove
* [Core Concepts → Security](/concepts/security.md) — the five-minute overview of accounts, users, and JWTs
