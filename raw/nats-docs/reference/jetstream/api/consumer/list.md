<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/list.md · fetched 2026-08-31 · section: list -->
# List Consumers

Lists consumers for a stream.

<!-- -->

## Subject

`$JS.API.CONSUMER.LIST.{stream}`

Where `{stream}` is the stream name.

## Request

A request to the JetStream $JS.API.CONSUMER.LIST API

All of the following:

offsetintegerrequired

Minimum:`0`

## Response

A response from the JetStream $JS.API.CONSUMER.LIST API

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

▶consumersobject\[]required

Full Consumer information for each known Consumer

All of the following:

totalintegerrequired

Minimum:`0`

offsetintegerrequired

Minimum:`0`

limitintegerrequired

Minimum:`0`

typeconst: "io.nats.jetstream.api.v1.consumer\_list\_response"required
