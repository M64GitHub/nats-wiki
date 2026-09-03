---
title: "nats-server v2.14.6 — the $SYS subjects, observed"
type: summary
area: [monitoring, core, security]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/system-subjects-observed-v2.14.6.md
author: this wiki (runs on the v2.14.6 binary with nats CLI 0.4.0, 2026-09-03; script system-subjects-run.sh beside the file)
article: "the HTTP mux, the request-only names, the account events and their heartbeats, a failed auth, service latency, reload by message, lame duck and shutdown"
date: 2026-09-03
version: "2.14.6"
tags: [system-account, "$SYS", events, monitoring, observed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — the `$SYS` subjects, observed

Eight runs on the lab cluster (`tools/lab/cluster.sh up 3`) and a standalone server with two
ordinary accounts, a latency-sampled service export and a leaf, all on the v2.14.6 binary. The
source half is [[s-nats-server-system-subjects]].

## Key claims

1. **HTTP status codes on n1**: `/varz` 200, `/statsz` **404**, `/idz` **404**, `/profilez` **404**,
   `/stacksz` 200 (a goroutine dump), `/debug/vars` 200 (Go `expvar`), `/subscriptionsz` 200 (the
   `/subsz` alias), `/expvarz` 404. Three of the docs' fifteen "HTTP monitoring endpoints" are not.
2. **The same three answer as requests**: `$SYS.REQ.SERVER.PING.IDZ` → three bare
   `{"name","host","id"}` replies; `PING.STATSZ` → `{"server":…,"statsz":{…}}`; `PING.PROFILEZ`
   with `{"name":"goroutine"}` → `{"server":…,"data":{"profile":"H4sI…"}}` (gzip, base64);
   `PING.VARZ` → `{"server":…,"data":{…}}`; `PING.EXPVARZ` answers (the request form of
   `/debug/vars`); `PING.STACKSZ` gets **no reply**; the legacy `$SYS.REQ.SERVER.PING` still answers
   with the `STATSZ` body.
3. **Account connections**: the event is on **both** `$SYS.ACCOUNT.<acc>.SERVER.CONNS` and
   `$SYS.SERVER.ACCOUNT.<acc>.CONNS` with the same `id`, on every connect and disconnect **and every
   30 s** while the account has a connection (`APP`: 01:47:31, 01:48:01, 01:48:31, 01:49:01). The
   docs' `$SYS.ACCOUNT.{account}.CONNECTIONS` never appeared; the event is a heartbeat, not the
   limit alarm the docs' overview describes. The body carries `name` and `num_subscriptions`, which
   the docs page omits; `leafnodes` counts a connected leaf (`"conns":1,"leafnodes":1,"total_conns":2`).
4. **A leaf node is a `CONNECT` event** on the account it binds to, `"kind":"Leafnode"`, `name` =
   the remote's `server_name`. **`$SYS.ACCOUNT.<acc>.LEAFNODE.CONNECT` was not published** (zero
   matches, two leaf connections) — `sendLeafNodeConnect` is a no-op without gateways.
5. **A failed authentication** produces `$SYS.SERVER.<id>.CLIENT.AUTH.ERR` **and**
   `$SYS.ACCOUNT.$G.DISCONNECT`, both of type `client_disconnect`, `reason: "Authentication
   Failure"`, the client attributed to `$G`; no `CONNECT` precedes them.
6. **Service latency** arrived on `svc.latency` — the export's `latency { subject }` — in the
   exporting account `SVC`, with `status: 200`, `requestor: {"acc":"APP","rtt":356292}`, the
   responder's `ClientInfo`, `service: 15000`, `system: 1792`, `total: 666084` (nanoseconds). The
   `$SYS.>` subscriber saw nothing for it; the docs' `$SYS.SERVER.METRIC.SERVICE.LATENCY` does not
   exist. The responder saw `Nats-Request-Info: {"acc":"APP","rtt":356292}` on the request.
7. **`STATSZ` every 10 s** from every server (01:47:12.778, :22.779, :32.779, …).
8. **Reload by message**: `$SYS.REQ.SERVER.<n1 id>.RELOAD` with an empty body answered
   `{"server":{…}}` and n1 logged `Reloaded server configuration (sha256:23f0c0…)`.
   **Lame duck**: `nats-server --signal ldm=<pid>` → `$SYS.SERVER.<n2 id>.LAMEDUCK` (a bare
   `ServerInfo`); n2 had no clients, exited in half a millisecond, and **no `SHUTDOWN` reached the
   subscriber** on that exit. A plain SIGTERM did produce `$SYS.SERVER.<n2 id>.SHUTDOWN`.
9. **Account-scoped requests as `sys`**: `$SYS.REQ.ACCOUNT.APP.{STATZ,INFO,SUBSZ,LEAFZ,CONNZ}`
   answer; `.JSZ` on a server without JetStream answers `"data":null,"error":{"code":500,…}`;
   `.CONNS` and `$SYS.REQ.ACCOUNT.NSUBS` give **no reply** (internal); `$SYS.DEBUG.SUBSCRIBERS`
   answers a bare number. **As the ordinary user `app`**: `$SYS.REQ.USER.INFO`,
   `$SYS.REQ.ACCOUNT.PING.CONNZ` and `.PING.STATZ` answer (scoped to `APP`);
   `$SYS.REQ.SERVER.PING.VARZ` and `$SYS.REQ.ACCOUNT.APP.CONNZ` → `No responders are available`.
10. Timestamps: the connect event's `timestamp` is UTC, the disconnect event's carries the local
    offset (`+02:00`) — `accountConnectEvent` uses `time.Now().UTC()`, `accountDisconnectEvent` the
    `now` its caller passes.

## Practical takeaways

- To reconcile "who is connected" after missing events: `$SYS.REQ.SERVER.<id>.CONNZ` per server
  (paged with `offset`/`limit` in the body), or wait 30 s for the next `CONNS` heartbeat per account.
- Alert on a missing `STATSZ` (10 s) or `CONNS` (30 s) rather than on a `SHUTDOWN`, which a lame-duck
  exit may not deliver.
- The leafnode-connect event needs gateways; on a plain cluster or a single hub, watch
  `$SYS.ACCOUNT.*.CONNECT` for `"kind":"Leafnode"` instead.

## Notable quotes

- `No responders are available` — an ordinary user asking `$SYS.REQ.SERVER.PING.VARZ`.
- `"reason":"Authentication Failure"` on a `client_disconnect` body: the auth-error event's shape.

## Relevance to the wiki

Proves the docs' three non-endpoints (docs issue #65), the `CONNECTIONS` subject and the
limit-versus-heartbeat contradiction (#66), the service-latency subject (#67); settles gh#5902
and gh#5768; the `To verify` item on [[advisories]] ("not captured on the wire") is closed by it.

## Questions it answers

Rows 82, 54, 161, 162, 163.

## Pages touched

[[system-subjects]] · [[monitoring-endpoints]] · [[advisories]] · [[reload-server-config]] · [[evict-a-sick-server]] · [[leafnode]]
