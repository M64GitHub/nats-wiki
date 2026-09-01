---
title: Subject permissions
type: concept
area: [security, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [permissions, allow, deny, default_permissions, allow_responses, queue-group, _INBOX, "$JS.API"]
aliases: [permissions, authorization, allow list, deny list, publish permissions, subscribe permissions, default_permissions, allow_responses]
sources: [s-docs-authorization, s-docs-authentication-basics, s-gh-5044-restrict-durable-consumers, s-nats-server-auth-and-tls, s-docs-security-checklist, s-docs-kv-under-the-hood, s-docs-object-store-under-the-hood, s-docs-mqtt-topics-and-subjects, s-docs-mqtt-auth-and-clustering, s-docs-websocket-browsers-and-origins, s-nats-server-mqtt-websocket-observed, s-docs-auth-callout, s-docs-cross-account, s-docs-decentralized-auth, s-gh-4535-unauthenticated-connections, s-gh-5941-restrict-leafnode-subjects, s-gh-7505-auth-callout-nkey, s-adr-51-message-scheduler]
created: 2026-08-31
updated: 2026-09-01
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
same two rules either way" (source: [[s-docs-authorization]]).

**A scoped key changes where permissions live, and that has three operational consequences**
(source: [[s-docs-decentralized-auth]]):

```
nats auth account keys add ORDERS order-writer --pub-allow 'orders.>' --sub-allow '_INBOX.>'
```

- **Editing the template re-permissions every user signed by that key** on the next account push,
  with no credentials re-issued. That is the point of it, and it is also how a careless edit changes
  more than one service at once.
- **A scoped key is invisible until the account is pushed** — before the push, creds minted against
  it simply fail.
- **Removing a scoped key is mass revocation, not an edit.** "The CLI has no command to edit a scope
  in place, so the only way to change one is to remove its key… That creates a new key, and every
  user signed by the old one is locked out at the next push."

The alternative is the account's identity key, and the reason to avoid it is a permission argument:
"whoever holds the account's seed can issue a user with any permissions".

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
- **An import that renames must be permitted under its *local* name.** An import may land on a
  different subject with `prefix:` or `to:`, and the rule is to "subscribe to the name the import
  lands on, not the name the exporter published" — so the subscribing user's `allow` list must carry
  the local name too. Import and export themselves are **account** properties, not user ones: no
  permission edit opens a boundary, and none closes one (sources: [[s-docs-cross-account]],
  [[s-docs-authorization]]; [[cross-account-sharing]]).
- **A user with no `permissions` block can do anything, and that is how servers get left open.** The
  question was asked directly on gh#4535 — "What are a user's permissions when no `permissions` block
  is defined for the user and no `defaultPermissions` block is defined, either?" — and went
  unanswered there; the docs settle it as unrestricted. The community's pre-fix lock-down for
  anonymous clients was to point `no_auth_user` at a user denied everything:

  ```
  { user: no_auth_user, password: foobar,
    permissions: { publish: { deny: ["*"] }, subscribe: { deny: ["*"] } } }
  ```

  Note `*`, not `>`: that denies one token only. `>` is the form that denies everything (sources:
  [[s-gh-4535-unauthenticated-connections]], [[s-docs-authorization]];
  [[unauthenticated-clients-still-connect]]).
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

## A KV bucket needs an ACL, not just `deny_delete`

A [[key-value]] bucket is created with `deny_delete: true`, which blocks the JetStream message-delete
API so nothing removes entries behind the KV API's back. **It does not stop a publish.** A raw
`nats pub` to `$KV.<bucket>.<key>` lands a bare message with none of the headers the KV API sets — no
expected-revision header, no `KV-Operation`, no `Nats-Rollup` — so "a watcher can't tell it from a
real put and a purge you meant never happens" (source: [[s-docs-kv-under-the-hood]]).

The only thing that actually prevents it is a permission. Deny publish on the bucket's subject space
to everything except the KV clients:

```
publish: { deny: ["$KV.>"] }
```

The same reasoning applies to `$O.>` for an [[object-store]] bucket, and there it is sharper, because
an object bucket has **two subject spaces with different sensitivities** (source:
[[s-docs-object-store-under-the-hood]]):

| subject space | holds | who needs it |
|---|---|---|
| `$O.<bucket>.C.>` | the chunk messages — the object bytes | only clients that put and get objects |
| `$O.<bucket>.M.>` | one `ObjectInfo` per object — names, sizes, digests | anything that lists or watches |

A reader that only needs to know *what* is in a bucket — a watcher, a dashboard — needs `.M.>` and
**not** `.C.>`, because the object-store watch carries metadata and never the bytes. That is a real
least-privilege split, not a theoretical one, and it is only available because the two spaces are
separate subjects. The docs are explicit that this is an ordinary subject problem: "securing these
subjects… is a security concern, not an object-store one."

One caveat before writing that ACL: a **list** is not just a read of `.M.>`. It creates and deletes an
ephemeral consumer, so it also needs `$JS.API.CONSUMER.CREATE.OBJ_<bucket>.>` and the matching
`DELETE` ([[js-api-subjects]]). A grant of the metadata subject alone lets a client *watch* but not
*list*.

This is a case where the protective-looking stream setting and the protection an operator needs are
two different mechanisms.

## Two places the permission model changes shape

**On a leafnode, config mode has no user permissions at all.** A leafnode connection authenticates
against `leafnodes { authorization }`, which is a *different* block from the top-level one, and
`parseLeafUsers` (`opts.go:3005–3064`) is "a trimmed down version of parseUsers" accepting exactly
`user`, `pass`, `account` and `proxy_required`. Adding `permissions` there is a **parse error**:
`unknown field "permissions"`. What you have instead is:

- **`deny_exports` and `deny_imports` on the leaf's own remote** — `deny_exports` is a publish deny,
  `deny_imports` is a subscribe deny. **Deny only**: "deny everything, allow one subject" is not
  expressible;
- **the account the leaf is bound to**, whose imports and exports then decide what crosses — the real
  boundary in config mode ([[account]]).

In **[[operator-mode]]** the model comes back: the leaf presents a `.creds` file, the permissions
travel in the user JWT, and they do reach the connection — reversed on the hub side and pushed back
to the leaf for local enforcement (`leafnode.go:2307–2318`, `2423–2424`). The two ends **compose**:
the hub's permissions arrive in the INFO and the leaf's local `deny_imports` / `deny_exports` are
merged on top, so restricting at one end does not stop you restricting at the other (source:
[[s-gh-5941-restrict-leafnode-subjects]]; [[leafnode]]).

**With [[auth-callout]], the permissions are minted per connection by a service you write.** The
callout returns a user JWT carrying the lists, so the two rules above still hold — they are just
decided at connect time rather than in a config file. Two permission facts belong here:

- **The server denies publishing to `$SYS.REQ.USER.AUTH` for every user on the callout's account**,
  including `auth-svc` itself, which is why ADR-26 recommends giving the callout an account of its
  own — "with nothing else in that account, no other user can" reach the subject
  (source: [[s-docs-auth-callout]]).
- **Nothing the client sent is verified before your service runs.** Every field of `connect_opts` —
  `nkey` included — is an unverified claim, so issuing permissions based on one is a spoofing bug:
  "you evaluate on what you got from the client, if you don't like it you reject". The detail, and
  the nonce a service can verify for itself, is on [[auth-callout]] (source:
  [[s-gh-7505-auth-callout-nkey]]).

## Interop: the transport is part of the permission

Two things here are easy to get wrong because the rule is written against something other than what
the client sent.

**[[mqtt]] permissions are checked on the converted subject, never the topic.** The server converts
first, then checks. A rule written `sensors/#` matches nothing; the rule is `sensors.>`. And because
an MQTT filter ending in `#` makes the server create **two** NATS subscriptions — `sensors.>` and the
parent `sensors` — both must be granted, or the whole filter is refused with `0x80` in the SUBACK and
the subscription already created is torn down (source: [[s-docs-mqtt-topics-and-subjects]]):

```
subscribe: ["sensors.>", "sensors"]
```

**Leave `$MQTT.sub.>` out of the lists entirely.** From 2.12.3 an MQTT connection is implicitly
allowed to subscribe to `$MQTT.sub.` and `$MQTT.deliver.pubrel.`; before that it had to be allowed
explicitly. But **deny is still enforced**, so a restrictive rule that denies everything under
`$MQTT.` breaks QoS 1 and 2 while QoS 0 keeps working — a fleet that looks half-broken (source:
[[s-docs-mqtt-auth-and-clustering]]).

**`allowed_connection_types` binds a credential to a transport**, which is the cheapest way to stop a
dashboard or device credential also working from a shell on 4222. The full set is `STANDARD`,
`WEBSOCKET`, `LEAFNODE`, `LEAFNODE_WS`, `MQTT`, `MQTT_WS`, `IN_PROCESS`; omitting it allows **every**
type, which is the default. The `_WS` variants are separate values, so a browser-based MQTT client
needs `MQTT_WS` and a leaf dialling in over WebSocket needs `LEAFNODE_WS` — using `LEAFNODE` refuses
it. Aliases: `connection_types`, `clients`.

**And a warning about the one control that looks like a permission and is not.** `allowed_origins` on
a [[websocket]] listener is checked **only when an `Origin` header is present**, so it constrains
browsers and nothing else. Confirmed on 2.14.6: a handshake with no `Origin` gets
`101 Switching Protocols` from an origin-restricted listener, and the `nats` CLI publishes straight
through one (sources: [[s-docs-websocket-browsers-and-origins]],
[[s-nats-server-mqtt-websocket-observed]]). Permissions are what protect the port.

## A stream setting can undo a permission decision

Subject permissions are not the only thing that governs what a client can do to a stream, and one
stream field changes two others behind you: **enabling `allow_msg_schedules` also enables
`allow_rollup_hdrs` and clears `deny_purge`** (source: [[s-adr-51-message-scheduler]], confirmed on
v2.14.6 — [[message-scheduling]]).

That matters here because both of those are controls someone may have set deliberately:

- **`allow_rollup_hdrs`** lets a publisher send `Nats-Rollup: sub` — deleting every earlier message on
  a subject — or `Nats-Rollup: all`, deleting the whole stream's contents. A publish permission on
  `orders.>` becomes considerably more powerful once rollups are allowed.
- **`deny_purge`** blocks `$JS.API.STREAM.PURGE.<stream>` regardless of who is asking; clearing it
  re-opens that path to anyone whose permissions reach the JetStream API.

Neither change is announced, and **`allow_msg_schedules` cannot be turned off again**, so the stream
does not go back. When reviewing what an account may do to a stream, read the stream's stored config
rather than the config that was submitted:

```
nats stream info ORDERS --json | jq '.config | {allow_msg_schedules, allow_rollup_hdrs, deny_purge}'
```


## Related

[[account]] · [[operator-mode]] · [[auth-callout]] · [[tls-in-nats]] · [[cross-account-sharing]] ·
[[js-api-subjects]] · [[unauthenticated-clients-still-connect]] · [[config-keys]] · [[nats-cli]] ·
[[leafnode]] · [[consumer]]

## Sources

[[s-docs-authorization]] · [[s-docs-authentication-basics]] · [[s-gh-5044-restrict-durable-consumers]] ·
[[s-nats-server-auth-and-tls]] · [[s-docs-security-checklist]] · [[s-docs-kv-under-the-hood]] ·
[[s-docs-object-store-under-the-hood]] ·
[[s-docs-mqtt-topics-and-subjects]] · [[s-docs-mqtt-auth-and-clustering]] ·
[[s-docs-websocket-browsers-and-origins]] · [[s-nats-server-mqtt-websocket-observed]] ·
[[s-docs-auth-callout]] · [[s-docs-cross-account]] · [[s-docs-decentralized-auth]] ·
[[s-gh-4535-unauthenticated-connections]] · [[s-gh-5941-restrict-leafnode-subjects]] ·
[[s-gh-7505-auth-callout-nkey]] · [[s-adr-51-message-scheduler]]
