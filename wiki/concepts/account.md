---
title: Account
type: concept
area: [security, jetstream, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [account, multitenancy, "$G", "$SYS", system_account, no_auth_user, 10039, isolation]
aliases: [account, accounts, tenant, multitenancy, "$G", "$SYS", system account, global account]
sources: [s-docs-accounts-and-multitenancy, s-docs-cross-account, s-docs-operator-mode, s-gh-4535-unauthenticated-connections, s-nats-server-auth-and-tls, s-docs-mqtt-auth-and-clustering, s-docs-mqtt-topics-and-subjects, s-docs-mqtt-your-first-mqtt-client, s-docs-auth-callout, s-docs-authentication-basics, s-docs-authorization, s-docs-config-and-jwt-backup, s-docs-config-management, s-docs-decentralized-auth, s-docs-encryption-and-tls, s-docs-forming-a-cluster, s-docs-hardening, s-docs-leaf-nodes, s-docs-putting-it-together, s-docs-security-checklist, s-gh-5044-restrict-durable-consumers, s-gh-5606-cross-account-jetstream, s-gh-5941-restrict-leafnode-subjects, s-gh-7017-kv-across-accounts, s-gh-7505-auth-callout-nkey, s-gh-7834-leafnode-same-js-domain, s-gh-7854-jwt-push-timeout, s-issue-4281-insufficient-storage, s-nats-server-leafnode-js-domains, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-nats-server-system-subjects, s-nats-server-system-subjects-observed, s-nats-server-stream-topology-observed]
created: 2026-08-31
updated: 2026-09-04
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
| **`$G`** | the global account. "Every connection on a server with no `accounts` block lands in `$G`" (sources: [[s-docs-accounts-and-multitenancy]], [[s-docs-authentication-basics]]). The flat subject space a default server appears to have *is* one account. **Reserved** — declaring your own `$G` is a config error. |
| **`$SYS`** | the system account, where the server publishes its own events on `$SYS.SERVER.>`. You may declare it yourself, or rename it with the top-level `system_account` directive. |

**Subscribing to `$SYS.SERVER.>` from an ordinary account is accepted and receives nothing.** The
subjects are not blocked — they live in another account's subject space, and the responders exist
only there. This is the single most misleading behaviour on this page: no error, no denial, no
messages.

**The account is half of every identity the server prints.** A client shows up in the log as
`<account>/user:<name>`, so an authorization failure names the account it was judged in:

```
[ERR] 127.0.0.1:57456 - cid:6 - "v1.51.0:go:NATS CLI Version v0.4.0" - "$G/user:order-svc" - Publish Violation - Subject "billing.charge"
```

Reading the `$G` in that line is often the whole diagnosis (source: [[s-docs-authorization]]).

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

**The system account is the one account that may not have it.** Putting `jetstream: enabled` on the
account named by `system_account` stops the server dead:

```
[FTL] Not allowed to enable JetStream on the system account
```

"The system account provides JetStream as a service to all enabled accounts. So that is correct, you
can not enable JetStream on the system account" — @derekcollison, confirmed at 2.14.6 in
`server.go:2429` (sources: [[s-gh-5606-cross-account-jetstream]], [[s-nats-server-auth-and-tls]]). A
"central admin account" that owns every tenant's streams is therefore not a shape NATS has; the
system account is a **read-only overview** of the whole system.

**Each account gets its own JetStream store.** A stream created in `$G` before the accounts existed
**does not follow a user into its new account** — it must be recreated there. Nothing warns you.

**Accounts themselves reload.** Adding an account, adding users to one, changing their permissions,
changing an account's limits and even the `jetstream` enable flag itself all take effect on a config
reload without dropping connections (source: [[s-docs-config-management]]) — which is what makes the
`no_auth_user` exception below so sharp: everything around it reloads and it does not.

An account can also carry **limits** (connections, JetStream storage — see [[jetstream-sizing]] for
how `replicas × bytes` counts against them) and **exports/imports**, the one deliberate way to let a
subject cross the boundary.

## Per-account JetStream limits

The account is the second half of every JetStream reservation, and the half `/varz` does not show.

- **`10047 insufficient storage resources available` has two possible origins** — the *server*
  (`max_file_store`) or the *account* (its `MaxStore` tier). A 2023 report on that thread ran an
  operator-mode account whose tier limits were `122 MiB` of memory and storage while the server's own
  limits were far higher; the error came from the **account** half of the same check (source:
  [[s-issue-4281-insufficient-storage]], reported against 2.9.16–2.10.24 and still open on
  2026-08-31). `nats account info` is what tells the two apart — `/varz` alone cannot, because it
  reports the server's numbers. [[jetstream-out-of-disk]] separates the three failures that all read
  as "out of storage".
- **On an untiered account an `R3` stream counts three times** against the account limit, while the
  server limit counts a single replica's worth — the asymmetry is worked through in
  [[jetstream-sizing]].
- **`max_consumers` is an account setting, and it is the only enforceable lever** — though it is
  enforced *per stream*, not per account (below). Subject permissions
  cannot tell a durable consumer from an ephemeral one, because modern clients create both on
  `$JS.API.CONSUMER.CREATE.<stream>.<name>` and the difference lives in the request body; per-account
  limits bound resource use regardless of who creates what (source:
  [[s-gh-5044-restrict-durable-consumers]], and [[subject-permissions]] for why the subject-level
  lever fails).

### `max_consumers` is enforced per stream, not per account

The one correction to the bullet above, and it changes what the limit is worth as a tenancy control.
An account with `max_consumers: 2` held **four** consumers on 2.14.6 — two on `S1` and two more on
`S2` — because the server compares the limit against `mset.numLimitableConsumers()` for **the one
stream** (`consumer.go:1130–1137`; clustered, `jetstream_cluster.go:9587–9605`). `nats account info`
renders it correctly, *"Consumers: Maximum 2 per stream"*; the documentation states only "the maximum
number of consumers allowed", in the same shape as `max_streams`, which **is** per account. Recorded
as docs issue **#124** (source: [[s-nats-server-stream-topology-observed]], runs D2 and D11).

So an account's real consumer ceiling is `max_streams × max_consumers`, and the two limits are
indistinguishable from the error — a per-stream refusal and an account refusal both return
**`10026 maximum consumers limit reached`**. The other two, for comparison:

| limit | what the tenant sees |
|---|---|
| account `max_streams` | `10027 maximum number of streams reached` on `$JS.API.STREAM.CREATE` |
| account `max_file` | `10002 resource limits exceeded for account`, returned as the **`PubAck`** of the publish that would cross it |

Two behaviours worth knowing when a tenant reports being stuck: the storage check **reserves the
record** rather than filling to the byte (the account stopped 22 bytes short of its 64 MiB), and the
budget comes back **immediately** — a `purge` freed storage and the next publish was accepted, and
deleting a stream freed a `max_streams` slot at once. A mirror's and a source's internal consumers do
**not** count against `max_consumers` ([[mirrors-and-sources]]).


## What crosses the boundary, and what cannot

**There is no cross-account user.** A connection is bound to exactly one account for its whole life,
so a tool that administers several accounts holds one credential per account: "Each account is a
separate tenant, with fully isolated subject context etc. You cannot use one user to manage multiple
streams" (source: [[s-gh-5606-cross-account-jetstream]]). Two shapes get across anyway:

- **control plane** — the owning account exports `$JS.API.>` as a **service**, the other account
  imports it under a prefix, and the client is told to use that prefix;
- **data plane** — mirror or source the stream into the second account with an `external` block
  ([[mirrors-and-sources]]).

Both are all-or-nothing over the exported subject space unless the export itself is narrowed, which
is why "share a KV bucket with another account, *with restrictions*" has no clean public answer, and
why read access and write access are not symmetric (source: [[s-gh-7017-kv-across-accounts]]).
[[cross-account-sharing]] carries both shapes with their limits named.

**Import and export permissions are a property of the account, not of a user** (source:
[[s-docs-authorization]]), and no shared subject name ever bridges two accounts: "Never rely on a
shared subject name to bridge accounts; use an explicit export/import" (source:
[[s-docs-security-checklist]]).

