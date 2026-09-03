---
title: "nats-server v2.14.6 — request/reply and queue groups observed: the 503 and Nats-Subject, the CLI's gather modes and exit codes, a busy member, the pick across a cluster and a leafnode, the 503 over an import"
type: summary
area: [core, topology, clients]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/request-reply-observed-v2.14.6.md
author: this wiki (runs on the v2.14.6 binary with nats CLI 0.4.0, 2026-09-03; four scripts and request-reply-subsz.py beside the file; run E on tools/lab/cluster.sh, run H on a standalone hub and leaf)
article: "runs A–D, G on a standalone server; E on the three-node lab; H on a hub with a leafnode; four passes"
date: 2026-09-03
version: "2.14.6"
tags: [observed, 503, Nats-Subject, no-responders, exit-code, scatter-gather, replies, reply-timeout, wait-for-empty, sentinel, queue-group, readiness, cluster, leafnode, service-import, subsz]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — request/reply and queue groups observed

The behavioural half of [[s-nats-server-request-reply]]: eight runs in four passes, the raw protocol
where the claim is about the wire, the `nats` CLI (0.4.0, nats.go v1.51.0 inside it) where it is about
the client, the lab where it needs a cluster, and a standalone hub and leaf where it needs a leafnode.

## Key claims

- **A: `nats reply`'s default group.** `/subsz?subs=1&acc=$G` shows the two responders as `qgroup
  NATS-RPLY-22` and `qgroup carrier-b`. A default request (`--replies 1`) printed **one** reply, the first
  to arrive, and discarded the other group's; `--replies 0 --timeout 2s` printed both and returned after
  **2.045 s**; a third member in the default group changed nothing; over 40 requests the two default
  members received 18 and 25.
- **B: the 503 on the wire.** With `headers` and `no_responders` in `CONNECT`, a `SUB _INBOX.x 1` and
  a `PUB nobody _INBOX.x 0`: **`HMSG _INBOX.x 1 38 38`** + `NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n`
  — header length equals total length, 38 = 32 + `len("nobody")`. Without `no_responders`: nothing.
  `no_responders` without `headers`: `-ERR 'no responders requires headers support'`, the socket
  closed, `[ERR] … no responders requires headers support` in the log. A reply subject the connection
  is not subscribed to: nothing. A subscriber on the subject that never replies: nothing — a timeout,
  not a 503.
- **F: the CLI's exit codes.** No responders: `No responders are available` after **0.037 s**,
  **exit 0**. Timeout: **nothing printed** after `Sending request on "nobody"`, **exit 0** after
  1.058 s. Success: exit 0. One exit code for three outcomes, and the timeout is silent
  (`inbox/docs-issues.md` #89).
- **C: a busy member keeps its share.** Two members of group `inv`, one running `sleep 1` before each
  reply, under 20 concurrent requests: the slow one received **8 of 20** (then 12 of 20 on the repeat,
  `/subsz` `msgs 8` and `msgs 12`) and answered them one per second, so the run took 8.6 s and 12.3 s.
  Nothing routed around it — the pick is random (`client.go:5516–5519`), not readiness-aware, against
  `learn/services/scaling.md:150, 272` (docs issue #86).
- **D: gather timing.** Three responders: `--replies 3` returns in **0.041 s**; `--replies 0 --timeout
  2s` holds the full **2.057 s**. Two responders and `--replies 3`: **0.364 s** — the average reply time
  plus the 300 ms `--reply-timeout`; `--reply-timeout 1s` → 1.061 s; `--replies 0 --reply-timeout 50ms`
  → 2.040 s (no effect). Nobody: `No responders are available` in 0.038 s. Two quoting responders and a
  third answering an **empty body** after 200 ms: with `--wait-for-empty` **and** with `--replies 5`
  alike, both quotes then `nil body` at ~212 ms and a return at ~0.25 s — an empty reply ends a
  counted gather whether or not the flag is given; `--replies 2` took the two quotes in 0.030 s and never
  saw the empty one. (A first pass of the sentinel run ended at 0.348 s with two replies: the
  responder's first `sh` start lost the race against the 300 ms gap.)
- **E: the pick across the lab.** One member on n1 and one on n2, publishing on n1: **92 / 108**, then
  116 / 84. One on n1 and **three** on n2, 400 publishes: **90 / 97 / 106 / 107**, then 105 / 98 / 102 / 95
  — a quarter each, wherever the member sits. Members only on n2 and n3: 105 / 95. Two on n1 and one on
  n2: 100 / 104 / 96. A plain subscriber on n3 beside the group: all 200, and the group still 98 / 102.
  n1's `/subsz` lists **only n1's own member**; a peer's members never appear on it.
- **G: the 503 across a service import.** `APP` importing `svc.check` from `SVC` with nobody in `SVC`:
  `No responders are available` after **0.037 s**; on the wire `HMSG _INBOX.x 1 41 41` with
  **`Nats-Subject: svc.check`**; with the import renamed `to: inv.stock`, **`Nats-Subject: inv.stock`** —
  the subject the requester published. With a responder in `SVC` both imports answer; a subject `APP`
  never imported is no responders too.
- **H: across a leafnode.** One member each side, publishing on the hub: **200 / 0**; on the leaf:
  **0 / 200**. Members only on the leaf, publishing on the hub: 93 / 107. Two on the hub and one on the
  leaf, publishing on the leaf: 0 / 0 / 200. **Two on the hub and two on the leaf, publishing on the hub:
  148 / 52, then 89 / 311, 297 / 103, 302 / 98** — the leaf's members get nothing and the hub's two are
  split **3 : 1**; two and one: 137 / 263 (2 : 1); three and two: 70 / 75 / 255 (1 : 1 : 3); the control,
  two and none: 196 / 204. The leaf's *n* entries sit side by side in the match list, the walk skips
  them and lands on the next local member, which receives its own share plus the leaf's *n*
  (`inbox/server-issues.md` SI-8).

## Practical takeaways

- A client sees the 503 only if it asked for headers and `no_responders` and holds the inbox
  subscription on the same connection; the header names the subject as the requester published it.
- Do not size a queue group on readiness: a slow member drags its share of requests behind it. Put
  the timeout on the requester and keep members interchangeable.
- In a cluster the pick is uniform per member; across a leafnode the publisher's own side takes
  everything; and a leaf holding members skews the hub's own split — put a group on one side of a leaf,
  or expect the skew.
- `nats request` exits 0 on a timeout and prints nothing; scripts must read the output, not `$?`.

## Notable quotes

- `HMSG _INBOX.x 1 38 38 | payload: NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n\r\n` — the whole no-responders reply.
- `hub-e1-2 297 · hub-e2-2 103 · leaf-e1-2 0 · leaf-e2-2 0` — the leafnode skew.

## Relevance to the wiki

Re-runnable evidence for every observable sentence on [[request-reply]] and [[queue-groups]]; the
import run for row 150 on [[cross-account-sharing]]; the leafnode rule on [[leafnode]]; docs issues
#85, #86, #89; server issue SI-8.

## Questions it answers

150, 172, 173, 174.

## Pages touched

[[request-reply]] · [[queue-groups]] · [[nats-timeout]] · [[cross-account-sharing]] · [[leafnode]] ·
[[gateway]] · [[nats-cli]] · [[monitoring-endpoints]] · [[core-nats-delivery]]
