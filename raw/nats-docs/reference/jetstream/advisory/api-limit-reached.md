<!-- source: https://docs.nats.io/reference/jetstream/advisory/api-limit-reached.md · fetched 2026-08-31 · section: api-limit-reached -->
# API Limit Reached

API rate limit reached events.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.API.LIMIT_REACHED.{account}`

Where `{account}` is the account name.

## Event Schema

An Advisory when the server takes action after very high number of pending API operations

typeconst: "io.nats.jetstream.advisory.v1.api\_limit\_reached"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

serverstringrequired

The server this event originates from, either a generated ID or the configured name

Min length:`1`

domainstring

The domain of the JetStreamServer

Minimum:`1`

droppedintegerrequired

The number of messages removed from the QPI queue
