---
title: A service layer on core NATS
type: operation
kind: pattern
area: [core, clients, security, deploy]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; the framework is client-side
verified-against: nats-server 2.14.6, nats.go v1.53.1, nats CLI 0.4.0, ADR-32 rev 6
verified-on: 2026-09-04
tags: [services, micro, request-reply, queue-group, timeout, no-responders, scatter-gather, "$SRV", idempotency, drain, permissions]
aliases: [service layer, services on core NATS, request-reply at scale, microservices on NATS, scatter-gather, "designing a service layer", RPC on NATS]
sources: [s-adr-32-service-api, s-docs-services-framework, s-docs-services-discovery-and-stats, s-docs-services-scaling, s-nats-server-services-observed, s-gh-4984-micro-with-jetstream, s-docs-core-nats-request-reply, s-docs-core-nats-queue-groups, s-nats-server-request-reply-observed]
created: 2026-09-04
updated: 2026-09-04
---

# A service layer on core NATS

How to design request/reply services on core NATS: what the queue group does and does not do for you,
how to size a timeout, when to fan out instead of load-balance, and where the design stops working and
needs [[stream]]. The mechanism is in [[services-framework]]; this page is the decisions.

## The problem

You have work that is **synchronous** — a caller waits for an answer — and you want more than one copy
of the handler, discoverable, with no broker state, no load balancer and no service registry. Core
NATS gives you exactly that: a subject is an address, a queue group is a load balancer, and
no-responders is a health signal. Nothing has to be enabled on the server (source:
[[s-docs-services-framework]]).

What it does **not** give you is any memory. A request that reaches a handler which then dies is gone,
with no redelivery and no dead letter, and the caller learns only that it timed out. That boundary is
where this pattern ends and [[worker-pool]] begins, and it is not moving: asked in public whether the
framework could ack and nak against JetStream, a maintainer answered "roughly planned for a future
itteration … No immediate plans" in 2024 and "Not yet no … Still not on the immediate roadmap" in 2025
(source: [[s-gh-4984-micro-with-jetstream]]).

## The design

**One subject per operation, grouped by the thing they act on.** The framework builds the subject as
`{group}.{endpoint}`, so the group is your namespace and the endpoint is your verb:
`orders.inventory.check`, `orders.inventory.reserve`. Callers need nothing but the subject; there is
no routing layer to configure (source: [[s-docs-services-framework]]).

**Every endpoint in a queue group, the default `q`.** A second instance with the same name and version
joins the same group and takes a share of the traffic with no configuration at all. That is the whole
scaling model. Size a fleet by adding copies; there is nothing else to turn (source:
[[s-docs-services-scaling]], [[queue-groups]]).

**Give a slow endpoint its own queue group.** The default `q` is per endpoint, not per service, so the
counters and the load-balancing set are already separate. What an override buys you is separating the
*fleet*: run the instances that serve `report` in a group of their own, on their own hosts, so a
30-second report cannot fill the same instances that answer a 5-millisecond `check`. Within one
instance nats.go already isolates the two — a blocked endpoint does not block its siblings, measured
at 327 µs for `check` while `slow` was three seconds into a block (source:
[[s-nats-server-services-observed]]) — but that is a client-library property, not a guarantee of the
model.