**What an account does *not* scope is TLS.** The three TLS blocks are per kind of peer — the
top-level `tls {}` for clients, `cluster { tls {} }` for routes, `gateway { tls {} }` for supercluster
links — and encryption at rest is "global, not per account, and independent" of them (sources:
[[s-docs-hardening]], [[s-docs-encryption-and-tls]]). An account isolates subjects and JetStream
storage; it does not give a tenant its own certificate or its own key.

## Limits and failure modes

- **Across an account boundary a request fails as `No responders are available`** — not as a
  permission error:

  ```
  14:20:18 Sending request on "orders.shipped"
  14:20:18 No responders are available
  ```

  "When a request that 'should' work reports no responders, check which account each side is in."
  This is the diagnostic to remember; it looks like an application bug and is a topology fact.

- **The server can create a `no_auth_user` you never wrote.** When the only declared account is the
  system account, and there is no top-level `authorization` block, `nats-server` fabricates a user in
  `$G` and points `no_auth_user` at it — while still advertising `auth_required: true`. This is the
  most common cause of "I added authentication and anonymous clients still connect"; the four exact
  conditions and the fix are in [[unauthenticated-clients-still-connect]].

- **`no_auth_user` can silently reopen what you just closed.** It admits unauthenticated clients as
  the named user, in that user's account — point it at a user in `$G` and every anonymous client is
  back in the global account. The checklist rule is to "Point `no_auth_user` at a deliberately narrow
  user, never a wide-open account" (source: [[s-docs-security-checklist]]). Three operational traps come with it:
  - it **cannot be introduced or changed by config reload**: the reload fails with
    `config reload not supported for NoAuthUser` and the **old config stays active**, so plan a
    restart;
  - **`nats-server -t` does not catch** a `no_auth_user` naming a user that does not exist — "that
    error only appears at startup";
  - the server **rejects it alongside a trusted operator**, so it never applies in operator mode.

