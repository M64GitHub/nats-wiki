---
title: "gh#7505 — Does NATS validate connect_opts.nkey before passing it to auth callout?"
type: summary
area: [security, topology]
source-url: https://github.com/nats-io/nats-server/discussions/7505
source-path: raw/gh-discussions/gh-7505.md
author: "@evrys (asked); @aricart (answer)"
article: "GitHub Discussion 7505 (Q&A)"
date: 2025-11-03          # opened and answered the same day
version: ""              # no server version stated
tags: [auth_callout, nkey, connect_opts, leafnode, callout.go, spoofing]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7505 — is `connect_opts.nkey` trustworthy inside a callout?

Opened and answered on 2025-11-03. A short thread that settles a security question with real
consequences: whether an auth callout service may treat the NKey it receives as proven.

## Key claims

**The setup.** Leafnodes each hold a unique seed and dial a hub:

```
leafnodes {
    remotes = [
        { url: "wss://cloud.example.com:443/nats", nkey: "SUAOBBHE…" }
    ]
}
```

The hub's auth service "looks up a device id corresponding to the incoming public key in a database
and returns JWT claims giving the leafnode permission to publish on e.g. `devices.${id}.foo`."

**What the service receives**, quoted from the request claim:

```json
{
  "nats": {
    "user_nkey": "UAO2CCMU37WL6VQGKZ6DRH52BCCUT7OWDBSTUIOT5W2KUI26YFSAPFNL",
    "connect_opts": {
      "nkey": "UDLY54Z6KSQXIP7SL4DICDB54FPYLX32NKZEIL5LDV3BUX327XTB4BLV",
      "lang": "nats.ws",
      "version": "3.2.0",
      "protocol": 1
    },
    "type": "authorization_request",
    "version": 2
  }
}
```

Note the two different NKeys: `user_nkey` is the **server's** one-time key for this connection;
`connect_opts.nkey` is what the **client** claimed.

**The question:** "can I assume NATS has already validated that the client is in possession of the
corresponding private key by the time it reaches my code?"

**The answer** (@aricart, marked):

> "callout doesn't do any kind of challenge response, you evaluate on what you got from the client,
> if you don't like it you reject, otherwise you issue a JWT for them - which is never given to
> them."

> "IMHO you need to have the client give you what you want to auth on, don't depend on the server
> for that."

The asker drew the right conclusion: "If the public key the callout service receives isn't already
checked though I'll need to think of some other way to avoid it being spoofed."

**The recommendation for implementers:** don't hand-roll the protocol.

> "you should take a look at <https://github.com/synadia-io/callout.go>, there are many checks that
> you should implement on your callout - the better suggestion is not to roll your own framework, but
> rather focus on the generation of your user jwt once you verified the data given by the client. The
> implementation above is hardened."

## Practical takeaways

- **Every field of `connect_opts` is an unverified claim**, `nkey` included. Confirmed in the source:
  `fillConnectOpts` copies `Nkey`, `SignedNonce`, `Token`, `Username` and `Password` straight from
  the client with no check ([[s-nats-server-auth-and-tls]]).
- **The challenge-response can still be done — by the service.** When the client supplied a
  signature, the server puts the nonce it issued into `client_info.nonce`, so a callout service can
  verify `connect_opts.signed_nonce` over that nonce against `connect_opts.nkey` itself. The thread
  does not mention this; the source does.
- **Treating an unverified NKey as an identity is a spoofing bug**, and a quiet one: the connection
  succeeds and the wrong device gets the wrong permissions.
- **Use a callout library.** Both maintainer replies point the same way, and `synadia-io/callout.go`
  is named as hardened.

## Notable quotes

> "you evaluate on what you got from the client, if you don't like it you reject" — @aricart

## Relevance to the wiki

The security caveat on [[auth-callout]], and the reason that page states what the server checks
*before* the callout (nothing) separately from what it checks *after* it (the response signature and
the one-time `user_nkey`).

## Questions it answers

Q53 (the "what does the server validate" half).

## Pages touched

[[auth-callout]] · [[subject-permissions]] · [[account]] · [[leafnode]]
