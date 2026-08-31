<!-- source: https://docs.nats.io/reference/system/advisory/client-disconnect.md · fetched 2026-08-31 · section: client-disconnect -->
# Client Disconnect

Client disconnection events.

<!-- -->

## Subscription Subject

`$SYS.ACCOUNT.{account}.DISCONNECT`

Where `{account}` is the account name.

## Event Schema

Advisory published a client disconnects to the NATS Server

Expand All

typeconst: "io.nats.server.advisory.v1.client\_disconnect"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

▶serverobjectrequired

Details about the server the client connected to

▶clientobjectrequired

Details about the client that connected to the server

▶sentobjectrequired

Data sent by the client

▶receivedobjectrequired

Data sent to the client

reasonstringrequired

The reason the client disconnected
