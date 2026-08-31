<!-- source: https://docs.nats.io/reference/jetstream/api/stream/leader-stepdown.md · fetched 2026-08-31 · section: leader-stepdown -->
# Leader Stepdown

Initiates leader stepdown for a stream.

<!-- -->

## Subject

`$JS.API.STREAM.LEADER.STEPDOWN.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request for the JetStream $JS.API.STREAM.LEADER.STEPDOWN API

Expand All

▶placementobject

Placement directives to consider when placing the leader

## Response

A response from the JetStream $JS.API.STREAM.LEADER.STEPDOWN API

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

typeconst: "io.nats.jetstream.api.v1.stream\_leader\_stepdown\_response"
