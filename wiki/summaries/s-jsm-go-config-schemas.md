---
title: "jsm.go v0.4.1 — the stream and consumer configuration JSON schemas"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/jsm.go/tree/v0.4.1/schemas/jetstream/api/v1
source-path: raw/jsm-go/consumer_configuration-v0.4.1.json
author: nats-io/jsm.go maintainers
article: "schemas/jetstream/api/v1/stream_configuration.json and consumer_configuration.json at tag v0.4.1"
date: 2026-05-01          # v0.4.1 publish date
version: "2.14"           # the API level the schemas describe at that tag
tags: [json-schema, stream-config, consumer-config, jsm.go]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# jsm.go v0.4.1 — the stream and consumer configuration JSON schemas

The schemas the docs' generated reference is rendered from ([[jsm-go]] is their home). Read for
[[stream-and-consumer-config]] because the docs render the stream one and **collapse the consumer
one** (docs issue #4), so the consumer field descriptions and schema defaults are readable only here.
Both files are in `raw/jsm-go/`.

## Key claims

- **`stream_configuration.json`: 38 properties — exactly the 38 JSON fields of the server's
  `StreamConfig` at v2.14.6**, none missing on either side. Defaults match the server's
  `checkStreamCfg`: `retention: limits`, `max_consumers`, `max_msgs`, `max_msgs_per_subject`,
  `max_bytes`, `max_msg_size` -1, `max_age` 0, `storage: file`, `compression: none`,
  `num_replicas` 1, `discard: old`, `duplicate_window` 0 ("0 for default" — the server then uses 2 m),
  every `allow_*` / `deny_*` / `sealed` false, `persist_mode` "".
- **`consumer_configuration.json`: 34 properties; the server struct has 35 — `sourcing` is internal
  and unschematised.** Descriptions and defaults: `deliver_policy: all`; **`ack_policy: none`**
  (the API default; the CLI's is `explicit`); `ack_wait` "30000000000" (a string in the schema);
  `max_deliver` -1; `replay_policy: instant`; `max_ack_pending` 1000; `max_waiting` 512 ("The number
  of pulls that can be outstanding on a pull consumer, pulls received after this is reached are
  ignored"); `max_batch`, `max_expires`, `max_bytes`, `inactive_threshold`, `priority_timeout` 0;
  `direct` false ("Creates a special consumer that does not touch the Raft layers, not for general
  use by clients, internal use only"); `mem_storage` false; `headers_only` false. `sample_freq` is "the
  percentage of acknowledgments that should be sampled for observability"; `rate_limit_bps` "the rate
  at which messages will be delivered to clients, expressed in bit per second"; `num_replicas` "When
  set do not inherit the replica count from the stream but specifically set it to this amount";
  `inactive_threshold` "Duration that instructs the server to cleanup ephemeral consumers that are
  inactive for that long" (default 0 — the server applies 5 s); `pause_until` "When creating a
  consumer supplying a time in the future will act as a deadline …".
- One description is wrong: **`opt_start_time` — "Start time used with the DeliverByStartSequence
  deliver policy"**; it is used with `DeliverByStartTime` (`consumer.go:306`, and the validation at
  `:935–945`). `opt_start_seq`'s line is correct.

## Practical takeaways

- Treat the schema as the field list and the server source as the defaults: the two agree except
  where the schema says 0 and the server substitutes (duplicate window, inactive threshold).

## Notable quotes

- "pulls received after this is reached are ignored" — `max_waiting`.

## Relevance to the wiki

The description column of [[stream-and-consumer-config]]; docs issue #74 (`opt_start_time`), with
`destination` jsm.go since the docs never render the field.

## Questions it answers

Row 164 in part; row 160 (the field list).

## Pages touched

[[stream-and-consumer-config]] · [[jsm-go]]
