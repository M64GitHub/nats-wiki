<!-- source: https://docs.nats.io/reference/jetstream/metric/consumer-ack.md · fetched 2026-08-31 · section: consumer-ack -->
# Consumer Acknowledgement Metric

Consumer acknowledgement metrics.

<!-- -->

## Subscription Subject

`$JS.EVENT.METRIC.CONSUMER.ACK.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

Metric published when a message was acknowledged to a consumer with Ack Sampling enabled

typeconst: "io.nats.jetstream.metric.v1.consumer\_ack"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the stream where the message is stored

consumerstringrequired

The name of the consumer where the message is held

stream\_seqintegerrequired

The sequence of the message in the stream that were acknowledged

Minimum:`1`

Maximum:`18446744073709552000`

consumer\_seqintegerrequired

The sequence of the message in the consumer that were acknowledged

Minimum:`1`

ack\_timeintegerrequired

The time it took on the final delivery for the message to be acknowledged in nanoseconds

Minimum:`1`

deliveriesintegerrequired

The number of deliveries that were attempted before being acknowledged

Minimum:`1`
