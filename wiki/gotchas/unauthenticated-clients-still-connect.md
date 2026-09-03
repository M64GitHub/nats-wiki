---
title: Unauthenticated clients still connect
type: gotcha
area: [security]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: ["$G", "$SYS", no_auth_user, accounts, auth_required, sysAccOnlyNoAuthUser, 2.10.2]
aliases: [anonymous connections, no credentials required, unauthenticated access, "$G open", auth_required true but anyone connects]
sources: [s-gh-4535-unauthenticated-connections, s-nats-server-auth-and-tls, s-docs-accounts-and-multitenancy, s-docs-authentication-basics, s-natscli-account-tls, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Unauthenticated clients still connect

## Symptom

You added authentication — a system account, or a user list, or both — and a client with **no
credentials at all** still connects and can publish and subscribe:

```
nats pub orders.created 'x'
```

```
14:22:34 Published 1 bytes to "orders.created"
```

There is no error, no warning at startup, and nothing in the log. Worse, the server's `INFO` line may
say `auth_required: true` while this is happening, so a client library that checks the flag believes
authentication is in force.

The reporter's own summary: "I can also connect with no user/pass. If I comment out the `accounts`
block, unauthenticated connections fail, as expected" (source:
[[s-gh-4535-unauthenticated-connections]]).

## Quick triage

```
nats server info                                     # any credentials at all?
nats account info                                    # which account did you land in?
curl -s http://127.0.0.1:8222/varz | jq '{auth_required, system_account}'
```

If `nats account info` reports **`$G`** for a connection you gave no credentials to, you have this
problem. Then look at the config and answer one question: **is there any declared account other than
the system account?**

## Causes

### 1 · Your only declared account is the system account (by far the most common)

The server fabricates a user in `$G` and points `no_auth_user` at it. From `server.go:1445–1462` at
v2.14.6:

```go
if len(opts.TrustedOperators) == 0 && numAccounts == 2 && opts.NoAuthUser == _EMPTY_ && !opts.authBlockDefined {
	…
	uname = fmt.Sprintf("nats-%s", b[:])
	opts.Users = append(opts.Users, &User{Username: uname, Password: uname[6:], Account: s.gacc})
	opts.NoAuthUser = uname
}
```

All four conditions must hold: **not operator mode**, **exactly two accounts** (the system account and
`$G`), **`no_auth_user` unset**, and **no top-level `authorization` block**. The fabricated user has a
random name and lives in the global account, so every anonymous client lands in `$G` with no
permissions block — which means unrestricted, per [[subject-permissions]].

**How to confirm.** Connect with no credentials and run `nats account info`; the account is `$G`. The
config has an `accounts` block containing only `$SYS` (or a renamed system account) and no top-level
`authorization`.

**The fix.** Declare any second account — it may be completely empty:

```
accounts {
  SYS: {
    users: [ { user: sys, password: sys } ]
  }
  APP: {}          # any non-system account closes $G
}

system_account: SYS
```

"When a non-system account is defined, the default `$G` account is no longer in effect and since
`APP` does not define any users, no non-sys authenticated clients will work" — @bruth, the marked
answer in gh#4535. In server terms, `numAccounts` is no longer 2 and the branch does not fire.

Adding a top-level `authorization` block works too, for the same reason, but declaring the real tenant
account is the change you wanted anyway.

### 2 · `no_auth_user` is set, deliberately or inherited

`no_auth_user` "admits unauthenticated clients as the named user, in that user's account". Point it at
a wide-open user and every anonymous client inherits that user's reach ([[account]]).

**How to confirm.** `grep no_auth_user` in the config *and* every `include`; then
`nats account info` with no credentials — it names the account the user lives in.

**The fix.** Remove it, or point it at a deliberately narrow user. Two traps come with the removal:

- **it cannot be introduced or changed by config reload** — the reload fails with
  `config reload not supported for NoAuthUser` and **the old config stays active**, so plan a restart;
- **`nats-server -t` does not catch** a `no_auth_user` naming a user that does not exist; that error
  appears only at startup.

