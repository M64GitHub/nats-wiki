<!-- source: https://docs.nats.io/reference/jetstream/advisory/snapshot-create.md · fetched 2026-08-31 · section: snapshot-create -->
# Snapshot Started

Stream snapshot initiated.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_CREATE.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream snapshot is created

Expand All

typeconst: "io.nats.jetstream.advisory.v1.snapshot\_create"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream being snapshotted

blocksintegerrequired

Approximate number of blocks in the snapshot

Minimum:`0`

block\_sizeintegerrequired

The size, in bytes, of every block

Minimum:`1`

▶clientobjectrequired

Details about the client that connected to the server
