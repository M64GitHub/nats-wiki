---
title: "gh#5941 — Proper way to configure leaf nodes to only export some subjects"
type: summary
area: [topology, security]
source-url: https://github.com/nats-io/nats-server/discussions/5941
source-path: raw/gh-discussions/gh-5941.md
author: "@humphd (asker), @derekcollison (answer), @Hitesh-Agrawal (unanswered follow-up)"
article: "GitHub Discussion 5941, nats-io/nats-server, Q&A"
date: 2024-09-28
version: ""
tags: [leafnode, deny_exports, deny_imports, permissions, subject-permissions, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5941 — deny lists, and an accepted answer that does not work in config mode

Opened 2024-09-28, answered the same day by **@derekcollison** (a NATS maintainer). Then, three
months later, a second user posts a complete config showing the answer having no effect — and that
comment has never been replied to. Both halves matter.

## Key claims

### The question

> "I only want to send a subset of messages (e.g., define a single pattern to sync, ignore the rest)
> going to the leaf node instances back to the global nats. In the docs I see mention of
> `deny_exports` and `deny_imports`, but I can't really find any examples of people using this how I
> intend. **My goal would be to do something where I default to exclude everything, then add an
> exception for one pattern.** Is this possible?"

That goal is **not expressible** with those two keys: both become `Deny` lists and neither has an
`allow` counterpart (`leafnode.go:473–481`, source: [[s-nats-server-topology]]).

### The accepted answer

> "Soliciting leafnodes should provide authentication information for when they connect to the hub.
> Just put permissions on that user from the hub side the restricts what that user (the one that was
> used to form the leafnode connection) can and can not do."
> — @derekcollison, 2024-09-28

The asker: "fantastic, this is working for me."

### The follow-up that was never answered

@Hitesh-Agrawal, 2024-12-18, posts the whole thing: a hub with

```
leafnodes {
  listen: 0.0.0.0:7422
  authorization { user: "leafuser", password: "test" }
}
authorization {
  users = [
    { user: default_user, permissions: { publish: ">", subscribe: ">" } }
    { user: leafuser, password: "test",
      permissions: { publish: { deny: ">" }, subscribe: { allow: ">" } } }
  ]
}
no_auth_user: default_user
```

publishes from the leaf and sees the message on the hub anyway:

> "Shouldn't this be denied on the hub with a config of `publish: { deny: ">" }`?"

**It should not, and this wiki reproduced it** on nats-server v2.14.5 (source:
[[s-nats-server-topology]]). Two facts explain it:

1. The `leafuser` entry in the **global** `authorization.users` block governs *client* connections.
   A leafnode connection authenticates against `leafnodes.authorization`, which is a different block.
2. A `leafnodes.authorization` user cannot carry permissions at all. `parseLeafUsers`
   (`opts.go:3005–3064`) is "a trimmed down version of parseUsers" accepting exactly `user`,
   `pass`, `account` and `proxy_required`. Adding `permissions` there is a **parse error**:
   `unknown field "permissions"`.

So in **config mode** the maintainer's answer has no implementation. It is correct in **operator
mode**, where the leaf presents a `.creds` file and the permissions travel in the user JWT — those do
reach the connection, are reversed on the hub side, and are pushed back to the leaf for local
enforcement (`leafnode.go:2307–2318`, `2423–2424`).

## Practical takeaways

- **`deny_exports` = publish deny, `deny_imports` = subscribe deny**, on the leaf's own remote. Deny
  only. "Deny everything, allow one subject" needs a different mechanism.
- In **config mode**, the boundary you actually have is the **account**: bind the leaf remote to an
  account (`leafnodes.remotes[].account`) and the hub-side leaf user to the matching account
  (`leafnodes.authorization.users[].account`), then let that account's imports and exports decide
  what crosses.
- In **operator mode**, put the permissions in the leaf user's JWT and the accepted answer works as
  written.
- The two ends **compose**: the hub's permissions arrive in the INFO and the leaf's local
  `deny_imports` / `deny_exports` are merged on top, so restricting at one end does not stop you
  restricting at the other.

## Relevance to the wiki

The demand and the correction behind the *What configures it* and *Limits and failure modes*
sections of [[leafnode]]. A rare case where a maintainer answer needs a version- and mode-qualifier
before this wiki repeats it.

## Questions it answers

- **Q48** — how to restrict which subjects a leafnode exports and imports, and why the obvious answer
  silently does nothing in config mode.

## Pages touched

[[leafnode]] · [[subject-permissions]] · [[account]] · [[operator-mode]] · [[cross-account-sharing]] ·
[[config-keys]]