- **A `$SYS` account with no user makes server events unreachable.** The server creates `$SYS`
  whether or not you declare it, but with no user in it you cannot connect there — `nats server
  account info` and every event tool stop working. Declare a `SYS` account with a user and name it
  with `system_account` (source: [[s-docs-security-checklist]]). The docs' own cluster chapter is the
  counter-example: its configs never set one up, so every `nats server` command against them fails
  until you add the account and connect with its credentials (source: [[s-docs-forming-a-cluster]]).

- **Some topologies refuse to start without one.** A server that defines both `leafnodes {}` and
  `gateway {}` and no `system_account` does not boot:

  ```
  nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
  ```

  The check is `validateLeafNodeOptions` (`leafnode.go:346–349`), reproduced on 2.14.6 — and
  `nats-server -c n1-east.conf -t` reports the same file **valid** first, so a config test does not
  catch it (source: [[s-docs-putting-it-together]]; recorded as `inbox/docs-issues.md` #24).

- **`nats server report leafnodes` has an `Account` column, and it is the isolation audit** rather
  than a label: a leaf that reads `$G` "lands in the default global account, and there's no boundary
  here". `Spoke` is a property of the vantage point, not of the link — it reads `true` only on the
  leaf's own report (source: [[s-docs-putting-it-together]]).

- **A restricted user sees no `Account:` line at all** in `nats account info`. The CLI asks the
  server over **`$SYS.REQ.USER.INFO`**, and a narrow publish allow-list blocks that request. The
  empty field is a permissions symptom, not a server fault.

## Why an operator cares

- **Adding accounts to a running server is a data-migration event, not a config tweak.** JetStream
  state does not follow users across the boundary, `no_auth_user` needs a restart, and existing
  clients must all be re-pointed at named users.
- **It is the multi-tenancy unit**, so per-tenant limits, per-tenant JetStream quotas and per-tenant
  monitoring all hang off it. `$SYS.ACCOUNT.<ACCOUNT>.SERVER.CONNS` advisories (and the older `$SYS.SERVER.ACCOUNT.<ACCOUNT>.CONNS`, both every 30 s while the account has a connection; [[system-subjects]]) report connections
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

## The two configuration models

This page describes accounts as **config blocks**. The same concept has a second form: in
[[operator-mode]] an account is a **signed JWT**, created with `nats auth account add`, delivered to
the server's resolver with `nats auth account push`, and carrying its users' permissions, its limits
and its imports and exports inside the token. The runtime model is identical — an authenticated user,
scoped to an account, bound by [[subject-permissions]] — and everything on this page about isolation,
`$G`, `$SYS` and per-account JetStream holds in both.

Three differences bite operationally:

- **`no_auth_user` does not exist in operator mode**; the server rejects it alongside a trusted
  operator.
- **Nothing takes effect until the account is pushed**, and no error tells you that you forgot. The
  push is an ordinary NATS request on **`$SYS.REQ.CLAIMS.UPDATE`**, made over the *client* port by a
  temporary user allowed exactly `$SYS.REQ.CLAIMS.LIST`, `$SYS.REQ.CLAIMS.UPDATE`,
  `$SYS.REQ.CLAIMS.DELETE` and subscribe `_INBOX.>`. When nothing is subscribed there it just times
  out —

  ```
  [ERR ] failed to get response to push account: nats: timeout
  ```

  — with **no line in the server log at all**, because from the server's side nothing went wrong. The
  candidates, in order: the server is not in operator mode, no `system_account` is set, the resolver
  is not `type: full`, or the push went to the wrong port (source: [[s-gh-7854-jwt-push-timeout]]).
- **More lives in the account JWT than the account's own settings.** User revocations are a
  `revocations` map inside it and an account's signing keys are listed in it, so revoking a user or
  adding a scoped key is an account change that needs a push like any other; a scoped key is
  invisible until then (source: [[s-docs-decentralized-auth]]). With `nats auth`, the `SYSTEM`
  account is pre-created but **its user is not** — add one before the first push (source:
  [[s-gh-7854-jwt-push-timeout]]).
- **Account names are a flat namespace across operators.** Multiple operators are supported and "are
  equivalent, and the namespace of accounts is flat across all operators", while rotating operators
  has "no current affordances in the tooling" (source: [[s-docs-decentralized-auth]]).
- **The account JWTs exist in two copies**, the `nsc` / `nats auth` store on a workstation and the
  server's resolver directory, and only `resolver_preload` of the system account bootstraps the rest;
  backing that pair up correctly is [[backup-and-restore-identity]]'s subject (source:
  [[s-docs-config-and-jwt-backup]]).
