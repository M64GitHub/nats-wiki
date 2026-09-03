---
title: "nats-server v2.14.6 — the $SYS subjects, from the source"
type: summary
area: [monitoring, core, security]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/system-subjects-v2.14.6.md
author: nats-io/nats-server maintainers
article: "server/events.go, server.go, jetstream_events.go, accounts.go at tag v2.14.6 — the subject constants, the request tables, the event bodies, the HTTP mux"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [system-account, "$SYS", events, monitoring, source]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — the `$SYS` subjects, from the source

Read for [[system-subjects]]: every subject the server subscribes to or publishes on in the system
account, with the request options, the event bodies and the HTTP mux beside them, so the reference
page can say which names are requests, which are events, which have an HTTP twin and which do not.
The behavioural half is [[s-nats-server-system-subjects-observed]].

## Key claims

**The constants** (`events.go:43–96`). Requests: `$SYS.REQ.SERVER.PING.<Z>` and
`$SYS.REQ.SERVER.<id>.<Z>` (`serverPingReqSubj`, `serverDirectReqSubj`), `$SYS.REQ.SERVER.PING` (the
legacy statsz ping, "use `$SYS.REQ.SERVER.PING.STATSZ` instead"), `$SYS.REQ.SERVER.<id>.RELOAD` /
`.KICK` / `.LDM`, `$SYS.REQ.ACCOUNT.<acc>.<Z>` (`accDirectReqSubj`), `$SYS.REQ.ACCOUNT.PING.<Z>`
("only used for STATZ and CONNZ import from system account"), `$SYS.REQ.ACCOUNT.<acc>.CLAIMS.LOOKUP`,
`$SYS.REQ.CLAIMS.PACK` / `.LIST` / `.UPDATE` / `.DELETE`, `$SYS.REQ.USER.INFO` and
`$SYS.REQ.USER.<acc>.INFO`, `$SYS.REQ.ACCOUNT.NSUBS`, `$SYS.DEBUG.SUBSCRIBERS`. Events:
`$SYS.ACCOUNT.<acc>.CONNECT` / `.DISCONNECT`, **`$SYS.ACCOUNT.<acc>.SERVER.CONNS`** and the
compatibility form `$SYS.SERVER.ACCOUNT.<acc>.CONNS` ("kept for backward compatibility"),
`$SYS.ACCOUNT.<acc>.LEAFNODE.CONNECT` ("for internal use only"), `$SYS.SERVER.<id>.STATSZ`,
`.LAMEDUCK`, `.SHUTDOWN`, `.CLIENT.AUTH.ERR`, `$SYS.ACCOUNT.CLIENT.AUTH.ERR`, `$SYS.LATENCY.M2.<acc>`,
`$SYS.SERVER.<id>.OCSP.PEER.CONN.REJECT` / `.OCSP.PEER.LINK.INVALID`, and the inboxes
`$SYS._INBOX.<id>.<x>` and `$SYS._INBOX_.<x>`. **There is no `$SYS.ACCOUNT.<acc>.CONNECTIONS`**, the
subject `reference/system/advisory.md` documents, and no `$SYS.SERVER.METRIC.>` anywhere in
`events.go` or `accounts.go`.

**The three intervals** (`:100–107`): `eventsHBInterval = 30 * time.Second` (the account-connections
heartbeat), `statsHBInterval = 10 * time.Second` (the `STATSZ` heartbeat), `statszRateLimit = 1s`.

**The fifteen `<Z>` names** (`monSrvc`, `:1268–1315`): `IDZ`, `STATSZ`, `VARZ`, `SUBSZ`, `CONNZ`,
`ROUTEZ`, `GATEWAYZ`, `LEAFZ`, `ACCOUNTZ`, `JSZ`, `HEALTHZ`, `PROFILEZ`, `EXPVARZ`, `IPQUEUESZ`,
`RAFTZ` — each subscribed as both `$SYS.REQ.SERVER.<id>.<Z>` and `$SYS.REQ.SERVER.PING.<Z>`
(`:1343–1352`). `PROFILEZ` runs in its own goroutine "because CPU profiling … could take several
seconds". No `STACKSZ`.

**The HTTP mux** (`server.go:3030–3044`, `:3134–3162`): `/`, `/varz`, `/connz`, `/routez`,
`/gatewayz`, `/leafz`, `/subsz` and the alias `/subscriptionsz`, `/stacksz`, `/accountz`,
`/accstatz`, `/jsz`, `/healthz`, `/ipqueuesz`, `/raftz`, `/debug/vars` (`ExpvarzPath`). **No
`/statsz`, `/idz` or `/profilez`**; `/stacksz` has no request form; `EXPVARZ` is the request form of
`/debug/vars`.

**The per-account table** (`monAccSrvc`, `:1362–1430`): `SUBSZ`, `CONNZ`, `LEAFZ`, `JSZ`, `INFO`,
`STATZ` ("essentially a duplicate of CONNS with an envelope identical to the others"), `CONNS`
(`connsRequest`, a server-to-server request answered only when the account has local connections).
`$SYS.REQ.ACCOUNT.PING.STATZ` is the one account request with a PING form (`:1445`). Every account
gets two service imports from the system account — `$SYS.REQ.ACCOUNT.PING.CONNZ` and `.STATZ`
mapped to that account's own `$SYS.REQ.ACCOUNT.<acc>.<Z>` (`:2385–2387`) — which is how an ordinary
user can ask about its own account and nothing else.

