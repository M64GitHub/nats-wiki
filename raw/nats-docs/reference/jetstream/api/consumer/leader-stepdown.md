<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/leader-stepdown.md · fetched 2026-08-31 · section: leader-stepdown -->
# Leader Stepdown

Initiates leader stepdown for a consumer.

<!-- -->

## Subject

`$JS.API.CONSUMER.LEADER.STEPDOWN.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Request

A request for the JetStream $JS.API.CONSUMER.LEADER.STEPDOWN API

Expand All

▶placementobject

Placement directives to consider when placing the leader

## Response

A response from the JetStream $JS.API.CONSUMER.LEADER.STEPDOWN API

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

If the leader successfully stood down

Default:`false`

typeconst: "io.nats.jetstream.api.v1.consumer\_leader\_stepdown\_response"
