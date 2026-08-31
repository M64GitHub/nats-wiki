<!-- source: https://docs.nats.io/reference/config/jetstream/max_memory_store.md · fetched 2026-08-31 · section: max_memory_store -->
# max\_memory\_store

Aliases:

<!-- -->

`max_mem_store`, `max_mem`

Hot Reloadable

2.12/2.14: increases only, and only while JetStream stays enabled. 2.11: never, while enabled.

Maximum size of the *memory* storage. Defaults to 75% of available memory.

## Types

| Type      | Description                                                              | Choices |
| --------- | ------------------------------------------------------------------------ | ------- |
| `storage` | Size in bytes or string with a metric unit such as 100K, 50M, 3G, or 1T. | -       |
