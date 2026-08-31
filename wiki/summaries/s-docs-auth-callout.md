---
title: "docs.nats.io — Auth callout"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/auth-callout.md
source-path: raw/nats-docs/learn/security/auth-callout.md
author: NATS documentation (Synadia Communications, Inc.)
article: Auth callout
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [auth_callout, issuer, auth_users, xkey, allowed_accounts, ADR-26, "$SYS.REQ.USER.AUTH"]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Auth callout

Authentication delegated to a NATS service you run. The protocol is fixed by ADR-26; what the
service decides is yours.

## Key claims

**One well-known subject.** "The server publishes the connection request there, and `auth-svc`
subscribes there, so authentication becomes a request/reply exchange over NATS itself":
**`$SYS.REQ.USER.AUTH`**.

**Requires nats-server 2.10.0 or later.** "It's also disabled in FIPS-140 mode and can't be
configured there."

**The config lives in the `authorization` block:**

```
accounts {
    ORDERS: {}
    ANALYTICS: {}
}

authorization {
    users: [ { user: auth-svc, password: c4llout } ]

    auth_callout {
        issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"
        auth_users: [ auth-svc ]
    }
}
```

- **`issuer`** — "the public account NKey allowed to sign the response. The server admits a client
  only if the reply was signed by this key." Generate it with
  `nats auth nkey gen account --output issuer.nk`; `nats auth nkey show issuer.nk` prints the public
  half.
- **`auth_users`** — "the users that skip the callout… Without that exemption, the service that
  answers callouts could never connect to receive them."
- **`account`** — "names which account `auth-svc` runs in and where `$SYS.REQ.USER.AUTH` is
  protected", defaulting to `$G`.
- **The account a client is placed into must already exist in the config.**

**The client learns nothing.** A good token publishes normally; a wrong one gets
`nats: error: nats: Authorization Violation`. "Why the token was rejected appears only in the server
log."

**Everything the client presented crosses the subject in the clear.** The request is a JWT, and
"base64 is encoding, not encryption": decoding the claims yields

```json
{
  "aud": "nats-authorization-request",
  "iss": "NAFYFDR6WSIIQ5ABEJQWTZ6MGWSHSSATKRMR3STTBJ52MHJQA5YIHA3R",
  "nats": {
    "user_nkey": "UA423HWLLH3GJC662GWLEBBGKTZXIM6TNZIXQKPCDPFIL3II5FNDRDLC",
    "client_info": { "user": "[REDACTED]" },
    "connect_opts": { "auth_token": "test-cred-xyz" },
    "type": "authorization_request"
  }
}
```

"The server redacts `client_info.user`, but the raw token the client presented rides along readable,
and a password or NKey seed would sit here the same way."

**The server denies publishing to that subject automatically.** "On the account where auth callout
runs, publishing to `$SYS.REQ.USER.AUTH` is denied for every user — including `auth-svc` itself,
which only needs to subscribe and reply." That "stops forgery, not eavesdropping", which is why
ADR-26 recommends a dedicated account: "With nothing else in that account, no other user can
subscribe to the request traffic."

**The signing rules:**

- The server signs each request with "an NKey it generated fresh at startup, carrying the server's
  own ID as issuer and the fixed string `nats-authorization-request` as audience." The service
  cannot pre-trust that key — "What actually stops another client from provoking a verdict is the
  publish deny."
- Each request pins a **one-time `user_nkey`**: "The reply is only valid if it names that exact NKey
  as its subject. A captured old reply can't be replayed against a new connection."
- **The response is two JWTs, one inside the other.** The outer verdict's subject is the
  `user_nkey`, its audience "is the ID of the server that asked, so a verdict produced for one server
  is useless at another". The inner user JWT's audience "is the name of the target account… and that
  audience is what places the client in `ORDERS`". Both "must be signed by the `issuer` account key
  from the config; in config mode the server rejects a user JWT that names an `issuer_account`."

**The placement shows in the log** — the client that connected with only a token is recorded as a
real user in a real account:

```
[ERR] 127.0.0.1:57852 - cid:12 - "v1.51.0:go:NATS CLI Version v0.4.0" - "ORDERS/user:order-svc" - Publish Violation - Subject "billing.charge"
```

**Two rejection shapes.** Reply with an error and the client gets `Authorization Violation` at once,
the text going to the log only:

```
[WRN] Auth callout service returned an error: token did not match any known service
```

Or drop the request: "the client waits out the callout timeout and typically reports
`read tcp ...: i/o timeout`. The callout libraries recommend dropping for bad credentials, because
the added delay slows down brute-force guessing."

**Named and left out:** `xkey` (x25519 encryption of request and response), and **`allowed_accounts`
(2.11+)** — "limits the delegation to the config-defined accounts you list… One exception: a
connection that matches no config user lands in the global account `$G`, and those connections always
go through the callout, whatever the list says." Crucially: "The moment `auth_callout` is on, every
connection except the `auth_users` entries goes through it — **including config users with correct
passwords** — so `allowed_accounts` lets you move one account at a time."

**In operator mode** the callout "is configured on the account's JWT instead of the server config,
and the account declares which other accounts `auth-svc` may bind clients to."

## Practical takeaways

- **The auth service is on the connection path.** "If `auth-svc` is down, slow, or crashed, the
  server gets no reply, waits out the `timeout` in the `authorization` block, and rejects the client.
  The default wait is two seconds, so an outage turns into two seconds of latency on every new
  connection followed by a rejection." *(The 2-second default only holds without TLS — docs issue
  #19.)*
- **What the client prints depends on which deadline fires first.** With both defaults ~2s the client
  usually reports `read tcp ...: i/o timeout`; with `timeout: "1s"` the server's rejection wins and
  the client sees `Authorization Violation`. "In both cases the reason lives only in the server log":
  `[ERR] ... authentication error - Token "[REDACTED]"`.
- **`auth_users` is not a convenience allow-list.** "Adding an application user here to 'save a round
  trip' silently exempts it from authentication. List only `auth-svc`."
- **Run more than one instance** and "keep its OIDC or LDAP lookups fast."

## When the page says to use it

"Use it when the identity is held somewhere NATS can't access directly" — OIDC/SSO bearer tokens,
LDAP or a corporate directory, or a bespoke credential. "If your users fit a static config list, use
centralized authentication. If they fit a trust chain you control with `nats auth`, use operator
mode."

## Notable quotes

> "The protocol between the server and `auth-svc` is fixed; what `auth-svc` does in the middle is
> yours."

> "That deny stops forgery, not eavesdropping."

## Relevance to the wiki

The whole of [[auth-callout]] and the answer to Q53 — though the page never states whether the
server checks `connect_opts.nkey` before handing it over. That was read from the server source
instead ([[s-nats-server-auth-and-tls]]) and asked in public as
[[s-gh-7505-auth-callout-nkey]].

## Questions it answers

Q53.

## Pages touched

[[auth-callout]] · [[account]] · [[subject-permissions]] · [[js-api-subjects]] ·
[[defaults-and-limits]] · [[config-keys]] · [[nats-server-2.11]]
