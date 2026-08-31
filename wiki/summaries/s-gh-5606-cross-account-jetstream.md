---
title: "gh#5606 — Manage streams / KVs across multiple accounts with one user"
type: summary
area: [security, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/5606
source-path: raw/gh-discussions/gh-5606.md
author: "@pcsegal (asked); @Jarema (answer), @ripienaar, @derekcollison, @jnmoyne, @atlejensen"
article: "GitHub Discussion 5606 (Q&A)"
date: 2024-06-28          # opened; answer chosen 2024-08-10
version: ""              # no server version stated
tags: [accounts, jetstream, api-prefix, imports, system-account, sourcing]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5606 — one user managing JetStream in several accounts

Opened 2024-06-28, answered 2024-08-10. Four maintainers give four different answers, and together
they are the closest thing to a public statement of how JetStream crosses an account boundary.

## Key claims

**The question.** "It looks like I can't have a single user that can manage streams/KVs in multiple
accounts… Is there a way of doing that without having to separately connect as each user's account?"

**The isolation answer** (@Jarema, marked):

> "Each account is a separate tenant, with fully isolated subject context etc. You cannot use one
> user to manage multiple streams. Even if you want to share some data between accounts, you need to
> explicitly specify imports/exports."

> "You can however use system account to overview the whole NATS & JetStream system."

**And the correction that follows it.** A reader tried to give the system account JetStream limits
and hit a fatal:

```
[FTL] Not allowed to enable JetStream on the system account
```

@derekcollison: "The system account provides JetStream as a service to all enabled accounts. So that
is correct, you can not enable JetStream on the system account." *(Verified at v2.14.6 —
`server.go:2429`, [[s-nats-server-auth-and-tls]].)* So the system account is a **read-only overview**,
not a management plane.

**The mechanism that actually answers the question** (@ripienaar):

> "You should be able to import the foreign account jetstream API and manage it using the API prefix
> options in clients and CLI"

This is the one reply that names the real feature: an account exports `$JS.API.>` as a **service**,
another account imports it under a prefix, and the client is told that prefix. Nothing in the thread
elaborates, and **no docs page covers it** — see docs issue #21.

**The data-plane alternative** (@jnmoyne): "You can source streams from one account to another and
have (some) control over what subjects get transferred", pointing at
<https://github.com/synadia-labs/cross-account-jetstream-sourcing>.

**A scale question that went unanswered:** "For a large multitenant system, is there a theoretical
maximum number of imports for a single account? I'm imagining importing thousands of tenants…"
Nobody replied. The wiki does not state a limit, because no public source gives one.

**The commercial answer** (@atlejensen): Synadia Control Plane "gives you an overlay where you can
manage multiple accounts with a single user", and Qaze as a desktop tool.

## Practical takeaways

- **There is no cross-account user.** A connection is bound to exactly one account for its whole
  life; a management tool that spans accounts holds one credential per account, or imports the
  foreign JetStream API.
- **Two distinct approaches, for two distinct problems:**
  - *control plane* — import the other account's `$JS.API.>` as a service and address it with an API
    prefix. One user can then create and inspect assets in the other account.
  - *data plane* — a `source` or `mirror` with an `external` block, which copies messages rather than
    delegating control.
- **The system account cannot hold streams.** Do not plan a "central admin account" that owns
  JetStream state; the server refuses to boot.
- The absence of a documented import ceiling is a genuine gap for anyone designing per-tenant
  accounts at thousands of tenants.

## Notable quotes

> "Each account is a separate tenant, with fully isolated subject context etc." — @Jarema

> "The system account provides JetStream as a service to all enabled accounts."
> — @derekcollison

## Relevance to the wiki

The only public source that names the API-prefix route, and therefore the backbone of
[[cross-account-sharing]]'s JetStream section. Paired with [[s-gh-7017-kv-across-accounts]], which
asks the same question about KV and gets no answer at all.

## Questions it answers

Q90; Q51 (partly).

## Pages touched

[[cross-account-sharing]] · [[account]] · [[key-value]] · [[mirrors-and-sources]] ·
[[js-api-subjects]] · [[synadia-products]] · [[error-codes]]
