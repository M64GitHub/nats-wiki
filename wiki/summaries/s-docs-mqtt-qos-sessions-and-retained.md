---
title: "docs — MQTT: QoS, sessions, and retained messages"
type: summary
area: [interop, jetstream]
source-url: https://docs.nats.io/learn/mqtt/qos-sessions-and-retained.md
source-path: raw/nats-docs/learn/mqtt/qos-sessions-and-retained.md
author: nats-io docs
article: "learn/mqtt/qos-sessions-and-retained.md"
date: 2026-09-01
version: ""
tags: [mqtt, qos, ack_wait, max_ack_pending, sessions, clean-session, will, retained, client-id]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — MQTT: QoS, sessions, and retained messages

The delivery contract, and the state the server holds between connections. The page names the streams'
*existence* — "the stored state lives in the JetStream streams the server created when you enabled
MQTT" — and **never names a stream**, which is why question-bank row **Q80** had to be measured
([[s-nats-server-mqtt-websocket-observed]]).

## Key claims

**The three levels, and the rule that combines them:**

| QoS | promise | cost |
|---|---|---|
| 0 | at most once | nothing stored, no acknowledgment |
| 1 | at least once, redelivered until acknowledged | stored until PUBACK; duplicates possible |
| 2 | exactly once, four-packet handshake | most round trips and most state |

"The effective level for a delivery is the lower of the two: a QoS 0 publish to a QoS 1 subscriber is
still delivered at QoS 0."

**QoS does not extend to NATS publishes.** "A message published by a NATS client and delivered to an
MQTT subscriber is always QoS 0, whatever QoS that subscription asked for… An MQTT device subscribed
at QoS 1 to a subject that NATS clients publish to gets at-most-once delivery in practice." The
remedy the page gives: "keep the durability on the NATS side, in a stream".

**Redelivery is governed by `ack_wait`, default 30 seconds**, set in the `mqtt {}` block. "A change to
`ack_wait` applies only to subscriptions created after the change." A redelivery "is a genuine
duplicate: the device sees the same payload twice".

**`max_ack_pending` defaults to 1024, range 0–65535, and `0` means the default** — "the server reads 0
as 'use the default' and applies 1024".

**Two limits combine into a subscription ceiling.** The per-session total across all subscriptions
cannot exceed **65535**, a subscription that would exceed it "is refused, and the server returns
`0x80` in the SUBACK", and a `#` subscription **counts twice**. So: "At the default of 1024, a session
has room for **63 plain subscriptions, or 31** if they all end in `#` — the check is strict, so the
subscription that would reach the cap exactly is already refused." (Both numbers reproduced exactly on
2.14.6.) "Lower `max_ack_pending` if you need more subscriptions per session."

**A session is keyed by client ID, not by connection**, and is "stored in JetStream, so they outlive
both the connection and a server restart". The `clean session` flag "clears any stored state for that
client ID and the session lasts only as long as the connection".

**A client ID must be a valid NATS subject token.** "An invalid one is refused at connect with an
identifier-rejected code. An empty client ID is allowed only together with the clean session flag, in
which case the server generates one."

**Duplicate client IDs evict each other.** The spec requires the server to close the first connection
and accept the newcomer. "Deploy the same client ID to two devices and each connection evicts the
other; if both have reconnect logic, the cycle repeats as fast as they can reconnect. The server
limits the damage by recording the client ID as flapping and refusing to hand the session over again
for **about a second**." Across a cluster "eviction has to travel between servers", so it is slower.

**Will messages** are registered in CONNECT and published "if the connection ends without a clean
DISCONNECT — the network drops, the keepalive times out, the process dies". "A clean DISCONNECT
discards it silently." The will topic converts like any other, so `fleet/truck-17/status` lands on
`fleet.truck-17.status` where NATS services see it.

**Retained messages: one per topic, replaced not queued.** "Retention is per topic name, not per
filter, so a subscriber using a wildcard receives the retained message for every matching topic."
Publishing an empty payload with RETAIN deletes it — "The zero-byte message is delivered to current
subscribers as a normal message, then the stored retained message is removed."

**Retained messages are stored regardless of QoS.** "A retained QoS 0 message is still persisted,
which is part of why the account needs JetStream even for a fleet that never uses QoS 1."

## Practical takeaways

- The subscription ceiling is the trap with the least obvious symptom: a device that subscribes to
  many topics silently gets `0x80` on the 64th, "which is easy to misread as a permissions problem".
- Testing a will with Ctrl-C proves nothing — mosquitto sends DISCONNECT and the will is discarded.
  "Test with a hard kill or by cutting the network."

## Notable quotes

> "A device that publishes ten readings with RETAIN while a subscriber is offline leaves one value
> behind, not ten."

> "Nothing in a NATS publish carries a QoS. There's no field to read and no acknowledgment contract
> to inherit."

## Relevance to the wiki

The core of [[mqtt]]. Its one gap — which streams, and what they cost — is exactly what
[[s-nats-server-mqtt-websocket-observed]] fills.

## Questions it answers

Q80 (the contract; the cost is measured separately).

## Pages touched

[[mqtt]] · [[defaults-and-limits]] · [[ack-and-redelivery]]

## Sources

`raw/nats-docs/learn/mqtt/qos-sessions-and-retained.md` · measured in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
