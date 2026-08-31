<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-group-unpinned.md · fetched 2026-08-31 · section: consumer-group-unpinned -->
# Consumer Group Unpinned

Consumer group unpinned from node.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.GROUP_UNPINNED.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when a pinned\_client grouped consumer unpinned a client

typeconst: "io.nats.jetstream.advisory.v1.consumer\_group\_unpinned"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

accountstring

The account hosting the consumer

streamstringrequired

The stream hosting the consumer

consumerstringrequired

The consumer name

domainstring

The domain of the JetStreamServer

Min length:`1`

groupstringrequired

The group that unpinned a client

reasonstringrequired

The reason the client was unpinned

Allowed values:`admin``timeout`
