<!-- source: https://docs.nats.io/reference/jetstream/api/consumer/names.md · fetched 2026-08-31 · section: names -->
# Consumer Names

Lists consumer names for a stream.

<!-- -->

## Subject

`$JS.API.CONSUMER.NAMES.{stream}`

Where `{stream}` is the stream name.

## Request

A request to the JetStream $JS.API.CONSUMER.NAMES API

All of the following:

offsetintegerrequired

Minimum:`0`

subjectstring

Filter the names to those consuming messages matching this subject or wildcard

## Response

A response from the JetStream $JS.API.CONSUMER.NAMES API

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

consumersstring\[]required

All of the following:

totalintegerrequired

Minimum:`0`

offsetintegerrequired

Minimum:`0`

limitintegerrequired

Minimum:`0`

typeconst: "io.nats.jetstream.api.v1.consumer\_names\_response"required
