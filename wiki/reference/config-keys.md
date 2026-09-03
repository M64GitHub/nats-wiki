---
title: Config keys
type: reference
area: [deploy, core, jetstream, security, topology]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14
verified-on: 2026-09-03
tags: [config, reload, restart-only, server_tags, jetstream]
aliases: [config, configuration, server config, config file, reload]
sources: [s-nats-server-jetstream-resources, s-nats-server-jetstream-log-warnings, s-docs-config-management, s-nats-server-lame-duck, s-docs-connection-limits-config, s-nats-server-constants-2.14.6, s-docs-sizing-and-resources, s-docs-placement, s-docs-upgrade-to-2.12, s-nats-server-auth-and-tls, s-docs-encryption-and-tls, s-docs-operator-mode, s-docs-auth-callout, s-nats-server-topology, s-docs-leaf-nodes, s-docs-super-clusters, s-docs-replication-and-r3, s-docs-accounts-and-multitenancy, s-docs-config-and-jwt-backup, s-docs-forming-a-cluster, s-docs-hardening, s-docs-rolling-upgrades, s-gh-4535-unauthenticated-connections, s-gh-5941-restrict-leafnode-subjects, s-gh-6070-lame-duck-under-systemd, s-issue-8322-dynamic-maxstore-shrinks, s-nats-server-route-cluster-formation, s-nats-server-systemd-units, s-nats-server-mqtt-websocket-observed, s-docs-websocket-tls-and-proxies, s-docs-mqtt-your-first-mqtt-client, s-docs-websocket-your-first-websocket-connection, s-docs-monitoring-profiling, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14]
created: 2026-08-31
updated: 2026-09-03
---

# Config keys

The server config keys that matter for **running** a server, by block, with defaults and **whether
a change takes effect on reload or needs a restart**. The complete generated set is **621 keys**
and lives in `inbox/config-keys-table.md` (the *Config keys* tab in the viewer); this page is the
curated subset.

Values here are as the docs state them; where the docs state nothing, the default is either absent
or read from the source and marked — see [[defaults-and-limits]]. **216 of the 621 keys state a
default** in the docs; the other 405 state none, which is why [[defaults-and-limits]] reads the
server source.

## Reload or restart

Of the 621 keys the docs mark:

| marking | count | meaning |
|---|---:|---|
| **reloadable** | 261 | takes effect on `nats-server --signal reload` |
| **reloadable\*** | 150 | reloadable, but **the key's own doc page carries caveats** on what the reload actually does |
| **restart-only** | 174 | requires a restart |
| *(unmarked)* | 36 | the docs say nothing — **do not assume either way** |

**The procedure is [[reload-server-config]]** — validate with `nats-server -c … -t`, send SIGHUP, and
read `Reloaded server configuration` in the log. The rule behind the table: a reload changes *policy*
(who connects, what they may do, how much they may store) but never *identity* (the addresses the
server and its cluster bind, or where JetStream keeps its data) — an identity change is a
[[upgrade-a-cluster]] (source: [[s-docs-config-management]]).

The asterisk is not decoration. `cluster.routes` is `reloadable*`, `tls.cert_file` is
`reloadable*` — for both, read the key's page before relying on a reload in production. For the
certificate pair the caveat resolves well: the server **re-reads `cert_file` and `key_file` on
reload**, and new handshakes present the new certificate while existing connections keep the old one
(source: [[s-docs-hardening]]; the procedure is [[rotate-tls-certificates]]).

**How the signal is actually sent.** Under the packaged unit it is `systemctl reload nats-server`,
wired as `ExecReload=/bin/kill -s HUP $MAINPID` (source: [[s-nats-server-systemd-units]]); a
restart-only change is a node-at-a-time rolling restart, not a reload
(sources: [[s-docs-rolling-upgrades]], [[s-gh-6070-lame-duck-under-systemd]]). Both are on
[[reload-server-config]] and [[upgrade-a-cluster]].

**A failed reload cannot break a running server.** The server validates the new config and, on a parse
or validation failure, keeps the old one — the reload is atomic. What the dry-run does *not* prove is
that the server could **start** from the file: a JetStream cluster missing `server_name` or `routes`
passes `-t` and still fails to boot (source: [[s-docs-config-management]]).

