<!-- source: https://docs.nats.io/reference/jetstream/api/stream/msg-get.md · fetched 2026-08-31 · section: msg-get -->
# Get Message

Retrieves a specific message from a stream.

<!-- -->

## Subject

`$JS.API.STREAM.MSG.GET.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.MSG.GET API

seqinteger

Stream sequence number of the message to retrieve, cannot be combined with last\_by\_subj

last\_by\_subjstring

Retrieves the last message for a given subject, cannot be combined with seq

next\_by\_subjstring

Combined with sequence gets the next message for a subject with the given sequence or higher

batchinteger

Request a number of messages to be delivered

max\_bytesinteger

Restrict batch get to a certain maximum cumulative bytes, defaults to server MAX\_PENDING\_SIZE

start\_timestring\<date-time>

Start the batch at a certain point in time rather than sequence

A point in time in RFC3339 format including timezone, though typically in UTC

multi\_laststring\[]

Get the last messages from the supplied subjects

up\_to\_seqinteger

Returns messages up to this sequence otherwise last sequence for the stream

up\_to\_timestring\<date-time>

Only return messages up to a point in time

A point in time in RFC3339 format including timezone, though typically in UTC

## Response

A response from the JetStream $JS.API.STREAM.MSG.GET API

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

▶messageobjectrequired

typeconst: "io.nats.jetstream.api.v1.stream\_msg\_get\_response"required