- **Config mode validates imports at startup and operator mode does not** — see
  [[cross-account-sharing]].

## The account is what a leafnode binds to

A leafnode's `account` field — `leafnodes { remotes: [ { …, account: ORDERS } ] }` on the leaf, and
`leafnodes { authorization { users: [ { …, account: ORDERS } ] } }` on the hub — "selects which local
account on the leaf the bridged interest joins", and pointing both ends at the same account is what
makes the factory floor and the cloud share one isolated subject space (source:
[[s-docs-leaf-nodes]]). So isolation across a leaf is an **account** decision, not a leafnode one:
"a leaf in the default account is as open as a client", and once bound, only the subjects that
account imports and exports cross the link.

In **config mode** that account binding is the only boundary you actually have.
`deny_imports` / `deny_exports` on the remote are deny-only and are merged with the hub's, and
`permissions` is a **parse error** inside `leafnodes { authorization { users } }` —
`parseLeafUsers` (`opts.go:3005–3064`) accepts exactly `user`, `pass`, `account` and
`proxy_required`. In [[operator-mode]] the leaf's permissions travel in its user JWT instead and do
reach the connection (source: [[s-gh-5941-restrict-leafnode-subjects]]).

**Extending JetStream over a leafnode is an account question before it is a domain question.** The
server extends only when the connection is on the **system account** *and* both ends carry an
identical `jetstream { domain }`; every other combination merges a deny of the JetStream API in both
directions, and identical domains on any *other* account make the server deny JetStream on that
connection outright. A remote bound to a tenant account — `account: SENTINEL`, in the thread that
found this — was never a candidate for extension, however the domains were set (sources:
[[s-nats-server-leafnode-js-domains]] at 2.14.6, `leafnode.go:1951`;
[[s-gh-7834-leafnode-same-js-domain]]). The domain itself is installed as a subject mapping into
**every non-system account** (`leafnode.go:2114–2121`), which is why `$JS.<domain>.API.>` works from
an ordinary account and the system account is the exception.
[[streams-not-visible-across-a-leafnode]] is the symptom page.