**Request bodies** (`:1979–2081`): every `<Z>` request takes `EventFilterOptions` — `server_name`,
`cluster`, `host`, `exact_match`, `tags`, `domain` — plus the endpoint's own options struct
(`ConnzOptions`, `JSzOptions`, …) with the **JSON-tag names**, which is why the request form takes
`account` where the URL takes `acc` (docs issue #48).

**Response envelopes**: `ServerAPIResponse` `{"server": ServerInfo, "data": …, "error": ApiError}`
(`:2125`); `STATSZ` answers with `ServerStatsMsg` `{"server", "statsz"}` (`:150`, `:2223`); `IDZ`
answers with the bare `ServerID` `{"name", "host", "id"}` (`:239`, `:2252`). `ServerInfo` (`:249`)
carries `name`, `host`, `id`, `cluster`, `domain`, `ver`, `tags`, `metadata`, `feature_flags`,
`jetstream`, `flags` (`JetStreamEnabled`, `BinaryStreamSnapshot`, `AccountNRG`), `seq`, `time`.

**Event bodies**: `ConnectEventMsg` (`client_connect`: `server`, `client`), `DisconnectEventMsg`
(`client_disconnect`: plus `sent`, `received`, `reason`), `AccountNumConns` (`account_connections`:
`acc`, `name`, `conns`, `leafnodes`, `total_conns`, `num_subscriptions`, `sent`, `received`,
`slow_consumers`) — "sent from a server that is tracking a given account when the number of
connections changes. It will also HB updates in the absence of any changes" (`:207–209`); the timer
is armed in `sendAccConnsUpdate` (`:2466`) and cleared when `TotalConns == 0`; `accConnsUpdate`
returns early for `$G` (`:2543`) and sends both subjects (`:2545`). `ClientInfo` (`:309`) is the
`client` object: `start`, `host`, `id`, `acc`, `svc`, `user`, `name`, `lang`, `ver`, `rtt`,
`server`, `cluster`, `alts`, `stop`, `jwt`, `issuer_key`, `name_tag`, `tags`, `kind`, `client_type`,
`client_id` (MQTT), `nonce`, `reply`. `ServerStats` (`:367`) is the `statsz` object. The auth-error
events are `DisconnectEventMsg` bodies with `reason` (`:2664–2780`). `LAMEDUCK` and `SHUTDOWN` carry
an empty `ServerInfo` filled by the send queue (`:679–707`); `sendShutdownEvent` is the last message
the queue takes.

**Leafnode connect event** (`:2416–2421`): `sendLeafNodeConnect` returns without sending unless
`s.gateway.enabled` — "If we are not in operator mode, or do not have any gateways defined, this
should also be a no-op."

**Service latency** (`accounts.go:1424–1502`): `ServiceLatency` (`io.nats.server.metric.v1.service_latency`;
`status`, `description`, `requestor`, `responder`, `header`, `start`, `service`, `system`, `total`)
is published by `sendLatencyResult` on `si.latency.subject` — the subject the export's `latency {}`
block names — in the exporting account. The docs' field `error` is `description` in the struct.

**`jetstream_events.go`, whole**: the 24 advisory and metric types with their `io.nats.jetstream.*`
schema strings and JSON bodies — the authority for [[s-docs-jetstream-advisories-reference]]'s sweep.
`publishAdvisory` (`:20–43`) sends nothing when the account has no interest in the subject and no
gateway interest either.

## Practical takeaways

- A monitoring user needs to publish on `$SYS.REQ.SERVER.PING.>` (and `$SYS.REQ.SERVER.*.>` for the
  per-server forms) and subscribe on `_INBOX.>`; an ordinary user reaches only `$SYS.REQ.USER.INFO`
  and the two imported `$SYS.REQ.ACCOUNT.PING.{CONNZ,STATZ}`.
- `STATSZ` every 10 s, account `CONNS` every 30 s while an account has connections: both are
  heartbeats you can alert on the absence of.
- Three names — `statsz`, `idz`, `profilez` — exist only as requests; two paths — `/stacksz`,
  `/debug/vars` — exist only over HTTP.

## Notable quotes

- "kept for backward compatibility" — `accConnsEventSubjOld`, `events.go:59`.
- "atm. only used for STATZ and CONNZ import from system account" — `accPingReqSubj`, `:52`.
- "If we are not in operator mode, or do not have any gateways defined, this should also be a
  no-op." — `sendLeafNodeConnect`, `:2418`.

## Relevance to the wiki

The authority behind [[system-subjects]] and the correction of [[monitoring-endpoints]]; settles
gh#5902 ([[s-gh-5902-leafnode-connect-events]]) and the `CONNECTIONS` subject of docs issue #66.

## Questions it answers

Rows 54, 82, 161, 162, 163 (with the observed run).

## Pages touched

[[system-subjects]] · [[monitoring-endpoints]] · [[advisories]] · [[js-api-subjects]] · [[account]]
