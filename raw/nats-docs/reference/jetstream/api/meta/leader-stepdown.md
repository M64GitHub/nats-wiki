<!-- source: https://docs.nats.io/reference/jetstream/api/meta/leader-stepdown.md · fetched 2026-08-31 · section: leader-stepdown -->
# Meta Leader Stepdown

Initiates meta-group leader stepdown.

<!-- -->

## Subject

`$JS.API.META.LEADER.STEPDOWN`

## Request

A request to the JetStream $JS.API.META.LEADER.STEPDOWN API

Expand All

▶placementobject

Placement requirements for a Stream or asset leader

## Response

A response from the JetStream $JS.API.META.LEADER.STEPDOWN API

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

typeconst: "io.nats.jetstream.api.v1.meta\_leader\_stepdown\_response"
