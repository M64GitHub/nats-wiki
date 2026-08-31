<!-- source: https://docs.nats.io/reference/jetstream/advisory/nak.md · fetched 2026-08-31 · section: nak -->
# Message Negative Acknowledgement

Message negatively acknowledged.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.MSG_NAK.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

Advisory published when a message was naked using a AckNak acknowledgement

typeconst: "io.nats.jetstream.advisory.v1.nak"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the stream where the message is stored

consumerstringrequired

The name of the consumer where the message was naked

consumer\_seqstringrequired

The sequence of the message in the consumer that was naked

Minimum:`1`

stream\_seqintegerrequired

The sequence of the message in the stream that was naked

Minimum:`1`

Maximum:`18446744073709552000`

deliveriesintegerrequired

The number of deliveries that were attempted

Minimum:`1`

domainstring

The domain of the JetStreamServer

Minimum:`1`
