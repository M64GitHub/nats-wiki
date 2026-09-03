---
title: "nats-server 2.11 release notes, v2.11.0 → v2.11.17 (2025-03-19 → 2026-04-27): the change layer"
type: summary
area: [deploy, jetstream, security, topology, monitoring, core, kv, interop]
source-url: https://github.com/nats-io/nats-server/releases
source-path: raw/release-notes/v2.11.0.md, raw/release-notes/v2.11.1-binary.md, raw/release-notes/v2.11.1.md, raw/release-notes/v2.11.2.md, raw/release-notes/v2.11.3.md, raw/release-notes/v2.11.4.md, raw/release-notes/v2.11.5.md, raw/release-notes/v2.11.6.md, raw/release-notes/v2.11.7.md, raw/release-notes/v2.11.8.md, raw/release-notes/v2.11.9.md, raw/release-notes/v2.11.10.md, raw/release-notes/v2.11.11.md, raw/release-notes/v2.11.12.md, raw/release-notes/v2.11.14.md, raw/release-notes/v2.11.15.md, raw/release-notes/v2.11.16.md, raw/release-notes/v2.11.17.md
author: nats-io/nats-server maintainers
date: 2026-04-27          # v2.11.17, the last release of the line; v2.11.0 shipped 2025-03-19
version: "2.11"
article: "The 18 GitHub release bodies of the 2.11 line read end to end as one changelog; RC and preview bodies excluded (folded into each GA body)"
tags: [release, 2.11, changelog, change-layer, defaults, cve, withdrawn, downgrade, api-level-1, ttl, priority-groups, tracing]
aliases: [v2.11.0, v2.11.1-binary, v2.11.1, v2.11.2, v2.11.3, v2.11.4, v2.11.5, v2.11.6, v2.11.7, v2.11.8, v2.11.9, v2.11.10, v2.11.11, v2.11.12, v2.11.14, v2.11.15, v2.11.16, v2.11.17, "2.11 release notes", "2.11 changelog"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server 2.11 release notes, v2.11.0 → v2.11.17: the change layer

The 2.11 line ran **from 2025-03-19 to 2026-04-27**: 18 releases (no 2.11.13), 54 tags counting the
two 2024 previews and the release candidates, one binary-only security release, one release
withdrawn, and — in its last four months, after 2.12 and alongside 2.14 — **twelve CVEs fixed in three
releases**. This summary reads the 18 bodies as one document and keeps what an operator needs **by
kind of change**, each item with its release and PR number. It does not repeat dependency bumps, Go
versions (in the table) or the *Complete Changes* links. Two releases have their own summaries and
are folded by reference: [[s-relnotes-2.11.2]] (the withdrawn consumer-consistency release) and
[[s-relnotes-2.11.5]] (the `DeliverLastPerSubject` ack fix). The 2.10 line is [[s-relnotes-2.10]].

Every body from 2.11.0 on links a "2.11 Upgrade Guide" at
`docs.nats.io/release-notes/whats_new/whats_new_211`; **that page does not exist** — the URL redirects
to `/release-notes/` (checked 2026-09-03) and the docs mirror holds guides for 2.12 and 2.14 only.
The bodies below are the record of what 2.11 changed.

## The releases at a glance

| release | date | Go | ★ | what an operator needs from it |
|---|---|---|---|---|
| 2.11.0 | 2025-03-19 | 1.24.1 | ★ | the feature release: per-message TTL and delete markers, priority groups, consumer pause, multi-get, message tracing, config digest, ingest rate limiting, `cluster_traffic`, `strict`, pedantic mode, `preferred` on stepdown; acks proposed through Raft on clustered interest and WorkQueue streams; SIGTERM exits 0 |
| 2.11.1-binary | 2025-03-31 | 1.24.1 | ★ | **CVE-2025-30215, CRITICAL**, binaries only, source a week later |
| 2.11.1 | 2025-04-08 | 1.24.1 | ★ | the tagged CVE release |
| 2.11.2 | 2025-04-25 | 1.24.2 | ★ | **withdrawn** — "contains a regression that has since been fixed in 2.11.3"; the consumer-consistency change with its throughput caveat; `default_sentinel`; `trace_headers`; delete markers for TTL expiry; the 2.10.28 backports ([[s-relnotes-2.11.2]]) |
| 2.11.3 | 2025-05-01 | 1.24.2 | | fixes the 2.11.2 regression (#6845); MQTT `js_api_timeout` |
| 2.11.4 | 2025-05-22 | 1.24.3 | | **stream and consumer updates refused when all peers are offline, "a potential avenue for data loss"** (#6856); WorkQueue sequences no longer reset to zero after a crash (#6882); TLS handshake errors log the certificate |
| 2.11.5 | 2025-06-26 | 1.24.4 | | `DeliverLastPerSubject` acks with interior deletes (#7005); Raft on monotonic time (#6999); `healthz` stops fixing up node skews (#7001); `/connz` includes leafnodes ([[s-relnotes-2.11.5]]) |
| 2.11.6 | 2025-07-01 | 1.24.4 | | **a filtered-consumer throughput regression present since 2.11.0 fixed** (#7015); filestore encryption could corrupt a block after restart (#7008); stalled sources keep their last-seen time |
| 2.11.7 | 2025-08-01 | 1.24.5 | | Raft recovers and snapshots before campaigning (#7040); pull consumers with an inactive threshold count pending acks (#7052); TTLs over an hour expired late (#7070); enabling TTLs scans existing messages (#7117); stale `index.db` after a block delete rebuilt (#7123) |
| 2.11.8 | 2025-08-14 | 1.24.6 | | Raft steps down on a higher term during catch-up; `healthz` stops reporting transient errors for new or deleted consumers (#7154); ephemeral consumers pick an online server |
| 2.11.9 | 2025-09-09 | 1.24.7 | ★ | **offline assets** — the reason it is the downgrade floor from 2.12 (#7158); `leader_since`, `system_account`, `traffic_account` in stream and consumer info and `/jsz`; account JWT connection limits disconnect the right clients; leafnode interest with daisy-chained imports |
| 2.11.10 | 2025-09-30 | 1.24.7 | | meta snapshot regression from 2.11.9 fixed (#7350); binary search for `opt_start_time` (#7357); API requests always from the worker pool (#7125); no meta snapshot per stream removal (#7373); TTL fixes; use-after-free in the flusher (#7295) |
| 2.11.11 | 2025-11-13 | 1.25.4 | | **`meta_compact` / `meta_compact_size`**; **`write_timeout`** (`default` / `retry` / `close`); streams loaded in parallel at startup (#7482); catch-ups use delete ranges (#7512); `healthz` reports catching-up streams as such (#7535); `no_wait` on an empty stream answers `No Messages` (#7466); tombstones lost with secure erase fixed |
| 2.11.12 | 2026-01-27 | 1.25.6 | | `websocket { ping_interval }` (the body prints `ping_internal`); `tls_cert_not_after` in `/varz`; **switching to interest retention removes no-interest messages from the head** (#7766); `AsyncFlush` could lose writes after a process pause (#7594); a large Raft membership batch (peer-remove of the last peer refused, removed peers not counted for quorum, peer state written immediately); non-replicated file consumers with a corrupt state file are **deleted automatically** (#7691); seven MQTT fixes including retained-message corruption in clusters (#7622) |
| 2.11.14 | 2026-03-09 | 1.25.8 | ★ | **CVE-2026-29785** (leafnode compression), **CVE-2026-27889** (WebSockets) — eight WebSocket parsing fixes |
| 2.11.15 | 2026-03-24 | 1.25.8 | ★ | **ten CVEs** (MQTT ×3, leafnodes ×2, WebSockets, JetStream ×2, mutual TLS, command-line credentials, publish permissions); the line's one `### Changed`: **a 1 MB size limit on JWTs** (#7960); `peer-remove` accepts a peer ID; a path-traversal bug on account purge; `Nats-Trace-Dest` now needs publish permission |
| 2.11.16 | 2026-04-14 | 1.25.9 | ★ | `### CVEs — TBD`; **`no_auth_user` restricted to client connections**; overlapping `deny` wildcards enforced; queue subscriptions can no longer bypass non-queue `deny`; leafnode ACLs enforced on inbound messages, `max_payload` enforced on leafnodes |
| 2.11.17 | 2026-04-27 | 1.25.9 | | `/connz` no longer discloses bearer JWTs; route and cluster URL secrets redacted from monitoring; repeated `CONNECT` clears subscriptions; JWT validity across midnight; gateway `pinned_certs` reload |

★ is the table's rule (`inbox/relnotes-toc.md`): changed, removed, downgrade, withdrawn, warning, CVE,
or the first of a minor.

## Defaults, limits and intervals that changed

| what | before | after | release, PR |
|---|---|---|---|
| exit code on a graceful `SIGTERM` shutdown | 1 | **0** | 2.11.0, #6336 ("Successful exit code for SIGTERM"); 2.11.10 fixes it when the signal arrives right after startup (#7367) |
| message removal by ack on **clustered** interest and WorkQueue streams | applied locally | **proposed through Raft** — "ensures that the removal ordering across all replicas is consistent, but may increase the amount of replication traffic" | 2.11.0, #6140 |
| a new leader's first responses | immediate | **only once "initially up-to-date with its Raft log"** — also fixes KV creates and updates during a leader change desyncing the stream | 2.11.0, #6194 #6485 #6518 |
| a consumer's starting sequence | clipped into the stream | **always respected, "except for consumers used for sources/mirrors"** — the 2.11 answer to the 2.10.19 → 2.10.22 clipping story ([[s-gh-6005-sourcing-memory-stream-restart]]) | 2.11.0, #6253 |
| replicated consumers' delivered state | updated on delivery | **updated only after quorum** ("may negatively impact the throughput of replicated consumers"; R1, `AckNone` and ordered consumers unaffected) | 2.11.2 (withdrawn) — see [[s-relnotes-2.11.2]] |
| stream or consumer update with every peer offline | accepted | **refused**, "fixing a potential avenue for data loss" | 2.11.4, #6856 |
| Raft heartbeat and quorum timing | wall clock | **monotonic time**, "resilient against wall-clock drifts or adjustments from NTP" | 2.11.5, #6999 |
| `healthz` behaviour | fixes up cluster node skews | **no longer does** — "this could interfere with processing assignments" | 2.11.5, #7001 |
| assets from a newer API level after a downgrade | misread | **reported offline and unsupported, data kept** — "allowing to either delete the asset or upgrade back" | 2.11.9, #7158 — why **v2.11.9 is the downgrade floor from 2.12** |
| stream snapshots on new route connections | — | **binary snapshots preferred by default** | 2.11.11, #7479 |
| stream loading when JetStream starts | serial | **parallel**, "often reducing the time it takes to start up the server"; recovery parallelism matches the I/O semaphore | 2.11.11, #7482 #7526 |
| switching a stream to `interest` retention | history kept until acked | **no-interest messages removed from the head of the stream** | 2.11.12, #7766 |
| a non-replicated file-backed consumer with a corrupt state file | fails | **deleted automatically** | 2.11.12, #7691 |
| JWT size | unbounded | **1 MB limit** | 2.11.15, #7960 ("Update JWT dependency") |
| `no_auth_user` | applied to any connection type | **client connections only** | 2.11.16 |
| `Nats-Trace-Dest` | any client | **requires publish permission on the destination subject** | 2.11.15 |

## Config keys, flags and fields that arrived

| key or field | release, PR | note |
|---|---|---|
| `nats-server -t` prints a **configuration digest**; `config_digest` in `/varz` | 2.11.0, #4325 | `config_digest` is documented nowhere (`inbox/docs-issues.md` #57) |
| scoped-user **templates not limited to a subject token** | 2.11.0, #5981 | |
| `/healthz?js-meta-only=true` | 2.11.0, #6649 | |
| **`Nats-TTL`** header (a duration string or seconds) — per-message TTL, ADR-43 | 2.11.0, #6272 … #6400 | see [[message-ttl]] |
| **`SubjectDeleteMarkerTTL`** (`subject_delete_marker_ttl`) and the `Nats-Marker-Reason` header | 2.11.0, #6378 … #6432 | markers also placed for TTL expiry from 2.11.2 (#6741); a KV purge no longer leaves an extra marker from 2.11.7 (#7026) |
| **`PriorityGroups`** / **`PriorityPolicy`** — pinning and overflow, ADR-42 | 2.11.0, #5814 #6078 #6081 | see [[priority-groups]]; push consumers error on them from 2.11.7 (#7053) |
| **`PauseUntil`** and **`$JS.API.CONSUMER.PAUSE`** | 2.11.0, #5066 | |
| asset versioning (ADR-44 — API levels) | 2.11.0, #5850 #5855 #5857 | |
| **multi-get** on direct get (ADR-31) | 2.11.0, #5107 | see [[direct-get]] |
| pedantic mode — creates or updates fail "if the resulting configuration would differ due to defaults" | 2.11.0, #5245 | |
| **`jetstream { max_buffered_msgs, max_buffered_size }`** — stream ingest rate limiting; a rate-limited publish with a reply gets **`429 Too Many Requests`** | 2.11.0, #5796 | the docs' default for `max_buffered_msgs` is wrong (10,000 vs 100,000 — `inbox/docs-issues.md` #22) and their description ("storage temporarily unavailable") does not describe an ingest queue |
| `Nats-Expected-Last-Subject-Sequence-Subject` header | 2.11.0, #5281 | |
| **`cluster_traffic: owner`** in an account's `jetstream` block — Raft traffic in the asset account instead of the system account | 2.11.0, #5466 #5947 | documented nowhere (`inbox/docs-issues.md` #56); reported by `traffic_account` from 2.11.9 (#7193) and by `/raftz` (#7186); 2.11.9 restores it correctly in operator mode (#7191), 2.11.12 fixes it in config mode (#7723) |
| `preferred` placement tags or clusters on a stepdown request | 2.11.0, #6282 #6284 | |
| **`jetstream { strict }`** — strict decoding of API requests | 2.11.0, #5858 | off by default in 2.11 (the server logs), **on by default in 2.12** ([[s-docs-upgrade-to-2.12]]) |
| TPM key storage for JetStream encryption on Windows | 2.11.0, #5273 | |
| `js_cluster_migrate` with a delay | 2.11.0, #5903 | |
| leafnode `handshake_first` as a **duration** (the fallback form) | 2.11.0, #5783 ("LeafNode: Support for TLS handshake_first duration") | the boolean arrived in 2.10.0 (#4119); the docs type the leafnode listener's key as boolean only (`inbox/docs-issues.md` #55) |
| WebSocket custom response headers | 2.11.0, #5230 | |
| MQTT SparkplugB Aware | 2.11.0, #5241 | |
| **`default_sentinel`** — a default sentinel JWT in operator mode, "making it possible to have default users" | 2.11.2, #6577 | must be a bearer token (2.11.7, #7074), or from a scoped signing key (2.11.9, #7217) |
| **`trace_headers`** — trace logging emits headers only, not payloads | 2.11.2, #6638 | |
| **`mqtt { js_api_timeout }`** | 2.11.3, #6833 | |
| **`jetstream { meta_compact, meta_compact_size }`** — entries or bytes in the meta log before snapshot and compaction | 2.11.11, #7484 #7521 | |
| **`write_timeout`** (`default` / `retry` / `close`) on clients, routes, gateways and leafnodes — what happens at `write_deadline` | 2.11.11, "#7513" (a cherry-pick PR: "Cherry-picks for 2.12.2-RC.2") | see [[slow-consumer-detected]] |
| `/jsz?direct-consumers=true`; meta snapshot statistics and leader counts in `/jsz` | 2.11.11, #7543 #7524 #7429 | |
| **`websocket { ping_interval }`** | 2.11.12, #7614 ("Add WebSocket-specific ping interval configuration option") | the body prints `ping_internal` — a typo, as `sync_internal` was in 2.10.0 |
| **`tls_cert_not_after`** in `/varz` | 2.11.12, #7709 | documented nowhere (#57) |
| `leader_since`, `system_account`, `traffic_account` in stream and consumer info and `/jsz` | 2.11.9, #7189 #7193 | documented nowhere (#57) |
| `/connz` includes leafnode connections; `accstatsz` carries leafnode, route and gateway stats | 2.11.5, #6949 #6967 | |
| `leafz` reports the connection ID; the monitoring index page names endpoints on hover | 2.11.7, #7063 #7066 | |
| `peer-remove` accepts a peer ID as well as a server name | 2.11.15, #7952 | |

## Subjects, headers and endpoints that arrived

- **Distributed message tracing** (2.11.0, #5014, #5057): a message with **`Nats-Trace-Dest`** set to a
  subject "will receive events representing what happens to the message as it moves through the
  system" — ingress, subject mapping, stream exports, service imports, egress to subscriptions,
  routes, gateways or leafnodes; **`Nats-Trace-Only: true`** traces without delivering. 2.11.11 fixes
  header corruption when setting the hop header (#7443); 2.11.15 requires publish permission on the
  destination and stops trace headers being mis-parsed at `max_payload` (#7954). 2.14.0 later stops
  tracing from modifying `traceparent` ([[s-relnotes-2.14.0]]).
- **`$JS.API.CONSUMER.PAUSE`** (2.11.0, #5066). See [[js-api-subjects]].
- **`429 Too Many Requests`** as a PubAck error under ingest rate limiting (2.11.0, #5796).
- **`No Messages` on `no_wait` against an empty stream** (2.11.11, #7466 "Consumer send 404 No Messages
  on EOS"). The 2.11.11 body prints "400 No Messages"; the server sends **`404`** (`consumer.go:4678`
  and `5024` at v2.14.6) and the 2.14.0 body says 404 for the same PR — a release-notes slip.
- `$SYS.REQ.USER.INFO` is answered only by the local server from 2.11.7 (#7089), "fixing cases where
  the endpoint may sometimes return without full connection details".

## Behaviours that changed — the "now" and "no longer" lines

- **Server, cluster and gateway names containing spaces are rejected** (2.11.0, #5676) — 2.10.19 had
  done it for leafnode cluster names.
- **Idempotent stream and consumer creates after a 2.10 → 2.11 upgrade** no longer fail "due to
  metadata changes" (2.11.2, #6716 "Idempotent stream/consumer create after standalone server
  upgrade") — 2.11.0 and 2.11.1 have this on an upgraded standalone server.
- **A `Nats-Msg-Id` message rejected for an invalid TTL** is no longer placed in the deduplication
  map (2.11.2, #6725).
- **Pull consumers with an inactive threshold consider pending acks** before being deleted
  (2.11.7, #7052) and no longer age out before processing acks (#7107).
- **The Raft layer recovers and handles snapshots before campaigning** (2.11.7, #7040), "fixing a
  situation where a node could continue with an outdated stream"; the log is not compacted until a
  snapshot is written (#7043); a higher term during catch-up forces a step-down (2.11.8, #7151).
- **Ephemeral consumers always select an online server** on a replicated stream (2.11.8, #7165).
- **An account JWT update with a lower connection limit disconnects the newest clients, not the
  oldest** (2.11.9, #7181, #7185); lowering the limit no longer loses stream interest (#7258).
- **Routes with invalid credentials no longer reconnect rapidly** (2.11.9, #7200).
- **A leader limits its cached in-memory Raft entries** (2.11.9, #7233); **non-leaders cannot send
  append entries** (2.11.10, #7297); **deleting a non-existent sequence no longer resets the cluster
  and elects** (2.11.10, #7348); a stream snapshot timeout no longer resets clustered state (#7293).
- **JetStream API requests are always handled from the worker pool**, "improving the semantics of the
  API request queue and logging when requests take too long" (2.11.10, #7125).
- **Streams with subject transforms republish implicitly** with `>` as both republish source and
  destination (2.11.11, #7515).
- **Lame duck no longer produces max-connections-exceeded errors** (2.11.11, #7527).
- **Health checks report streams that are catching up as such, not as unhealthy** (2.11.11, #7535);
  consumers deleted on recovery no longer fail them (#7523); a Raft group reports leadership only
  after a no-op entry on recovery (#7460).
- **The meta layer answers a peer-remove only after quorum** (2.11.12, #7581); **the last remaining
  peer cannot be removed** (#7610); **removed peers are not counted towards quorum** (#7589) and their
  removal is written to peer state immediately "to ensure the removed peers cannot unexpectedly
  reappear after a restart" (#7602); no concurrent membership changes (#7565, #7609); a removed peer is
  not re-admitted by a heartbeat between removal and leadership transfer (#7649).
- **Consumer updates recalculate pending only when the filter changes** (2.11.12, #7753); consumers on
  replicated interest and WorkQueue streams no longer lose interest after a filter update (#7773).
- **MQTT: `$MQTT.` subscription permissions are implicit** except `deny` ACLs (2.11.12, #7637) — then
  **restricted to the `$MQTT.sub.` and `$MQTT.deliver.pubrel.` prefixes** (2.11.15); NATS special
  characters (`.`, `>`, `*`, spaces, tabs) are refused in client IDs; a persisted session can only be
  restored by the matching client ID; passwords no longer appear in the JWT field of monitoring or
  advisories; session-flapping detection uses monotonic time (all 2.11.15).
- **Repeated `CONNECT` messages clear subscriptions** (2.11.17); **`/connz` no longer discloses bearer
  JWTs**; route and cluster URL secrets are redacted from monitoring when passed on the command line.

## Withdrawn releases, warnings and regressions

- **2.11.2 is withdrawn** — `> [!IMPORTANT] This version contains a regression that has since been
  fixed in 2.11.3. Please upgrade to that version instead.` 2.11.3 names it: "a regression introduced in
  v2.11.2 which can affect calculating consumer subject interest" (#6845) — the same regression, and
  the same fix, as 2.10.28 → 2.10.29.
- **2.11.0 → 2.11.6**: "Fixed a performance regression introduced in v2.11.0 which could result in
  abnormally low throughput from filtered consumers and higher GC pressure" (#7015) — every 2.11 before
  2.11.6 has it.
- **2.11.9 → 2.11.10**: "Meta snapshot performance for a very large number of assets has been
  improved after a regression in v2.11.9" (#7350).
- **2.11.7**: per-message TTLs over an hour "could take double the expected time" to expire until
  #7070.
- **2.11.16**'s CVE section reads `TBD` — the identifiers were not filled in when the body was
  published.

## Data-integrity and data-loss fixes

| release | fix |
|---|---|
| 2.11.0 | ack removals on clustered interest and WorkQueue streams proposed through Raft (#6140); a new leader responds only once up to date, fixing KV desyncs on leader change (#6194, #6485, #6518); replicated consumers no longer skip redeliveries after a leader change (#6566); first sequence populated on recovery from a bad checksum with zero messages (#6647) |
| 2.11.2 | the 2.10.28 set — tombstones on purge and compact (#6685), sequence numbers on interruption (#6778), the 32 MB cap (#6798), `FirstSeq` streams not purged on restart (#6753) — plus TTL state recovered from disk (#6758), tombstones for TTL expiry (#6781), markers replicated reliably (#6776) |
| 2.11.4 | **updates refused when all peers are offline** (#6856); first sequence adjusted when purging over interior deletes (#6861); WorkQueue first and last sequences no longer reset to zero after a crash with unflushed data (#6882) |
| 2.11.5 | desync after a partial catch-up following a snapshot (#6943); desync from catch-up messages with incorrect quorum (#6944); partitioned nodes no longer accept catch-ups from a lower term (#6951); `AllowMsgTTL` updates take effect (#6922) |
| 2.11.6 | **filestore encryption could corrupt a block** "if a write took place before a read after restarting the server" (#7008); removed streams no longer reappear (#7025) |
| 2.11.7 | truncate and erase consistent after a hard kill (#7100); a stale `index.db` after a block delete marked as lost data and rebuilt (#7123); cipher conversion with compression (#7099) |
| 2.11.8 | stale `index.db` cleaned on truncate (#7162); Raft off-by-one at startup truncation (#7162) |
| 2.11.9 | delayed entries from an old leader rejected during catch-up (#7209, #7239); the same stream cannot be created twice with different configurations (#7210, #7212); a consumer cannot get more replicas than its stream (#7202) |
| 2.11.10 | blocks with out-of-order sequences from disk corruption recovered (#7303, #7304); use-after-free in the flusher (#7295) |
| 2.11.11 | tombstones no longer lost with secure erase, last sequence kept when recovering tombstone-only blocks (#7384); `sync_always` honoured for TTL and schedule state files (#7385); skipped sequences checked for ordering before apply (#7400, #7399, #7401); scale-up from R1 installs a snapshot "avoiding a potential desync" (#7509) |
| 2.11.12 | **`AsyncFlush` could lose writes after a process pause** (#7594 "SyncBlocks may lose pending writes"); compactions reclaiming over half the space use an atomic write "to avoid losing messages if killed" (#7627); compaction sequence bookkeeping and `no idx present` (#7634); desyncs during snapshotting (#7655); encryption keys recovered independently of the index (#7678); a single truncated block no longer blocks storing (#7704); R1 last-sequence drift over limits (#7658); deleted streams no longer revived (#7668); MQTT retained messages corrupted in clusters (#7622) |
| 2.11.15 | meta snapshot apply errors surfaced so the applied index does not advance (#7944); reservations can no longer overflow tier limits; a stream restore checks the name matches the archive; an interior path-traversal bug on account purge |

## CVEs

| release | CVE | scope, as the body states it |
|---|---|---|
| 2.11.1-binary, 2.11.1 | **CVE-2025-30215, CRITICAL** | "all NATS Server versions from v2.2.0, prior to v2.11.1 or v2.10.27" — [[s-gh-6748-cve-binary-release-docker-images]] |
| 2.11.14 | CVE-2026-29785 | "systems with leafnode compression enabled" |
| 2.11.14 | CVE-2026-27889 | "systems with WebSockets enabled" |
| 2.11.15 | CVE-2026-33216, CVE-2026-33217, CVE-2026-33215 | MQTT |
| 2.11.15 | CVE-2026-33246 | leafnodes and service imports |
| 2.11.15 | CVE-2026-33218 | leafnodes |
| 2.11.15 | CVE-2026-33219 | WebSockets |
| 2.11.15 | CVE-2026-33223, CVE-2026-33222 | JetStream |
| 2.11.15 | CVE-2026-33248 | mutual TLS |
| 2.11.15 | CVE-2026-33247 | "systems providing credentials on the command line" |
| 2.11.15 | CVE-2026-33249 | "systems where client publish permissions should be restricted" |
| 2.11.16 | `TBD` | the body's CVE line was left unfilled; the fixes are ACL enforcement (`no_auth_user` client-only, `deny` wildcard overlaps, queue subscriptions bypassing `deny`, leafnode inbound ACLs and `max_payload`) |

The 2.12 and 2.14 lines received the same fixes on the same dates (2.12.5/2.12.6/2.12.7 and 2.14.x —
[[s-relnotes-2.12]]).

## Performance lines an operator would cite

- 2.11.4: per-subject limit enforcement after a rebuild or retention change "considerably faster"
  (#6871). 2.11.5: sourcing resyncs faster over leafnodes after a connection failure (#6981). 2.11.9:
  mirroring and sourcing sped up after a leaf reconnect "in complex topologies" (#7265).
- 2.11.10: sequence-from-timestamp lookups (`opt_start_time`, direct-get `start_time`) by binary search
  (#7357); TTL state without the store lock (#7344); no meta snapshot per stream removal (#7373).
- 2.11.11: catch-ups use delete ranges "speeding up catchups of large streams with many interior
  deletes" (#7512); parallel stream loading (#7482); fewer snapshots on removal or scale-down (#7495).
- 2.11.12: the scan for the last sourced message of a subject-filtered source "considerably faster"
  (#7553 — the mechanism [[jetstream-recovery-is-slow]] measured); interest checks with large gaps
  (#7656); consumer file stores created without the stream lock (#7700); multi-filter lookups skip
  blocks (#7750).

## Corrections and notes the line forces

1. **`handshake_first` on the leafnode listener takes the duration and `auto` forms since 2.11.0**
   (#5783); the docs type it `boolean` only — `inbox/docs-issues.md` #55.
2. **`cluster_traffic`** is parsed in `parseJetStreamForAccount` (`opts.go:2451–2463` at v2.14.6,
   values `system` and `owner`) and documented nowhere — #56.
3. **`config_digest`, `tls_cert_not_after`, `leader_since`** (with `system_account` and
   `traffic_account`) are monitoring fields the docs never name — #57.
4. **`max_buffered_msgs`**: the docs' default 10,000 is the server's 100,000 (#22, already recorded),
   and the docs describe the buffer as "for a stream whose storage is temporarily unavailable" while
   the body and `stream.queueInbound` describe an ingest-rate limit with a `429` — noted on #22.
5. Two typos in the bodies: `ping_internal` (2.11.12) for `websocket { ping_interval }`, and "400 No
   Messages" (2.11.11) for the `404` the server sends.
6. **PR #4119 is listed in both 2.10.0 and 2.11.0**: the boolean leafnode `handshake_first` is 2.10.0's;
   2.11.0 adds the duration form (#5783).

## Relevance to the wiki

Every "since 2.11" on a page can now cite the body that says so — per-message TTL, delete markers,
priority groups, multi-get, consumer pause, `strict`, the ingest rate limit and its `429`, message
tracing, `cluster_traffic`, `write_timeout`, `meta_compact` — and the two "which 2.11 patch" rules
join [[upgrade-a-cluster]]: below 2.11.6 filtered consumers run slow, below 2.11.9 a downgrade from
2.12 is unsafe, and 2.11.14–2.11.16 close twelve CVEs.

## Questions it answers

Rows 64 and 130 in part (the data-integrity table, the 2.11.9 floor, the 2.11.2 withdrawal); 71
(per-message TTL and KV per-key TTL are 2.11.0, from the body); 63 in part.

## Pages touched

[[nats-server-2.11]] · [[nats-server-2.12]] · [[upgrade-a-cluster]] · [[message-ttl]] ·
[[priority-groups]] · [[direct-get]] · [[consumer]] · [[stream]] · [[retention-policies]] ·
[[key-value]] · [[mirrors-and-sources]] · [[js-api]] · [[js-api-subjects]] · [[raft-in-nats]] ·
[[meta-layer]] · [[replicas]] · [[evict-a-sick-server]] · [[monitoring-endpoints]] · [[tls-in-nats]] ·
[[leafnode]] · [[websocket]] · [[mqtt]] · [[account]] · [[subject-permissions]] · [[operator-mode]] ·
[[auth-callout]] · [[cross-account-sharing]] · [[slow-consumer-detected]] ·
[[jetstream-slows-as-consumers-grow]] · [[jetstream-recovery-is-slow]] · [[filestore-layout]] ·
[[consumer-keeps-redelivering]] · [[jetstream-out-of-disk]] · [[install-nats-server]] ·
[[reload-server-config]] · [[config-keys]] · [[defaults-and-limits]] · [[error-codes]] ·
[[stream-placement]] · [[advisories]]
