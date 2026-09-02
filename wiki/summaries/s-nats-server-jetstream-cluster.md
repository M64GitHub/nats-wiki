---
title: "nats-server v2.14.6 — the JetStream meta layer"
type: summary
area: [jetstream, topology, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/jetstream-cluster-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/jetstream_cluster.go, raft.go, jetstream_api.go, monitor.go, jetstream.go, server.go, opts.go and errors.json at v2.14.6, plus a three-node cluster run on the v2.14.6 binary (raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md)"
date: 2026-09-01
version: "2.14.6"
tags: [meta-layer, meta-group, meta-leader, raft, quorum, orphan, peer-remove, election, healthz, jsz, 10008, snapshot, meta_compact, extension_hint, observer]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# nats-server v2.14.6 — the JetStream meta layer

Read to write [[meta-layer]], the internals page five pages already pointed at, and to settle the
open items on [[raft-in-nats]] and [[replicas]]. `server/jetstream_cluster.go` (11,584 lines) and
`server/raft.go` (5,574) were read for five questions rather than summarised; the quoted ranges are
in `raw/nats-server-src/jetstream-cluster-v2.14.6.md`. Then a **three-node cluster was run on the
v2.14.6 binary** with **nats CLI 0.4.0** — bootstrap, restart, a killed meta leader, two of three
killed, a standalone server joining with data, a live peer-remove — and the transcript is
`raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md`.

## Key claims

### One group, named `_meta_`, whose peers are every JetStream-enabled server

- The group is `defaultMetaGroupName = "_meta_"`, its log a filestore with **1 MB** blocks
  (`defaultMetaFSBlkSize`), at `<store_dir>/jetstream/<system account>/_js_/_meta_`
  (`jetstream_cluster.go:457–462`, `1018–1026`). Observed on disk: `peers.idx`, `tav.idx`
  (term and vote), `msgs/*.blk`, `snapshots/`, `meta.inf`, `meta.sum`. A standalone server has no
  such directory.
- **There is no replica count for it.** At first start the peer set is `s.ActivePeers()` — every
  node the server has heard of that is not offline (`server.go:1570–1579`) — and the *expected* size
  is the larger of 2 and `len(routes) + gateway URLs` (`raft.go:364–401`; observed:
  `Adjusting expected peer set size to 3 with 1 known` on a node with three routes). Quorum is
  always `csz/2 + 1` (`raft.go:1120–1121`, `1142–1143`). In mixed mode the leader trims the size
  to the JetStream-enabled count (`checkClusterSize`, `1966–2004`).
- It reaches across gateways: gateway URLs count toward the expected size, so a super-cluster is
  one meta group and every assignment needs a majority of *all* its servers.
- A solicited leafnode that shares the system account starts its meta node as an **observer**
  (`cfg.Observer = canExtendOtherDomain() && extension_hint != "no_extend"`, `1040`), which never
  campaigns (`runAsFollower` resets its timer to 48 h). `peers.idx` records whether the previous run
  extended, so the choice survives restarts (`1044–1076`). A *standalone* server refuses to extend
  unless `extension_hint: will_extend` (`jetstream.go:509–516`).

### What it stores: assignments, not messages

`cc.streams` is `ACCOUNT → STREAM → *streamAssignment` and "All servers will have this be the
same" (`jetstream_cluster.go:43–48`). A `streamAssignment` carries the requesting `Client`, `Created`,
the `Config`, the `Group` (`Name`, `Peers`, `Storage`, `Cluster`, `Preferred`, `ScaleUp`), a `Sync`
subject, and its consumers (`171–189`); a `consumerAssignment` the same plus `State` (`294–310`). The
log's meta operations are `assignStreamOp`, `assignConsumerOp`, `removeStreamOp`,
`removeConsumerOp`, `updateStreamOp` and a compressed consumer form (`121–155`); a snapshot is the
list of `writeableStreamAssignment` (`2010–2017`). Peer membership changes are Raft-level
`EntryAddPeer` / `EntryRemovePeer` entries in the same log (`2673–2735`).

### Every create, update and delete is a proposal by the meta leader

- A clustered `STREAM.CREATE` ends in `cc.meta.Propose(cc.term, encodeAddStreamAssignment(sa))`
  (`8295–8313`); the assigned peers then create the stream when the entry is applied
  (`processStreamAssignment`, `4959–5060`). The same request handled twice with an identical
  config is answered from the existing assignment; a different config gets *stream name already in
  use* (`8250–8268`).
- Every meta-handled API request runs the same gate (`jetstream_api.go:1295–1309`, `1389–1397`,
  `3156–3164`): `js.isLeaderless()` → **`10008 JetStream system temporarily unavailable`**; not the
  meta leader → **return without replying**. `isLeaderless` is true only after the node has existed
  for `lostQuorumIntervalDefault` (10 s) (`jetstream_cluster.go:1140–1156`). `STREAM.INFO` on a
  work-queue or interest stream is also answered by the meta leader (`4424–4447`).
- The meta leader alone subscribes to `$JS.API.META.LEADER.STEPDOWN`, **`$JS.API.SERVER.REMOVE`**,
  `$JS.API.ACCOUNT.STREAM.MOVE.*.*`, `$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.*.*` and
  `$JS.API.ACCOUNT.PURGE.*`, on the system account (`7508–7540`; `jetstream_api.go:187–212`).
  `apiDispatch` explicitly ignores the first two (`798–806`).

### Orphans: the record whose absence deletes a stream

"Streams and consumers are recovered from disk, and the meta layer's mappings should clean them
up, but under crash scenarios there could be orphans" (`1507–1509`). `checkForOrphans` runs
**30 s after meta recovery** (`time.AfterFunc(30*time.Second, js.checkForOrphans)`), only when a
meta leader exists and this node is `Healthy()` with it, and deletes every recovered stream with no
entry in `cc.streams` and every consumer with no entry under its stream, logging
`Detected orphaned stream '<account> > <stream>', will cleanup` (`1510–1585`). **Observed**: a
standalone server's `ORPHAN` stream was restored from disk, the server joined the cluster, and the
stream was deleted **30.0 s** later with that one warning line.

### Losing the meta leader: what still works, what blocks

- **Stream reads and writes continue** — they belong to the stream's own group. Observed: with the
  meta leader (also the stream leader) SIGKILLed, an R3 stream kept accepting publishes throughout
  its own re-election; with two of three servers killed, publishes and creates could not commit.
- **Creates, updates, deletes, consumer creates, stepdowns and peer-removes block.** During an
  election the request hits a server that is not leader and gets no reply (client timeout); once
  the node is `Leaderless` it gets `10008`.
- **A leader that loses its followers keeps claiming leadership for ~10 s, up to ~20 s**: the
  `lostQuorumCheck` ticker fires every `hbInterval * 10` = 10 s and a peer counts while heard from
  within `lostQuorumInterval` = 10 s (`raft.go:295–296`, `3231–3235`, `3345–3355`). Observed: the
  sole survivor reported `/healthz` **ok** and named itself leader for 10 s, then logged
  `JetStream cluster no metadata leader` and `… has NO quorum, stalled` for the stream.
- The log lines: `Self is new JetStream cluster metadata leader`,
  `JetStream cluster new metadata leader: <server>/<cluster>`, `JetStream cluster no metadata leader`
  (`7601–7627`). `/healthz` distinguishes five states — meta write error, meta layer not running,
  still recovering, **`JetStream has not established contact with a meta leader`** (no leader
  known), **`JetStream is not current with the meta leader`** (a leader is known but not heard from
  within `hbInterval * 2`) — and `?js-meta-only=true` stops after them (`monitor.go:3868–3907`,
  `2995–3004`). Observed: a *killed* leader produces the second message until the term changes.
- **A request that timed out is not necessarily lost.** Observed: two creates that timed out were
  applied once quorum returned because the same server re-won the election; one was discarded
  because a different server won; two publishes that returned `nats: timeout` were both stored.

### Elections and timing are constants, not configuration

`raft.go:289–310`: `minElectionTimeout` 4 s, `maxElectionTimeout` 9 s, `hbInterval` 1 s,
`lostQuorumInterval` 10 s, `lostQuorumCheck` 10 s, campaign 100–800 ms, `observerModeInterval` 48 h,
`peerRemoveTimeout` 5 min — package-level `var`s that **no config key sets** (`opts.go` parses no
key for any of them; the only meta keys are `meta_compact`, `meta_compact_size`,
`meta_compact_sync` and `extension_hint`). Observed: bootstrap elected a leader in 282 ms (early
`Campaign()`, `1081–1083`); a full-cluster restart took 5.32 s; a SIGKILLed leader was replaced in
3.47 s; a stepdown is a *transfer* to a peer heard from within `hbInterval * 3`
(`raft.go:2018–2095`) and took 0.53 s. A node cannot campaign while an observer, paused, or behind
on applies (`5512–5551`).

### Snapshots and compaction

- Meta: a 1-minute ticker, or after applying > 8 MB when 30 s have passed, forced whenever a peer
  entry is applied and on becoming leader (`1601–1628`, `1893–1912`). `meta_compact` (entries) and
  `meta_compact_size` (bytes) are thresholds read on every check, so they are reloadable; **both
  default to 0, which means snapshot on every check** (`byNeither`). Snapshots are asynchronous
  unless `meta_compact_sync: true`, and fall back to blocking above **10 ×** the size threshold
  (8 MB when unset) with `JetStream cluster metalayer log size has exceeded async threshold`
  (`1649–1670`, `1700–1706`).
- Stream groups: 2 min (+ jitter), 8 MB or 65,536 entries (`3188–3197`); consumer groups: 2 min,
  64 KB or 1,024 entries (`6602–6612`).

### Peers: removal, return, and the 5-minute rejoin

- `$JS.API.SERVER.REMOVE` accepts `peer` (server name) or `peer_id`, refuses a second change while
  one is in flight (`10202`) and an unknown name (`10044`), and **replies only after a quorum has
  the removal in its log** (`jetstream_api.go:2486–2521`; `jetstream_cluster.go:2694–2720`). The
  last node of a group cannot be removed (`raft.go:1079–1082`).
- The removed server logs `JetStream being DISABLED, our server was removed from the cluster`,
  publishes `$JS.EVENT.ADVISORY.SERVER.REMOVED` and disables its own JetStream; the leader re-places
  every stream that had the peer (`2535–2586`). Observed, including the advisory body.
- A returning peer is folded back into streams that are missing peers (`processAddPeer`,
  `2479–2533`). A **removed** peer that keeps talking is proposed back in after `peerRemoveTimeout`
  = **5 minutes** (`trackPeer`, `raft.go:3855–3882`). Observed: restarted 88 s after removal, the
  server followed the group, reported `/healthz` ok, and was not in the leader's `replicas` list.
- Shutdown: a meta leader transfers leadership and waits up to 2 s (`jetstream.go:704–733`); a
  server that hits its resource limits steps down as meta leader (`2844–2852`).

### `meta.Reset()` — what a leaf discards

Step down, drain every queue, **remove the whole `snapshots/` directory**, reset the WAL, set the peer
set to itself alone, term and vote to 0, and persist that (`raft.go:2306–2357`). Called by
`addLeafNodeConnection` when a leaf with a matching domain starts extending the hub — see
[[s-nats-server-leafnode-js-domains]].

### Monitoring: what `/jsz` really carries

`MetaClusterInfo` (`monitor.go:3089–3099`): `name`, `leader`, `peer` (the leader's id),
`replicas` (leader only, one per other peer, with `current` and `active` nanoseconds since last
contact), `cluster_size`, `pending`, `pending_requests`, `pending_infos`, `snapshot`. It is
**always present**; `HandleJsz` decodes no `meta` parameter, so `/jsz?meta=1` is silently the same as
`/jsz`. `/jsz?raft=1&streams=1` adds each stream's `raft_group`, `leader_since` and replicas.
`nats server report jetstream` prints the same peers as the `RAFT Meta Group Information` table and
marks the leader with `*` in the summary.

## Practical takeaways

- Check the right thing: `nats server report jetstream` or `/jsz` `meta_cluster.leader` for the
  meta group, `nats stream info` for a stream's group. A missing meta leader stalls *changes*, not
  traffic.
- After a request times out during an election, **look before retrying differently**: a create with
  the same config is idempotent; a publish needs `Nats-Msg-Id`.
- Do not alert on the first 10 s of `/healthz` disagreement after a node loss — and do not trust a
  lone survivor's `ok` for the first 10–20 s after it lost its peers.
- Peer-remove needs a meta leader; with no quorum the CLI's "ensure the account used has system
  privileges" message is misleading.
- Never bring a standalone server's store into a cluster expecting its streams to survive; the
  timer is 30 s and there is no flag.
- The docs' `$JS.API.META.SERVER.REMOVE` is not the subject; `$JS.API.SERVER.REMOVE` is. Nor is
  `$JS.API.ACCOUNT.PURGE`; the account is a token, `$JS.API.ACCOUNT.PURGE.<account>`.

## Notable quotes

> "Streams and consumers are recovered from disk, and the meta layer's mappings should clean them
> up, but under crash scenarios there could be orphans." — `jetstream_cluster.go:1508–1509`

> "For stream and consumer assignments. All servers will have this be the same." —
> `jetstream_cluster.go:46`

## Relevance to the wiki

This is the mechanism behind [[streams-deleted-when-clustering-a-standalone-server]], the missing
replica-count answer on [[replicas]], the heartbeat/election-timer question on [[raft-in-nats]], and
the "global quorum" sentence on [[choosing-a-topology]] and [[multi-region-jetstream]]. It also
found docs issues **#43** (the peer-remove and account-purge subjects), **#44** (orphan cleanup is documented nowhere)
and **#45** (two system-account subjects absent from a reference the docs call complete).

## Questions it answers

- **Q36** (no quorum, stalled) — the 10-second lost-quorum arithmetic and the two `/healthz` messages.
- **Q38** (streams orphaned when clustering a standalone server) — now with the mechanism, the timer
  and the log line, observed.
- **Q40** (evicting a sick-but-not-dead node) — the peer-remove half: what the removed server does,
  the advisory, the 5-minute rejoin. The thread itself is step 2 of the plan.

## Pages touched

[[meta-layer]] · [[raft-in-nats]] · [[replicas]] ·
[[streams-deleted-when-clustering-a-standalone-server]] · [[jetstream-domain]] ·
[[no-suitable-peers-for-placement]] · [[js-api-subjects]] · [[monitoring-endpoints]] ·
[[error-codes]] · [[advisories]] · [[choosing-a-topology]] · [[multi-region-jetstream]] ·
[[gateway]] · [[nats-timeout]] · [[disaster-recovery]] · [[upgrade-a-cluster]] ·
[[build-a-3-node-cluster]]
