<!-- source: https://docs.nats.io/learn/security/auth-callout.md · fetched 2026-08-31 · section: auth-callout -->
# Auth callout

Every page so far decided authentication inside the server. Centralized mode checked a user list in the config. Decentralized mode, the ACME chain you built and ran over the last two pages, verified a signature chain back to the operator. Either way, the server held everything it needed to say yes or no.

Sometimes the server can't have that information. The real source of truth for "who is this?" lives in an OIDC provider, an LDAP directory, or a custom service that mints short-lived credentials. You don't want to copy that directory into NATS config, and you can't make the server query LDAP directly. Auth callout handles this: the server asks an external service instead.

## What auth callout is

**Auth callout** delegates the authentication decision to an external NATS service. When a client connects, the server doesn't make the authentication decisions about the client itself. The server packages up what the client presented and some details about the connection, and sends that to a service you run, then waits for a verdict.

That service is the **auth service**: in our scenario, `auth-svc`. It receives each connection attempt, applies its own logic, and replies with either a user identity or a rejection.

The hand-off happens over one well-known subject: `$SYS.REQ.USER.AUTH`. The server publishes the connection request there, and `auth-svc` subscribes there, so authentication becomes a request/reply exchange over NATS itself.

The protocol between the server and `auth-svc` is fixed; what `auth-svc` does in the middle is yours. That's how NATS authenticates against any external identity system.

This whole mechanism is defined in ADR-26, which specifies the request and response shape, the signing rules, and the optional encryption we point to at the end.

## The flow

**Message flow — Auth callout flow (animated):** Auth callout, one connection through. A client connects to the server with an external credential. The server does not consult its own user list; it publishes a signed authorization request on $SYS.REQ.USER.AUTH. The external auth-svc receives it, verifies the credential its own way, and replies with a signed user JWT that places the client into an account. The server verifies the reply and admits the client as that user — the admission decision was made outside the server.

* Client (order-svc) → NATS (operator ACME)
* Client (order-svc) → NATS (operator ACME)
* NATS (operator ACME) → auth-svc (subject: $SYS.REQ.USER.AUTH)
* auth-svc → NATS (operator ACME) (subject: signed user JWT)
* NATS (operator ACME) → auth-svc

Follow one connection through.

A client connects, presenting a token, say `ord-token-123`. The client isn't in `auth_users`, so the server doesn't consult its own user list at all. It builds a request describing the attempt.

The server publishes that request to `$SYS.REQ.USER.AUTH`. `auth-svc` is subscribed, so it receives the request, reads the token, and decides the token maps to the `order-svc` user in `ORDERS`.

`auth-svc` replies with a user identity for `order-svc`. The server reads the reply, admits the client as `order-svc`, and the publish succeeds, exactly as if `order-svc` had logged in directly.

The client has no indication that a callout happened. It connected with a token and got a working connection. The directory lookup, the mapping, and the verdict all happened in `auth-svc`, separate from the client.

## Configure it

Auth callout lives in the `authorization` block, the same block that held the config user list on the [Authentication basics](/learn/security/authentication-basics.md) page. So for this page the server leaves operator mode and goes back to a config-mode `nats.conf` — auth callout works in either mode, but the operator-mode variant needs JWT changes covered at the end. The config below is deliberately minimal: it declares `ORDERS` and `ANALYTICS` as empty accounts so the callout has somewhere to place clients, without the users, permissions, and export the earlier pages built. You add an `auth_callout` section to the `authorization` block:

```
accounts {

    ORDERS: {}

    ANALYTICS: {}

}



authorization {

    # auth-svc connects with these credentials.

    users: [ { user: auth-svc, password: c4llout } ]



    auth_callout {

        # Public account NKey allowed to sign the response.

        issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"

        # Users that bypass the callout (the auth service itself).

        auth_users: [ auth-svc ]

    }

}
```

