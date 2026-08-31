---
title: Config keys
type: reference
area: [deploy, core, jetstream, security, topology]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [config, reload, restart-only, server_tags, jetstream]
aliases: [config, configuration, server config, config file, reload]
sources: [s-nats-server-jetstream-resources, s-nats-server-jetstream-log-warnings, s-docs-config-management, s-nats-server-lame-duck, s-docs-connection-limits-config, s-nats-server-constants-2.14.6, s-docs-sizing-and-resources, s-docs-placement, s-docs-upgrade-to-2.12, s-nats-server-auth-and-tls, s-docs-encryption-and-tls, s-docs-operator-mode, s-docs-auth-callout, s-nats-server-topology, s-docs-leaf-nodes, s-docs-super-clusters]
created: 2026-08-31
updated: 2026-08-31
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
`reloadable*` — for both, read the key's page before relying on a reload in production.

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

**`pool_size: 3`** is why a three-node cluster shows eight `/routez` entries per node rather than
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
(reloadable\*).

**`timeout` has two defaults, not one**: **2 seconds** when the listener has no TLS, and
**`tls_timeout + 1`** — 3 seconds at stock settings — when it does (`getDefaultAuthTimeout`,
`opts.go:6191–6199`). The reference states `1`, which is neither. It is also the auth callout
deadline. See [[defaults-and-limits]].

The `auth_callout { … }` sub-block is exactly five keys — `issuer`, `account`, `auth_users`, `xkey`,
`allowed_accounts` (`opts.go:394–407`); none is reloadable in a way this wiki has checked.

## Operator mode keys

Set together, and all **restart-only** in practice — a config reload cannot introduce or change a
trusted operator ([[reload-server-config]]).

| key | what it takes |
|---|---|
| `operator` | the operator **JWT**, not a bare key |
| `system_account` | the system account's public key or name — the nats resolver refuses to start without one |
| `resolver { type: full, dir, allow_delete, interval, limit }` | the account-JWT store; `full` is the only type `nats auth account push` can write to |
| `resolver_preload { <account-key>: <jwt> }` | bakes account JWTs into the config; in practice the system account only |

`no_auth_user` is **rejected alongside a trusted operator** — see [[account]] and [[operator-mode]].

## `websocket { … }` and `mqtt { … }`

`websocket.port` and `websocket.no_tls` are **restart-only**; there is **no default WebSocket port**.
`mqtt.port` defaults to **`1883`** (restart-only), `mqtt.ack_wait` to **`30s`** and
`mqtt.max_ack_pending` to **`100`** (both reloadable\*). Note that MQTT has its **own**
`ack_wait` and `max_ack_pending`, unrelated to a JetStream [[consumer]]'s.

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

## The three listener ports have no default

**Corrected 2026-08-31.** The generated reference gives `cluster.port` `6222`, `gateway.port` `7222`
and `leafnodes.port` `7422` as **defaults**, and this page repeated `6222` above. The server applies
none of them; what it does instead differs per key
(source: [[s-nats-server-topology]], reproduced on v2.14.5):

| key | reference says | what an omitted value actually does |
|---|---|---|
| `cluster.port` | `6222` | **no route listener**, silently |
| `leafnodes.port` | `7422` | **no leafnode listener**, silently — a `leafnodes { }` block that does nothing |
| `gateway.port` | `7222` | **the server refuses to start**: `gateway %q has no port specified (select -1 for random port)` |

`DEFAULT_LEAFNODE_PORT = 7422` does exist (`const.go:206`) and is used in exactly one place: filling
in a missing port on a **remote's** URL (`opts.go:6096`). The `host` defaults (`0.0.0.0`) are real,
but only apply once a port is set (`opts.go:6072–6074`, `6140–6142`).

Recorded as `inbox/docs-issues.md` #23. Write the port on all three blocks, every time.

## Two option checks `nats-server -t` will not catch

`-t` parses the file; it does not run `validateOptions`, which happens inside `NewServer`
(`server.go:729`). Both of these pass the dry run and then stop the server on start:

- **A composed server needs a system account.** A server with both a `leafnodes { listen }` and a
  `gateway {}` block fails with `leaf nodes and gateways (both being defined) require a system
  account to also be configured` (`leafnode.go:346–349`) unless `system_account` is set. The docs'
  own composed example omits it — `inbox/docs-issues.md` #24.
- **`gateway.name` must equal `cluster.name`** — a *conflicting* pair is
  `cluster name conflicts between cluster and gateway definitions` (`errors.go:192`). An **unset**
  `cluster.name` is instead **adopted from `gateway.name`** (`server.go:1118–1124`), the same shape
  as the route-side adoption in `inbox/docs-issues.md` #11.

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


## Related

[[defaults-and-limits]] · [[jetstream-sizing]] · [[replicas]] · [[stream-placement]] ·
[[monitoring-endpoints]] · [[js-api]] · [[slow-consumer-detected]] · [[nats-server-2.12]] ·
[[tls-in-nats]] · [[account]] · [[operator-mode]] · [[auth-callout]] · [[subject-permissions]]

## Sources

[[s-docs-connection-limits-config]] · [[s-nats-server-constants-2.14.6]] ·
[[s-docs-sizing-and-resources]] · [[s-docs-placement]] · [[s-docs-upgrade-to-2.12]] ·
[[s-docs-replication-and-r3]] · [[s-nats-server-auth-and-tls]] · [[s-docs-encryption-and-tls]] ·
[[s-docs-operator-mode]] · [[s-docs-auth-callout]] · [[s-nats-server-jetstream-resources]] ·
[[s-nats-server-jetstream-log-warnings]] · [[s-nats-server-topology]] · [[s-docs-leaf-nodes]] · [[s-docs-super-clusters]]
