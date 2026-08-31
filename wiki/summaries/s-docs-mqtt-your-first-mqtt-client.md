---
title: "docs — MQTT: Your first MQTT client"
type: summary
area: [interop, jetstream, deploy]
source-url: https://docs.nats.io/learn/mqtt/your-first-mqtt-client.md
source-path: raw/nats-docs/learn/mqtt/your-first-mqtt-client.md
author: nats-io docs
article: "learn/mqtt/your-first-mqtt-client.md"
date: 2026-09-01
version: ""
tags: [mqtt, Nmqtt-Pub, jetstream-required, port-1883, mqtt-websocket]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — MQTT: Your first MQTT client

The chapter's opening page, and the one that states the two hard preconditions: **JetStream, and a
port**. `nats-server` *is* the MQTT broker — "there's no bridge process and no translation layer you
operate".

## Key claims

**MQTT requires JetStream, and the check is scoped.** "Configure `mqtt {}` without JetStream and the
server refuses to start: `mqtt requires JetStream to be enabled if running in standalone mode`." The
page reads the scope out of the message itself: "A server with a `cluster`, `gateway`, or `leafnode`
configuration can reach JetStream elsewhere in the system, so the check doesn't apply there."

**The requirement is also per account**: "an MQTT user whose account has no JetStream is refused at
connect time."

**There is no default MQTT port**, and the failure is silent: "an `mqtt {}` block with no `listen` or
`port` disables MQTT silently, with **no error and no log line**, so always set one." When it is set:
`[INF] Listening for MQTT clients on mqtt://127.0.0.1:1883`.

**A topic becomes a subject at the server.** `sensors/warehouse/cold-1/temp` published over MQTT
arrives at `nats sub "sensors.>"` as `sensors.warehouse.cold-1.temp`, with the payload untouched —
"MQTT payloads are bytes, and so are NATS payloads".

**The `Nmqtt-Pub` header** is "the server marking the message as MQTT-originated, with the QoS it was
published at; NATS subscribers can read it or ignore it."

**The bridge is a real subscription, not a special case.** "When the MQTT client subscribed to
`fleet/truck-17/telemetry`, the server created a matching NATS subscription on
`fleet.truck-17.telemetry`… Because the interest is a real NATS subscription, it propagates the way
any other subscription does" — so a publisher on another server in the cluster reaches the device.

**A NATS publish always reaches an MQTT subscriber at QoS 0**, "whatever QoS the subscription asked
for. A NATS publish carries no QoS, so there's nothing to promote it with."

**Device traffic is ordinary NATS traffic**, so a stream captures it:
`nats stream add DEVICES --subjects "sensors.>,fleet.>" --storage file --retention limits
--max-age 720h --defaults`.

**MQTT over WebSocket goes to the WebSocket port.** "Send a WebSocket handshake to 1883 and the
server rejects it with `MQTT clients over websocket must connect to the Websocket port, not the MQTT
port`."

## Practical takeaways

- The silent no-port case is the same shape as `websocket {}`'s (see
  [[s-docs-websocket-your-first-websocket-connection]]) and as the wiki already records for
  `mqtt.port` having no default — a listener that does not exist and says nothing.
- "MQTT requires JetStream" is not a slogan: it is a startup check on standalone servers and a
  connect-time check per account.

## Notable quotes

> "`nats-server` is the MQTT broker. There's no bridge process and no translation layer you operate."

> "An `mqtt {}` block with no `listen` or `port` disables MQTT silently, with no error and no log
> line."

## Relevance to the wiki

The wiki had MQTT only as config keys in [[config-keys]] and [[defaults-and-limits]] — including two
corrected defaults (docs issues #28, #29) — and no page saying what the feature *is*. This is the
foundation of [[mqtt]].

## Questions it answers

Q80 (background).

## Pages touched

[[mqtt]] · [[defaults-and-limits]] · [[config-keys]]

## Sources

`raw/nats-docs/learn/mqtt/your-first-mqtt-client.md` · run against the server in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
