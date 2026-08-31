<!-- source: https://docs.nats.io/reference/jetstream/api/stream/list.md · fetched 2026-08-31 · section: list -->
# List Streams

Lists all streams.

<!-- -->

## Subject

`$JS.API.STREAM.LIST`

## Request

A request to the JetStream $JS.API.STREAM.LIST API

subjectstring

Limit the list to streams matching this subject filter

offsetinteger

Minimum:`0`

## Response

A response from the JetStream $JS.API.STREAM.LIST API

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

▶streamsobject\[]required

Full Stream information for each known Stream

missingstring\[]

In clustered environments gathering Stream info might time out, this list would be a list of Streams for which information was not obtainable

offline{ \[key: string]: string }

List of streams that are offline and reasons for being offline

All of the following:

totalintegerrequired

Minimum:`0`

offsetintegerrequired

Minimum:`0`

limitintegerrequired

Minimum:`0`

typeconst: "io.nats.jetstream.api.v1.stream\_list\_response"required
