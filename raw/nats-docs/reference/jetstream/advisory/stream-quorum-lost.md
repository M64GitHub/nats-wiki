<!-- source: https://docs.nats.io/reference/jetstream/advisory/stream-quorum-lost.md · fetched 2026-08-31 · section: stream-quorum-lost -->
# Stream Quorum Lost

Stream lost quorum.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a clustered Stream lost quorum

Expand All

typeconst: "io.nats.jetstream.advisory.v1.stream\_quorum\_lost"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream that lost quorum

▶replicasobjectrequired
