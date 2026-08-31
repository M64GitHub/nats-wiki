<!-- source: https://docs.nats.io/reference/jetstream/advisory/api-audit.md · fetched 2026-08-31 · section: api-audit -->
# API Audit

JetStream API audit events.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.API`

## Event Schema

Advisory published when the JetStream API is accessed across the network

Expand All

typeconst: "io.nats.jetstream.advisory.v1.api\_audit"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

serverstringrequired

The server this event originates from, either a generated ID or the configured name

Min length:`1`

subjectstringrequired

The subject the admin API request was received on

Min length:`1`

responsestringrequired

The full unparsed body of the response sent to the caller

requeststring

The full unparsed body of the request received from the client

▶clientobjectrequired

Details about the client that connected to the server
