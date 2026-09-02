---
title: "nats-server v2.11.5 release notes (2025-06-26) — the DeliverLastPerSubject ack fix (#7005)"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.11.5
source-path: raw/release-notes/v2.11.5.md
author: "nats-io/nats-server maintainers"
article: "Release v2.11.5 body (GitHub release)"
date: 2025-06-26
version: "2.11.5"
tags: [release, 2.11.5, last_per_subject, interior-deletes, ack, redelivery, raft, monotonic-time, healthz, connz, leafnodes]
aliases: [v2.11.5]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.11.5 (2025-06-26) — where issue #6921 was fixed

Read for one line. Issue #6921 ([[s-issue-6921-last-per-subject-acks]]) was closed after a reporter
bisected its fix to this release, and the issue itself names no pull request; this body does. Phase D
will fold it into the per-minor `s-relnotes-2.11`; the whole body is in `raw/release-notes/`.

## Key claims

**The line** (Fixed, JetStream):

- "The consumer `DeliverLastPerSubject` delivery policy now correctly deliver messages and handles
  acks when there are interior deletes, such as when `MaxMsgsPerSubject` limits are in use on the
  stream (#7005)"

**Other fixes an operator would notice**, JetStream:

- "Consumer pull requests with `NoWait` will now return correctly from replicated consumers (#6960)"
- "Consumers that are up against the `MaxWaiting` limit will no longer respond if the request
  heartbeat is set, to avoid client tightloops (#7011)"
- "Stream retention policy changes are now correctly propagated to running consumers in all cases
  (#6995)"
- "Updating the `AllowMsgTTL` setting on a stream will now take effect correctly (#6922)"
- "Mirrors now remove `Nats-Expected-` headers that could interfere with mirroring operations (#6961)"
- Two desync fixes — "after a partial catchup following a snapshot (#6943)" and "due to catchup
  messages with incorrect quorum (#6944)" — and "Network-partitioned Raft nodes should no longer
  desync by accepting catchups from nodes with lower term (#6951)"
- "Raft now uses monotonic time for heartbeat tracking and determining quorum, making it resilient
  against wall-clock drifts or adjustments from NTP (#6999)"
- "The `healthz` monitoring endpoint no longer tries to fix up cluster node skews, as this could
  interfere with processing assignments (#7001)"
- "A potential deadlock when purging stream consumers has been fixed (#6933)"

General: "Leafnodes with restrictive permissions can now route replies correctly when the message
originates from a supercluster (#6931)"; "Memory usage is now reported correctly on Linux systems with
huge pages enabled (#7006)".

**Improved**: "The `connz` monitoring endpoint now includes leafnode connections (#6949)";
"`accstatsz` … now contains leafnode, route and gateway connection stats (#6967)"; "Sourcing and
mirroring should now resync more quickly when sourcing over leafnodes after a connection failure
(#6981)"; "Ephemeral R1 consumers will no longer log `new consumer leader` on clustered setups,
reducing log noise when watchers etc are in use (#7003)". Go 1.24.4; nats.go v1.43.0.

## Practical takeaways

- **Any 2.11.0–2.11.4 with `last_per_subject` consumers on streams that keep more than one message
  per subject wants 2.11.5 or later.** The issue's reporters saw acks stop registering and the floor
  freeze; nothing in the server said why.
- The monotonic-time change (#6999) is the one to know about on virtual machines whose clocks get
  stepped: before it, a wall-clock adjustment could cost a quorum.
- `#7011` changes what a client sees at `MaxWaiting`: no response at all when the request carries a
  heartbeat, by design, so a client library that retries on silence must not tight-loop.

## Questions it answers

- Version layer for **row 14** (the known-defect cause on [[consumer-keeps-redelivering]]).

## Pages touched

[[consumer-keeps-redelivering]] · [[nats-server-2.11]] · [[consumer]]
