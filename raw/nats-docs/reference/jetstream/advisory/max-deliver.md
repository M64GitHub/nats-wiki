<!-- source: https://docs.nats.io/reference/jetstream/advisory/max-deliver.md · fetched 2026-08-31 · section: max-deliver -->
# Max Deliveries Exceeded

Message exceeded max delivery attempts.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

Advisory published when a message have reached its maximum delivery attempts

typeconst: "io.nats.jetstream.advisory.v1.max\_deliver"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the stream where the message is stored

consumerstringrequired

The name of the consumer where the message reached its limit

stream\_seqintegerrequired

The sequence of the message in the stream that failed

Minimum:`1`

Maximum:`18446744073709552000`

deliveriesintegerrequired

The number of deliveries that were attempted

Minimum:`1`
