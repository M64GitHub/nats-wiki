<!-- source: https://docs.nats.io/reference/jetstream/api/stream/delete.md · fetched 2026-08-31 · section: delete -->
# Delete Stream

Deletes an existing stream.

<!-- -->

## Subject

`$JS.API.STREAM.DELETE.{stream}`

Where `{stream}` is the name of the stream to delete.

## Response

A response from the JetStream $JS.API.STREAM.DELETE API

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

typeconst: "io.nats.jetstream.api.v1.stream\_delete\_response"required
