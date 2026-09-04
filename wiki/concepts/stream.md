---
title: Stream
type: concept
area: [jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [stream, storage, limits, discard, persist_mode]
aliases: [streams, StreamConfig, stream config]
sources: [s-nats-server-snapshot-restore, s-docs-stream-config, s-docs-policies, s-docs-retention-policies, s-docs-surviving-node-loss, s-docs-replication-and-r3, s-synadia-jetstream-memory-patterns, s-docs-upgrade-to-2.12, s-relnotes-2.14.0, s-nats-server-constants-2.14.6, s-adr-35-filestore-compression, s-docs-delivery-and-acknowledgment, s-nats-server-filestore-layout, s-docs-publishing, s-docs-advanced-publishing, s-docs-shaping-the-stream, s-docs-altering-stream-state, s-docs-subject-mapping, s-docs-reading-back, s-docs-kv-history-and-revisions, s-adr-1-jetstream-json-api, s-adr-10-extended-purge, s-adr-20-object-store, s-adr-43-per-message-ttl, s-adr-8-key-value-store, s-docs-accounts-and-multitenancy, s-docs-disaster-recovery, s-docs-get-direct, s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-docs-sizing-and-resources, s-docs-stream-backup-restore, s-docs-upgrade-to-2.14, s-gh-5924-filestore-dirs-vanished, s-issue-4281-insufficient-storage, s-synadia-jetstream-anti-patterns, s-adr-51-message-scheduler, s-docs-jetstream-headers, s-nats-server-message-schedules-observed, s-gh-7147-one-billion-cap, s-gh-7032-max-msgs-known-good, s-nats-server-filestore-recovery, s-gh-8333-high-cardinality-subjects, s-synadia-how-many-subjects, s-nats-server-stream-scale-observed, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-relnotes-2.15-preview, s-nats-server-stream-consumer-config, s-nats-server-config-mutability-observed, s-docs-concepts-jetstream, s-docs-core-nats-chapter, s-docs-jetstream-where-next, s-nats-server-core-or-jetstream-observed, s-gh-3507-no-external-store, s-gh-6100-stream-per-subject-or-one, s-gh-3772-jetstream-as-an-event-store, s-nats-server-stream-topology-observed, s-gh-3871-tiered-storage-planned, s-gh-6478-s3-offload-and-query]
created: 2026-08-31
updated: 2026-09-04
---

# Stream

A stream is JetStream's durable, ordered message store: it captures messages published on a set of
subjects, assigns each one a monotonically increasing sequence number, and keeps it until a
[[retention-policies|retention policy]] or a limit removes it. Everything else in JetStream —
[[consumer|consumers]], KV buckets, Object Store buckets — is built on one.

## How it behaves

- A stream binds to a **list of subjects**, wildcards included (`orders.>`,
  `orders.*.created`). A stream configured with a `mirror` must have an empty `subjects` list; a
  stream with `sources` may have one (source: [[s-docs-stream-config]]).
- Publishing into a stream is a **request**: the server answers with a `PubAck` carrying the
  assigned sequence. `nats pub --jetstream` waits for it; a plain `nats pub` is a core NATS publish
  and does not (source: [[s-docs-replication-and-r3]], [[s-docs-publishing]]). What the ack proves,
  the four publish modes, and duplicate suppression are on [[publishing]].
- Messages are **immutable and ordered by stream sequence**. A message leaves the stream only when
  a limit removes it, when [[retention-policies|retention]] decides consumers are finished with it,
  or when it is deleted or purged by hand.
- **The subject a message is stored under is not always the subject it was published to.** A stream
  subject transform rewrites it on the way in — see [[subject-transforms]].
- With more than one replica the stream has a **leader** that takes every write; see
  [[replicas]] and [[raft-in-nats]].
- Reads are independent of writes: each [[consumer]] keeps its own cursor over the one shared copy
  of the data (source: [[s-docs-delivery-and-acknowledgment]]).
- **A stream lives in exactly one [[account]], and the account owns the namespace.** Each account
  gets its own JetStream store, a stream created in `$G` before the accounts existed does not follow
  its users into a new account, and the server checks a new stream's subjects against **every stream
  in that account** — an overlap is refused with `subjects overlap with an existing stream`
  (**10065**) (sources: [[s-docs-accounts-and-multitenancy]], [[s-docs-disaster-recovery]]). That
  check is why promoting a DR mirror needs the dead stream's assignment removed first.

## What configures it

Field names below are the `StreamConfig` names the JetStream API uses; the `nats` CLI flag is
given where it differs. All defaults are from the 2.14 schema reference
(source: [[s-docs-stream-config]]).

**Identity and shape**

| field | default | notes |
|---|---|---|
| `name` | — | must not contain `.`, `*` or `>` (pattern `^[^.*>]*$`) |
| `description` | — | max 4096 characters |
| `subjects` | — | `--subjects "orders.>"` |
| `storage` | `file` | `file` \| `memory`; **fixed at creation** |
| `num_replicas` | `1` | **minimum 1, maximum 5**; `--replicas` |
| `placement` | unset | cluster + tags; random placement when unset — see [[stream-placement]] |

**Limits — what makes a message leave**

| field | default | notes |
|---|---|---|
| `max_msgs` | `-1` | unlimited |
| `max_msgs_per_subject` | `-1` | per-subject cap on a wildcard stream |
| `max_bytes` | `-1` | unlimited |
| `max_age` | `0` | nanoseconds; `0` is unlimited |
| `max_msg_size` | `-1` | signed 32-bit, maximum `2147483647` |
| `max_consumers` | `-1` | unlimited |
| `discard` | `old` | `old` deletes the oldest to make room; `new` rejects the publish |
| `discard_new_per_subject` | `false` | with `discard: new` and `max_msgs_per_subject` set, applies discard-new per subject |
| `retention` | `limits` | `limits` \| `interest` \| `workqueue` — see [[retention-policies]] |

**Behaviour flags** (all default `false` unless noted)

`no_ack` (disable publish acknowledgements) · `sealed` (no deletion via limits or API, cannot be
unsealed, settable only on an existing stream via the Update API) · `deny_delete` and `deny_purge`
(cannot be changed once `true`) · `allow_rollup_hdrs` (enables the `Nats-Rollup` header) ·
`allow_direct` and `mirror_direct` (direct per-message reads — the API default is `false`, but
"the CLI enables it for new streams", so a stream added with `nats stream add` has it on and one
created through a client library may not; check with `nats stream info` and turn it on later with
`nats stream edit ORDERS --allow-direct`, source: [[s-docs-get-direct]]) · `allow_atomic` (atomic batched
publishes, **2.12**) · `allow_batched` (fast batch publishing, **2.14**) · `allow_msg_counter`
(counter CRDT semantics, **2.12**) · `allow_msg_schedules` (delayed scheduling **2.12**; recurring
and cron schedules, subject sampling and scheduled rollups **2.14**) · `allow_msg_ttl`
(per-message TTL via headers, **2.11**) · `subject_delete_marker_ttl` (**2.11**) ·
`compression` (`none` | `s2`) · `duplicate_window` (nanoseconds, default `0` — see *The deduplication window* below) ·
`persist_mode` (`""` | `default` | `async`) · `pedantic` (default `false`; the server applies no
defaults and does not rewrite the request) · `republish` (re-emit every stored message onto a second
subject on the way out — the fields, the five headers and the `10052` cycle check are on
[[subject-transforms]]).

**Compression.** `s2` makes a file-storage stream compress message blocks on disk, spending CPU to
cut disk usage — repetitive payloads such as JSON compress well, already-compressed payloads such
as images do not. Set it at creation with `--compression s2`. It *can* be edited later, but the new
setting only takes effect when the stream's store restarts (a server restart or a leader change),
and blocks already on disk stay as they are (source: [[s-docs-policies]]) — confirmed by running it
on 2.14.6, where a block sealed after the edit was still uncompressed. Treat it as a create-time
decision; see [[stream-compression]].

**Persist mode.** By default a message is flushed to storage before the `PubAck` follows. On
`async` the server acknowledges first and flushes in the background: a higher ingest rate in
exchange for a window in which a crash loses messages the server already acked. `async` is only
accepted on a **file-storage stream with a single replica**, and an `async` stream **refuses atomic
batch publishing** (source: [[s-docs-policies]]).

## What you cannot change later

The server refuses these updates outright; the only way to change your mind is to recreate the
stream and move the data. The complete field-by-field table, with every refusal string as the
v2.14.6 binary produced it, is [[stream-and-consumer-config]] (source:
[[s-nats-server-stream-consumer-config]], [[s-nats-server-config-mutability-observed]]; the docs'
statements, [[s-docs-policies]], [[s-docs-stream-config]]).

| field | on a live stream |
|---|---|
| `name` | **fixed** — `stream name in subject does not match request` (10056) |
| `storage` | **fixed** — `stream configuration update can not change storage type` |
| `persist_mode` | **fixed** — `stream configuration update can not change persist mode` |
| `allow_msg_counter` | **fixed** — `stream configuration update can not change message counter setting` |
| `retention` | `limits` ↔ `interest` allowed, and the switch re-applies to messages already stored; to or from `workqueue` refused with `stream configuration update can not change retention policy to/from workqueue` |
| `mirror` | **fixed** — `stream mirror configuration can not be updated` (10055); "You can't point a mirror at a different upstream or change what it copies in place" — but since **2.12.0 removing it is allowed** (promotion, #7171); `sources`, by contrast, can be added, dropped or re-filtered (sources: [[s-docs-mirrors-and-sources]], [[s-relnotes-2.12]]) |
| `sealed`, `deny_delete`, `deny_purge` | **one-way** — each can be set and never cleared (`can not unseal a sealed stream`, `can not cancel deny message deletes`, `can not cancel deny purge`); sealing also forces `deny_delete`, `deny_purge`, `discard: new` and `max_age: 0`, so a later edit built from the old config is refused for a field you did not touch |
| `allow_msg_ttl` | **one-way** — `message TTL status can not be disabled`; setting it (or `subject_delete_marker_ttl`) requires stream API level `1`, and `subject_delete_marker_ttl` may not be set on a mirror at all (source: [[s-adr-43-per-message-ttl]]) |
| `allow_msg_schedules` | **one-way** — `message schedules can not be disabled`; turning it on turns `allow_rollup_hdrs` on for you |
| `max_consumers` | free **since 2.12.5** (#7724); fixed before |
| `discard`, `num_replicas`, `subjects`, `compression`, the limits, `metadata`, `consumer_limits` | can change — `compression` only takes effect after the store is re-created ([[stream-compression]]); a `consumer_limits` change re-validates every consumer |

Recreating a stream means moving the data. A [[mirrors-and-sources|mirror]] can copy the messages
across, but a mirror is read-only and turning it into a publishable replacement takes further steps
(source: [[s-docs-policies]]).

## Which clock stamps a message

The **leader's**. `processJetStreamMsg` sets the timestamp with `time.Now().UnixNano()` on the leader
before the message is proposed to the group, and the value travels in the Raft proposal, so every
replica stores the same instant and a follower's clock never enters a message (`stream.go:6929–6931`
at v2.14.6; atomic batches `:7486`; source: [[s-nats-server-stream-consumer-config]]). A cluster
therefore does not need synchronised clocks for *ordering* — sequence numbers do that — but it does
for **anything measured in time across a leader change**: `max_age`, per-message TTLs,
`subject_delete_marker_ttl` and `opt_start_time` are evaluated by whichever server leads at the
moment, against the stored timestamp, so a new leader whose clock is ahead ages every message by the
skew. Run NTP on JetStream nodes; the question is gh#3095 (row 140).


## Limits and failure modes

- **Replica count is capped at 5** and defaults to 1. R=1 is a single point of failure; see
  [[replicas]].
- **Limits do not overlap with retention** — they are a second, independent way a message leaves.
  On an `interest` or `workqueue` stream the limits are the backstop that keeps the stream bounded
  when consumers fall behind (source: [[s-docs-retention-policies]]).
- **The three limits are independent and all active at once; the first one reached wins**
  (source: [[s-docs-shaping-the-stream]]). So *"a seven-day `max_age` does not guarantee seven days
  of history"* — a traffic spike can reach `max_bytes` first and discard messages hours old. Size
  `max_bytes` for peak traffic, not average, whenever the age window is a promise you made.
- **`max_age` is not a discard-policy choice.** `discard` decides what happens when a **size or
  count** limit is hit; `max_age` "expires stored messages on its own timer under either policy".
- **Whole-stream limits do not balance across subjects.** `orders.created` and `orders.shipped` count
  against one ceiling, so under `discard: old` a flood of one can evict the other. The per-subject
  ceiling is `max_msgs_per_subject`.
- **`discard: new` does not make a full *subject* reject.** By default a per-subject limit still
  rolls, discarding that subject's oldest message. Making it reject takes `discard_new_per_subject`
  **on top of** `discard: new`, and then a publish past the ceiling fails with
  `maximum messages per subject exceeded` — the third rejection string alongside the whole-stream
  `maximum bytes exceeded` and `maximum messages exceeded` ([[maximum-messages-exceeded]]).
- **`max_bytes` is a reservation, not just a ceiling.** "`max_bytes` will reserve that for you
  against the jetstream limits for the servers and the account", so a stream that stores 5 MB but
  declares `--max-bytes=10G` has spent 10 GB of the budget the next stream is checked against — and
  the refusal is `insufficient storage resources available` (**10047**), which does *not* mean the
  disk is full. Streams left at `-1` reserve nothing and still consume real disk, which is what makes
  a mixed deployment's arithmetic surprising (source: [[s-issue-4281-insufficient-storage]];
  [[jetstream-out-of-disk]], [[jetstream-sizing]]).
- **A stream costs more than its bytes.** JetStream spends roughly **two file descriptors per
  stream**, and on an un-tiered account an R3 stream counts `replicas × bytes` — a 10 GiB stream at
  R3 spends 30 GiB of the account's `MaxStore` (source: [[s-docs-sizing-and-resources]];
  [[jetstream-sizing]] does the arithmetic).