**Two traps this wiki has already hit:**

- **`max_payload` is reloadable but `max_pending` is not**, and `max_payload` must stay
  `≤ max_pending` or the server refuses to start. Raising the payload ceiling is therefore a
  two-stage change: restart to raise `max_pending`, then reload `max_payload`
  (source: [[s-docs-connection-limits-config]]).
- **The per-client `max_subscriptions` and the per-account `accounts.…max_subscriptions` are
  different keys with different reload behaviour.** The docs say so explicitly on the former's page.

**In operator mode, account limits do not come from this file at all.** `MaxStore`, `MaxStreams` and
the rest live in the account JWT the resolver holds; editing and pushing the JWT is the only way to
move them, and **a reload or restart will not** (source: [[s-docs-sizing-and-resources]]). See
[[jetstream-sizing]].

## Top level

| key | type | default | reload |
|---|---|---|---|
| `port` | integer | `4222` (source) | — |
| `host` | string | `0.0.0.0` (source) | — |
| `server_name` | string | generated if unset | — |
| **`server_tags`** | string / [string] | — | reloadable |
| `server_metadata` | { string: string } | — | reloadable — **2.12+** |
| `http_port` | integer | `8222` conventional; **off unless set** | — |
| `https_port` | integer | — | — |
| **`max_payload`** | string | **1 MB** (source) | **reloadable** |
| **`max_pending`** | string | **64 MB** (source) | **restart** |
| `max_connections` | string | **65,536** (source) | reloadable |
| `max_subscriptions` | string | unlimited (`0`) | restart |
| `max_control_line` | string | `4096` (source) | reloadable |
| **`write_deadline`** | duration | **`10s`** (source) | reloadable |
| `ping_interval` | string | `2m` (source) | reloadable |
| `ping_max` | integer | `2` (source) | reloadable |
| `debug` | boolean | — | reloadable |
| `trace` | boolean | — | reloadable |
| `logfile` | string | — | reloadable |
| **`lame_duck_duration`** | duration | **`2m`** (min `30s`) | **restart** |
| `lame_duck_grace_period` | duration | `10s` | **restart** |

**`debug` is reloadable**, which is what makes the diagnostic on
[[no-suitable-peers-for-placement]] usable on a running cluster.

**The two lame-duck keys are restart-only, and a service unit depends on them.** The shipped
systemd unit sets `TimeoutStopSec=150` — `lame_duck_duration` plus buffer — so raising one without the
other means systemd kills the drain partway ([[install-nats-server]]). Both are validated: `< 30s` is a
parse error, and a grace period not **strictly** lower than the duration stops the server at startup.
The duration governs **client disconnects only** — see [[upgrade-a-cluster]].

## `jetstream { … }`

| key | type | default | reload |
|---|---|---|---|
| `enabled` | boolean | `true` | reloadable\* |
| `store_dir` | string | `/tmp/nats/jetstream` | reloadable\* |
| **`max_memory_store`** | storage | **75% of RAM** (`256MB` only as a fallback) | reloadable\* |
| **`max_file_store`** | storage | **75% of available disk** (`1TB` only as a fallback) | reloadable\* |
| **`sync_interval`** | duration / string | **`2m`**; `always` syncs before every `PubAck` | **restart** |
| **`strict`** | boolean | **`true`** — since 2.12 invalid API requests are *rejected*, not just logged | restart |
| `domain` | string | — | restart |
| `unique_tag` | string | — | restart |
| `cipher` / `encryption_key` / `prev_encryption_key` | string | — | restart |
| **`max_buffered_msgs`** | integer | **`100000`** (docs say `10000`) | restart |
| `max_buffered_size` | storage | `128MB` | restart |
| **`max_outstanding_catchup`** | storage | **`64MB`** (docs say `32M`) | restart |
| `request_queue_limit` | integer | `10000` | restart |
| **`info_queue_limit`** | integer | **defaults to `request_queue_limit`**, so `10000` (docs say `100000`) | restart |
| `meta_compact` / `meta_compact_size` | integer / storage | — | reloadable |
| `meta_compact_sync` | boolean | `false` | reloadable |
| `limits` | block | — | restart |
| `tpm` | block | — | restart |

