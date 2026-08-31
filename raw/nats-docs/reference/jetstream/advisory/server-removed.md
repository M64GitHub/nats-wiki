<!-- source: https://docs.nats.io/reference/jetstream/advisory/server-removed.md · fetched 2026-08-31 · section: server-removed -->
# Server Removed

Server removed from cluster.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.SERVER.REMOVED`

## Event Schema

An Advisory sent when a Server has been removed from the cluster

typeconst: "io.nats.jetstream.advisory.v1.server\_removed"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

serverstringrequired

The server name that was remove

server\_idstringrequired

The server ID that was remove

clusterstringrequired

The cluster the server was in

domainstring

The domain the server was in