- **Since 2.14 a filestore I/O error freezes the stream** rather than being logged and passed over:
  "each stream affected by it will stop making progress", and it is surfaced in logs and health
  checks. Other streams on the same server are unaffected, and on a replicated stream another replica
  picks up the work transparently (source: [[s-docs-upgrade-to-2.14]]).
- **`nats stream info` can list a stream whose data directory is gone.** Stream *metadata* lives in
  the meta layer while message *blocks* live under `jetstream { store_dir }`, so the two can
  disagree — the pairing of "all streams listed" with "most directories missing" is itself the
  diagnostic, and a `store_dir` left under `os.TempDir()` is the usual reason (source:
  [[s-gh-5924-filestore-dirs-vanished]]; [[stream-directories-disappear]]).
- **A `PubAck` on a replicated stream means a quorum holds the write, not that it is on disk.**
  JetStream batches disk syncs on `sync_interval`, which defaults to `2m`. See [[replicas]] and
  [[raft-in-nats]] (source: [[s-docs-replication-and-r3]]).
- Choosing `storage: memory` gives up durability across a restart for the whole stream — storage is
  a stream-wide property and cannot be mixed per replica (source: [[s-docs-surviving-node-loss]]). It also gives up **backup**: a snapshot copies
  a stream's on-disk files, and a memory stream has none, so `nats stream backup` fails with
  `snapshot failed: no impl` (**10064**) — [[backup-and-restore-jetstream]]. Since `storage` is fixed
  at creation, this is decided once and for good.
