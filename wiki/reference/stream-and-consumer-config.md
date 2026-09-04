---
title: Stream and consumer configuration
type: reference
area: [jetstream]
since: [2.10]   # the tables carry the minor each field arrived in; 2.10 means present at the floor
verified-against: nats-server 2.14.6
verified-on: 2026-09-04
tags: [stream-config, consumer-config, StreamConfig, ConsumerConfig, defaults, mutability, cli-flags]
aliases: [StreamConfig, ConsumerConfig, stream config, consumer config, stream configuration, consumer configuration, stream fields, consumer fields]
sources: [s-nats-server-stream-consumer-config, s-nats-server-config-mutability-observed, s-jsm-go-config-schemas, s-nats-cli-help-0.4.0, s-docs-stream-config, s-docs-consumer-config, s-gh-3944-subjects-in-a-stream, s-adr-33-metadata, s-adr-34-multiple-filters, s-adr-9-idle-heartbeats, s-adr-42-priority-groups, s-adr-43-per-message-ttl, s-adr-51-message-scheduler, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-nats-server-core-or-jetstream-observed, s-synadia-subject-hierarchies, s-synadia-expected-sequence-headers]
created: 2026-09-03
updated: 2026-09-04
---

# Stream and consumer configuration

Every field of `StreamConfig` (38) and `ConsumerConfig` (35) as `nats-server` v2.14.6 defines them:
type, the default the **server** applies when the field is left out, the minor it arrived in, whether
it can change after creation, the `nats` CLI 0.4.0 flag, and the validation rule that bites. It does
not explain the fields — the concept pages do ([[stream]], [[consumer]], [[retention-policies]],
[[replicas]] …) — and it does not cover the server's own `jetstream {}` block ([[config-keys]]) or
its defaults ([[defaults-and-limits]]). Read from the source and run on the binary; the docs render
the stream schema and collapse the consumer one (docs issue #4).

**How to read *after creation*.** *free* — an update may change it. **fixed** — refused, with the
server's words. *one-way* — may be turned on, never off. *conditional* — allowed under a rule given
in the row. Every refusal string below was produced on 2.14.6 (source:
[[s-nats-server-config-mutability-observed]]); every "not tested" is a field `configUpdateCheck`
or `checkNewConsumerConfig` does not mention and the run did not exercise.

## Stream fields

Defaults from `checkStreamCfg` (`stream.go:1660–1760`); arrivals from the release-note summaries;
the update rules from `configUpdateCheck` (`stream.go:2300–2437`) (source:
[[s-nats-server-stream-consumer-config]]; schema defaults, which agree, [[s-jsm-go-config-schemas]]).

| field | type | server default | since | after creation | `nats stream add` | rule that bites |
|---|---|---|---|---|---|---|
| `name` | string | required | 2.10 | **fixed** — `stream name in subject does not match request` (10056) | positional | no `.`, `*`, `>`, `\`, `/`; ≤ 255 chars |
| `description` | string | — | 2.10 | free | `--description` | ≤ 4096 chars |
| `subjects` | string[] | — | 2.10 | free (a mirror may have none: `stream mirrors can not contain subjects`, 10034) | `--subjects` | no duplicates or overlaps; `>` or an overlap with `$JS.API` / `$SYS` needs `no_ack`, and `>` needs R1 |
| `subject_transform` | `{src, dest}` | — | 2.10.0 | free (not tested) | `--transform-source`, `--transform-destination`; edit: `--no-transform` | a cycle with `republish` is refused ([[subject-transforms]]) |
| `retention` | `limits` \| `interest` \| `workqueue` | `limits` | 2.10 | *conditional* — `limits` ↔ `interest` free; **to or from `workqueue`** refused: `can not change retention policy to/from workqueue` | `--retention` | a counter stream must be `limits` |
| `max_consumers` | int | -1 | 2.10 | free **since 2.12.5** (#7724); fixed before | `--max-consumers` | |
| `max_msgs` | int64 | -1 | 2.10 | free | `--max-msgs` | 0 or < -1 → -1 (pedantic: error) |
| `max_bytes` | int64 | -1 | 2.10 | free — the difference is checked against the account reservation | `--max-bytes` | |
| `max_age` | duration (ns on the wire) | 0 = unlimited | 2.10 | free | `--max-age` | **0 or ≥ 100 ms**: `max age needs to be >= 100ms`; sealing forces 0 |
| `max_msgs_per_subject` | int64 | -1 | 2.10 | free | `--max-msgs-per-subject` | |
| `max_msg_size` | int32 | -1 | 2.10 | free | `--max-msg-size` | |
| `discard` | `old` \| `new` | `old` | 2.10 | free | `--discard` | sealing forces `new`; a counter or scheduling stream cannot be `new` |
| `storage` | `file` \| `memory` | `file` | 2.10 | **fixed** — `can not change storage type` | `--storage` | `persist_mode: async` needs `file` |
| `num_replicas` | int | 1 | 2.10 | free — R>1 on a standalone server refused (10074) | `--replicas` | 1–5 (`StreamMaxReplicas`); a `>` subject needs 1 |
| `no_ack` | bool | false | 2.10 | free (not tested) | `--no-ack` | required for `>` and API-overlapping subjects |
| `duplicate_window` | duration | **2 m** when 0 — unless the stream is a mirror or has sources | 2.10 | free | `--dupe-window` | ≥ 100 ms; ≤ `max_age`: `duplicates window can not be larger then max age`; ≤ the server's `max_duplicate_window` |
| `placement` | `{cluster, tags, preferred}` | none (random) | 2.10 (`preferred` on stepdown 2.11.0) | free (not tested) | `--cluster`, `--tag` | `preferred` refused in a config: `preferred server not permitted in placement` |
| `mirror` | `StreamSource` | — | 2.10 | **fixed** — `stream mirror configuration can not be updated` (10055); **removable since 2.12.0** (promotion, #7171) | `--mirror`; edit: `--no-mirror` | `subjects` and `sources` must be empty |
| `sources` | `StreamSource[]` | — | 2.10 | free — add, drop, re-filter ([[mirrors-and-sources]]; not tested here) | `--source` | |
| `compression` | `none` \| `s2` | `none` | 2.10.0 | free — takes effect only when the store is re-created ([[stream-compression]]) | `--compression` | file storage only |
| `first_seq` | uint64 | 0 | 2.10.0 | creation only (edit has no flag; not tested) | `--first-sequence` | |
| `sealed` | bool | false | 2.10 | *one-way* — `can not unseal a sealed stream`; **sealing also sets `deny_delete`, `deny_purge`, `discard: new`, `max_age: 0`** and drops roll-ups | *(no flag; `--config`)* | roll-ups and sealing are exclusive |
| `deny_delete` | bool | false | 2.10 | *one-way* — `can not cancel deny message deletes` | `--deny-delete` | |
| `deny_purge` | bool | false | 2.10 | *one-way* — `can not cancel deny purge` | `--deny-purge` | roll-ups need purge: `roll-ups require the purge permission` |
| `allow_rollup_hdrs` | bool | false | 2.10 | free | `--allow-rollup` | needs purge; **turned on by the server when `allow_msg_schedules` is set** |
| `allow_direct` | bool | false | 2.10 | free | `--allow-direct` | [[direct-get]] |
| `mirror_direct` | bool | false | 2.10 | free | `--allow-mirror-direct` | needs a `mirror` at creation |
| `republish` | `{src, dest, headers_only}` | — | 2.10 | free (not tested) | `--republish-source`, `--republish-destination`, `--republish-headers`; edit: `--no-republish` | a destination that forms a cycle is refused |
| `discard_new_per_subject` | bool | false | 2.10 | *conditional* — needs `discard: new` and `max_msgs_per_subject > 0`, each refused by name | `--discard-per-subject` | |
| `metadata` | map | — | 2.10.0 | free | `--metadata` | ≤ 128 KB; `_nats` reserved ([[s-adr-33-metadata]]) |
| `consumer_limits` | `{inactive_threshold, max_ack_pending}` | — | 2.10 | free — every consumer is re-checked against the new limits | `--limit-consumer-inactive`, `--limit-consumer-max-pending` | |
| `allow_msg_ttl` | bool | false | 2.11.0 | *one-way* — `message TTL status can not be disabled` | `--allow-msg-ttl` | needs stream API level 1 ([[message-ttl]]) |
| `subject_delete_marker_ttl` | duration | 0 = off | 2.11.0 | free | `--subject-del-markers-ttl` | ≥ 1 s; needs `allow_msg_ttl` and roll-ups; **never on a mirror** |
| `allow_atomic` | bool | false | 2.12.0 | free (not tested) | `--allow-batch` | not with `persist_mode: async` ([[publishing]]) |
| `allow_msg_counter` | bool | false | 2.12.0 | **fixed** — `can not change message counter setting` | `--allow-counter` | not with `discard: new`, TTLs, schedules, or any retention but `limits` |
| `allow_msg_schedules` | bool | false | 2.12.0 (cron 2.14.0) | *one-way* — `message schedules can not be disabled` | `--allow-schedules` | needs roll-ups (set for you), not `discard: new` ([[message-scheduling]]) |
| `persist_mode` | `""` \| `default` \| `async` | `""` | 2.12.0 | **fixed** — `can not change persist mode` | `--persist-mode` | `async` needs file storage, R1, no atomic batches |
| `allow_batched` | bool | false | 2.14.0 | free (not tested) | `--allow-fast` | fast-ingest batches ([[publishing]]) |

`StreamSource` (the shape of `mirror` and each of `sources`): `name`, `opt_start_seq`, `opt_start_time`,
`filter_subject`, `subject_transforms[] {src, dest}`, `external {api, deliver}`, `consumer {name,
deliver_subject}` (`stream.go:406–417`); `external.api` must not contain wildcards (10024). A
sealed stream's state, as the server rewrote it on 2.14.6: `sealed: true, deny_delete: true,
deny_purge: true, discard: new, max_age: 0`.

## Consumer fields

Defaults from `setConsumerConfigDefaults` (`consumer.go:587–704`), validation from
`checkConsumerCfg` (`:705–1000`), the update rules from `checkNewConsumerConfig` (`:2481–2549`) and
`updateConfig` (`:2551–2705`) (source: [[s-nats-server-stream-consumer-config]]; descriptions,
[[s-jsm-go-config-schemas]]). The pull/push split matters: a consumer is push when
`deliver_subject` is set.

| field | type | server default | since | after creation | `nats consumer add` | rule that bites |
|---|---|---|---|---|---|---|
| `durable_name` | string | — (ephemeral) | 2.10 | **fixed** — `consumer name in subject does not match durable name in request` (10017) | positional | no `.`, `*`, `>`, `\`, `/`; must equal `name` if both set |
| `name` | string | generated | 2.10 | **fixed** | positional / `--ephemeral` | as above |
| `description` | string | — | 2.10 | free | `--description` | ≤ 4096 (10107) |
| `deliver_policy` | `all` \| `last` \| `new` \| `by_start_sequence` \| `by_start_time` \| `last_per_subject` | `all` | 2.10 | **fixed** — `deliver policy can not be updated` (10012) | `--deliver` | the start fields must match the policy (10094); `last_per_subject` needs a filter |
| `opt_start_seq` | uint64 | — | 2.10 | **fixed** — `start sequence can not be updated` | `--deliver=<seq>` | only with `by_start_sequence` |
| `opt_start_time` | RFC3339 | — | 2.10 | **fixed** — `start time can not be updated` | `--deliver=<duration or time>` | only with `by_start_time` (the schema's description names the wrong policy, #74) |
| `ack_policy` | `none` \| `all` \| `explicit` \| `flow_control` | **`none`** (the CLI's `--ack` default is `explicit`) | 2.10 (`flow_control` 2.14.0) | **fixed** — `ack policy can not be updated` | `--ack` | pull on a workqueue stream needs `explicit` (10084); `max_ack_pending` needs an ack policy (10082) |
| `ack_wait` | duration | **30 s** for `explicit` and `all`; none for `none` | 2.10 | free | `--wait` | positive (10183); **a `backoff` overwrites it with its first entry** ([[consumer-keeps-redelivering]]) |
| `max_deliver` | int | -1 | 2.10 | free | `--max-deliver` | must exceed `len(backoff)`: `max deliver is required to be > length of backoff values` (10116) |
| `backoff` | duration[] | — | 2.10 | free (the same `max_deliver` rule) | `--backoff`, `--backoff-steps`, `--backoff-min`, `--backoff-max` | entries positive (10184) |
| `filter_subject` | string | — | 2.10 | free — and may become `filter_subjects` | `--filter` | must fit the stream's subjects; empty entries refused |
| `filter_subjects` | string[] | — | 2.10.0 | free | `--filter` (repeated) | no duplicates, no overlaps (10136), not both forms (10134) ([[s-adr-34-multiple-filters]]) |
| `replay_policy` | `instant` \| `original` | `instant` | 2.10 | **fixed** — `replay policy can not be updated` | `--replay` | |
| `rate_limit_bps` | uint64 | 0 | 2.10 | free (not tested) | `--bps` | push only (10086) |
| `sample_freq` | string (`"50%"`) | — | 2.10 | free (not tested) | `--sample` | must parse (10095); the only switch for the ack metric ([[advisories]]) |
| `max_waiting` | int | **512** (pull) | 2.10 | **fixed** — `max waiting can not be updated` | `--max-waiting` | push consumers may not set it (10080) |
| `max_ack_pending` | int | stream `consumer_limits`, else **1000**, clamped by the server and account limits | 2.10 | free — shrinking it pauses delivery until acks catch up | `--max-pending` | ≤ every limit (10121); needs an ack policy |
| `flow_control` | bool | false | 2.10 | **fixed** — `flow control can not be updated` | `--flow-control` | push only (10089); needs `idle_heartbeat` |
| `headers_only` | bool | false | 2.10 | free (not tested) | `--headers-only` | |
| `max_batch` | int | the server's `max_request_batch`, else 0 = none | 2.10 | free | `--max-pull-batch` | a pull above it: `409 Exceeded MaxRequestBatch of N` — **there is no other ceiling** (docs issue #73) |
| `max_expires` | duration | 0 | 2.10 | free (not tested) | `--max-pull-expire` | |
| `max_bytes` | int | 0 | 2.10 | free (not tested) | `--max-pull-bytes` | |
| `deliver_subject` | string | — (pull) | 2.10 | *conditional* — a push consumer may move to another subject; **pull ↔ push refused**: `can not update pull consumer to push based` | `--target` | no wildcards (10079), no cycle (10081) |
| `deliver_group` | string | — | 2.10 | free (not tested) | `--deliver-group` | push only |
| `idle_heartbeat` | duration | 0 | 2.10 | **fixed** — `heart beats can not be updated` | `--heartbeat` | push only (10088); ≥ 100 ms (10083); the pull form is per request ([[s-adr-9-idle-heartbeats]]) |
| `inactive_threshold` | duration | stream `consumer_limits`, else **5 s for ephemerals** (+ up to 1 s jitter), none for durables | 2.10 | free | `--inactive-threshold` | ≤ the stream limit |
| `num_replicas` | int | the stream's | 2.10 | free | `--replicas` | ≤ the stream's; must equal it for memory or workqueue streams |
| `mem_storage` | bool | false | 2.10 | **fixed** — `storage type can not be updated` | `--memory` | |
| `direct` | bool | false | 2.10 | **fixed** (internal: "not for general use") | — | push and ephemeral only (10090, 10091) |
| `sourcing` | bool | false | 2.10 | **fixed** (internal, unschematised) | — | |
| `metadata` | map | — | 2.10.0 | free | `--metadata` | ≤ 128 KB (10135); `_nats.*` written by the server |
| `pause_until` | RFC3339 | — | 2.11.0 | free — by update or `$JS.API.CONSUMER.PAUSE` | `--pause` | a past time unpauses |
| `priority_groups` | string[] | — | 2.11.0 | the source allows it and 2.14.6 accepts it; ADR-42 says it must not change (docs issue #37) | `--pinned-groups`, `--overflow-groups`, `--prioritized-groups` | pull only (10178); names 1–16 chars of `A-Z a-z 0-9 -_/=` (10162) |
| `priority_policy` | `none` \| `overflow` \| `pinned_client` \| `prioritized` | `none` | 2.11.0 (`prioritized` 2.12.0) | as above | as above | groups and policy go together ([[priority-groups]]) |
| `priority_timeout` | duration | **2 m** for `pinned_client` | 2.11.0 | as above | `--pinned-ttl` | needs a policy |

## The limits that clamp a consumer

| where | keys | effect |
|---|---|---|
| server `jetstream { limits { … } }` | `max_request_batch`, `max_ack_pending`, `max_ha_assets`, `max_duplicate_window`, `max_batch_inflight_per_stream`, `max_batch_inflight_total`, `max_batch_size`, `max_batch_timeout` | defaults and ceilings for every account (`JSLimitOpts`, `opts.go:375–384`); batch defaults when unset: 10 s, 50 atomic batches per stream / 1000 total / 1000 messages, 1000 fast batches per stream / 50,000 total (`stream.go:446–455`) |
| account `jetstream { … }` | `max_ack_pending`, `max_memory`, `max_file` (`max_storage`), `max_streams`, `max_consumers`, `memory_max_stream_bytes`, `storage_max_stream_bytes`, `max_bytes_required` | per account (`JetStreamAccountLimits`, `jetstream.go:71–80`; [[config-keys]]) |
| stream `consumer_limits { … }` | `inactive_threshold`, `max_ack_pending` | defaults for consumers that set none, ceilings for those that do; re-checked on every stream update |

## What the docs do not render

`reference/jetstream/api/consumer/create.md` collapses the `config` object, so no consumer default is
readable in the docs (docs issue #4); the descriptions above come from the jsm.go schema and the
defaults from the server. `get-next.md` gives `batch` a "Maximum: 256" that the server does not
enforce (#73). The stream page is complete and its defaults agree with the server (source:
[[s-docs-stream-config]], [[s-docs-consumer-config]]).

## Which subjects a stream holds

`$JS.API.STREAM.INFO.<stream>` with `{"subjects_filter": "<wildcard>"}` returns `state.subjects`, a
map of every matching subject to its message count, paged with `offset` (100000 per page on
2.14.6); `nats stream info <s> --subjects` and `nats stream subjects <s>` wrap it. There is no
negative filter: "everything except X" is a `filter_subjects` list of the rest (gh#3944; source:
[[s-gh-3944-subjects-in-a-stream]], [[s-nats-server-config-mutability-observed]] §5).

### The page limit has a name, and a design consequence

The 100,000 above is `const JSMaxSubjectDetails = 100_000` (`server/jetstream_api.go:435`, used at
`:2040`, `:2043`, `:2058`). It is a **hard cap per request**, not a default you can raise — there is no
config key for it.

The consequence is a subject-design one: a stream whose subject space is unbounded (a correlation id
or request id in a token) makes every subject-level view of it — `nats stream subjects`,
`nats stream info --subjects`, anything built on `subjects_filter` — paginate through millions of
one-message entries, which is to say unusable (source: [[s-synadia-subject-hierarchies]]). Entity ids
are bounded and fine; per-message ids belong in a header ([[subjects-and-wildcards]]).

## The publish-expectation headers, and what is mutable about them

Not stream configuration at all — they are per-publish, which is why they are easy to miss when
reading `StreamConfig`. All five are in `server/stream.go:640–644` at v2.14.6:
`Nats-Expected-Stream`, `Nats-Expected-Last-Sequence`, `Nats-Expected-Last-Subject-Sequence`,
`Nats-Expected-Last-Subject-Sequence-Subject` (**2.11.0**, #5281) and `Nats-Expected-Last-Msg-Id`.
Nothing on the stream enables or disables them; any publisher may send them at any time, and a stream
that has never seen one behaves identically to one that has.

Two settings do interact with them:

- **`duplicate_window`** governs `Nats-Msg-Id`, which is a different mechanism — deduplication, not a
  precondition. A message rejected by an expectation is not stored and does not enter the duplicate
  window ([[publishing]]).
- **`allow_direct` / `mirror_direct`** decide how cheaply a publisher can *read* the sequence it is
  about to assert, which is the loop an optimistic-concurrency writer actually runs
  ([[direct-get]], source: [[s-synadia-expected-sequence-headers]]).

The rejection codes are on [[error-codes]] — *The publish-expectation family*.


## Which clock stamps a message

The **leader's**. `processJetStreamMsg` sets the timestamp with `time.Now().UnixNano()` on the
leader before the message is proposed to the Raft group, and the value travels in the proposal, so
every replica stores the same instant and a follower's clock never enters a message
(`stream.go:6929–6931`; atomic batches `:7486`; source: [[s-nats-server-stream-consumer-config]]).
Synchronised clocks matter for `opt_start_time`, `max_age` and TTLs when leadership moves — a new
leader with a skewed clock ages messages by its own time; see [[stream]].

## How this was derived

- **Fields, types, defaults, validation and update rules**: `server/stream.go`, `consumer.go`,
  `jetstream.go`, `jetstream_api.go`, `jetstream_cluster.go`, `opts.go` at tag v2.14.6, quoted with
  line numbers in `raw/nats-server-src/stream-consumer-config-v2.14.6.md` (source:
  [[s-nats-server-stream-consumer-config]]). To regenerate: re-read `StreamConfig`, `ConsumerConfig`,
  `checkStreamCfg`, `configUpdateCheck`, `setConsumerConfigDefaults`, `checkConsumerCfg`,
  `checkNewConsumerConfig` at the new tag.
- **The refusal strings and the accepted changes**: three passes of raw `$JS.API` updates on the
  v2.14.6 binary, `raw/nats-server-src/config-mutability-observed-v2.14.6.md` with its scripts
  (source: [[s-nats-server-config-mutability-observed]]).
- **Descriptions**: the jsm.go schemas at v0.4.1, `raw/jsm-go/` (source: [[s-jsm-go-config-schemas]]).
- **CLI flags**: `nats` 0.4.0 help, `raw/nats-cli/help-0.4.0.md` (source: [[s-nats-cli-help-0.4.0]]).
- **Arrivals**: the per-minor release-note summaries and the ADRs named in the rows.

## Version notes

- **2.10.0**: `subject_transform`, `compression`, `first_seq`, `metadata` (ADR-33),
  `filter_subjects` (ADR-34) (source: [[s-relnotes-2.10]]). **2.11.0**: `allow_msg_ttl` and
  `subject_delete_marker_ttl` (ADR-43), `priority_groups` / `priority_policy` / `priority_timeout`
  (ADR-42), `pause_until`, pedantic mode, `preferred` placement on stepdown (source:
  [[s-relnotes-2.11]]). **2.12.0**: `allow_atomic`, `allow_msg_counter`, `allow_msg_schedules`,
  `persist_mode`, mirror promotion, the `prioritized` policy; **2.12.5**: `max_consumers` updatable
  (source: [[s-relnotes-2.12]]). **2.14.0**: `allow_batched`, the `flow_control` ack policy, cron
  schedules (source: [[s-relnotes-2.14]]).

## The three rules behind `no_ack`

`no_ack` looks like a minor flag in the table above; it is the switch on three hard subject rules the
server enforces at create time (`server/stream.go:2170–2196` at 2.14.6, observed in
[[s-nats-server-core-or-jetstream-observed]]):

| subject | rejected with | unless |
|---|---|---|
| `>` | `capturing all subjects requires no-ack to be true` (`10052`) — and then `capturing all subjects requires replicas of 1` | `no_ack: true` **and** `replicas: 1` |
| overlaps `$JS.>`, `$JSC.>` or `$NRG.>` | `subjects that overlap with jetstream api require no-ack to be true` | `no_ack: true`; `$JS.EVENT.>` is exempt |
| overlaps `$SYS.>` | `subjects that overlap with system api require no-ack to be true` | `no_ack: true`; `$SYS.ACCOUNT.>` is exempt |

The reason is that an acking stream **replies** to everything it captures, so a stream over a
request/reply subject answers those requests with its own `PubAck`. The server blocks exactly the
three cases where that would break itself, and allows every other one silently — an ordinary
`svc.>` is not checked. Setting `no_ack` also means a JetStream publish into that stream can never
succeed: nothing answers, so the publish waits out its full deadline and returns `nats: timeout`.

`10052` is `JSStreamInvalidConfigF`, whose description is `{err}`, so the numeric code identifies none
of these — [[error-codes]]. The design guidance is on [[core-or-jetstream]].


## Related

[[stream]] · [[consumer]] · [[defaults-and-limits]] · [[config-keys]] · [[js-api-subjects]] ·
[[retention-policies]] · [[replicas]] · [[mirrors-and-sources]] · [[message-ttl]] ·
[[message-scheduling]] · [[publishing]] · [[priority-groups]] · [[direct-get]] ·
[[subject-transforms]] · [[stream-placement]] · [[nats-cli]] · [[jsm-go]]

## Sources

[[s-nats-server-stream-consumer-config]] · [[s-nats-server-config-mutability-observed]] ·
[[s-jsm-go-config-schemas]] · [[s-nats-cli-help-0.4.0]] · [[s-docs-stream-config]] ·
[[s-docs-consumer-config]] · [[s-gh-3944-subjects-in-a-stream]] · [[s-adr-33-metadata]] ·
[[s-adr-34-multiple-filters]] · [[s-adr-9-idle-heartbeats]] · [[s-adr-42-priority-groups]] ·
[[s-adr-43-per-message-ttl]] · [[s-adr-51-message-scheduler]] · [[s-relnotes-2.10]] ·
[[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-nats-server-core-or-jetstream-observed]] · [[s-synadia-subject-hierarchies]] · [[s-synadia-expected-sequence-headers]]
