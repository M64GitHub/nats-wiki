<!-- source: https://docs.nats.io/reference/jetstream/api/meta/server-remove.md · fetched 2026-08-31 · section: server-remove -->
# Server Remove

Removes a server from the JetStream cluster.

<!-- -->

## Subject

`$JS.API.META.SERVER.REMOVE`

## Request

A request to the JetStream $JS.API.SERVER.REMOVE API

peerstring

The Name of the server to remove from the meta group

peer\_idstring

Peer ID of the peer to be removed. If specified this is used instead of the server name

## Response

A response from the JetStream $JS.API.SERVER.REMOVE API

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

typeconst: "io.nats.jetstream.api.v1.meta\_server\_remove\_response"
