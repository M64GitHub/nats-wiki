<!-- source: https://docs.nats.io/reference/config/accounts/jetstream.md · fetched 2026-08-31 · section: jetstream -->
# jetstream

Hot Reloadable

Applied by replacing the account's whole limits map, so it is all-or-nothing: on a standalone server the update is rejected if it would put max\_memory/max\_file below already-reserved stream bytes, and the reload still reports success (the error is only logged). Worse, the account walk returns on the first such error, so accounts later in iteration order get no limit update at all.

## Types

| Type      | Description                                                  | Choices                                    |
| --------- | ------------------------------------------------------------ | ------------------------------------------ |
| `boolean` | -                                                            | `true`, `false`                            |
| `string`  | Indicates the capability is enabled or disabled.             | `enabled`, `enable`, `disabled`, `disable` |
| `object`  | An object with a set of explicit properties that can be set. | -                                          |

## Properties

| Name                                                                                         | Description                                                                                                 | Type      | Default | Reloadable |
| -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`max_memory`](/reference/config/accounts/jetstream/max_memory.md)                           | The maximum storage allowed across all memory-based assets.                                                 | `integer` | -       | Yes\*      |
| [`max_file`](/reference/config/accounts/jetstream/max_file.md)                               | The maximum storage allowed across all file-based assets.                                                   | `integer` | -       | Yes\*      |
| [`max_streams`](/reference/config/accounts/jetstream/max_streams.md)                         | The maximum number of streams allowed.                                                                      | `integer` | -       | Yes\*      |
| [`max_consumers`](/reference/config/accounts/jetstream/max_consumers.md)                     | The maximum number of consumers allowed.                                                                    | `integer` | -       | Yes\*      |
| [`max_bytes_required`](/reference/config/accounts/jetstream/max_bytes_required.md)           | If true, requires all streams to have an explicit max bytes defined for both file and memory-based streams. | `boolean` | -       | Yes\*      |
| [`memory_max_stream_bytes`](/reference/config/accounts/jetstream/memory_max_stream_bytes.md) | Maximum bytes any given memory-based stream is allowed to be allocated.                                     | `integer` | -       | Yes\*      |
| [`disk_max_stream_bytes`](/reference/config/accounts/jetstream/disk_max_stream_bytes.md)     | Maximum bytes any given file-based stream is allowed to be allocated.                                       | `integer` | -       | Yes\*      |
| [`max_ack_pending`](/reference/config/accounts/jetstream/max_ack_pending.md)                 | The maximum ack pending count allowed to be set on any given consumer.                                      | `integer` | -       | Yes\*      |

\* See the property page for reload caveats.
