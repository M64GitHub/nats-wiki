---
title: Config keys
type: reference
area: [deploy, core, jetstream, security, topology]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [config, reload, restart-only, server_tags, jetstream]
aliases: [config, configuration, server config, config file, reload]
sources: [s-docs-connection-limits-config, s-nats-server-constants-2.14.6, s-docs-sizing-and-resources, s-docs-placement, s-docs-upgrade-to-2.12]
created: 2026-08-31
updated: 2026-08-31
---

# Config keys

The server config keys that matter for **running** a server, by block, with defaults and **whether
a change takes effect on reload or needs a restart**. The complete generated set is **621 keys**
and lives in `inbox/config-keys-table.md` (the *Config keys* tab in the viewer); this page is the
curated subset.

Values here are as the docs state them; where the docs state nothing, the default is either absent
or read from the source and marked — see [[defaults-and-limits]].

## Reload or restart

Of the 621 keys the docs mark:

| marking | count | meaning |
|---|---:|---|
| **reloadable** | 285 | takes effect on `nats-server --signal reload` |
| **reloadable\*** | 126 | reloadable, but **the key's own doc page carries caveats** on what the reload actually does |
| **restart-only** | 134 | requires a restart |
| *(unmarked)* | 76 | the docs say nothing — **do not assume either way** |

The asterisk is not decoration. `cluster.routes` is `reloadable*`, `tls.cert_file` is
`reloadable*` — for both, read the key's page before relying on a reload in production.

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

**`debug` is reloadable**, which is what makes the diagnostic on
[[no-suitable-peers-for-placement]] usable on a running cluster.

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
| `max_buffered_msgs` | integer | `10000` | restart |
| `max_buffered_size` | storage | `128MB` | restart |
| `max_outstanding_catchup` | storage | `32M` | restart |
| `request_queue_limit` | integer | `10000` | restart |
| `info_queue_limit` | integer | `100000` | restart |
| `meta_compact` / `meta_compact_size` | integer / storage | — | reloadable |
| `meta_compact_sync` | boolean | `false` | reloadable |
| `limits` | block | — | restart |
| `tpm` | block | — | restart |

**`sync_interval` is restart-only**, so the durability/throughput trade on [[replicas]] cannot be
changed without a restart — which is the practical argument for the documented pattern of a
*separate cluster* tagged for `sync_interval: always`.

## `cluster { … }`

| key | type | default | reload |
|---|---|---|---|
| `name` | string | — | reloadable |
| `listen` | string | — | **restart** — only a listen string with an unchanged host **and** port `-1` survives a reload |
| `routes` | [string] | — | reloadable\* — self-routes are ignored |
| `no_advertise` | boolean | — | reloadable |
| `pool_size` | integer | **`3`** | reloadable |
| `compression` | string / object | — | reloadable |
| `connect_backoff` | boolean | `false` | reloadable — **2.12+**; when `true`, 1s growing to 30s |

**`pool_size: 3`** is why a three-node cluster shows eight `/routez` entries per node rather than
two — see [[monitoring-endpoints]].

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

| key | default | reload |
|---|---|---|
| `cert_file`, `key_file`, `ca_file` | — (`ca_file` defaults to the system trust store) | reloadable\* |
| `verify` | `false` | reloadable\* |
| `timeout` | **`500ms`** | reloadable |
| `insecure` | — | reloadable\* — outgoing connections only |

`tls.timeout` (`500ms`) is the config key; the compiled-in `TLS_TIMEOUT` constant is `2s`
(`const.go:108`). They are different things and both are real — see [[defaults-and-limits]].

## `authorization { … }`

`token` (reloadable\*), `users` (reloadable), `timeout` (default **`1`** second, reloadable\*).

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

## What is deliberately not here

The other ~560 keys. This page covers what an operator sets to run a server; the table covers
everything, is filterable in the viewer, and carries a `cited by` column that shows how much of the
surface the wiki actually explains.

## Related

[[defaults-and-limits]] · [[jetstream-sizing]] · [[replicas]] · [[stream-placement]] ·
[[monitoring-endpoints]] · [[js-api]] · [[slow-consumer-detected]] · [[nats-server-2.12]]

## Sources

[[s-docs-connection-limits-config]] · [[s-nats-server-constants-2.14.6]] ·
[[s-docs-sizing-and-resources]] · [[s-docs-placement]] · [[s-docs-upgrade-to-2.12]] ·
[[s-docs-replication-and-r3]]