## Where auth callout puts a client

[[auth-callout]] delegates account placement to an external service, and three of its rules are
account rules (source: [[s-docs-auth-callout]]):

- the callout's own `account` field "names which account `auth-svc` runs in and where
  `$SYS.REQ.USER.AUTH` is protected", **defaulting to `$G`**. On that account, publishing to
  `$SYS.REQ.USER.AUTH` is denied for every user — including `auth-svc` itself — so ADR-26 recommends
  giving the callout an account of its own;
- **the account a client is placed into must already exist in the config.** The inner user JWT's
  audience is the target account's name, and that audience is what places the client;
- **`allowed_accounts` (2.11+)** limits the delegation to the config-defined accounts you list, so a
  server can be migrated one account at a time. The exception is the one that catches people: a
  connection matching no config user lands in `$G`, and those connections always go to the callout.

What the server validates *before* the callout runs is nothing: every field of `connect_opts`,
`nkey` included, is an unverified client claim, and treating it as an identity is a spoofing bug —
that material is on [[auth-callout]] (source: [[s-gh-7505-auth-callout-nkey]]).

## An account is also the JetStream boundary for MQTT

Two account-level facts that only show up when [[mqtt]] is enabled (sources:
[[s-docs-mqtt-your-first-mqtt-client]], [[s-docs-mqtt-auth-and-clustering]],
[[s-docs-mqtt-topics-and-subjects]]):

- **The JetStream requirement is per account, not just per server.** A standalone server without a
  `jetstream {}` block refuses to start with `mqtt requires JetStream to be enabled if running in
  standalone mode` — but an MQTT user whose *account* has no JetStream is refused **at connect time**,
  on a server that started fine.
- **MQTT permissions are account permissions on converted subjects.** A device's topic becomes a NATS
  subject before authorization runs, so the account's `publish`/`subscribe` rules are written in NATS
  notation — `sensors.>`, never `sensors/#` ([[subject-permissions]]).

`allowed_connection_types` on a user narrows which transports its credential works on
(`STANDARD`, `WEBSOCKET`, `LEAFNODE`, `LEAFNODE_WS`, `MQTT`, `MQTT_WS`, `IN_PROCESS`); omitted, every
type is allowed. The `mqtt {}` block can also carry its own `authorization {}` and `no_auth_user`
scoped to that listener, which is how a fleet whose firmware cannot send credentials is mapped onto
one account user — though a listener-scoped username or token cannot be combined with a top-level
`users` list, and `no_auth_user` does not work in [[operator-mode]].

