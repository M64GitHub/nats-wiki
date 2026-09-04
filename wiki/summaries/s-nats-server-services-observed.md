---
title: "observed: the services framework on nats-server 2.14.6 — subscriptions, $SRV bodies, the service error, and a blocked instance"
type: summary
area: [core, clients, monitoring, topology]
source-url: ""
source-path: raw/nats-server-src/services-observed-v2.14.6.md
author: maintainer
date: 2026-09-04
version: "nats-server 2.14.6; nats CLI 0.4.0; nats.go v1.53.1"
article: "runs A–E, six passes, with services-runA.sh … -runE2.sh, services-svc.go, services-raw.py and services-subsz.py"
tags: [observed, services, micro, "$SRV", queue-group, "Nats-Service-Error", drain, leafnode, permissions]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# observed: the services framework on nats-server 2.14.6

What a service actually puts on a server, what `$SRV` answers, what a service error is on the wire,
what a blocked instance does to a queue group, and what crosses a leafnode. Six passes on one machine
against `nats-server v2.14.6`, `nats` CLI 0.4.0 and a purpose-built nats.go v1.53.1 service with six
endpoints. The transcripts are `raw/nats-server-src/services-observed-v2.14.6.md`; the scripts, the
service program and the raw client sit beside it.

`$SRV` appears nowhere in the server's source. Everything below is what a **client library** does,
observed from the server side.

## Key claims

- **Ten subscriptions per instance, of which nine are `$SRV`.** Three verbs × three levels
  (`$SRV.PING`, `$SRV.PING.<name>`, `$SRV.PING.<name>.<id>`, and the same for `INFO` and `STATS`),
  **all plain subscriptions with no queue group** — which is why discovery is a broadcast — plus one
  subscription per endpoint carrying that endpoint's queue group (run A9, C2).
- **The demo service's shape**: `nats service serve <name>` creates a group named after the service
  and one endpoint `echo`, so the subject is `<name>.echo`, version `1.0.0`, with two metadata keys
  natscli stamps on (`_nats.client.created.library`, `_nats.client.created.version`) (run A1, A2).
- **`nats service list --json` is the raw `info_response`**, one object per instance; two instances of
  one service differ only in `id` (run A2).
- **`nats service info` shows one instance even when several run** — it takes the first reply, the
  mistake `discovery.md:325` warns callers about, in the CLI itself (run A3).
- **The `ping_response` carries five fields and nothing else** — no `started`, no `description`, no
  endpoints; the round-trip time is measured by the caller (run A5).
- **`processing_time` and `average_processing_time` are integer nanoseconds**; `started` is RFC3339
  UTC; `last_error` is present as `""` when there has been none; `data` is the `StatsHandler`'s
  return value (run A7).
- **`last_error` is formatted `"<code>:<description>"`** — e.g. `400:order total must be positive`
  (run C4).
- **Six requests split 4 / 2 across two instances**, and 1 / 5 and 5 / 1 on repeats — random per
  request (run A6).
- **The server does not reserve `$SRV`.** An ordinary client's `nats pub '$SRV.PING' hello` was
  accepted (`Published 5 bytes`), and a plain subscriber on `$SRV.>` saw another caller's discovery
  request with its reply inbox (run B1).
- **An endpoint subject is an ordinary subscription**: a publish with no reply subject still ran the
  handler, and the reply went nowhere (run B1).
- **Permissions are the only isolation.** A user allowed to publish `orders.>` but not `$SRV.>` could
  call the endpoint and not discover; a user with the reverse could discover and not call. The server
  logged `Publish Violation - Subject "$SRV.PING"` and `Publish Violation - Subject "orders.echo"`,
  and neither client was told anything — the CLI printed nothing and timed out (run B2).
- **`{group}.{endpoint}` confirmed**, and a service-level endpoint with an explicit subject gets no
  group prefix. For an endpoint whose queue group is disabled, `nats service info` **omits the Queue
  Group line** and stats print `in group ""` (run C1).
