---
title: nats-server 2.11
type: entity
kind: release
area: [deploy, jetstream]
since: [2.11]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [release, 2.11, api-level-1, ttl, priority-groups, tracing, cve, withdrawn, changelog]
aliases: ["2.11", v2.11, v2.11.0, v2.11.2, v2.11.9, v2.11.17, v2.11.1-binary]
sources: [s-docs-upgrade-to-2.12, s-adr-43-per-message-ttl, s-adr-42-priority-groups, s-adr-8-key-value-store, s-docs-raft-and-leaders, s-docs-placement, s-docs-auth-callout, s-relnotes-2.11.2, s-relnotes-2.11.5, s-issue-6921-last-per-subject-acks, s-relnotes-2.10, s-gh-6748-cve-binary-release-docker-images, s-relnotes-2.11]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.11

The minor that introduced **stream API level 1** and the features gated behind it — per-message
TTL, delete markers, priority groups, consumer pause, multi-get — plus message tracing, the config
digest, ingest rate limiting and `cluster_traffic`. **18 releases from 2025-03-19 to 2026-04-27**,
one withdrawn, one CVE as binaries first, and **twelve CVEs closed in its last three releases**,
after 2.12 and 2.14 had shipped. Two versions back from current stable.

## Facts

| | |
|---|---|
| first release | **v2.11.0**, 2025-03-19 |
| last release | **v2.11.17**, 2026-04-27 — three days before 2.14.0 |
| releases in this line | **18** (no 2.11.13); 54 tags from `v2.11.0-preview.1` (2024-02-27) counting previews, release candidates and `v2.11.1-binary` |
| withdrawn | **v2.11.2** — "This version contains a regression that has since been fixed in 2.11.3. Please upgrade to that version instead." |
| **downgrade floor from 2.12** | **v2.11.9** (2025-09-09) or higher — the release that added *offline assets* |
| CVEs | **CVE-2025-30215, CRITICAL** (v2.11.1-binary 2025-03-31, v2.11.1 2025-04-08); CVE-2026-29785 and CVE-2026-27889 (v2.11.14); ten more (v2.11.15); v2.11.16's CVE line reads `TBD` |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md`; the 18 bodies are in
`raw/release-notes/` and read as one changelog in [[s-relnotes-2.11]]; every release with its flags
is a row of `inbox/relnotes-toc.md`. The docs' 2.11 upgrade guide, which every body links, does not
exist (the URL redirects to `/release-notes/`), so the bodies are the record.

## What v2.11.0 added

From the release body (source: [[s-relnotes-2.11]]):

- **JetStream** — **per-message TTL** (`Nats-TTL`, ADR-43) and **subject delete markers**
  (`subject_delete_marker_ttl`, `Nats-Marker-Reason`) — see [[message-ttl]]; **priority groups**
  with pinning and overflow (ADR-42, [[priority-groups]]); **consumer pause** (`PauseUntil`,
  `$JS.API.CONSUMER.PAUSE`); **asset versioning** — API levels (ADR-44); **multi-get** on direct get
  (ADR-31, [[direct-get]]); **pedantic mode**; **stream ingest rate limiting** (`max_buffered_msgs`,
  `max_buffered_size`, a `429 Too Many Requests` reply); `Nats-Expected-Last-Subject-Sequence-Subject`;
  **`cluster_traffic: owner`** to carry an account's Raft traffic in the account rather than the
  system account; `preferred` placement on stepdown; **`jetstream { strict }`** (off by default here,
  on in 2.12); TPM key storage on Windows; a delay on `js_cluster_migrate`.
- **Operations** — **distributed message tracing** (`Nats-Trace-Dest`, `Nats-Trace-Only`); a
  **configuration digest** (`nats-server -t`, `config_digest` in `/varz`);
  `/healthz?js-meta-only=true`; scoped-user templates beyond a subject token; a graceful `SIGTERM`
  **exits 0** instead of 1.
- **Edges** — the leafnode `handshake_first` duration form; WebSocket custom response headers; MQTT
  SparkplugB Aware.
- **Consistency** — acks on clustered interest and WorkQueue streams are proposed through Raft
  ("may increase the amount of replication traffic"); a new leader answers only once up to date
  with its log; replicated consumers no longer skip redeliveries after a leader change; a consumer's
  starting sequence "is now always respected, except for consumers used for sources/mirrors".

## What the patch releases changed

The keys, defaults and behaviours an operator on 2.11 lives with, by release (all from
[[s-relnotes-2.11]], which has the full tables and PR numbers):