**Four of the values above were wrong in the docs and are corrected here from the server at
v2.14.6** (source: [[s-nats-server-jetstream-resources]], recorded as **docs issue #22**):
**The dynamic value is recomputed at every start, not remembered**, so a server whose disk has
filled comes back with a *smaller* `max_file_store` than it had — the streams it already holds can
exceed the new ceiling (source: [[s-issue-8322-dynamic-maxstore-shrinks]]; see
[[jetstream-out-of-disk]]).

`max_file_store`'s generated page calls `1TB` the default rather than the `statfs`-failure fallback;
`max_buffered_msgs` is `streamDefaultMaxQueueMsgs = 100_000` (`stream.go:441`);
`max_outstanding_catchup` is `defaultMaxTotalCatchupOutBytes = 64 * 1024 * 1024`
(`jetstream_cluster.go:11158`); and `info_queue_limit` has no default of its own — `opts.go:6183–6185`
sets it to `JetStreamRequestQueueLimit`. `max_buffered_size`, `request_queue_limit`, `sync_interval`,
`strict` and `store_dir` were checked at the same time and are correct.

**`max_file_store: 0` is not "unlimited".** An explicitly configured `0` is honoured as zero
(`jetstream.go:2760`), and no stream can then be created. Leaving the key **unset** is what gives you
the dynamic value — and that value shrinks at every restart before 2.14.6; see
[[jetstream-out-of-disk]].

**`request_queue_limit` and `info_queue_limit` are the two that lose requests silently.** When either
queue fills, the server **drains it entirely** — every queued JetStream API request is discarded with
no reply of any kind, which the client sees as a plain timeout
(`jetstream_api.go:876–890`, source: [[s-nats-server-jetstream-log-warnings]]). See [[nats-timeout]].

**`sync_interval` is restart-only**, so the durability/throughput trade on [[replicas]] cannot be
changed without a restart — which is the practical argument for the documented pattern of a
*separate cluster* tagged for `sync_interval: always`.

## `cluster { … }`

| key | type | default | reload |
|---|---|---|---|
| `name` | string | — | reloadable |
| `port` | integer | **none** — the reference says `6222`; see *The three listener ports have no default* below | **restart** |
| `listen` | string | — | **restart** — only a listen string with an unchanged host **and** port `-1` survives a reload |
| `routes` | [string] | — | reloadable\* — self-routes are ignored |
| `no_advertise` | boolean | — | reloadable |
| `pool_size` | integer | **`3`** | reloadable |
| `compression` | string / object | — | reloadable |
| `connect_backoff` | boolean | `false` | reloadable — **2.12+**; when `true`, 1s growing to 30s |

**`pool_size: 3`** — two peers × (3 pooled + 1 system) — is why a three-node cluster shows eight
`/routez` entries per node rather than
two — see [[monitoring-endpoints]]. The same arithmetic is what the `Routes` column of
`nats server list` counts — [[build-a-3-node-cluster]] reads it.

## `leafnodes { … }`

| key | type | reload |
|---|---|---|
| `port` | integer | — |
| `listen` | string | **restart** |
| `remotes` | block | reloadable — **remotes can be added and removed by reload since 2.14** |
| `no_advertise` | boolean | — |
| `compression` | string / object | reloadable — `on` means `s2_auto` |

Also `isolate_leafnode_interest` and per-remote `disabled: true`, both **2.12+**
(source: [[s-docs-upgrade-to-2.12]]).

**`leafnodes { authorization { users } }` is not the global `authorization.users` block.**
`parseLeafUsers` (`opts.go:3005–3064`) is "a trimmed down version of parseUsers" and accepts exactly
four fields — `user`, `pass`, `account`, `proxy_required`. **`permissions` there is a parse error**,
`unknown field "permissions"`, so a leaf connection cannot be restricted this way in config mode at
all; in operator mode the permissions travel in the leaf's user JWT instead
(source: [[s-gh-5941-restrict-leafnode-subjects]]). See [[subject-permissions]] and [[leafnode]].

**Leafnode compression is on by default.** Both the listener and every remote default to
**`s2_auto`**, not to the `accept` the generated reference publishes — `opts.go:6082–6089` and
`6099–6106` at v2.14.6, and a hub/leaf pair with no compression key reports
`"compression": "s2_uncompressed"` on `/leafz`, where two `accept` ends report `"off"`. `accept`
is the **cluster** default (`opts.go:6061–6070`). Recorded as `inbox/docs-issues.md` #27
(source: [[s-nats-server-defaults-sweep]]).

## `gateway { … }`

`name`, `listen`, `gateways` and `reject_unknown_cluster` (default `false`) are all
**restart-only**. Gateways are the least reload-friendly block in the server.

## `tls { … }`

One block per connection type, and they do not inherit — see [[tls-in-nats]].

| key | default | reload |
|---|---|---|
| `cert_file`, `key_file`, `ca_file` | — (`ca_file` defaults to the system trust store) | reloadable\* |
| `verify` | `false` | reloadable\* |
| `verify_and_map` | `false` | reloadable\* |
| `timeout` | **`2s`** — *the docs say `500ms`* | reloadable |
| `handshake_first` | `false`; also takes `"auto"` / `"auto_fallback"` (50ms) or a duration | reloadable |
| `insecure` | — | reloadable\* — outgoing connections only |

**Corrected 2026-08-31.** `tls.timeout`'s default is the compiled-in `TLS_TIMEOUT`, **2 seconds**
(`const.go:108`, applied at `opts.go:6021` and on every other listener). This page previously
repeated the reference's `500ms` and treated the two as separate values; they are the same value, and
`500ms` is wrong on all nine documented `tls.timeout` keys — `inbox/docs-issues.md` #19. The key
accepts a float in seconds or a duration string.

## `authorization { … }`

`token` (reloadable\*), `users` (reloadable), `auth_callout` (see [[auth-callout]]), and `timeout`
(reloadable\*). This block predates accounts and still works: its users land in an
**implicit `$G` account** unless one is named (source: [[s-gh-4535-unauthenticated-connections]]).

**`timeout` has two defaults, not one**: **2 seconds** when the listener has no TLS, and
**`tls_timeout + 1`** — 3 seconds at stock settings — when it does (`getDefaultAuthTimeout`,
`opts.go:6191–6199`). The reference states `1`, which is neither. It is also the auth callout
deadline. See [[defaults-and-limits]].

The `auth_callout { … }` sub-block is exactly five keys — `issuer`, `account`, `auth_users`, `xkey`,
`allowed_accounts` (`opts.go:394–407`); none is reloadable in a way this wiki has checked.

## Operator mode keys

Set together, and all **restart-only** in practice — a config reload cannot introduce or change a
trusted operator ([[reload-server-config]]). What each holds — the operator JWT the server trusts, the
`SYSTEM` account preload and the resolver directory the account JWTs land in — is
[[s-docs-config-and-jwt-backup|the backup set worth keeping]].

| key | what it takes |
|---|---|
| `operator` | the operator **JWT**, not a bare key |
| `system_account` | the system account's public key or name — the nats resolver refuses to start without one |
| `resolver { type: full, dir, allow_delete, interval, limit }` | the account-JWT store; `full` is the only type `nats auth account push` can write to |
| `resolver_preload { <account-key>: <jwt> }` | bakes account JWTs into the config; in practice the system account only |

`no_auth_user` is **rejected alongside a trusted operator** — see [[account]] and [[operator-mode]].

## `websocket { … }` and `mqtt { … }`

`websocket.port` and `websocket.no_tls` are **restart-only**; there is **no default WebSocket port**.
`mqtt.port` is **restart-only and has no default either** — the reference publishes `1883`, the
server applies nothing, and `mqtt { }` with no port starts no MQTT listener and logs nothing
(`mqtt.go:689–694`; observed on v2.14.6). `mqtt.ack_wait` does default to **`30s`**
(`mqttDefaultAckWait`, `mqtt.go:147`), but `mqtt.max_ack_pending` defaults to **`1024`**, not the
`100` the reference states (`mqttDefaultMaxAckPending`, `mqtt.go:151`, applied at `mqtt.go:3336`,
`5497` and `5633`); both are reloadable\*. Neither value is visible in `/varz`, which omits the
option because the server leaves it zero and fills it in at the use site. Recorded as
`inbox/docs-issues.md` #28 and #29. Note that MQTT has its **own** `ack_wait` and
`max_ack_pending`, unrelated to a JetStream [[consumer]]'s (source:
[[s-nats-server-defaults-sweep]]).