## Version notes: the 2.10 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch accounts from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- `$SYS.REQ.USER.INFO` is since 2.10.0 (#3671); `no_auth_user` may name an nkey user since 2.10.8
  (#4938); several `trusted_operators` in one config file since 2.10.21 (#5896) (source:
  [[s-relnotes-2.10]]).
- The authorization bypass of 2.10.0 and 2.10.1 — an `accounts` block ignoring top-level
  `authorization` users — is fixed in **2.10.2** (#4605); see [[nats-server-2.10]].
- 2.10.17: import/export cycle detection (#5494); imports available to a client after a server
  restart (#5588, #5589). 2.10.19: connection types in scoped signing keys honoured (#5789). 2.10.28:
  reducing an account's max connections no longer closes internal clients, "fixing cases where
  JetStream assets could become unavailable" (#6785); internal JetStream clients survive an expired
  claim update (#6817).


### The 2.11 line

- **2.11.0**: scoped users may have "templates that are not limited to a subject token" (#5981);
  the publish-permissions cache is pruned more than once so it stays under its size (#6674)
  (source: [[s-relnotes-2.11]]).
- **`default_sentinel`** — "a default sentinel JWT, which is used in operator mode when none is
  specified … making it possible to have default users" (2.11.2, #6577); it must be a bearer token
  (2.11.7, #7074) or come from a scoped signing key (2.11.9, #7217). See [[operator-mode]].
- **2.11.9**: an account JWT update with a lower connection limit disconnects the **newest** clients
  rather than the oldest (#7181, #7185); lowering the limit no longer makes streams lose interest
  (#7258). **2.11.12**: a JetStream subscription leak when an import/export overlaps `$JS.>` (#7720).
- **2.11.15**: **a 1 MB size limit on JWTs** (#7960); CVE-2026-33249, "systems where client publish
  permissions should be restricted". **2.11.16**: **`no_auth_user` applies to client connections
  only**; overlapping wildcard `deny` patterns enforced; queue subscriptions can no longer bypass a
  non-queue `deny`. **2.11.17**: JWT validity times that cross midnight validated correctly;
  repeated `CONNECT` messages clear subscriptions; `/connz` no longer discloses bearer JWTs.


### The 2.12 line

- **2.12.0**: a leafnode connection without auth "no longer unexpectedly connect[s] to the global
  account" (#7116); connection-related log lines carry the account and user (#7079) (source:
  [[s-relnotes-2.12]]).
- **2.12.12**: inherited JWT default permissions refreshed when account claims are updated (#8276);
  external auth configuration cleared on a claims update (#8275); `NoAuthUser` checks connection
  restrictions. **2.12.14**: "combining `no_auth_user` with auth callouts will no longer skip
  authentication checks when no `CONNECT` message is sent"; JWT validation no longer crashes on
  whitespace-only permissions; `healthz` skips expired JWT accounts (#8379).


## To verify

- Per-account **limits**: the JetStream tier fields (`MaxStore`, `MaxMemory`, `max_consumers`) are
  now stated above from [[s-issue-4281-insufficient-storage]] and
  [[s-gh-5044-restrict-durable-consumers]], but the **connection-side** limits are still only named,
  not enumerated; the field list is in `raw/nats-docs/reference/config/accounts/limits/` and is
  already indexed in `inbox/config-keys-table.md`.
- Whether there is any **ceiling on the number of imports** one account may hold. Asked directly on
  the thread — "For a large multitenant system, is there a theoretical maximum number of imports for
  a single account? I'm imagining importing thousands of tenants…" — and never answered (source:
  [[s-gh-5606-cross-account-jetstream]]).
- Whether **`nats account backup` / `nats account restore`** is the supported way to move JetStream
  assets between accounts. A maintainer says so in [[s-gh-4535-unauthenticated-connections]] and the
  commands exist at natscli v0.4.0 ([[s-natscli-account-tls]]); no docs page describes the use.

### The 2.14 line

**2.14.3**: inherited JWT default permissions are refreshed when account claims are updated (#8276);
external auth config cleared on a claims update (#8275); `NoAuthUser` checks connection restrictions;
`/accstatz` no longer omits accounts with only leaf connections (2.14.2, #8252) (source:
[[s-relnotes-2.14]]). **2.14.4**: `healthz` skips expired JWT accounts (#8379); JWT validation no
longer crashes the server on whitespace-only permissions; a resolver whose parent directory is
missing no longer panics at startup (2.14.3, #8329). **2.14.6**: consumer tiers distinguished when
enforcing account limits (#8484).


## What the system account answers, and what an ordinary account may ask

Every `$SYS` subject — the fifteen `$SYS.REQ.SERVER.PING.<Z>` requests (three of them, `STATSZ`,
`IDZ` and `PROFILEZ`, with no HTTP form), the per-account `$SYS.REQ.ACCOUNT.<acc>.<Z>` requests, the
claims and auth-callout subjects, and the events with their heartbeats — is tabled on
[[system-subjects]], read from `events.go` at v2.14.6. The boundary for an **ordinary** account is
two built-in imports: `$SYS.REQ.ACCOUNT.PING.CONNZ` and `.STATZ`, which the system account exports and
map onto the asking account's own `$SYS.REQ.ACCOUNT.<acc>.<Z>` (`events.go:2385–2387`), plus
`$SYS.REQ.USER.INFO`; anything else — `$SYS.REQ.SERVER.PING.VARZ`, another account's `CONNZ` — gets
`No responders are available`, whatever the user's permissions say (observed on 2.14.6; source:
[[s-nats-server-system-subjects]], [[s-nats-server-system-subjects-observed]]).


## Related

[[nats-server]] · [[stream]] · [[error-codes]] · [[config-keys]] · [[monitoring-endpoints]] ·
[[advisories]] · [[nsc]] · [[nk]] · [[nats-cli]] · [[jetstream-sizing]] · [[js-api]] ·
[[rotate-tls-certificates]] · [[subject-permissions]] · [[operator-mode]] ·
[[cross-account-sharing]] · [[auth-callout]] · [[tls-in-nats]] ·
[[unauthenticated-clients-still-connect]] · [[leafnode]] · [[choosing-a-topology]] ·
[[mirrors-and-sources]] · [[jetstream-out-of-disk]] · [[streams-not-visible-across-a-leafnode]] ·
[[backup-and-restore-identity]] · [[consumer]]

## Sources

[[s-docs-accounts-and-multitenancy]] · [[s-docs-cross-account]] · [[s-docs-operator-mode]] ·
[[s-gh-4535-unauthenticated-connections]] · [[s-nats-server-auth-and-tls]] ·
[[s-docs-mqtt-auth-and-clustering]] · [[s-docs-mqtt-topics-and-subjects]] ·
[[s-docs-mqtt-your-first-mqtt-client]] · [[s-docs-auth-callout]] ·
[[s-docs-authentication-basics]] · [[s-docs-authorization]] · [[s-docs-config-and-jwt-backup]] ·
[[s-docs-config-management]] · [[s-docs-decentralized-auth]] · [[s-docs-encryption-and-tls]] ·
[[s-docs-forming-a-cluster]] · [[s-docs-hardening]] · [[s-docs-leaf-nodes]] ·
[[s-docs-putting-it-together]] · [[s-docs-security-checklist]] ·
[[s-gh-5044-restrict-durable-consumers]] · [[s-gh-5606-cross-account-jetstream]] ·
[[s-gh-5941-restrict-leafnode-subjects]] · [[s-gh-7017-kv-across-accounts]] ·
[[s-gh-7505-auth-callout-nkey]] · [[s-gh-7834-leafnode-same-js-domain]] ·
[[s-gh-7854-jwt-push-timeout]] · [[s-issue-4281-insufficient-storage]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-nats-server-system-subjects]] · [[s-nats-server-system-subjects-observed]] · [[s-nats-server-stream-topology-observed]]
