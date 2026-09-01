---
title: Stream
type: concept
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [stream, storage, limits, discard, persist_mode]
aliases: [streams, StreamConfig, stream config]
sources: [s-nats-server-snapshot-restore, s-docs-stream-config, s-docs-policies, s-docs-retention-policies, s-docs-surviving-node-loss, s-docs-replication-and-r3, s-synadia-jetstream-memory-patterns, s-docs-upgrade-to-2.12, s-relnotes-2.14.0, s-nats-server-constants-2.14.6, s-adr-35-filestore-compression, s-docs-delivery-and-acknowledgment, s-nats-server-filestore-layout, s-docs-publishing, s-docs-advanced-publishing, s-docs-shaping-the-stream, s-docs-altering-stream-state, s-docs-subject-mapping, s-docs-reading-back, s-docs-kv-history-and-revisions, s-adr-1-jetstream-json-api, s-adr-10-extended-purge, s-adr-20-object-store, s-adr-43-per-message-ttl, s-adr-8-key-value-store, s-docs-accounts-and-multitenancy, s-docs-disaster-recovery, s-docs-get-direct, s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-docs-sizing-and-resources, s-docs-stream-backup-restore, s-docs-upgrade-to-2.14, s-gh-5924-filestore-dirs-vanished, s-issue-4281-insufficient-storage, s-synadia-jetstream-anti-patterns]
created: 2026-08-31
updated: 2026-09-01
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
stream and move the data (source: [[s-docs-policies]]).

| policy | on a live stream |
|---|---|
| `storage` | **fixed** — `stream configuration update can not change storage type` |
| `persist_mode` | **fixed** |
| `retention` | `limits` ↔ `interest` allowed, and the switch re-applies to messages already stored; to or from `workqueue` refused with `stream configuration update can not change retention policy to/from workqueue` |
| `discard` | can change |
| `compression` | can change, but only takes effect after a server or leader restart |
| `mirror` | **fixed at creation** — "You can't point a mirror at a different upstream or change what it copies in place"; `sources`, by contrast, can be added, dropped or re-filtered by updating the stream (sources: [[s-docs-mirrors-and-sources]], [[s-docs-mirrors-as-dr]]) |
| `allow_msg_ttl` | can be **enabled** on an existing stream and **never disabled**; setting it (or `subject_delete_marker_ttl`) requires stream API level `1`, and `subject_delete_marker_ttl` may not be set on a mirror at all (source: [[s-adr-43-per-message-ttl]], 2.11) |

`deny_delete` and `deny_purge` cannot be changed once set to `true`, and a `sealed` stream cannot
be unsealed (source: [[s-docs-stream-config]]).

Recreating a stream means moving the data. A [[mirrors-and-sources|mirror]] can copy the messages
across, but a mirror is read-only and turning it into a publishable replacement takes further steps
(source: [[s-docs-policies]]).

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
[[nats-server-2.14]].
