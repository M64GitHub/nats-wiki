---
title: "$SYS subjects"
type: reference
area: [monitoring, security, core]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; the per-subject arrivals are in Version notes
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [system-account, "$SYS", "$SYS.REQ", events, monitoring, acl]
aliases: ["$SYS", "$SYS.REQ", "$SYS.REQ.SERVER", system subjects, system account subjects, system events, system requests]
sources: [s-nats-server-system-subjects, s-nats-server-system-subjects-observed, s-docs-system-monitor-reference, s-docs-system-advisories-and-metrics, s-docs-jetstream-api-index, s-docs-jetstream-advisories-reference, s-gh-5768-track-connected-clients, s-gh-5902-leafnode-connect-events, s-nats-server-kick-ldm-mqtt-session, s-nats-server-auth-and-tls, s-gh-7854-jwt-push-timeout, s-docs-accounts-and-multitenancy, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-nats-surveyor-metrics-observed]
created: 2026-09-03
updated: 2026-09-03
---

# `$SYS` subjects

Every subject a `nats-server` **answers on or publishes to in the system account**, read from
`server/events.go`, `server.go` and `accounts.go` at v2.14.6 and run on the binary. It covers
requests (`$SYS.REQ.*`), events (`$SYS.SERVER.*`, `$SYS.ACCOUNT.*`) and the internal forms, and says
for each whether an HTTP endpoint is its twin. It does **not** cover `$JS.API` ([[js-api-subjects]])
or `$JS.EVENT` ([[advisories]]); the HTTP endpoints' own query parameters and fields are on
[[monitoring-endpoints]]. A reference states values; the concept is [[account]].

## Server requests — `$SYS.REQ.SERVER.PING.<Z>` and `$SYS.REQ.SERVER.<id>.<Z>`

Every name below is subscribed twice: `PING.<Z>` reaches **every server** (one reply each, so ask
for as many replies as you have servers) and `<id>.<Z>` reaches one (`events.go:1343–1352`). The
body is JSON: the endpoint's own options under their **JSON-tag names** — `account`, `subscriptions`,
`consumers` … not the URL's `acc`, `subs` — plus the filter every request accepts, `EventFilterOptions`:
`server_name`, `cluster`, `host`, `exact_match`, `tags`, `domain` (`events.go:1979–1986`). The reply
is `{"server": ServerInfo, "data": …}` or `{"server", "data": null, "error": {"code", "description"}}`
(`ServerAPIResponse`, `:2125`), with two exceptions marked below.

| `<Z>` | answers with | HTTP twin | `nats server request …` |
|---|---|---|---|
| `VARZ` | `data`: the `/varz` object | `/varz` | `variables` |
| `CONNZ` | `data`: the `/connz` object; `offset` / `limit` in the body page it | `/connz` | `connections` |
| `SUBSZ` | `data`: the `/subsz` object | `/subsz` (alias `/subscriptionsz`) | `subscriptions` |
| `ROUTEZ` | `data` | `/routez` | `routes` |
| `GATEWAYZ` | `data` | `/gatewayz` | `gateways` |
| `LEAFZ` | `data` | `/leafz` | `leafnodes` |
| `ACCOUNTZ` | `data` | `/accountz` | `accounts` |
| `JSZ` | `data`: the `/jsz` object; on a server without JetStream `"data":null,"error":{"code":500,…}` | `/jsz` | `jetstream` |
| `HEALTHZ` | `data`: `{status, status_code, error, errors[]}` | `/healthz` | `jetstream-health` |
| `IPQUEUESZ` | `data` | `/ipqueuesz` | `ipqueue` |
| `RAFTZ` | `data` | `/raftz` | `raft` |
| `EXPVARZ` | `data`: the Go `expvar` page (`memstats`, `cmdline`) | `/debug/vars` | — |
| **`STATSZ`** | **`{"server", "statsz": ServerStats}`** — not `data` (`ServerStatsMsg`, `:150`) | **none — `/statsz` is 404** | — (used by `nats server ping`, `list`, `report`) |
| **`IDZ`** | **the bare `{"name", "host", "id"}`** (`ServerID`, `:239`, `:2252`) | **none — `/idz` is 404** | — |
| **`PROFILEZ`** | `data`: `{"profile": <gzip, base64>}`; body `{"name": "goroutine" \| "heap" \| "allocs" \| "cpu" …, "duration", "debug"}`; runs in its own goroutine because a CPU profile takes seconds (`:1318–1330`) | **none — `/profilez` is 404** | `profile` |

