<!-- source: https://docs.nats.io/reference/jetstream/advisory/consumer-action.md · fetched 2026-08-31 · section: consumer-action -->
# Consumer Action

Consumer lifecycle events.

<!-- -->

## Subscription Subject

```
$JS.EVENT.ADVISORY.CONSUMER.CREATED.{stream}.{consumer}

$JS.EVENT.ADVISORY.CONSUMER.DELETED.{stream}.{consumer}
```

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

An Advisory sent when a Consumer is created or deleted

typeconst: "io.nats.jetstream.advisory.v1.consumer\_action"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

actionstringrequired

The action that the event describes

Allowed values:`create``delete`

streamstringrequired

The name of the Stream that the Consumer belongs to

consumerstring

The name of the Consumer that's acted on