| release | change |
|---|---|
| 2.11.1 | CVE-2025-30215; system API calls validate the calling account |
| 2.11.2 | **withdrawn**; replicated consumers wait for quorum before delivering (throughput caveat); `default_sentinel`; `trace_headers`; delete markers on TTL expiry; the 2.10.28 backports (32 MB cap, five-minute peer re-admission) |
| 2.11.3 | the 2.11.2 regression fixed; `mqtt { js_api_timeout }` |
| 2.11.4 | **stream and consumer updates refused when all peers are offline** ("a potential avenue for data loss"); WorkQueue sequences survive a crash with unflushed data; TLS handshake errors log the certificate |
| 2.11.5 | `DeliverLastPerSubject` acks with interior deletes; Raft on monotonic time; `healthz` stops fixing up node skews; `/connz` includes leafnodes |
| 2.11.6 | **a filtered-consumer throughput regression present since 2.11.0 fixed**; filestore encryption could corrupt a block after a restart |
| 2.11.7 | Raft recovers and snapshots before campaigning; pull consumers with an inactive threshold count pending acks; TTLs over an hour expired late; enabling TTLs scans existing messages |
| 2.11.8 | Raft steps down on a higher term during catch-up; `healthz` no transient errors for new or deleted consumers |
| 2.11.9 | **offline assets** — the downgrade floor from 2.12; `leader_since`, `system_account`, `traffic_account` in info and `/jsz`; connection-limit JWT updates disconnect the newest clients |
| 2.11.10 | meta snapshot regression from 2.11.9 fixed; API requests always from the worker pool; binary search for `opt_start_time` |
| 2.11.11 | **`meta_compact`, `meta_compact_size`**; **`write_timeout`** (`default` / `retry` / `close`); streams loaded in parallel at startup; catch-ups use delete ranges; `healthz` reports catching-up streams as such |
| 2.11.12 | `websocket { ping_interval }`; `tls_cert_not_after` in `/varz`; **switching to interest retention removes no-interest messages from the head**; `AsyncFlush` could lose writes after a pause; a Raft membership batch (last peer cannot be removed, removed peers not counted, peer state written at once); a corrupt file-backed R1 consumer is deleted automatically; seven MQTT fixes |
| 2.11.14 | CVE-2026-29785 (leafnode compression), CVE-2026-27889 (WebSockets) |
| 2.11.15 | ten CVEs; **a 1 MB limit on JWTs**; `peer-remove` by peer ID; `Nats-Trace-Dest` needs publish permission |
| 2.11.16 | `no_auth_user` client connections only; overlapping `deny` wildcards and queue-subscription bypasses closed; leafnode inbound ACLs and `max_payload` enforced |
| 2.11.17 | `/connz` no longer discloses bearer JWTs; repeated `CONNECT` clears subscriptions; JWT validity across midnight |

## Which patch to be on, and why

- **2.11.3, never 2.11.2** — withdrawn for a regression in consumer subject-interest calculation
  (the same one 2.10.28 → 2.10.29 fixed) (source: [[s-relnotes-2.11.2]], [[s-relnotes-2.11]]).
- **2.11.6 or later if consumers filter** — "a performance regression introduced in v2.11.0 which
  could result in abnormally low throughput from filtered consumers and higher GC pressure" (#7015)
  is in every earlier 2.11.
