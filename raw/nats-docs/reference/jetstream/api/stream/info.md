<!-- source: https://docs.nats.io/reference/jetstream/api/stream/info.md · fetched 2026-08-31 · section: info -->
# Stream Info

Retrieves information about a stream.

<!-- -->

## Subject

`$JS.API.STREAM.INFO.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.INFO API

deleted\_detailsboolean

When true will result in a full list of deleted message IDs being returned in the info response

subjects\_filterstring

When set will return a list of subjects and how many messages they hold for all matching subjects. Filter is a standard NATS subject wildcard pattern.

offsetinteger

Paging offset when retrieving pages of subject details

Minimum:`0`

## Response

A response from the JetStream $JS.API.STREAM.INFO API

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

▶configobjectrequired

The active configuration for the Stream

▶stateobjectrequired

Detail about the current State of the Stream

createdstring\<date-time>required

Timestamp when the stream was created

A point in time in RFC3339 format including timezone, though typically in UTC

tsstring\<date-time>

The server time the stream info was created

A point in time in RFC3339 format including timezone, though typically in UTC

▶clusterobject

▶mirrorobject

Information about an upstream stream source in a mirror

▶sourcesobject\[]

Streams being sourced into this Stream

▶alternatesobject\[]

List of mirrors sorted by priority

domainstring

The JetStream domain the stream is in

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

typeconst: "io.nats.jetstream.api.v1.stream\_info\_response"required

totalinteger

Minimum:`0`

offsetinteger

Minimum:`0`

limitinteger

Minimum:`0`
