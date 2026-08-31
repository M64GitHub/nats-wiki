<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/info.md · fetched 2026-08-31 · section: info -->
# Consumer Info

Retrieves consumer information.

<!-- -->

## Subject

`$JS.API.CONSUMER.INFO.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Response

A response from the JetStream $JS.API.CONSUMER.INFO API

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

stream\_namestringrequired

The Stream the consumer belongs to

namestringrequired

A unique name for the consumer, either machine generated or the durable name

tsstring\<date-time>

The server time the consumer info was created

A point in time in RFC3339 format including timezone, though typically in UTC

▶configallOfrequired

createdstring\<date-time>required

The time the Consumer was created

A point in time in RFC3339 format including timezone, though typically in UTC

▶deliveredobjectrequired

The last message delivered from this Consumer

▶ack\_floorobjectrequired

The highest contiguous acknowledged message

num\_ack\_pendingintegerrequired

The number of messages pending acknowledgement

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`0`

Maximum:`9223372036854776000`

num\_redeliveredintegerrequired

The number of redeliveries that have been performed

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`0`

Maximum:`9223372036854776000`

num\_waitingintegerrequired

The number of pull consumers waiting for messages

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`0`

Maximum:`9223372036854776000`

num\_pendingintegerrequired

The number of messages left unconsumed in this Consumer

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

▶clusterobject

push\_boundboolean

Indicates if any client is connected and receiving messages from a push consumer

pausedboolean

Indicates if the consumer is currently in a paused state

pause\_remaininginteger

When paused the time remaining until unpause

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

▶priority\_groupsobject\[]

The state of Priority Groups

Option

<!-- -->

2

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶errorobjectrequired

typeconst: "io.nats.jetstream.api.v1.consumer\_info\_response"required