- **2.11.9 or later before any 2.12 rollout** — below it a downgraded server misreads assets created
  under the higher API level; from it they are reported offline and kept safe (#7158). See
  [[nats-server-2.12]] and [[upgrade-a-cluster]].
- **2.11.1 or later, full stop** (CVE-2025-30215), and **2.11.16 or later** for the twelve 2026
  CVEs — the same fixes shipped the same days as 2.12.5–2.12.7 and the 2.14 line.
- **2.11.4 or later on any cluster** — before it a stream or consumer update was accepted with every
  peer offline, "a potential avenue for data loss" (#6856).

## The patch releases, for consumers

- **2.11.2 (2025-04-25) is withdrawn** — its body opens with "This version contains a regression that
  has since been fixed in 2.11.3. Please upgrade to that version instead." It carries the fix for
  acknowledged messages being redelivered after a consumer leader change ("waiting for delivered
  state to reach quorum before delivering new messages"), with the note that this "may negatively
  impact the throughput of replicated consumers" while "R1 consumers, consumers with `AckNone` ack
  policy and ordered consumers are not affected"; plus #6698, preserving redelivered state when the
  consumer leader sits on a lagging follower, and #6798, the 32 MB JetStream publish limit enforced
  against filestore corruption (source: [[s-relnotes-2.11.2]]).
- **2.11.5 (2025-06-26)** fixes issue #6921 — a `last_per_subject` consumer with explicit acks on a
  stream with `max_msgs_per_subject` above 1 stopped registering acks on 2.11.0–2.11.4; #7005 in the
  notes, bisected by a reporter, no PR linked on the issue (source:
  [[s-issue-6921-last-per-subject-acks]], [[s-relnotes-2.11.5]]). The same release moves Raft
  heartbeats and quorum to monotonic time (#6999) and stops `healthz` from fixing up cluster node
  skews (#7001).

The symptom page for both is [[consumer-keeps-redelivering]].

## What 2.10.23 had already done

The consumer-consistency change 2.11.2 describes — waiting for delivered state to reach quorum — has
a 2.10 precursor: "Replicated consumers will no longer update their delivered state until quorum is
reached, fixing some drifts that can occur on a leader change" in **2.10.23** (#6139), stated without
the throughput caveat (source: [[s-relnotes-2.10]]).

## CVE-2025-30215 shipped as `v2.11.1-binary`

The 2.11 line's first patch was the CRITICAL CVE fix: `v2.11.1-binary` on 2025-03-31, binaries
only, and `v2.11.1` a week later on 2025-04-08 — the same day the docker-library pull request for the
official image merged, with the Alpine variants still to be built (source:
[[s-gh-6748-cve-binary-release-docker-images]]). The pattern, and what it means for a Docker or
Helm deployment, is on [[install-nats-server]].

## What other sources attribute to 2.11

- **Per-message TTL** — ADR-43 is tagged `2.11` (source: [[s-adr-43-per-message-ttl]]); the v2.11.0
  body confirms it (#6272 …). See [[message-ttl]].
- **Stream API level 1.** Setting `allow_msg_ttl` or `subject_delete_marker_ttl` requires it, and
  KV limit markers require "NATS Server with API level 1 or newer support (2.11+)". Clients are
  told to assert this with **`$JS.API.INFO`, not the connected server's version string**
  (source: [[s-adr-8-key-value-store]]); the body calls it "asset versioning (ADR-44)".
- **KV max-age limit markers**, and **per-key TTL** built on per-message TTL; the non-direct KV get
  path was removed from the spec in the same revision (source: [[s-adr-8-key-value-store]]).
- **Priority groups** — ADR-42 is tagged `2.11` and describes the `overflow` and `pinned_client`
  policies; the body lists "pinning and overflow". **The third policy, `prioritized`, arrived in
  2.12**, not here (source: [[s-docs-upgrade-to-2.12]]). See [[priority-groups]].
- **`allowed_accounts` on auth callout** — "limits the delegation to the config-defined accounts you
  list", **2.11+** (source: [[s-docs-auth-callout]]). It is what makes a callout rollout incremental:
  the moment `auth_callout` is on, every connection except the `auth_users` entries goes through it —
  including config users with correct passwords — so before 2.11 the switch was all-or-nothing. The
  one exception holds at any version: a connection matching no config user lands in `$G` and always
  goes through the callout, whatever the list says. See [[auth-callout]]. *The 2.11 release bodies
  do not list `allowed_accounts` by name; the attribution rests on the docs page.*
- **`nats stream cluster step-down --preferred <server>`** requires 2.11 or newer
  (source: [[s-docs-raft-and-leaders]], [[s-docs-placement]]); the body: "preferred placement tags or
  clusters using `preferred` when issuing stepdown requests" (#6282, #6284). See [[raft-in-nats]].
- **The strict-JetStream-API warning starts here.** From 2.11 the server *logs* an invalid
  JetStream request; from 2.12 it also **rejects** it (source: [[s-docs-upgrade-to-2.12]]); the body:
  "strict decoding for JetStream API requests with the new `strict` option" (#5858):

```
[WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.test-stream': json: unknown field "unknown"
```

  A cluster still on 2.11 can use those log lines as a pre-flight check for the 2.12 upgrade —
  every one of them becomes a client-visible error afterwards.

## Why the version still matters

- **v2.11.9 is the downgrade floor from 2.12.** Below it, an older server does not recognise 2.12
  features in use and will not put the affected stream or consumer into unsupported/offline mode —
  losing the protection that keeps a rolled-back cluster from misreading newer data. See
  [[nats-server-2.12]].
- **API level 1, not the version string, is the feature gate** for TTLs and KV limit markers. A
  mixed-version cluster can report a 2.11+ binary and still refuse the feature.
- **Four things 2.11 added that the docs do not name** — `cluster_traffic`, `config_digest`,
  `tls_cert_not_after`, `leader_since`, and the duration form of the leafnode `handshake_first` —
  are `inbox/docs-issues.md` #55–#57.

## To verify

- Whether 2.11 is still receiving patches: the newest tag is **v2.11.17 (2026-04-27)**, three days
  before 2.14.0 shipped; the 2.12 line continued to 2.12.15 (2026-08-12). No source read states a
  support or end-of-life policy.

## Related

[[nats-server-2.12]] · [[nats-server-2.10]] · [[message-ttl]] · [[priority-groups]] ·
[[direct-get]] · [[key-value]] · [[raft-in-nats]] · [[upgrade-a-cluster]] · [[nats-server]]

## Sources

[[s-docs-upgrade-to-2.12]] · [[s-adr-43-per-message-ttl]] · [[s-adr-42-priority-groups]] ·
[[s-adr-8-key-value-store]] · [[s-docs-raft-and-leaders]] · [[s-docs-placement]] ·
[[s-docs-auth-callout]] · [[s-relnotes-2.11.2]] · [[s-relnotes-2.11.5]] · [[s-issue-6921-last-per-subject-acks]] · [[s-relnotes-2.10]] · [[s-gh-6748-cve-binary-release-docker-images]] · [[s-relnotes-2.11]]
