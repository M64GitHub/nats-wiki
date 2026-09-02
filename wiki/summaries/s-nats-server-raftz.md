---
title: "nats-server v2.14.6 — /raftz, read and run"
type: summary
area: [monitoring, topology, jetstream]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/raftz-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/monitor.go (Raftz, RaftzGroup, RaftzGroupPeer, HandleRaftz and the sibling handlers' query names), server/store.go (StreamState), server/raft.go (append-entry batching) at v2.14.6, plus the endpoint called on the four-node cluster of jetstream-cluster-observed-v2.14.6.md"
date: 2026-09-01
version: "2.14.6"
tags: [raftz, monitoring, raft, overrun, catching_up, quorum_needed, wal, peers, acc, query-parameters, docs-issue]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# nats-server v2.14.6 — `/raftz`, read and run

The field set the docs promise and do not print ([[s-docs-monitor-raftz]]), taken from
`monitor.go` at v2.14.6 and then observed on a live meta group and a stream group. Also the sweep
that fell out of it: which query-parameter names the HTTP monitoring handlers actually read.

## Key claims

### The response: one object per Raft group, keyed by account then group name

`RaftzStatus` is `account → group → RaftzGroup` (`monitor.go:4232`). `RaftzGroup`
(`4195–4223`), every field:

| field | meaning |
|---|---|
| `id` | this server's peer id in the group |
| `state` | `LEADER`, `FOLLOWER`, `CANDIDATE`, `OBSERVER`, `CLOSED` |
| `size`, `quorum_needed` | configured peer count and `size/2 + 1` |
| `observer`, `paused` | this node cannot campaign / has paused applies (omitted when false) |
| `overrun`, `overrun_count` | **the 2.14 overrun protection**: quorum paused or the leader overrun, and how often (omitted when zero) |
| `committed`, `applied` | the commit index and what this node has applied |
| `catching_up` | a catch-up from the leader is in progress (omitted when false) |
| `leader`, `leader_since` | the leader's peer id; `leader_since` only on the leader |
| `ever_had_leader` | whether this node ever saw a leader — the cold-boot signal |
| `term`, `voted_for`, `pterm`, `pindex` | current term, this node's vote in it (omitted if none), and the previous term/index |
| `system_account`, `traffic_account` | whether the group's traffic runs on the system account, and which |
| `ipq_proposal_len`, `ipq_entry_len`, `ipq_resp_len`, `ipq_apply_len` | the four internal queues — the apply queue backing up is a node that cannot keep up |
| `wal` | a `StreamState` of the Raft log: `messages`, `bytes`, `first_seq`, `first_ts`, `last_seq`, `last_ts`, `consumer_count` (plus `num_subjects`, `num_deleted`, `lost` when non-zero; `store.go`) |
| `wal_error` | the last write error, if any |
| `peers` | `id → {name, known, last_replicated_index, last_seen}` (`4225–4230`) |

**Observed** on the `_meta_` group: a follower prints `last_seen` for the leader only and no
`last_replicated_index`; the leader prints both for every peer (`last_replicated_index: 84`). A
compacted log reads `messages: 0, first_seq: 85, last_seq: 84`.

### The HTTP parameters are `acc` and `group`, and the account defaults to the system account

`HandleRaftz` (`4234–4254`) reads `r.URL.Query().Get("acc")` and `Get("group")`; `Raftz`
(`4256–4268`) substitutes the **system account** when `acc` is empty. Consequences, all observed:
a bare `/raftz` lists only `$SYS` → `_meta_`; a stream's group needs `?acc=<account>`; `?group=<g>`
alone returns `{}` because the group is not in `$SYS`; and **`?account=`, the name the docs print, is
ignored**. The docs' names are the JSON tags of `RaftzOptions` (`3021–3024`), which the
`nats server request raft --account --group` system request does use.

### The sibling sweep: six reference pages print the payload names, not the query names

Every `Handle<Z>` in `monitor.go` was read for the names it decodes and compared with the request
schema of `reference/system/monitor/<z>.md`:

| page | docs print | handler reads |
|---|---|---|
| `accountz` | `account` | `acc` |
| `jsz` | `account`, `consumer`, `direct_consumer`, `leader_only`, `stream_leader_only` | `acc`, `consumers`, `direct-consumers`, `leader-only`, `stream-leader-only` |
| `leafz` | `account`, `subscriptions` | `acc`, `subs` |
| `subsz` | `account`, `subscriptions` | `acc`, `subs` |
| `gatewayz` | `account_name`, `name`, `subscriptions`, `subscriptions_detail` | `acc_name`, `gw_name`, `accs` |
| `raftz` | `account` | `acc` |

`connz` and `healthz` print the HTTP names and match. Observed: `/accountz?account=NOPE` returns the
normal page, `/accountz?acc=NOPE` answers `400 Account NOPE does not exist`. Docs issue **#48**.

### The parameters the docs promise are constants

Append entries are batched at **256 KB or 512 entries** (`raft.go:3250–3251`); heartbeat, election
and lost-quorum timing and every compaction threshold are in [[s-nats-server-jetstream-cluster]].
None is exposed by `/raftz` and none has a config key.

## Practical takeaways

- `curl -s 'http://n1:8222/raftz?acc=ORDERS_ACCOUNT&group=S-R3F-…' | jq` for one stream's group;
  `/raftz` alone for the meta group.
- Watch `overrun`, `catching_up` and `ipq_apply_len`; `term` climbing is the flap counter
  ([[stream-leader-keeps-moving]]).
- Use the underscore names only in `nats server request …` payloads and CLI flags, never in URLs.

## Relevance to the wiki

Settles [[raft-in-nats]]'s last *To verify* item and corrects the parameter lists on
[[monitoring-endpoints]]; gives [[meta-layer]] and [[stream-leader-keeps-moving]] a per-group view.

## Questions it answers

- **Q36** and **Q37** gain the endpoint that shows a group's term, leader and overrun state directly.

## Pages touched

[[raft-in-nats]] · [[monitoring-endpoints]] · [[meta-layer]] · [[stream-leader-keeps-moving]]
