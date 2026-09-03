---
title: "nats CLI 0.4.0 — stream add/edit and consumer add/edit help"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/natscli
source-path: raw/nats-cli/help-0.4.0.md
author: nats-io/natscli maintainers (captured output of the 0.4.0 binary)
article: "nats stream add --help, nats stream edit --help, nats consumer add --help, nats consumer edit --help"
date: 2026-09-03
version: "0.4.0"
tags: [nats-cli, flags, stream-config, consumer-config]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats CLI 0.4.0 — `stream add` / `edit` and `consumer add` / `edit` help

Captured verbatim for the CLI column of [[stream-and-consumer-config]]: which flag sets which API
field, and what the CLI's own defaults are where they differ from the server's.

## Key claims

- **`stream add`, 47 stream flags**: `--subjects`, `--description`, `--storage`, `--compression`,
  `--replicas`, `--tag` / `--cluster` (placement), `--[no-]ack`, `--retention`, `--discard`,
  `--[no-]discard-per-subject`, `--first-sequence`, `--max-age`, `--max-bytes`, `--max-consumers`
  (default -1), `--max-msg-size`, `--max-msgs` (default 0), `--max-msgs-per-subject` (0),
  `--dupe-window`, `--mirror`, `--source` (repeatable), `--[no-]allow-batch` (atomic),
  `--[no-]allow-fast` (fast batch), `--allow-counter`, `--[no-]allow-rollup`, `--[no-]deny-delete`,
  `--[no-]deny-purge`, `--[no-]allow-direct`, `--[no-]allow-mirror-direct`, `--allow-msg-ttl`,
  `--[no-]allow-schedules`, `--subject-del-markers-ttl`, `--transform-source` / `--transform-destination`,
  `--metadata` (repeatable), `--republish-source` / `--republish-destination` / `--republish-headers`,
  `--limit-consumer-inactive` / `--limit-consumer-max-pending` (`consumer_limits`), `--persist-mode`,
  plus `--config` (a JSON file), `--validate`, `--output`, `--defaults`. **`stream edit`** adds
  `--dry-run`, `--no-mirror`, `--no-republish`, `--no-transform` and drops `--first-sequence`.
- **`consumer add`, 38 consumer flags**: `--ack` (none, all, explicit), `--bps`, `--backoff` /
  `--backoff-steps` (10) / `--backoff-min` (1m) / `--backoff-max` (20m), `--deliver` (all, new, last,
  subject, a duration, or a sequence), `--deliver-group`, `--description`, `--ephemeral`, `--filter`
  (repeatable → `filter_subjects`), `--flow-control`, `--heartbeat`, `--[no-]headers-only`,
  `--max-deliver`, `--max-pending` (default -1), `--max-waiting`, `--max-pull-batch` / `--max-pull-expire`
  / `--max-pull-bytes`, `--pull`, `--replay`, `--sample`, `--target` (push `deliver_subject`), `--wait`
  (default -1s), `--inactive-threshold`, `--memory`, `--replicas`, `--metadata`, `--pause`,
  `--pinned-groups` / `--pinned-ttl` / `--overflow-groups` / `--prioritized-groups`. **`consumer
  edit`** offers a subset (43 flags in all against 61): the updatable fields — description, ack wait,
  max deliver, backoff, filter, max pending, the pull limits, inactive threshold, replicas, sample,
  target, metadata — and none of the fixed ones.
- The CLI's `--max-pending=-1` and `--wait=-1s` mean "let the server decide" (1000 and 30 s for an
  explicit consumer); `--max-consumers=-1` is the server's own default.

## Practical takeaways

- Anything `consumer edit` has no flag for is a field the server refuses to update; the CLI mirrors
  `checkNewConsumerConfig`.
- `--config file.json` on either command sends the raw configuration and is the way to set a field
  the CLI has no flag for.

## Relevance to the wiki

The CLI column of [[stream-and-consumer-config]]; the [[nats-cli]] entity gains the capture.

## Questions it answers

Row 164 in part.

## Pages touched

[[stream-and-consumer-config]] · [[nats-cli]]
