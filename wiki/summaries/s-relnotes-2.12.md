---
title: "nats-server 2.12 release notes, v2.12.0 → v2.12.15 (2025-09-22 → 2026-08-12): the change layer"
type: summary
area: [deploy, jetstream, security, topology, monitoring, core, kv, interop]
source-url: https://github.com/nats-io/nats-server/releases
source-path: raw/release-notes/v2.12.0.md, raw/release-notes/v2.12.1.md, raw/release-notes/v2.12.2.md, raw/release-notes/v2.12.3.md, raw/release-notes/v2.12.4.md, raw/release-notes/v2.12.5.md, raw/release-notes/v2.12.6.md, raw/release-notes/v2.12.7.md, raw/release-notes/v2.12.8.md, raw/release-notes/v2.12.9.md, raw/release-notes/v2.12.10.md, raw/release-notes/v2.12.11.md, raw/release-notes/v2.12.12.md, raw/release-notes/v2.12.14.md, raw/release-notes/v2.12.15.md
author: nats-io/nats-server maintainers
date: 2026-08-12          # v2.12.15, the last release of the line so far; v2.12.0 shipped 2025-09-22
version: "2.12"
article: "The 15 GitHub release bodies of the 2.12 line read end to end as one changelog, checked line by line against the docs' 2.12 upgrade guide; RC and preview bodies excluded"
tags: [release, 2.12, changelog, change-layer, defaults, cve, downgrade, api-level-2, atomic-batch, counters, scheduling, strict, async-flush]
aliases: [v2.12.0, v2.12.1, v2.12.2, v2.12.3, v2.12.4, v2.12.5, v2.12.6, v2.12.7, v2.12.8, v2.12.9, v2.12.10, v2.12.11, v2.12.12, v2.12.14, v2.12.15, "2.12 release notes", "2.12 changelog"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server 2.12 release notes, v2.12.0 → v2.12.15: the change layer

The 2.12 line runs **from 2025-09-22** and was still receiving patches on **2026-08-12**, after 2.14
shipped: 15 releases (no 2.12.13), 47 tags counting two previews and the release candidates. No
release was withdrawn, but **2.12.5 carries a `> [!WARNING]`** (a stream update could lose a
cluster's consumers) and **2.12.7 introduced a regression 2.12.11 fixes**. From 2.12.9 on, every
release is the same-day twin of a 2.14 patch (2.12.9 = 2.14.1 … 2.12.15 = 2.14.5), and from 2.12.2
to 2.12.8 of a 2.11 patch ([[s-relnotes-2.11]]). This summary reads the 15 bodies as one document,
by kind of change, each item with its release and PR number, and — because this is the one line with
a docs upgrade guide — **checks the guide's claims against the bodies** ([[s-docs-upgrade-to-2.12]]).
The 2.10 line is [[s-relnotes-2.10]].

## The releases at a glance

| release | date | Go | ★ | what an operator needs from it |
|---|---|---|---|---|
| 2.12.0 | 2025-09-22 | 1.25.1 | ★ | the feature release: atomic batch publish, counter streams, `prioritized` policy, trusted proxies, mirror promotion, delayed scheduling, offline assets, `partition(n)` / `random(n)`, `Nats-Required-Api-Level`, async writes, `server_metadata`, `isolate_leafnode_interest`, `disabled` remotes; **API level 2**; **strict API by default**; **async flush by default** on replicated streams; **`max_buffered_msgs` default ×10**; WebSocket and MQTT drop TCP keepalives; insecure cipher suites off |
| 2.12.1 | 2025-10-14 | 1.25.3 | | **`write_deadline` per `cluster`, `leafnode`, `gateway` block** (#7405); WebSocket leafnodes through an HTTP proxy; atomic batch deduplicates on `Nats-Msg-Id`; meta files written through temp staging; the 2.11.10 TTL and Raft fixes |
| 2.12.2 | 2025-11-13 | 1.25.4 | | **PROXY protocol v1/v2** (`proxy_protocol: true`, #7456); `meta_compact`, `write_timeout`; expvar `/debug/vars`; the 2.11.11 set (parallel stream loading, delete-range catch-ups) |
| 2.12.3 | 2025-12-17 | 1.25.5 | | the 2.11.12 JetStream and MQTT set; **`DiscardNewPerSubject` enforced by the leader before proposing** (#7607); the meta layer stages and deduplicates recovery (#7540) |
| 2.12.4 | 2026-01-27 | 1.25.6 | | `tls_cert_not_after`; interest switch removes head messages (#7766); corrupt R1 file consumers deleted (#7691); consumer info no longer recalculates pending (#7758) |
| 2.12.5 | 2026-03-09 | 1.25.8 | ★ | **`> [!WARNING]` — a stream update may lose a cluster's consumers; mitigate with `meta_compact_sync: true`**; CVE-2026-29785, CVE-2026-27889; **async metalayer snapshots**; **`max_consumers` updatable** (#7724); `max_conns: 0`; snapshot `window_size` and flow control; the `store_max_stream_bytes` "long-standing bug" (#7895) |
| 2.12.6 | 2026-03-24 | 1.25.8 | ★ | **ten CVEs**; **the 2.12.5 regression fixed** (#7939); 1 MB JWT limit; HTTP CONNECT proxy for leafnodes; restores processed from the wire; the orphan check no longer deletes direct consumers (#7957) |
| 2.12.7 | 2026-04-14 | 1.25.9 | ★ | `### CVEs — TBD`; the ACL fixes; **`max_mem_store` / `max_file_store` may be raised by reload** (#8014); purge loads only the relevant blocks; **introduces the stale subject-state regression** |
| 2.12.8 | 2026-04-27 | 1.25.9 | | consumer start-sequence scans asynchronous, "no longer pauses the metalayer" (#8051); the 2.11.17 set; `Nats-Msg-Id` no longer deduplicated in mirrors (#8043); sourcing no longer duplicates after a leaf reconnect (#8069); `last sequence mismatch` on a failed proposal (#8057) |
| 2.12.9 | 2026-05-20 | 1.25.10 | | = 2.14.1: **`in_client_msgs` / `in_client_bytes` / `out_client_*` in `/varz`** (#7851); pending calculated only on consumer leaders (#8172); the drifted-redelivered-state fixes (#8102, #8156, #8168); `$JS.ACK` double-encoding over routes and gateways (#8089) |
| 2.12.10 | 2026-06-02 | 1.25.10 | | = 2.14.2: **the block skip check disabled on extremely high subject counts — runaway CPU** (#8227); quorum with gateway URLs resolving to several IPs (#8238); counter and schedule config constraints (#8240); peer-set drift after removing an online node (#8258) |
| 2.12.11 | 2026-06-09 | 1.25.11 | | one fix: **"a regression introduced in v2.12.7 which could result in stale subject state tracking … `Message Not Found` errors when a max messages per subject limit is configured" (#8285) — "v2.14.x versions are not affected"** |
| 2.12.12 | 2026-06-29 | 1.25.11 | ★ | = 2.14.3: **`### Removed` — JSONP callback support on monitoring endpoints**; service import replies across routes (#8317); **counter staging corrupted the running total** (#8311); **filestore compaction corrupted compressed or encrypted blocks** (#8312); Raft stops voting after write errors (#8290); a security batch without CVE ids |
| 2.12.14 | 2026-07-30 | 1.25.12 | | = 2.14.4: **`max_concurrent_io`, and the disk semaphore raised to 4096** (#8336); **an authentication bypass with `verify_and_map` and blank passwords**; `no_auth_user` + auth callout skipping checks; malformed replicated entries rejected (five reports by one contributor); `healthz` skips expired JWT accounts |
| 2.12.15 | 2026-08-12 | 1.25.12 | | = 2.14.5: **"potential data loss when handling idempotent stream creates when an offline node catches up from a metalayer snapshot"** (#8449); a logger deadlock (#8430) |

★ is the table's rule (`inbox/relnotes-toc.md`): changed, removed, downgrade, withdrawn, warning, CVE,
or the first of a minor.

## Defaults, limits and intervals that changed

| what | before | after | release, PR |
|---|---|---|---|
| **JetStream API level** | 1 | **2** | 2.12.0, #6969 |
| `jetstream { strict }` | `false` (2.11) | **`true`** — "erroring if unknown fields are provided in the request body" | 2.12.0, #7049 |
| replicated stream flush | synchronous | **asynchronous by default** "as long as `sync: always` is not configured" | 2.12.0, #7018 #7163 ("Filestore async flush"); R1 opt-in with async persist mode, #7315 #7323 |
| **`max_buffered_msgs`** | 10,000 | **100,000** — "increased by 10x" | 2.12.0, #6633 ("Raise max_buffered_msgs defaults by 10x") — the docs still print 10,000 (`inbox/docs-issues.md` #22) |
| WebSocket and MQTT client sockets | TCP keepalives | **no TCP keepalives** | 2.12.0, #7329 — the line's `### Changed` |
| insecure TLS cipher suites | allowed | **disabled**, unless `tls { allow_insecure_cipher_suites }` | 2.12.0, #7144 |
| route and gateway reconnection | fixed interval | **exponential backoff** (the guide: `connect_backoff`, "1 second up to 30 seconds") | 2.12.0, #7042 #7048 |
| a replicated stream with replica nodes offline | creation refused | **created** "even if some of the replica nodes are offline" | 2.12.0, #7075 |
| Raft nodes that lost their stable storage | could rejoin and vote | **empty-vote protection** — "improves how the Raft election logic handles nodes that have lost their stable storage and attempt to rejoin the cluster regardless" | 2.12.0, #7038 ("NRG: Empty log protection") |
| filestore in-memory caches | strong pointers | **weak (elastic) pointers** that "can respond to garbage collector (GC) pressure" | 2.12.0, #7180 |
| `DiscardNewPerSubject` | enforced by each replica | **by the leader before proposing**, "reducing the potential for stream desync" | 2.12.3, #7607 |
| metalayer snapshots | synchronous, blocking the API | **asynchronous when possible**; `jetstream { meta_compact_sync: true }` restores the old behaviour | 2.12.5, #7827 #7846 — and the 2.12.5 regression's mitigation |
| `max_consumers` on a stream | fixed at creation | **updatable** | 2.12.5, #7724 |
| `max_conns` | ≥ 1 | **`0` refuses all client connections** | 2.12.5, #7877 |
| stream backups | staged on the filesystem | **streamed with flow control** (`window_size`) and, on restore, **processed from the wire** | 2.12.5, #7828 #7839; 2.12.6 |
| JWT size | unbounded | **1 MB** | 2.12.6, #7960 |
| `max_mem_store`, `max_file_store` | restart | **may be increased (not decreased) by config reload** | 2.12.7, #8014 |
| consumer start-sequence scan | pauses the metalayer | **asynchronous** | 2.12.8, #8051 |
| the filestore block skip check | always | **skipped above a subject-count threshold**, "as it could result in runaway CPU usage" | 2.12.10, #8227 ("Enforce cardinality threshold on `checkSkipFirstBlock`…") |
| JSONP on monitoring endpoints | supported | **removed** | 2.12.12 |
| **concurrent disk I/O** | CPU-scaled | **4096 slots**; `jetstream { max_concurrent_io }` (server bounds 4 – 8192, `dios.go` at v2.14.6) | 2.12.14, #8336 — documented nowhere, `inbox/docs-issues.md` #59 |

## Config keys, headers and fields that arrived

| key or field | release, PR | note |
|---|---|---|
| **atomic batch publish** — `Nats-Batch-Id`, `Nats-Batch-Sequence`, `Nats-Batch-Commit` (ADR-50) | 2.12.0, #6966 … #7330 | 2.12.1: deduplicates on `Nats-Msg-Id` (#7391), rejects unsupported commits (#7368); 2.12.2: the unsupported-header check fixed (#7436), a deadlock with direct get (#7458); 2.12.9: an *unsupported* advisory on API-level mismatch (#8082); 2.12.12: end-of-batch max-size checks and R1 rewrites (#8305). See [[publishing]] |
| **counter streams** — `Nats-Incr` (ADR-49) | 2.12.0, #6973 #6988 #7081 #7118 | 2.12.10: configuration constraints (#8240); **2.12.12: "counter stream staging no longer corrupts the committed running total" (#8311)** |
| **`prioritized`** priority policy (ADR-42) | 2.12.0, #7113 | see [[priority-groups]] |
| **`proxies { trusted [ … ] }`** — trusted proxies (ADR-55) | 2.12.0, #7153 | `parseProxies`, `opts.go:5720` at v2.14.6; documented nowhere — #60. `authorization { proxy_required }` is documented |
| **mirror promotion** — remove the `mirror` configuration | 2.12.0, #7171 | "cannot be undone and also requires configuring the stream subjects" |
| **delayed scheduling** — `Nats-Schedule-TTL`, single schedules (ADR-51) | 2.12.0, #7170 #7245 #7319 | cron and `@every` are 2.14 ([[message-scheduling]]); 2.12.1: deactivated when followed by an unscheduled message (#7366), triggers after recovery (#7347); 2.12.8: `Nats-Schedule-Next: purge` errors when scheduling is off (#8035); 2.12.9: schedule subjects corrupted on recovery (#8085) |
| **offline assets** (ADR-44) | 2.12.0, #7158 | also 2.11.9, so a downgrade lands on a server that knows them |
| `partition(n)` and `random(n)` subject transforms | 2.12.0, #6950 | |
| **`Nats-Required-Api-Level`** request header | 2.12.0, #7157 | 2.12.4: the error only after other checks (#7711) |
| async writes opt-in (`persist_mode: async`) | 2.12.0, #7315 #7323 | |
| **`server_metadata { }`** | 2.12.0, #6935 | |
| `leader_since` in stream and consumer info | 2.12.0, #7189 (and 2.11.9) | |
| **`leafnodes { isolate_leafnode_interest }`** | 2.12.0, #7238 #7243 #7277 | |
| `leafnodes { remotes [ { disabled } ] }`, reloadable | 2.12.0, #7054 | |
| `tls { allow_insecure_cipher_suites }`; `X25519MLKEM768` in `curve_preferences` | 2.12.0, #7144 #7280 | |
| **`Nats-Subject`** header on a no-responders error — "the original subject" | 2.12.0, #5250 | see [[cross-account-sharing]] |
| `exact_match` on monitoring filters (server name, host, cluster) | 2.12.0, #7260 | |
| **`write_deadline`** in `cluster`, `leafnodes`, `gateway` | 2.12.1, #7405 | the config reference gives `10s` for each |
| `leafnodes { remotes [ { proxy { url, username, password, timeout } } ] }` — HTTP proxy for WebSocket leafnodes; HTTP CONNECT for plain leafnodes from 2.12.6 (#7781) | 2.12.1, #7242 | |
| `NewServerFromConfig` (embedded) | 2.12.1, #7364 | |
| **`proxy_protocol: true`** — PROXY protocol v1 and v2 on client connections | 2.12.2, #7456 | 2.12.9: works with TLS listeners (#8130); 2.12.12: detection, TLS sniffing with `allow_non_tls`, v1 address-family parsing fixed (#8302) |
| `jetstream { meta_compact, meta_compact_size }`; `write_timeout` | 2.12.2, #7484 #7521; "#7513" | as in 2.11.11 |
| expvar `/debug/vars` on the monitoring port | 2.12.2, #7469 | |
| `websocket { ping_interval }` (the body: `ping_internal`) | 2.12.3, #7614 | |
| `tls_cert_not_after` in `/varz` | 2.12.4, #7709 | undocumented, #57 |
| snapshot `window_size` | 2.12.5, #7839 | undocumented — noted on #57 |
| **`jetstream { meta_compact_sync }`** | 2.12.5, #7827 #7846 | the mitigation for the 2.12.5 warning |
| `max_conns: 0` | 2.12.5, #7877 | |
| `$SYS.REQ.USER.INFO` returns the account and user nametag | 2.12.6, #7973 | |
| `peer-remove` by peer ID | 2.12.6, #7952 | |
| **`in_client_msgs`, `in_client_bytes`, `out_client_msgs`, `out_client_bytes`** in `/varz` — "data to/from normal clients only" | 2.12.9, #7851 | undocumented — noted on #57 |
| the client ID through the embedded `ClientAuthentication` API | 2.12.10, #8217 | |
| **`jetstream { max_concurrent_io }`** | 2.12.14, #8336 | #59 |

## Behaviours that changed — the "now" and "no longer" lines

- **Leafnode connections without auth no longer land in the global account** (2.12.0, #7116 "Leaf
  node without auth doesn't default to global account") — see [[unauthenticated-clients-still-connect]].
- **Raft nodes no longer answer catch-up messages with success when not leader**, "fixing some
  potential stream desync scenarios" (2.12.0, #6944); no append entries in a known non-leader state
  (#7297); "The Raft layer no longer commits entries from previous terms" (2.12.6, #7955); forwarded
  proposals accepted "only if caught up as the new leader, limiting potentially unbounded log growth"
  (2.12.5, #7809); the cluster size is no longer restored to 1 at startup, "which could result in an
  isolated node incorrectly winning a single-node election" (2.12.5, #7850); **nodes no longer vote or
  campaign after write errors** (2.12.12, #8290); elections ignore votes from removed peers (2.12.14,
  #8353).
- **`$SYS.REQ.CLAIMS.DELETE` strips headers** like `UPDATE` does (2.12.1, #7413).
- **Consumers with overlapping filter subjects "where one is not a subset of the other" are allowed**
  (2.12.5, #7810); a message at `max_deliver` is preserved on WorkQueue streams (#7845); consumer
  naming is consistent between the current and legacy create endpoints (#7848).
- **Client connections are no longer registered after an auth-callout timeout** (2.12.6, #7932); the
  service-import cycle detection catches a genuine cycle (#7961); **the orphan-consumer check no
  longer deletes direct consumers, "which could affect sourcing and mirroring"** (#7957); a Windows
  service enters lame duck and exits correctly (#7958).
- **The stale `Message Not Found` regression** — 2.12.7's filestore change ("Filestore restore stale
  fblk for MaxMsgsPer>1 with FIFO removal", #8285) left subject-state tracking stale on streams with
  `max_msgs_per_subject`; fixed in 2.12.11, which says "v2.14.x versions are not affected".
- **Roll-ups apply on interest streams with no interest** (2.12.8, #8019); **a `Nats-Msg-Id` is no
  longer deduplicated in a mirror** (#8043); consistency checks use the transformed subject (#8022);
  **stream sourcing no longer duplicates after a leafnode reconnect or a failed proposal** (#8069);
  path separators are refused in asset names.
- **Pending is calculated only on consumer leaders** (2.12.9, #8172); mirror consumers retry
  immediately on a last-sequence mismatch (#8152); a source consumer in set-up is not scheduled again,
  "avoiding potential setup storms" (#8111); the delivery policy is enforced on clustered WorkQueue
  consumers (#8126); a consumer file store flushes on a single redelivery delete, "avoiding
  unexpected further redeliveries" (#8168).
- **Purges behave the same on file and memory stores** (2.12.10, #8241); scale-down is consistent
  (#8253); the per-subject last block is stored correctly with a limit of 1 (#8254).
- **Service-import replies are delivered across cluster routes** (2.12.12, #8317); message tracing
  works with imports and exports; `NoAuthUser` checks connection restrictions; inherited JWT default
  permissions refresh on a claims update (#8276); a stream catch-up is no longer skipped when limits
  are exceeded, "preventing possible stream desync" (#8265); zero consumer limits mean unlimited on a
  stream update (#8286).
- **2.12.14's security batch, without CVE ids**: "an authentication bypass with TLS `verify_and_map`
  authenticating users with blank passwords"; "combining `no_auth_user` with auth callouts will no
  longer skip authentication checks when no `CONNECT` message is sent"; JWT validation no longer
  crashes on whitespace-only permissions; queue-subscription permission paths "no longer treat the
  whole permission as a subject literal"; JetStream and MQTT endpoints guard against JSON nulls. Also:
  `healthz` skips expired JWT accounts (#8379); `/varz` reports JetStream limits after a reload
  (#8394); a publish exceeding the maximum store size is rejected before proposal (#8389); encryption
  key files are synced "more aggressively" (#8366); a consumer's storage type cannot be changed by
  update (#8382); a stream recreated while a node was down is not taken for an update by the
  returning node, "avoiding stale Raft groups from continuing to run" (#8413).

## Warnings and regressions

- **2.12.5** — `> [!WARNING] A regression has been found in this version where a stream update may
  result in the loss of consumers in clustered deployments in specific cases. Single-server
  deployments are not affected. To temporarily mitigate, set `meta_compact_sync: true` in the
  `jetstream` config block and perform a configuration reload.` Fixed in **2.12.6** (#7939 "Stream
  update loses consumers in async meta snapshot"). The 2.12.5 body is the only place the mitigation
  is stated.
- **2.12.7 → 2.12.11** — stale subject-state tracking with `max_msgs_per_subject`, "`Message Not
  Found` errors" (#8285); 2.14 unaffected.
- **2.12.6** — "a regression introduced in 2.12.6" where the `jwt` was not sent to auth callout for
  MQTT clients, fixed in 2.12.7 (#7997, #7999).
- **2.12.7's CVE section reads `TBD`**, as 2.11.16's does.

## Data-integrity and data-loss fixes

| release | fix |
|---|---|
| 2.12.0 | catch-up success no longer sent when not leader (#6944); empty-log protection (#7038); filestore write correctness "particularly when combined with async mode" (#7318, #7331); blocks with unexpected sequence ordering recovered (#7303 …) |
| 2.12.1 | meta files staged through temporary files, "avoiding accidental truncation on crashes" (#7388); tombstones with secure erase, tombstone-only blocks (#7384); skipped sequences ordered before apply (#7400) |
| 2.12.3 | `DiscardNewPerSubject` enforced by the leader (#7607); the `AsyncFlush` pending-write loss (#7594); atomic compaction (#7627); the Raft membership batch |
| 2.12.5 | tombstones always used for trailing deletes (#7782); the #7816 filestore batch (checksums after truncation on compressed or encrypted stores, locks not leaked, subject and header corruption avoided); consumer assignments no longer lose transition state "which could lead to issues on recovery or cause consumer state to be lost" (#7905, #7908); tiered reservations (#7880); the `store_max_stream_bytes` / `memory_max_stream_bytes` limits no longer applied to account totals — "a long-standing bug" (#7895) |
| 2.12.6 | the 2.12.5 consumer loss (#7939); mirror goroutines stuck "stalling the mirror indefinitely" (#7929); idempotent create with sources (#7928); a stream restore checks the archive's name; commits only from the current term (#7955) |
| 2.12.8 | the cluster sequence no longer advanced on a failed proposal — `last sequence mismatch` (#8057); Raft commit-index reset on term mismatch (#8023); a legacy zero-index snapshot no longer panics (#8039) |
| 2.12.9 | encryption-mode conversion cleared caches, "avoiding block-level corruption" (#8105, #8166); Raft ignores temporary snapshots after a crash (#8101); append-entry caches invalidated on truncation and snapshot install (#8149); no proposals to remove unknown peers (#8154); metalayer state preserved on shutdown (#8199) |
| 2.12.10 | peer-set drift after removing an online node (#8258); Raft peers tracked after an inactivity stall (#8226) |
| 2.12.12 | **counter staging corrupting the running total (#8311)**; **compaction corrupting compressed or encrypted blocks (#8312)**; catch-up not skipped over limits (#8265); malformed TTL and schedule state rejected (#8269); phantom streams and consumers after meta recovery (#8324); uncommitted membership changes reverted on truncation (#8332); peer-state decoding bounded (#8310) |
| 2.12.14 | malformed replicated acks, delivered updates, skips and resets rejected; empty entries ignored; oversized entries and AVL node counts validated on 32-bit (#8284, #8345, #8347, #8355, #8357); recreated streams not taken for updates (#8413) |
| 2.12.15 | **"potential data loss when handling idempotent stream creates when an offline node catches up from a metalayer snapshot, caused by an incorrect update to the create time in the stream assignment" (#8449)** |

## CVEs

The same identifiers as the 2.11 line, on the same days: 2.12.5 (CVE-2026-29785, CVE-2026-27889),
2.12.6 (the ten of 2026-03-24), 2.12.7 (`TBD`) — the table is in [[s-relnotes-2.11]]. 2.12.12 and
2.12.14 each carry a security batch without identifiers (above).

## The docs' upgrade guide against the bodies

[[s-docs-upgrade-to-2.12]] read line by line against the 2.12.0 body:

- **Confirmed by the body**: atomic batch, counters, scheduling, `prioritized`, `server_metadata`,
  mirror promotion, exponential backoff, offline assets, async flush, elastic (weak) pointers,
  cipher suites, `partition(n)` / `random(n)`, account and user in log lines, `isolate_leafnode_interest`,
  `disabled` remotes, strict mode by default, the v2.11.9 floor.
- **Not in the bodies**: "System events for the `$G` account" (guide line 42) — no 2.12 body mentions
  `$G` events; the bodies neither confirm nor deny it.
- **Wrong**: "`GOMAXPROCS` and `GOMEMLIMIT` in server stats" (guide line 44) is presented as new in
  2.12. The bodies date it to **2.10.28 and 2.11.2** (2025-04-25, #6791, merged 2025-04-11);
  `inbox/docs-issues.md` #58.
- **The guide omits** the API level 2, the `max_buffered_msgs` ×10, the TCP-keepalive change, trusted
  proxies, `Nats-Required-Api-Level`, the `Nats-Subject` header, `exact_match`, and everything after
  2.12.0.

## Corrections and notes

1. **`max_buffered_msgs`**: the docs' 10,000 is the 2.11 default; 2.12.0 raised it ×10 (#6633). #22
   extended with the history.
2. **`max_concurrent_io`** (2.12.14 / 2.14.4): `dios.go` at v2.14.6 — `defaultConcurrentIOs = 4096`,
   `minConcurrentIOs = 4`, `maxConcurrentIOs = 8192`, clamped in `newDiskIOSemaphore`; parsed at
   `opts.go:2789–2794`. Documented nowhere — #59.
3. **`proxies { trusted [ … ] }`** (2.12.0, ADR-55): `parseProxies` at `opts.go:5720`; the docs know
   only `proxy_required` and the `Proxy is not trusted` error — #60.
4. The `write_timeout` body cites "#7513", a cherry-pick PR, as in 2.11.11; `ping_internal` again in
   2.12.3; "400 No Messages" again in 2.12.2 (the server sends 404).

## Relevance to the wiki

The 2.12 line is the current upgrade *from*, and its patches are the 2.14 patches under another
number: an operator on 2.12 reading [[nats-server-2.14]]'s fixes has most of them in 2.12.9–2.12.15.
The three hazards — the 2.12.5 consumer loss, the 2.12.7 → 2.12.11 `Message Not Found` regression,
the 2.12.15 idempotent-create data loss — join [[upgrade-a-cluster]]; `max_concurrent_io` and the
4096-slot semaphore join [[jetstream-sizing]]; the counter-corruption and compaction-corruption fixes
of 2.12.12 are the reason not to run 2.12.9–2.12.11 with counters, compression or encryption.

## Questions it answers

Rows 64 and 130 in part (the data-integrity table, the 2.12.5 warning); 63 in part; 9 and 13 in part
(the cardinality threshold of 2.12.10, the async start-sequence scan of 2.12.8, the 4096-slot
semaphore of 2.12.14); 139 in part (the client-only counters of 2.12.9 exist; their exactness is not
stated).

## Pages touched

[[nats-server-2.12]] · [[nats-server-2.14]] · [[upgrade-a-cluster]] · [[publishing]] ·
[[message-scheduling]] · [[priority-groups]] · [[stream]] · [[consumer]] · [[retention-policies]] ·
[[key-value]] · [[mirrors-and-sources]] · [[js-api]] · [[raft-in-nats]] · [[meta-layer]] ·
[[replicas]] · [[monitoring-endpoints]] · [[tls-in-nats]] · [[leafnode]] · [[websocket]] · [[mqtt]] ·
[[account]] · [[subject-permissions]] · [[auth-callout]] · [[cross-account-sharing]] ·
[[run-nats-behind-a-proxy]] · [[slow-consumer-detected]] · [[jetstream-sizing]] ·
[[filestore-layout]] · [[jetstream-recovery-is-slow]] · [[jetstream-out-of-disk]] ·
[[consumer-keeps-redelivering]] · [[backup-and-restore-jetstream]] · [[evict-a-sick-server]] ·
[[reload-server-config]] · [[install-nats-server]] · [[unauthenticated-clients-still-connect]] ·
[[config-keys]] · [[defaults-and-limits]] · [[error-codes]] · [[subject-transforms]]
