---
title: Subject permissions
type: concept
area: [security, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [permissions, allow, deny, default_permissions, allow_responses, queue-group, _INBOX, "$JS.API"]
aliases: [permissions, authorization, allow list, deny list, publish permissions, subscribe permissions, default_permissions, allow_responses]
sources: [s-docs-authorization, s-docs-authentication-basics, s-gh-5044-restrict-durable-consumers, s-nats-server-auth-and-tls, s-docs-security-checklist]
created: 2026-08-31
updated: 2026-08-31
---

# Subject permissions

**A user's authorization is two lists of subjects: what it may publish to, and what it may subscribe
to.** There is no role, no resource type and no verb beyond those two — "Every right a user has is a
subject it may publish to or a subject it may subscribe to" (source: [[s-docs-authorization]]).

That is not a simplification. Everything a client does travels on a subject, a request is a publish
plus a subscribe, and the JetStream control plane is `$JS.API.>`, so the subject lists really are the
whole of what a user can reach. Permissions operate *inside* an [[account]]; they cannot open or
close an account boundary.

## How it behaves

**Two rules govern every permission you will ever write.**

**1 — An `allow` list closes everything else.** "The moment you write an `allow` list, every subject
not on it is denied", `$JS.API.>` included. The corollary is the one that surprises people: a user
with **no** `permissions` block "can do anything on the server".

**2 — Deny beats allow.** "The server checks `allow` first, then checks `deny`, and a match in `deny`
overrides the allow." You rarely need both lists; when you do, deny is applied last.

**An empty list is not a lock-down.** `publish: []` "parses as no list at all, so the user can publish
anywhere". To block every publish, write `publish: { deny: [">"] }`.

**`default_permissions` is a fallback, never a merge.** It applies only to users with no
`permissions` block of their own; "A user with its own block ignores the defaults entirely — the two
are never merged."

**Wildcards are the ordinary subject wildcards.** `*` is one token, `>` is one or more trailing
tokens. `orders.>` covers `orders.at.northpole`; `orders.*` does not.

## What configures it

```
authorization {
  users: [
    {
      user: order-svc
      password: s3cr3t
      permissions: {
        publish:   { allow: ["orders.>"], deny: ["orders.secret"] }
        subscribe: { allow: ["_INBOX.>"] }
      }
    }
  ]
}
```

The same block sits inside an account's `users` array once you have accounts, and inside a JWT once
you are in [[operator-mode]] — where the recommended form is a **scoped signing key** whose template
carries the lists, leaving the user's own JWT with `"pub": {}, "sub": {}`. "The server enforces the
same two rules either way."

| field | what it does |
|---|---|
| `publish` / `subscribe` | the two independent lists, each taking `allow` and `deny` |
| `allow_responses` | lets a service reply without a broad publish grant — "the server tracks each reply subject it handed out and permits exactly that one reply" |
| queue-group form | a subscribe entry `"orders.created billing-workers"` permits the subject **only** as a member of that queue group; "a plain subscribe to the same subject stays denied" |
| `default_permissions` | the fallback for users with no block of their own |

The CLI equivalent in operator mode replaces a whole list per flag:

```
nats auth user edit order-svc ORDERS --pub-allow "orders.>"
```

"Each flag replaces that entire list, so always pass the complete set of subjects."

## What a denial looks like

**A denied publish is loud** — an asynchronous error, the message dropped, the connection kept open:

```
nats: error: nats: permissions violation: Permissions Violation for Publish to "billing.charge"
```

On the wire the server sends `-ERR 'Permissions Violation for Publish to "billing.charge"'`, and
logs it with the account, the user and the subject:

```
[ERR] 127.0.0.1:57456 - cid:6 - "v1.51.0:go:NATS CLI Version v0.4.0" - "$G/user:order-svc" - Publish Violation - Subject "billing.charge"
```

**A denied request is silent.** A request publishes and subscribes to a reply inbox; when the publish
is denied there is no responder and the caller simply waits. And because "Every JetStream API call is
a request under the hood", a locked-down user running `nats stream info` fails with **`context
deadline exceeded`**, not a permission error. When a request times out for no reason, read the server
log.

**A deny under a wildcard subscription is silent on both sides.** A *literal* subscribe to a denied
subject is rejected loudly. But a wildcard subscribe that merely overlaps a deny "is accepted, and
the server filters the denied subjects out at delivery time" — no client error, **no violation line
in the server log either**. A subscriber that seems to miss messages is the symptom.

## Limits and failure modes

- **A missing entry in an `allow` list is a silent block**, indistinguishable from a bug in the
  publisher until you read the log. Prefer the wildcard that matches the user's real subject space
  over an enumerated list you must remember to grow.
- **A subscribe deny breaks request-reply irrecoverably.** With `subscribe: { deny: [">"] }` the
  client cannot create its `_INBOX` subscription, and adding `allow: ["_INBOX.>"] ` alongside does
  **not** help, because deny beats allow. Replace the deny. The server logs
  `Subscription Violation - Subject "_INBOX.<random>", SID 1`; the CLI prints nothing and exits 0.
- **`allow: [">"]` hands over the server**, `$JS.API.>` and every other account-visible control
  subject with it.
- **Permissions cannot see a message body.** This is why "let this user create ephemeral consumers
  but not durables" has no clean answer: modern clients create both on
  `$JS.API.CONSUMER.CREATE.<stream>.<name>`, and the durable name is in the **payload**
  (source: [[s-gh-5044-restrict-durable-consumers]]). You can pin the *filter* by allowing
  `$JS.API.CONSUMER.CREATE.<stream>.*.<subject>` and denying the unfiltered
  `$JS.API.CONSUMER.CREATE.<stream>`, but the durable/ephemeral distinction is not reachable from a
  subject rule. Per-account JetStream limits are the enforceable control.
- **A restricted user cannot see its own account.** `nats account info` asks the server over
  `$SYS.REQ.USER.INFO`; a narrow publish allow-list blocks the request and the field comes back empty
  (see [[account]]).

## Why an operator cares

The two rules decide whether a lockdown is real. The common production mistake is not an overly tight
list — that fails loudly on the first publish — but an overly loose one: a user with no `permissions`
block at all, or a `>` grant added "temporarily", both of which include the JetStream API.

The second is diagnostic. Three of this wiki's silent-failure gotchas are permission problems wearing
other clothes: a JetStream command that times out, a subscriber missing one branch of a wildcard, and
a request that never gets a responder.

## Related

[[account]] · [[operator-mode]] · [[auth-callout]] · [[tls-in-nats]] · [[cross-account-sharing]] ·
[[js-api-subjects]] · [[unauthenticated-clients-still-connect]] · [[config-keys]] · [[nats-cli]]

## Sources

[[s-docs-authorization]] · [[s-docs-authentication-basics]] · [[s-gh-5044-restrict-durable-consumers]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-security-checklist]]
