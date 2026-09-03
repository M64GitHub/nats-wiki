---
title: MQTT
type: concept
area: [interop, jetstream, security]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [mqtt, qos, retained, sessions, client-id, topic-conversion, "$MQTT", stream_replicas, MQTT_WS]
aliases: [MQTT, mqtt, "mqtt {}", MQTT broker, "$MQTT", MQTT_WS, mosquitto]
sources: [s-docs-mqtt-your-first-mqtt-client, s-docs-mqtt-topics-and-subjects, s-docs-mqtt-qos-sessions-and-retained, s-docs-mqtt-auth-and-clustering, s-nats-server-mqtt-websocket-observed, s-nats-server-monitoring-observed, s-gh-7533-quorum-loss-mqtt, s-nats-server-kick-ldm-mqtt-session, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14]
created: 2026-09-01
updated: 2026-09-03
---

# MQTT

`nats-server` **is** an MQTT broker — not a bridge to one. One binary holds a listener for NATS
clients and another for MQTT devices, and the conversion between them happens inside the server, so a
device publishes plain MQTT and every NATS subscriber, stream and service sees ordinary NATS traffic
(source: [[s-docs-mqtt-your-first-mqtt-client]]).

Only **MQTT v3.1.1** is supported; a CONNECT carrying protocol level 5 is refused with CONNACK return
code **1**, "unacceptable protocol version" (observed on 2.14.6, source:
[[s-nats-server-mqtt-websocket-observed]]).

## What it needs before it will start

Two things, and both fail in ways worth knowing.

**JetStream.** MQTT keeps sessions, retained messages and in-flight QoS 1/2 deliveries in streams, so
a standalone server with an `mqtt {}` block and no `jetstream {}` block **refuses to start**:

```
nats-server: mqtt requires JetStream to be enabled if running in standalone mode
```

The scope is in the message: a server with a `cluster`, `gateway` or `leafnode` block can reach
JetStream elsewhere, so the check does not apply there. The requirement is **also per account** — an
MQTT user whose account has no JetStream is refused at connect time (source:
[[s-docs-mqtt-your-first-mqtt-client]]).

**A port.** There is **no default**. An `mqtt {}` block with neither `listen` nor `port` disables MQTT
**silently — no error, no warning, no log line** (confirmed on 2.14.6). The only confirmation is the
log:

```
[INF] Listening for MQTT clients on mqtt://127.0.0.1:1883
```

Once the server has a `cluster` or `gateway` block, **`server_name` becomes required** or startup
fails with `mqtt requires server name to be explicitly set` (source:
[[s-docs-mqtt-auth-and-clustering]]).

```
jetstream { store_dir: "/data/js" }
mqtt { listen: 127.0.0.1:1883 }
```

## Topics become subjects

