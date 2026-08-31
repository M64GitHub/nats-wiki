---
title: "gh#7854 — Example JWT setup from the docs is not working.. at all."
type: summary
area: [security]
source-url: https://github.com/nats-io/nats-server/discussions/7854
source-path: raw/gh-discussions/gh-7854.md
author: "@tbalbers (asked); @MauriceVanVeen (answer), @aricart"
article: "GitHub Discussion 7854 (Q&A)"
date: 2026-02-19          # opened and answered the same day
version: "2.12"          # the version the answer recommends; the fault was 1.4.1
tags: [nsc, nats-auth, resolver, account-push, "$SYS.REQ.CLAIMS.UPDATE", timeout]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7854 — an account push that times out with nothing in the log

Opened and answered on 2026-02-19. The value here is not the cause — it was an absurdly old server —
but the **failure shape**, which is what an operator-mode setup looks like when any link in the chain
is missing.

## Key claims

**The symptom.** A push that fails with a timeout and a zero count:

```
nsc push -a sentinel -u nats://localhost:8222
[ERR ] push to nats-server "nats://localhost:8222" using system account "SYS":
       [ERR ] push sentinel to nats-server with nats account resolver:
              [ERR ] failed to get response to push account: nats: timeout
              [ OK ] pushed to a total of 0 nats-server
Error: all jobs failed
```

**And nothing in the server log, even at `-DV`.** The trace shows the whole exchange working right up
to the point where nothing answers:

```
[TRC] ... ->> [SUB _INBOX.9ML9Xq7cqAXTRCImi29bDV  1]
[TRC] ... ->> [PUB $SYS.REQ.CLAIMS.UPDATE _INBOX.9ML9Xq7cqAXTRCImi29bDV 712]
[DBG] ... Client connection closed
```

So the push **connected and authenticated**, published its account JWT to
**`$SYS.REQ.CLAIMS.UPDATE`**, and waited out its timeout because the server had no subscriber on that
subject. There is no error, because from the server's point of view nothing went wrong.

**The push user's own permissions**, decoded from the CONNECT line in the trace, are narrow and
temporary — a "nsc temporary push user" allowed to publish exactly
`$SYS.REQ.CLAIMS.LIST`, `$SYS.REQ.CLAIMS.UPDATE`, `$SYS.REQ.CLAIMS.DELETE` and subscribe `_INBOX.>`.

**The cause.** @MauriceVanVeen read it off the boot banner the asker had pasted:

```
[INF] Starting nats-server version 1.4.1
```

> "That's way too old! You'll need at least 2.2.0, which is also logged when creating an operator."

@aricart: "Likely that version doesn't support `$SYS.REQ.CLAIMS.UPDATE`." The asker upgraded and it
worked immediately.

**A maintainer's working `nats auth` sequence**, given in the same answer:

```
nats auth operator add MyOperator
nats auth operator select MyOperator

nats auth account add MyAccount --defaults
nats auth user add MyUser MyAccount --defaults
nats auth user credential MyUser.creds MyUser MyAccount

nats auth user add sys SYSTEM --defaults
nats auth user credential sys.creds sys SYSTEM

nats server generate nats-auth-config    # select "'nats auth' managed NATS Server configuration"
nats-server -c nats-auth-config/server.conf
```

```
nats auth account push MyAccount --creds sys.creds
Updating account MyAccount (ADUE6YPH3JI5FLIZVAYMZ2BDGG2HJGIMPMAL4QZL34P3KQ6RWTVLFGE7) on 1 server(s)
✓ Update completed on nats.example.net
Success 1 Failed 0 Expected 1
```

Note `nats auth operator select`, which the docs' own walkthrough omits, and that **`SYSTEM` is
pre-created but its user is not** — you must add one before you can push anything.

**The `nsc`-era resolver config** the asker was following is quoted verbatim in the thread and is
worth keeping for its comments: `resolver { type: full, dir: './jwt', allow_delete: false,
interval: "2m", timeout: "1.9s" }` plus `resolver_preload` for the system account only —
"This only applies to the system account. Therefore other account jwt are not included here."
Its inline instructions name the prerequisite the docs bury:
`nsc edit operator --account-jwt-server-url nats://localhost:4222`, and note that
`nsc push --prune` requires `allow_delete: true`.

**A maintainer's view of the tooling:** "Admittedly the UX of `nsc` isn't the best still, and is one
of the reasons for improving it as part of the new `nats auth` command."

## Practical takeaways

- **`nats: timeout` on a push means nothing was listening on `$SYS.REQ.CLAIMS.UPDATE`.** The
  candidates, in order: the server is not in operator mode at all, no `system_account` is set, the
  resolver is not `type: full`, or the push is pointed at the wrong port. A too-old server is the
  exotic case; the ordinary ones produce the identical message.
- **Read the boot banner before reading anything else.** The version was printed in the asker's own
  paste and went unnoticed for hours.
- **The push port is the client port.** The asker's server listened on `8222` — usually the
  *monitoring* port — which is legal and confusing; a push goes over a normal NATS client connection.
- **A push failure is silent on the server side.** There is no log line to grep for; the evidence is
  the absence of a reply on the `_INBOX` in a `-DV` trace.

## Notable quotes

> "I've been trying to get NATS to work for hours and hours -but it seems impossible."
> — @tbalbers, on a version mismatch nothing diagnosed

## Relevance to the wiki

The Verify and Pitfalls halves of [[set-up-operator-mode]]: the runbook gates each step on a check
precisely because this failure produces no error anywhere.

## Questions it answers

Q49 (with [[s-docs-operator-mode]] and [[s-docs-decentralized-auth]]).

## Pages touched

[[set-up-operator-mode]] · [[operator-mode]] · [[nsc]] · [[nats-cli]] · [[account]] ·
[[js-api-subjects]]
