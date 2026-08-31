<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/get-next.md · fetched 2026-08-31 · section: get-next -->
# Get Next Message

Gets next message(s) from a consumer.

<!-- -->

## Subject

`$JS.API.CONSUMER.MSG.NEXT.{stream}.{consumer}`

Where `{stream}` is the stream name and `{consumer}` is the consumer name.

## Request

A request to the JetStream $JS.API.CONSUMER.MSG.NEXT API

expiresinteger

A duration from now when the pull should expire, stated in nanoseconds, 0 for no expiry

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

batchinteger

How many messages the server should deliver to the requestor

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`0`

Maximum:`256`

max\_bytesinteger

Sends at most this many bytes to the requestor, limited by consumer configuration max\_bytes

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`0`

Maximum:`9223372036854776000`

no\_waitboolean

When true a response with a 404 status header will be returned when no messages are available

idle\_heartbeatinteger

When not 0 idle heartbeats will be sent on this interval

nanoseconds depicting a duration in time, signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

groupstring

The consumer group to pull from

min\_pendinginteger

The minimum number of messages the server should have in the consumer's pending queue before serving this pull

signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

min\_ack\_pendinginteger

The minimum number of messages the server should have in the consumer's ack pending queue before serving this pull

signed 64 bit integer

Minimum:`0`

Maximum:`9223372036854776000`

idstring

When pulling from a Pinned Client consumer this is the unique client ID

priorityinteger

The priority of the pull request

Minimum:`0`

Maximum:`9`
