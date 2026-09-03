<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, macOS, 2026-09-03 · the lab cluster of tools/lab/cluster.sh (n1–n3), raw $JS.API requests from the $G account; scripts config-mutability-run.sh, -run2.sh, -run3.sh beside this file -->
# nats-server v2.14.6 — which stream and consumer fields can change after creation, observed

The behavioural half of `stream-consumer-config-v2.14.6.md`, for `wiki/reference/stream-and-consumer-config.md`
(phase E step 2). Every update is a raw `$JS.API.STREAM.UPDATE.<s>` or `$JS.API.CONSUMER.CREATE.<s>.<c>` with
`"action":"update"`, so the refusal strings are the server's. Three passes: pass 1 (`CFG`, `allow_msg_ttl: true`
from creation) covered most fields but its harness copied a config with `allow_rollup_hdrs: true` forward from
the *schedules* case, so its later stream cases are contaminated and are re-run in pass 2 (`CFG2`, a bare
stream); pass 3 is the pull-batch test on an unsealed stream, because pass 2 had sealed its stream before
publishing. The contaminated pass-1 lines are kept below and marked.

## 1 · Stream updates — refused

| change | code | description |
|---|---|---|
| `name` | 10056 | `stream name in subject does not match request` |
| `storage` file → memory | 10052 | `stream configuration update can not change storage type` |
| `retention` interest → workqueue | 10052 | `stream configuration update can not change retention policy to/from workqueue` |
| `persist_mode` "" → async | 10052 | `stream configuration update can not change persist mode` |
| `allow_msg_ttl` true → false | 10052 | `message TTL status can not be disabled` |
| `allow_msg_counter` false → true | 10052 | `stream configuration update can not change message counter setting` (pass 2, bare stream); on the TTL stream of pass 1 the earlier validation fired first: `counter stream cannot use message TTLs` |
| `allow_msg_schedules` true → false | 10052 | `message schedules can not be disabled` |
| `deny_delete` true → false | 10052 | `stream configuration update can not cancel deny message deletes` |
| `deny_purge` true → false | 10052 | `stream configuration update can not cancel deny purge` |
| `sealed` true → false | 10052 | `stream configuration update can not unseal a sealed stream` |
| `mirror` added to a stream with `subjects` | 10034 | `stream mirrors can not contain subjects` |
| `mirror` added, `subjects` emptied | 10055 | `stream mirror configuration can not be updated` |
| `max_age` 50ms | 10052 | `max age needs to be >= 100ms` |
| `duplicate_window` 2m with `max_age` 1m | 10052 | `duplicates window can not be larger then max age` |
| `discard_new_per_subject` with `discard: old` | 10052 | `discard new per subject requires discard new policy to be set` |
| `discard_new_per_subject` with `discard: new`, no `max_msgs_per_subject` | 10052 | `discard new per subject requires max msgs per subject > 0` |
| `max_age` 1h on a sealed stream | 10052 | `stream configuration update can not cancel deny message deletes` — sealing had set `deny_delete`, which the request (built from the pre-seal config) did not carry |

## 2 · Stream updates — accepted