- **A service error on the wire**: `HMSG _INBOX.RAW.1 1 92 109` with
  `NATS/1.0\r\nNats-Service-Error: order total must be positive\r\nNats-Service-Error-Code: 400\r\n\r\n{"field":"total"}`.
  A no-responders answer for a subject nobody serves, on the same connection, is
  `HMSG _INBOX.RAW.2 1 55 55` with `NATS/1.0 503\r\nNats-Subject: orders.inventory.nosuch\r\n\r\n`
  and an empty body. **Both are delivered replies; only the headers tell them apart** (run C3).
- **★ A blocked endpoint does not block its siblings.** `slow` blocked 3 s; `check` was handled 0.3 s
  in and answered in 327 µs, `vip` 0.6 s in and answered in 508 µs. Each endpoint is its own
  `QueueSubscribe` with its own dispatcher (`nats.go@v1.53.1/micro/service.go:448–464`) (run C5).
- **★ A blocked instance keeps its share, and the queue group does not route around it.** Two
  instances, both handlers blocking 3 s, eight requests fired at once: every request was delivered at
  t = 11.086–11.087, the split was 3 / 5 at random, each instance processed one at a time, and **four
  of the eight callers timed out** — those requests were answered at 20.09 s, 23.09 s and 26.09 s into
  inboxes nobody was listening on (run C7).
- **An endpoint with the queue group disabled answers once per instance**: one request, two replies
  from two instances; the queue-grouped endpoints answered once (run C6).
- **`Stop()` removes everything at once and returns in about a millisecond.** Called 2.0 s into a 5 s
  handler, it returned in 1.3 ms; immediately after, both the endpoint and `$SRV.PING` answered
  `No responders`, and `/subsz` showed none of the instance's fifteen subscriptions. The in-flight
  handler still replied at 5.001 s, because the process stayed alive (run D1).
- **A `kill -9` mid-handler loses the work and tells the caller nothing** — the request had already
  been accepted, so there is no no-responders answer; the caller waits out its timeout (run D2).
- **★ `$SRV` and endpoint subjects cross a leafnode with no configuration.** A service on the leaf was
  listed, pinged and called from the hub (run E1).
- **★ But the queue group prefers the local member.** One instance on each side of the leafnode, one
  queue group: 8 of 8 requests from the hub went to the hub instance and 8 of 8 from the leaf to the
  leaf instance, while discovery saw both from either side (run E2).
- **`/subsz` does not itemise leaf-origin interest**: with a service only on the leaf, the hub's
  `/subsz?subs=1&acc=$G` counted 24 subscriptions and returned no `subscriptions_list` entries for
  them (run E3).
- **ADR-32's overridable `$SRV` prefix is not implemented in nats.go**: `APIPrefix = "$SRV"` is a
  `const` with no configuration path (`nats.go@v1.53.1/micro/service.go:264–265`).

## Practical takeaways

- Budget **ten subscriptions per instance plus one per extra endpoint** when sizing a fleet of
  services against a server's subscription count.
- Write two permission rules per service account: publish `$SRV.>` for the tooling that discovers,
  publish the endpoint subjects for the callers. They are independent, and a client denied either one
  simply times out.
- Size the caller's timeout for `handler time × queue depth`, not for the handler alone — a busy
  member queues its share and answers late, and late replies are indistinguishable from lost ones.
- Put a service instance next to its callers when the link is a leafnode: their traffic will stay
  local whether you intended it or not.

## Relevance to the wiki

The measured spine of [[services-framework]] and [[services-on-core-nats]]: the subscription count, the
two reply shapes, the drain behaviour and the leafnode locality result are all things no docs page
states. It settles four docs issues (#86, #113, #114, #115) and supplies the numbers behind the
sizing section of the pattern page.

## Questions it answers

134 (with [[services-on-core-nats]]), 188, 189, 190, 191, 192.

## Pages touched

[[services-framework]], [[services-on-core-nats]], [[queue-groups]], [[request-reply]],
[[system-subjects]], [[subject-permissions]], [[nats-timeout]], [[leafnode]], [[monitoring-endpoints]],
[[nats-cli]], [[nats-go]], [[worker-pool]]
