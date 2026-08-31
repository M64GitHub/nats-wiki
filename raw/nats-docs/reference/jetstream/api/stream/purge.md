<!-- source: https://docs.nats.io/reference/jetstream/api/stream/purge.md · fetched 2026-08-31 · section: purge -->
# Purge Stream

Purges messages from a stream.

<!-- -->

## Subject

`$JS.API.STREAM.PURGE.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.PURGE API

filterstring

Restrict purging to messages that match this subject

seqinteger

Purge all messages up to but not including the message with this sequence. Can be combined with subject filter but not the keep option

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

keepinteger

Ensures this many messages are present after the purge. Can be combined with the subject filter but not the sequence

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

## Response

A response from the JetStream $JS.API.STREAM.PURGE API

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

purgedintegerrequired

Number of messages purged from the Stream

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

typeconst: "io.nats.jetstream.api.v1.stream\_purge\_response"required
