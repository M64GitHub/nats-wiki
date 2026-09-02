---
title: "docs.nats.io — Reference → /raftz"
type: summary
area: [monitoring, topology, jetstream]
source-url: https://docs.nats.io/reference/system/monitor/raftz.md
source-path: raw/nats-docs/reference/system/monitor/raftz.md
author: NATS documentation (Synadia Communications, Inc.)
article: Raftz
date: 2026-08-31          # the page is undated; this is the fetch date (re-fetched live 2026-09-01)
version: "2.14"
tags: [raftz, monitoring, reference, generated, docs-issue]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs.nats.io — Reference → /raftz

The reference page three learn chapters send you to for "the full set of RAFT internals". It is 173
bytes long. This summary records what it says, what it does not, and what those chapters promise on
its behalf — the finding behind docs issue **#47**.

## Key claims

The whole page, re-fetched from the live site on 2026-09-01 and identical to the mirror:

- `## Request Schema` — "Request options for raftz monitoring endpoint": `account` (string),
  `group` (string).
- `## Response Schema` — "Response from raftz monitoring endpoint". **No fields.**

That is all. No parameter is explained, no response field is named, no default is stated.

## What the learn chapters say it contains

- `learn/clustering/raft-and-leaders.md` line 52: "The full set of RAFT internals it exposes is
  documented in Reference → /raftz: log compaction, the `$NRG.*` subjects peers vote over, snapshot
  timing." Line 162: "the RAFT group monitoring endpoint and its full field set."
- `learn/clustering/replication-and-r3.md` line 257: "You'll find the full set of RAFT replication
  parameters (append-entry batching, heartbeat intervals, log compaction) in Reference."

None of those five things is on the page, and four of them are not endpoint fields at all: the
heartbeat interval, election window, append-entry batch size and compaction thresholds are constants
in `raft.go` and `jetstream_cluster.go` that no endpoint reports and no key sets
([[s-nats-server-jetstream-cluster]], [[s-nats-server-raftz]]).

## The parameter name is the system request's, not the endpoint's

`account` is the JSON tag of `RaftzOptions`, the payload of the `$SYS.REQ.SERVER.PING.RAFTZ` system
request that `nats server request raft --account` sends. The HTTP handler reads **`acc`**;
`/raftz?account=X` is silently ignored. The same pattern holds on five sibling pages — docs issue
**#48** ([[s-nats-server-raftz]]).

## Practical takeaways

- Do not look for RAFT tuning parameters in the reference; there are none to find, on the page or in
  the server ([[raft-in-nats]]).
- Use `/raftz?acc=<account>&group=<group>` over HTTP, or `nats server request raft --account
  --group` on the system account; the field set is on [[monitoring-endpoints]].

## Relevance to the wiki

Closes the last *To verify* item on [[raft-in-nats]] — by establishing that the promised
documentation does not exist, and replacing it with the server's own structs.

## Questions it answers

- None directly; it removes a false lead from **Q36**'s and **Q37**'s pages.

## Pages touched

[[raft-in-nats]] · [[monitoring-endpoints]]
