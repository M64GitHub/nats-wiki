<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-quorum-lost.md · fetched 2026-08-31 · section: consumer-quorum-lost -->
# Consumer Quorum Lost

Consumer lost quorum.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.QUORUM_LOST.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when a clustered Consumer lost quorum

Expand All

typeconst: "io.nats.jetstream.advisory.v1.consumer\_quorum\_lost"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream the Consumer belongs to

consumerstringrequired

The name of the Consumer that lost quorum

▶replicasobjectrequired
