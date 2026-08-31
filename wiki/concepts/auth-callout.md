---
title: Auth callout
type: concept
area: [security]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [auth_callout, issuer, auth_users, xkey, allowed_accounts, ADR-26, "$SYS.REQ.USER.AUTH", oidc, ldap]
aliases: [auth callout, authorization callout, external auth, "$SYS.REQ.USER.AUTH", auth_callout]
sources: [s-docs-auth-callout, s-gh-7505-auth-callout-nkey, s-nats-server-auth-and-tls]
created: 2026-08-31
updated: 2026-08-31
---

# Auth callout

**The server delegates the authentication decision to a NATS service you run.** On each connection it
publishes a signed request to **`$SYS.REQ.USER.AUTH`** and waits for a signed reply naming a user and
an account; the client sees an ordinary connection (source: [[s-docs-auth-callout]]).

Reach for it when the identity lives somewhere NATS cannot read — an OIDC provider, an LDAP
directory, a service that mints its own tokens. If your users fit a config list use
[[subject-permissions]] and a user block; if they fit a trust chain you control, use
[[operator-mode]].

**Since nats-server 2.10.0.** "It's also disabled in FIPS-140 mode and can't be configured there."

## How it behaves

**Authentication becomes request/reply over NATS itself.** The server builds a request describing the
attempt, publishes it, and blocks until the reply arrives or the deadline passes. "The client has no
indication that a callout happened."

**The moment `auth_callout` is on, every connection goes through it** — including config users with
correct passwords — except the users named in `auth_users`. `allowed_accounts` (**2.11+**) narrows
that: users of accounts not on the list authenticate the ordinary way, "so `allowed_accounts` lets you
move one account at a time". One exception: "a connection that matches no config user lands in the
global account `$G`, and those connections always go through the callout, whatever the list says."

**What the server signs and pins.** Each request is a JWT signed by an NKey "it generated fresh at
startup", with the server's ID as issuer and the fixed audience `nats-authorization-request`. Each
request also carries a **one-time `user_nkey`**: "The reply is only valid if it names that exact NKey
as its subject", so a captured reply cannot be replayed onto a later connection.

**What the service signs.** The response is two JWTs, one inside the other. The outer verdict's
subject is the `user_nkey` and its audience is "the ID of the server that asked, so a verdict produced
for one server is useless at another". The inner user JWT's audience is the **target account name**,
"and that audience is what places the client in `ORDERS`". Both must be signed by the `issuer` account
key from the config; in config mode "the server rejects a user JWT that names an `issuer_account`".

**What the server does *not* check: anything the client presented.** `fillConnectOpts` copies the
client's JWT, NKey, signature, token, username and password into the request verbatim, with no
verification (`auth_callout.go:490`, source: [[s-nats-server-auth-and-tls]]). A maintainer put it
plainly: "callout doesn't do any kind of challenge response, you evaluate on what you got from the
client, if you don't like it you reject" (source: [[s-gh-7505-auth-callout-nkey]]).

The server does hand over the material to do the check yourself: when the client supplied a signature,
it fills `client_info.nonce` with the nonce it issued —

```go
if claim.ConnectOptions.SignedNonce != _EMPTY_ {
	claim.ClientInformation.Nonce = string(c.nonce)
}
```

— so a service can verify `signed_nonce` over `nonce` against `nkey` and recover the proof of
possession the server skipped.

## What configures it

```
accounts {
    ORDERS: {}
    ANALYTICS: {}
}

authorization {
    timeout: "1s"
    users: [ { user: auth-svc, password: c4llout } ]

    auth_callout {
        issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"
        auth_users: [ auth-svc ]
        account: AUTH
        xkey: "XA…"
        allowed_accounts: [ ORDERS ]
    }
}
```

The block is exactly five fields (`opts.go:394–407`):

| field | what it does |
|---|---|
| `issuer` | the **public account NKey** allowed to sign the response; the server admits a client only if the reply carries this signature. `nats auth nkey gen account --output issuer.nk`, then `nats auth nkey show issuer.nk` |
| `auth_users` | the users that **skip** the callout. Exactly one job: letting the auth service connect so it can receive requests |
| `account` | where the service runs and where `$SYS.REQ.USER.AUTH` is protected. Defaults to `$G` |
| `xkey` | an x25519 public key; the request and response are sealed with it (header `Nats-Server-Xkey`) |
| `allowed_accounts` | 2.11+; "If empty then all accounts will be delegated" |

**The account a client is placed into must already exist in the config.**

**The deadline is `authorization { timeout }`** — the same key that bounds ordinary authentication,
used both as the request claim's expiry and as the reply wait (`auth_callout.go:371`, `:447`). Its
default is **2s without TLS and `tls_timeout + 1` — 3s at stock settings — with TLS configured**; the
docs state a flat 2s (see [[defaults-and-limits]] and docs issue #19).

**In operator mode** the callout is configured on the account's JWT instead, "and the account declares
which other accounts `auth-svc` may bind clients to".

## Limits and failure modes

- **The service is on the connection path.** If it is down, slow or crashed, "the server gets no
  reply, waits out the `timeout` … and rejects the client" — every new connection pays the full
  timeout and then fails. Run more than one instance and keep its directory lookups fast.
- **What the client prints depends on which deadline fires first.** With the callout timeout below the
  client's connect deadline the client sees `Authorization Violation`; with both near 2s it usually
  sees `read tcp ...: i/o timeout`. "In both cases the reason lives only in the server log":
  `[ERR] ... authentication error - Token "[REDACTED]"`.
- **Credentials cross `$SYS.REQ.USER.AUTH` in the clear.** The request is a JWT, and "base64 is
  encoding, not encryption" — `connect_opts.auth_token` (or a password, or a seed) decodes in one
  line. The server redacts `client_info.user` and nothing else. Two mitigations, and you want both:
  run the service in a **dedicated account** so nothing else can subscribe, and set `xkey` so even a
  leaked subscription reads nothing.
- **The server's automatic deny stops forgery, not eavesdropping.** On the callout account,
  publishing to `$SYS.REQ.USER.AUTH` is denied for every user, the auth service included — so no
  ordinary user can inject a request or a verdict. Reading is a different matter.
- **`auth_users` is not a convenience allow-list.** Every user on it "connects with no external
  check". Adding an application user there silently exempts it from authentication entirely.
- **Rejection style is a security choice.** Replying with an error rejects at once; dropping the
  request makes the client wait out the timeout, and "the callout libraries recommend dropping for bad
  credentials, because the added delay slows down brute-force guessing".
- **Do not roll your own handler.** `synadia-io/callout.go` is named by a maintainer as hardened:
  "there are many checks that you should implement on your callout".

## Why an operator cares

Auth callout moves the availability of authentication out of the server and into a service you
operate. That is the whole trade: you get an identity system NATS could never reach, and you take on
a component whose outage means no new connections anywhere on the server.

The security failure to watch for is not the protocol — the replay and forgery paths are closed — but
the handler trusting `connect_opts`. A service that reads `connect_opts.nkey` as an identity is
spoofable, and the spoof succeeds silently with the wrong permissions attached.

## Related

[[account]] · [[subject-permissions]] · [[operator-mode]] · [[tls-in-nats]] · [[js-api-subjects]] ·
[[defaults-and-limits]] · [[config-keys]] · [[nats-server-2.11]] · [[leafnode]]

## Sources

[[s-docs-auth-callout]] · [[s-gh-7505-auth-callout-nkey]] · [[s-nats-server-auth-and-tls]] ·
[[s-docs-security-checklist]]
