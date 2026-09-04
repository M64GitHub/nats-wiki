---
title: "ADR-32 — Service API"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-32.md
source-path: raw/adr/ADR-32.md
author: "@aricart"
date: 2022-11-23
version: ""
article: "ADR-32, revisions 1–6 (2022-11-23 → 2025-02-17); status Implemented; tags client, spec"
tags: [services, micro, "$SRV", queue-group, discovery, endpoints, groups, adr]
aliases: [ADR-32, "Service API", micro]
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# ADR-32 — Service API

The specification behind the services framework (`micro` in Go and Python, `service`/`services`
elsewhere): the configuration a service takes, the `$SRV` discovery tree, the three response types,
and the queue-group rules. It is the **only versioned source** for any of this — the docs' eleven
services pages cite no ADR, no server version and no client version.

Six revisions: 1 initial (2022-11-23), 2 configurable queue group (2023-09-12), 3 version regex
(2023-10-07), 4 explicit naming (2023-11-10), 5 optional queue groups and immutable metadata
(2024-08-08), 6 endpoints may be added after the service has started (2025-02-17).

## Key claims

- **Nothing runs on the server.** A service is a client-library convention over ordinary
  request/reply and queue groups: the framework "will automatically create a subscription to handle
  discovery and monitoring requests" (L75–76). There is no server-side registry, and the ADR asks for
  no server change.
- **Configuration** (L34–48): `name` — "really the _kind_ of the service", restricted to
  `A-Z, a-z, 0-9, dash, underscore`; `version` — a SemVer string validated with "one of the official
  semver regex"; `description` (optional); `metadata` — an optional string map, "Must be immutable
  once set", implemented like ADR-33's stream/consumer metadata; `statsHandler` — an optional function
  returning JSON-serialisable data per endpoint; `queueGroup` — "overrides a default queue group".
- **Identity**: `name` is shared by every instance of the same kind; "On startup a service is assigned
  an unique `id`" that "allows for a specific instance of the service to be addressed" (L69–71). The
  ADR does not say the id is a NUID — that is a client implementation choice.
- **The `$SRV` tree** (L78–95): three verbs, `PING`, `STATS`, `INFO`, at three levels —
  `$SRV.PING|STATS|INFO`, `$SRV.PING|STATS|INFO.<name>`, `$SRV.PING|STATS|INFO.<name>.<id>`. A service
  "should respond to" all three that match it. "The verbs are uppercase"; the prefix "will honor
  whatever case was specified".
- **The prefix is meant to be overridable**: "Note that this prefix needs to be overridable much in
  the way as we do for `$JS`, in order to enable targetting tools to work across accounts" (L78–81).
  This is stated as a requirement; nats.go v1.53.1 declares `APIPrefix = "$SRV"` as a `const` with no
  configuration path (`micro/service.go:264–265`), and no docs page mentions an override at all.
- **The standard fields** on every response (L105–130): `type`, `name`, `id`, `version`, `metadata`.
- **INFO** adds `description` and `endpoints: EndpointInfo[]`, each with `name`, `subject`,
  `queue_group`, `metadata` (L134–177). Type `io.nats.micro.v1.info_response`.
- **PING** returns only the standard fields; "The intention of `PING` is for clients to calculate RTT
  to a service and discover services" (L181–195). Type `io.nats.micro.v1.ping_response`.
- **STATS** adds `started` ("ISO Date string when the service started in UTC timezone") and
  `endpoints: EndpointStats[]` (L199–263), each with `name`, `subject`, `queue_group`, `num_requests`,
  `num_errors`, optional `last_error`, optional `data` from the stats handler, `processing_time`
  ("Total processing_time for the service") and `average_processing_time` ("the total processing_time
  divided by the num_requests"), both typed `Nanos`. Type `io.nats.micro.v1.stats_response`.
- **Groups and endpoints** (L267–318): a group "serves as a common prefix to all endpoints registered
  in it"; a group name "should be a valid NATS subject or an empty string, but cannot contain `>`".
  An endpoint's subject defaults to its name; with a group it is `{group_name}.{name}`; nested groups
  concatenate. "Endpoints can be added after the service has been created and started. For now, there
  is no option to remove an endpoint or a group" (L269–271). Endpoint `metadata` "Must be immutable
  once set".
- **Queue groups** (L303–309, L343–351): every handler runs "under the default queue group `q`", "so
  that in order to scale up or down all the user needs to do is add or stop services". A service-level
  `queueGroup` overrides the default, a group overrides the service, an endpoint overrides the group.
  "Clients should provide an idiomatic way to set no `queueGroup`" — then "the subscription for the
  endpoint will be a normal subscribe instead of a queue subscribe". Running instances "with different
  `queueGroup`" is the ADR's way to fan a request to several services and take the quickest.
- **Errors** (L322–341): a service **must** include the headers `Nats-Service-Error` (a
  human-readable description) and `Nats-Service-Error-Code` ("a value that is always safe to parse as
  a number"). "Clients making request from the service _must_ check if the response is an error by
  looking for these headers." Libraries "_must_ provide an error formatting function".
- **Lifecycle** (L52–67): `stop(error?)` — "Stop should always drain its service subscriptions";
  `reset()`; `info()`; `stats()`; a done callback, "independent of the NATS connection"; and "it should
  be possible to run multiple services under a single connection".
- **`$SRV` is off-limits to handlers**: "Handler subject does not contain the `$SRV` prefix. This
  prefix is reserved for internal handlers" (L351–353) — a convention for framework authors, not a
  server rule.
- **Dispatch is not serialised by the framework**: "no assumption is made on whether returning from
  the callback signals that the request is completed. The framework will dispatch requests as fast as
  the handler returns" (L355–357).
- **Naming** (L359–363): clients and tooling "should use the term 'service' or 'services'" — which is
  why `nats service` is canonical and `nats micro` only an alias.

## Practical takeaways

- Everything an operator can see is a subject: nine `$SRV` subscriptions per instance and one
  subscription per endpoint. Permissions are the only isolation mechanism there is.
- The queue group is the whole scaling story, and `q` is the default every instance shares —
  so a second copy of a service load-balances with the first without any configuration.
- Immutable metadata and immutable endpoints mean a shape change is a rolling restart, never a reload.
- `Nats-Service-Error` makes a failure a *delivered reply*: a caller that only checks for a transport
  error will read every service error as a success.

## Notable quotes

- "really the _kind_ of the service. Shared by all the services that have the same name" (L34–36).
- "this prefix needs to be overridable much in the way as we do for `$JS`, in order to enable
  targetting tools to work across accounts" (L78–81).
- "Stop should always drain its service subscriptions" (L55–57).
- "The framework will dispatch requests as fast as the handler returns" (L357).

## Relevance to the wiki

The version-bearing authority under [[services-framework]] and [[services-on-core-nats]]: every rule
the docs state without a date is dated here, and the two facts the docs never state — the overridable
prefix and the `data` stats field — exist only in the ADR. It also settles what
[[s-docs-services-discovery-and-stats]] can and cannot claim about the response schemas.

## Questions it answers

134 (with [[services-on-core-nats]]), 188, 189, 191.

## Pages touched

[[services-framework]], [[services-on-core-nats]], [[queue-groups]], [[request-reply]],
[[system-subjects]], [[subject-permissions]], [[nats-cli]], [[nats-go]]
