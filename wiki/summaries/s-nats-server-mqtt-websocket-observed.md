---
title: "nats-server v2.14.6 — MQTT and WebSocket, run rather than read"
type: summary
area: [interop, jetstream, security, topology, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md
author: nats-io/nats-server contributors (the binary); this wiki (the experiments and the probe client)
article: "Fifteen experiments on the v2.14.6 binary with nats CLI 0.4.0 and a hand-written MQTT 3.1.1 probe client"
date: 2026-09-01
version: "2.14.6"
tags: [mqtt, websocket, "$MQTT_msgs", "$MQTT_sess", "$MQTT_qos2in", "$MQTT_rmsgs", "$MQTT_out", stream_replicas, allowed_origins, 10005]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# nats-server v2.14.6 — MQTT and WebSocket, run rather than read

Run to answer question-bank row **Q80** — *"How does MQTT QoS 1/2 map onto JetStream, and what does it
cost?"* — which `learn/mqtt` answers in prose while **never naming a single stream**, and to check the
rest of both chapters against the binary. Fifteen experiments on **nats-server v2.14.6** with **nats
CLI 0.4.0**.

**The instrument.** No MQTT client was installed on this machine and none was installed for this: the
probe is a ~110-line stdlib-only MQTT **3.1.1** client written for these runs
(`raw/nats-server-src/mqtt-probe-client-v3.1.1.py`), speaking the full QoS 2 handshake and reading
SUBACK return codes, so `0x80` is directly observable.

## Key claims

**Five streams, created lazily on the first MQTT connection** — not at server start. Before any client
connects, `nats stream ls -a` says `No Streams defined`.

| stream | subjects | retention | discard | `max_msgs_per_subject` | holds |
|---|---|---|---|---|---|
| `$MQTT_sess` | `$MQTT.sess.>` | limits | old | 1 | one session record per client id |
| `$MQTT_msgs` | `$MQTT.msgs.>` | **interest** | old | -1 | QoS 1/2 messages awaiting ack |
| `$MQTT_out` | `$MQTT.out.>` | **interest** | old | -1 | outbound PUBREL state for QoS 2 delivery |
| `$MQTT_qos2in` | `$MQTT.qos2.in.>` | limits | **new** | 1 | inbound QoS 2 dedup records |
| `$MQTT_rmsgs` | `$MQTT.rmsgs.>` | limits | old | 1 | retained messages, one per topic |

All five are `storage: file`, `max_age: 0`. A QoS 1/2 subscription also creates a durable consumer on
`$MQTT_msgs`, a `$MQTT_PUBREL_<id>` consumer on `$MQTT_out`, and a `$MQTT_rmsgs_<id>` consumer.

**Q80, measured.** One durable QoS-2 subscriber, one publisher, a 100-byte payload:

| publish | what it costs |
|---|---|
| **QoS 0** | **nothing** — no stream moves |
| **QoS 1** | one message in `$MQTT_msgs`, **194 bytes** for a 100-byte payload |
| **QoS 2** (full handshake) | **the same** — one message in `$MQTT_msgs`, 194 bytes |
| **retained, QoS 0** | **174 bytes** in `$MQTT_rmsgs` |

So **QoS 2 costs the same stored bytes as QoS 1**; its extra price is round trips and transient state,
not storage. And a session record is **104 bytes bare, 791 bytes with a single subscription** — the
subscription is the expensive part, not the session.

**The QoS 2 dedup record leaks when a handshake is abandoned.** A PUBLISH at QoS 2 with no PUBREL
leaves one record (118 bytes) in `$MQTT_qos2in`; it survives the DISCONNECT and does not expire
(`max_age: 0`). A completed `PUBREC->PUBREL->PUBCOMP` leaves the stream unchanged. The subject is
**`$MQTT.qos2.in.<client-id>.<packet-id>`** with `max_msgs_per_subject: 1`, so the leak is **bounded at
65,535 records per client id** and unbounded in the number of client ids.

**`$MQTT_out` is the outbound PUBREL store.** Delivering a QoS 2 message: the publish puts 1 message in
`$MQTT_msgs`; the subscriber's PUBREC drops `$MQTT_msgs` to **0** (interest retention) and writes
**1 record to `$MQTT_out`**; the server then sends packet type 6 (PUBREL).

**gh#7397's symptom reproduced** — the unanswered thread behind question-bank row **Q81**, whose
reporter says rotating client ids with QoS 1 mean "messages never get deleted since the stale clients
block deletion":

```
3 stale durable sessions (subscribed QoS 1, then killed)  $MQTT_sess=3/1446  $MQTT_msgs=0/0
after 5 QoS-1 publishes                                   $MQTT_sess=4/1564  $MQTT_msgs=5/470
+3s (nobody ever acks)                                    $MQTT_sess=4/1564  $MQTT_msgs=5/470
after reconnecting each client id once with clean session $MQTT_sess=1/118   $MQTT_msgs=0/0
```

`$MQTT_msgs` uses **interest retention** and a stale session's durable consumer still holds interest,
so nothing is removed. Reconnecting each dead client id once with the clean-session flag empties it.
**No public source connects these two facts.**

**All ten topic→subject conversion rules matched the docs exactly**, including the four
wildcard-passthrough cases (`fleet*/telemetry` → `fleet*.telemetry` literal;
`fleet/*/telemetry` → `fleet.*.telemetry` a real wildcard).

**The `Nmqtt-Pub` header carries the QoS, as documented**: 0, 1, 2 on the delivered NATS message, and
0 for a retained QoS 0 publish. (The value *inside* `$MQTT_qos2in` is a different encoding — 24 — with
an `Nmqtt-Subject` header beside it; that is an internal record, not a delivered message.)

**The six refused characters confirmed**, with the documented asymmetry: publishing closes the
connection, subscribing returns SUBACK `0x80`. BEL (`\x07`) is accepted both ways, confirming "other
control characters pass through".

**The subscription ceiling arithmetic is exact.** At the default `max_ack_pending` of 1024:
**subscription #64 refused with `0x80` (63 accepted)** for plain filters, and **#32 refused (31
accepted)** for `#` filters.