**Three more keys in these blocks that change whether the server starts at all**, all confirmed on
v2.14.6 (source: [[s-nats-server-mqtt-websocket-observed]]):

| key | behaviour |
|---|---|
| `websocket.tls` / `websocket.no_tls` | one of them is **required**. Neither, and the server exits 1 with `websocket requires TLS configuration` (source: [[s-docs-websocket-your-first-websocket-connection]]) |
| `mqtt.*` with no `jetstream {}` block | on a standalone server, exit 1 with `mqtt requires JetStream to be enabled if running in standalone mode`. The check does not apply once a `cluster`, `gateway` or `leafnode` block exists, and it applies **per account** too (source: [[s-docs-mqtt-your-first-mqtt-client]]) |
| `server_name` with `mqtt` + a `cluster`/`gateway` block | **required**; otherwise exit 1 with `mqtt requires server name to be explicitly set` |

**`mqtt.stream_replicas` has no default and is not simply 1.** Unset, the server derives the replica
count from **the number of addresses in its own `routes` list**, clamped to 1–3 — so a node in a
three-node cluster that lists its two peers creates MQTT state at `R=2` (observed). It announces the
result: `Creating MQTT streams/consumers with replicas N for account "…"`.

**Only certificate material in `websocket { … }` reloads.** `cert_file` and `key_file` take effect for
later connections; every other field in the block — `verify_and_map`, `pinned_certs`,
`allowed_origins`, the timeouts — is **rejected, and a rejected field aborts the whole reload**
(source: [[s-docs-websocket-tls-and-proxies]]). See [[reload-server-config]], [[mqtt]], [[websocket]].