**Size the timeout from the queue, not from the handler.** This is the decision the docs get wrong and
the one that will page you. The server picks a queue-group member **at random per request** and never
looks at whether it is busy; a blocked member keeps receiving its share and works through it one at a
time. Measured on 2.14.6: two instances, handlers blocking 3 s, eight simultaneous requests, split 3
and 5 at random — **four of the eight callers timed out**, and their replies arrived at 20 s, 23 s and
26 s into inboxes nobody was listening on (source: [[s-nats-server-services-observed]], run C7; docs
issues #86 and #114).

So the caller's deadline has to cover the queue depth, not one handler:

```
timeout ≈ p99 handler time × (peak concurrent requests / instances) × safety
```

and the two ways to shrink it are more instances or a faster handler — never a longer timeout alone,
which just converts a stall into a slower stall. If the arithmetic gives a number you would not wait
for, the work is not synchronous and belongs in a stream.

**Make every handler idempotent.** A caller that times out and retries has no way to know whether the
first request was handled; the reply may simply have been late. Nothing in core NATS deduplicates.
See the retry policy on [[request-reply]].

**Use no-responders as the deploy check, not a timeout.** With `no_responders` negotiated, a request to
a subject with no subscriber comes back **immediately** as `NATS/1.0 503` rather than waiting out the
timeout, so a caller can tell "nothing is deployed" from "everything is busy" in one round trip
(source: [[s-docs-core-nats-request-reply]], [[core-nats-delivery]]). Three outcomes, three meanings:

| what the caller sees | what it means |
|---|---|
| a reply with no service-error header | handled |
| a reply with `Nats-Service-Error-Code` | reached a handler, which rejected it |
| `NATS/1.0 503` immediately | no instance is subscribed — a deploy or permissions problem |
| a timeout | every instance is busy, or the one that took it died mid-flight |

**Check the error headers on every reply.** A service error is a delivered reply carrying
`Nats-Service-Error` and `Nats-Service-Error-Code`; a caller that only asks "did I get a message"
counts every rejection as a success (source: [[s-adr-32-service-api]]). [[nats-timeout]] is the triage
page when these run together.

**Scatter-gather only outside a queue group.** When you genuinely want every instance to answer — a
cache invalidation, a config reload, a poll of who is alive — that endpoint must have its queue group
*disabled*, and the caller must collect by deadline or by count rather than taking the first reply.
Measured: one request to a queue-group-disabled endpoint on two instances returns two replies (source:
[[s-nats-server-services-observed]]). Never disable a queue group on an endpoint that returns a
result: the caller keeps one reply and the rest are wasted work.

**Drain on stop; never signal a running instance.** `Stop()` removes the endpoint subscriptions *and*
the nine `$SRV` subscriptions at once and returns in about a millisecond, leaving in-flight handlers
running — so the shutdown is `Stop()`, wait for the work, then exit. Measured: after `Stop()` the
endpoint answered `No responders` immediately, and the handler that was mid-flight still replied three
seconds later because the process was still alive (source: [[s-nats-server-services-observed]], run
D1). A `kill -9` in the same place loses the work and tells the caller nothing at all. A rolling
upgrade is therefore: start the new instances, then stop the old ones one at a time.

**Use `$SRV` for discovery and health, not for routing.** `nats service ping <name>` returns one line
per instance, which is your count of live queue-group members; `$SRV.STATS` gives per-endpoint request
and error counters. Collect by deadline — a plain request-reply call against `$SRV` shows you one
instance and hides the rest (source: [[s-docs-services-discovery-and-stats]]).

## The configuration that implements it

### Permissions, per role

Discovery and invocation are separate publish permissions, and this is the only isolation the design
has — `$SRV` is **not** reserved by the server, and any client may publish to it or subscribe to
`$SRV.>` and watch every discovery request go by (source: [[s-nats-server-services-observed]], run B1).

```
authorization {
  users = [
    # the service itself
    { user: inventory, password: …, permissions: {
        publish:   { allow: ["_INBOX.>"] }
        subscribe: { allow: ["orders.inventory.>", "$SRV.>"] }
      }
    }
    # a caller: may invoke, may not enumerate the estate
    { user: orders-api, password: …, permissions: {
        publish:   { allow: ["orders.inventory.>", "_INBOX.>"] }
        subscribe: { allow: ["_INBOX.>"] }
      }
    }
    # operations tooling: may discover everything, may invoke nothing
    { user: ops, password: …, permissions: {
        publish:   { allow: ["$SRV.>", "_INBOX.>"] }
        subscribe: { allow: ["_INBOX.>"] }
      }
    }
  ]
}
```

Measured: the caller could invoke and not discover, the ops user could discover and not invoke, and
the server logged `Publish Violation - Subject "$SRV.PING"` for the refusal. **Neither client was told
anything** — a permissions refusal arrives as an async error the CLI does not print, so to the caller
it looks exactly like a timeout (source: [[s-nats-server-services-observed]], run B2). Budget a log
check into your triage runbook; see [[subject-permissions]].

### An inbox prefix per application

Give each calling application its own inbox prefix (`--inbox-prefix` on the CLI, the equivalent option
in every client) so a caller's replies can be permitted narrowly instead of granting `_INBOX.>` to
everyone. See [[request-reply]].

### Across accounts

The endpoint subject is exported and imported as an ordinary service (`allow_responses` on the export,
so the reply gets back); see [[cross-account-sharing]]. `$SRV` is **not** carried by that import: the
importing account cannot discover the exporting account's services unless you share the tree
deliberately. ADR-32 asks for an overridable `$SRV` prefix so cross-account tooling can address one
estate at a time; nats.go v1.53.1 hardcodes it as a `const` and no docs page mentions an override, so
today the answer is one discovery tree per account (source: [[s-adr-32-service-api]],
[[s-nats-server-services-observed]]).

### Where to place the instances

Discovery and endpoint subjects cross a leafnode with no configuration, but **the queue group prefers
the local member**: with one instance on each side of a leafnode, 8 of 8 requests from the hub went to
the hub instance and 8 of 8 from the leaf to the leaf instance, while discovery listed both from either
side (source: [[s-nats-server-services-observed]], run E). Read that twice before planning capacity
across an edge: an instance at the edge serves the edge's callers and adds nothing to the hub's
throughput, and if the local instance is the slow one, its callers queue behind it while a healthy
remote instance sits idle. See [[queue-groups]] and [[leafnode]].

## Trade-offs and costs

- **At-most-once, always.** A handler that dies mid-request loses it silently. There is no
  redelivery, no dead letter, and no way for the caller to distinguish "died" from "slow".
- **Ten subscriptions per instance**, plus one per extra endpoint, all of them in the account's
  subscription table (source: [[s-nats-server-services-observed]]). A large fleet of small services
  costs more in interest than in traffic; see [[jetstream-sizing]] for what a server's subscription
  count costs.
- **No aggregate anything.** Counters are per endpoint per instance and the server keeps no total;
  a dashboard has to sum across ids and cope with `Reset()` zeroing them (source:
  [[s-docs-services-discovery-and-stats]]).
- **No backpressure.** A queue group has no depth you can read and no way to shed load. The only
  signal that a fleet is saturated is callers timing out, which is why the timeout arithmetic above is
  the design's load model.
- **Shape changes are restarts.** Endpoints and metadata are immutable, so a rename or a new subject
  is a rolling restart of the fleet (source: [[s-docs-services-framework]]).
- **Discovery is not authorization.** Anyone who can publish `$SRV.>` can enumerate every service,
  endpoint, subject and queue group in the account.

## When *not* to use it

- **The work must not be lost.** If a request represents an order, a payment or anything you would
  have to reconcile, put it in a [[stream]] and answer from a consumer — [[worker-pool]] is that
  pattern. The framework will not grow acks: as of 2.14.6 the maintainers' answer is still "not on
  the immediate roadmap" (source: [[s-gh-4984-micro-with-jetstream]]).
- **The caller does not need the answer now.** A synchronous round trip that exists only to confirm
  receipt is a stream publish with a `PubAck` — see [[core-or-jetstream]].
- **The handler is slow enough that the queue arithmetic frightens you.** Anything beyond a second or
  two of p99 handler time turns a burst into a timeout storm; make it asynchronous.
- **You need retries with backoff, or a dead-letter path.** Both are consumer features; core NATS has
  neither. See [[ack-and-redelivery]] and [[dead-letter-queue]].
- **You need to fan out to a *changing* set of receivers reliably.** A queue-group-disabled endpoint
  reaches whoever is connected at that instant and nothing else; an interest-retention stream reaches
  whoever is registered. See [[retention-policies]].

## Verify it

```
nats service ping ORDERS                      # one line per live instance
nats service stats ORDERS --json              # per-endpoint counters, per instance
nats request '$SRV.INFO' '' --replies=0       # every service in the account, gathered by deadline
nats request orders.inventory.nosuch x        # expect: No responders are available, immediately
```

A deploy is healthy when `nats service ping` counts the instances you expect and a request to a
misspelled endpoint comes back as no-responders rather than a timeout.

## Related

[[services-framework]] · [[request-reply]] · [[queue-groups]] · [[core-nats-delivery]] ·
[[core-or-jetstream]] · [[worker-pool]] · [[nats-timeout]] · [[subject-permissions]] ·
[[cross-account-sharing]] · [[leafnode]] · [[system-subjects]] · [[nats-cli]]

## Sources

[[s-adr-32-service-api]] · [[s-docs-services-framework]] · [[s-docs-services-discovery-and-stats]] ·
[[s-docs-services-scaling]] · [[s-nats-server-services-observed]] ·
[[s-gh-4984-micro-with-jetstream]] · [[s-docs-core-nats-request-reply]] ·
[[s-docs-core-nats-queue-groups]] · [[s-nats-server-request-reply-observed]]