**MQTT v5 is refused at connect** — a CONNECT with protocol level 5 returns CONNACK return code **1**,
"unacceptable protocol version".

**Four startup errors verbatim, all exit 1**: `mqtt requires JetStream to be enabled if running in
standalone mode`; `mqtt requires server name to be explicitly set`; `websocket requires TLS
configuration`; and the mixed-scheme leafnode remote refusal.

**Both silent no-listener cases confirmed.** `mqtt { }` with no port and `websocket { no_tls: true }`
with no port each start the server with **no line about that listener at all**.

**The WebSocket origin table reproduced exactly** — one `101`, four `403 Forbidden` — **plus the row
that matters most: a handshake with no `Origin` header gets `101 Switching Protocols`.** The `nats`
CLI publishes straight through an origin-restricted listener.

**MQTT stream replicas are derived from the `routes` list, not the cluster — confirmed.** A genuine
three-node cluster (`/jsz?meta=1`: `cluster size: 3`) whose n1 lists **two** routes created all five
MQTT streams at **R=2**. The server announces it:
`[INF] Creating MQTT streams/consumers with replicas 2 for account "$G"`. With
`stream_replicas: 3` on the same node, all five came up **R=3**.

**And what "streams fail to create" looks like from the device**: asked for `stream_replicas: 3` on a
two-node cluster, the server logs
`unable to connect: create sessions stream for account "$G": no suitable peers for placement (10005)`
and **the device gets the TCP connection closed with no CONNACK at all** — not a return code, nothing
an MQTT client can report.

## Practical takeaways

- **Set `stream_replicas` explicitly.** The ordinary "list your two peers" cluster config silently
  gives MQTT state R=2 on a three-node cluster.
- **`Creating MQTT streams/consumers with replicas N`** is the one log line that tells you what you
  actually got; grep for it after any cluster change.
- **An MQTT client that cannot connect and gets no CONNACK is a JetStream placement failure**, and the
  diagnosis is only in the server log.
- **Origin checking is not access control**, and the proof is one CLI command.

## Notable quotes

Not applicable; this is a run. The verbatim output is in the raw file.

## Relevance to the wiki

Q80 could not be answered from the chapter, which never names a stream. This names all five, measures
each QoS level, and explains the retention policy that produces the complaint in Q81's thread. It also
supplies [[mqtt]] and [[websocket]] with their observable behaviour, and ties an MQTT connect failure
to [[no-suitable-peers-for-placement]].

## Questions it answers

Q80. Q81 (the mechanism behind it, not the restriction it asks for).

## Pages touched

[[mqtt]] · [[websocket]] · [[no-suitable-peers-for-placement]] · [[defaults-and-limits]] ·
[[replicas]] · [[monitoring-endpoints]] · [[subject-permissions]]

## Sources

`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md` ·
`raw/nats-server-src/mqtt-probe-client-v3.1.1.py` · [[s-docs-mqtt-qos-sessions-and-retained]] ·
[[s-docs-mqtt-auth-and-clustering]]
