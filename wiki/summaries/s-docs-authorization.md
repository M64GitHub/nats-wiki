---
title: "docs.nats.io — Authorization"
type: summary
area: [security]
source-url: https://docs.nats.io/learn/security/authorization.md
source-path: raw/nats-docs/learn/security/authorization.md
author: NATS documentation (Synadia Communications, Inc.)
article: Authorization
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [permissions, allow, deny, default_permissions, allow_responses, queue-group, _INBOX]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Authorization

What an authenticated user may do, expressed entirely as subjects. Two rules govern every
permission NATS has, and both of them fail silently when you get them wrong.

## Key claims

**Every right is a subject.** "There's no separate notion of an admin role or a resource type.
Every right a user has is a subject it may publish to or a subject it may subscribe to." The two
lists are independent — a user can publish where it cannot subscribe, and the reverse.

```
permissions: {
  publish:   { allow: ["orders.>"] }
  subscribe: { allow: ["_INBOX.>"] }
}
```

**Rule 1 — an `allow` list closes everything else.** "The moment you write an `allow` list, every
subject not on it is denied", including "the JetStream API under `$JS.API.>`". A user with **no**
`permissions` block "can do anything on the server". Authorization is opt-in: "you opt in by writing
an `allow` list."

**An empty list is not a lock-down.** "`publish: []` parses as no list at all, so the user can
publish anywhere. To block all publishes, write `publish: { deny: [">"] }`."

**Rule 2 — deny beats allow.** "The server checks `allow` first, then checks `deny`, and a match in
`deny` overrides the allow."

**`default_permissions` is a fallback, never a merge.** A block inside `authorization {}` "applies to
every user that has no `permissions` block of its own. A user with its own block ignores the defaults
entirely — the two are never merged."

**A denial is reported, not silent — for a publish.** The client gets an asynchronous error and the
connection stays open; the server drops the message:

```
nats: error: nats: permissions violation: Permissions Violation for Publish to "billing.charge"
```

On the wire: `-ERR 'Permissions Violation for Publish to "billing.charge"'`. Every violation is
logged server-side, naming user and subject:

```
[ERR] 127.0.0.1:57456 - cid:6 - "v1.51.0:go:NATS CLI Version v0.4.0" - "$G/user:order-svc" - Publish Violation - Subject "billing.charge"
```

**A denied *request* looks like nothing at all.** "A request is a pairing of publish with a reply
'inbox' subscribe; so when the publish is denied, no responder ever sees it and the requester just
times out." And: "Every JetStream API call is a request under the hood, so a locked-down user running
`nats stream info` fails with `context deadline exceeded` rather than a permission error."

**Three grants the page names and skips:**

- **`allow_responses`** — "let a service reply to requests without a broad publish allow; the server
  tracks each reply subject it handed out and permits exactly that one reply."
- **queue-group permissions** — a subscribe entry `"orders.created billing-workers"` "permits
  subscribing to `orders.created` only as a member of the `billing-workers` queue group; a plain
  subscribe to the same subject stays denied."
- **import/export permissions** — "a property of an account, not a user".

**The same lists live in JWTs under decentralized auth**, edited with the CLI:

```
nats auth user edit order-svc ORDERS --pub-allow "orders.>"
```

"Each flag replaces that entire list, so always pass the complete set of subjects." With scoped
signing keys "the user's JWT carries empty publish and subscribe lists, and the permissions live in
the account's signing-key scope instead. The server enforces the same two rules either way."

## Practical takeaways

**Four failure shapes, in the page's own order:**

1. **A subscribe deny silently breaks request-reply.** `subscribe: { deny: [">"] }` blocks the
   `_INBOX.>` subscription a request needs. "Adding `allow: ["_INBOX.>"]` next to the deny doesn't
   help — deny beats allow." The CLI prints only `Sending request on "orders.lookup"`, waits out the
   timeout and **exits 0**; the server logs
   `Subscription Violation - Subject "_INBOX.<random>", SID 1`.
2. **A missing entry in an allow list is a silent block.** Prefer `orders.>` over an enumerated
   `["orders.created", "orders.shipped"]` you must remember to grow.
3. **`allow: [">"]` grants the whole server**, `$JS.API.>` included.
4. **A deny under a wildcard subscription is invisible.** A *literal* subscribe to a denied subject
   fails loudly; a wildcard subscribe that merely overlaps the deny "is accepted, and the server
   filters the denied subjects out at delivery time… no error, no gap marker" — and, unlike the
   literal case, **no violation line in the server log either**. "If a subscriber seems to miss
   messages, check its deny lists before suspecting the publisher."

## Notable quotes

> "Because of that, controlling the subjects controls everything the user can reach."

> "The rejection is reported, not silent."

## Relevance to the wiki

The permission model every other security page assumes, and the source of two of the wiki's better
diagnostics: a JetStream call that times out instead of erroring, and a subscriber that quietly
misses a branch of a wildcard. Both look like application bugs.

## Questions it answers

Q52 (partly — the durable-consumer half needs `$JS.API` subject-level grants, see
[[s-gh-5044-restrict-durable-consumers]]).

## Pages touched

[[subject-permissions]] · [[account]] · [[js-api-subjects]] · [[operator-mode]] · [[nats-cli]] ·
[[cross-account-sharing]]
