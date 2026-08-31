<!-- source: https://docs.nats.io/reference/jetstream/advisory/restore-complete.md · fetched 2026-08-31 · section: restore-complete -->
# Restore Complete

Stream restore completed.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.RESTORE_COMPLETE.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream restore is completed

Expand All

typeconst: "io.nats.jetstream.advisory.v1.restore\_complete"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The Stream being restored

startstringrequired

The time the Restore process started

endstringrequired

The time the Restore was completed

bytesintegerrequired

The number of bytes that was received

Minimum:`0`

▶clientobjectrequired

Details about the client that connected to the server
