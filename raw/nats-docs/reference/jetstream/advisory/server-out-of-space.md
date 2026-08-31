<!-- source: https://docs.nats.io/reference/jetstream/advisory/server-out-of-space.md · fetched 2026-08-31 · section: server-out-of-space -->
# Server Out of Space

Server storage exhausted.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE`

## Event Schema

An Advisory sent when a Server has run out of disk space

typeconst: "io.nats.jetstream.advisory.v1.server\_out\_of\_space"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstring

The Stream that triggered the out of space event

serverstringrequired

The server name that ran out of space

server\_idstringrequired

The server ID that ran out of space

clusterstring

The cluster the server is in
