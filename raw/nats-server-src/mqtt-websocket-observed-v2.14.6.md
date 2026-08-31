<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-09-01 · configs and output verbatim below. -->

# Observed on nats-server v2.14.6 — MQTT and WebSocket

Fifteen experiments run while ingesting `learn/mqtt` and `learn/websocket`, to settle what those
chapters describe without naming and to answer question-bank row **Q80** ("how does MQTT QoS 1/2 map
onto JetStream, and what does it cost") — which the chapter answers in prose while **never naming a
single stream**.

**The instrument.** No MQTT client was installed on this machine and none was installed for this:
`mqtt-probe-client-v3.1.1.py` in this directory is a ~110-line stdlib-only MQTT **3.1.1** client
written for these runs. It speaks CONNECT/CONNACK, PUBLISH/PUBACK, the full QoS 2
PUBREC/PUBREL/PUBCOMP handshake, SUBSCRIBE/SUBACK (so SUBACK return codes are readable, including
`0x80`), DISCONNECT, and an abnormal close. Everything below is reproducible with it.

### Standalone setup

```
listen: 127.0.0.1:4261
http: 8261
server_name: mqttlab
jetstream { store_dir: "<scratch>/interop/store" }
mqtt { listen: 127.0.0.1:1883 }
```

---

## 1 · The five streams MQTT creates, and when

`nats stream ls -a` immediately after startup, before any MQTT client connects:

```
No Streams defined
```

After **one** MQTT CONNECT, five streams exist. They are created **lazily, on the first MQTT
connection**, not at server start:

| stream | subjects | retention | discard | `max_msgs_per_subject` |
|---|---|---|---|---|
| `$MQTT_sess` | `$MQTT.sess.>` | limits | old | **1** |
| `$MQTT_msgs` | `$MQTT.msgs.>` | **interest** | old | -1 |
| `$MQTT_out` | `$MQTT.out.>` | **interest** | old | -1 |
| `$MQTT_qos2in` | `$MQTT.qos2.in.>` | limits | **new** | **1** |
| `$MQTT_rmsgs` | `$MQTT.rmsgs.>` | limits | old | **1** |

All five: `storage: file`, `max_age: 0`, `max_msgs: -1`, `allow_rollup_hdrs: false`,
`allow_direct: false`, `deny_delete: false`.

**Consumers**, after one QoS-2 subscription from one durable session:

```
$MQTT_msgs   -> HIfEYfjm_7lJX7GmXMhBtKErXxUSKaU        (Ack Pending 2)
$MQTT_out    -> $MQTT_PUBREL_HIfEYfjm
$MQTT_rmsgs  -> $MQTT_rmsgs_7lJX7GmXMhBtKErXxUSJyk
$MQTT_qos2in -> (none)
$MQTT_sess   -> (none)
```

## 2 · Q80 — what each QoS level actually costs

One durable subscriber (`clean session` off, subscribed at QoS 2), one publisher, a **100-byte**
payload each time. `messages/bytes` per stream, cumulative:

| step | `$MQTT_msgs` | `$MQTT_out` | `$MQTT_qos2in` | `$MQTT_rmsgs` | `$MQTT_sess` |
|---|---|---|---|---|---|
| server up, no MQTT client | *(streams do not exist)* | | | | |
| one durable session | 0/0 | 0/0 | 0/0 | 0/0 | **1/104** |
| + one QoS-2 subscription | 0/0 | 0/0 | 0/0 | 0/0 | **1/791** |
| + one clean-session publisher | 0/0 | 0/0 | 0/0 | 0/0 | 2/908 |
| + **QoS 0** publish | 0/0 | 0/0 | 0/0 | 0/0 | 2/908 |
| + **QoS 1** publish | **1/194** | 0/0 | 0/0 | 0/0 | 2/908 |
| + **QoS 2** publish (full handshake) | **2/388** | 0/0 | 0/0 | 0/0 | 2/908 |
| + **retained QoS 0** publish | 2/388 | 0/0 | 0/0 | **1/174** | 2/908 |

Reading it:

- **QoS 0 costs nothing.** No stream moves.
- **QoS 1 and QoS 2 cost the same in steady state**: one message in `$MQTT_msgs`, **194 bytes for a
  100-byte payload** (~94 bytes of overhead) in both cases. QoS 2's extra cost is **round trips and
  transient state, not stored bytes**.
- **A retained message costs 174 bytes even at QoS 0** — which is why JetStream is required for a
  fleet that never uses QoS 1.
- **A session record is 104 bytes bare and 791 bytes with a single subscription.** One subscription
  is the expensive part of a session, not the session.

## 3 · The QoS 2 inbound dedup record, and the leak when a handshake is abandoned

Fresh server, fresh connection per case so packet ids never overlap.

**A — PUBLISH at QoS 2 with no PUBREL:**

```
$MQTT_qos2in before      : 0/0
after PUBLISH only       : 1/118
after DISCONNECT         : 1/118
+2s                      : 1/118
```

**B — the full four-packet handshake on a fresh connection:** `PUBREC->PUBREL->PUBCOMP`, and
`$MQTT_qos2in` is **unchanged** (1/118 before and after). The record is written on PUBLISH and
removed on PUBREL.

So an **abandoned QoS 2 handshake leaves a record behind permanently**: `$MQTT_qos2in` has
`max_age: 0` and no age limit. The record:

```
Item: $MQTT_qos2in#1 on Subject $MQTT.qos2.in.q2-abandon.1

Headers:
  Nmqtt-Pub: 24
  Nmqtt-Subject: fleet.x

abandoned
```

The subject is **`$MQTT.qos2.in.<client-id>.<packet-id>`** and `max_msgs_per_subject` is 1, so a
device reusing a packet id replaces its own record. The leak is therefore **bounded at 65,535 records
per client id** — and unbounded in the number of distinct client ids.

## 4 · What `$MQTT_out` carries

A QoS 2 message delivered *to* a subscriber, step by step:

| step | `$MQTT_msgs` | `$MQTT_out` |
|---|---|---|
| before publish | 0/0 | 0/0 |
| publisher completes its QoS 2 publish | **1/89** | 0/0 |
| subscriber receives PUBLISH (qos 2) and sends **PUBREC** | **0/0** | **1/87** |
| server sends packet type **6 (PUBREL)** to the subscriber | | |

`$MQTT_out` holds the **outbound PUBREL state** for QoS 2 *delivery* — the server's half of the
four-packet handshake toward a subscriber — and `$MQTT_msgs` releases the message as soon as the
subscriber's PUBREC arrives (interest retention).

## 5 · gh#7397's symptom reproduced: stale sessions block deletion

Question-bank row **Q81** comes from a thread that has been open and **unanswered since 2025-10-06**,
whose reporter says: *"clients sometimes connect with different client_id all the time and QoS1. This
means that messages never get deleted since the stale clients … block deletion."* That is
reproducible:

```
3 stale durable sessions (each subscribed QoS 1, then killed)
                                   $MQTT_sess=3/1446  $MQTT_msgs=0/0
after 5 QoS-1 publishes            $MQTT_sess=4/1564  $MQTT_msgs=5/470
+3s (nobody ever acks)             $MQTT_sess=4/1564  $MQTT_msgs=5/470
after reconnecting each client id
  once with clean session          $MQTT_sess=1/118   $MQTT_msgs=0/0
```

`$MQTT_msgs` uses **interest retention**, and a stale session's durable consumer still holds
interest, so nothing is ever removed. Reconnecting each dead client id once with the clean-session
flag drops the stream to empty. The docs never connect these two facts.

## 6 · Topic → subject conversion: all ten documented rules

Published over MQTT, read off `nats sub '>'`. Every row matched `learn/mqtt/topics-and-subjects.md`
exactly:

| MQTT topic | NATS subject | matched docs |
|---|---|---|
| `sensors/cold-1/temp` | `sensors.cold-1.temp` | yes |
| `/sensors/temp` | `/.sensors.temp` | yes |
| `sensors/temp/` | `sensors.temp./` | yes |
| `sensors//temp` | `sensors./.temp` | yes |
| `//sensors/temp` | `/./.sensors.temp` | yes |
| `cold-1.temp` | `cold-1//temp` | yes |
| `fleet*/telemetry` | `fleet*.telemetry` | yes |
| `fleet>/telemetry` | `fleet>.telemetry` | yes |
| `fleet/*/telemetry` | `fleet.*.telemetry` | yes |
| `fleet/>` | `fleet.>` | yes |

## 7 · The `Nmqtt-Pub` header a NATS subscriber sees

| published at | header on the delivered NATS message |
|---|---|
| QoS 0 | `Nmqtt-Pub: 0` |
| QoS 1 | `Nmqtt-Pub: 1` |
| QoS 2 | `Nmqtt-Pub: 2` |
| QoS 0 with RETAIN | `Nmqtt-Pub: 0` |

So the docs are right that the header carries the QoS. Note the value **inside** `$MQTT_qos2in` is
not the same encoding (`Nmqtt-Pub: 24` there, alongside an `Nmqtt-Subject` header) — that is an
internal storage record, not a delivered message.

## 8 · Characters refused in a topic

| character | PUBLISH | SUBSCRIBE |
|---|---|---|
| space | connection **closed** by server | SUBACK `0x80` |
| tab | connection closed | SUBACK `0x80` |
| newline | connection closed | SUBACK `0x80` |
| carriage return | connection closed | SUBACK `0x80` |
| form feed | connection closed | SUBACK `0x80` |
| DEL | connection closed | SUBACK `0x80` |
| **BEL (`\x07`)** | **accepted**, connection stays open | SUBACK `0x00` |

Confirms both the six-character list and the docs' claim that other control characters pass through.

## 9 · The per-session subscription ceiling

At the default `max_ack_pending` of 1024, subscribing repeatedly on one session until refused:

```
plain filters : subscription #64 refused with 0x80  -> 63 accepted
'#' filters   : subscription #32 refused with 0x80  -> 31 accepted
```

Exactly the **63** and **31** the chapter derives, and the `#` filter does cost double.

## 10 · MQTT v5 is refused at connect

A CONNECT with protocol level **5**:

```
CONNACK {'session_present': 0, 'return_code': 1}
```

Return code 1 is "unacceptable protocol version". Level 4 (v3.1.1) connects normally.

## 11 · Startup errors, verbatim (all exit 1)

| config | stderr |
|---|---|
| `mqtt {}` with no `jetstream` block | `nats-server: mqtt requires JetStream to be enabled if running in standalone mode` |
| `mqtt {}` + a `cluster` block, no `server_name` | `nats-server: mqtt requires server name to be explicitly set` |
| `websocket {}` with neither `tls {}` nor `no_tls` | `nats-server: websocket requires TLS configuration` |
| a leafnode remote mixing `wss://` and `nats://` | `nats-server: remote leaf node configuration cannot have a mix of websocket and non-websocket urls: ["wss://example.com:443" "nats://example.com:7422"]` |

## 12 · The two silent no-listener cases

| config | result |
|---|---|
| `mqtt { }` — no `listen`, no `port` | server starts; log shows only `[INF] Listening for client connections on 0.0.0.0:4299`. **No MQTT line, no warning, no error.** |
| `websocket { no_tls: true }` — no port | server starts; **no websocket line at all.** |
| `websocket { listen: …, no_tls: true }` | `[INF] Listening for websocket clients on ws://127.0.0.1:18080`<br>`[WRN] Websocket not configured with TLS. DO NOT USE IN PRODUCTION!` |

## 13 · The WebSocket origin check

```
websocket {
  listen: 127.0.0.1:18081
  no_tls: true
  allowed_origins [ "http://localhost:8000" ]
}
```

Raw handshakes (a fresh `Sec-WebSocket-Key` each time):

| `Origin` sent | status line |
|---|---|
| `http://localhost:8000` | `HTTP/1.1 101 Switching Protocols` |
| `http://127.0.0.1:8000` | `HTTP/1.1 403 Forbidden` |
| `https://localhost:8000` | `HTTP/1.1 403 Forbidden` |
| `http://localhost:8001` | `HTTP/1.1 403 Forbidden` |
| `http://localhost` | `HTTP/1.1 403 Forbidden` |
| `https://evil.example` | `HTTP/1.1 403 Forbidden` |
| **no `Origin` header at all** | **`HTTP/1.1 101 Switching Protocols`** |

The docs' five-row table reproduced exactly, plus the row that matters most: **a request with no
`Origin` header is admitted.** And the CLI, which sends none, connects straight through an
origin-restricted listener:

```
nats -s ws://127.0.0.1:18081 pub probe.origin "hello"
00:03:18 Published 5 bytes to "probe.origin"
```

**A methodology note, because it nearly produced a false finding.** A first attempt reported `400`
for every origin including the allowed one. That was a shell-quoting bug — `${1:+-H "Origin: $1"}`
word-splits and hands curl a malformed header — not server behaviour. The table above was re-run from
Python, building the handshake by hand. Reusing one `Sec-WebSocket-Key` across requests also draws
`websocket handshake error: invalid websocket key`.

## 14 · MQTT stream replicas are derived from the `routes` list, not the cluster

A genuine **three-node** cluster (`east`, n1/n2/n3), in which **n1 lists only two routes**:

```
cluster {
  name: east
  listen: 127.0.0.1:6291
  routes: [ nats://127.0.0.1:6292, nats://127.0.0.1:6293 ]
}
mqtt { listen: 127.0.0.1:1881 }
```

`/varz` on n1: `routes ['127.0.0.1:6292', '127.0.0.1:6293']`; `/routez`: `num_routes: 4`;
`/jsz?meta=1`: `meta leader: n1, cluster size: 3`. So the cluster is fully formed and has three
members. The MQTT streams created by n1:

```
$MQTT_msgs     R=2
$MQTT_out      R=2
$MQTT_qos2in   R=2
$MQTT_rmsgs    R=2
$MQTT_sess     R=2
```

**R=2 on a three-node cluster**, exactly as the chapter warns. The server announces the number it
chose:

```
[INF] Creating MQTT streams/consumers with replicas 2 for account "$G"
```

With `mqtt { listen: …, stream_replicas: 3 }` on the same two-route node, and stores wiped:

```
$MQTT_msgs  R=3   $MQTT_out  R=3   $MQTT_qos2in  R=3   $MQTT_rmsgs  R=3   $MQTT_sess  R=3
```

## 15 · What "streams fail to create" looks like from the device

While experiment 14 was being set up, n3 was down (`[FTL] Unable to listen for MQTT connections:
listen tcp 127.0.0.1:1883: bind: address already in use`), leaving a two-node cluster asked for
`stream_replicas: 3`. The result is worth recording because it is the failure mode the chapter names
in half a sentence:

```
[INF] Creating MQTT streams/consumers with replicas 3 for account "$G"
[ERR] 127.0.0.1:50068 - mid:25 - "cluster-probe3" - unable to connect: create sessions stream
      for account "$G": no suitable peers for placement (10005)
```

and, earlier, with the meta leader not yet elected:

```
[WRN] 127.0.0.1:49958 - mid:18 - "cluster-probe2" - Readloop processing time: 5.000711166s
[ERR] ... unable to connect: lookup sessions stream for account "$G": timeout after 5.000369875s:
      request type "SL" on "$JS.API.STREAM.INFO.$MQTT_sess"
```

**The device sees the TCP connection closed with no CONNACK at all** — not a return code, not an
authorization error, nothing an MQTT client can report. The diagnosis is only in the server log, and
the error is `10005`, the same one [[no-suitable-peers-for-placement]] covers.

## What was not run

- **MQTT over WebSocket** (`MQTT_WS`), and the `MQTT clients over websocket must connect to the
  Websocket port` error.
- **`same_origin: true`**, the cookie settings (`jwt_cookie`, `user_cookie`, `pass_cookie`,
  `token_cookie`), and `compress` — all require operator mode or a browser.
- **`allowed_connection_types`** in any form; **operator-mode bearer JWT** authentication for MQTT.
- **A leafnode over WebSocket** end to end; only the mixed-scheme startup refusal was run.
- **`ack_wait` redelivery timing** and the client-ID flapping window (~1 s), both of which need a
  timing harness rather than a probe.
- Anything about **WebSocket connection counts** (question-bank Q78).