Two HTTP paths have **no request form**: `/stacksz` (a goroutine dump) and `/` (the landing page);
there is no `STACKSZ` (`:1268–1315`; a request to it gets no reply). The docs' monitor reference
lists `Statsz`, `Idz` and `Profilez` among fifteen "HTTP monitoring endpoints" reachable at
`http://localhost:8222/<z>` — on 2.14.6 those three return **404** and the docs omit `/stacksz` and
`/debug/vars` (docs issue #65; source: [[s-nats-server-system-subjects-observed]] §1–2,
[[s-docs-system-monitor-reference]]).

Beyond the `<Z>` family, per server only (`<id>` is the server id from `IDZ` or `/varz`):

| subject | body | does |
|---|---|---|
| `$SYS.REQ.SERVER.<id>.RELOAD` | empty | reloads the configuration by message — answered `{"server": {…}}`, logged `Reloaded server configuration (sha256:…)`; the same reload as `SIGHUP` ([[reload-server-config]]) |
| `$SYS.REQ.SERVER.<id>.KICK` | `{"cid": <n>}` (`KickClientReq`, `:3213`) | disconnects one client; `nats server request kick <cid> <id>` ([[evict-a-sick-server]]) |
| `$SYS.REQ.SERVER.<id>.LDM` | `{"cid": <n>}` | sends one client an `INFO` with `ldm: true`; whether it leaves is the client library's decision (source: [[s-nats-server-kick-ldm-mqtt-session]]) |
| `$SYS.REQ.SERVER.PING` | any | the legacy statsz ping — still answered, "use `$SYS.REQ.SERVER.PING.STATSZ` instead" (`:69`) |

`nats server request` has no `statsz` or `idz` subcommand; `nats req '$SYS.REQ.SERVER.PING.IDZ' '{}'
--replies 3` with the system user is the direct form ([[nats-cli]]).

## Account requests — `$SYS.REQ.ACCOUNT.<acc>.<Z>`, and what an ordinary user may ask

| subject | who may ask | answers with |
|---|---|---|
| `$SYS.REQ.ACCOUNT.<acc>.CONNZ` / `.SUBSZ` / `.LEAFZ` / `.JSZ` | the system account | the endpoint's object scoped to that account (`monAccSrvc`, `:1362–1430`) |
| `$SYS.REQ.ACCOUNT.<acc>.INFO` | the system account | the account's configuration and limits |
| `$SYS.REQ.ACCOUNT.<acc>.STATZ` | the system account | "essentially a duplicate of `CONNS` with an envelope identical to the others" (`:1414`) |
| `$SYS.REQ.ACCOUNT.PING.STATZ` | the system account | every server's `STATZ` for every account — the only account request with a `PING` form (`:1445`) |
| `$SYS.REQ.ACCOUNT.<acc>.CONNS` | servers, to each other | a server-to-server request when a server starts tracking an account (`accNumConnsReq`, `:233`); **no reply** to a client in 4 s on 2.14.6 |
| `$SYS.REQ.ACCOUNT.NSUBS` | internal | `{"acc", "subject", "queue"}`; **no reply** to a client in 3 s |
| `$SYS.DEBUG.SUBSCRIBERS` | the system account | a bare subscriber count (`:84`) |
| **`$SYS.REQ.USER.INFO`** | **any user** | `{"user", "account", "account_name"}` (`UserInfo`, `:1516`) — what `nats account info` asks; answered only by the local server since 2.11.7 |
| **`$SYS.REQ.ACCOUNT.PING.CONNZ`** and **`.STATZ`** | **any user** | the user's **own account's** `CONNZ` / `STATZ`: the system account exports them and every account imports them, mapped onto `$SYS.REQ.ACCOUNT.<own>.<Z>` (`:2385–2387`) |

