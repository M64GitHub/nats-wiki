<!-- source: https://docs.nats.io/reference/jetstream/advisory/stream-action.md · fetched 2026-08-31 · section: stream-action -->
# Stream Action

Stream lifecycle events.

<!-- -->

## Subscription Subject

```
$JS.EVENT.ADVISORY.STREAM.CREATED.{stream}

$JS.EVENT.ADVISORY.STREAM.DELETED.{stream}

$JS.EVENT.ADVISORY.STREAM.UPDATED.{stream}
```

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream is created, modified or deleted

typeconst: "io.nats.jetstream.advisory.v1.stream\_action"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

actionstringrequired

The action that the event describes

Allowed values:`create``delete``modify`

streamstringrequired

The name of the Stream that's acted on

templatestring

The Stream Template that manages the Stream
