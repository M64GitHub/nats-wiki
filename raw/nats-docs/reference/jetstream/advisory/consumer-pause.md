<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-pause.md · fetched 2026-08-31 · section: consumer-pause -->
# Consumer Pause

Consumer paused or resumed.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.PAUSE.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when consumer is paused or resumed

typeconst: "io.nats.jetstream.advisory.v1.consumer\_pause"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the Stream the Consumer belongs to

consumerstringrequired

The name of the Consumer that elected a new leader

pausedbooleanrequired

Indicates the consumer is paused

pause\_untilstring

When paused the time the consumer will be unpaused, RFC3339 format

domainstring

The domain hosting the Stream and Consumer if configured
