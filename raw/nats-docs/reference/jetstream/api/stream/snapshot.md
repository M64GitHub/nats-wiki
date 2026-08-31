<!-- source: https://docs.nats.io/reference/jetstream/api/stream/snapshot.md · fetched 2026-08-31 · section: snapshot -->
# Snapshot Stream

Creates a snapshot of a stream.

<!-- -->

## Subject

`$JS.API.STREAM.SNAPSHOT.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.SNAPSHOT API

deliver\_subjectstringrequired

The NATS subject where the snapshot will be delivered

Min length:`1`

no\_consumersboolean

When true consumer states and configurations will not be present in the snapshot

chunk\_sizeinteger

The size of data chunks to send to deliver\_subject

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`1024`

Maximum:`9223372036854776000`

window\_sizeinteger

The size of the window to use for the snapshot

integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit

Minimum:`1024`

Maximum:`33554432`

jsckboolean

Check all message's checksums prior to snapshot

Default:`false`

## Response

A response from the JetStream $JS.API.STREAM.SNAPSHOT API

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

▶configobjectrequired

▶stateobjectrequired

typeconst: "io.nats.jetstream.api.v1.stream\_snapshot\_response"
