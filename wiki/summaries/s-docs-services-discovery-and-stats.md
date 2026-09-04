---
title: "docs: services discovery and stats — the $SRV verbs, the three response schemas, and the service error"
type: summary
area: [core, clients, monitoring]
source-url: https://docs.nats.io/learn/services/discovery
source-path: raw/nats-docs/learn/services/discovery.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "learn/services/discovery.md and observability.md, with reference/services.md and the three reference/services/*-response.md schema pages, cross-read against raw/jsm-go/micro-*-v0.4.1.json"
tags: ["$SRV", discovery, PING, INFO, STATS, "Nats-Service-Error", stats, num_requests, processing_time]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: services discovery and stats — the `$SRV` verbs, the three response schemas, and the service error

The wire surface of the services framework: the two learn pages that describe it and the four
reference pages that specify it. The reference pages are renderings of the `io.nats.micro.v1.*`
JSON schemas, and the renderer **collapsed** the `metadata` `oneOf` and the `endpoints` array's item
schema — so this summary reads the schemas themselves from `raw/jsm-go/micro-*-v0.4.1.json`, mirrored
for that reason.

## Key claims

- **Three verbs, three levels.** `PING` "checks whether a service is present … Use it to find services
  and measure round-trip time"; `INFO` "adds the description and the list of endpoints, each with its
  subject and queue group"; `STATS` "adds per-endpoint counters" (`discovery.md:14–16`). The address
  levels are `$SRV.<VERB>`, `$SRV.<VERB>.<name>`, `$SRV.<VERB>.<name>.<id>` (`:24–30`).
- **Nothing is announced.** "A service doesn't publish to `$SRV` itself; it subscribes there and
  replies to your requests, the same request-reply you already know" (`discovery.md:18`).
- **Discovery is broadcast, deliberately.** "A `$SRV.INFO.OrderInventory` request reaches *every*
  instance named `OrderInventory`, and every one of them replies … a caller doesn't wait for a single
  reply; it waits a short deadline and collects however many responses arrive in that window"
  (`discovery.md:180–182`). The pitfall: "A plain request returns the first response and stops …
  five running instances appear as one" (`:325`) — which `nats service info` itself does (run A3).
- **The CLI wrappers** run the same requests: "`nats service list` enumerates every service and
  instance it can find; `nats service info` formats one service's endpoints; `nats service ping`
  measures round-trip time to each responder … These run the same `$SRV` requests internally and
  gather the replies by deadline" (`discovery.md:309–319`).
- **The five counters** (`observability.md:14–20`): `num_requests` "total requests this endpoint has
  handled"; `num_errors` "how many of those ended in a service error"; `last_error` "the description
  string of the most recent error"; `processing_time` "total handler time across all requests, in
  nanoseconds"; `average_processing_time` "`processing_time` divided by `num_requests`, in
  nanoseconds". "The counters tracked here are per endpoint, not per service" (`:164`).
- **Per instance, and resettable.** "Each running instance keeps its own counters, so
  `$SRV.STATS.OrderInventory` returns one `stats_response` per instance and you must sum
  `num_requests` across IDs yourself to get a service-wide total; the server keeps no aggregate for
  you. And a call to `Reset()` on an instance sets its counters back to zero and resets the `started`
  timestamp, so a dashboard that assumes monotonically increasing counters will see a drop"
  (`observability.md:401`).
- **The service error.** "`Nats-Service-Error` holds a human-readable description, and
  `Nats-Service-Error-Code` holds a short code string like `"400"`" … the framework "attaches both
  headers, sends the response, and bumps `num_errors` and `last_error` for that endpoint in the same
  step" (`observability.md:172`).
- **A service error is a delivered reply.** "The request reached the handler, the handler chose to
  answer with an error, and that answer came back over the same reply subject as any success. This is
  different from **no-responders**, where nothing is listening at all" (`observability.md:287`). The
  caller-side trap: "the caller's `Request` returns a message with no transport error … every service
  error reads as a success" (`:295`). Run C3 shows both replies byte for byte.
- **The schemas** (`raw/jsm-go/micro-*-v0.4.1.json`). All three share `type` (a `const`), `name`
  (`^[a-zA-Z0-9_-]+$`, min length 1), `id` (min length 1), `version` (the official SemVer regex, min
  length 5) and an optional `metadata` string map that may be `null`. `ping_response` requires
  `type, name, id, version` and has nothing else. `info_response` also requires **`description`** and
  adds `endpoints[]`, each requiring `name` and `subject` and optionally carrying `metadata` and
  `queue_group`. `stats_response` requires `type, name, id, version, started, endpoints`; `started` is
  RFC3339 `date-time`; each endpoint entry requires `name, subject, num_requests, num_errors,
  last_error, processing_time, average_processing_time` and may carry `queue_group` and a free-form
  `data`. The nanosecond units are in the schemas' `$comment` fields, not their descriptions.
- **`description` is required by the schema** while ADR-32 calls it optional at creation — compatible,
  because an empty string satisfies the schema, but worth knowing when validating a reply.
- **The reserved-prefix claim.** "`$SRV` is a reserved subject prefix: do not publish to it yourself.
  The framework owns the entire `$SRV` tree … Who may even see `$SRV` across account boundaries is a
  separate question, covered in Security" (`discovery.md:469`). The server enforces nothing of the
  kind (run B1), and the Security chapter does not cover it (docs issue #111).
- **Service latency is a different mechanism.** "the server can emit service-latency advisories that
  measure round-trip time from outside the service … their schemas live in Reference"
  (`observability.md:403`) — the schemas are not there, and the page never says that service latency
  is a feature of a **cross-account service export** with `latency {}` configured, not of the
  framework. See [[advisories]] and [[system-subjects]].
- **The reference overview lists capabilities the schemas do not have** (`reference/services.md:30–51`):
  "Resource utilization", "Request counts and rates", "Service availability status", "Response time
  measurement", "Structured logging and metrics", "API version management support", and "Services
  announce themselves on startup". None of these exist in the three schemas or in ADR-32 (docs issue
  #112). `stats-response.md:51` also reads "The time the service was **stated**" — the typo is in the
  schema itself.

## Practical takeaways

- To count instances, ask `$SRV.PING.<name>` and collect by deadline; a plain request-reply gives you
  one instance and no warning.
- To read a service's health from outside, the fields you can scrape are the five counters per
  endpoint per instance — there is no rate, no histogram and no aggregate. Anything else is your own
  `StatsHandler` `data` blob.
- Check `Nats-Service-Error-Code` on every reply. A service error and a success are the same kind of
  message; only the headers differ, and the 503 is a third, different shape.

## Notable quotes

- "A service doesn't publish to `$SRV` itself; it subscribes there and replies to your requests."
  (`discovery.md:18`)
- "five running instances appear as one" (`discovery.md:325`)
- "the server keeps no aggregate for you" (`observability.md:401`)

## Relevance to the wiki

The reference half of [[services-framework]]: the subject tree, the three response shapes and the two
error headers, all of which an operator reads in CLI output or scrapes. It is also where three docs
issues come from — the invented capabilities on the reference overview (#112), the `$SRV` reservation
the server does not enforce (#113), and the promised chapters that do not exist (#111).

## Questions it answers

134 (with [[services-on-core-nats]]), 188, 190, 191.

## Pages touched

[[services-framework]], [[services-on-core-nats]], [[system-subjects]], [[nats-timeout]],
[[subject-permissions]], [[advisories]], [[metrics]], [[nats-cli]]
