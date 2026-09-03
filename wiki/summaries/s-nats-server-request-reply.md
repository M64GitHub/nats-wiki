---
title: "nats-server v2.14.6 — request/reply and queue groups in the source: the 503, processMsgResults, the queue weight, the gateway exclusion"
type: summary
area: [core, topology, clients]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/request-reply-v2.14.6.md
author: nats-io (server source at tag v2.14.6, verbatim ranges with line numbers)
date: 2026-08-27
version: "2.14.6"
article: "server/client.go — the pmr flags, the tail of processInboundClientMsg (the 503), subForReply, processMsgResults' queue selection and delivery; server/sublist.go — the remote queue weight expansion; server/route.go — RS+ with a weight; server/gateway.go — sendMsgToGateways' queue exclusion"
tags: [source, 503, no_responders, Nats-Subject, subForReply, processMsgResults, queue-group, random-index, qw, RS+, leafnode, spoke, gateway, exclusion-list]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — request/reply and queue groups in the source

The ranges behind [[request-reply]] and [[queue-groups]], read at the tag and then run
([[s-nats-server-request-reply-observed]]). The `CONNECT` check that refuses `no_responders` without
`headers` is in [[s-nats-server-core-delivery]] (`client.go:2454–2470`) and not repeated.

## Key claims

### The 503 (`client.go:4474–4516`, `:4522–4531`)

- `didDeliver` is set by the local delivery (`processMsgResults`) and by the gateway send; the
  no-responders reply goes out only when **all four** hold: nothing took the message, the publish
  carried a reply subject, the connection's `CONNECT` had `no_responders`, and **the requesting
  connection itself holds a plain subscription matching the reply subject** — `subForReply` walks the
  account's matches for the reply subject and returns the first whose `client == c` (`:4523–4531`).
  A request whose reply subject the requester is not subscribed to gets nothing (run B4); a request
  from one connection with the inbox subscribed on another gets nothing.
- The reply is `HMSG <reply> <sid> <hdrLen> <hdrLen>\r\nNATS/1.0 503\r\nNats-Subject: <subject>\r\n\r\n\r\n`
  with `hdrLen := 32 /* header without the subject */ + len(c.pa.subject)` (`:4508–4511`): header length
  equals total length, so the message has no body, and the subject named is the one the requester
  published (across a renamed service import, the importer's name — run G3).
- When the server is a gateway with queue subscriptions on the far side, the local delivery is asked
  to collect the queue names it served (`pmrCollectQueueNames`, `:4481–4489`) so that
  `sendMsgToGateways` can exclude them.

### One member per message (`client.go:5220`, `:5426–5577`, `:5625–5663`)

- Plain subscriptions are delivered first. For each matching queue group the server takes the group's
  entry list, picks **a random start index** (`sindex = int(fastrand.Uint32() % uint32(lqs))`, `:5516`;
  "Find a subscription that is able to deliver this message starting at a random index", `:5519`) and
  walks the list from there; the first entry that can take the message gets it and the walk ends
  (`:5628–5657`).
- What "can take" means depends on the message's origin (`c.kind`) and the entry's kind
  (`sub.client.kind`):
  - from a **client**: a local member is delivered to; a **route** entry — a member on a peer server —
    is taken at once, "Pick this one and be done" (`:5570–5571`), unless the peer holds it for a leaf
    (`sub.origin`), in which case it is only the fallback (`:5556–5566`); a **leaf** entry is skipped and
    remembered as the fallback — "Remember that leaf in case we don't find any other candidate"
    (`:5547–5552`);
  - from a **route**: "we want to prefer local subs. So only select from local subs but remember the
    first rsub in case all else fails" (`:5480–5482`) — a routed message is never routed again; among the
    fallbacks a leaf beats a route, and two leaves are decided by a coin flip (`:5497–5504`, #6040);
  - a **spoke leaf** never forwards to a route (`:5534`).
- When no local entry took the message the remembered route or leaf entry is added to the route
  targets (`addSubToRouteTargets`, `:5662–5663`) and the message leaves the server once.

### A peer's members count one by one (`sublist.go:702–704`, `:728–751`; `route.go:1486–1499`, `:1570–1582`)

- A peer announces its members with `RS+ <account> <subject> <queue> <weight>`; the weight is the
  member count behind that route, kept in `sub.qw` and updated as members come and go
  (`route.go:1498`, `:1573`).
- The sublist's match result **shadows** a routed or leaf queue subscription once per unit of weight
  — "for n := 0; n < int(ns); n++ { results.qsubs[i] = append(results.qsubs[i], sub) }"
  (`sublist.go:741–747`, `isRemoteQSub` at `:702–704`) — so the random pick above is over *members*,
  not over connections: one local member plus a peer holding three gives four entries and a quarter
  each (run E2). The same expansion puts a leaf's *n* entries side by side in the list, which the
  skip-a-leaf rule walks over onto the next local member (run H5 — the 3 : 1 split; `inbox/server-issues.md`
  SI-8).

### Geo-affinity is an exclusion list (`gateway.go:2539`, `:2611–2654`)

- `sendMsgToGateways` receives the queue names the local delivery served; for each remote cluster
  with interest it drops those names from the message's queue list (`:2638–2649`) and skips the gateway
  only when no plain interest and no other queue remains (`:2653–2654`) — the lines [[gateway]] already
  quotes from [[s-nats-server-topology]].

## Practical takeaways

- The 503 needs the requester's own subscription on the reply subject: a client that subscribes to
  its inbox on one connection and publishes on another never sees it.
- In a cluster every member of a group is equally likely, wherever it sits; across a leafnode the
  publisher's side wins outright; across a gateway the publisher's cluster wins by exclusion.
- `Nats-Subject` names the subject as published, so across an import it is the importer's subject.

## Notable quotes

- "Find a subscription that is able to deliver this message starting at a random index." (`client.go:5519`)
- "Pick this one and be done." (`client.go:5570`)

## Relevance to the wiki

The server's half of [[request-reply]] and [[queue-groups]]; the same-cluster and leafnode rules on
[[gateway]] and [[leafnode]]; the mechanism behind SI-8.

## Questions it answers

150, 173, 174.

## Pages touched

[[request-reply]] · [[queue-groups]] · [[gateway]] · [[leafnode]] · [[cross-account-sharing]] ·
[[core-nats-delivery]]
