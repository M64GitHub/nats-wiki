---
title: nats-server 2.11
type: entity
kind: release
area: [deploy, jetstream]
since: [2.11]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.11, api-level-1, ttl, priority-groups]
aliases: ["2.11", v2.11, v2.11.0, v2.11.9, v2.11.17]
sources: [s-docs-upgrade-to-2.12, s-adr-43-per-message-ttl, s-adr-42-priority-groups, s-adr-8-key-value-store, s-docs-raft-and-leaders, s-docs-placement, s-docs-auth-callout, s-relnotes-2.11.2, s-relnotes-2.11.5, s-issue-6921-last-per-subject-acks]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.11

The minor that introduced **stream API level 1** and the features gated behind it. Two versions
back from current stable.

## Facts

| | |
|---|---|
| first release | **v2.11.0**, 2025-03-19 |
| latest release | **v2.11.17**, 2026-04-27 |
| releases in this line | 54 tags, from `v2.11.0-preview.1` (2024-02-27) |
| **downgrade floor from 2.12** | **v2.11.9** (2025-09-09) or higher |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md` (GitHub releases API, fetched
2026-08-31).

> **There is no upgrade guide for 2.11 in the docs mirror.** `raw/nats-docs/release-notes/` holds
> only the 2.12 and 2.14 guides. Everything below is attributed to the ADR or doc page that names
> 2.11 explicitly; this page is therefore **not a changelog** and should not be read as complete.

## What it adds (as attributed by other sources)

- **Per-message TTL** — the `Nats-TTL` header, `allow_msg_ttl` and `subject_delete_marker_ttl`.
  ADR-43 is tagged `2.11` (source: [[s-adr-43-per-message-ttl]]). See [[message-ttl]].
- **Stream API level 1.** Setting `allow_msg_ttl` or `subject_delete_marker_ttl` requires it, and
  KV limit markers require "NATS Server with API level 1 or newer support (2.11+)". Clients are
  told to assert this with **`$JS.API.INFO`, not the connected server's version string**
  (source: [[s-adr-8-key-value-store]]).
- **KV max-age limit markers**, and **per-key TTL** built on per-message TTL; the non-direct KV get
  path was removed from the spec in the same revision (source: [[s-adr-8-key-value-store]]).
- **Priority groups** — ADR-42 is tagged `2.11` and describes the `overflow` and `pinned_client`
  policies. **The third policy, `prioritized`, arrived in 2.12**, not here
  (source: [[s-docs-upgrade-to-2.12]]). See [[priority-groups]].
- **`allowed_accounts` on auth callout** — "limits the delegation to the config-defined accounts you
  list", **2.11+** (source: [[s-docs-auth-callout]]). It is what makes a callout rollout incremental:
  the moment `auth_callout` is on, every connection except the `auth_users` entries goes through it —
  including config users with correct passwords — so before 2.11 the switch was all-or-nothing. The
  one exception holds at any version: a connection matching no config user lands in `$G` and always
  goes through the callout, whatever the list says. See [[auth-callout]].
- **`nats stream cluster step-down --preferred <server>`** requires 2.11 or newer
  (source: [[s-docs-raft-and-leaders]], [[s-docs-placement]]). See [[raft-in-nats]].
- **The strict-JetStream-API warning starts here.** From 2.11 the server *logs* an invalid
  JetStream request; from 2.12 it also **rejects** it (source: [[s-docs-upgrade-to-2.12]]):

```
[WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.test-stream': json: unknown field "unknown"
```

  A cluster still on 2.11 can use those log lines as a pre-flight check for the 2.12 upgrade —
  every one of them becomes a client-visible error afterwards.

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


## Why the version still matters

- **v2.11.9 is the downgrade floor from 2.12.** Below it, an older server does not recognise 2.12
  features in use and will not put the affected stream or consumer into unsupported/offline mode —
  losing the protection that keeps a rolled-back cluster from misreading newer data. See
  [[nats-server-2.12]].
- **API level 1, not the version string, is the feature gate** for TTLs and KV limit markers. A
  mixed-version cluster can report a 2.11+ binary and still refuse the feature.

## To verify

- No 2.11 upgrade guide exists in the mirror, and the GitHub release body for **v2.11.0 has not
  been ingested** — only the tag and its date. The feature list above is what other sources
  attribute to 2.11 and is certainly incomplete.
- Whether 2.11 is still receiving patches: the newest tag seen is **v2.11.17 (2026-04-27)**, three
  days before 2.14.0 shipped. No source read states a support or end-of-life policy.

## Related

[[nats-server-2.12]] · [[nats-server-2.10]] · [[message-ttl]] · [[priority-groups]] ·
[[key-value]] · [[raft-in-nats]] · [[upgrade-a-cluster]] · [[nats-server]]

## Sources

[[s-docs-upgrade-to-2.12]] · [[s-adr-43-per-message-ttl]] · [[s-adr-42-priority-groups]] ·
[[s-adr-8-key-value-store]] · [[s-docs-raft-and-leaders]] · [[s-docs-placement]] ·
[[s-docs-auth-callout]] · [[s-relnotes-2.11.2]] · [[s-relnotes-2.11.5]] · [[s-issue-6921-last-per-subject-acks]]
