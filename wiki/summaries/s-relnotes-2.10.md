---
title: "nats-server 2.10 release notes, v2.10.0 → v2.10.29 (2023-09-19 → 2025-05-01): the change layer"
type: summary
area: [deploy, jetstream, security, topology, monitoring, core, kv, interop]
source-url: https://github.com/nats-io/nats-server/releases
source-path: raw/release-notes/v2.10.0.md, raw/release-notes/v2.10.1.md, raw/release-notes/v2.10.2.md, raw/release-notes/v2.10.3.md, raw/release-notes/v2.10.4.md, raw/release-notes/v2.10.5.md, raw/release-notes/v2.10.6.md, raw/release-notes/v2.10.7.md, raw/release-notes/v2.10.8.md, raw/release-notes/v2.10.9.md, raw/release-notes/v2.10.10.md, raw/release-notes/v2.10.11.md, raw/release-notes/v2.10.12.md, raw/release-notes/v2.10.14.md, raw/release-notes/v2.10.16.md, raw/release-notes/v2.10.17.md, raw/release-notes/v2.10.18.md, raw/release-notes/v2.10.19.md, raw/release-notes/v2.10.20.md, raw/release-notes/v2.10.21.md, raw/release-notes/v2.10.22.md, raw/release-notes/v2.10.23.md, raw/release-notes/v2.10.24.md, raw/release-notes/v2.10.25.md, raw/release-notes/v2.10.26.md, raw/release-notes/v2.10.27-binary.md, raw/release-notes/v2.10.27.md, raw/release-notes/v2.10.28.md, raw/release-notes/v2.10.29.md, raw/nats-server-src/stree-arrival-v2.10.10.md
author: nats-io/nats-server maintainers
date: 2025-05-01          # v2.10.29, the last release of the line; v2.10.0 shipped 2023-09-19
version: "2.10"
article: "The 29 GitHub release bodies of the 2.10 line read end to end as one changelog; RC bodies excluded (folded into each GA body)"
tags: [release, 2.10, changelog, change-layer, defaults, cve, withdrawn, downgrade]
aliases: [v2.10.0, v2.10.1, v2.10.2, v2.10.3, v2.10.4, v2.10.5, v2.10.6, v2.10.7, v2.10.8, v2.10.9, v2.10.10, v2.10.11, v2.10.12, v2.10.14, v2.10.16, v2.10.17, v2.10.18, v2.10.19, v2.10.20, v2.10.21, v2.10.22, v2.10.23, v2.10.24, v2.10.25, v2.10.26, v2.10.27-binary, v2.10.27, v2.10.28, v2.10.29, "2.10 release notes", "2.10 changelog"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server 2.10 release notes, v2.10.0 → v2.10.29: the change layer

The 2.10 line ran **from 2023-09-19 to 2025-05-01**: 29 releases (there is no 2.10.13 — the 2.10.14
body says so; 2.10.15 was never tagged either), 82 tags counting release candidates, one binary-only
security release, one release withdrawn. This summary reads the 29 GitHub release bodies as one
document and keeps what an operator needs from them **by kind of change**, each item with its release
and PR number, so a page can say "since 2.10.x" and point here. It does not repeat the dependency
bumps, the Go versions (in the table) or the *Complete Changes* links. Two releases already have
their own summaries — 2.10.16 and 2.10.17's redelivery fixes in [[s-relnotes-2.11.2]] — and are
folded by reference. The table of all releases is `inbox/relnotes-toc.md`.

Every body from 2.10.3 on opens with "Refer to the 2.10 Upgrade Guide … for backwards compatibility
notes with 2.9.x", linking `docs.nats.io/release-notes/whats_new/whats_new_210`. **That page no longer
exists**: the URL redirects to `/release-notes/` (checked 2026-09-03), and the docs mirror holds
guides for 2.12 and 2.14 only. The bodies below are the only public record of what 2.10 changed.

## The releases at a glance

| release | date | Go | ★ | what an operator needs from it |
|---|---|---|---|---|
| 2.10.0 | 2023-09-19 | 1.21.1 | ★ | the feature release: auth callout, per-account routes, S2 compression on routes, leafnodes and streams, subject transforms, multi-filter consumers, `first_seq`, `metadata`, QoS 2, four new `$SYS.REQ.SERVER` requests, `sync_interval` control; **downgrade floor 2.9.22** |
| 2.10.1 | 2023-09-20 | 1.21.1 | ★ | three fixes (leafnode TLS handshake, single-filter consumers, consumer limits with explicit ack); repeats the downgrade note |
| 2.10.2 | 2023-10-06 | 1.21.2 | ★ | the **authorization-bypass fix** (#4605); `prof_block_rate`; systemd units switch to SIGUSR2; lame duck now steps JetStream down first |
| 2.10.3 | 2023-10-12 | 1.21.3 | | KV lookups failing after a history decrease (#4656); compaction reclaims more with compression |
| 2.10.4 | 2023-10-27 | 1.21.3 | ★ | **CVE-2023-46129** (nkeys xkeys); `tls.handshake_first` for clients; the MQTT keys that decline QoS 2; AckTerm advisory gains a `reason`; Raft group name in stream and consumer info |
| 2.10.5 | 2023-11-09 | 1.21.4 | | memory with many subjects; 2.9→2.10 meta-file cleanup; `DiscardNew` byte calculation |
| 2.10.6 | 2023-12-01 | 1.21.4 | | filestore state checks; `ocsp_peer_cache` dropped from `/varz` when unused |
| 2.10.7 | 2023-12-06 | 1.21.5 | | per-subject tracking corrupted on a bad `index.db` (#4851); fewer full-state writes |
| 2.10.8 | 2024-01-10 | 1.21.6 | | `tls.certs` (multi-cert); `no_auth_user` may be an nkey; corrupt `psim` detected on recovery; "Account not enabled" when JetStream is called through the system account |
| 2.10.9 | 2024-01-11 | 1.21.6 | | one fix: sources from 2.9.x servers could panic (#4950) |
| 2.10.10 | 2024-02-02 | 1.21.6 | | `cluster.ping_interval`; **the subject tree replaces the per-subject map** (#4960, #4983); ack floor moves on acked redeliveries (#5008) |
| 2.10.11 | 2024-02-15 | 1.21.7 | | placement of streams created in rapid succession (#5079); keys not found after extended downtime (#5054) |
| 2.10.12 | 2024-03-12 | 1.21.8 | | last-sequence drift on clustered streams (#5179); leafnode loop detection on daisy chains; minimum expiry threshold 250ms |
| 2.10.14 | 2024-04-11 | 1.21.9 | | Trail of Bits review fixes; overlapping-subject checks; orphan messages; multiple deliveries decrementing the count (#5305) |
| 2.10.16 | 2024-05-21 | 1.22.3 | ★ | **warning: zero-byte `tav.idx` panics at startup**; `/expvarz`; Left/Right mapping; first *redelivery of acked messages* fix (#5419) |
| 2.10.17 | 2024-06-27 | 1.22.4 | ★ | `/raftz` (experimental); the only `### Changed` of the line (MQTT); replicated-consumer ack consistency (#5524, #5482, #5533); audit streams on `$JS.>`/`$SYS.>` need `NoAck`; stree for message-block indexing |
| 2.10.18 | 2024-07-17 | 1.22.5 | | per-subject state fixes; filtered consumers no longer ack inapplicable messages |
| 2.10.19 | 2024-08-27 | 1.22.6 | | `O_SYNC` metadata with `sync: always`; WorkQueue retention removing uncovered messages (#5697); **consumer start sequence no longer clipped (#5785)**; `maximum messages per subject exceeded` with limit 1 + discard new (#5761); bad meta state deleting assets (#5767) |
| 2.10.20 | 2024-08-29 | 1.22.6 | | one fix: **KV CAS regression on R1 introduced in 2.10.19** (#5841) |
| 2.10.21 | 2024-09-26 | 1.22.7 | | `tls.min_version`; **global JetStream API queue limit** (#5900); **`statsz` every 10 s instead of 30 s** (#5925); multiple trusted operators in config; `index.db` recovery |
| 2.10.22 | 2024-10-17 | 1.22.8 | | **warning at startup when the store directory is in a temp folder** (#5935); safer default file permissions; **#5785 reverted** (#6014); replica desync after failed catch-ups; pull consumers stalling at `max_deliver` (#5995); leafnode queue-group balancing |
| 2.10.23 | 2024-12-10 | 1.23.4 | | the Raft consolidation release (70 lines); metalayer recovery groups assets; replicated consumers wait for quorum before updating delivered state (#6139); backoff honours `max_deliver` (#6154); RLE off-by-one removing an extra message (#6111); Windows cert-store options |
| 2.10.24 | 2024-12-17 | 1.23.4 | ★ | CVE-2024-45337 (x/crypto; not vulnerable); reverts a 2.10.23 consumer-info change (#6250); `healthz` fixes |
| 2.10.25 | 2025-01-23 | 1.23.5 | | stream snapshot interval removed; advisories only encoded with interest; **healthz no longer recreates deleted assets** (#6362); JetStream shuts down on a read-only store (#6292); AckAll retry timeouts after restart |
| 2.10.26 | 2025-02-25 | 1.23.6 | | `no_fast_producer_stall`; `first_info_timeout`; `write_deadline` per batch; **service import with no interest returns "no responders"** (#6532); consumer signalling optimised (#6499); disk I/O concurrency raised; `routez.pending_bytes` |
| 2.10.27-binary | 2025-03-31 | 1.24.1 | ★ | **CVE-2025-30215, CRITICAL**, binaries only, source a week later |
| 2.10.27 | 2025-04-08 | 1.24.1 | ★ | the tagged CVE-2025-30215 release; system API calls validate the calling account; limits checked on stream restore |
| 2.10.28 | 2025-04-25 | 1.24.2 | ★ | **withdrawn** ("contains a regression … upgrade to 2.10.29"); peer-removed servers **re-admitted after 5 minutes** (#6815); the same subject importable from several accounts; **32 MB publish limit enforced** (#6798); tombstones on purge/compact; `GOMAXPROCS`/`GOMEMLIMIT` in `/varz` |
| 2.10.29 | 2025-05-01 | 1.24.2 | | fixes the 2.10.28 regression in consumer subject interest (#6845); preferred-leader reporting after scale-up (#6851); `/connz?state=all` |

★ is the table's rule (`inbox/relnotes-toc.md`): changed, removed, downgrade, withdrawn, warning, CVE,
or the first of a minor.

## Defaults, limits and intervals that changed

| what | before | after | release, PR |
|---|---|---|---|
| leafnode connection compression | none | **`s2_auto`**, "to compress relative to the RTT of the hub" | 2.10.0, #4167 #4230 |
| downgrade floor from 2.10 | — | **2.9.22 or a later 2.9 patch**: "the old version will not understand the format on disk" | 2.10.0 body, repeated in 2.10.1 and 2.10.2 |
| S2 writer concurrency on leafnodes | `GOMAXPROCS` | **1**, "to improve performance" | 2.10.2, #4570 |
| minimum interval between full `index.db` state writes | (unstated) | **increased**, "to reduce contention for high-speed ingest in large streams" | 2.10.7, #4858 |
| minimum expiry threshold | (unstated) | **250ms** | 2.10.12, #5206 — the body says no more than that |
| filestore block and per-subject info cache expiry | (unstated) | **increased**, "to help improve performance on sparse streams" | 2.10.17, #5568 |
| JetStream API request queue | unbounded | **a global hard limit** "for protecting the system" — the value is not in the notes; the wiki reads `request_queue_limit` = 10,000 from the 2.14.6 source on [[js-api]] | 2.10.21, #5900 #5923 |
| `statsz` interval | **30 s** | **10 s** | 2.10.21, #5925 |
| default file permissions of the filestore and log files | (unstated) | **"safer"** | 2.10.22, "#6013" — the number cited is the *release* PR, not a change |
| Raft group file sync | its own | **the filestore's `sync_interval`, including `sync: always`** | 2.10.23, #6041 |
| metalayer snapshot frequency | — | **lower**: minimum interval increased, consumer deletes no longer pre-empt | 2.10.23, #6165 |
| stream snapshot interval | a fixed interval | **removed** — "now relying on the compaction minimum" | 2.10.25, #6289 |
| `write_deadline` | applied to the whole outbound buffer | **applied to the current batch of write vectors, at most 64 MB**, "making it easier to configure and reason about" | 2.10.26, #6471 |
| concurrent disk I/O operations JetStream performs | (unstated) | **raised** | 2.10.26, #6449 |
| fast-producer stall gate | — | **"less penalizing"** | 2.10.26, #6568 #6579 |
| maximum publish into JetStream | not enforced | **32 MB, enforced**, "avoiding filestore corruption from overflowing the maximum record length" | 2.10.28, #6798 |
| a `peer-remove`d server | stays out until restarted | **re-admitted automatically after 5 minutes without a server restart** | 2.10.28, #6815 |

## Config keys, flags and fields that arrived

| key or field | release, PR | note |
|---|---|---|
| `auth_callout` block — "Authorization callout extension for delegating to external auth providers" | 2.10.0, #3719 #3784 #3799 #3864 #3987 #4501 #4544 | see [[auth-callout]] |
| per-account routes and multiple routes, "to reduce head-of-line blocking in clustered setups" | 2.10.0, #4001 #4183 #4414 | the pooled routes `/routez` shows; see [[monitoring-endpoints]] |
| `cluster { compression }` — S2 on route traffic | 2.10.0, #4115 #4137 | |
| `leafnodes { … compression }`, default `s2_auto` | 2.10.0, #4167 #4230 | see [[leafnode]] |
| leafnode `handshake_first` ("TLSHandshakeFirst … before sending connection info") | 2.10.0, #4119 | 2.10.1 fixes the case where the remote has no `tls` block (#4565) |
| leafnode remotes from the same server binding to the same hub account | 2.10.0, #4259 | |
| `logfile_max_num` — auto-rotated files kept | 2.10.0, #4548 | |
| `$SYS.REQ.SERVER.<id>.RELOAD` — reload by a system-account message | 2.10.0, #4307 | see *Subjects and endpoints* |
| `--signal` accepts glob-style PIDs | 2.10.0, #4370 | |
| stream **subject transforms** (`subject_transform`, and republish on mirrors and sources) | 2.10.0, #3814 #3823 #3827 #4035 #4354 #4400 #4403 #4512; #4010 | see [[subject-transforms]]; wildcard-token removal #4152; cluster filtering in account mappings #4175 |
| stream and consumer **`metadata`** | 2.10.0, #3797 | |
| consumer **multiple filter subjects** (`filter_subjects`) | 2.10.0, #3500 #3865 #4008 #4129 #4188 | 2.10.1: a single entry uses the extended format as `filter_subject` did (#4564) |
| stream **`compression`** (S2, file store only) | 2.10.0, #4004 #4072 | see [[stream-compression]] |
| filestore **re-encryption with new keys** | 2.10.0, #4296 | |
| stream **`first_seq`** at creation | 2.10.0, #4322 #4345 | 2.10.28: no longer purged after a restart when the first sequence still matches (#6753) |
| `jetstream { sync_interval }` and `sync: always` — "Added ability to control sync intervals and sync always" (PR #4483's title; the body prints **`sync_internal`**, a typo) | 2.10.0, #4483 | 2.10.19: with `always`, stream and consumer metadata are written `O_SYNC` (#5729) |
| `NATS_STARTUP_DELAY` (Windows service) | 2.10.0, #3743 | |
| embedded: `User.ConnectionDeadline`, disable the JetStream banner | 2.10.0, #3580 #3674; #4261 | |
| MQTT **QoS 2** | 2.10.0, #4349 #4440 | see [[mqtt]] |
| `prof_block_rate` | 2.10.2, #4587 | |
| `tls { handshake_first }` for client connections, opt-in | 2.10.4, #4642 | see [[tls-in-nats]] |
| the MQTT keys that decline QoS 2 — "config options to disable QoS 2 support" (PR #4705 names no key; the config reference documents `reject_qos2_publish` and `downgrade_qos2_subscribe`) | 2.10.4, #4705 | |
| **`tls { certs [ … ] }`** — several certificate/key pairs on one listener | 2.10.8, #4889 | |
| `no_auth_user` may name an nkey user; leafnode authorization accepts nkeys | 2.10.8, #4938; #4940 | |
| `cluster { ping_interval }`, separate from the client one | 2.10.10, #5029 | |
| Left and Right subject-mapping operations | 2.10.16, #5337 | |
| `tls { min_version }` | 2.10.21, #5904 | |
| several `trusted_operators` in a config file | 2.10.21, #5896 | |
| Windows `tls`: `ca_certs_match`, `cert_match_skip_invalid`, `cert_match_by: thumbprint` | 2.10.23, #5115 #6042 #6047 | |
| **`no_fast_producer_stall`** — drop to the slow consumer instead of stalling the producer | 2.10.26, #6500 | see [[slow-consumer-detected]] |
| `leafnodes { remotes [ { first_info_timeout } ] }` — "useful for high latency links" | 2.10.26, #5424 | see [[leafnode]] |
| `max_closed_clients` parsed correctly from the config file | 2.10.26, #6497 | a fix: the key existed, the parser did not read it |
| the same subject imported from several accounts | 2.10.28, #6704 | see [[cross-account-sharing]] |

## Subjects, headers, endpoints and fields that arrived

| what | release, PR |
|---|---|
| `$SYS.REQ.USER.INFO` — "user info" request | 2.10.0, #3671 |
| `$SYS.REQ.SERVER.PING.IDZ` — basic server info | 2.10.0, #3663 |
| `$SYS.REQ.SERVER.<id>.PROFILEZ` — debugging profiles; CPU profiles from 2.10.19 (#5743) | 2.10.0, #3774 |
| `$SYS.REQ.SERVER.<id>.RELOAD` | 2.10.0, #4307 |
| `$SYS.REQ.SERVER.<id>.KICK` and `.LDM` — disconnect, or lame-duck, one client by `id` or `name` (2.10.17: KICK also reaches leafnode connections, #5587) | 2.10.0, #4298 |
| `unique_tag` in `/jsz` and `/varz`; `slow_consumer_stats` in `/varz`; subscription count in `/statz`; `/jsz?raft=1` | 2.10.0, #3617 #4330 #3875 #3914 |
| the original timestamp as a header on republished messages | 2.10.0, #3933 |
| `reason` on the AckTerm advisory | 2.10.4, #4697 |
| Raft group name in stream and consumer info | 2.10.4, #4661 |
| higher-fidelity client info in JetStream advisories — then **removed again** from assignment proposals, API advisories and snapshot/restore advisories in 2.10.25 (#6326, #6338) | 2.10.10, #5019 #5026 |
| `/expvarz` | 2.10.16, #5374 |
| **`/raftz`**, "experimental … for diagnostic purposes" | 2.10.17, #5530 |
| `StreamLeaderOnly` filter on `/jsz` | 2.10.19, #5704 |
| pending JetStream API request count in `statsz` and `/jsz` | 2.10.21, #5923 #5926 |
| `gatewayz` subscription info; `raftz` and `ipqueuesz` over the system account; `routez.pending_bytes` | 2.10.26, #6525 #6439 #6476 |
| `GOMAXPROCS` and `GOMEMLIMIT` in `statsz` and `/varz` | 2.10.28, #6791 |
| `/jsz` paginates with `offset` (fix); `/connz?state=all` returns open connections (fix) | 2.10.28, #6794 #6816; 2.10.29, #6849 |

**The docs never mention four of these.** `RELOAD`, `KICK`, `LDM` and `PING.IDZ` appear nowhere in the
docs tree (grep of `raw/nats-docs/` on 2026-09-03: the tree names only `PING.VARZ` and
`PING.PROFILEZ` under `$SYS.REQ.SERVER`), while `server/events.go` at v2.14.6 declares all four
(lines 62, 63, 70 and the `IDZ` handler at 1268). Recorded as `inbox/docs-issues.md` #54.

## Behaviours that changed — the "now" and "no longer" lines

- **A `limits` stream may be switched to `interest` retention** by stream update (2.10.0, #4361). See
  [[retention-policies]] for why that swap still rewrites history.
- **Lame duck mode steps JetStream down first**, "to signal transfer of leadership if the leader"
  (2.10.2, #4579); the systemd unit examples switched to SIGUSR2 for shutdown (#4603).
- **Calling the JetStream API through the system account** returns "Account not enabled" (2.10.8,
  #4910).
- **An orphaned Raft group is detected and deleted** by a self-healing mechanism (2.10.0, #4510).
- **Acking a redelivered message with more pending moves the ack floor** (2.10.10, #5008).
- **Consumer start sequence was no longer clipped into the stream** (2.10.19, #5785) — and **that was
  reverted in 2.10.22** (#6014) because "sourcing/mirroring consumers could skip messages"; the public
  thread is [[s-gh-6005-sourcing-memory-stream-restart]].
- **A stream that captures `$JS.>`, `$JS.API.>`, `$JSC.>` or `$SYS.>` is only allowed with `NoAck`**,
  "avoiding potential misconfiguration that could affect the JetStream API"; `$JS.EVENT.>` and
  `$SYS.ACCOUNT.>` stay allowed (2.10.17, #5548 #5556); 2.10.28 tightens the overlap check "so that
  badly-configured streams should not be able to break the API" (#6786). See [[stream]].
- **MQTT no longer waits for JetStream responses when a session disconnects** — the line's one
  `### Changed` entry (2.10.17, #5575).
- **Orphaned ephemeral consumer clean-up is logged at debug level only** (2.10.21, #5917).
- **A warning is logged at startup if the JetStream store directory appears to be in a temporary
  folder** (2.10.22, #5935). See [[stream-directories-disappear]].
- **Queue groups are load-balanced over leafnode connections** (2.10.22, #5982) and from leafnodes in
  a cluster (2.10.23, #6043); interest propagation distinguishes leaf subscriptions from routed ones
  (2.10.23, #6161).
- **Replicated consumers no longer update their delivered state until quorum is reached**, "fixing
  some drifts that can occur on a leader change" (2.10.23, #6139) — the same change 2.11.2 later
  describes with its throughput caveat ([[s-relnotes-2.11.2]]).
- **A consumer detects an ack past the stream's last sequence** and stops registering pre-acks from a
  snapshot (2.10.23, #6109).
- **Health checks no longer re-evaluate stream and consumer assignments**, "avoiding some streams
  and consumers being unexpectedly recreated shortly after a deletion" (2.10.25, #6362). See
  [[meta-layer]].
- **JetStream shuts itself down when the store's filesystem has become read-only** (2.10.25, #6292).
- **Advisories are only encoded and sent when there is interest** (2.10.25, #6341).
- **A request through a service import with no interest returns "no responders"** "instead of silently
  dropping the message" (2.10.26, #6532). See [[cross-account-sharing]].
- **Consumers created or recreated while a node was down** are handled correctly after a snapshot
  when it returns (2.10.26, #6507).
- **Auth callout authenticates username/password and tokens from a leafnode connection** (2.10.26,
  #6492); **callout users can be revoked** (2.10.17, #5555 #5561); **scoped users are bound
  correctly** (2.10.10, #5013).
- **Import/export cycles are detected** (2.10.17, #5494); **imports are available to a client after a
  server restart** (2.10.17, #5588 #5589).
- **Auth tokens are redacted in trace logs**; trapped signals are logged at notice level (2.10.28,
  #6808, #6800).
- **A peer-removed server is re-admitted after 5 minutes** without a restart (2.10.28, #6815). See
  [[evict-a-sick-server]].
- **`nats-server --js --store_dir …` survives a config reload** — before 2.10.28 the reload disabled
  JetStream (#6609). See [[reload-server-config]].

## Withdrawn releases, warnings and regressions

- **2.10.16** — `> [!WARNING]`: "A possible regression may result in a server panic at startup when
  `tav.idx` files were incorrectly truncated down to zero bytes"; work-around: delete the zero-byte
  `tav.idx` files before starting; they come from "a previous server crash before a successful file
  sync to disk". 2.10.17 then "avoid[s] panic on corrupted TAV file" (#5464).
- **2.10.19 → 2.10.20** — "Fix regression in KV CAS operations on R=1 replicas introduced in
  v2.10.19" (#5841), two days later.
- **2.10.19 → 2.10.22** — #5785 (no clipping of the consumer start sequence) reverted by #6014.
- **2.10.23 → 2.10.24** — a 2.10.23 change "could potentially cause a consumer info call to fail if it
  takes place immediately after the consumer was created in some large or heavily-loaded clustered
  setups"; reverted (#6250).
- **2.10.28 is withdrawn** — `> [!IMPORTANT] This version contains a regression that has since been
  fixed in 2.10.29. Please upgrade to that version instead.` 2.10.29 names it: "a regression
  introduced in v2.10.28 which can affect calculating consumer subject interest" (#6845).
- **2.10.17** fixes "a performance regression in `LoadNextMsg` with very sparse or no messages"
  (#5475) — the body does not say which release introduced it.

## Data-integrity and data-loss fixes

The lines an operator weighs when deciding how far to upgrade (rows 64 and 130). The wording is the
release body's, shortened.

| release | fix |
|---|---|
| 2.10.0 | downgrading below **2.9.22** leaves the on-disk format unreadable |
| 2.10.2 | duplicate messages sourced on leader failover (#4592); excess messages in a stream with `MaxMsgsPerSubject=1` from lookup misses (#4631); a purge of the entire stream when targeting sequence `1` (2.10.4, #4698) |
| 2.10.3 | stream and KV lookups fail after decreasing history size (#4656) |
| 2.10.5 | meta files not removed after the 2.9→2.10 conversion (#4733); `DiscardNew` exceed-bytes miscalculated (#4772) |
| 2.10.7 | per-subject tracking corrupted on recovery of a bad or missing `index.db` (#4851) |
| 2.10.8 | corrupt `psim` subjects detected on `index.db` recovery (#4890); snapshots no longer written before recovery completes (#4927) |
| 2.10.11 | keys not found after restarts following extended downtime (#5054) |
| 2.10.12 | drift assigning last sequences on clustered streams (#5179) |
| 2.10.14 | overlapping subject checks letting several consumers or streams bind the same subjects (#5224); orphan messages (#5227); a corrupt message block during indexing (#5238); valid messages skipped when loading from the filestore (#5266); the same message delivered several times, decrementing the delivery count (#5305); ack floor higher than the last known state now forces a standard purge (#5293) |
| 2.10.16 | redelivery of acked messages during server restarts (#5419); stream catch-up after a crash and restart (#5362); tombstones held for previous blocks on compact (#5426) |
| 2.10.17 | redelivery after a successful ack during rollout restarts (#5482); follower stores inheriting the redelivered sequence (#5533); last sequence reset on restart (#5497); streams from failed snapshot restores cleaned up (#5549) |
| 2.10.19 | messages incorrectly removed from a WorkQueue stream whose consumers did not cover the subject space (#5697); bad meta state on restart deleting assets (#5767); expected-last-sequence-per-subject drift between leader and followers (#5794); stream snapshots on graceful shutdown (#5809) |
| 2.10.22 | replica desync after stalled or failed catch-ups (#5939, #5986); unusually large blocks from many tombstones (#5973); sourcing consumers skipping messages (#6014); consumers stuck on WorkQueue streams with per-subject limits (#6003) |
| 2.10.23 | an off-by-one in the run-length encoding of interior deletes "could incorrectly remove an extra message" (#6111); the leader's snapshot replaced on shutdown, causing a desync (#6053); subject state cleared on in-memory compaction, fixing replica drift (#6187); Raft entries not certainly applied during a shutdown no longer reported as applied (#6087, #6133) |
| 2.10.25 | partial writes detected consistently (#6283); health checks recreating deleted assets (#6362) |
| 2.10.26 | consumers skipping messages on interest or WorkQueue streams (#6526); proposals dropped after a peer remove → stream desync (#6456); desync when the server exits during a catch-up (#6459); delete map cleanup so `index.db` recovers correctly (#6515); replica drift when the ack floor runs ahead of the stream applies (#6519); `max_deliver` state preserved on interest streams so a new consumer does not remove the message (#6575) |
| 2.10.28 | first sequence preserved on rebuild after bad checksums (#6647); tombstones written on purge and compact, "fixing a bug that could result in some deleted messages returning if the stream index had to be rebuilt" (#6685); a `first_seq` stream no longer purged after a restart (#6753); stream sequence numbers no longer lost when the server is interrupted, "particularly noticeable with WQ or interest retention" (#6778); the 32 MB publish cap (#6798) |

## CVEs

| release | CVE | what the body says |
|---|---|---|
| 2.10.4 | **CVE-2023-46129** | "nkeys: xkeys seal encryption used fixed key for all encryption" (advisory `secnote-2023-02`) |
| 2.10.24 | CVE-2024-45337 | in `x/crypto`; "the NATS Server does not use the affected functionality and is therefore not vulnerable" |
| 2.10.27-binary, 2.10.27 | **CVE-2025-30215, CRITICAL** | "affecting all NATS Server versions from v2.2.0, prior to v2.11.1 or v2.10.27"; binaries on 2025-03-31, "public disclosure … no sooner than a week", the tag on 2025-04-08 with "correctly validate the calling account on a number of system API calls" and "check system and account limits when processing a stream restore" |

The Docker-image side of a binary-only release is [[s-gh-6748-cve-binary-release-docker-images]].

## Performance lines an operator would cite

- 2.10.0: replicated streams with many interior deletes ("common in large KVs") need far less CPU and
  memory for snapshots (#4070, #4071, #4075, #4284, #4520, #4553); filestore meta indexing rewritten,
  "significantly reducing time to recover streams at startup" (#4450, #4481).
- 2.10.5, 2.10.6: memory with many subjects (#4742, #4806); 2.10.10: subject index memory (#4960,
  #4983) — **this is where `server/stree/` arrives**, see below.
- 2.10.17: stree for message-block subject indexing instead of hash maps (#5559), `node48` (#5585);
  2.10.23: `node10` for numeric subject spaces (#6106); 2.10.16, 2.10.17: subject matching (#5316 …).
- 2.10.21, 2.10.23: `index.db` recovery from old or corrupt state (#5893, #5901, #5907); metalayer
  recovery grouping assets, "reducing the chance of ghost consumers and misconfigured streams
  happening after restarts" (#6066, #6069, #6088, #6092); consumer creation "considerably faster"
  with multi-subject num-pending (#6089, #6112).
- 2.10.26: consumer signalling takes filters into account, "significantly reducing CPU usage … when
  there are a large number of consumers with sparse or non-overlapping interest" (#6499) — the fix
  behind [[jetstream-slows-as-consumers-grow]]'s question; disk I/O concurrency raised (#6449).
- 2.10.28: KV `PurgeDeletes` (#6801); replicated asset creation campaigns for leadership sooner (#6697).

## Corrections the line forces on this wiki

1. **The subject tree is since 2.10.10, not 2.10.9.** A maintainer wrote ">= 2.10.9" in discussion
   #5202 and three pages repeated it. `server/filestore.go` declares `psim map[string]*psi` at tag
   v2.10.9 and `psim *stree.SubjectTree[psi]` at v2.10.10; `server/stree/` does not exist at v2.10.9;
   the oldest commit on `server/stree/stree.go` is #4960 of 2024-01-20, listed under v2.10.10's
   *Improved*. Evidence with lines: `raw/nats-server-src/stree-arrival-v2.10.10.md`.
2. **`sync_internal` in the 2.10.0 body is a typo** for `sync_interval` (PR #4483: "Added ability to
   control sync intervals and sync always"). A release-notes slip, not a docs issue.
3. **"#6013" under 2.10.22 is the release PR** ("Release v2.10.22"), so the "safer default file
   permissions" line cannot be traced to a change PR from the body alone.

## Relevance to the wiki

The first primary source for what 2.10 changed: until now every "since 2.10" on a page came from an
ADR tag. The line settles three open bank rows — 150 (no responders over an import, 2.10.26), 154
(the sourcing stall, 2.10.19 → 2.10.22) and 155 (the binary-only CVE release) — dates the arrival of a
dozen config keys and six system-account requests, and hands [[upgrade-a-cluster]] its 2.10
hazards: the 2.9.22 floor, the zero-byte `tav.idx`, the withdrawn 2.10.28.

## Questions it answers

Rows 150, 154, 155 (with the two thread summaries); 64 and 130 in part (the data-integrity table);
12 in part (the 32 MB JetStream publish cap, 2.10.28); 9 and 13 in part (the subject tree's arrival).

## Pages touched

[[nats-server-2.10]] · [[upgrade-a-cluster]] · [[stream]] · [[consumer]] · [[ack-and-redelivery]] ·
[[consumer-keeps-redelivering]] · [[retention-policies]] · [[key-value]] · [[mirrors-and-sources]] ·
[[cross-account-sharing]] · [[account]] · [[auth-callout]] · [[tls-in-nats]] · [[leafnode]] ·
[[mqtt]] · [[subject-transforms]] · [[monitoring-endpoints]] · [[reload-server-config]] ·
[[evict-a-sick-server]] · [[install-nats-server]] · [[meta-layer]] · [[raft-in-nats]] · [[js-api]] ·
[[advisories]] · [[slow-consumer-detected]] · [[jetstream-slows-as-consumers-grow]] ·
[[stream-directories-disappear]] · [[maximum-messages-exceeded]] · [[jetstream-out-of-disk]] ·
[[duplicate-messages-across-a-leafnode]] · [[filestore-layout]] · [[jetstream-sizing]] ·
[[jetstream-recovery-is-slow]] · [[defaults-and-limits]] · [[config-keys]] · [[error-codes]] ·
[[worker-pool]] · [[stream-placement]]
