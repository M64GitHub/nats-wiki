---
title: nats-server 2.10
type: entity
kind: release
area: [deploy, jetstream, kv, objectstore]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [release, 2.10, compression, kv-sources, kv-mirrors, auth-callout, subject-transforms, changelog]
aliases: ["2.10", v2.10, v2.10.0, v2.10.29, v2.10.28, v2.10.27-binary]
sources: [s-adr-8-key-value-store, s-adr-20-object-store, s-gh-4535-unauthenticated-connections, s-gh-5202-max-unique-subjects, s-relnotes-2.11.2, s-relnotes-2.10, s-gh-6748-cve-binary-release-docker-images, s-gh-6005-sourcing-memory-stream-restart]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.10

The oldest minor this wiki covers, and the floor for most of what it describes: auth callout,
subject transforms, multi-subject consumer filters, stream compression, S2 on routes and leafnodes,
KV sources and mirrors, MQTT QoS 2. **29 releases from 2023-09-19 to 2025-05-01**, one withdrawn, one
CVE shipped as binaries a week before its tag.

## Facts

| | |
|---|---|
| first release | **v2.10.0**, 2023-09-19 |
| last release | **v2.10.29**, 2025-05-01 |
| releases in this line | **29** (there is no 2.10.13 — the 2.10.14 body says so — and no 2.10.15); 82 tags counting release candidates and `v2.10.27-binary` |
| **downgrade floor** | **2.9.22 or a later 2.9 patch** — "the old version will not understand the format on disk with the exception 2.9.22 and any subsequent patch releases for 2.9" (v2.10.0 body) |
| withdrawn | **v2.10.28** — "This version contains a regression that has since been fixed in 2.10.29. Please upgrade to that version instead." |
| CVEs | CVE-2023-46129 (v2.10.4); **CVE-2025-30215, CRITICAL** (v2.10.27-binary on 2025-03-31, v2.10.27 on 2025-04-08) |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md`; the 29 release bodies are in
`raw/release-notes/` and read as one changelog in [[s-relnotes-2.10]]; every release with its flags
is a row of `inbox/relnotes-toc.md`. The docs' 2.10 upgrade guide, which every body links, no
longer exists (the URL redirects to `/release-notes/`), so the bodies are the record.

## What v2.10.0 added

From the release body (source: [[s-relnotes-2.10]]):

- **Security** — the `auth_callout` block, "delegating to external auth providers" (see
  [[auth-callout]]); `$SYS.REQ.USER.INFO`.
- **Clustering and leafnodes** — per-account routes and multiple routes "to reduce head-of-line
  blocking"; S2 compression on route connections, and on leafnode connections with the default
  **`s2_auto`**; leafnode `handshake_first`; reconnect jitter. See [[leafnode]].
- **JetStream** — stream **subject transforms** and republish on mirrors and sources
  ([[subject-transforms]]); stream and consumer **`metadata`**; consumers **filtering on multiple
  subjects**; optional **S2 stream compression** on file storage ([[stream-compression]]);
  re-encryption with new keys; **`first_seq`** at creation; control of **`sync_interval`** and
  `sync: always` (the body misspells the key `sync_internal`); a stream may switch from `limits` to
  `interest` retention ([[retention-policies]]); orphaned Raft groups are detected and deleted.
- **Operations** — reload by a system-account message (`$SYS.REQ.SERVER.<id>.RELOAD`), `KICK` and
  `LDM` of one client by id or name, `PING.IDZ`, `PROFILEZ`; `logfile_max_num`; `--signal` with glob
  PIDs; `unique_tag` in `/jsz` and `/varz`, `slow_consumer_stats` in `/varz`, `/jsz?raft=1`. See
  [[monitoring-endpoints]] and [[reload-server-config]].
- **MQTT** — QoS 2, retained messages kept with KV semantics, topics with `.` in them. See [[mqtt]].
- **Filestore** — meta indexing rewritten, "significantly reducing time to recover streams at
  startup"; far less CPU and memory for replicated streams with many interior deletes, "common in
  large KVs".

## What the patch releases changed

The defaults, keys and behaviours an operator on 2.10 lives with, by release (all from
[[s-relnotes-2.10]], which has the full tables and PR numbers):

| release | change |
|---|---|
| 2.10.2 | the **authorization-bypass fix** (#4605, below); `prof_block_rate`; systemd units switch to SIGUSR2; lame duck steps JetStream down first |
| 2.10.4 | `tls { handshake_first }` for clients; the MQTT keys that decline QoS 2; the AckTerm advisory gains a `reason` |
| 2.10.8 | `tls { certs [ … ] }` for several certificate pairs; `no_auth_user` may be an nkey; "Account not enabled" when JetStream is called through the system account |
| 2.10.10 | `cluster { ping_interval }`; **the per-subject index becomes a subject tree** (below) |
| 2.10.16 | `/expvarz`; `> [!WARNING]` — zero-byte `tav.idx` files panic at startup (delete them first) |
| 2.10.17 | `/raftz` (experimental); a stream on `$JS.>`, `$JS.API.>`, `$JSC.>` or `$SYS.>` needs `NoAck`; MQTT no longer waits for JetStream on disconnect |
| 2.10.19 | `O_SYNC` metadata under `sync: always`; consumer start sequence **no longer clipped** (#5785) |
| 2.10.20 | fixes the **KV compare-and-swap regression on R1 that 2.10.19 introduced** |
| 2.10.21 | `tls { min_version }`; a **global JetStream API queue limit**; **`statsz` every 10 s instead of 30 s**; several trusted operators in a config file |
| 2.10.22 | **warns at startup when the store directory looks temporary**; safer default file permissions; **#5785 reverted** — sourcing consumers could skip messages |
| 2.10.23 | the Raft consolidation; replicated consumers wait for quorum before updating delivered state; backoff honours `max_deliver`; Windows certificate-store keys |
| 2.10.25 | the stream snapshot interval removed; advisories only encoded with interest; **health checks no longer recreate deleted assets**; JetStream shuts down on a read-only store |
| 2.10.26 | **`no_fast_producer_stall`**; `first_info_timeout` on leafnode remotes; `write_deadline` applied per batch of at most 64 MB; **a service import with no interest returns "no responders"**; consumer signalling optimised for many sparse consumers |
| 2.10.27 | CVE-2025-30215: system API calls validate the calling account; limits checked on stream restore |
| 2.10.28 | **withdrawn**; a peer-removed server **re-admitted after five minutes**; the same subject importable from several accounts; **32 MB publish cap** enforced against filestore corruption; `GOMAXPROCS` and `GOMEMLIMIT` in `/varz` |
| 2.10.29 | the 2.10.28 consumer-interest regression fixed |

## Which patch to be on, and why

- **Never below 2.10.2.** Before it, declaring an `accounts` block "appears to outright ignore any
  users/creds defined in `authorization`" — so a config with a `$SYS` account and top-level
  `authorization` users accepted connections **with no credentials at all**, landing them in the
  still-active default `$G`. A maintainer confirmed it as a bug, filed
  [PR #4605](https://github.com/nats-io/nats-server/pull/4605), and stated the release: "Merged, will
  be in **2.10.2** release" (source: [[s-gh-4535-unauthenticated-connections]]); the 2.10.2 body lists
  it as "Prevent bypassing authorization block when enabling system account access in accounts
  block" (source: [[s-relnotes-2.10]]). The narrower trap that survives it — `no_auth_user`, and `$G`
  staying alive when you name only the system account — is on [[account]].
- **2.10.17 or later for replicated consumers** (the redelivery fixes below).
- **Not 2.10.19, 2.10.20 or 2.10.21 if anything sources or mirrors** from a stream that can restart
  empty: 2.10.19 stopped clipping the consumer start sequence into the stream, so a source whose
  upstream came back at sequence 0 stalled and then skipped; 2.10.22 reverted it (source:
  [[s-gh-6005-sourcing-memory-stream-restart]]). 2.10.19 also broke KV compare-and-swap on R1
  buckets, fixed in 2.10.20 (source: [[s-relnotes-2.10]]).
- **2.10.27 or later, full stop**: CVE-2025-30215 is CRITICAL and affects every server "from v2.2.0,
  prior to v2.11.1 or v2.10.27". The fix shipped as `v2.10.27-binary` on 2025-03-31 with the source
  held for a week; the official Docker image is built by Docker's library from a pull request the
  NATS team opens, and its Alpine variants lagged the tag by over a week (source:
  [[s-gh-6748-cve-binary-release-docker-images]]).
- **2.10.29, never 2.10.28** — withdrawn for a regression in consumer subject-interest calculation.
- **On 2.10.16**, delete zero-byte `tav.idx` files before a restart, or move on to 2.10.17.

## Redelivery of acked messages, fixed in 2.10.16 and 2.10.17

Two consecutive releases fixed the same complaint from the restart side: "Fix potential redelivery of
acked messages during server restarts (#5419)" in **2.10.16** (2024-05-21), then "Fix possible
redelivery after successful ack during rollout restarts (#5482)", "Follower stores no longer inherit
the redelivered consumer delivered sequence which could break ack gap fill (#5533)" and "Ensure ack
processing is consistent and correct between leader and followers for replicated consumers (#5524)"
in **2.10.17** (2024-06-27). 2.10.16 also carries a warning of its own — a possible startup panic on
zero-byte `tav.idx` files, with the work-around of deleting them (source: [[s-relnotes-2.11.2]]). A
2.10 cluster that redelivers acked messages around rolling restarts wants 2.10.17 or later; the
symptom page is [[consumer-keeps-redelivering]]. 2.10.23 then made replicated consumers wait for
quorum before updating their delivered state (#6139) — the change 2.11.2 later describes with its
throughput caveat (source: [[s-relnotes-2.10]]).

## The per-subject index, since 2.10.10

From **2.10.10** a file store's per-subject index is an in-memory adaptive radix tree ("stree"): per
subject, the message count and the first and last block, with path compression so only the suffix
is stored at the leaf. A maintainer described it in answer to "how many unique subjects can one
stream hold" — no configured maximum; RAM for the tree is the bound — and dated it ">= 2.10.9"
(source: [[s-gh-5202-max-unique-subjects]]). **The source tree says 2.10.10**: `server/stree/` does
not exist at tag v2.10.9, `fileStore.psim` is a `map[string]*psi` there and a `*stree.SubjectTree[psi]`
at v2.10.10, and the oldest commit on the package is #4960, which the 2.10.10 body lists (source:
[[s-relnotes-2.10]], evidence in `raw/nats-server-src/stree-arrival-v2.10.10.md`). Message-block
subject indexing moved onto the same tree in 2.10.17 (#5559), which also added the `node48` size;
2.10.23 added `node10` for numeric subject spaces. The cost per subject is on [[jetstream-sizing]];
the layout on [[filestore-layout]].

## What other sources attribute to 2.10

- **KV sourced buckets** and **read-replica mirror buckets** — ADR-8 revision 2 (2023-10-16), server
  requirement `2.10.0` (source: [[s-adr-8-key-value-store]]). See [[key-value]].
- **KV bucket compression** — ADR-8 revision 4 (2023-10-25), server requirement `2.10.0`.
- **KV bucket metadata** — ADR-8 revision 8 (2025-02-17), server requirement `2.10.0`.
- **Object Store compression** — ADR-20 revision 3 (2024-02-05), "Data Compression of Object Stores
  for NATS Server 2.10" (source: [[s-adr-20-object-store]]). See [[object-store]].

## Why the version still matters

It is the floor for **`compression: "s2"`** on KV and Object Store buckets, for KV sources and
mirrors, for subject transforms, multi-subject consumer filters and auth callout. A deployment still
on 2.10 has those; anything the wiki tags `since: 2.11` or later it does not. And within the line the
patch matters as much as the minor: the 2.9.22 downgrade floor, the 2.10.19–2.10.21 sourcing window,
the CVE at 2.10.27, the withdrawn 2.10.28.

## To verify

- The last 2.10 tag is **v2.10.29, 2025-05-01** — before 2.12 shipped. Whether the line is still
  supported is **not stated by any source read**; no support-lifecycle document has been ingested.
  The 2.11 and 2.12 lines kept receiving patches through 2026.

## Related

[[nats-server-2.11]] · [[upgrade-a-cluster]] · [[key-value]] · [[object-store]] · [[stream]] ·
[[mirrors-and-sources]] · [[install-nats-server]] · [[nats-server]]

## Sources

[[s-adr-8-key-value-store]] · [[s-adr-20-object-store]] · [[s-gh-4535-unauthenticated-connections]] · [[s-gh-5202-max-unique-subjects]] · [[s-relnotes-2.11.2]] · [[s-relnotes-2.10]] · [[s-gh-6748-cve-binary-release-docker-images]] · [[s-gh-6005-sourcing-memory-stream-restart]]
