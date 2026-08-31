<!-- source: https://docs.nats.io/reference/jetstream/api/stream/names.md · fetched 2026-08-31 · section: names -->
# Stream Names

Lists stream names.

<!-- -->

## Subject

`$JS.API.STREAM.NAMES`

## Request

A request to the JetStream $JS.API.STREAM.NAMES API

subjectstring

Limit the list to streams matching this subject filter

offsetinteger

Minimum:`0`

## Response

A response from the JetStream $JS.API.STREAM.NAMES API

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

consumersstring\[]

All of the following:

totalintegerrequired

Minimum:`0`

offsetintegerrequired

Minimum:`0`

limitintegerrequired

Minimum:`0`

typeconst: "io.nats.jetstream.api.v1.stream\_names\_response"required
