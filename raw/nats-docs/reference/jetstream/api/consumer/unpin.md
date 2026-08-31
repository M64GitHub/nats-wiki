<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/unpin.md · fetched 2026-08-31 · section: unpin -->
# Unpin Consumer

Unpins a consumer group.

<!-- -->

## Subject

`$JS.API.CONSUMER.UNPIN.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Request

A request to the JetStream $JS.API.CONSUMER.UNPIN API

groupstringrequired

The group to unpin

## Response

A response from the JetStream $JS.API.CONSUMER.UNPIN API

Expand All

▶errorobject

typeconst: "io.nats.jetstream.api.v1.consumer\_unpin\_response"required
