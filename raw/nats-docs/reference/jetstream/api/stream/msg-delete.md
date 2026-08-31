<!-- source: https://docs.nats.io/reference/jetstream/api/stream/msg-delete.md · fetched 2026-08-31 · section: msg-delete -->
# Delete Message

Deletes a specific message from a stream.

<!-- -->

## Subject

`$JS.API.STREAM.MSG.DELETE.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.MSG.DELETE API

seqintegerrequired

Stream sequence number of the message to delete

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

no\_eraseboolean

Default will securely remove a message and rewrite the data with random data, set this to true to only remove the message

## Response

A response from the JetStream $JS.API.STREAM.MSG.DELETE API

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

typeconst: "io.nats.jetstream.api.v1.stream\_msg\_delete\_response"required