| change | note |
|---|---|
| `retention` limits → interest | accepted (and back) |
| `discard` old → new | accepted |
| `num_replicas` 1 → 3 → 1 | accepted on the three-node lab |
| `max_consumers` -1 → 5 | accepted (updatable since 2.12.5, #7724) |
| `compression` none → s2 | accepted — takes effect only when the store is re-created, `wiki/concepts/stream-compression.md` |
| `subjects` | accepted |
| `allow_msg_schedules` false → true | accepted **without** `allow_rollup_hdrs` — the reply carried `allow_rollup_hdrs: true` (the server turns it on, `message-schedules-observed-v2.14.6.md`) |
| `deny_delete` false → true | accepted |
| `deny_purge` false → true | accepted (pass 2; in pass 1, with `allow_rollup_hdrs: true` inherited, refused `roll-ups require the purge permission`) |
| `sealed` false → true | accepted; `STREAM.INFO` afterwards: `sealed: true, deny_delete: true, deny_purge: true, discard: new, max_age: 0` — the four adjustments `configUpdateCheck` makes for a sealed stream (`stream.go:2371–2377`) |
| `discard_new_per_subject` with `discard: new` and `max_msgs_per_subject: 10` | accepted |

Pass-1 lines contaminated by the inherited `allow_rollup_hdrs: true` (each refused `10052 roll-ups require
the purge permission`, which is the roll-up/purge validation and not the field under test): `deny_purge on`,
`sealed on`, `sealed off`, `mirror added`, `discard_new_per_subject without discard new`,
`allow_msg_counter on a sealed stream`. Pass 2 re-ran the first five cleanly; the last is subsumed by the
counter refusal.

## 3 · Consumer updates — refused

Pull consumer `c1`, `ack_policy: explicit`, `filter_subject: cfg.a`, `action: update`:

| change | code | description |
|---|---|---|
| `deliver_policy` all → new | 10012 | `deliver policy can not be updated` |
| `deliver_policy` → by_start_sequence with `opt_start_seq: 5` | 10012 | `deliver policy can not be updated` (the policy check fires before the start-sequence one) |
| `ack_policy` explicit → all | 10012 | `ack policy can not be updated` |
| `replay_policy` instant → original | 10012 | `replay policy can not be updated` |
| `deliver_subject` set (pull → push) | 10012 | `can not update pull consumer to push based` |
| `max_waiting` 512 → 10 | 10012 | `max waiting can not be updated` |
| `mem_storage` false → true | 10012 | `storage type can not be updated` |
| `durable_name` changed | 10017 | `consumer name in subject does not match durable name in request` |
| `idle_heartbeat` 5s on a pull consumer | 10088 | `consumer idle heartbeat requires a push based consumer` |
| `flow_control` on a pull consumer | 10089 | `consumer flow control requires a push based consumer` |
| `backoff` [1s, 2s, 3s] with `max_deliver: 2` | 10116 | `max deliver is required to be > length of backoff values` |

## 4 · Consumer updates — accepted

`description`; `ack_wait` 30s → 10s; `max_deliver` -1 → 5; `max_ack_pending` 1000 → 10; `filter_subject`
cfg.a → cfg.b; `filter_subject` → `filter_subjects: [cfg.a, cfg.c]`; `backoff: [1s, 2s]` with `max_deliver: 5`
(the reply's `ack_wait` became 1s — the first backoff entry, `consumer.go:651–658`); `inactive_threshold` 1m;
`num_replicas` 1; `priority_groups: [a]` + `priority_policy: overflow` on a pull consumer (accepted — the
change ADR-42 says is not allowed; already `priority-groups-observed-v2.14.6.md`, docs issue #37);
`max_batch` 5. The created consumer reported the defaults the server filled in: `ack_wait 30000000000`,
`max_deliver -1`, `max_ack_pending 1000`, `max_waiting 512`.

An **ephemeral** consumer created with only `ack_policy: none` came back with `inactive_threshold: 5000000000`
(5 s, `JsDeleteWaitTimeDefault`), `max_waiting: 512`, and no `ack_wait` or `max_ack_pending` — those two
apply to `explicit` and `all` only (`consumer.go:651`, `:674`).

## 5 · `STREAM.INFO` with `subjects_filter` (row 146)

Three publishes (`cfg.a`, `cfg.b`, `cfg.a`), then `{"subjects_filter":">"}`:

```
state.num_subjects: 2   subjects: {'cfg.a': 2, 'cfg.b': 1}   paging total/offset/limit: 2 0 100000
```

The per-subject counts arrive in `state.subjects`, paged 100000 at a time with `offset` — the answer to
"which subjects does the stream actually hold" (gh#3944).

## 6 · The pull `batch` ceiling (docs: "Maximum: 256")

Pass 3, stream `CFG3` with three messages, consumer `c3` with no `max_batch`:

```
$JS.API.CONSUMER.MSG.NEXT.CFG3.c3  {"batch":300,"no_wait":true}   → m1, m2, m3, then Status 404 No Messages
$JS.API.CONSUMER.MSG.NEXT.CFG3.c3  {"batch":100000,"no_wait":true} → Status 404 No Messages
```

A batch of 300 and of 100000 were accepted and served; the only ceiling is the consumer's `max_batch`
(pass 1, after `max_batch: 5`): `Status 409, Description: Exceeded MaxRequestBatch of 5` — and the server
limit `jetstream { limits { max_request_batch } }` behind it (`consumer.go:834–835`). There is no 256.

## Not tested

Push-consumer updates (`deliver_subject` changes on a bound push consumer, `deliver_group`, `headers_only`);
`num_replicas` changes on a consumer other than 1; `rate_limit_bps`; `sample_freq`; `pause_until` by update;
`sources` edits (the docs and `mirrors-and-sources` say they can be added and dropped); `first_seq` on
update; the clustered R3 stream's update path (all streams here were R1 except the `num_replicas 3` case);
pedantic mode.
