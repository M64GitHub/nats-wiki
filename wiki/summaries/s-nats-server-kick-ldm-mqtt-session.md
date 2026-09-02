---
title: "nats-server v2.14.6 — kicking a client, lame-ducking a client, and the MQTT session record"
type: summary
area: [core, interop, topology, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/kick-ldm-and-mqtt-session-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/mqtt.go, events.go, server.go and jetstream_cluster.go at v2.14.6, plus the KICK and LDM requests run against a live client (raw/nats-server-src/kick-ldm-observed-v2.14.6.md)"
date: 2026-09-01
version: "2.14.6"
tags: [kick, ldm, lame-duck, system-requests, mqtt, session, 10071, Nats-Expected-Last-Subject-Sequence, leader-elected, log-lines]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# nats-server v2.14.6 — kicking a client, lame-ducking a client, and the MQTT session record

Read for the two unanswered threads of the meta-layer plan's step 2: what the server can do to a
single client from the system account (**Q40**, [[s-gh-6892-evict-a-sick-node]]), and what the first
line of gh#7533's failure sequence means (**Q37**, [[s-gh-7533-quorum-loss-mqtt]]). Nine quoted
ranges; the two requests were then run on the cluster of [[s-nats-server-jetstream-cluster]].

## Key claims

### Two per-client requests, both executed by the server that holds the client

- `$SYS.REQ.SERVER.<server-id>.KICK` and `$SYS.REQ.SERVER.<server-id>.LDM`, body `{"cid": <n>}`,
  subscribed by each server **for its own id only** (`events.go:60–63`, `1499–1510`, `3213–3253`).
  KICK calls `DisconnectClientByID` and closes the connection; LDM calls `LDMClientByID`, which
  **only sends the client an INFO with `ldm: true`** — what happens next is the client library's
  choice (`server.go:4753–4790`).
- **Observed**: a kicked `nats sub` printed `>>> Disconnected due to: EOF, will attempt reconnect`
  and came back on another server within 2.5 s; an LDM'd one stayed where it was. An unknown cid
  answers `{"error":{"code":500,"description":"no such client or leafnode id"}}`.
- Nothing else exists at this level: the per-server request subjects are `KICK`, `LDM`, `RELOAD`
  and the monitoring `z` endpoints (`events.go:52–75`). No request addresses clients by IP, kicks
  every client of a server, or makes *other* servers drop a route. nats CLI 0.4.0 has
  `nats server request kick <client> <server>` and no `ldm` subcommand.

### The MQTT session record is a conditional publish

`mqttSession.save` (`mqtt.go:3357–3399`) publishes the session record to the client's subject in
`$MQTT_sess` with the header **`Nats-Expected-Last-Subject-Sequence: <seq>`** whenever it has
stored the record before, `seq` being the sequence the last `PubAck` returned. A rejected publish is
reported as `unable to persist session "<id>" (seq=<seq>): <error>` — so
`… (seq=40344): wrong last sequence: 0 (10071)` means the stream's last sequence **for that subject
was 0**: the record the server remembered writing was gone from the stream as that server then saw
it. `createOrRestoreSession` wraps any load error other than *no message found* as
`loading session record: …` (`3100–3125`) — the form gh#7533's second line takes around `10008`.

### The stream-leader log lines

`JetStream cluster new stream leader for '<account> > <stream>'` is logged by the new leader, which
also publishes the leader-elected advisory (`jetstream_cluster.go:4735–4742`);
`Transfer of stream leader for '<account> > <stream>' to '<server>'` marks a deliberate move during a
scale-down or peer change (`3868–3880`). Consumer groups have the same pair.

## Practical takeaways

- To get clients off a sick server from outside: `nats server request kick <cid> <server-id>` per
  client, and only while that server still processes system-account traffic. There is no bulk form.
- Do not rely on the LDM request to move clients; it informs, it does not disconnect.
- Read `wrong last sequence: 0` on an MQTT session as "the stream lost the record", not as an MQTT
  problem.

## Relevance to the wiki

The mechanism behind [[evict-a-sick-server]]'s honest scope, the `10071` explanation on
[[stream-leader-keeps-moving]] and [[mqtt]].

## Questions it answers

- **Q40** — the per-client half of evicting a sick server, with what cannot be done.
- **Q37** — what the first symptom means; not why it happened.

## Pages touched

[[evict-a-sick-server]] · [[stream-leader-keeps-moving]] · [[mqtt]]