An ordinary user asking anything else — `$SYS.REQ.SERVER.PING.VARZ`, another account's
`$SYS.REQ.ACCOUNT.<acc>.CONNZ` — gets `No responders are available` (source:
[[s-nats-server-system-subjects-observed]] §8). To reconcile "who is connected" after a missed event
(gh#5768): `PING.CONNZ` with `offset` / `limit` in the body, or wait for the 30-second `CONNS`
heartbeat below (source: [[s-gh-5768-track-connected-clients]]).

## Claims and authentication requests

What an account push and an auth callout travel on (moved here from [[js-api-subjects]]):

| subject | what it is | source |
|---|---|---|
| **`$SYS.REQ.CLAIMS.UPDATE`** | an **account push**. When nothing is subscribed here, the push fails with a bare `nats: timeout` and the server logs nothing | `events.go:46` |
| `$SYS.REQ.CLAIMS.LIST` | list the accounts the resolver holds | `events.go:45` |
| `$SYS.REQ.CLAIMS.DELETE` | delete an account JWT; needs `allow_delete: true` on the resolver; strips headers like `UPDATE` since 2.12.1 | `events.go:47` |
| `$SYS.REQ.CLAIMS.PACK` | resolver-to-resolver reconciliation | `events.go:44` |
| `$SYS.REQ.ACCOUNT.<id>.CLAIMS.LOOKUP` | the server fetching one account JWT | `events.go:43` |
| `$SYS.REQ.ACCOUNT.<id>.CLAIMS.UPDATE` | the per-account form of a push (`accUpdateEventSubjNew`); `$SYS.ACCOUNT.<id>.CLAIMS.UPDATE` is the old form | `events.go:55–56` |
| **`$SYS.REQ.USER.AUTH`** | the [[auth-callout]] hand-off; carries the client's credentials **in the clear** unless `xkey` is set | `auth_callout.go:30` (source: [[s-nats-server-auth-and-tls]]) |

Two permission facts follow: the temporary user a push uses is scoped to exactly `CLAIMS.LIST`,
`CLAIMS.UPDATE` and `CLAIMS.DELETE` plus `_INBOX.>` on the subscribe side (source:
[[s-gh-7854-jwt-push-timeout]]), so narrowing the system account's permissions can break pushes and
nothing else; and on the account where auth callout runs, **the server denies publishing to
`$SYS.REQ.USER.AUTH` for every user**, the auth service included. A narrow publish allow-list on an
ordinary user silently blanks `$SYS.REQ.USER.INFO`'s answer while `/accountz` keeps working
(source: [[s-docs-accounts-and-multitenancy]]; see [[account]]).

## Events the server publishes

All on the system account; a subscriber needs a system-account user. Schema types are the `type`
field of the body (`events.go:150–232`, `accounts.go:1443`).

| subject | type | when | body |
|---|---|---|---|
| `$SYS.ACCOUNT.<acc>.CONNECT` | `io.nats.server.advisory.v1.client_connect` | a client, **or a leaf node** (`"kind":"Leafnode"`), joins the account | `server`, `client` (`ClientInfo`: `start`, `host`, `id`, `acc`, `user`, `name`, `lang`, `ver`, `rtt`, `name_tag`, `kind`, `client_type`, `client_id` for MQTT, …) |
| `$SYS.ACCOUNT.<acc>.DISCONNECT` | `…client_disconnect` | it leaves | plus `sent`, `received` (`msgs`, `bytes`), `reason` (`Client Closed`, `Authentication Failure`, …) |
| **`$SYS.ACCOUNT.<acc>.SERVER.CONNS`** and `$SYS.SERVER.ACCOUNT.<acc>.CONNS` (compatibility) | `…account_connections` | **on every connect and disconnect, and every 30 s while the account has a connection** (`eventsHBInterval`, `:100`, `:2466`); never for `$G` (`:2543`) | `acc`, `name`, `conns`, `leafnodes`, `total_conns`, `num_subscriptions`, `sent`, `received` (with `gateways` / `routes` / `leafs`), `slow_consumers` — the same `id` on both subjects |
| `$SYS.SERVER.<id>.STATSZ` | — (`ServerStatsMsg`) | **every 10 s** (`statsHBInterval`, `:101`), from 250 ms doubling up after start; also the reply to `PING.STATSZ` | `server`, `statsz` (`ServerStats`: `mem`, `cores`, `cpu`, `connections`, `total_connections`, `active_accounts`, `subscriptions`, `sent`, `received`, `slow_consumers`, `stale_connections`, `stalled_clients`, `routes[]`, `gateways[]`, `active_servers`, `jetstream`, `gomemlimit`, `gomaxprocs`) |
| `$SYS.SERVER.<id>.LAMEDUCK` | — | the server enters lame duck (`:679`) | the server's `ServerInfo` and nothing else |
| `$SYS.SERVER.<id>.SHUTDOWN` | — | the server shuts down (`:689`) — the last message the send queue takes; **observed on a plain SIGTERM, not after a lame-duck drain with no clients** (`inbox/server-issues.md` SI-5) | `ServerInfo` |
| `$SYS.SERVER.<id>.CLIENT.AUTH.ERR` | `…client_disconnect` | a client fails authentication (`:2664`) | the disconnect body with `reason: "Authentication Failure"`, `acc: "$G"`; **a `$SYS.ACCOUNT.$G.DISCONNECT` accompanies it** |
| `$SYS.ACCOUNT.CLIENT.AUTH.ERR` | `…client_disconnect` | the same, delivered **into the origin account** "for account owners" (`:2723`) | as above |
| `$SYS.ACCOUNT.<acc>.LEAFNODE.CONNECT` | — | a leaf connects — **only when gateways are enabled** (`:2418`, "for internal use only"); there is **no `LEAFNODE.DISCONNECT`** | `{"server", "acc"}` |
| `$SYS.LATENCY.M2.<acc>` | — | the responder's half of a service-latency measurement, server to server (`:72`, `:2903`) | `ServiceLatency` |
| `$SYS.SERVER.<id>.OCSP.PEER.CONN.REJECT`, `.OCSP.PEER.LINK.INVALID` | `…ocsp_peer_reject`, `…ocsp_peer_link_invalid` | OCSP peer verification rejects a handshake or a chain link (`:182–207`) | `kind`, `peer`, `link`, `reason` |

**Service latency is not a `$SYS` event.** `io.nats.server.metric.v1.service_latency` is published on
the subject the export's `latency { subject: … }` names, **in the exporting account**
(`accounts.go:1496–1500`), with `status`, `description`, `requestor`, `responder`, `header`, `start`,
`service`, `system`, `total`. The docs' `$SYS.SERVER.METRIC.SERVICE.LATENCY` does not exist in the
server (docs issue #67).

The docs' account-connections page gives **`$SYS.ACCOUNT.{account}.CONNECTIONS`** and says the event
fires "when account connection limits are reached"; the server has no such subject, and the event is
the heartbeat above (docs issue #66; source: [[s-docs-system-advisories-and-metrics]],
[[s-nats-server-system-subjects-observed]] §3). The connect event's `timestamp` is UTC, the
disconnect event's carries the local offset — `accountConnectEvent` stamps `time.Now().UTC()`,
`accountDisconnectEvent` the `now` its caller passes (`:2551–2662`; observed; `inbox/server-issues.md` SI-4).

The leafnode question of gh#5902 — `LEAFNODE.CONNECT` seen on Synadia Cloud, never on a
docker-compose hub, the maintainer wondering whether "a single server vs a cluster" is the
difference — is the gateway condition: watch `$SYS.ACCOUNT.*.CONNECT` for `"kind":"Leafnode"`
instead, or the `leafnodes` count in `CONNS` (source: [[s-gh-5902-leafnode-connect-events]]; see
[[leafnode]]).

## The inbox and reply forms

`$SYS._INBOX.<server>.<x>` and `$SYS._INBOX_.<x>` (`:57`, `:73`) are the reply subjects the servers
use among themselves; a client's own requests use its ordinary `_INBOX.>`. `ServerInfo`
(`:249–266`) is the `server` object of every envelope and event: `name`, `host`, `id`, `cluster`,
`domain`, `ver`, `tags`, `metadata`, `feature_flags`, `jetstream`, `flags` (bit 1 JetStream, bit 2
binary stream snapshots, bit 4 account NRG), `seq`, `time`.

## Permissions

- **A monitoring user** needs publish on `$SYS.REQ.SERVER.PING.>` (and `$SYS.REQ.SERVER.*.>` for the
  per-server forms, `$SYS.REQ.ACCOUNT.>` for the account forms) and subscribe on `_INBOX.>`;
  events need subscribe on `$SYS.SERVER.>` and `$SYS.ACCOUNT.>`. [[nats-surveyor]] runs on exactly
  this: `PING.STATSZ`, `PING.JSZ` and the account forms.
- **An ordinary user** reaches `$SYS.REQ.USER.INFO` and its own `$SYS.REQ.ACCOUNT.PING.{CONNZ,STATZ}`
  and nothing else in `$SYS`, whatever its permissions say — the imports are the boundary.
- **Without a system-account user** none of this is reachable, and a config that declares its own
  `accounts` block without a `SYS` account has no such user ([[account]],
  [[unauthenticated-clients-still-connect]]).

## Cheat sheet

```
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.PING.IDZ'    '{}' --replies 3     # every server's name and id
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.PING.STATSZ' '{}' --replies 3     # the 10-second heartbeat body, on demand
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.<id>.CONNZ' '{"offset":0,"limit":100}'
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.<id>.RELOAD' ''                    # reload by message
nats --server nats://sys:sys@host:4222 sub '$SYS.ACCOUNT.*.SERVER.CONNS'                       # per-account connection counts, every 30 s
nats --server nats://sys:sys@host:4222 sub '$SYS.SERVER.*.CLIENT.AUTH.ERR'                     # every failed login
nats --server nats://app:app@host:4222 req '$SYS.REQ.USER.INFO' ''                             # what an ordinary user may ask
```

## How this was derived

- **Subjects, tables, structs and intervals**: `server/events.go` at tag v2.14.6 — the constants at
  lines 43–107, the `monSrvc` table at 1268–1315 and its double subscription at 1343–1352, the
  `monAccSrvc` table at 1362–1430, the imports at 2385–2387, the senders at 679–707, 2416–2548,
  2551–2780; `server/server.go` 3030–3044 and 3134–3162 for the HTTP mux; `server/accounts.go`
  1424–1502 for service latency — all quoted with line numbers in
  `raw/nats-server-src/system-subjects-v2.14.6.md` (source: [[s-nats-server-system-subjects]]). To
  regenerate at a new tag: re-read those ranges, then re-run `system-subjects-run.sh`.
- **The HTTP codes, the envelopes, the heartbeat intervals, the auth-error pair, the latency subject,
  reload, lame duck and shutdown, and the ordinary-user boundary**: run on the v2.14.6 binary on
  2026-09-03 — `raw/nats-server-src/system-subjects-observed-v2.14.6.md` (source:
  [[s-nats-server-system-subjects-observed]]).
- **The docs' side**: `raw/nats-docs/reference/system/` — the monitor tree
  ([[s-docs-system-monitor-reference]]) and the advisory and metric pages
  ([[s-docs-system-advisories-and-metrics]]); the `$JS.API` *System Account* column
  ([[s-docs-jetstream-api-index]]) and the JetStream advisory bodies
  ([[s-docs-jetstream-advisories-reference]]) were read in the same pass and live on
  [[js-api-subjects]] and [[advisories]].

## Version notes

- **2.10.0**: `$SYS.REQ.SERVER.<id>.RELOAD` (#4307), `.KICK` and `.LDM` (#4298; `KICK` reaches
  leafnode connections from 2.10.17, #5587), `$SYS.REQ.SERVER.PING.IDZ` (#3663),
  `$SYS.REQ.SERVER.<id>.PROFILEZ` (#3774; CPU profiles from 2.10.19, #5743), `$SYS.REQ.USER.INFO`
  (#3671). **2.10.16**: the `EXPVARZ` request (#5374 — the release body calls it "a `/expvarz`
  monitoring endpoint", but no HTTP path existed at that tag; `/expvarz` is 404 on 2.14.6).
  **2.10.21**: `STATSZ` every 10 s instead of 30 s (#5925). **2.10.26**: `RAFTZ` and `IPQUEUESZ`
  over the system account (#6439, #6476) (source: [[s-relnotes-2.10]]).
- **2.11.7**: `$SYS.REQ.USER.INFO` answered only by the local server (#7089). **2.11.11** and
  **2.12.2**: the HTTP `/debug/vars` path for `EXPVARZ` (#7469, "Added expvar `/debug/vars` endpoint
  to the monitoring port"; `ExpvarzPath` present in `server.go` at v2.11.11 and v2.12.2, absent at
  v2.11.10 and v2.12.1); 2.11.15 / 2.12.6 redact secrets from its command-line arguments (source:
  [[s-relnotes-2.11]], [[s-relnotes-2.12]]).
- **2.12**: the upgrade guide says the `$G` account now produces connect and disconnect events; no
  2.12 body mentions it. **2.12.1**: `$SYS.REQ.CLAIMS.DELETE` strips headers like `UPDATE` (#7413).
  **2.12.6**: `$SYS.REQ.USER.INFO` returns the account and user name tags (#7973) (source:
  [[s-relnotes-2.12]]).

## What surveyor makes of these requests

`nats-surveyor` v0.9.11 turns `$SYS.REQ.SERVER.PING.STATSZ` (and `JSZ`, `RAFTZ` on request) into 105
time series from one system-account connection — the per-server, per-route and per-account counters,
`ha_assets`, the meta group's replica state and Raft indices, and the stream and consumer series —
observed against the lab on 2026-09-03 and tabled on [[metrics]] (source:
[[s-nats-surveyor-metrics-observed]]).


## Related

[[monitoring-endpoints]] · [[advisories]] · [[js-api-subjects]] · [[account]] ·
[[reload-server-config]] · [[evict-a-sick-server]] · [[nats-surveyor]] · [[nats-cli]] · [[leafnode]]

## Sources

[[s-nats-server-system-subjects]] · [[s-nats-server-system-subjects-observed]] ·
[[s-docs-system-monitor-reference]] · [[s-docs-system-advisories-and-metrics]] ·
[[s-docs-jetstream-api-index]] · [[s-docs-jetstream-advisories-reference]] ·
[[s-gh-5768-track-connected-clients]] · [[s-gh-5902-leafnode-connect-events]] ·
[[s-nats-server-kick-ldm-mqtt-session]] · [[s-nats-server-auth-and-tls]] ·
[[s-gh-7854-jwt-push-timeout]] · [[s-docs-accounts-and-multitenancy]] · [[s-relnotes-2.10]] ·
[[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-nats-surveyor-metrics-observed]]