## `prof_port` and `prof_block_rate`

Two profiling keys whose **reload behaviour differs**, which is the whole operational point (source:
[[s-docs-monitoring-profiling]]):

| key | reloadable | note |
|---|---|---|
| `prof_port` | **no** | turning it on is a restart, so a rolling restart mid-incident. It has **no authentication** and binds to the same `host` as the client port — default `0.0.0.0`, with no separate profiling host to narrow |
| `prof_block_rate` | **yes** | block profiling returns an empty profile until this is above zero; raise it with a SIGHUP, take the profile, drop it back. Block sampling slows the server |

Prefer `nats server request profile` over `$SYS.REQ.SERVER.PING.PROFILEZ`, which needs neither key and
no restart — [[monitoring-endpoints]], [[jetstream-sizing]].

## Account JetStream limits

`accounts.<name>.jetstream.max_memory`, `.max_file`, `.max_streams`, `.max_consumers` — all
reloadable\*, none with a documented default. **On an un-tiered account an R3 stream counts
`replicas × bytes` against the storage limit** ([[jetstream-sizing]]).

## How this was derived

- Every key, type, default and reload marking is from **`inbox/config-keys-table.md`**, generated by
  `python3 tools/build-config-table.py` from `raw/nats-docs/reference/config/` — the docs' 2.14
  tree, itself generated from the server. Re-run the script after a release and **diff the table**;
  that diff is the configuration change layer.
