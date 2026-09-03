---
title: "docs.nats.io — JetStream API reference: the index tables and the 25 operation pages"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/reference/jetstream/api.md
source-path: raw/nats-docs/reference/jetstream/api.md
author: NATS documentation (Synadia Communications, Inc.) — generated from the jsm.go JSON schemas
article: "reference/jetstream.md, reference/jetstream/api.md, api/{stream,consumer,account,meta}.md and every operation page under api/ except stream/create, consumer/create and headers (which have their own summaries)"
date: 2026-08-31          # the pages are undated; this is the fetch date
version: "2.14"
tags: [js-api, subjects, generated, stream-info, msg-get, purge, snapshot, get-next]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# docs.nats.io — JetStream API reference: the index tables and the operation pages

The whole `reference/jetstream/api/` tree read in one sitting for phase E step 1; the three pages
with substance of their own keep their summaries ([[s-docs-stream-config]],
[[s-docs-consumer-config]], [[s-docs-jetstream-headers]]). One summary for the rest: four index
tables and twenty-five request/response listings.

## Key claims

**The index tables** (`api/stream.md`, `consumer.md`, `account.md`, `meta.md`) give 27 subjects with
a *System Account* column: every stream, consumer and account operation `No`; the two meta operations
`$JS.API.META.LEADER.STEPDOWN` and `$JS.API.META.SERVER.REMOVE` `Yes`. `api.md` says only that the
API is request/response over NATS subjects and that access is "controlled through standard NATS
authentication and authorization". The tree does not list `$JS.API.DIRECT.GET`,
`$JS.API.CONSUMER.RESET`, `$JS.API.ACCOUNT.STREAM.MOVE` or the legacy `CONSUMER.DURABLE.CREATE`
([[js-api-subjects]] carries them from other sources).

**Stream operations.** `info`: request `deleted_details`, **`subjects_filter`** ("a list of
subjects and how many messages they hold for all matching subjects. Filter is a standard NATS
subject wildcard pattern"), `offset`; response `config`, `state`, `created`, `ts`, `cluster`,
`mirror`, `sources`, `alternates`, `domain`, and the paging `total` / `offset` / `limit`. `list`:
`subject`, `offset`; response `streams[]`, **`missing[]`** ("In clustered environments gathering
Stream info might time out, this list would be a list of Streams for which information was not
obtainable"), **`offline`** ("List of streams that are offline and reasons"). `names`: `subject`,
`offset`; **the response array is documented as `consumers string[]`** — the server writes
`streams` (`JSApiStreamNamesResponse`, `jetstream_api.go:464–468`). `msg-get`: `seq` (cannot be
combined with `last_by_subj`), `last_by_subj`, `next_by_subj` ("Combined with sequence gets the next
message for a subject with the given sequence or higher"), `batch`, `max_bytes` ("defaults to server
MAX_PENDING_SIZE"), `start_time`, `multi_last[]`, `up_to_seq`, `up_to_time`. `msg-delete`: `seq`,
`no_erase` ("Default will securely remove a message and rewrite the data with random data").
`purge`: `filter`, `seq` ("up to but not including … Can be combined with subject filter but not the
keep option"), `keep`; response `purged`. `snapshot`: `deliver_subject`, `no_consumers`,
`chunk_size` (min 1024), `window_size` (1024–33554432), `jsck` ("Check all message's checksums prior
to snapshot"). `restore`: request `config`, `state` (the page labels the request "A response from
…"); response `deliver_subject`. `leader-stepdown` and `remove-peer`: `placement` / `peer`, response
`success`. `pub-ack`: `stream`, `seq`, `duplicate`, `domain`, `batch`, `count`, **`val`** ("The
current value of the counter on counter enabled streams").

**Consumer operations.** `get-next` (`$JS.API.CONSUMER.MSG.NEXT`): `expires` (ns, 0 = no expiry),
`batch` (**"Maximum: 256"**), `max_bytes`, `no_wait` ("a response with a 404 status header"),
`idle_heartbeat`, `group`, **`min_pending`**, **`min_ack_pending`** ("the minimum number of messages
the server should have in the consumer's ack pending queue before serving this pull"), `id` (the
pinned client id), `priority` (0–9). `pause`: `pause_until` ("when empty or a time in the past will
unpause"); response `paused`, `pause_until`, `pause_remaining`. `unpin`: `group`. `info`, `list`,
`names` (`subject` filter), `delete`, `leader-stepdown`: as the stream twins.

**Account operations.** `$JS.API.INFO`: `memory`, `storage`, `streams`, `consumers`, `domain`,
`limits`, `tiers`, `api`. `$JS.API.ACCOUNT.PURGE`: response `initiated` — "If the purge operation
was successfully started". **Meta.** `META.SERVER.REMOVE`: `peer` (name) or `peer_id` ("If specified
this is used instead of the server name"); its request heading reads `$JS.API.SERVER.REMOVE`.

## Practical takeaways

- Row 146's first half is `subjects_filter` on `STREAM.INFO`: `nats stream info ORDERS --subjects`
  or the raw request with `{"subjects_filter":">"}`, paged with `offset`.
- `msg-get`'s `multi_last` and `up_to_*` are the batched direct-get shapes of [[direct-get]];
  `snapshot`'s bounds are the ones [[backup-and-restore-jetstream]] cites.

## Notable quotes

- "In clustered environments gathering Stream info might time out" — `stream/list.md`, `missing`.

## Relevance to the wiki

Completes the docs coverage of `reference/jetstream/api/` (33 of 33 read); docs issue #69
(`names.md`'s `consumers`); the `batch` ceiling and `restore.md`'s label are checked in step 2 of
the plan. Feeds [[js-api-subjects]] (the `subjects_filter`, `missing`, `offline` and `val` fields)
and [[system-subjects]] (the *System Account* column against the server's meta subjects).

## Questions it answers

Row 146 in part (`subjects_filter`).

## Pages touched

[[js-api-subjects]] · [[system-subjects]]