- **A restore is a recreate, and it is strict about identity.** The snapshot directory holds
  `backup.json` (the stream's configuration and state) and `stream.tar.s2` (the messages); a restore
  rebuilds the stream from it, will **not** merge into a live one, and refuses a rename — the CLI's
  message is `stream names may not be changed during restore`. So a real recovery is: confirm the
  broken stream is gone, then restore (source: [[s-docs-stream-backup-restore]];
  [[backup-and-restore-jetstream]] has the runbook).

### There is no cap on messages, and no known-good `max_msgs`

A stream's message count is not bounded by the server: no constant of a billion exists in it,
sequences are `uint64`, and `max_msgs` is an `int64` whose only validation rewrites 0 or anything
below −1 to −1 — unlimited (source: [[s-nats-server-filestore-recovery]]); `nats stream edit
--max-msgs 10000000000` is accepted on 2.14.6 (source: [[s-nats-server-stream-scale-observed]]). A
maintainer answered the
"capped at one billion?" report with a limits stream at **1,174,510,552 messages** on one subject;
the reporter's discards were never explained and the thread never shows the size limits that would
have (source: [[s-gh-7147-one-billion-cap]]). Asked for the largest known-good `max_msgs`, a
maintainer said there is no hard limit and the bounds are disk and the per-subject index in RAM —
shard by time when one runs out (source: [[s-gh-7032-max-msgs-known-good]]). What a stream *is*
bounded by, then: `max_bytes` and the server's and account's storage limits (all sizes), `max_age`,
memory for one entry per distinct subject (a few hundred bytes each; source:
[[s-gh-8333-high-cardinality-subjects]], [[s-synadia-how-many-subjects]]), and the time a restart
takes to read it ([[jetstream-recovery-is-slow]]). [[jetstream-sizing]] prices each.


## Sequences are addresses, and they are never reused

`1`, then `2`, then `3`, "and the server never hands `2` out again to a future message"
(source: [[s-docs-altering-stream-state]]). Four consequences, and the last two are the ones that
break code:

- **A delete or a purge leaves a permanent hole.** Delete sequence 2 and 1 and 3 stay exactly where
  they were; the server does not renumber to close the gap.
- **A purge does not rewind the counter.** It "sets the stream's first sequence to one past its
  last", so after emptying a stream the next publish continues from where it stopped, not from `1`.
- **A stored sequence is a stable external reference.** Save "order `ord_8w2k` is at sequence 2"
  beside your business record and that pointer "either still points at the same message or points at
  nothing. It never points at a different message."
- **A count is not a sequence.** Do not compute "the next message" as `count + 1`, and do not read a
  message count as the highest sequence. On any stream that has ever lost a message they differ.
- **A KV revision is one of these numbers.** That is why a bucket's revision counter is bucket-wide
  rather than per key: writes to any key take the next stream sequence, so one key's revisions are
  `2`, `5`, `9` and the gaps are other keys (source: [[s-docs-kv-history-and-revisions]];
  [[key-value]]).

Consumers cope with the gaps without help: a consumer "never blocks waiting for a deleted message,
and a missing `2` is not redelivered" ([[consumer]]).

**Removing a message by hand has two costs, and the CLI picks the expensive one.**
`nats stream rmm <stream> <seq>` **securely erases**: the server overwrites the stored bytes so the
old contents cannot be read back — the right default for data that should never have been stored.
The client libraries default the other way: `DeleteMsg(seq)` marks the message erased and leaves its
bytes until they are later overwritten, while `SecureDeleteMsg(seq)` overwrites immediately and is
slower for it. **The only difference the server sees is a single `no_erase` flag on the delete
request** (source: [[s-docs-altering-stream-state]]). If you are deleting a message *because* of what
it contained, make sure you used the erasing form.

## Purging is a request with options

`$JS.API.STREAM.PURGE.<stream>` **with no payload purges the whole stream**. With a JSON body it
takes three options, and they are the difference between an outage and a recovery (source:
[[s-adr-10-extended-purge]] — a 2021 spec that is still exactly what 2.14.6 implements):

| option | CLI | effect |
|---|---|---|
| `filter` | `--subject=<subject>` | purge one subject only — how you evict one tenant, key space or partition out of a shared stream |
| `seq` | `--seq=<sequence>` | purge everything below a sequence |
| `keep` | `--keep=<messages>` | keep the newest *n* messages, purge the rest |

`seq` and `keep` are **mutually exclusive**; sending both returns `10003 bad request`
(`jetstream_api.go:3726`). A **sealed** stream refuses with `10109 invalid operation on sealed
stream`, and a stream configured `deny_purge: true` with `10110 stream purge not permitted`
(`jetstream_api.go:3748`).

**`--keep` is the recovery tool for a stream at its limit** — the only form that guarantees the
stream is still usable afterwards, and unlike raising `max_msgs` it takes effect immediately. A purge
removes messages; it does not renumber, as *Sequences are addresses* above says.

## The API

`$JS.API.STREAM.CREATE.<stream>` creates a stream (source: [[s-docs-stream-config]]). The full
subject set will live in [[js-api-subjects]].

**Every stream operation has its own subject** — `$JS.API.STREAM.INFO.%s`,
`$JS.API.STREAM.PURGE.%s`, `$JS.API.STREAM.MSG.GET.%s`, `$JS.API.STREAM.PEER.REMOVE.%s`,
`$JS.API.STREAM.LEADER.STEPDOWN.%s` among them — and that is deliberate: "every API has a unique
subject and generally the subject includes the Stream or Consumer name, this facilitates ACLs giving
people access to either subsets of API or even down to a single Stream or Consumer" (source:
[[s-adr-1-jetstream-json-api]]). [[subject-permissions]] is where that gets used.

