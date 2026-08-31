<!-- source: https://docs.nats.io/reference/jetstream/api/stream/remove-peer.md · fetched 2026-08-31 · section: remove-peer -->
# Remove Peer

Removes a peer from a stream cluster.

<!-- -->

## Subject

`$JS.API.STREAM.PEER.REMOVE.{stream}`

Where `{stream}` is the name of the stream.

## Request

A request to the JetStream $JS.API.STREAM.PEER.REMOVE API

peerstringrequired

Server name of the peer to remove

Min length:`1`

## Response

A response from the JetStream $JS.API.STREAM.PEER.REMOVE API

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

If the peer was successfully removed

Default:`false`

typeconst: "io.nats.jetstream.api.v1.stream\_remove\_peer\_response"
