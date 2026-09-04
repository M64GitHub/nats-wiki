---
title: "docs: the Services chapter — what a service is, and how endpoints and groups shape its subjects"
type: summary
area: [core, clients]
source-url: https://docs.nats.io/learn/services
source-path: raw/nats-docs/learn/services.md
author: docs.nats.io
date: 2026-08-31
version: ""
article: "learn/services.md (index), your-first-service.md, endpoints-and-groups.md, where-next.md — read together; the chapter states it is unversioned"
tags: [services, micro, endpoints, groups, queue-group, semver, metadata, immutable]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# docs: the Services chapter — what a service is, and how endpoints and groups shape its subjects

Four of the six pages of `learn/services/`: the chapter index, the first service, endpoints and
groups, and the closing checklist. The other two are in
[[s-docs-services-discovery-and-stats]] and [[s-docs-services-scaling]].

**The chapter is unversioned by design**: "This chapter is unversioned and concept-first. The exact
config fields, their valid ranges, and the wire format of the discovery verbs live in **Reference**,
which is versioned and exhaustive" (`where-next.md:24`). Not one nats-server version, client version
or ADR number appears in the eleven services pages, so every date and rule here is pinned from
[[s-adr-32-service-api]] and [[s-nats-server-services-observed]], never from the chapter.

## Key claims

- **What the framework adds.** A hand-written responder "is only a function on a wire. It has no name
  you can look up and no version" (`services.md:4`). A service is "a named, versioned handler that the
  server can discover, that reports its own stats, and that load-balances across as many copies as you
  start. You add no new infrastructure. A service is still request-reply underneath" (`:6`).
- **Nothing to enable.** "The Services framework needs nothing special enabled. It runs on ordinary
  request-reply, so a plain `nats-server` is enough" (`services.md:47`).
- **The module name differs per client**: `micro` in Go and Python, `service`/`services` in
  JavaScript, Java, Rust and C# (`services.md:6`). C is not in that list although the C client
  implements `micro` and is the only language whose code survived the docs fetch.
- **The CLI cannot host a service**: "Building the service itself … is a client-library task"
  (`services.md:48`); `nats service serve` "only runs a demo echo service on `<name>.echo`, not a
  named endpoint on a subject you choose" (`your-first-service.md:39–41`). Confirmed by run A.
- **Name, version, id.** `AddService` takes `Name`, `Version` ("a SemVer string, `1.0.0`") and
  `Description` (`your-first-service.md:12–14`). The `Name` is "the kind of service"; the id is
  "an auto-generated NUID like `IcpremQQGTYS0fK1iyfQ86`. You never set it" (`:16`).
- **Validation is at creation, and fatal**: "A `Name` of `Order Inventory` (with a space) or a
  `Version` of `v1` (not SemVer) fails the `AddService` call outright; the service never starts"
  (`your-first-service.md:315`). Metadata "is immutable once set … you stop the service and start a
  new one" (same line).
- **What creating one endpoint does**: it "joins the endpoint to the default queue group `"q"`, and
  subscribes the discovery verbs under `$SRV`" (`your-first-service.md:33–35`, repeated at `:77`,
  `:118`, `:322`). Run A9 counts those subscriptions: nine, plus one per endpoint.
- **The subject rule.** "the endpoint's subject **defaults to its name**" (`endpoints-and-groups.md:12`,
  `:118`). With a group, "The subject a caller sends to is always `{group}.{endpoint}`. There's no
  separate routing layer; the group is just a way to build the subject" (`:206`). Nested groups give
  `{outer}.{inner}.{endpoint}` (`:208`).
- **Three levels of queue group.** "The queue group is set at three levels, and each level overrides
  the one above it. The service sets a default. A group can override it for every endpoint under it. A
  single endpoint can override it again. If none of them set anything, the endpoint falls back to
  `"q"`" (`endpoints-and-groups.md:214`); "The default name is `"q"`" (`:212`).
- **Disabling the queue group is broadcast, not scaling.** "an endpoint with no queue group is a plain
  subscription, so **every instance** receives **every** request … the caller gets one reply per
  instance and the rest are noise. Do not disable the queue group to 'make sure a request is handled'"
  (`endpoints-and-groups.md:309–311`). Run C6 measures it: two instances, two replies.
- **Endpoints are immutable.** "There's no remove. You can't detach an endpoint, rename it, or change
  its subject on a running service. The same holds for the metadata" (`:389`); "There is no
  `nats service remove-endpoint`" (`:426`); a shape change is `svc.Stop()` and a new service (`:430`).
  ADR-32 revision 6 (2025-02-17) allows endpoints to be *added* after start.
- **The service error headers**: a failure is "a response that carries `Nats-Service-Error` and a
  `Nats-Service-Error-Code` header whose value is always safe to parse as a number (use `400` for bad
  input)" (`your-first-service.md:207`).
- **The production checklist** (`where-next.md:54–89`) collects the chapter's pitfalls: validate input
  and answer bad input with a service error; use a valid `Name` charset and a real SemVer `Version`;
  override queue groups deliberately and never disable one on a responder; treat endpoints and
  metadata as immutable; collect discovery replies "with a deadline-or-count loop"; never publish
  under `$SRV`; check `Nats-Service-Error-Code` on every reply; aggregate stats across ids and
  remember `Reset()` zeroes them; protect shared external state; keep handlers non-blocking or run
  more instances.

## Practical takeaways

- The only thing the server sees is subjects: `{group}.{endpoint}` for work and `$SRV.*` for
  discovery. That is what you write permissions, imports and monitoring against.
- Endpoint shape is fixed at start, so a rename or a re-subject is a rolling restart — plan the
  subject layout with the same care as a stream name.
- `q` is shared by every instance of a service by default, which is why a second copy scales it with
  no configuration at all; an override splits the load-balancing set, and disabling it stops
  load-balancing entirely.

## Notable quotes

- "It has no name you can look up and no version." (`services.md:4`)
- "The subject a caller sends to is always `{group}.{endpoint}`. There's no separate routing layer."
  (`endpoints-and-groups.md:206`)
- "Do not disable the queue group to 'make sure a request is handled': that's exactly what the default
  `"q"` already guarantees, with one handler, not N." (`endpoints-and-groups.md:309`)

## Relevance to the wiki

The narrative source under [[services-framework]] — the subject layout, the queue-group precedence and
the immutability rules an operator plans a deployment around. Its unversioned claims are dated from
[[s-adr-32-service-api]] and measured in [[s-nats-server-services-observed]]. Four docs issues came out
of it: the missing configuration reference (#109), the `WithEndpointQueueGroupDisabled` cross-reference
that points at a page which never names it (#110), and two in the sibling summaries.

## Questions it answers

134 (with [[services-on-core-nats]]), 188, 189.

## Pages touched

[[services-framework]], [[services-on-core-nats]], [[queue-groups]], [[request-reply]],
[[subject-permissions]], [[nats-cli]]
