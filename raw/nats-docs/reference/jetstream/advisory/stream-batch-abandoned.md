<!-- source: https://docs.nats.io/reference/jetstream/advisory/stream-batch-abandoned.md · fetched 2026-08-31 · section: stream-batch-abandoned -->
# Stream Batch Abandoned

An advisory sent when a stream abandons a batch.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.STREAM.BATCH_ABANDONED.{stream}`

Where `{stream}` is the stream name.

## Event Schema

An Advisory sent when a Stream abandons a batch

typeconst: "io.nats.jetstream.advisory.v1.stream\_batch\_abandoned"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

reasonstringrequired

The reason the batch was abandoned

Allowed values:`timeout``large``incomplete`

streamstringrequired

The name of the Stream that's acted on

batchstringrequired

The ID of the batch that was abandoned

accountstring

The account hosting the Stream

domainstring

The domain hosting the Stream