Note the asymmetry with cause 1: when *you* set `no_auth_user`, the server clears `auth_required` in
its `INFO`. When the server fabricates one, it does not (`server.go:3290`) — so `auth_required: true`
plus anonymous access is the signature of cause 1 specifically.

### 3 · No `authorization` block and no accounts at all

The base case. "A server with no `authorization` block admits every connection"
(source: [[s-docs-authentication-basics]]). Not a subtlety, but it is what a `-js`-only development
config does, and development configs get promoted.

**The fix.** Give every server at least one user list, so an unauthenticated connect fails with
`nats: error: nats: Authorization Violation`.

### 4 · A pre-2.10.2 server ignoring your `authorization` block

Historic, and worth knowing if you run something old. Until the fix in
[PR #4605](https://github.com/nats-io/nats-server/pull/4605), "defining the `accounts` block appears
to outright ignore any users/creds defined in `authorization`" — @bruth, after checking with the
server team. @derekcollison: "Merged, will be in **2.10.2** release."

**How to confirm.** The boot banner's version is below 2.10.2 *and* the config has both an `accounts`
block and a top-level `authorization` block.

**The fix.** Upgrade ([[upgrade-a-cluster]]). At v2.14.6 the `!opts.authBlockDefined` condition in
cause 1 is that fix.

## Version notes

- **2.12.0**: "Leafnode connections without auth no longer unexpectedly connect to the global
  account" (#7116, "Leaf node without auth doesn't default to global account") — the leafnode form of
  this page's symptom, closed there (source: [[s-relnotes-2.12]]).
- **2.12.12**: `NoAuthUser` "now checks connection restrictions". **2.12.14** (and 2.14.4): "combining
  `no_auth_user` with auth callouts will no longer skip authentication checks when no `CONNECT`
  message is sent"; "an authentication bypass with TLS `verify_and_map` authenticating users with
  blank passwords" fixed. **2.11.16 / 2.12.7**: `no_auth_user` applies to client connections only
  ([[s-relnotes-2.11]]).


## Prevention

- **Never ship an `accounts` block whose only entry is the system account.** Declare the tenant
  account at the same time, even before it has users.
- **Test the negative case in CI.** A connect with no credentials must fail with
  `Authorization Violation`. Every cause above is invisible to a test that only checks that the *right*
  credentials work.
- **Do not trust `auth_required`.** Under cause 1 the server advertises `true` and admits anonymous
  clients anyway.
- **Treat `no_auth_user` as a deliberate feature, never as a lock-down.** Using it to deny everything
  — a user with `publish: { deny: ["*"] }` — is a documented community workaround and still means
  every anonymous client is authenticated as *somebody*. Closing `$G` is the real fix.
- **In [[operator-mode]] this cannot happen**: `no_auth_user` is rejected alongside a trusted
  operator, and the first condition of the branch excludes operator mode entirely.

## Migrating once you close the door

Clients are not the only thing that moves. **JetStream state does not follow a user into a new
account** — a stream created in `$G` must be recreated in the tenant account, and nothing warns you
([[account]]). A maintainer's route for moving the assets is
`nats account backup` then `nats account restore`, which exist at natscli v0.4.0 with `--cluster` and
`--tag` placement flags ([[s-natscli-account-tls]]); no docs page describes this use, so rehearse it
before you need it. See [[backup-and-restore-jetstream]].

## Explained by

[[account]] — the `$G` / `$SYS` model and why an account boundary is not a permission ·
[[subject-permissions]] — why a user with no permissions block is unrestricted

## Related

[[account]] · [[subject-permissions]] · [[operator-mode]] · [[tls-in-nats]] ·
[[reload-server-config]] · [[upgrade-a-cluster]] · [[backup-and-restore-jetstream]] ·
[[config-keys]] · [[nats-server-2.10]]

## Sources

[[s-gh-4535-unauthenticated-connections]] · [[s-nats-server-auth-and-tls]] ·
[[s-docs-accounts-and-multitenancy]] · [[s-docs-authentication-basics]] · [[s-natscli-account-tls]] · [[s-relnotes-2.12]]
