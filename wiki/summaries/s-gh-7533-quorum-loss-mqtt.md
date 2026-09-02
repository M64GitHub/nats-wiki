---
title: "gh#7533 — Unexpected JetStream quorum loss and MQTT session errors after several days of stable operation"
type: summary
area: [jetstream, topology, interop]
source-url: https://github.com/nats-io/nats-server/discussions/7533
source-path: raw/gh-discussions/gh-7533.md
author: "@nikolaigut (asked); nobody answered"
article: "GitHub Discussion 7533 (Q&A)"
date: 2025-11-10
version: "2.12.1"
tags: [quorum, meta-leader, mqtt, 10071, 10008, no-quorum, leader-election, kubernetes, unanswered]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7533 — quorum loss after days of stable operation, seen from MQTT

Opened 2025-11-10 in Q&A; **zero comments and no answer** when fetched on 2026-09-01. It is the only
public thread in the question bank that describes a *spontaneous* quorum loss on a cluster that had
been running for days, and it does so with an unusually complete sequence of log lines — which is why
it is worth a summary even though it settles nothing.

## The report

**nats-server 2.12.1**, JetStream, the MQTT bridge, three nodes on Kubernetes with the official Helm
chart; about 30 MQTT clients at roughly 10 QoS 1 messages a minute each. "After several days of stable
operation, we consistently encounter the following issue sequence":

1. Every MQTT client fails in turn on connect:
   `unable to connect: unable to persist session "mqtt-client-id" (seq=40344): wrong last sequence: 0 (10071)`
2. Shortly after: `unable to connect: loading session record for account "default", session
   "mqtt-client-id": JetStream system temporarily unavailable (10008)`
3. Then repeated `timeout after 5.000165086s: request type "MS" on "$MQTT.msgs.DEVICE.measurements"`
   with `Readloop processing time: 5.000206463s`
4. Finally `[WRN] JetStream cluster consumer 'default > $MQTT_msgs > zh49h37z_…' has NO quorum,
   stalled.` — "after which no more messages are processed".

CPU and memory "spike heavily for a short period and then drop again" at the same time; the clients
keep publishing at their steady rate throughout.

The four questions asked: what causes `wrong last sequence: 0` on session persistence; whether this
is quorum loss or a synchronisation problem; whether load or disk latency can make JetStream
"temporarily unavailable"; and what diagnostics or configuration prevent it.

## What can be said about the sequence, from sources this wiki has read

None of this is the thread's answer; it is what the server's own code and this wiki's run say each
line means ([[s-nats-server-kick-ldm-mqtt-session]], [[s-nats-server-jetstream-cluster]],
[[s-nats-server-mqtt-websocket-observed]]):

- **Line 1, `10071`** — an MQTT session record is written to `$MQTT_sess` with the header
  `Nats-Expected-Last-Subject-Sequence: <seq>` set to the sequence the server last stored for that
  client id (`mqtt.go:3373–3384`). `wrong last sequence: 0` means the stream answered that the
  subject now has **no** message at all — the record the server remembered writing at sequence
  40344 was no longer in the stream. Something made the `$MQTT_sess` stream's state go backwards
  from the connecting server's point of view.
- **Line 2, `10008`** — the server handling the connect believed the **meta group had no leader**;
  that is the only condition under which the JetStream API returns this code.
- **Line 3** — a JetStream publish into `$MQTT_msgs` (request type `MS`) that never got its
  `PubAck` within the MQTT bridge's 5-second wait: the *stream's* group could not commit.
- **Line 4** — the consumer's own Raft group lost its majority; `NO quorum, stalled` is logged by
  the group leader about 10 s after it last heard from a majority.

So the answer to the reporter's second question is yes: lines 2–4 are the meta group, the stream
group and a consumer group each losing quorum. The first line is the odd one: it precedes the loss
and says the stream's stored state had already changed. **Why** — a leader election that landed on a
peer with an empty or truncated log, a reset, or something else — is not established anywhere
public. 2.12's release notes describe "better protection against leader elections based on empty
state" ([[s-docs-upgrade-to-2.12]]); the reporter was on 2.12.1.

## Practical takeaways

- Read the sequence in the order the groups fail: meta (`10008`), then streams (publish timeouts),
  then consumers (`NO quorum`). A CPU or memory spike long enough to miss ~10 s of heartbeats
  produces exactly that order — see [[stream-leader-keeps-moving]].
- Capture `$JS.EVENT.ADVISORY.>` into a stream *before* the next occurrence; the `QUORUM_LOST` and
  `LEADER_ELECTED` advisories for `$MQTT_sess`, `$MQTT_msgs` and their consumers would date the
  first loss to the second ([[advisories]]).
- On Kubernetes, check the probes and the storage: the Helm chart's liveness probe restarts a pod
  whose JetStream is unhealthy, and a pod catching up after a restart still reports ready
  ([[monitoring-endpoints]], [[kubernetes-storage]]).

## Relevance to the wiki

The symptom half of [[stream-leader-keeps-moving]], and the one question-bank row (**Q37**) that
names a quorum loss with no operator action behind it. It also ties the MQTT bridge's error strings
to the meta layer: [[mqtt]] gains the `10071` / `10008` pair.

## Questions it answers

- **Q37** — *What causes unexpected quorum loss after days of stable operation?* Not answered in
  public. The wiki maps every line of the reported sequence to a mechanism and says which part is
  unexplained.

## Pages touched

[[stream-leader-keeps-moving]] · [[mqtt]] · [[meta-layer]] · [[raft-in-nats]]
