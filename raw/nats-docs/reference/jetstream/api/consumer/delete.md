<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/delete.md · fetched 2026-08-31 · section: delete -->
# Delete Consumer

Deletes a consumer.

<!-- -->

## Subject

`$JS.API.CONSUMER.DELETE.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Response

A response from the JetStream $JS.API.CONSUMER.DELETE API

Expand All

One of the following:

Option

<!-- -->

1

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶errorobjectrequired

Option

<!-- -->

2

<!-- -->

(

<!-- -->

object

<!-- -->

)

successbooleanrequired

typeconst: "io.nats.jetstream.api.v1.consumer\_delete\_response"required
