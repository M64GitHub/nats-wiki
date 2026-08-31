<!-- source: https://docs.nats.io/reference/jetstream/advisory/snapshot-complete.md · fetched 2026-08-31 · section: snapshot-complete -->
# Snapshot Complete

Stream snapshot completed.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_COMPLETE.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream snapshot is completed

Expand All

typeconst: "io.nats.jetstream.advisory.v1.snapshot\_complete"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The Stream that had the snapshot

startstringrequired

The time the snapshot was created

endstringrequired

The time the snapshot was completed

▶clientobjectrequired

Details about the client that connected to the server
