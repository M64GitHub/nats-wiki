<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-leader-elected.md · fetched 2026-08-31 · section: consumer-leader-elected -->
# Consumer Leader Elected

New consumer leader elected.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when a clustered Consumer elected a new leader

Expand All

typeconst: "io.nats.jetstream.advisory.v1.consumer\_leader\_elected"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream the Consumer belongs to

consumerstringrequired

The name of the Consumer that elected a new leader

leaderstringrequired

The server name of the elected leader

▶replicasobjectrequired
