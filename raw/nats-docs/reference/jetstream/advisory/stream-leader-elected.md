<!-- source: https://docs.nats.io/reference/jetstream/advisory/stream-leader-elected.md · fetched 2026-08-31 · section: stream-leader-elected -->
# Stream Leader Elected

New stream leader elected.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a clustered Stream elected a new leader

Expand All

typeconst: "io.nats.jetstream.advisory.v1.stream\_leader\_elected"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream that elected a leader

leaderstringrequired

The server name of the elected leader

▶replicasobjectrequired
