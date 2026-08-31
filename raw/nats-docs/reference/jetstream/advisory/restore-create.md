<!-- source: https://docs.nats.io/reference/jetstream/advisory/restore-create.md · fetched 2026-08-31 · section: restore-create -->
# Restore Started

Stream restore initiated.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream restore is started

Expand All

typeconst: "io.nats.jetstream.advisory.v1.restore\_create"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The Stream being restored

▶clientobjectrequired

Details about the client that connected to the server