The server rewrites the separator and escapes what would otherwise be an invalid subject. All ten rules
below were **checked against 2.14.6 and all ten matched** (source:
[[s-nats-server-mqtt-websocket-observed]]; the table is [[s-docs-mqtt-topics-and-subjects]]'s).

| MQTT topic | NATS subject | rule |
|---|---|---|
| `sensors/cold-1/temp` | `sensors.cold-1.temp` | `/` between levels becomes `.` |
| `/sensors/temp` | `/.sensors.temp` | a leading `/` becomes `/.` |
| `sensors/temp/` | `sensors.temp./` | a trailing `/` becomes `./` |
| `sensors//temp` | `sensors./.temp` | a `/` next to another becomes `./` |
| `//sensors/temp` | `/./.sensors.temp` | both rules in turn |
| `cold-1.temp` | `cold-1//temp` | a `.` in the topic becomes `//` |

`.` conversion arrived in **2.10**; before that a `.` in a topic was rejected.

**Wildcards**: `+` → `*`, `#` → `>`, subscribe-only in both protocols.

**`#` below the top level costs two subscriptions.** MQTT's `sensors/#` matches the parent level
`sensors` itself; NATS's `sensors.>` does not. So the server creates **two** NATS subscriptions,
`sensors.>` and `sensors`. A bare `#` needs no help. This is why a `#` filter counts twice against the
per-session budget below.

**`*` and `>` are ordinary MQTT characters and are not escaped.** `fleet/*/telemetry` becomes the real
wildcard subscription `fleet.*.telemetry` — the device asked for one literal topic and receives every
`fleet/<anything>/telemetry`. `fleet*/telemetry` stays literal, because `*` is only part of the token.

**Six characters are refused**: space, tab, newline, carriage return, form feed, DEL. The asymmetry
matters and was confirmed on 2.14.6 — **publishing closes the connection; subscribing returns
`0x80` in the SUBACK and the connection survives.** Other control characters (BEL was tested) pass
through unchanged.

## Delivery: QoS, and what each level costs

The effective level of a delivery is **the lower of the publish and the subscription**. QoS 0 is
at-most-once, QoS 1 at-least-once with redelivery after `ack_wait` (**default 30s**), QoS 2
exactly-once through a four-packet handshake.

**A NATS publish always arrives at an MQTT subscriber as QoS 0.** Nothing in a NATS message carries a
QoS, so there is nothing to promote. A device subscribed at QoS 1 to a subject NATS clients publish to
gets at-most-once delivery in practice; if that traffic must survive the device being offline, put it
in a [[stream]] and replay it (source: [[s-docs-mqtt-qos-sessions-and-retained]]).

### The five streams, and the price of each level

The chapter says the state "lives in the JetStream streams the server created" and **never names
one**. Measured on 2.14.6, they are created **lazily on the first MQTT connection** (source:
[[s-nats-server-mqtt-websocket-observed]]):

| stream | subjects | retention | discard | `max_msgs_per_subject` | holds |
|---|---|---|---|---|---|
| `$MQTT_sess` | `$MQTT.sess.>` | limits | old | 1 | one session record per client id |
| `$MQTT_msgs` | `$MQTT.msgs.>` | **interest** | old | -1 | QoS 1/2 messages awaiting ack |
| `$MQTT_out` | `$MQTT.out.>` | **interest** | old | -1 | outbound PUBREL state for QoS 2 delivery |
| `$MQTT_qos2in` | `$MQTT.qos2.in.>` | limits | **new** | 1 | inbound QoS 2 dedup records |
| `$MQTT_rmsgs` | `$MQTT.rmsgs.>` | limits | old | 1 | retained messages, one per topic |

With a 100-byte payload and one durable QoS-2 subscriber:

| publish | cost |
|---|---|
| **QoS 0** | **nothing** — no stream moves |
| **QoS 1** | one message in `$MQTT_msgs`, **194 bytes** |
| **QoS 2**, handshake completed | **the same** — one message, 194 bytes |
| **retained, at QoS 0** | **174 bytes** in `$MQTT_rmsgs` |

So **QoS 2 does not cost more stored bytes than QoS 1** — it costs round trips and transient state. And
a **retained message is stored even at QoS 0**, which is why the account needs JetStream for a fleet
that never uses QoS 1 at all.

A session record is **104 bytes bare and 791 bytes with a single subscription**: the subscription is
the expensive part, not the session.

### An abandoned QoS 2 handshake leaks a record

A PUBLISH at QoS 2 whose PUBREL never arrives leaves a record in `$MQTT_qos2in` that **survives the
disconnect and never expires** (`max_age: 0`). A completed `PUBREC → PUBREL → PUBCOMP` leaves nothing.
The subject is `$MQTT.qos2.in.<client-id>.<packet-id>` with `max_msgs_per_subject: 1`, so the leak is
**bounded at 65,535 records per client id** — and unbounded in the number of distinct client ids
(observed, source: [[s-nats-server-mqtt-websocket-observed]]).

### How many messages can be in flight

`max_ack_pending` caps QoS 1 and 2 messages in flight per subscription. **Default 1024**, range
0–65535, and **`0` means "use the default"**, not "none". The per-session total across all
subscriptions cannot exceed **65535**, and a `#` filter counts twice.

The arithmetic that follows was confirmed exactly on 2.14.6: at the default, a session takes
**63 plain subscriptions** (the 64th is refused) or **31 `#` subscriptions** (the 32nd is refused),
and the refusal is `0x80` in the SUBACK — "easy to misread as a permissions problem". Lower
`max_ack_pending` if a device needs more subscriptions. Like `ack_wait`, a change applies only to
subscriptions created after it.

## Sessions, client ids, wills and retained messages

A **session** is keyed by the **client ID**, not the connection, which is what lets it survive a
reconnect; it is stored in `$MQTT_sess` and outlives a server restart. The `clean session` flag clears
stored state and scopes the session to the connection. A client ID must be a valid NATS subject token;
an empty one is allowed only with clean session, and the server generates it.

**Duplicate client ids evict each other.** The spec requires the newcomer to win, so two devices
sharing an id knock each other off on every reconnect; the server records the id as flapping and
refuses to hand the session over again "for about a second", which slows the cycle without stopping
it. Across a cluster the eviction travels between servers, so both connections can be briefly alive.

**A will** is registered in CONNECT and published only on an **abnormal** disconnect — a clean
DISCONNECT discards it silently, so a liveness test that stops the device politely proves nothing. The
will topic converts like any other, so `fleet/truck-17/status` reaches NATS subscribers on
`fleet.truck-17.status`.

**Retained messages** are one per topic, replaced rather than queued, and deleted by publishing an
empty payload with RETAIN. Retention is per topic name, not per filter, so a wildcard subscriber
receives the retained message for every matching topic.

### Stale sessions stop QoS 1 messages from ever being deleted

`$MQTT_msgs` uses **interest retention**, so a message is removed when every interested consumer has
acked. A session that vanished still has its durable consumer, so it still holds interest — and
nothing is ever removed. Reproduced on 2.14.6: three durable sessions subscribed at QoS 1 and killed,
then five publishes, left `$MQTT_msgs` at 5 messages that did not drain. Reconnecting each dead client
id **once with the clean-session flag** took it straight back to zero.

This is the mechanism behind an **unanswered** public question (question-bank Q81,
[gh#7397](https://github.com/nats-io/nats-server/discussions/7397), open since 2025-10-06), whose
reporter has devices rotating client ids and finds messages never deleted. No public source connects
the two facts (source: [[s-nats-server-mqtt-websocket-observed]]).

## Security

**Permissions are checked against the converted subject**, always. A rule written `sensors/#` matches
nothing; the rule you want is `sensors.>`. And because a `#` filter creates two subscriptions, both
must be granted or the **whole filter** fails with `0x80` — the server tears down the `sensors.>`
subscription it had already created:

```
subscribe: ["sensors.>", "sensors"]
```

**`allowed_connection_types` pins a user to a transport.** The full set is `STANDARD`, `WEBSOCKET`,
`LEAFNODE`, `LEAFNODE_WS`, `MQTT`, `MQTT_WS`, `IN_PROCESS`; omitting it allows every type, which is
the default. A browser-based MQTT client needs **`MQTT_WS`**, not `MQTT`. Aliases: `connection_types`,
`clients`. See [[subject-permissions]].

**Leave `$MQTT.sub.>` out of permission lists entirely.** From **2.12.3** an MQTT connection is
implicitly allowed to subscribe to `$MQTT.sub.` and `$MQTT.deliver.pubrel.`; before that (2.10, 2.11)
you had to allow `$MQTT.sub.>` or every QoS 1/2 subscription failed with `0x80`. **Deny is still
enforced** — an explicit deny breaks QoS 1 and 2 while QoS 0 keeps working, so the fleet looks
half-broken. Do not allow it and do not deny it (source: [[s-docs-mqtt-auth-and-clustering]]).

**In [[operator-mode]] the device sends its JWT as the MQTT password**, with any non-empty username,
because nothing in MQTT can sign a server nonce. That needs the user *and* the account marked bearer:

```
nats auth account edit SENSORS --bearer
nats auth user add sensor SENSORS --bearer
```

Miss either and the device sees **CONNACK return code 5**, not the `Authorization Violation` string a
NATS client would get. `no_auth_user` does not work in operator mode at all.

The `mqtt {}` block takes its own `tls {}`, its own `authorization {}`, and its own `no_auth_user`
which overrides the top-level one for MQTT connections — useful when firmware cannot send credentials.
A listener-scoped username or token cannot be combined with a top-level `users` list.

## In a cluster

**Replica count is derived from the `routes` list, not from the cluster.** The server counts the
addresses in its own `routes` and clamps to 1–3. Confirmed on 2.14.6: a genuine **three-node** cluster
whose node listed **two** routes created all five MQTT streams at **`R=2`**. The server says which it
chose:

```
[INF] Creating MQTT streams/consumers with replicas 2 for account "$G"
```

Set it explicitly instead:

```
mqtt { listen: 127.0.0.1:1883, stream_replicas: 3 }
```

**Ask for more replicas than the cluster can satisfy and MQTT clients simply cannot connect.** The
device gets the TCP connection closed with **no CONNACK at all** — nothing an MQTT client can report —
and the diagnosis is only in the server log:

```
[ERR] ... unable to connect: create sessions stream for account "$G":
      no suitable peers for placement (10005)
```

which is [[no-suitable-peers-for-placement]] arriving through an unexpected door.

**Two cluster caveats** (source: [[s-docs-mqtt-auth-and-clustering]]). Retained messages are
**best-effort**: a subscriber connecting to a different server microseconds later may see nothing, so
an application that must read a retained value immediately should connect to the server that produced
it. And client-ID collision detection is slower, so both connections can be briefly alive.

**On a leaf node**, `js_domain` selects the [[jetstream-domain]] MQTT stores state in. Point it at the
leaf's own domain and sessions and retained messages stay local, so devices keep working when the link
to the hub is down; the domain is part of the session's storage identity, which is what keeps sessions
in different domains from colliding. A leaf need not run JetStream itself — the standalone check does
not apply once a `leafnodes` block exists.

## What you can observe

| where | what |
|---|---|
| log | `Listening for MQTT clients on mqtt://…`; `Creating MQTT streams/consumers with replicas N for account "…"` |
| `/connz?mqtt_client=truck-17` | filter connections by MQTT client id; each record carries `mqtt_client` |
| `/varz` | an `mqtt` section with the listener's resolved settings, including the JetStream domain |
| `nats stream ls -a` | the five `$MQTT_*` streams and their replica counts |
| a NATS subscriber | the `Nmqtt-Pub` header, carrying the QoS (0, 1 or 2) — confirmed on 2.14.6 |

See [[monitoring-endpoints]].

## MQTT connections have no RTT

`sendRTTPingLocked` returns false immediately for an MQTT connection (`client.go:2671–2673`, v2.14.6),
so the server never sends one an RTT PING. A `/connz` entry for an MQTT client therefore never gets the
ping-derived `rtt` that a NATS client eventually does — see
[[monitoring-endpoints]] for what that field means and how stale it can be on any connection
(source: [[s-nats-server-monitoring-observed]]). Use `/connz?mqtt_client=<id>` for what MQTT
connections *do* expose.

## Two connect errors that come from the cluster, not from MQTT

Both were reported in the same incident on 2.12.1 — 30 QoS 1 clients on a three-node Kubernetes
cluster, failing one after another after days of stable operation (source:
[[s-gh-7533-quorum-loss-mqtt]]):

```
unable to connect: unable to persist session "<client id>" (seq=40344): wrong last sequence: 0 (10071)
unable to connect: loading session record for account "default", session "<client id>": JetStream system temporarily unavailable (10008)
```

**`10071`** is the stream refusing a conditional publish. The server writes a session record to
`$MQTT_sess` with `Nats-Expected-Last-Subject-Sequence` set to the sequence it stored last time;
`wrong last sequence: 0` says the stream now holds **no** record on that subject — the record the
server remembered writing was gone as the stream then reported it (source:
[[s-nats-server-kick-ldm-mqtt-session]]). **`10008`** is the server believing the JetStream meta group
has no leader ([[meta-layer]]). Neither is an MQTT fault; the sequence that followed them — 5-second
`MS` timeouts on `$MQTT.msgs.…`, then a `$MQTT_msgs` consumer with `NO quorum, stalled` — is
[[stream-leader-keeps-moving]]. The thread was never answered; what made the session record vanish
first is not known in public.


## Version notes: the 2.10 line

- **QoS 2 is since 2.10.0** (#4349, #4440); retained messages moved to KV semantics "instead of
  holding retained messages in memory" (#4199, #4228); topics with `.` (#4243); the `RETAIN` flag set
  on delivery to new subscriptions only (#4443) (source: [[s-relnotes-2.10]]).
- **2.10.4**: "config options to disable QoS 2 support" (#4705) — the config reference documents
  `reject_qos2_publish` and `downgrade_qos2_subscribe`; the release body and the PR title name
  neither — and a standalone server no longer needs `server_name` for MQTT (#4679).
- **2.10.17, the line's only `### Changed`**: "Do not wait for JS responses when disconnecting the
  session" (#5575).
- Fixes worth knowing on an older 2.10: a retained-message memory leak (2.10.4, #4665), retained
  messages broken when the server name contains `.` (2.10.11, #5048), rapid load-balanced reconnects
  racing (2.10.5, #4734), the PUBREL header incompatibility and crash (2.10.2, #4616; 2.10.3, #4646).


### The 2.11 line

- **2.11.0**: SparkplugB Aware support (#5241). **2.11.3**: **`mqtt { js_api_timeout }`** — "how long
  to wait for JetStream operations caused by MQTT calls" (#6833; the config reference gives `5s`)
  (source: [[s-relnotes-2.11]]).
- **2.11.12, seven fixes**: `max_payload` enforced for MQTT clients (#7555); a reload panic when the
  user lacked permission on retained messages (#7596); account mapping for JetStream API requests
  through servers without JetStream (#7598); QoS 0 across imports and exports with subject mappings
  (#7605); retained messages loading after a restart (#7616) and **"a bug which could corrupt retained
  messages in clustered deployments"** (#7622); QoS 2 messages retrievable after a restart (#7643);
  `$MQTT.` subscription permissions handled implicitly except `deny` (#7637); retained messages
  sourced from another account with a transform (#7636).
- **2.11.15, three CVEs** (CVE-2026-33216, -33217, -33215) and the protocol tightened (#7933):
  `SUB`/`UNSUB` with packet identifier 0 rejected (#7805); a panic on invalid fixed32/fixed64 fields
  (#7941); **a persisted session can only be restored by the matching client ID**; the implicit
  permissions restricted to the `$MQTT.sub.` and `$MQTT.deliver.pubrel.` prefixes; **MQTT passwords
  no longer exposed in the JWT field of monitoring endpoints or advisories**; NATS special characters
  (`.`, `>`, `*`, spaces, tabs) refused in client IDs; session-flapping detection on monotonic time.


### The 2.12 line

**2.12.0**: MQTT clients no longer use TCP keepalives (#7329) (source: [[s-relnotes-2.12]]).
**2.12.7**: "the `jwt` is now correctly sent to auth callout for MQTT clients, fixing a regression
introduced in 2.12.6" (#7997, #7999). **2.12.9**: invalid characters in subjects rejected, "avoiding
protocol issues when forwarded to other connection types" (#8104, #8112). **2.12.12**: partial
`CONNECT` packets can no longer exhaust pre-authentication memory; a `PUBLISH` remaining-length
underflow no longer panics; subscriptions to `$MQTT.deliver.pubrel` rejected; subscribe `deny` rules
enforced on retained-message and QoS replay paths; a WebSocket `/mqtt` upgrade no longer panics when
MQTT is disabled. **2.12.14**: packet identifiers for QoS 1 and 2 issued by a monotonic counter
(#8358); pending QoS 1/2 deliveries no longer leak when a subscription is downgraded to QoS 0
(#8359); QoS 2 messages released on a resumed session keep their QoS and packet ID (#8414).


### The 2.14 line

**2.14.0**: retained messages "can no longer contain the ASCII DEL character (0x7F) in the subject"
(#8071) — the one `### Changed` MQTT line of the minor (source: [[s-relnotes-2.14]]). **2.14.1**:
invalid subject characters rejected (#8104, #8112). **2.14.3**: the security batch — partial `CONNECT`
packets, the `PUBLISH` underflow panic, `$MQTT.deliver.pubrel` subscriptions, deny rules on retained
and QoS replay paths, the `/mqtt` upgrade panic with MQTT disabled. **2.14.4**: packet identifiers
for QoS 1 and 2 from a monotonic counter (#8358); pending QoS 1/2 deliveries no longer leak on a
downgrade to QoS 0 (#8359); QoS 2 messages released on a resumed session keep their QoS and packet
ID (#8414); **MQTT clients can no longer subscribe to `$MQTT.>`**, "closing a potential permission
bypass". These are the 2.12.9–2.12.14 lines under 2.14 numbers.


## Related

[[websocket]] · [[stream]] · [[subject-permissions]] · [[account]] · [[operator-mode]] ·
[[jetstream-domain]] · [[leafnode]] · [[replicas]] · [[no-suitable-peers-for-placement]] ·
[[defaults-and-limits]] · [[config-keys]]

## To verify

- **`ack_wait` redelivery timing and the ~1-second client-ID flapping window** were not run; both need
  a timing harness rather than a probe.
- **MQTT over WebSocket (`MQTT_WS`)** was not run, including the
  `MQTT clients over websocket must connect to the Websocket port` error.
- **`allowed_connection_types` and operator-mode bearer authentication** were not run; they rest on
  [[s-docs-mqtt-auth-and-clustering]] alone.
- **What collects a leaked `$MQTT_qos2in` record**, if anything, is unknown: the stream has no age
  limit and no source describes a cleanup path.
- **`since:` is `2.10`** only because that is the release the docs name for `.`-in-topic conversion.
  No source read so far states which release first shipped MQTT support; the field is the earliest
  version this page can cite, not a claim about the feature's arrival.

## Sources

[[s-docs-mqtt-your-first-mqtt-client]] · [[s-docs-mqtt-topics-and-subjects]] ·
[[s-docs-mqtt-qos-sessions-and-retained]] · [[s-docs-mqtt-auth-and-clustering]] ·
[[s-nats-server-mqtt-websocket-observed]] ·
[[s-nats-server-monitoring-observed]] · [[s-gh-7533-quorum-loss-mqtt]] · [[s-nats-server-kick-ldm-mqtt-session]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]]
