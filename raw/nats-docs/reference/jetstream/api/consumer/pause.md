<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/pause.md · fetched 2026-08-31 · section: pause -->
# Pause Consumer

Pauses or resumes a consumer.

<!-- -->

## Subject

`$JS.API.CONSUMER.PAUSE.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Request

A request to the JetStream $JS.API.CONSUMER.PAUSE API

pause\_untilstring\<date-time>

Time to pause until, when empty or a time in the past will unpause the consumer

A point in time in RFC3339 format including timezone, though typically in UTC

## Response

A response from the JetStream $JS.API.CONSUMER.PAUSE API

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

pausedboolean

Indicates if after parsing the pause\_until property if the consumer was paused

pause\_untilstring\<date-time>

The deadline till the consumer will be unpaused, only usable if 'paused' is true

A point in time in RFC3339 format including timezone, though typically in UTC

pause\_remaininginteger

When paused the time remaining until unpause

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

typeconst: "io.nats.jetstream.api.v1.consumer\_pause\_response"
