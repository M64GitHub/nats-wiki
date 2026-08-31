---
title: "docs.nats.io — Config management"
type: summary
area: [deploy, security, core]
source-url: https://docs.nats.io/learn/deployment/config-management.md
source-path: raw/nats-docs/learn/deployment/config-management.md
author: NATS documentation (Synadia Communications, Inc.)
article: Config management
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [reload, SIGHUP, include, dry-run, reloader, configmap, variables, tls-rotation]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Config management

Change a running server's configuration without dropping a connection: `include` files, a dry-run,
a SIGHUP, and the line between what a reload can and cannot change. The prose source for the
reload/restart split that `inbox/config-keys-table.md` only tabulates.

## Key claims

**`include` paths are relative to the including file, not the working directory.**

```
include "tls.conf"
include "regions/us.conf"
```

> "the path is **relative to the directory of the config file that contains it**, not to the
> directory you launch the server from … Launch the server from `/root` or from `/`, and it still
> resolves the same way."

**An unquoted `$NAME` is a variable; a quoted one is a literal.**

```
{ user: "order-svc", password: $ORDER_SVC_PASS }
```

> "an unquoted `$NAME` token resolves a config-defined variable and then an environment variable, and
> an unset one is **a parse error the dry-run catches**. Quoting it (`"$ORDER_SVC_PASS"`) would store
> the literal string … which is why **bcrypt hashes, full of `$`, are the values you do quote**."

**The reload/restart line, stated as a principle:**

> "A reload can change *policy* (who connects, what they may do, how much they may store), but it
> can't change *identity* (the addresses the server and its cluster bind, or where JetStream keeps
> its data)."

**Reloadable**, per this page: accounts, users and permissions; `max_connections`, `max_payload`,
`max_control_line` — **"Not `max_subscriptions` — a reload rejects a change to it"**; most JetStream
account limits **and the `jetstream` enable flag itself** ("a reload turns JetStream on or off"); TLS
certificate and key paths; cluster routes and logging. **"Gateway routes are not reloadable; a reload
can only refresh their TLS material."**

**Non-reloadable**: `port` / `listen`; the cluster's listen host and port; the JetStream `store_dir`.

**The reload is atomic, and validation happens twice.**

> "NATS validates the new config first, and on a parse or validation failure **the old config stays
> active**. The reload is atomic: either the new config applies cleanly, or nothing changes."

```
nats-server -c /etc/nats/nats.conf -t
```

A clean config "prints `nats-server: configuration file ... is valid` and exits zero", a broken one
prints the parse error and the offending line and exits non-zero. **What `-t` does not check:** "a
JetStream cluster missing `server_name` or `routes` passes `-t` yet still fails to boot".

The gate to use in a script:

```
nats-server -c /etc/nats/nats.conf -t && systemctl reload nats-server
```

The server "re-reads its config, applies the reloadable changes in place, and logs
`Reloaded server configuration`. Open connections … stay up the whole time, and no client
reconnects."

**On Kubernetes the reloader sidecar sends the SIGHUP.** It "watches the mounted config file with
inotify, and on any change reads the server PID from `/var/run/nats/nats.pid` and sends it a
SIGHUP", shipped enabled (`reloader: { enabled: true }`, confirmed at chart release nats-2.14.6 —
[[s-nats-helm-chart-values-2.14.6]]). "The reloader retries if the server is briefly unreachable
(**30 retries by default, four seconds apart**)"; where inotify is unavailable, add `--force-poll`
through `reloader.merge`, "which replaces the container's args wholesale".

**Secrets are mounted files, and that is what makes rotation a reload:** the config names a path,
the file behind it changes, `systemctl reload` re-reads it, "new handshakes present the new
certificate while open connections keep their session. The config text never changes."

**Four pitfalls:**

1. **Include paths** — as above.
2. **"A reload during a rebalance can interrupt a leadership transfer."** "Don't reload
   mid-rebalance. Wait for the cluster to settle."
3. **"Lowering a store limit on reload does not evict data already stored."** "the existing messages
   stay, but **new writes fail** until an admin trims the stream back under the limit. The reload
   changes the *ceiling*, not the *contents*."
4. **"Rotating a TLS certificate late fails every new handshake."** Connections already open keep
   their session regardless of the old cert's expiry; "once it's expired the server presents a dead
   cert, and every new connection and every client reconnect fails its TLS handshake".

> "The do-this for all four is the same: never SIGHUP an unvalidated config."

## Practical takeaways

- **Policy versus identity is the rule to remember**, and it predicts the table: anything that
  changes what the server *is* on the network needs a restart, therefore a rolling upgrade.
- **The dry-run's blind spot is startup, not syntax.** `-t` proves the file parses; it does not prove
  a JetStream cluster can boot from it.
- **A failed reload is safe, and that is a deliberate design property** — the worst case is that
  nothing changed. It is still worth gating on `-t` so the failure lands in your terminal.
- **`max_subscriptions` is the exception inside a group of reloadable limits**, which is exactly the
  shape of thing an operator gets wrong once.
- **Lowering a JetStream limit is a foot-gun with a delayed trigger**: nothing fails at reload time;
  the next write fails.

## Notable quotes

> "A reload can change *policy* … but it can't change *identity*."

> "Never SIGHUP an unvalidated config."

## Relevance to the wiki

The whole of [[reload-server-config]], the reload half of [[config-keys]], and the mechanism the
wanted [[rotate-tls-certificates]] runbook will build on.

## Questions it answers

**Q54** (add an account and reload without dropping clients) and **Q55** (which changes reload and
which need a restart), together with `inbox/config-keys-table.md`.

## Pages touched

[[reload-server-config]] · [[config-keys]] · [[account]] · [[nats-helm-charts]] ·
[[install-nats-server]] · [[upgrade-a-cluster]]
