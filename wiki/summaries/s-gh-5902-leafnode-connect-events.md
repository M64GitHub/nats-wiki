---
title: "gh#5902 — Subscribe to LEAFNODE.CONNECT and LEAFNODE.DISCONNECT events"
type: summary
area: [monitoring, topology]
source-url: https://github.com/nats-io/nats-server/discussions/5902
source-path: raw/gh-discussions/gh-5902.md
author: "@ZarkoRunjevac (asker), @derekcollison (chosen answer)"
date: 2024-09-18
version: "2.10.20"        # the asker's hub; the maintainer's example is 2.10.21-RC.1
tags: [system-account, leafnode, connect-events, gateways]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# gh#5902 — `LEAFNODE.CONNECT` events that never arrive

A hub with one leaf, `nats sub '$SYS.>'` as the system user: `$SYS.ACCOUNT.*.CONNECT` arrives,
`$SYS.ACCOUNT.*.LEAFNODE.>` never does. The maintainer shows both working on Synadia Cloud
("Verified with Synadia Cloud"), suggests a call to triage, and the thread ends with "I am wondering
if this is only presenting as an issue when the hub is a single server vs a cluster or more advanced
system?" — unanswered since 2024-09-30. A nats.net discussion (#604) reports the same.

## Key claims

- Maintainer: from the system account, `$SYS.ACCOUNT.*.CONNECT` "will show all connections of all
  types for all accounts. The third token is the account"; "If you want only the leafnodes …
  `$SYS.ACCOUNT.*.LEAFNODE.>`". His `LEAFNODE.CONNECT` example body is a bare `{"server": {…},
  "acc": …}` from a server with `"cluster":"ngsprod-aws-uswest2"` and `"domain":"ngs"`.
- Asker (server 2.10.20, docker-compose hub + leaf, `system_account: SYS`): `/leafz` shows the leaf,
  the debug log shows the connection, `nats events` lists only the `CONNECT`, `DISCONNECT` and
  `CLIENT.AUTH.ERR` subjects, and a `sub '>'` on the system account sees only
  `$SYS.SERVER.ACCOUNT.*.CONNS` and `$SYS.SERVER.*.STATSZ`.

## What the server says

- `sendLeafNodeConnect` (`events.go:2416–2421`, v2.14.6) returns before sending unless
  **`s.gateway.enabled`** — "If we are not in operator mode, or do not have any gateways defined,
  this should also be a no-op" — and the subject constant is marked "for internal use only"
  (`:71`): its purpose is to switch a gateway account to interest-only mode, not to notify
  operators. Synadia Cloud runs gateways; a single hub or a plain cluster does not. **There is no
  `LEAFNODE.DISCONNECT` subject in the server at all.**
- Reproduced on 2.14.6 ([[s-nats-server-system-subjects-observed]] §3): a leaf dialling a standalone
  hub produced `$SYS.ACCOUNT.<acc>.CONNECT` with `"kind":"Leafnode"` and the remote's `server_name`
  as `name`, plus a `CONNS` update with `"leafnodes":1`, and **no** `LEAFNODE.CONNECT`.

## Practical takeaways

- Watch `$SYS.ACCOUNT.*.CONNECT` / `.DISCONNECT` and filter on `"kind":"Leafnode"`; or poll
  `$SYS.REQ.SERVER.PING.LEAFZ`; or watch the `leafnodes` count in `$SYS.ACCOUNT.*.SERVER.CONNS`.
  `LEAFNODE.CONNECT` is a gateway-only internal signal with no disconnect twin.

## Notable quotes

- "I am wondering if this is only presenting as an issue when the hub is a single server vs a
  cluster or more advanced system?" — the maintainer's last word.

## Relevance to the wiki

The public form of row 162; the difference the thread never found is on [[system-subjects]] and
[[leafnode]].

## Questions it answers

Row 162.

## Pages touched

[[system-subjects]] · [[leafnode]]
