<!-- source: https://docs.nats.io/reference/jetstream.md · fetched 2026-08-31 · section: jetstream -->
# JetStream

JetStream is the persistence layer of NATS, providing message streaming, replay, and at-least-once delivery semantics.

## Components

### [API](/reference/jetstream/api/.md)

Programmatic interface for managing JetStream resources:

* [Account](/reference/jetstream/api/account/.md) - Account-level management
* [Stream](/reference/jetstream/api/stream/.md) - Stream operations and data management
* [Consumer](/reference/jetstream/api/consumer/.md) - Consumer configuration and control
* [Meta](/reference/jetstream/api/meta/.md) - Cluster metadata operations

### [Advisory](/reference/jetstream/advisory/.md)

System events for monitoring and observability:

* Stream lifecycle events (created, updated, deleted)
* Consumer state changes and leadership elections
* Cluster quorum and storage notifications
* API audit trails and rate limiting

### [Metrics](/reference/jetstream/metric/.md)

Performance and usage measurements:

* [Consumer Acknowledgement](/reference/jetstream/metric/consumer-ack.md) - Message acknowledgement latency

### [Errors](/reference/jetstream/errors.md)

Comprehensive error reference:

* Error codes and HTTP status mappings
* Detailed error descriptions
* Troubleshooting guidance

## Key Concepts

JetStream extends NATS with:

* Streams - Message storage and replay
* Consumers - Subscription state and delivery management
* Persistence - File or memory-based storage
* Replication - Multi-node redundancy
* Exactly-once - Message delivery guarantees
