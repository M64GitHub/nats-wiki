---
title: "nats-server v2.14.6 — stream and consumer updates, observed"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/config-mutability-observed-v2.14.6.md
author: this wiki (runs on the v2.14.6 binary with nats CLI 0.4.0, 2026-09-03; scripts config-mutability-run.sh, -run2.sh, -run3.sh beside the file)
article: "every fixed, one-way and free field of a stream and a pull consumer tried by raw API update; what sealing forces; subjects_filter; an ephemeral's defaults; a pull of batch 300"
date: 2026-09-03
version: "2.14.6"
tags: [stream-config, consumer-config, mutability, observed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — stream and consumer updates, observed

Three passes of raw `$JS.API.STREAM.UPDATE` and `CONSUMER.CREATE … "action":"update"` requests on the
lab cluster. The source half is [[s-nats-server-stream-consumer-config]].

## Key claims

1. **Stream fields refused on update**, with the server's words: `name` (10056), `storage`
   (`can not change storage type`), `retention` to/from `workqueue`, `persist_mode`, `allow_msg_ttl`
   off (`message TTL status can not be disabled`), `allow_msg_counter` on (`can not change message
   counter setting`), `allow_msg_schedules` off, `deny_delete` off, `deny_purge` off, `sealed` off
   (`can not unseal a sealed stream`), a `mirror` added (10034 `stream mirrors can not contain
   subjects` with subjects, 10055 `stream mirror configuration can not be updated` without) — all
   10052 unless noted.
2. **Accepted**: `retention` limits ↔ interest, `discard`, `num_replicas` 1 → 3 → 1, `max_consumers`,
   `compression`, `subjects`, `deny_delete` on, `deny_purge` on, `sealed` on,
   `discard_new_per_subject` once `discard: new` and `max_msgs_per_subject` are set, and
   `allow_msg_schedules` on — which **turned `allow_rollup_hdrs` on by itself**.
3. **Sealing changed four other fields**: `STREAM.INFO` afterwards showed `deny_delete: true`,
   `deny_purge: true`, `discard: new`, `max_age: 0`; a later update built from the pre-seal config
   was refused for "cancelling deny message deletes".
4. **Consumer fields refused on update** (10012 unless noted): `deliver_policy`, `ack_policy`,
   `replay_policy`, `opt_start_seq` (reported as the deliver-policy refusal), pull → push (`can not
   update pull consumer to push based`), `max_waiting`, `mem_storage` (`storage type can not be
   updated`), `durable_name` (10017); on a pull consumer `idle_heartbeat` (10088) and `flow_control`
   (10089); a `backoff` longer than `max_deliver` (10116).
5. **Accepted**: `description`, `ack_wait`, `max_deliver`, `max_ack_pending`, `filter_subject`, a
   switch to `filter_subjects`, `backoff` (with `ack_wait` silently becoming its first entry),
   `inactive_threshold`, `num_replicas`, `max_batch`, and priority groups on a pull consumer
   (contradicting ADR-42, docs issue #37).
6. **Defaults as stored**: a pull explicit consumer came back with `ack_wait 30s`, `max_deliver -1`,
   `max_ack_pending 1000`, `max_waiting 512`; an ephemeral with `ack_policy: none` with
   `inactive_threshold 5s`, `max_waiting 512` and **no `ack_wait` or `max_ack_pending`**.
7. **`subjects_filter`**: `{"subjects_filter":">"}` on `STREAM.INFO` returned
   `state.subjects: {cfg.a: 2, cfg.b: 1}` with paging `total 2, offset 0, limit 100000`.
8. **A pull of `batch: 300` was served in full** (three messages, then `404 No Messages`), and
   `batch: 100000` accepted; the only refusal is the consumer's own `max_batch` — `409 Exceeded
   MaxRequestBatch of 5`. The docs' "Maximum: 256" on `get-next.md` is not a server limit.
9. A harness lesson, recorded: pass 1 copied a config carrying `allow_rollup_hdrs: true` forward, so
   six later cases were refused for `roll-ups require the purge permission` and had to be re-run.

## Practical takeaways

- `nats stream edit` on a sealed stream must carry `deny_delete`, `deny_purge`, `discard: new` and
  `max_age: 0`, or the request is refused for a field you did not mean to touch.
- Turning schedules on turns roll-ups on; plan the purge permission accordingly.

## Notable quotes

- `Status: 409 · Description: Exceeded MaxRequestBatch of 5` — the pull ceiling that exists.

## Relevance to the wiki

The observed column of [[stream-and-consumer-config]]; docs issue #73 (the 256); row 146.

## Questions it answers

Rows 146, 164; 151 in part.

## Pages touched

[[stream-and-consumer-config]] · [[stream]] · [[consumer]] · [[js-api-subjects]]