Two commands make the wire form readable rather than guessed at: `nats schema show
io.nats.jetstream.api.v1.stream_create_request --yaml` prints the request schema, and **`--trace` on
any `nats` command logs every JetStream API subject and body unmodified** — the fastest way to see
what a client library actually sent (source: [[s-adr-1-jetstream-json-api]]).

## The deduplication window

`duplicate_window` is the period over which the server tracks recently seen message IDs so a
repeated publish is rejected as a duplicate. The `StreamConfig` schema records the field's default
as `0`, described only as "0 for default" — it does not say what the server substitutes
(source: [[s-docs-stream-config]]).

The substituted default is **2 minutes** — `StreamDefaultDuplicatesWindow`, `server/stream.go:1658`
at **v2.14.6** (source: [[s-nats-server-constants-2.14.6]]). Synadia stated the same value in a post
dated 2025-08-08 (source: [[s-synadia-jetstream-memory-patterns]]); the source read confirms it for
2.14. **The docs state it too, in prose, in the `learn` chapter** — "the duplicate-tracking window is
two minutes by default" (source: [[s-docs-publishing]]) — so the gap is narrower than first recorded:
the value is missing from the generated reference where the field is *defined*, not from the docs as
a whole. `inbox/docs-issues.md` #5 has been corrected accordingly.

**What a publisher must do to use the window** — a stable `Nats-Msg-Id`, and what the guarantee is
and is not — is on [[publishing]].

It applies **only** when the stream sets no window of its own **and is neither a mirror nor a
source** (`stream.go:1750`), and is then clamped down by the account or server `Duplicates` limit if
that is lower, and by `max_age` if `max_age` is smaller. **In pedantic mode both clamps are errors
instead of silent adjustments.**

The window is a **memory** setting as much as a correctness one: the server holds the tracked
message IDs in RAM, so a long window on a high-cardinality publisher is paid for in memory. If you
deduplicate externally, shortening or disabling it per stream is one of the named ways to cut
JetStream's memory footprint — see [[jetstream-sizing]].

## Streams you did not create by hand

A KV bucket and an Object Store bucket are each **one stream with fixed properties**, so everything
above applies to them — and a few of the properties are not yours to choose:

