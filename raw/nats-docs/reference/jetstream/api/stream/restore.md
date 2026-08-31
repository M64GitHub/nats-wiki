<!-- source: https://docs.nats.io/reference/jetstream/api/stream/restore.md · fetched 2026-08-31 · section: restore -->
# Restore Stream

Restores a stream from a snapshot.

<!-- -->

## Subject

`$JS.API.STREAM.RESTORE.{stream}`

Where `{stream}` is the name of the stream.

## Request

A response from the JetStream $JS.API.STREAM.RESTORE API

Expand All

▶configobjectrequired

▶stateobjectrequired

## Response

A response from the JetStream $JS.API.STREAM.RESTORE API

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

deliver\_subjectstringrequired

The Subject to send restore chunks to

Min length:`1`

typeconst: "io.nats.jetstream.api.v1.stream\_restore\_response"
