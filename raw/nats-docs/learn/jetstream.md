<!-- source: https://docs.nats.io/learn/jetstream.md · fetched 2026-08-31 · section: jetstream -->
# JetStream Deep Dive

JetStream is the part of NATS that stores messages. Once a message is stored, you can read it again later, and replay it as many times as you need. Delivery is tracked per reader: a message counts as handled once it's acknowledged.

This chapter builds that up one page at a time, using a single running example: the Acme `ORDERS` platform. The same server runs across the whole chapter, and its data carries over from one page to the next.

## Who this is for

You've read the [Core Concepts → JetStream](/concepts/jetstream.md) primer, or you're otherwise comfortable with NATS basics: publishing, subscribing, subjects, and queue groups.

## Map

| Page                                                                           | What you learn                                                            |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| [Your first stream](/learn/jetstream/your-first-stream.md)                     | Why a stream, then create the `ORDERS` stream and read its anatomy        |
| [Publishing](/learn/jetstream/publishing.md)                                   | Publish into a stream and understand the `PubAck` contract                |
| [Reading back the stream](/learn/jetstream/reading-back.md)                    | Read stored messages back with a durable consumer                         |
| [Filtering what you consume](/learn/jetstream/filtering.md)                    | Add a second consumer that reads only `orders.shipped`                    |
| [Delivery and acknowledgment](/learn/jetstream/delivery-and-acknowledgment.md) | In-flight, ack, double ack, and redelivery                                |
| [Ack responses and redelivery](/learn/jetstream/acknowledgment.md)             | ack, nak, term, in-progress, and redelivery timing                        |
| [Pull consumers in depth](/learn/jetstream/pull-consumers.md)                  | fetch vs consume, and the knobs that bound a pull                         |
| [Scaling a consumer](/learn/jetstream/worker-pool.md)                          | Many workers split the load of one consumer                               |
| [Ordered consumers](/learn/jetstream/ordered-consumer.md)                      | A throwaway in-order read of a stream, and the config behind it           |
| [Priority groups](/learn/jetstream/priority-groups.md)                         | Steer which client gets served: overflow, pinned\_client, and prioritized |
| [Pausing a consumer](/learn/jetstream/pausing.md)                              | Stop delivery for a window, then resume                                   |
| [Shaping the stream](/learn/jetstream/shaping-the-stream.md)                   | Tune retention limits and discard behavior                                |
| [Retention policies](/learn/jetstream/retention-policies.md)                   | Limits, Interest, and WorkQueue retention                                 |
| [Altering stream state](/learn/jetstream/altering-stream-state.md)             | Delete a message or purge the stream, by hand                             |
| [Surviving node loss](/learn/jetstream/surviving-node-loss.md)                 | Replicas, leaders, and storage durability                                 |
| [Advanced publishing](/learn/jetstream/advanced-publishing.md)                 | Async, atomic-batch, and fast-ingest publishing                           |
| [Mirrors and sources](/learn/jetstream/mirrors-and-sources.md)                 | Copy one stream, or aggregate many                                        |
| [Reading messages directly](/learn/jetstream/get-direct.md)                    | Get one message or a batch straight from the stream, no consumer          |
| [Subject mapping and transforms](/learn/jetstream/subject-mapping.md)          | Rewrite subjects on the way into a stream, and republish stored messages  |
| [Per-message TTL](/learn/jetstream/message-ttl.md)                             | Expire individual messages ahead of the stream                            |
| [Stream and consumer policies](/learn/jetstream/policies.md)                   | Every stream and consumer policy, and which are fixed at creation         |
| [Where to go next](/learn/jetstream/where-next.md)                             | A map of what's beyond this chapter                                       |

## Prerequisites

You'll need:

* A running `nats-server` with JetStream turned on. The simplest way to get one is `nats-server -js` (see [Getting Started](/concepts/getting-started/.md)).
* The `nats` CLI installed and pointed at your server.
