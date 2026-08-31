---
title: Account
type: concept
area: [security, jetstream, core]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [account, multitenancy, "$G", "$SYS", system_account, no_auth_user, 10039, isolation]
aliases: [account, accounts, tenant, multitenancy, "$G", "$SYS", system account, global account]
sources: [s-docs-accounts-and-multitenancy]
created: 2026-08-31
updated: 2026-08-31
---

# Account

**An isolated tenant with its own subject space.** Two accounts on the same server never see each
other's traffic: `orders.shipped` in one account and `orders.shipped` in another "are two different
subjects that happen to share the same user-visible name" (source:
[[s-docs-accounts-and-multitenancy]]).

The account is the strongest boundary NATS has, and the unit almost everything else is scoped to —
JetStream storage, limits, imports and exports, and the `$SYS` events an operator reads.

## How it behaves

**The boundary is absolute, and it is not a permission.** Permissions narrow what one user may do
*inside* its account; an account boundary means "the message doesn't cross it". No allow-list edit
opens it — only an explicit export/import pair does.

**Every server already runs two accounts**, whether you declare any or not:

| account | what it is |
|---|---|
| **`$G`** | the global account. "Every connection on a server with no `accounts` block lands in `$G`." The flat subject space a default server appears to have *is* one account. **Reserved** — declaring your own `$G` is a config error. |
| **`$SYS`** | the system account, where the server publishes its own events on `$SYS.SERVER.>`. You may declare it yourself, or rename it with the top-level `system_account` directive. |

**Subscribing to `$SYS.SERVER.>` from an ordinary account is accepted and receives nothing.** The
subjects are not blocked — they live in another account's subject space, and the responders exist
only there. This is the single most misleading behaviour on this page: no error, no denial, no
messages.

**A user lives in exactly one account, and the username selects it.** So usernames must be unique
across *all* accounts; a duplicate is a startup error:

```
Duplicate user "order-svc" detected
```

**Declaring tenant accounts closes the open door** — connections no longer land in `$G` and an
unauthenticated connect is rejected. But the lockdown comes from the *tenant* accounts, not from the
`accounts` block: "a config whose only account is the system account still admits unauthenticated
clients into `$G`."

## What configures it

```
accounts {
  ORDERS: {
    jetstream: enabled
    users: [ { user: order-svc, password: s3cr3t, permissions: { publish: { allow: ["orders.>"] } } } ]
  }
  ANALYTICS: {
    users: [ { user: analytics-reader, password: an4lytics } ]
  }
  SYS: {
    users: [ { user: sys-admin, password: syspass } ]
  }
}
system_account: SYS
```

The `accounts` block **takes over from the top-level `authorization` block** — move the users into
their accounts and delete the old block, because "users left there stay in `$G`".

**JetStream becomes opt-in per account.** Without `jetstream: enabled`, every JetStream call from
that account fails with:

```
JetStream not enabled for account (10039)
```

**Each account gets its own JetStream store.** A stream created in `$G` before the accounts existed
**does not follow a user into its new account** — it must be recreated there. Nothing warns you.

An account can also carry **limits** (connections, JetStream storage — see [[jetstream-sizing]] for
how `replicas × bytes` counts against them) and **exports/imports**, the one deliberate way to let a
subject cross the boundary.

## Limits and failure modes

- **Across an account boundary a request fails as `No responders are available`** — not as a
  permission error:

  ```
  14:20:18 Sending request on "orders.shipped"
  14:20:18 No responders are available
  ```

  "When a request that 'should' work reports no responders, check which account each side is in."
  This is the diagnostic to remember; it looks like an application bug and is a topology fact.

- **`no_auth_user` can silently reopen what you just closed.** It admits unauthenticated clients as
  the named user, in that user's account — point it at a user in `$G` and every anonymous client is
  back in the global account. Three operational traps come with it:
  - it **cannot be introduced or changed by config reload**: the reload fails with
    `config reload not supported for NoAuthUser` and the **old config stays active**, so plan a
    restart;
  - **`nats-server -t` does not catch** a `no_auth_user` naming a user that does not exist — "that
    error only appears at startup";
  - the server **rejects it alongside a trusted operator**, so it never applies in operator mode.

- **A `$SYS` account with no user makes server events unreachable.** The server creates `$SYS`
  whether or not you declare it, but with no user in it you cannot connect there — `nats server
  account info` and every event tool stop working. Declare a `SYS` account with a user and name it
  with `system_account`.

- **A restricted user sees no `Account:` line at all** in `nats account info`. The CLI asks the
  server over **`$SYS.REQ.USER.INFO`**, and a narrow publish allow-list blocks that request. The
  empty field is a permissions symptom, not a server fault.

## Why an operator cares

- **Adding accounts to a running server is a data-migration event, not a config tweak.** JetStream
  state does not follow users across the boundary, `no_auth_user` needs a restart, and existing
  clients must all be re-pointed at named users.
- **It is the multi-tenancy unit**, so per-tenant limits, per-tenant JetStream quotas and per-tenant
  monitoring all hang off it. `$SYS.SERVER.ACCOUNT.<ACCOUNT>.CONNS` advisories report connections
  per account.
- **Verify the boundary, don't assume it.** The docs' own check is two clients on the same subject
  string in different accounts; the message does not arrive.

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

## To verify

- **Cross-account exports and imports** — the deliberate way to share one subject, and the answer to
  question-bank Q51 — are covered by `learn/security/cross-account.md`, which is **local but not yet
  ingested** (step 4 of the current plan).
- **Operator mode / JWT accounts** (`nsc`, `nats auth`, account push and resolvers) are a different
  configuration model for the same concept; `learn/security/operator-mode.md` and
  `decentralized-auth.md` are local and unread. This page describes accounts in **config mode** only.
- Per-account **limits** are named but not enumerated by the source read here; the field list is in
  `raw/nats-docs/reference/config/accounts/limits/` and is already indexed in
  `inbox/config-keys-table.md`.

## Related

[[nats-server]] · [[stream]] · [[error-codes]] · [[config-keys]] · [[monitoring-endpoints]] ·
[[advisories]] · [[nsc]] · [[nk]] · [[nats-cli]] · [[jetstream-sizing]] · [[js-api]] ·
[[rotate-tls-certificates]]

## Sources

[[s-docs-accounts-and-multitenancy]]
