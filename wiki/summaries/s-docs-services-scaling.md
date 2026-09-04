---
title: "docs: scaling a service — instances, the queue group, and stopping one cleanly"
type: summary
area: [core, clients, deploy]
source-url: https://docs.nats.io/learn/services/scaling
source-path: raw/nats-docs/learn/services/scaling.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "learn/services/scaling.md — the operator page of the services chapter"
tags: [services, scaling, queue-group, drain, Stop, rolling-restart, blocking-handler, at-most-once]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: scaling a service — instances, the queue group, and stopping one cleanly

The one page of the services chapter written for whoever runs the thing: how copies of a service share
load, what a graceful stop does, how to roll a version, and the two failure modes the page names.
**Two of its behavioural claims are wrong**, and both are the kind an architect sizes on; runs C5 and
C7 in [[s-nats-server-services-observed]] settle them, and they are docs issues #86 and #114.

## Key claims

- **An instance is a copy.** "Each copy is an **instance**: one running service with its own service
  ID. All instances of `OrderInventory` share the same service name and the same version; only the
  auto-generated service ID differs" (`:12`). "You don't register instances anywhere. You don't
  configure a load balancer" (`:14`).
- **The default queue group is the whole scaling mechanism.** "What makes the requests spread is the
  **default queue group `"q"`**. Every endpoint joins it unless you override it. When several
  instances subscribe to `orders.inventory.check` under the same queue group, the server delivers each
  request to exactly one member of that group" (`:16`).
- "Six requests across two instances land roughly three and three" (`:150`) — measured splits on
  2.14.6 were 4 / 2, 1 / 5 and 5 / 1 (run A6), which is what "random per request" looks like.
- **★ Wrong: "the server delivers each message to whichever queue-group member is ready"** (`:150`).
  The server picks a member at random per message (`server/client.go:5514–5520`) and reads nothing
  about a handler's state. Docs issue #86.
- **★ Wrong: "The queue group masks this for a while by sending requests to the busy instance's peers
  instead"** (`:272`). Run C7: two instances, eight requests, handlers blocking 3 s — every request was
  delivered at once, the split was 3 / 5 at random, each instance processed its own share one at a
  time, and **four of the eight callers timed out** while replies arrived at 20 s, 23 s and 26 s.
  A blocked member keeps its share; nothing is re-routed. Docs issue #114.
- **Half wrong: "Handlers run synchronously on the service's connection. While one handler blocks …
  that instance answers no other request"** (`:272`). In nats.go each endpoint is its own
  `QueueSubscribe` with its own dispatcher, so a block is **per endpoint**: run C5 answered `check`
  in 327 µs and `vip` in 508 µs while `slow` was 3 s into a block on the same instance. Part of docs
  issue #114.
- **What `Stop()` does** (`:164`): it "**drains** each endpoint subscription: it removes the endpoint's
  queue-group interest right away, so the server stops routing new requests to this instance, then
  unsubscribes the `$SRV` discovery verbs. Requests the instance already accepted keep processing in
  the background. `Stop()` returns before that background processing finishes, so don't exit the
  process the moment it returns". Run D1 confirms it exactly: `Stop()` returned in 1.3 ms, every
  subscription was gone at once, new requests got `No responders`, and the in-flight handler still
  replied 3 s later because the process stayed alive.
- **No gap while scaling down**: "Because the endpoint leaves the queue group as part of the stop, the
  remaining instances pick up every new request automatically. There's no window where a request lands
  on a queue group whose only member just vanished" (`:166`).
- **The CLI has no graceful stop**: "Ctrl-C on `nats service serve` closes the connection abruptly,
  with no drain, which is the failure mode to avoid" (`:187–189`). Confirmed in natscli's source —
  `serveAction` blocks on `<-ctx.Done()` and returns without calling `Stop()`
  (`natscli@v0.4.0/cli/service_command.go:190–194`).
- **Rolling a version**: "start fresh instances, then stopping the old ones one at a time; at every
  moment at least one instance is in the queue group answering orders" (`:260`).
- **Instances share nothing**: "If a handler increments a counter, caches a value, or reserves stock in
  a local variable, each instance keeps its own copy … Keep handlers stateless, and when work genuinely
  needs shared state, push it into an external store: a database, or a JetStream stream or key-value
  bucket" (`:270`).
- **Durability is elsewhere**: "A service stores nothing; it's at-most-once request-reply. Put durable
  state behind JetStream" (`:262`).
- **Contradiction with the chapter's own closing page**: `where-next.md:34` says "when an instance
  stops, its in-flight work is gone", against this page's `:164` and `:376` ("the survivors absorb the
  load with nothing dropped") and `where-next.md:46` ("each `Stop()` drains in-flight requests").
  Run D shows both are true of different stops: a graceful `Stop()` keeps the work, a `kill -9`
  loses it and the caller learns nothing but a timeout. Docs issue #115.
- **A dangling cross-reference**: "You met `WithEndpointQueueGroupDisabled` on endpoints and groups"
  (`:158`) — that page never names the option, it says only "You control this with one option"
  (`endpoints-and-groups.md:311`). Docs issue #110.

## Practical takeaways

- Size a service by the **slowest handler on its busiest endpoint**, not by the fleet: a blocked
  member's share waits behind the block, so the queue's depth is (requests per second × block time) /
  instances, and the caller's timeout has to cover it.
- The rollout procedure is start-then-stop, one at a time, with a `Stop()` and a wait — never a
  `kill -9`, which drops in-flight work with no signal to the caller.
- `nats service ping <name>` counting replies is the readiness check: it counts queue-group members.

## Notable quotes

- "You don't register instances anywhere. You don't configure a load balancer." (`:14`)
- "`Stop()` returns before that background processing finishes, so don't exit the process the moment
  it returns." (`:164`)
- "Ctrl-C on `nats service serve` closes the connection abruptly, with no drain." (`:187`)

## Relevance to the wiki

The operating half of [[services-framework]] and the trade-offs section of [[services-on-core-nats]].
It is also this ingest's richest source of docs issues: #86 (readiness), #114 (the busy instance's
peers, and per-endpoint blocking), #115 (in-flight work on stop), #110 (the cross-reference).

## Questions it answers

134 (with [[services-on-core-nats]]), 189, 192.

## Pages touched

[[services-framework]], [[services-on-core-nats]], [[queue-groups]], [[worker-pool]],
[[slow-consumer-in-the-client]], [[client-connection-lifecycle]]
