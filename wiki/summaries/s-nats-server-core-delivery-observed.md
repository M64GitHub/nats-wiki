---
title: "nats-server v2.14.6 — core delivery observed: whitespace subjects, max_payload with headers, pedantic mode, max_subscription_tokens, /subsz, nats trace, mappings, restart and lame duck"
type: summary
area: [core, monitoring, clients]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/core-delivery-observed-v2.14.6.md
author: this wiki (runs on the v2.14.6 binary with nats CLI 0.4.0, 2026-09-03; script core-delivery-run.sh and the raw protocol writer core-delivery-raw.py beside the file; run D6 on tools/lab/cluster.sh)
article: "seven runs A–G on a standalone server, one on the three-node lab"
date: 2026-09-03
version: "2.14.6"
tags: [observed, whitespace, max_payload, HPUB, pedantic, Invalid Publish Subject, max_subscription_tokens, subsz, nats-trace, mappings, weight, partition, reload, lame-duck, reconnect]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — core delivery observed

The behavioural half of [[s-nats-server-core-delivery]]: every claim of the core-NATS chapter that could
be run, run — over the raw protocol where the claim is about the wire, with the `nats` CLI where it is
about the client, and once on the lab where it needs a system account.

## Key claims

- **A: whitespace and the handshake.** `nc` prints the `INFO` line with `"headers":true`,
  `"max_payload":1048576`, `"api_lvl":4`. A raw `PUB orders.us created 0` is accepted and a `>` tap
  prints `Received on "orders.us" with reply "created"` — the server read the space as the reply
  boundary. `nats pub` and `nats sub` refuse the same subject client-side: `nats: error: nats: invalid
  subject`, exit 1. A `CONNECT` with `no_responders` and no headers: `-ERR 'no responders requires
  headers support'`, socket closed.
- **B: `max_payload`.** A 2 MB `nats pub`: `nats: error: nats: maximum payload exceeded`, exit 1,
  nothing sent. A raw `PUB` of 1,048,577 bytes: `-ERR 'Maximum Payload Violation'`, the connection
  closed on the control line (broken pipe before the body was written), log `maximum payload exceeded:
  1048577 vs 1048576`; exactly 1,048,576 delivered. An `HPUB` of **600,000 header + 500,000 body bytes**,
  each under the limit: refused, `maximum payload exceeded: 1100000 vs 1048576` — **headers count**;
  600,000 + 400,000 delivered. With `no_header_support: true`: `INFO` says `"headers":false`, `nats pub
  -H` fails client-side (`headers not supported by this server`), and a `CONNECT` asking for
  `no_responders` is refused as in A.
- **C: subject checks.** `SUB orders.>.created` → `-ERR 'Invalid Subject'`, connection open. A
  non-pedantic `PUB orders.*.created 0` is delivered to `orders.>` **and to a subscriber on
  `orders.*.created`** (its `*` matched the literal `*`), not to `orders.us.created`. A **pedantic**
  connection gets `-ERR 'Invalid Publish Subject'` **and the message is still delivered**. `orders..created`
  → `Invalid Subject`. With `max_subscription_tokens: 3`: `SUB a.b.c.d` → `-ERR 'Permissions Violation for
  Subscription to "a.b.c.d", too many tokens'` + `[ERR] … Subscription Violation Too Many Tokens - Subject
  "a.b.c.d", SID 1`; `SUB a.b.c` fine; `PUB a.b.c.d` delivered. A reload with the value changed:
  `Failed to reload server configuration: config reload not supported for MaxSubTokens: old=3, new=4`.
  `0` → `value can not be negative`; `256` → `value is too big`.
- **D: `/subsz` and the two requests.** `test=orders.us.created` with an `orders.>` subscriber: `total: 1`
  and that one entry (`num_subscriptions: 6` counts all of `$G`); all of `$G` is four `$SYS.REQ.*`
  service-import subscriptions on one cid, the queue subscription (`"qgroup": "packers"`) and the tap;
  no `acc=` → 62 across `$G` and `$SYS`; no subscriber → `total: 0` and no list. On the plain server
  `nats server request subscriptions` → `server request failed, ensure the account used has system
  privileges and appropriate permissions` (exit 1) while `… connections` answers with the caller's own
  connection; on the lab as `sys` both answer, one reply per node.
- **E: `nats trace`.** No interest: `--X No active interest`. With `orders.>`: `--C Client "NATS CLI
  Version 0.4.0" cid:6 subject:"orders.>"`, `Egress Count: Client: 1`, the subscriber received nothing.
  `--deliver`: the subscriber received the traced message carrying `Nats-Trace-Dest: _INBOX.…` and
  `Accept-Encoding: snappy`, empty body. All on a plain server with no system user.
- **F: mappings.** Dry runs give the docs' outputs, buckets 0/1/2 for the three ids. Weight 10 to a
  canary: **17 of 200** remapped. Weight edited to 50 and `--signal reload`: `Reloaded: accounts`, then
  93 / 107. Weights 60 + 50: `Error adding mapping for "orders.created" : total weight needs to be <=
  100`, exit 1. The source as its own destination at 90: **188 of 200 arrived, 12 dropped**. Live
  partition: buckets 0, 1, 2, and 0 again for the repeated id; a subscriber on the pre-map subject got
  nothing.
- **G: restart and lame duck.** `nats sub --trace`: `>>> Disconnected due to: EOF, will attempt
  reconnect`, `>>> Setting reconnect delay to 725ms`, `>>> Reconnected to nats://127.0.0.1:14222`; a
  `nats pub` while the server was down: `nats: error: nats: no servers available for connection`,
  exit 1. `--signal ldm` with `lame_duck_grace_period: 1s` (`lame_duck_duration` has a **30 s minimum**
  — `3s` is refused at start): `Entering lame duck mode, stop accepting new clients`, one second later
  `Closing existing clients`, `Initiating Shutdown...`, `Server Exiting..` — with its only client closed
  the server exited after the grace period, not after the duration. The CLI printed no lame-duck line,
  only the disconnect and then jittered reconnect delays (1.0 s … 7.9 s) with `connection refused`.

## Practical takeaways

- What the client guards, the server does not: whitespace, wildcards, `$` prefixes and token counts in
  a *publish* all reach the server and are routed. Pedantic mode only adds an error line.
- A `max_payload` violation is a **disconnect**, and the budget is header plus body.
- `nats server request …` on a plain server is not "broken": `subscriptions` needs a system user,
  `connections` answers for your own account. `/subsz?test=` needs no credentials at all.
- A weighted mapping's remainder is dropped only when the source is listed; otherwise it stays.

## Notable quotes

- `-ERR 'Invalid Publish Subject'` followed, on the tap, by `[#1] Received on "orders.*.created"` — the
  pedantic error that delivers anyway.

## Relevance to the wiki

Re-runnable evidence for every observable sentence on [[subjects-and-wildcards]] and
[[core-nats-delivery]]; the `max_subscription_tokens` and `mappings` reload facts on [[config-keys]];
the `/subsz` fields on [[monitoring-endpoints]]; server issue SI-7.

## Questions it answers

25, 169, 170, 171.

## Pages touched

[[subjects-and-wildcards]] · [[core-nats-delivery]] · [[subject-transforms]] · [[config-keys]] ·
[[defaults-and-limits]] · [[monitoring-endpoints]] · [[nats-cli]] · [[unauthenticated-clients-still-connect]] ·
[[nats-server-2.11]]
