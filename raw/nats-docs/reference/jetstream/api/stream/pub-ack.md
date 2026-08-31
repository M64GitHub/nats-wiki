<!-- source: https://docs.nats.io/reference/jetstream/api/stream/pub-ack.md · fetched 2026-08-31 · section: pub-ack -->
# Publish Acknowledgement

Publishes a message directly to a stream and receives an acknowledgement.

<!-- -->

## Subject

Messages are published directly to the stream's subjects (as configured in the stream). The acknowledgement is returned as a response to the publish operation.

## Schema

A response received when publishing a message

Expand All

▶errorobject

streamstringrequired

The name of the stream that received the message

Min length:`1`

seqinteger

If successful this will be the sequence the message is stored at

unsigned 64 bit integer

Minimum:`0`

Maximum:`18446744073709552000`

duplicateboolean

Indicates that the message was not stored due to the Nats-Msg-Id header and duplicate tracking

Default:`false`

domainstring

If the Stream accepting the message is in a JetStream server configured for a domain this would be that domain

batchstring

When doing Atomic Batch Publishes this will be the Batch ID being committed

countinteger

When doing Atomic Batch Publishes how many messages was in the batch

valstring

The current value of the counter on counter enabled streams
