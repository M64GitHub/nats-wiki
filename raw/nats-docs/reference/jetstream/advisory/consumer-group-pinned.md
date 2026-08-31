<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-group-pinned.md · fetched 2026-08-31 · section: consumer-group-pinned -->
# Consumer Group Pinned

Consumer group pinned to node.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.GROUP_PINNED.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when a pinned\_client grouped consumer pinned a client

typeconst: "io.nats.jetstream.advisory.v1.consumer\_group\_pinned"required

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

pinned\_idstringrequired

The unique server-assigned ID for the client