The account `auth-svc` places a client into must exist in the config — here the empty `ORDERS` and `ANALYTICS` declarations above.

Three fields in the `authorization` block do the work here.

`issuer` is the public account NKey allowed to sign the response. The server admits a client only if the reply was signed by this key. It starts with `A` because it's an account key, the same prefix you read on the [Decentralized authentication](/learn/security/decentralized-auth.md) page. Generate the pair with `nats auth nkey gen account --output issuer.nk`; `nats auth nkey show issuer.nk` prints the public half for this config, and `auth-svc` keeps the seed file so it can sign.

`auth_users` lists the users that skip the callout. `auth-svc` itself connects to NATS to receive requests, so it must authenticate the ordinary way. Listing it here exempts that user from the callout. Without that exemption, the service that answers callouts could never connect to receive them.

The `users` entry above defines those bypass credentials: `auth-svc` connects with user `auth-svc` and password `c4llout`.

A fourth field, `account`, names which account `auth-svc` runs in and where `$SYS.REQ.USER.AUTH` is protected. We leave it unset here, so it defaults to the global account `$G`. The next section explains why production setups override it.

With the server running this config and `auth-svc` answering requests, the flow from the animation works end to end. Our `auth-svc` maps the token `ord-token-123` to `order-svc` in `ORDERS`:

```
nats --token "ord-token-123" pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

```
14:20:43 Published 91 bytes to "orders.created"
```

The client presented a token the server config knows nothing about, and the publish went through. A wrong token gets the opposite verdict:

```
nats --token "wrong-token" pub orders.created 'x'
```

```
nats: error: nats: Authorization Violation
```

`Authorization Violation` is all the client learns. Why the token was rejected appears only in the server log; the next sections cover both that and what protects the exchange itself.

Auth callout requires NATS Server 2.10.0 or later. It's also disabled in FIPS-140 mode and can't be configured there.

## Why the auth service runs in its own account

`$SYS.REQ.USER.AUTH` carries every connection attempt on the server. Each request includes whatever the client presented: its token, its password, its NKey. Anything that can read this subject can harvest other clients' credentials.

You can watch that happen. The bypass user subscribes to the subject, a second client connects with a test credential, and the request the server publishes there decodes straight back to readable JSON:

#### CLI

```
#!/bin/sh

# Eavesdrop demo: what actually crosses $SYS.REQ.USER.AUTH. The server's

# automatic deny stops other users from PUBLISHING a fake request or

# verdict, but it does not hide the request from anything that can read

# the subject. The auth service — and anything sharing its account — sees

# every connection attempt in the clear. That is why ADR-26 says isolate

# the account and reach for xkey.



# 1. The page's callout config. auth-svc is the auth_users bypass user, so

#    it is the one client allowed to connect without a callout and read the

#    subject. auth-callout.conf:

#

#    accounts {

#        ORDERS: {}

#        ANALYTICS: {}

#    }

#    authorization {

#        users: [ { user: auth-svc, password: c4llout } ]

#        auth_callout {

#            issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"

#            auth_users: [ auth-svc ]

#        }

#    }



# 2. Start the server with that config.

nats-server -c auth-callout.conf &



# 3. Terminal one: the bypass user subscribes to the hand-off subject. No

#    auth service is answering — we only want to read what the server

#    publishes there, not reply to it.

nats --server nats://localhost:4222 \

  --user auth-svc --password c4llout \

  sub '$SYS.REQ.USER.AUTH' --count 1



# 4. Terminal two: a second client connects with a test credential. The

#    server can't authenticate it locally, so it publishes an authorization

#    request to $SYS.REQ.USER.AUTH — which terminal one receives.

nats --server nats://localhost:4222 \

  --token "test-cred-xyz" \

  pub orders.created 'hi'



# Terminal one prints the request: a base64url JWT.

# [#1] Received on "$SYS.REQ.USER.AUTH" with reply "$SYS._INBOX...."

# eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJuYXRz...



# 5. base64 is encoding, not encryption. Decode the middle segment — the

#    claims — and the plaintext falls straight out. tr fixes base64url

#    characters; the loop pads to a multiple of four so base64 -d does not

#    truncate.

P="$(nats --server nats://localhost:4222 \

  --user auth-svc --password c4llout \

  sub '$SYS.REQ.USER.AUTH' --count 1 --raw | cut -d. -f2 | tr '_-' '/+')"

while [ $(( ${#P} % 4 )) -ne 0 ]; do P="${P}="; done

printf '%s' "$P" | base64 -d

# (run the terminal-two publish again to trigger a fresh request)



# Expected (trimmed): the request the server signs, decoded.

# {

#   "aud": "nats-authorization-request",

#   "iss": "NAFYFDR6WSIIQ5ABEJQWTZ6MGWSHSSATKRMR3STTBJ52MHJQA5YIHA3R",

#   "nats": {

#     ...

#     "user_nkey": "UA423HWLLH3GJC662GWLEBBGKTZXIM6TNZIXQKPCDPFIL3II5FNDRDLC",

#     "client_info": { ..., "user": "[REDACTED]", ... },

#     "connect_opts": { "auth_token": "test-cred-xyz", ... },

#     "type": "authorization_request"

#   }

# }

#

# Three things to read off it:

#  - The hand-off subject is real: the attempt arrived on

#    $SYS.REQ.USER.AUTH exactly as the flow describes.

#  - user_nkey is fresh for this connection. Run the publish again and

#    the next request carries a different one, so a captured reply can't

#    be replayed against a later connection.

#  - connect_opts.auth_token is the client's credential in plaintext.

#    client_info.user shows [REDACTED], but the raw token the client

#    presented rides along readable. A password or nkey seed would sit

#    here the same way.

#

# The token is readable to every subscriber on this subject. Isolating

# auth-svc in its own account keeps other users off the subject; xkey

# (Reference -> auth_callout) seals the payload so even a subscriber

# can't read it.
```

```
{

  "aud": "nats-authorization-request",

  "iss": "NAFYFDR6WSIIQ5ABEJQWTZ6MGWSHSSATKRMR3STTBJ52MHJQA5YIHA3R",

  ...

  "nats": {

    ...

    "user_nkey": "UA423HWLLH3GJC662GWLEBBGKTZXIM6TNZIXQKPCDPFIL3II5FNDRDLC",

    "client_info": { ..., "user": "[REDACTED]", ... },

    "connect_opts": { "auth_token": "test-cred-xyz", ... },

    "type": "authorization_request"

  }

}
```

The hand-off subject is real: the attempt lands on `$SYS.REQ.USER.AUTH` exactly as the flow describes, and each attempt carries its own fresh `user_nkey`. The `auth_token` is the client's credential in plaintext: base64 is encoding, not encryption, so any subscriber decodes it in one line. The server redacts `client_info.user`, but the raw token the client presented rides along readable, and a password or NKey seed would sit there the same way. That's what account isolation below, and the `xkey` option this page covers at the end, are there to protect.

The server adds one protection automatically. On the account where auth callout runs, publishing to `$SYS.REQ.USER.AUTH` is denied for every user — including `auth-svc` itself, which only needs to subscribe and reply. No ordinary user can inject a fake request or a fake verdict onto the subject.

That deny stops forgery, not eavesdropping, which is why ADR-26 recommends one step further: run `auth-svc` in its own dedicated account. With nothing else in that account, no other user can subscribe to the request traffic. And since the auth service can bind a client to any authorized account, a service with that much capability should be isolated anyway: a compromise of some other tenant can't reach it, and a bug in `auth-svc` can't leak into a tenant's subject space.

This is the `account` field from the config above. Point it at a small account that holds nothing but `auth-svc`, and the callout setup stays isolated from `ORDERS`, `ANALYTICS`, and everything else.

## The signed request and response

The request/reply over `$SYS.REQ.USER.AUTH` is the obvious attack surface. If anything could publish a fake reply, it could forge any user. Signatures and a one-time key protect against that.

The server signs the request. Every request it sends to `$SYS.REQ.USER.AUTH` is a JWT signed by an NKey the server generated fresh at startup, carrying the server's own ID as issuer and the fixed string `nats-authorization-request` as audience. `auth-svc` can check the request is self-consistent and unmodified, but the key isn't an identity the service was told to trust in advance. What actually stops another client from provoking a verdict is the publish deny from the previous section: only the server can get a request onto the subject.

The request also pins a one-time identity. The server generates a fresh public user NKey for this connection and places it in the request, in a field called `user_nkey`. The reply is only valid if it names that exact NKey as its subject. A captured old reply can't be replayed against a new connection, because each connection carries its own NKey.

`auth-svc` signs the response, and the response is two JWTs, one inside the other. The outer one is the verdict. Its subject is the connection's one-time `user_nkey`, and its audience is the ID of the server that asked, so a verdict produced for one server is useless at another.

Inside it is a user JWT, the same kind of signed identity document from the [Decentralized authentication](/learn/security/decentralized-auth.md) page. Its subject is again the `user_nkey`. Its audience is the name of the target account, `"ORDERS"` in our scenario, and that audience is what places the client in `ORDERS`: `auth-svc` writes the account name into the user JWT, and the server binds the connection there. Both JWTs must be signed by the `issuer` account key from the config; in config mode the server rejects a user JWT that names an `issuer_account`.

The placement shows up in the server log. Here the admitted client publishes outside the permissions `auth-svc` granted it:

```
[ERR] 127.0.0.1:57852 - cid:12 - "v1.51.0:go:NATS CLI Version v0.4.0" - "ORDERS/user:order-svc" - Publish Violation - Subject "billing.charge"
```

The client connected with nothing but a token, yet the server records it as `order-svc` in `ORDERS`. Identity, account, and permissions all came from the response JWT.

Rejections take one of two shapes. `auth-svc` can reply with an error: the client gets `nats: error: nats: Authorization Violation` right away, and the error text goes to the server log only, never to the client:

```
[WRN] Auth callout service returned an error: token did not match any known service
```

Or the service can drop the request without replying: the client waits out the callout timeout and typically reports `read tcp ...: i/o timeout`. The callout libraries recommend dropping for bad credentials, because the added delay slows down brute-force guessing.

## When to use it

Auth callout is the more involved option. Use it when the identity is held somewhere NATS can't access directly.

* **OIDC / SSO.** A client carries a bearer token from your identity provider; `auth-svc` validates it and maps the claims to a NATS user.
* **LDAP / directory.** Users and groups live in a corporate directory; `auth-svc` looks them up and grants the matching permissions.
* **Custom tokens.** A bespoke credential (an API key, a signed cookie, a license token) that only your service knows how to verify.

If your users fit a static config list, use centralized authentication. If they fit a trust chain you control with `nats auth`, use operator mode. Auth callout is for when the verdict must come from a system NATS doesn't own.

## What we're leaving out

A few parts of ADR-26 go beyond this page.

* The request and response can be encrypted with an x25519 **xkey**, set in the `auth_callout` block, so the credentials on `$SYS.REQ.USER.AUTH` are sealed even from a leaked subscription. See [Reference → auth\_callout](/reference/config/authorization/auth_callout/.md).
* An **`allowed_accounts`** field (NATS Server 2.11 and later) limits the delegation to the config-defined accounts you list; users of every other account authenticate the ordinary way. One exception: a connection that matches no config user lands in the global account `$G`, and those connections always go through the callout, whatever the list says. The moment `auth_callout` is on, every connection except the `auth_users` entries goes through it — including config users with correct passwords — so `allowed_accounts` lets you move one account at a time.
* In operator mode, auth callout is configured on the account's JWT instead of the server config, and the account declares which other accounts `auth-svc` may bind clients to. The full request claim and the binding details are in ADR-26.
* Writing the `auth-svc` handler itself (decoding the request, validating the token, signing the response) is a programming task with ready-made libraries; the See also links point at runnable services.

Here we use only the `issuer` and `auth_users` fields, in the global account.

## Pitfalls

Two things catch people when they turn the callout on.

**The auth service is a single point of failure.** Every new connection that needs a callout waits for `auth-svc` to reply. If `auth-svc` is down, slow, or crashed, the server gets no reply, waits out the `timeout` in the `authorization` block, and rejects the client. The default wait is two seconds, so an outage turns into two seconds of latency on every new connection followed by a rejection.

Set `timeout` deliberately and treat the auth service as production infrastructure. Run more than one instance so a single slow one doesn't stall logins, and keep its OIDC or LDAP lookups fast.

What the client reports depends on timing. A client's own connect deadline also defaults to about two seconds, so with both defaults in place the client usually gives up at the same moment the server rejects it and prints `nats: error: read tcp ...: i/o timeout` instead of an auth error. When the callout `timeout` is shorter than the client's deadline (the demo below sets it to one second), the server's rejection arrives first and the client sees `Authorization Violation`. In both cases the reason lives only in the server log.

Here's what an outage looks like. The publish triggers a callout, nobody answers, and the connection is rejected after the timeout:

#### CLI

```
#!/bin/sh

# Pitfall: the callout sits on the connection path. If auth-svc is slow,

# down, or crashed, every new connection waits for the response and is

# then rejected when the wait runs out. The wait is the `timeout` field

# in the authorization block (default 2s). Set it deliberately.



# 1. The server config sets an explicit callout timeout. auth-callout.conf:

#

#    authorization {

#        # How long the server waits for auth-svc before rejecting. Default 2s.

#        timeout: "1s"

#        users: [ { user: auth-svc, password: c4llout } ]

#        auth_callout {

#            issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"

#            auth_users: [ auth-svc ]

#        }

#    }



# 2. Start the server with that config.

nats-server -c auth-callout.conf &



# 3. Do NOT start auth-svc, to simulate an outage. A client connects with a

#    token. The server signs a request, publishes it to $SYS.REQ.USER.AUTH,

#    and no one replies. The 1s callout timeout is below the client's ~2s

#    connect deadline, so the server's rejection arrives first and the

#    client sees Authorization Violation.

nats --server nats://localhost:4222 \

  --token "ord-token-123" \

  pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'



# Expected: the publish fails with an authorization error after ~1s.

# nats: error: nats: Authorization Violation

#

# The fix is operational, not config: run auth-svc with enough replicas

# that one slow instance does not stall connections, and keep its

# OIDC/LDAP lookups fast.
```

```
nats: error: nats: Authorization Violation
```

The rejection lands after about one second, the configured `timeout`. The server log records the same moment as `[ERR] ... authentication error - Token "[REDACTED]"`; the server redacts the presented token even in its own log.

**Adding application users to `auth_users`.** Every user named in `auth_users` skips the callout and connects with no external check. The list exists for one job: letting `auth-svc` itself in so it can receive requests on `$SYS.REQ.USER.AUTH`.

Adding an application user here to "save a round trip" silently exempts it from authentication. List only `auth-svc`. Everything else goes through the callout, which is the point of turning callout on.

#### CLI

```
#!/bin/sh

# Pitfall: auth_users is not a convenience allow-list. Every user listed

# there skips the callout entirely and connects with no external check.

# It exists for one job: letting auth-svc itself in so it can receive

# requests. Adding an application user here silently exempts it from

# authentication.



# WRONG. order-svc now bypasses the callout and connects unchecked.

#

#    authorization {

#        users: [

#            { user: auth-svc,  password: c4llout }

#            { user: "order-svc", password: "open" }

#        ]

#        auth_callout {

#            issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"

#            auth_users: [ auth-svc, order-svc ]   # <-- order-svc escapes the callout

#        }

#    }



# RIGHT. Only auth-svc bypasses. order-svc goes through the callout like

# every other connection. auth-callout.conf:

#

#    authorization {

#        users: [ { user: auth-svc, password: c4llout } ]

#        auth_callout {

#            issuer: "ABJHLOVMPA4CI6R5KLNGOB4GSLNIY7IOUPAJC4YFNDLQVIOBYQGUWVLA"

#            auth_users: [ auth-svc ]

#        }

#    }



# Start the server with the RIGHT config. No auth service is running in

# this demo, which is what makes the exemption visible.

nats-server -c auth-callout.conf &



# auth-svc is in auth_users, so it connects and publishes even though no

# auth service is running. The callout is skipped for it — exactly what

# an application user would inherit if you listed one here.

nats --server nats://localhost:4222 \

  --user auth-svc --password c4llout \

  pub orders.created 'x'

# Expected:

# 14:22:34 Published 1 bytes to "orders.created"



# order-svc is not in auth_users, so its token goes through the callout.

# With no auth service answering, the connection fails after the callout

# timeout (default 2s). With default client timeouts the client reports

# an i/o timeout; the reason appears only in the server log.

nats --server nats://localhost:4222 \

  --token "ord-token-123" \

  pub orders.created \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# Expected:

# nats: error: read tcp ...: i/o timeout
```

```
14:22:34 Published 1 bytes to "orders.created"

nats: error: read tcp ...: i/o timeout
```

The first line is `auth-svc` itself. It's in `auth_users`, so it connects and publishes with no auth service running at all: that's the exemption the list grants, and what an application user would inherit if you added one. The token client isn't exempt, so it goes through the callout, and with nobody answering it fails after the default two-second timeout.

Two more mistakes are covered by the sections above: leaving the callout in the global account `$G`, and skipping `xkey` so credentials cross `$SYS.REQ.USER.AUTH` in the clear. Run `auth-svc` in its own account, and reach for `xkey` when the wire carries secrets you wouldn't want a leaked subscription to read.

## Where you are

Auth callout is configured and working:

* The server delegates the decision by publishing each connection attempt to `$SYS.REQ.USER.AUTH`.
* `auth-svc` subscribes there, maps a token to a user, and replies. In our scenario it maps `ord-token-123` to `order-svc` in `ORDERS`.
* The server signs the request; `auth-svc` signs the response with the `issuer` account key. The one-time `user_nkey` stops replay.
* The demo callout runs in the global account `$G`; in production you point the `account` field at a dedicated account holding only `auth-svc`, so nothing else can observe the request traffic. Either way, only `auth_users` may publish on the protected subject.

That's the last of the chapter's three authentication styles: a config user list, a signature chain, and a verdict delegated to your own service.

## What's next

Every connection this chapter made ran over plaintext TCP: passwords and tokens crossed the wire readable, and even the JWT handshake was visible. The next page covers TLS on the client connection, a certificate as the identity, and encryption of the JetStream store.

Continue to [Encryption & TLS](/learn/security/encryption.md).

## See also

* [Reference → auth\_callout](/reference/config/authorization/auth_callout/.md) — every field of the `auth_callout` block, including `xkey` and `allowed_accounts`.
* [Decentralized authentication](/learn/security/decentralized-auth.md) — the user JWTs and account NKeys that the callout response reuses.
* [ADR-26](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-26.md) — the full protocol: request and response claims, signing rules, and xkey encryption.
* [callout.go](https://github.com/synadia-io/callout.go), [callout.net](https://github.com/synadia-io/callout.net), and [NATS by Example: auth callout](https://natsbyexample.com/examples/auth/callout/cli) — runnable services and libraries for writing `auth-svc`.
