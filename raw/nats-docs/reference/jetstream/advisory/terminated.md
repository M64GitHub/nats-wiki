<!-- source: https://docs.nats.io/reference/jetstream/advisory/terminated.md · fetched 2026-08-31 · section: terminated -->
# Message Terminated

Message terminated.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.{stream}.{consumer}`

Where:

* `{stream}` is the stream name
* `{consumer}` is the consumer name

## Event Schema

Advisory published when a message was terminated using a AckTerm acknowledgement

typeconst: "io.nats.jetstream.advisory.v1.terminated"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

streamstringrequired

The name of the stream where the message is stored

consumerstringrequired

The name of the consumer where the message was terminated

stream\_seqintegerrequired

The sequence of the message in the stream that was terminated

Minimum:`1`

Maximum:`18446744073709552000`

consumer\_seqstringrequired

The sequence of the message in the consumer that was terminated

Minimum:`1`

deliveriesintegerrequired

The number of deliveries that were attempted

Minimum:`1`

domainstring

The domain the JetStream instance managing the message is in

reasonstring

An optional reason indicating why the message got terminated
