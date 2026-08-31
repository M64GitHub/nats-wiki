---
title: "docs — MQTT: Auth and clustering"
type: summary
area: [interop, security, topology, jetstream]
source-url: https://docs.nats.io/learn/mqtt/auth-and-clustering.md
source-path: raw/nats-docs/learn/mqtt/auth-and-clustering.md
author: nats-io docs
article: "learn/mqtt/auth-and-clustering.md"
date: 2026-09-01
version: ""
tags: [mqtt, allowed_connection_types, bearer, stream_replicas, js_domain, "$MQTT.sub", connz, mqtt_client]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — MQTT: Auth and clustering

How a device proves who it is, and the three things that change when MQTT leaves one server. Carries
the wiki's first statement of `allowed_connection_types` and of the **replica count derived from the
`routes` list**, which is the page's most operationally surprising claim (and reproduces exactly).

## Key claims

**`allowed_connection_types` pins a user to a transport.** The full set is **`STANDARD`,
`WEBSOCKET`, `LEAFNODE`, `LEAFNODE_WS`, `MQTT`, `MQTT_WS`, `IN_PROCESS`**. "The `_WS` variants cover
the same protocol carried over WebSocket, so a browser-based MQTT client needs `MQTT_WS` rather than
`MQTT`. Omit `allowed_connection_types` entirely and every type is allowed, which is the default."
Aliases: `connection_types`, `clients`.

Presenting an MQTT-only user's credentials on the client port gives `nats: error: nats: Authorization
Violation`.

**The `mqtt {}` block takes its own `tls {}`**, separate from the client port's, "the same as any
other `tls {}` block".

**It can also carry its own `authorization {}` and `no_auth_user`**, which "overrides the top-level
one for MQTT connections… it maps credential-less MQTT connections onto one of the users defined in
the top-level `users` list". Two limits: "a listener-scoped username or token can't be combined with a
top-level `users` list, and `no_auth_user` doesn't work in operator mode."

**`$MQTT.sub.>` — do not allow it and do not deny it.** "From server **2.12.3**, an MQTT connection is
implicitly allowed to subscribe to `$MQTT.sub.` and `$MQTT.deliver.pubrel.` subjects: the allow-list
check is skipped for them. Before 2.12.3 — including 2.10 and 2.11 — you have to list `$MQTT.sub.>` in
the user's subscribe allow list, or every QoS 1 and 2 subscription fails with `0x80` in the SUBACK."
But: "**Deny is still enforced.** An explicit deny on `$MQTT.sub.>` stops the server from creating the
internal subscription."

**Operator mode authenticates MQTT devices with a bearer JWT as the password.** "MQTT clients can't
[sign a nonce]. There's nothing in the MQTT protocol that signs a server-supplied nonce." So "the
device sends the JWT as the MQTT **password**, with any non-empty username". It requires **two**
settings, because accounts disallow bearer tokens by default:

```
nats auth account edit SENSORS --bearer
nats auth user add sensor SENSORS --bearer
```

"Miss either one and the connection is refused… The device sees a CONNACK with **return code 5**, 'not
authorized' — MQTT clients get that rather than the `Authorization Violation` error a NATS client
would receive, so check the CONNACK code rather than looking for that string."

**`server_name` becomes required** once the server has a `cluster` or `gateway` block:
`mqtt requires server name to be explicitly set`.

**Stream replicas are derived from the `routes` list, not the cluster.** "The server counts the
addresses in its own `routes` list, then clamps the result to between 1 and 3… `n1-east` lists two
routes, so its MQTT streams come up at **`R=2`, not `R=3`** — enough to survive one server, but not
what you'd guess from a three-node cluster." `stream_replicas` overrides it. "Ask for more replicas
than the cluster can satisfy and the streams fail to create, which surfaces as MQTT clients being
unable to connect."

**`js_domain` puts MQTT state in a named JetStream domain**, which is how a leaf keeps sessions local:
"Set it to the leaf's local domain and sessions and retained messages stay on the leaf, so local
devices keep working when the link to the hub is down. The domain is part of the session's storage
identity, which is also what keeps sessions in different domains from colliding." A leaf need not run
JetStream itself — "The standalone JetStream check doesn't apply once the server has a `leafnodes`
configuration".

**Two cluster caveats.** Retained messages are **best-effort**: "A publisher can retain a message on
one server while a subscriber connecting to a different server subscribes microseconds later and sees
nothing… have it connect to the server that produced it." And client-ID collision detection is slower:
"both connections can be briefly alive at once."

**Monitoring knows about MQTT**: `curl -s "http://127.0.0.1:8222/connz?mqtt_client=truck-17"`, each
connection record carrying `mqtt_client`, and "`/varz` has an `mqtt` section showing the listener's
resolved settings, including the JetStream domain in use".

## Practical takeaways

- The replica derivation is the one to act on: the ordinary "list your two peers" cluster config gives
  MQTT state `R=2` on a three-node cluster, silently. Set `stream_replicas` explicitly.
- `$MQTT.sub.>` is a rare case where the correct permission entry is **no entry at all**.

## Notable quotes

> "`n1-east` lists two routes, so its MQTT streams come up at `R=2`, not `R=3`."

> "Don't go looking for an `Authorization Violation` in the client's output — MQTT clients never
> receive that message, only the CONNACK code."

## Relevance to the wiki

`allowed_connection_types` is a security surface [[subject-permissions]] and [[account]] never
mentioned, and the replica derivation belongs on [[replicas]] and [[jetstream-sizing]] as much as on
[[mqtt]].

## Questions it answers

Q81 (partly — see below).

**It does not answer Q81 as asked.** The row asks how to restrict *which MQTT client ids* a user may
present, via JWT/nsc. This page restricts a user to a *connection type* and hands devices a bearer
JWT; nothing here constrains the client ID. See [[s-nats-server-mqtt-websocket-observed]], which
reproduces the problem behind that question.

## Pages touched

[[mqtt]] · [[subject-permissions]] · [[account]] · [[replicas]] · [[jetstream-domain]] ·
[[monitoring-endpoints]] · [[operator-mode]]

## Sources

`raw/nats-docs/learn/mqtt/auth-and-clustering.md` · verified against the server in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