| | KV bucket (source: [[s-adr-8-key-value-store]]) | Object Store bucket (source: [[s-adr-20-object-store]]) |
|---|---|---|
| stream name | `KV_<bucket>` | `OBJ_<bucket>` |
| subjects | `$KV.<bucket>.>` | `$O.<bucket>.C.>` (chunks) and `$O.<bucket>.M.>` (metadata) — **two subject spaces in one stream** |
| `discard` | always `new` | `new` |
| `allow_rollup_hdrs` | always `true` | `true` — the object's info subject is always rolled up per subject |
| `allow_direct` | always `true`, "modifiable out-of-band only, never through a KV bucket update" | `true` |
| `deny_delete` | always `true` | — |
| history / retention | `max_msgs_per_subject`, **maximum 64, minimum 1** | `max_age: 0`, `max_bytes: -1` in the ADR's example config |
| key/object TTL | the stream's `max_age` | `TTL → max_age` |
| size caps | `max_msg_size` per value, `max_bytes` per bucket | `MaxBytes → max_bytes` |

`placement`, `republish`, `metadata` and `compression` stay available on both. Two consequences worth
carrying: **deleting a bucket deletes the stream**, and a bucket's per-key **history cannot exceed
64** because it is `max_msgs_per_subject`. See [[key-value]] and [[object-store]].

**Consumers are not the only way to read one.** A `republish` policy re-emits stored messages onto
core subjects for subscribers that do not need delivery guarantees, and Direct Get serves "specific
messages from streams" with no consumer at all — both are named as the fix when a stream has grown
too many consumers (source: [[s-synadia-jetstream-anti-patterns]];
[[jetstream-slows-as-consumers-grow]], [[direct-get]]).

## `allow_msg_schedules`, and the two fields it changes behind you

**Since 2.12.** Setting `allow_msg_schedules` lets messages on this stream carry `Nats-Schedule`
headers, so the stream itself publishes messages on a schedule ([[message-scheduling]]). It belongs on
this page for one reason: **it is a one-way door that silently rewrites two other stream fields**
(source: [[s-adr-51-message-scheduler]], confirmed on v2.14.6 —
source: [[s-nats-server-message-schedules-observed]]).

```
$ nats stream add SCHED --subjects='schedules.>,orders' --allow-schedules --allow-msg-ttl
$ nats stream info SCHED --json | jq '.config | {allow_msg_schedules, allow_rollup_hdrs, deny_purge}'
{ "allow_msg_schedules": true, "allow_rollup_hdrs": true, "deny_purge": false }
```

Neither rollup nor purge was asked for. Schedules are stored as rollup-subject messages — the server
auto-applies `Nats-Rollup: sub` so a new schedule replaces the old one on the same subject — so
enabling the feature **enables `allow_rollup_hdrs` and clears `deny_purge`**. If either was a
deliberate control on that stream, it is gone; see [[subject-permissions]].

Its other rules, and where they sit against *What you cannot change later*:

| rule | error |
|---|---|
| **cannot be turned off again** — it joins the fields above that are effectively permanent | `message schedules can not be disabled (10052)` |
| not allowed on a **mirror** | `10186` |
| not allowed on a stream with **sources** | `10187` |
| not supported with **`discard: new`** | `message scheduling cannot use discard new (10052)` |
| raises the stream to **API level 2** | older clients cannot manage it |

`nats stream info` shows it as `Allows Schedules: true` with `Required API Level: 2`.


## Version notes: the 2.10 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch streams from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

From the release bodies (source: [[s-relnotes-2.10]]):

