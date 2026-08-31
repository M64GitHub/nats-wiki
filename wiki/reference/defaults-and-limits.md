---
title: Defaults and limits
type: reference
area: [core, jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [defaults, limits, max_payload, ack_wait, duplicate_window, sync_interval]
aliases: [defaults, limits, default values]
sources: [s-nats-server-jetstream-resources, s-nats-server-constants-2.14.6, s-docs-stream-config, s-docs-sizing-and-resources, s-docs-connection-limits-config, s-docs-acknowledgment, s-docs-pull-consumers, s-nats-server-auth-and-tls, s-docs-encryption-and-tls, s-docs-authentication-basics, s-nats-server-topology, s-nats-server-filestore-layout, s-docs-policies, s-docs-raft-and-leaders, s-docs-upgrade-to-2.12, s-synadia-jetstream-anti-patterns, s-docs-consumer-config, s-nats-server-jetstream-log-warnings, s-adr-31-direct-get, s-docs-auth-callout, s-gh-6070-lame-duck-under-systemd, s-issue-8322-dynamic-maxstore-shrinks, s-docs-advanced-publishing, s-docs-reading-back, s-adr-20-object-store, s-docs-object-store-chunking, s-docs-object-store-under-the-hood, s-nats-server-object-store-observed,
  s-docs-mqtt-qos-sessions-and-retained, s-docs-websocket-browsers-and-origins,
  s-nats-server-mqtt-websocket-observed, s-docs-mqtt-your-first-mqtt-client, s-docs-websocket-your-first-websocket-connection]
created: 2026-08-31
updated: 2026-08-31
---

# Defaults and limits

The values `nats-server` uses when you set nothing. **Every row is either read from the tagged
source at v2.14.6 with its file and line, or stated by a docs page that is cited.** Nothing here is
inferred, and a value neither source states is not on this page.

This page states values; it does not explain them — follow the link in the last column.

## Core server

From `server/const.go` at **v2.14.6** (source: [[s-nats-server-constants-2.14.6]]).

| setting | default | source | explained by |
|---|---|---|---|
| `port` | `4222` | `const.go:78` | — |
| `host` | `0.0.0.0` | `const.go:86` | — |
| `http_port` (monitoring) | `8222` — **off unless set** | `const.go:135` | [[monitoring-endpoints]] |
| `max_control_line` | `4096` | `const.go:90` | — |
| **`max_payload`** | **1 MB** | `const.go:94` | [[jetstream-sizing]] |
| `max_payload` warning threshold | **8 MB** | `const.go:99` | see *the 8 MB question* below |
| **`max_pending`** | **64 MB** | `const.go:102` | [[jetstream-sizing]] |
| **`max_connections`** | **65,536** (`64 * 1024`) | `const.go:105` | [[jetstream-sizing]] |
| `max_subscriptions` | **unlimited** (`0` means unlimited) | docs: [[s-docs-sizing-and-resources]], [[s-docs-connection-limits-config]] | — |
| TLS handshake timeout | `2s` | `const.go:108` | — |
| authorization timeout | `2s` | `const.go:117` | — |
| ping interval | `2m` | `const.go:120` | — |
| max pings outstanding | `2` | `const.go:123` | — |
| **`write_deadline`** | **`10s`** (`DEFAULT_FLUSH_DEADLINE`) | `const.go:132` | [[slow-consumer-detected]] |
| max closed clients retained | `10000` | `const.go:192` | — |
| **`lame_duck_duration`** | **`2m`** | `const.go:196`† | [[install-nats-server]] |
| `lame_duck_grace_period` | `10s` | `const.go:200`† | [[install-nats-server]] |

† Quoted from `raw/nats-server-src/const-lame-duck-v2.14.6.md`, the range
`constants-v2.14.6.md` stops short of; the docs agree (`reference/config.md` gives `2m` and `10s`).
Both defaults are **confirmed in the field as well as in the source** — a 2026 report running stock
`lame_duck_duration: 2m` and `lame_duck_grace_period: 10s` quotes them back
(source: [[s-gh-6070-lame-duck-under-systemd]]).

Both matter to a service unit: `TimeoutStopSec` must exceed `lame_duck_duration` or systemd kills the
drain half-finished (source: [[s-nats-server-systemd-units]], [[install-nats-server]]). Both are also
**enforced**: a duration under `30s` is rejected at parse time, and a grace period **≥** the duration
stops the server at startup. The duration is the window over which *client connections* are closed —
minus the grace period, and with the per-client interval capped at one second — and it does **not**
bound the Raft stepdown or JetStream shutdown that precede it (source:
[[s-nats-server-lame-duck]], [[upgrade-a-cluster]]).

### The 8 MB question

`max_payload` has **two** numbers and they are different things
(source: [[s-nats-server-constants-2.14.6]]):

- **1 MB** is the default.
- **64 MB** is the documented ceiling — "`max_payload` can be set up to 64MB"
  (source: [[s-docs-connection-limits-config]]).
- **8 MB is a warning threshold, not a limit.** Above it the server logs, at startup:

  ```
  Maximum payloads over 8.0MB are generally discouraged and could lead to poor performance
  ```

  and keeps running (`server/server.go:2342`). The constant's own comment adds: *"In the future, the
  server may enforce/reject max_payload above this value."*

**`max_payload` must be `≤ max_pending`, and the server refuses to start otherwise**
(source: [[s-docs-sizing-and-resources]]). With the defaults, 1 MB against 64 MB, there is a lot of
headroom — but `max_pending` **requires a restart** to change while `max_payload` is **hot
reloadable**, so raising the payload ceiling past 64 MB is a two-stage change.

**`max_pending` is also the ceiling on an unbounded Direct Get batch.** A batched
`$JS.API.DIRECT.GET` request has **no flow control**: the server sends up to `max_bytes`, and when
`max_bytes` is unset it uses `max_pending` — "the server default (currently 64MB)", which ADR-31
states independently of the constant above (source: [[s-adr-31-direct-get]]). So this key bounds a
read path as well as a connection's write queue; see [[direct-get]].

## JetStream — server

| setting | default | source | explained by |
|---|---|---|---|
| **`jetstream.sync_interval`** | **`2m`** | `filestore.go:333`; docs agree | [[replicas]] |
| `jetstream.max_memory_store` | **75% of *total* system RAM** (`sysMem / 4 * 3`), capped by `GOMEMLIMIT`; falls back to `256MB` only when system memory cannot be read | `jetstream.go:2769–2781`, `jetstream.go:2735` | [[jetstream-sizing]] |
| `jetstream.max_file_store` | **75% of the space *free* under `store_dir` at startup** (`Bavail * Bsize / 4 * 3`); falls back to `1TB` only when `statfs` fails or the platform cannot report | `disk_avail.go:31`, `jetstream.go:2733` | [[jetstream-sizing]] · [[jetstream-out-of-disk]] |
| `jetstream.store_dir` | `os.TempDir()/nats/jetstream` — `/tmp/nats/jetstream` on Linux, logged with `Temporary storage directory used, data could be lost on system reboot` | `jetstream.go:2746–2749` | [[stream-directories-disappear]] |
| `jetstream.max_buffered_msgs` | **`100000`** — the docs say `10000` | `stream.go:441` | [[config-keys]] |
| `jetstream.max_buffered_size` | `128MB` | `stream.go:442` | [[config-keys]] |
| `jetstream.max_outstanding_catchup` | **`64MB`** — the docs say `32M` | `jetstream_cluster.go:11158` | [[config-keys]] |
| `jetstream.request_queue_limit` | `10000` | `jetstream_api.go:367` | [[nats-timeout]] |
| `jetstream.info_queue_limit` | **whatever `request_queue_limit` is** (so `10000`) — the docs say `100000` | `opts.go:6183–6185` | [[nats-timeout]] |
| stream lag warning threshold | **10,000** accepted-but-unapplied proposals; not configurable | `jetstream_cluster.go:10213` | [[stream-has-high-message-lag]] |
| `jetstream.strict` | **`true` since 2.12** — invalid API requests are rejected, not just logged | [[s-docs-upgrade-to-2.12]] | [[js-api]] |
| filestore cache buffer expiration | `10s` | `filestore.go:331` | — |
| filestore idle FD close | `30s` | `filestore.go:335` | — |

**`256MB` and `1TB` are fallbacks, not defaults.** They apply only when the server cannot read the
system's memory or disk size. This is the most commonly mis-stated pair of numbers in NATS sizing —
and the generated `reference/config/jetstream/max_file_store.md` states the fallback as the default,
which is **docs issue #22**. Every value in this block is now read from the server at **v2.14.6**
rather than from a docs page (source: [[s-nats-server-jetstream-resources]]). The upstream issue
behind #22 is where the maintainers state the auto-sizing rule twice and an operator asks whether it
is documented anywhere (source: [[s-issue-8322-dynamic-maxstore-shrinks]]).

**The two 75% figures are not the same kind of number.** Memory is 75% of the machine's *total* RAM;
file storage is 75% of what is *free* under `store_dir` at the moment the server starts, so it falls
as JetStream fills the volume. Before 2.14.6 that made the limit shrink at every restart — see
[[jetstream-out-of-disk]].

### The filestore's own constants

Not configuration — these are compiled in, and they decide how much disk a stream really takes
(source: [[s-nats-server-filestore-layout]], all `nats-server 2.14.6`). See [[filestore-layout]].

| constant | value | source | explained by |
|---|---|---|---|
| record header + checksum per message (`emptyRecordLen`) | **30 B** (`msgHdrSize` 22 + `checksumSize` 8), plus `len(subject)`, plus `4 + len(headers)` when headers are present | `filestore.go:1119–1121`, `filestore.go:9821–9828` | [[filestore-layout]] · [[jetstream-sizing]] |
| delete tombstone | **30 B**, appended on every message delete | `filestore.go:7396–7398` | [[filestore-layout]] |
| memory-store per-message overhead | **16 B**, and no header-length field — a *different* formula | `memstore.go:2334–2336` | [[stream]] |
| default block size, `limits` retention | **8MB** (`defaultLargeBlockSize`) | `filestore.go:361–362`, `filestore.go:844–846` | [[filestore-layout]] |
| default block size, any other retention | **4MB** (`defaultMediumBlockSize`) | `filestore.go:363–364`, `filestore.go:847–849` | [[filestore-layout]] |
| block size when `max_msgs_per_subject` is set — **every KV bucket** | **4MB** (`defaultKVBlockSize`) | `stream.go:1422–1424` | [[key-value]] |
| minimum block size (`FileStoreMinBlkSize`) | **32,000 B** | `filestore.go:379–380` | [[filestore-layout]] |
| maximum block size (`FileStoreMaxBlkSize`, `maxBlockSize`) | **8MB** | `filestore.go:375–376`, `filestore.go:381–382` | [[filestore-layout]] |
| block size cap when encryption is on | **2MB** (`maximumEncryptedBlockSize`) | `filestore.go:371–372` | [[filestore-layout]] |
| inline compaction floor (`compactMinimum`) | **2MB**, *and* the block must be more than half dead | `filestore.go:377–378`, `filestore.go:6254–6256` | [[filestore-layout]] |
| the last message block | **never compacted**, on either path | `filestore.go:6151`, `filestore.go:8039` | [[filestore-layout]] |
| `index.db` write cadence | **2m plus up to 30s of jitter**, forced on purge and clean stop | `filestore.go:11904–11906` | [[filestore-layout]] |
| `index.db` cost | **`len(subject) + 4` per distinct subject**, plus ~8 per block | `filestore.go:12050–12056` | [[filestore-layout]] · [[key-value]] |
| high-cardinality cut-off (`highCardinalityThreshold`) | **1,000,000** subjects or interior deletes — above it the periodic `index.db` write is skipped | `filestore.go:388–390`, `filestore.go:12006–12009` | [[filestore-layout]] |
| per-block subject-state idle expiry (`defaultFssExpiration`) | `2m` | `filestore.go:337` | — |
| bad-record-length guard (`rlBadThresh`) | `32MB` | `filestore.go:383–384` | — |

**None of these is settable from a stream's config.** `nats stream info --json` reports no block
size, and there is no monitoring field for one.

## Stream configuration

Defaults from the generated `StreamConfig` schema unless a line reference is given
(source: [[s-docs-stream-config]]).

| field | default | range |
|---|---|---|
| `retention` | `limits` | `limits` \| `interest` \| `workqueue` |
| `storage` | `file` | `file` \| `memory` |
| `num_replicas` | `1` | **min 1, max 5** |
| `discard` | `old` | `old` \| `new` |
| `compression` | `none` | `none` \| `s2` |
| `max_msgs` | `-1` (unlimited) | |
| `max_msgs_per_subject` | `-1` | |
| `max_bytes` | `-1` | |
| `max_age` | `0` (unlimited) | **must be ≥ `100ms` if set** (`stream.go:1746`) |
| `max_msg_size` | `-1` | signed 32-bit, max `2147483647` |
| `max_consumers` | `-1` | |
| **`duplicate_window`** | schema says `0` = "use default"; **the server substitutes `2m`** | `stream.go:1658` |
| `persist_mode` | `""` (server default) | `""` \| `default` \| `async` |
| `no_ack`, `sealed`, `deny_delete`, `deny_purge`, `allow_rollup_hdrs`, `allow_direct`, `mirror_direct`, `allow_atomic`, `allow_batched`, `allow_msg_counter`, `allow_msg_schedules`, `allow_msg_ttl`, `discard_new_per_subject`, `pedantic` | all `false` | |
| `description` | — | max 4096 characters |
| `name` | — | pattern `^[^.*>]*$` |

**Batch-publish limits are stated by the docs and not confirmed here.** `learn/jetstream/advanced-publishing.md`
gives **1,000 messages per atomic batch**, **at most 50 batches in flight per stream**, and a
**ten-second** stall before a batch is abandoned, describing all three as "operator-configurable
server limits, not fixed protocol caps" (source: [[s-docs-advanced-publishing]]). No config key for
any of them appears in `inbox/config-keys-table.md`, and none has been checked against
`nats-server` — so this table records them as the docs' claim, not as verified defaults. The two
`429` error codes they surface are `10210` and `10211` ([[error-codes]]); the mechanism is
[[publishing]]. **(unverified)**

### When the 2-minute duplicate window applies

`StreamDefaultDuplicatesWindow` is used **only** when the stream sets no window of its own **and is
neither a mirror nor a source** — `if cfg.Duplicates == 0 && cfg.Mirror == nil &&
len(cfg.Sources) == 0` (`stream.go:1750`). It is then clamped down by the account or server
`Duplicates` limit if that is lower, and by `max_age` if `max_age` is smaller. **In pedantic mode
both clamps become errors instead of silent adjustments**
(source: [[s-nats-server-constants-2.14.6]]).

## Consumer configuration

`ConsumerConfig` defaults are **not readable from the docs** — the reference renders the config
object as a collapsed schema node (source: [[s-docs-consumer-config]]). These come from the source
at v2.14.6 (source: [[s-nats-server-constants-2.14.6]]) and are corroborated by the learn pages.

| field | CLI flag | default | source |
|---|---|---|---|
| **`ack_wait`** | `--wait` | **`30s`** — explicit-ack consumers only | `consumer.go:573` |
| **`max_deliver`** | `--max-deliver` | **`-1`** (unlimited) | `consumer.go:589–593` |
| **`max_ack_pending`** | `--max-pending` | **`1000`** — for explicit-ack consumers that set none | `consumer.go:580` |
| `inactive_threshold` (ephemerals) | | **`5s`** before a non-durable consumer is deleted | `consumer.go:576` |
| flow-control max pending | | `32 MB` | `consumer.go:578` |
| **`PriorityTimeout`** | | **`2m`** — grace period before the server picks a new pinned client | `consumer.go:582` |
| `ack_policy` | `--ack` | `explicit` in the docs' walkthrough | [[s-docs-acknowledgment]] |
| `deliver_policy` | `--deliver` | `all` | [[s-docs-policies]] |
| `replay_policy` | | `instant` | [[s-docs-policies]] |
| `priority_policy` | | `none` | [[s-docs-policies]] |
| pull `expires` | | **client-side ~30s**; `0` on the wire never times out | [[s-docs-pull-consumers]] |

In **pedantic mode**, a `max_deliver` below `-1` is an error rather than being corrected to `-1`.

## Cluster and RAFT

| behaviour | value | source |
|---|---|---|
| leader heartbeat | "about once a second" | [[s-docs-raft-and-leaders]] |
| election timer | **4–9 seconds** after the last heartbeat, staggered | [[s-docs-raft-and-leaders]] |
| quorum | `(N+1)/2` | [[s-docs-raft-and-leaders]] |
| `connect_backoff` (routes/gateways, 2.12+) | when `true`: **1s growing to 30s** | [[s-docs-upgrade-to-2.12]] |

## Authentication and TLS handshake budgets

Read from `server/const.go` and `server/opts.go` at **v2.14.6**
(source: [[s-nats-server-auth-and-tls]]). **The generated config reference states different values
for every key in this table** — see `inbox/docs-issues.md` #19.

| setting | default | source |
|---|---|---|
| `tls { timeout }` — client, cluster, leafnode, gateway, MQTT | **2s** | `TLS_TIMEOUT`, `const.go:108`; applied at `opts.go:6021`, `:6031`, `:6076`, `:6144`, `:6166` |
| `leafnodes { remotes: [ { tls { timeout } } ] }` | **2s** | `DEFAULT_LEAF_TLS_TIMEOUT`, `const.go:165`; `opts.go:3155` |
| `authorization { timeout }` — **no TLS on that listener** | **2s** | `AUTH_TIMEOUT`, `const.go:117` |
| `authorization { timeout }` — **TLS configured** | **`tls_timeout + 1`**, so 3s at stock settings | `getDefaultAuthTimeout`, `opts.go:6191–6199` |
| `tls { handshake_first }` fallback delay, when set to `"auto"` | **50ms** | `DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY`, `const.go:114` |

Two consequences worth carrying:

- **`authorization { timeout }` is also the auth callout deadline.** The server uses it both as the
  authorization request's expiry and as the wait for a reply (`auth_callout.go:371`, `:447`), so an
  auth service's latency budget is this key — 3 seconds on a TLS-enabled server, not the 2 the docs
  state. The docs page for the feature repeats the 2-second figure without the TLS case
  (source: [[s-docs-auth-callout]]). See [[auth-callout]].
- **`tls { timeout }` accepts a float in seconds *or* a duration string** (`opts.go:5222–5232`);
  `timeout: 2` and `timeout: "2s"` are the same value. The reference's type says `duration` only.

`websocket { tls { timeout } }` is documented but **has no corresponding server option**:
`WebsocketOpts` carries `HandshakeTimeout` for the whole websocket handshake instead.


## Topology — leafnodes and gateways

All read from `nats-server` v2.14.6 (source: [[s-nats-server-topology]]).

| key or behaviour | value | source |
|---|---|---|
| `cluster { port }` | **no default** — omitted means no route listener | `opts.go:6072` (host default is gated on the port) |
| `leafnodes { port }` | **no default** — omitted means no leafnode listener | `leafnode.go:328` |
| `gateway { port }` | **no default** — omitted is a **startup error** | `gateway.go:316–318` |
| `DEFAULT_LEAFNODE_PORT` | `7422` — used only to fill a missing port on a **remote's URL** | `const.go:206`, applied at `opts.go:6096` |
| `cluster`/`leafnodes`/`gateway` `host` | `0.0.0.0` (`DEFAULT_HOST`), applied only once a port is set | `opts.go:6072–6074`, `:6140–6142` |
| `leafnodes { remotes: [ { first_info_timeout } ] }` | **1s** (`DEFAULT_LEAFNODE_INFO_WAIT`) | `const.go:203` |
| leafnode reconnect interval | **1s** (`DEFAULT_LEAF_NODE_RECONNECT`) | `const.go:162` |
| `leafnodes`/`gateway` `write_deadline` | `10s` | `reference/config/leafnodes.md`, `gateway.md` |
| `gateway { connect_retries }` | `0` — no retry for a *discovered* gateway | `reference/config/gateway.md` |
| `gateway { reject_unknown_cluster }` | `false` | `reference/config/gateway.md` |
| gateway connect delay / max | **1s** / **30s** | `gateway.go:37–38` |
| gateway reconnect delay | **1s** | `gateway.go:39` |
| gateway PING interval cap | **15s**, or `ping_interval` if smaller | `gateway.go:58` |
| `leafnodes { min_version }` | must be ≥ **`2.8.0`** if set | `reference/config/leafnodes/min_version.md` |
| `leafnodes { compression }`, and each remote's | **`s2_auto`** — the reference says `accept` | `opts.go:6082–6089`, `6099–6106`; observed on `/leafz` |
| `cluster { compression }` | `accept` — here the reference is right | `opts.go:6061–6070` |
| `mqtt { port }` | **no default** — omitted means no MQTT listener, silently | `mqtt.go:689–694` |
| `mqtt { max_ack_pending }` | **1024** (`mqttDefaultMaxAckPending`) — the reference says `100` | `mqtt.go:151`, applied at `:3336`, `:5497`, `:5633` |
| `mqtt { ack_wait }` | **30s** (`mqttDefaultAckWait`) — the reference is right | `mqtt.go:147` |
| `leafnodes { isolate_leafnode_interest }` | `false`, since **2.12** | `reference/config/leafnodes/isolate_leafnode_interest.md` |

The four "no default" rows contradict the generated config reference, which states `6222`, `7422`,
`7222` and `1883` — `inbox/docs-issues.md` #23 and #29. The two compression rows are #27, and
`max_ack_pending` is #28 (source: [[s-nats-server-defaults-sweep]]). See [[config-keys]] and
[[leafnode]].

## Interop — MQTT and WebSocket

The listener defaults are in the table above. These are the behavioural limits the two protocols
impose, all confirmed on **2.14.6** unless marked otherwise (sources:
[[s-docs-mqtt-qos-sessions-and-retained]], [[s-docs-websocket-browsers-and-origins]],
[[s-nats-server-mqtt-websocket-observed]]).

| limit | value | note |
|---|---|---|
| MQTT protocol version | **v3.1.1 only** | a CONNECT at level 5 gets CONNACK return code **1** — observed |
| `mqtt { port }` / `websocket { port }` | **no default**, and no listener and **no log line** without one | sources: [[s-docs-mqtt-your-first-mqtt-client]], [[s-docs-websocket-your-first-websocket-connection]] |
| `mqtt { max_ack_pending }` per subscription | **1024**, range **0–65535** | **`0` means "use the default"**, not "none" |
| MQTT in-flight total per **session** | **65535** across all subscriptions | over it, the subscription is refused with `0x80` in the SUBACK |
| plain subscriptions per session at the default | **63** — the 64th is refused | observed exactly |
| `#` subscriptions per session at the default | **31** — the 32nd is refused | a `#` filter creates two NATS subscriptions and counts twice; observed exactly |
| `mqtt { stream_replicas }` | **derived from the number of addresses in the server's own `routes` list, clamped 1–3** | a 3-node cluster whose node lists 2 routes gets **R=2** — observed |
| MQTT client-ID flap suppression | **~1s** before the session is handed over again | docs only; not measured |
| characters refused in an MQTT topic | space, tab, LF, CR, FF, DEL | publishing **closes the connection**; subscribing returns `0x80` — observed |
| `allowed_origins` matching | **exact string** on scheme, host and port | **skipped entirely when no `Origin` header is present** — observed |
| WebSocket `user_cookie` / `pass_cookie` / `token_cookie` | since **2.11** | `jwt_cookie` has always existed |
| `websocket { ping_interval }` | since **2.12**; before that the server-wide ping interval applies | docs only |
| WebSocket under FIPS-140 | needs a build from **Go 1.26 or later** | earlier toolchains make the server refuse the listener |

**The five streams MQTT creates on its own**, lazily on the first MQTT connection — no source names
them, so these were read off the server (source: [[s-nats-server-mqtt-websocket-observed]]):

| stream | subjects | retention | discard | `max_msgs_per_subject` |
|---|---|---|---|---|
| `$MQTT_sess` | `$MQTT.sess.>` | limits | old | 1 |
| `$MQTT_msgs` | `$MQTT.msgs.>` | **interest** | old | -1 |
| `$MQTT_out` | `$MQTT.out.>` | **interest** | old | -1 |
| `$MQTT_qos2in` | `$MQTT.qos2.in.>` | limits | **new** | 1 |
| `$MQTT_rmsgs` | `$MQTT.rmsgs.>` | limits | old | 1 |

All five: `storage: file`, `max_age: 0`. What each QoS level costs is on [[mqtt]].

## Fast-producer stall

The budget a publisher is slowed by when one of its destinations cannot keep up — including a
gateway to a distant cluster (source: [[s-nats-server-topology]]).

| constant | value | source |
|---|---|---|
| `stallClientMinDuration` | **2ms** | `client.go:125` |
| `stallClientMaxDuration` | **5ms** — used once pending bytes reach the max | `client.go:126` |
| `stallTotalAllowed` | **10ms** per read-loop invocation | `client.go:127` |
| `no_fast_producer_stall` | `false` — `true` drops to the slow consumer instead | `reference/config/no_fast_producer_stall.md` |

Observable as `/varz` → `stalled_clients`, `/connz` → `stalls`, and the log line
`Producer was stalled for a total of %v` — [[monitoring-endpoints]],
[[supercluster-slows-when-a-remote-subscriber-joins]].


## Key-Value and Object Store

These are **client-side** defaults on constructs the server knows only as streams, so they appear in
no server constant and in no `nats-server` config key. They are here because they decide a stream's
message count and therefore its sizing.

| what | default | where it is stated | checked |
|---|---|---|---|
| object **chunk size** | **128 KiB** (`128 * 1024`) | ADR-20; `learn/object-store/chunking.md` states "128 KB" in prose | **observed**: a 3,145,728-byte file lands exactly 24 chunks, a 200 MiB object 1,600 |
| object **digest** algorithm | `SHA-256`, no alternative | ADR-20 | observed, stored as `SHA-256=<base64url>` |
| object bucket **name charset** | `A-Z a-z 0-9 - _` | ADR-20 (`restricted-term`) | observed: `.`, space and `>` each rejected client-side with `nats: invalid object-store name` |
| object bucket backing stream | `discard: new`, `allow_rollup_hdrs: true`, `allow_direct: true`, `max_age: 0`, `max_bytes: -1` | ADR-20; `learn/object-store/under-the-hood.md` | observed field-for-field on 2.14.6, plus `duplicate_window: 2m` and `max_msgs_per_subject: -1` |

(sources: [[s-adr-20-object-store]], [[s-docs-object-store-chunking]],
[[s-docs-object-store-under-the-hood]], [[s-nats-server-object-store-observed]] · [[s-docs-mqtt-qos-sessions-and-retained]] ·
[[s-docs-websocket-browsers-and-origins]] · [[s-nats-server-mqtt-websocket-observed]]; the concept pages
are [[object-store]] and [[key-value]].)

**The chunk size has a hard ceiling and no stated floor.** A chunk must fit in one message, so
`max_payload` (**1 MB** by default, above) bounds it — and on 2.14.6 a `--chunk-size` above
`max_payload` is rejected **by the client**, before anything is published. The docs advise against
tuning it at all.

## Guidance thresholds — not server limits

These are recommendations from Synadia, explicitly **not enforced by the server**, and the source
states neither the version they were measured against nor the method
(source: [[s-synadia-jetstream-anti-patterns]]).

| guidance | value |
|---|---|
| total consumers before instability becomes likely | **~100,000** |
| disjoint subject filters on one consumer | **~300** |
| CPU headroom above steady state | **20–30%** ([[s-docs-sizing-and-resources]]) |
| file descriptors per stream | **~2** ([[s-docs-sizing-and-resources]]) |
| `max_pending` relative to peak message size | **≥ 10×** ([[s-docs-sizing-and-resources]]) |

## How this was derived

- **Source values** were read from `nats-io/nats-server` at tag **v2.14.6**, files
  `server/const.go`, `server/consumer.go`, `server/stream.go`, `server/filestore.go` and
  `server/server.go`. The exact quoted line ranges are stored verbatim in
  `raw/nats-server-src/constants-v2.14.6.md`, so each row links to
  `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`.
  To regenerate: fetch those files at the new tag and re-read the constants.
- **Schema values** come from `raw/nats-docs/reference/jetstream/api/stream/create.md`, the
  generated `StreamConfig` reference in the docs' 2.14 tree.
- **Docs-only values** (the JetStream storage percentages, `max_subscriptions`, the CPU and FD rules
  of thumb) come from `raw/nats-docs/learn/deployment/sizing-and-resources.md` and
  `raw/nats-docs/reference/config/`.
- **The whole documented surface was swept once, mechanically**: `python3 tools/check-defaults.py`
  compares every default in `inbox/config-keys-table.md` with the option parser, the use sites, the
  flags and the constants at a tag, and writes `inbox/check-defaults-<tag>.md`. On v2.14.6: 175 of
  the 216 documented defaults agree, 15 disagree and 26 need a human. Re-run it after a release and
  diff the report; every disagreement is still verified by hand before it is stated here.
- **Object-store values** come from ADR-20 and `raw/nats-docs/learn/object-store/`, and each was
  re-checked on the running v2.14.6 binary — the runs are in
  `raw/nats-server-src/object-store-observed-v2.14.6.md`. They are client-side constants, so
  `tools/check-defaults.py` does not and cannot sweep them.
- **A value stated by neither is absent from this page**, not guessed.

## What is deliberately not here

- **Consumer `ConsumerConfig` fields with no named constant and no docs statement.** Only the ones
  above are established.
- **Account and tier limits** (`MaxMemory`, `MaxStore`, `MaxStreams`, `MaxConsumers`) — these have no
  universal default; they come from the account or its JWT. Read them live with
  `nats account info` ([[jetstream-sizing]]).
- **Per-block config keys** — the full 621-key table with type and reload behaviour is
  [[config-keys]] and `inbox/config-keys-table.md`.

## Related

[[config-keys]] · [[jetstream-sizing]] · [[stream]] · [[consumer]] · [[ack-and-redelivery]] ·
[[replicas]] · [[priority-groups]] · [[slow-consumer-detected]] · [[js-api]] ·
[[object-store]] · [[key-value]] · [[mqtt]] · [[websocket]]

## Sources

[[s-nats-server-constants-2.14.6]] · [[s-docs-stream-config]] · [[s-docs-sizing-and-resources]] ·
[[s-docs-connection-limits-config]] · [[s-docs-acknowledgment]] · [[s-docs-pull-consumers]] ·
[[s-docs-policies]] · [[s-docs-raft-and-leaders]] · [[s-docs-upgrade-to-2.12]] ·
[[s-synadia-jetstream-anti-patterns]] · [[s-docs-consumer-config]] · [[s-nats-server-auth-and-tls]] · [[s-docs-encryption-and-tls]] · [[s-docs-authentication-basics]] ·
[[s-nats-server-jetstream-resources]] · [[s-nats-server-jetstream-log-warnings]] · [[s-nats-server-topology]] ·
[[s-nats-server-filestore-layout]] ·
[[s-adr-31-direct-get]] · [[s-docs-auth-callout]] · [[s-gh-6070-lame-duck-under-systemd]] · [[s-issue-8322-dynamic-maxstore-shrinks]] ·
[[s-docs-advanced-publishing]] · [[s-docs-reading-back]] · [[s-adr-20-object-store]] ·
[[s-docs-object-store-chunking]] · [[s-docs-object-store-under-the-hood]] ·
[[s-nats-server-object-store-observed]] · [[s-docs-mqtt-qos-sessions-and-retained]] ·
[[s-docs-websocket-browsers-and-origins]] · [[s-nats-server-mqtt-websocket-observed]] ·
[[s-docs-mqtt-your-first-mqtt-client]] · [[s-docs-websocket-your-first-websocket-connection]]
