<!-- source: https://docs.nats.io/reference/jetstream/advisory.md · fetched 2026-08-31 · section: advisory -->
# JetStream Advisories

Advisories are system events published by JetStream servers to notify about important state changes and operational events. These events are published to specific subjects that can be subscribed to for monitoring and observability.

## Advisory Events

| Name                                                                                | Subject                                                                                                                                          | Description                             |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- |
| [API Audit](/reference/jetstream/advisory/api-audit.md)                             | `$JS.EVENT.ADVISORY.API`                                                                                                                         | Audit trail of JetStream API operations |
| [API Limit Reached](/reference/jetstream/advisory/api-limit-reached.md)             | `$JS.EVENT.ADVISORY.API.LIMIT_REACHED.{account}`                                                                                                 | API rate limit reached                  |
| [Consumer Action](/reference/jetstream/advisory/consumer-action.md)                 | `$JS.EVENT.ADVISORY.CONSUMER.CREATED.{stream}.{consumer}`<br />`$JS.EVENT.ADVISORY.CONSUMER.DELETED.{stream}.{consumer}`                         | Consumer lifecycle events               |
| [Consumer Group Pinned](/reference/jetstream/advisory/consumer-group-pinned.md)     | `$JS.EVENT.ADVISORY.CONSUMER.GROUP_PINNED.{stream}.{consumer}`                                                                                   | Consumer group pinned to node           |
| [Consumer Group Unpinned](/reference/jetstream/advisory/consumer-group-unpinned.md) | `$JS.EVENT.ADVISORY.CONSUMER.GROUP_UNPINNED.{stream}.{consumer}`                                                                                 | Consumer group unpinned from node       |
| [Consumer Leader Elected](/reference/jetstream/advisory/consumer-leader-elected.md) | `$JS.EVENT.ADVISORY.CONSUMER.LEADER_ELECTED.{stream}.{consumer}`                                                                                 | New consumer leader elected             |
| [Consumer Pause](/reference/jetstream/advisory/consumer-pause.md)                   | `$JS.EVENT.ADVISORY.CONSUMER.PAUSE.{stream}.{consumer}`                                                                                          | Consumer paused or resumed              |
| [Consumer Quorum Lost](/reference/jetstream/advisory/consumer-quorum-lost.md)       | `$JS.EVENT.ADVISORY.CONSUMER.QUORUM_LOST.{stream}.{consumer}`                                                                                    | Consumer lost quorum                    |
| [Domain Leader Elected](/reference/jetstream/advisory/domain-leader-elected.md)     | `$JS.EVENT.ADVISORY.DOMAIN.LEADER_ELECTED.{domain}`                                                                                              | New domain leader elected               |
| [Max Deliveries Exceeded](/reference/jetstream/advisory/max-deliver.md)             | `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.{stream}.{consumer}`                                                                                 | Message exceeded max delivery attempts  |
| [Message NAK](/reference/jetstream/advisory/nak.md)                                 | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAK.{stream}.{consumer}`                                                                                        | Message negatively acknowledged         |
| [Message Terminated](/reference/jetstream/advisory/terminated.md)                   | `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.{stream}.{consumer}`                                                                                 | Message terminated                      |
| [Restore Complete](/reference/jetstream/advisory/restore-complete.md)               | `$JS.EVENT.ADVISORY.STREAM.RESTORE_COMPLETE.{stream}`                                                                                            | Stream restore completed                |
| [Restore Started](/reference/jetstream/advisory/restore-create.md)                  | `$JS.EVENT.ADVISORY.STREAM.RESTORE_CREATE.{stream}`                                                                                              | Stream restore initiated                |
| [Server Out of Space](/reference/jetstream/advisory/server-out-of-space.md)         | `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE`                                                                                                       | Server storage exhausted                |
| [Server Removed](/reference/jetstream/advisory/server-removed.md)                   | `$JS.EVENT.ADVISORY.SERVER.REMOVED`                                                                                                              | Server removed from cluster             |
| [Snapshot Complete](/reference/jetstream/advisory/snapshot-complete.md)             | `$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_COMPLETE.{stream}`                                                                                           | Stream snapshot completed               |
| [Snapshot Started](/reference/jetstream/advisory/snapshot-create.md)                | `$JS.EVENT.ADVISORY.STREAM.SNAPSHOT_CREATE.{stream}`                                                                                             | Stream snapshot initiated               |
| [Stream Action](/reference/jetstream/advisory/stream-action.md)                     | `$JS.EVENT.ADVISORY.STREAM.CREATED.{stream}`<br />`$JS.EVENT.ADVISORY.STREAM.DELETED.{stream}`<br />`$JS.EVENT.ADVISORY.STREAM.UPDATED.{stream}` | Stream lifecycle events                 |
| [Stream Leader Elected](/reference/jetstream/advisory/stream-leader-elected.md)     | `$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.{stream}`                                                                                              | New stream leader elected               |
| [Stream Quorum Lost](/reference/jetstream/advisory/stream-quorum-lost.md)           | `$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST.{stream}`                                                                                                 | Stream lost quorum                      |

## Subscribing to Advisories

To receive advisory events, subscribe to the appropriate subject pattern. You can use wildcards to subscribe to multiple advisory types:

* `$JS.EVENT.ADVISORY.>` - All advisory events
* `$JS.EVENT.ADVISORY.STREAM.>` - All stream-related advisories
* `$JS.EVENT.ADVISORY.CONSUMER.>` - All consumer-related advisories
