---
title: "gh#4535 — Issue with denying unauthenticated connections"
type: summary
area: [security]
source-url: https://github.com/nats-io/nats-server/discussions/4535
source-path: raw/gh-discussions/gh-4535.md
author: "@alexherington (asked); @bruth (answer), @derekcollison, @wallyqs, @cascadia-sati"
article: "GitHub Discussion 4535 (Q&A)"
date: 2023-09-14          # opened; answer chosen 2023-09-28
version: "2.10"          # the fix shipped in 2.10.2
tags: ["$G", "$SYS", no_auth_user, accounts, unauthenticated, nats-py]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#4535 — unauthenticated clients still connect after adding a system account

Opened 2023-09-14, **answered by a maintainer**, and the answer turned into a server bug fix. The
report is the clearest public statement of a trap that still exists in a narrower form at 2.14.6.

## Key claims

**The symptom.** With this config, `foo` (in `$SYS`) and `bar` (in `authorization`) both work — and
so does a connection with **no credentials at all**:

```
accounts {
  "$SYS" {
    users = [ {user: "foo", pass: "pass"} ]
  }
}

authorization {
  users = [ {user: "bar", password: "pass"} ]
}

jetstream {}
http = "0.0.0.0:8222"
listen = "0.0.0.0:4222"
```

"I can also connect with no user/pass. If I comment out the `accounts` block, unauthenticated
connections fail, as expected."

**The maintainer's rule** (@bruth, marked as the answer). The top-level `authorization` block "was
one of original config options (pre-multi tenancy and system account). When multi-tenancy was
introduced, this block still works and defaults to an implicit `$G` account."

> "However if you only define the system account, the default account named `$G` is still in effect
> and does not require auth. The simplest way to address is to define a new explicit account."

```
accounts {
  SYS: {
    users: [ { user: sys, password: sys } ]
  }
  APP: {}  # <- whatever name you want
}

system_account: SYS
```

> "When a non-system account is defined, the default `$G` account is no longer in effect and since
> `APP` does not define any users, no non-sys authenticated clients will work."

**And then a correction.** @bruth, same day: "After talking with the server team, there is a
correction to what I said above, we are checking whether this is a bug in that defining the
`accounts` block appears to outright ignore any users/creds defined in `authorization`."

@derekcollison confirmed it, filed
[PR #4605](https://github.com/nats-io/nats-server/pull/4605), and stated the release:
**"Merged, will be in 2.10.2 release."**

**The community workaround, before the fix** — `no_auth_user` pointed at a user denied everything:

```
no_auth_user: no_auth_user
authorization: {
  users: [
    { user: no_auth_user, password: foobar,
      permissions: { publish: { deny: ["*"] }, subscribe: { deny: ["*"] } } }
  ]
}
```

"Silly that we have to jump through this hoop, but there it is." The asker's own verdict:
"`no_auth_user` seems like it's designed to specifically add permissions to anonymous users rather
than be used to block access, as it's bypassing authentication."

**A client bug rode along.** The Python client would not send credentials when the server's `INFO`
omitted `auth_required`; fixed in **nats-py v2.4.0**, published during the thread. "The go client
seems to work fine."

**Moving JetStream assets to a new account.** Asked after the fix — "Is there a way I can migrate the
existing streams/msgs to a new account?" — @derekcollison: "`nats account backup` then `nats account
restore` should allow you to move JetStream assets from one account to another."

**Two questions in the thread nobody answered:**

- "What are a user's permissions when no `permissions` block is defined for the user and no
  `defaultPermissions` block is defined, either?" (Answered by the docs, not here: unrestricted —
  see [[s-docs-authorization]].)
- Whether the `no_auth_user` hoop was ever meant as a lock-down.

## Practical takeaways

- **Never ship a config whose only declared account is the system account.** Declare at least one
  tenant account, even an empty one.
- **The fix narrowed the trap; it did not remove it.** At v2.14.6 the server still fabricates a
  `$G` no-auth user, but only when there is *also* no top-level `authorization` block — see
  [[s-nats-server-auth-and-tls]] for the exact four conditions.
- **`$G` is where an unauthenticated connection lands**, so a permission-denied user in `$G` is a
  blunt but working shutter if a restart is not available.

## Notable quotes

> "If I comment out the `accounts` block, unauthenticated connections fail, as expected."
> — @alexherington

> "I highly recommend adding that to the documentation. 😄" — @cascadia-sati

## Relevance to the wiki

The whole of [[unauthenticated-clients-still-connect]], and the reason that page states the server's
four conditions rather than the thread's rule of thumb: the rule was written before the fix and is
now too broad.

## Questions it answers

Q56.

## Pages touched

[[unauthenticated-clients-still-connect]] · [[account]] · [[subject-permissions]] ·
[[nats-server-2.10]] · [[nats-py]] · [[config-keys]]
