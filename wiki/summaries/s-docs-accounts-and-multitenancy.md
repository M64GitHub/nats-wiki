---
title: "docs.nats.io — Accounts and multitenancy"
type: summary
area: [security, jetstream, core]
source-url: https://docs.nats.io/learn/security/accounts-and-multitenancy.md
source-path: raw/nats-docs/learn/security/accounts-and-multitenancy.md
author: NATS documentation (Synadia Communications, Inc.)
article: Accounts and multitenancy
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [account, multitenancy, "$G", "$SYS", system_account, no_auth_user, 10039, jetstream-per-account]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Accounts and multitenancy

What an account actually is, the two the server always has, and the four ways a two-account config
goes wrong in production. The source page for the most-linked concept this wiki was missing.

## Key claims

**An account is an isolated subject space, and the boundary is absolute.**

> "Two accounts on the same server never see each other's traffic … The subject `orders.shipped` in
> `ORDERS` and a subject `orders.shipped` in another account are **two different subjects that happen
> to share the same user-visible name**."

The page contrasts it with permissions: "Permissions narrow what one user may do inside its account.
An account boundary is absolute: **the message doesn't cross it**."

**Every server already runs two accounts.**

- **`$G`** — the global account. "Every connection on a server with no `accounts` block lands in
  `$G` … The single flat subject space you started with is one account named `$G`." **`$G` is a
  reserved name** — declaring your own is a config error.
- **`$SYS`** — the system account, where the server publishes its own events on `$SYS.SERVER.>`.
  "Those subjects aren't blocked for other accounts — they live in the system account's subject
  space, so a subscription to them from an ordinary account is accepted and **never receives
  anything**." You may declare `$SYS` yourself, or rename it with the top-level **`system_account`**
  directive.

**A user lives in exactly one account, and the username selects it.** "Because the username is what
selects the account, it must be **unique across all accounts** — a duplicate is a startup error:
`Duplicate user "order-svc" detected`."

**JetStream becomes opt-in per account.** "On a server that runs JetStream, declaring an `accounts`
block makes JetStream opt-in per account: an account without the field gets **`JetStream not enabled
for account (10039)`** on every JetStream call." And: "**Each account gets its own JetStream store** —
a stream created back in `$G` before the accounts existed doesn't follow `order-svc` into `ORDERS`."

```
accounts {
  ORDERS: {
    jetstream: enabled
    users: [ { user: order-svc, password: s3cr3t, permissions: { … } } ]
  }
  ANALYTICS: {
    users: [ { user: analytics-reader, password: an4lytics } ]
  }
}
```

**Declaring tenant accounts closes the door — with one caveat.** "Because the config defines tenant
accounts, connections no longer land in `$G` by default … an unauthenticated connect is rejected."
But: "the lockdown comes from the **tenant** accounts, not from the `accounts` block itself. A config
whose only account is the system account still admits unauthenticated clients into `$G`."

**Across an account boundary a request fails as `No responders`, not as a permission error.**

```
14:20:18 Sending request on "orders.shipped"
14:20:18 No responders are available
```

"The only subscriber on that name lives in `ANALYTICS`, so inside `ORDERS` the subject has no
responders. **When a request that 'should' work reports no responders, check which account each side
is in.**"

**Accounts also carry limits and exports/imports**: connection counts, JetStream storage, and the
export/import pair that is "the one deliberate way to let a subject cross the boundary".

**Three pitfalls, stated as such:**

1. **`no_auth_user` can reopen access you intended to close.** It "admits unauthenticated clients as
   the named user, placing them in that user's account. Point it at a user in `$G` and every
   anonymous client lands in the global account again." Three operational traps: it **cannot be
   introduced or changed by config reload** — "the reload fails with `config reload not supported for
   NoAuthUser` and the old config stays active, so plan a restart"; **`nats-server -t` does not catch
   a `no_auth_user` naming a missing user** ("that error only appears at startup"); and the server
   **rejects it together with a trusted operator**, "so it never applies in operator mode".
2. **The system account has no user, so server events are unreachable.** "Define your own `accounts`
   block and the server still creates `$SYS`, but with no user inside it you can't connect there …
   `nats server account info` and event tooling stop working." Fix: declare a `SYS` account with a
   user and set `system_account: SYS`.
3. **A shared subject name doesn't mean shared delivery.**

**Verification commands and their output:**

```
nats account info --user analytics-reader --password an4lytics
nats server account info SYS --user sys-admin --password syspass
nats subscribe '$SYS.SERVER.>' --user sys-admin --password syspass
```

```
                      User: analytics-reader
                   Account: ANALYTICS (ANALYTICS)
            System Account: false
```

A system-account user reports `System Account: true` and sees live advisories such as
**`$SYS.SERVER.ACCOUNT.ANALYTICS.CONNS`**. A detail worth keeping: running `nats account info` as a
restricted user "prints an info block with **no `Account:` line at all** — the CLI asks the server for
it over **`$SYS.REQ.USER.INFO`**, and `order-svc`'s publish allow list blocks that request."

## Practical takeaways

- **"No responders" is the account-boundary symptom.** It is the single most useful diagnostic on
  this page, because it looks like an application bug and is a topology fact.
- **An empty `Account:` line in `nats account info` is a permissions symptom**, not a server problem —
  the client cannot publish to `$SYS.REQ.USER.INFO`.
- **Enabling accounts strands existing JetStream state.** Streams created in `$G` do not migrate, and
  nothing warns you; this is the kind of change that must be planned, not applied.
- **`no_auth_user` needs a restart, and `-t` will not save you.** Two independent reasons a
  security-relevant change cannot be rolled out the way other config changes are.

## Notable quotes

> "An account boundary is absolute: the message doesn't cross it."

> "When a request that 'should' work reports no responders, check which account each side is in."

## Relevance to the wiki

The whole of [[account]], the most-cited page this wiki did not have; groundwork for the
cross-account and operator-mode work in step 4 of the current plan.

## Questions it answers

Groundwork for Q51 (sharing a stream between accounts) and Q54 (adding accounts on a live cluster);
neither closes without the cross-account and config-reload pages.

## Pages touched

[[account]] · [[error-codes]] · [[config-keys]] · [[monitoring-endpoints]] · [[advisories]] ·
[[nats-cli]] · [[stream]]