- **Since 2.10.0**: `subject_transform` on a stream and republish on mirrors and sources
  ([[subject-transforms]]); `metadata`; `compression` (`s2`, file storage — [[stream-compression]]);
  `first_seq` at creation; filestore re-encryption with new keys; `jetstream { sync_interval }` and
  `sync: always` (the body misspells the key `sync_internal`); a `limits` stream may be updated to
  `interest` retention (#4361).
- **Since 2.10.17 a stream whose subjects capture `$JS.>`, `$JS.API.>`, `$JSC.>` or `$SYS.>` is
  only allowed with `no_ack`** — "avoiding potential misconfiguration that could affect the JetStream
  API"; `$JS.EVENT.>` and `$SYS.ACCOUNT.>` stay allowed (#5548, #5556); 2.10.28 tightened the
  overlap check "so that badly-configured streams should not be able to break the API" (#6786).
- **Since 2.10.28 a publish into JetStream above 32 MB is rejected** — "correctly enforce the 32MB
  maximum publish size limit into JetStream, avoiding filestore corruption from overflowing the
  maximum record length" (#6798); the same release stopped a `first_seq` stream from being purged
  after a restart when its first sequence still matched (#6753).
- 2.10.19: with `sync: always`, stream and consumer metadata files are written `O_SYNC` (#5729).


## Version notes: the 2.11 line

From the release bodies (source: [[s-relnotes-2.11]]):

- **Since 2.11.0**: **ingest rate limiting** — `jetstream { max_buffered_msgs, max_buffered_size }`
  "control how many publishes should be queued before rate-limiting", and a rate-limited publish
  with a reply subject receives **`429 Too Many Requests`** (#5796). The server's default is 100,000
  messages and 128 MB; the docs print 10,000 and describe the buffer as being for unavailable
  storage — `inbox/docs-issues.md` #22. Also 2.11.0: `subject_delete_marker_ttl` ([[message-ttl]]),
  the `Nats-Expected-Last-Subject-Sequence-Subject` header (#5281), pedantic mode, and asset
  versioning (API levels, ADR-44).
- **2.11.4**: **an update is refused while all peers are offline** — "fixing a potential avenue for
  data loss" (#6856); a WorkQueue stream's first and last sequences survive a crash with unflushed
  data (#6882); purging over interior deletes adjusts the first sequence (#6861).
- **2.11.9**: the same stream can no longer be created twice with different configurations (#7210,
  #7212); an update with an empty `placement` no longer triggers a move (#7222).
- **2.11.11**: a stream with subject transforms **republishes implicitly** when both republish
  source and destination are `>` (#7515).
- **2.11.12**: **switching to `interest` retention removes no-interest messages from the head of the
  stream** (#7766) — see [[retention-policies]].
- **2.11.15**: a restore checks that the stream name in the subject matches the archive; ingest
  strips a NATS status header so sourced or mirrored messages are not taken for control traffic;
  sourcing into a stream with `discard_new_per_subject` works (#7896).


## Version notes: the 2.12 line

From the release bodies (source: [[s-relnotes-2.12]]):

- **2.12.0**: **replicated streams flush asynchronously by default** "as long as `sync: always` is
  not configured" (#7018, #7163), with an opt-in async persist mode for R1 (#7315, #7323); a mirror
  may be **promoted** by removing its `mirror` configuration (#7171); a replicated stream can be
  created "even if some of the replica nodes are offline" (#7075); stricter config validation
  (#7134); `Nats-Expected-Last-Subject-Sequence-Subject` without its companion header now errors
  (#7196); `max_buffered_msgs` default ×10 to 100,000 (#6633).
- **2.12.3**: `discard_new_per_subject` "is now enforced by the leader before proposing rather than
  by individual replicas, reducing the potential for stream desync" (#7607).
- **2.12.5**: **`max_consumers` can be updated after creation** (#7724); consumers with overlapping
  filter subjects "where one is not a subset of the other" allowed (#7810); a stream source from
  another account or domain is checked correctly (#7903).
- **2.12.7 → 2.12.11**: a stream with `max_msgs_per_subject` on 2.12.7–2.12.10 can return `Message
  Not Found` from stale subject-state tracking (#8285); 2.14 unaffected.
- **2.12.8**: roll-ups apply on interest streams with no interest (#8019); consistency checks use
  the transformed subject (#8022); a failed proposal no longer advances the cluster sequence,
  "avoiding a `last sequence mismatch` error" (#8057); path separators are refused in asset names.
- **2.12.12**: zero consumer limits mean unlimited on an update (#8286). **2.12.14**: a publish over
  the maximum store size is rejected before proposal (#8389); a stream recreated while a node was
  down is not taken for an update by the returning node (#8413). **2.12.15**: idempotent creates no
  longer risk data loss when an offline node catches up from a meta snapshot (#8449).


## To verify

- The `duplicate_window` clamps in **pedantic mode** are read from the source; no run has confirmed
  which of the two clamps errors first when both apply.
- The `republish` policy's **inner field names**. [[subject-transforms]] carries the CLI flags
  (`--republish-source`, `--republish-destination`); the JSON in
  [[s-synadia-jetstream-anti-patterns]] writes them as `source` / `destination`, and no read of the
  server has confirmed the wire names here.

## What a stream's reported `bytes` actually counts

`nats stream info` reports **record bytes, not payload bytes**. Each stored message costs
`30 + len(subject)` beyond its payload — a 22-byte record header (`total_len`, `seq`, `ts`,
`subj_len`) plus an 8-byte checksum, with the subject written verbatim — and `4 + len(headers)` more
when it carries headers (source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`).

Everything that meters a stream uses that figure: `max_bytes`, `/jsz` `storage`, and an account's
`MaxStore`. Payload bytes are reported nowhere.

A **memory** stream counts differently — `len(subject) + len(headers) + len(payload) + 16` — so the
same message reports 135 B in a file stream and 121 B in a memory stream. The two numbers are not
comparable, and switching a stream's storage type changes its reported size.

The physical file is larger again: deletes leave the record in place and add a 30-byte tombstone,
and the newest message block is never compacted. See [[filestore-layout]] for the arithmetic and
[[jetstream-sizing]] for what to do with it.


## Version notes: the 2.14 line

From the seven release bodies (source: [[s-relnotes-2.14]]):

- **2.14.0**: `allow_batch_publish` — fast-ingest batch publishing (#7778 …); recurring schedules,
  sampling and rollups under `allow_msg_schedules` (#7504 …); **rollups allowed at the
  `discard_new_per_subject` limit** (#7974); **stream state snapshots on replicated streams taken
  asynchronously** (#7876); sourcing from WorkQueue and Interest streams (#7613); deduplication may
  be disabled when sourcing (#7651); stream info and list requests queued behind writes (#7898).
- **2.14.1**: republish subjects validated (#8127); reservations consistent between create/update and
  clustered/non-clustered (#8170). **2.14.2**: purges consistent between file and memory stores
  (#8241); scale-down consistent (#8253). **2.14.3**: catch-up no longer skipped when limits are
  exceeded, "preventing possible stream desync" (#8265); zero consumer limits mean unlimited on an
  update (#8286); `MultiLastSeqs` no longer reorders the configured subjects (#8315).
- **2.14.4**: a publish over the maximum store size is rejected before proposal (#8389); a stream
  recreated while a node was down is not taken for an update by the returning node (#8413); the
  snapshot endpoints check the reply subject more strictly. **2.14.5**: idempotent creates no longer
  risk data loss when an offline node catches up from a meta snapshot (#8449).
- **2.14.6**: **a config update with `replicas > 1` is rejected on a non-clustered server** (#8464);
  the created time survives recovery on a standalone server (#8471); snapshots no longer prevented
  on a clean shutdown (#8465); stream reads under a separate lock (#8486).
- **2.15 preview**: `$JS.API.STREAM.CANCEL_MOVE.<stream>` rolls back any in-flight scale, move or
  retention change; `$JS.API.STREAM.PEER.EVACUATE.<stream>`; a v2 backup format; and on a
  replicated stream `sync_interval: always` syncs the Raft log but no longer the stream layer
  (source: [[s-relnotes-2.15-preview]]).


## Choosing the subject list: what a stream quietly takes over

A stream captures by subject, and the publisher is never told one exists — "when a publisher sends a
message to a matching subject, the server appends it to the stream and assigns it a sequence number"
(source: [[s-docs-concepts-jetstream]]). That is what makes a stream easy to add under a running flow,
and it is also how a subject list widened by one token takes over traffic nobody meant to store.

**A stream that captures a request/reply subject answers the requests itself.** With a responder on
`svc.echo`, `nats request svc.echo ping` returns `pong`. Create `SVC` on `svc.>` and the same request
returns `{"stream":"SVC","seq":1}` — the stream's `PubAck`, delivered to the requester's inbox as an
ordinary `MSG`, and it arrives **first** (277 µs against the responder's 407 µs). A client that takes
one reply takes the ack; the responder's answer is discarded. Meanwhile the stream stores every
request with its payload (source: [[s-nats-server-core-or-jetstream-observed]], runs D1–D4).

The server refuses exactly three shapes of this and nothing else — `server/stream.go:2170–2196` at
2.14.6 requires `no_ack` for a stream on `>` (plus `replicas: 1`), for one overlapping
`$JS.>` / `$JSC.>` / `$NRG.>` (exception `$JS.EVENT.>`), and for one overlapping `$SYS.>` (exception
`$SYS.ACCOUNT.>`):

```
nats: error: could not create Stream: capturing all subjects requires no-ack to be true (10052)
```

`svc.>` is not one of those, so nothing warns you. List a stream's subjects explicitly rather than
sweeping a whole tree, keep request/reply verbs and `_INBOX.>` out of them, and check
`nats stream subjects <name>` after any change.

**And do not build a stream on `>`.** The only one the server accepts — `--no-ack --replicas 1` — held
twelve subjects and 41 messages after six ordinary commands, including every reply inbox,
`$SRV.PING.DEMO` and `$JS.API.STREAM.INFO.<itself>`: two `nats stream subjects` calls a moment apart
took that last count from 3 to 6, so reading the stream writes to it. A JetStream publish into it can
never succeed either, because a `no_ack` stream never answers (`nats: timeout` at the full deadline).

The rule for whether the flow wants a stream at all is one line: "stay on plain pub-sub when the next
message supersedes the last; reach for a stream only when a missed message has consequences" (source:
[[s-docs-jetstream-where-next]], and the same rule from the core side in
[[s-docs-core-nats-chapter]]). [[core-or-jetstream]] is that decision worked through per subject.


## Two storage backends, and there is no third

`memory` or `file`. Asked in public whether JetStream would support an external database the way NATS
Streaming did — the asker had been running it on Postgres and replicating the database himself — the
chosen answer was: "**No, we will support memory and file based for the store level.** We can
replicate in either store and each store can also have digital twins or source mux/demux streams"
(source: [[s-gh-3507-no-external-store]], @derekcollison, 2022-09-28; still true at 2.14.6, where
`storage` takes exactly those two values — [[stream-and-consumer-config]]).

Durability is therefore bought inside NATS and nowhere else: `--replicas` for a quorum
([[replicas]]), a mirror or a source for a second copy ([[mirrors-and-sources]]), a snapshot for an
offline one ([[backup-and-restore-jetstream]]). A design that assumed the data would also be sitting
in a database the rest of the estate can query needs [[direct-get]] or a republish into something
else — [[subject-transforms]] — not a storage option.


### And there is no tier below them either

The question that follows "memory or file" is whether old data can move somewhere cheaper, and the
answer is no — with a date on it. "Currently, tiered storage support is **not built-in as an option to
a stream's retention policy**" (2023-01-08); "**We have it planned but no schedule yet** on when we
will do this work as of yet" (@derekcollison, **2023-02-16**), in the thread opened to ask exactly
that. Asked again in 2024-10-31 and 2024-12-07 against Kafka's and Pulsar's tiered storage, the
maintainer's reply was a question about requirements and there has been **no further maintainer
comment**; the thread is still open, with no chosen answer, on 2026-09-04 (source:
[[s-gh-3871-tiered-storage-planned]]). The most-upvoted idea in the repository — 42 votes for
offloading to S3 in a queryable format — has **no maintainer comment at all** (source:
[[s-gh-6478-s3-offload-and-query]]).

So a stream's data lives where its `store_dir` is, for as long as its limits keep it. The two shapes
that exist instead are an **archiving consumer** (a client that reads the stream and writes elsewhere,
which is the maintainers' own suggestion) and **sharding by time** — a stream per period, closed when
the period ends. Both are on [[event-sourcing-on-jetstream]], which is where this decision usually
gets made.


## How many streams, and what a second one costs

The default is **one stream with many subjects and many filtered consumers**, and the maintainers say
so plainly: "Many Consumers per single Stream is usually the simple and good pattern as a starting
point. **It's rarely a good idea to have stream per subject**" (source:
[[s-gh-6100-stream-per-subject-or-one]]). What makes it work is that filtering is indexed rather than
scanned ([[consumer]]); what makes the alternative expensive is Raft.

**What a replicated stream costs beyond its data.** "Each Stream, if replicated (3 or more replicas)
will have some overhead for maintaing its own RAFT group" (source:
[[s-gh-6100-stream-per-subject-or-one]]) — and the ceiling that follows from it, from a second
maintainer: "Each stream and consumer having replicas >1 has an associated raft group… A theoretical
upper may be **on the order of 100s of thousands of assets** could likely saturate the network and CPU
of the servers within a given cluster" (source: [[s-gh-3772-jetstream-as-an-event-store]]). That is the
same unit [[jetstream-slows-as-consumers-grow]] calls an **HA asset**, and it counts consumers as well
as streams — so "many small streams, one consumer each" spends the budget twice.

At `R1` neither statement applies: there is no Raft group, and the cost of a second stream is the
per-stream floor on disk and in memory rather than a group in the meta layer.

**The reason to split that both maintainers accept** is not performance but **policy**: "I would stick
to one stream, **unless you need different retention policies for some subjects** for example" (source:
[[s-gh-6100-stream-per-subject-or-one]]). Retention, replication, storage backend, placement and the
account a stream lives in are all per-stream, so a subject needing a different one of those needs its
own stream. A subject that only needs a different *reader* does not — that is a consumer.

The related but opposite question — one stream **per tenant** rather than per subject — is
[[account]]'s territory as much as this page's, and the public answers point the other way; it is bank
row 108 and phase G1's `stream-topology-design`.

### What a stream costs when it is empty, and what a thousand cost

The maintainers' "streams are cheap" has a floor, and it was measured on 2.14.6 (source:
[[s-nats-server-stream-topology-observed]], one laptop — a ratio, never a limit):

- **One empty file stream is 3 directories and 3 files** — `meta.inf` 516 B, `meta.sum` 16 B,
  `msgs/1.blk` 0 B — which is **8 KiB** of allocated blocks, and **~53–58 KiB of RSS**. Both stay
  linear: 1,000 streams are 8,000 KiB and 75.1 MiB, 10,000 are 80,000 KiB and 534.2 MiB.
- **Creating them is fast at `R1` and slow at `R3`**: 1,592/s for the first thousand (P50 **0.6 ms**),
  675/s for ten thousand — against **P50 107–112 ms** each for a replicated stream, because the cost is
  the Raft group and not the stream ([[meta-layer]]).
- **Having many streams does not slow the publish path into one of them**: 194,031 / 204,803 /
  209,442 / 192,309 msg/s into the same stream with 1 / 10 / 100 / 1,000 streams on the server.
- **The first message into a fresh stream costs ~4.4 ms.** 10,000 messages into 10,000 empty streams,
  one each, took 43.97 s; the same 10,000 messages into the same streams again took 0.36 s.
- **Spreading a volume over streams costs disk**: the same 100,000 × 128 B messages were 21,004 KiB
  over 1,000 streams against 16,708 KiB in one stream with a tenant token — **1.26×**, and the
  difference is per-stream block slack ([[filestore-layout]]).
- **Restart is where the count is felt.** 1,001 streams: **125 ms** to start JetStream. 10,000 empty
  streams: **5.4 s**. A node holding 1,000 `R3` streams: **18 s** to come back, and more than 10 s to
  shut down.

The design question these numbers serve — how many streams, and how many consumers on each — is
[[stream-topology-design]].


## What a stream is, if you are coming from Kafka

One sentence saves a whole architecture review: "Many people compare a Kafka topic with a NATS stream,
but this is not correct. It would be more accurate that **a single *partition* is comparable to a NATS
stream**, since it is the unit of total ordering and replication" (source:
[[s-gh-3772-jetstream-as-an-event-store]]). A multi-partition topic is emulated with deterministic
subject-token partitioning into several streams ([[subject-transforms]]) — which is also why
throughput comparisons against a whole Kafka topic are not comparisons against one stream.

The storage layer behind it, from the same maintainer: "NATS has it own custom storage layer that
supports both in-memory and file-based persistence. It combines a traditional append-only log style
structure for making writes fast, however it supports some traditional 'data store' kind of operations,
such as being able to get an individual message or mark a message for deletion" — with subject indexing
for server-side filtering ([[filestore-layout]]).


## Related

[[consumer]] · [[retention-policies]] · [[replicas]] · [[stream-placement]] · [[raft-in-nats]] ·
[[ack-and-redelivery]] · [[jetstream-sizing]] · [[jetstream-out-of-disk]] ·
[[stream-directories-disappear]] · [[stream-has-high-message-lag]] · [[stream-compression]] ·
[[maximum-messages-exceeded]] · [[account]] · [[key-value]] · [[object-store]] ·
[[subject-transforms]] · [[direct-get]] · [[mirrors-and-sources]] · [[publishing]] ·
[[backup-and-restore-jetstream]] · [[subject-permissions]] · [[js-api-subjects]] ·
[[jetstream-slows-as-consumers-grow]] · [[message-ttl]]

## Sources

[[s-docs-stream-config]] · [[s-docs-policies]] · [[s-docs-retention-policies]] ·
[[s-docs-surviving-node-loss]] · [[s-docs-replication-and-r3]] ·
[[s-docs-delivery-and-acknowledgment]] · [[s-synadia-jetstream-memory-patterns]] ·
[[s-docs-upgrade-to-2.12]] · [[s-relnotes-2.14.0]] · [[s-nats-server-constants-2.14.6]] ·
[[s-adr-35-filestore-compression]] ·
[[s-nats-server-snapshot-restore]]

[[s-nats-server-filestore-layout]] · [[s-docs-publishing]] · [[s-docs-advanced-publishing]] ·
[[s-docs-shaping-the-stream]] · [[s-docs-altering-stream-state]] · [[s-docs-subject-mapping]] ·
[[s-docs-reading-back]] · [[s-docs-kv-history-and-revisions]]

[[s-adr-1-jetstream-json-api]] · [[s-adr-8-key-value-store]] · [[s-adr-10-extended-purge]] ·
[[s-adr-20-object-store]] · [[s-adr-43-per-message-ttl]] · [[s-docs-accounts-and-multitenancy]] ·
[[s-docs-disaster-recovery]] · [[s-docs-get-direct]] · [[s-docs-mirrors-and-sources]] ·
[[s-docs-mirrors-as-dr]] · [[s-docs-sizing-and-resources]] · [[s-docs-stream-backup-restore]] ·
[[s-docs-upgrade-to-2.14]] · [[s-gh-5924-filestore-dirs-vanished]] ·
[[s-issue-4281-insufficient-storage]] · [[s-synadia-jetstream-anti-patterns]]

Version attribution for the behaviour flags: [[nats-server-2.11]], [[nats-server-2.12]],
[[nats-server-2.14]]. · [[s-adr-51-message-scheduler]] · [[s-docs-jetstream-headers]] · [[s-nats-server-message-schedules-observed]] · [[s-gh-7147-one-billion-cap]] · [[s-gh-7032-max-msgs-known-good]] · [[s-nats-server-filestore-recovery]] · [[s-gh-8333-high-cardinality-subjects]] · [[s-synadia-how-many-subjects]] · [[s-nats-server-stream-scale-observed]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-relnotes-2.15-preview]] · [[s-nats-server-stream-consumer-config]] · [[s-nats-server-config-mutability-observed]] · [[s-docs-concepts-jetstream]] · [[s-docs-core-nats-chapter]] · [[s-docs-jetstream-where-next]] · [[s-nats-server-core-or-jetstream-observed]] · [[s-gh-3507-no-external-store]] · [[s-gh-6100-stream-per-subject-or-one]] · [[s-gh-3772-jetstream-as-an-event-store]] · [[s-nats-server-stream-topology-observed]] · [[s-gh-3871-tiered-storage-planned]] · [[s-gh-6478-s3-offload-and-query]]