- The reload words map from the docs' own markers: `Hot Reloadable` → `reloadable`, `Yes*` →
  `reloadable*` (caveats on the key's page), `No` → `restart-only`, nothing → blank.
- Defaults marked **(source)** are not in the docs and were read from `nats-io/nats-server` at tag
  **v2.14.6** — see [[defaults-and-limits]] for the file and line of each.
- Version attributions (`server_metadata`, `connect_backoff`, leafnode remote reload) come from the
  upgrade guides, not the config table, which is unversioned.
- **Where the table and the server disagree, this page states the server** and says so on the line.
  That applies to `tls.timeout` and `authorization.timeout`, whose documented defaults are wrong on
  all 15 keys of those two families — `inbox/docs-issues.md` #19. The generated table still carries
  the docs' values, because it is a faithful rendering of the docs and is diffed against them.

## What is deliberately not here

The other ~560 keys. This page covers what an operator sets to run a server; the table covers
everything, is filterable in the viewer, and carries a `cited by` column that shows how much of the
surface the wiki actually explains.

## The listener ports have no default

**Corrected 2026-08-31.** The generated reference gives `cluster.port` `6222`, `gateway.port` `7222`,
`leafnodes.port` `7422` and `mqtt.port` `1883` as **defaults**, and this page repeated `6222` above.
The server applies none of them; what it does instead differs per key
(source: [[s-nats-server-topology]], [[s-nats-server-defaults-sweep]], reproduced on v2.14.6):

| key | reference says | what an omitted value actually does |
|---|---|---|
| `cluster.port` | `6222` | **no route listener**, silently |
| `leafnodes.port` | `7422` | **no leafnode listener**, silently — a `leafnodes { }` block that does nothing |
| `gateway.port` | `7222` | **the server refuses to start**: `gateway %q has no port specified (select -1 for random port)` |
| `mqtt.port` | `1883` | **no MQTT listener**, silently — `validateMQTTOptions` returns at `mqtt.go:692` |

`DEFAULT_LEAFNODE_PORT = 7422` does exist (`const.go:206`) and is used in exactly one place: filling
in a missing port on a **remote's** URL (`opts.go:6096`). The `host` defaults (`0.0.0.0`) are real,
but only apply once a port is set (`opts.go:6072–6074`, `6140–6142`).

`websocket.port` has no documented default and none in the server, which is the one page in the
family that is right.

Recorded as `inbox/docs-issues.md` #23 (the three topology listeners) and #29 (MQTT). Write the
port on every one of these blocks, every time.

## Three option checks `nats-server -t` will not catch

`-t` parses the file; it does not run `validateOptions`, which happens inside `NewServer`
(`server.go:729`). All three pass the dry run, and then stop the server on start or refuse the
reload:

- **A composed server needs a system account.** A server with both a `leafnodes { listen }` and a
  `gateway {}` block fails with `leaf nodes and gateways (both being defined) require a system
  account to also be configured` (`leafnode.go:346–349`) unless `system_account` is set. The docs'
  own composed example omits it — `inbox/docs-issues.md` #24.
- **`gateway.name` must equal `cluster.name`** — a *conflicting* pair is
  `cluster name conflicts between cluster and gateway definitions` (`errors.go:192`). An **unset**
  `cluster.name` is instead **adopted from `gateway.name`** (`server.go:1118–1124`), the same shape
  as the route-side adoption in `inbox/docs-issues.md` #11 — a server whose `cluster.name` is unset
  **silently adopts its peer's** over a route (source: [[s-nats-server-route-cluster-formation]]).
- **`no_auth_user` cannot be introduced or changed by a reload.** The reload fails with `config
  reload not supported for NoAuthUser` and **the old config stays active**, so an anonymous client
  keeps landing where it did; plan a restart. `-t` does not catch this either
  (source: [[s-docs-accounts-and-multitenancy]]). See [[account]].

See [[reload-server-config]] for what this means for a config-validation gate.

## More `leafnodes` and `gateway` keys

The tables above are the reload-relevant subset. The operator-facing keys and their defaults are on
[[leafnode]] and [[gateway]]; the two worth naming here because they change behaviour silently:

| key | default | note |
|---|---|---|
| `leafnodes.remotes[].deny_exports` | — | a **publish** deny; deny-only, no `allow` counterpart. Reload returns success and takes effect only on restart (2.11/2.12) |
| `leafnodes.remotes[].deny_imports` | — | a **subscribe** deny, same caveats |
| `leafnodes.remotes[].jetstream_cluster_migrate` | `true` | the reference gives **no description at all** — `inbox/docs-issues.md` #26 |
| `gateway.tls` | — | `verify` is **always enabled** on gateway TLS; only certificate material reloads |
| `no_fast_producer_stall` | `false` | reloadable. `true` drops to the slow consumer instead of stalling the producer — [[supercluster-slows-when-a-remote-subscriber-joins]] |


## Keys that arrived during 2.10

From the release bodies (source: [[s-relnotes-2.10]]); the full table is `inbox/config-keys-table.md`:

| key | since |
|---|---|
| `auth_callout { … }` | 2.10.0 |
| `cluster { compression }`, `leafnodes { compression }` (default `s2_auto`), leafnode `handshake_first` | 2.10.0 |
| `logfile_max_num` | 2.10.0 (#4548) |
| `jetstream { sync_interval }`, `sync: always` | 2.10.0 (#4483; the body misspells it `sync_internal`) |
| `prof_block_rate` | 2.10.2 (#4587) |
| `tls { handshake_first }` (clients); `mqtt { reject_qos2_publish, downgrade_qos2_subscribe }` as the config reference names them | 2.10.4 (#4642, #4705) |
| `tls { certs [ … ] }`; `no_auth_user` as an nkey | 2.10.8 (#4889, #4938) |
| `cluster { ping_interval }` | 2.10.10 (#5029) |
| `tls { min_version }`; several `trusted_operators` in a config file | 2.10.21 (#5904, #5896) |
| Windows `tls { ca_certs_match, cert_match_skip_invalid, cert_match_by: thumbprint }` | 2.10.23 (#5115, #6042, #6047) |
| `no_fast_producer_stall`; `leafnodes { remotes [ { first_info_timeout } ] }` | 2.10.26 (#6500, #5424) |
| `max_closed_clients` read from the config file at all | 2.10.26 (#6497 — a parser fix) |


## Keys that arrived during 2.11

From the release bodies (source: [[s-relnotes-2.11]]):

| key | since |
|---|---|
| `jetstream { max_buffered_msgs, max_buffered_size }` — ingest rate limiting, `429 Too Many Requests` | 2.11.0 (#5796) — the docs' default for `max_buffered_msgs` is wrong, `inbox/docs-issues.md` #22 |
| `jetstream { strict }` — strict decoding of API requests | 2.11.0 (#5858); default `true` from 2.12 |
| an account's `jetstream { cluster_traffic: system \| owner }` | 2.11.0 (#5466, #5947) — undocumented, #56 |
| `js_cluster_migrate` with a delay | 2.11.0 (#5903) |
| leafnode `handshake_first` as a duration | 2.11.0 (#5783) — the reference types it `boolean`, #55 |
| `nats-server -t` prints the config digest | 2.11.0 (#4325) |
| `default_sentinel` | 2.11.2 (#6577) |
| `trace_headers` | 2.11.2 (#6638) |
| `mqtt { js_api_timeout }` | 2.11.3 (#6833) |
| `jetstream { meta_compact, meta_compact_size }` | 2.11.11 (#7484, #7521) |
| `write_timeout` (`default` / `retry` / `close`) — top level, `cluster`, `gateway`, `leafnodes` | 2.11.11 (the body cites #7513, a cherry-pick PR) |
| `websocket { ping_interval }` | 2.11.12 (#7614; the body prints `ping_internal`) |


## Keys that arrived during 2.12

From the release bodies (source: [[s-relnotes-2.12]]):

| key | since |
|---|---|
| `server_metadata { }` | 2.12.0 (#6935) |
| `tls { allow_insecure_cipher_suites }`; `X25519MLKEM768` in `curve_preferences` | 2.12.0 (#7144, #7280) |
| `cluster { connect_backoff }`, `gateway { connect_backoff }` (the guide's name for #7042) | 2.12.0 |
| `leafnodes { isolate_leafnode_interest }`; `leafnodes { remotes [ { disabled } ] }` | 2.12.0 (#7238, #7054) |
| `proxies { trusted [ … ] }`; `authorization { proxy_required }` | 2.12.0 (#7153) — the block is undocumented, `inbox/docs-issues.md` #60 |
| stream `persist_mode: async` (opt-in async writes) | 2.12.0 (#7315) |
| `cluster { write_deadline }`, `leafnodes { write_deadline }`, `gateway { write_deadline }` | 2.12.1 (#7405) |
| `leafnodes { remotes [ { proxy { url, username, password, timeout } } ] }` | 2.12.1 (#7242) |
| `proxy_protocol` | 2.12.2 (#7456) |
| `jetstream { meta_compact, meta_compact_size }`; `write_timeout` | 2.12.2 (as 2.11.11) |
| `websocket { ping_interval }` | 2.12.3 (#7614) |
| `jetstream { meta_compact_sync }` | 2.12.5 (#7827, #7846) |
| `max_conns: 0` | 2.12.5 (#7877) |
| `max_mem_store` / `max_file_store` increase by reload | 2.12.7 (#8014) |
| **`jetstream { max_concurrent_io }`** | 2.12.14 / 2.14.4 (#8336) — undocumented, #59 |


## Keys that arrived during 2.14

| key | since |
|---|---|
| **`feature_flags { <name>: <bool> }`** — `js_ack_fc_v2`, `js_raft_delete_range` at v2.14.6 (`feature_flags.go:22–25`); an unknown name is silently `false`; a non-boolean value is `error parsing feature flag "<name>": expected bool` (`opts.go:1842–1862`). Remove before downgrading below 2.14. The docs page names no flag — `inbox/docs-issues.md` #62 | 2.14.0 (#7866) |
| `leafnodes { remotes [ { ignore_discovered_servers } ] }` | 2.14.0 (#8067) |
| `leafnodes { remotes }` — **reloadable** (add and remove remotes by `SIGHUP`) | 2.14.0 (#7937) |
| `jetstream { info_queue_limit }` — the separate, deprioritised queue for info and list requests; unset → `request_queue_limit` (10,000), not the docs' 100,000 (#22) | 2.14.0 (#7898) |
| `jetstream { max_concurrent_io }` — default 4096, bounds 4–8192 (#59) | 2.14.4 (#8336) |
| **`leafnodes { dial_timeout }`** and **`leafnodes { remotes [ { dial_timeout } ] }`** — durations; unset or `<= 0` → `1s` (`opts.go:2872–2873, 3211–3212`; `const.go:156`). Documented nowhere — #61 | 2.14.5 (#8427) |

(source: [[s-relnotes-2.14]]). The 2.15 preview adds `feature_flags { js_snapshot_sources }`
([[nats-server-2.15-preview]]).


## Related

[[defaults-and-limits]] · [[jetstream-sizing]] · [[replicas]] · [[stream-placement]] ·
[[monitoring-endpoints]] · [[js-api]] · [[slow-consumer-detected]] · [[nats-server-2.12]] ·
[[tls-in-nats]] · [[account]] · [[operator-mode]] · [[auth-callout]] · [[subject-permissions]]

## Sources

[[s-docs-connection-limits-config]] · [[s-nats-server-constants-2.14.6]] ·
[[s-docs-sizing-and-resources]] · [[s-docs-placement]] · [[s-docs-upgrade-to-2.12]] ·
[[s-docs-replication-and-r3]] · [[s-nats-server-auth-and-tls]] · [[s-docs-encryption-and-tls]] ·
[[s-docs-operator-mode]] · [[s-docs-auth-callout]] · [[s-nats-server-jetstream-resources]] ·
[[s-nats-server-jetstream-log-warnings]] · [[s-nats-server-topology]] · [[s-docs-leaf-nodes]] · [[s-docs-super-clusters]] ·
[[s-docs-config-management]] · [[s-nats-server-lame-duck]] ·
[[s-docs-accounts-and-multitenancy]] · [[s-docs-config-and-jwt-backup]] · [[s-docs-forming-a-cluster]] · [[s-docs-hardening]] · [[s-docs-rolling-upgrades]] · [[s-gh-4535-unauthenticated-connections]] · [[s-gh-5941-restrict-leafnode-subjects]] · [[s-gh-6070-lame-duck-under-systemd]] · [[s-issue-8322-dynamic-maxstore-shrinks]] · [[s-nats-server-route-cluster-formation]] · [[s-nats-server-systemd-units]] ·
[[s-nats-server-mqtt-websocket-observed]] · [[s-docs-websocket-tls-and-proxies]] ·
[[s-docs-mqtt-your-first-mqtt-client]] · [[s-docs-websocket-your-first-websocket-connection]] ·
[[s-docs-monitoring-profiling]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]]
