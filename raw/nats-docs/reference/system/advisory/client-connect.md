<!-- source: https://docs.nats.io/reference/system/advisory/client-connect.md · fetched 2026-08-31 · section: client-connect -->
# Client Connect

Client connection events.

<!-- -->

## Subscription Subject

`$SYS.ACCOUNT.{account}.CONNECT`

Where `{account}` is the account name.

## Event Schema

Advisory published a client connects to the NATS Server

Expand All

typeconst: "io.nats.server.advisory.v1.client\_connect"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

▶serverobjectrequired

Details about the server the client connected to

▶clientobjectrequired

Details about the client that connected to the server
