---
title: Services framework
type: concept
area: [core, clients, monitoring]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; the framework is client-side and needs no server feature
verified-against: nats-server 2.14.6, nats.go v1.53.1, nats CLI 0.4.0, ADR-32 rev 6
verified-on: 2026-09-04
tags: [services, micro, "$SRV", PING, INFO, STATS, endpoints, groups, queue-group, "Nats-Service-Error", "Nats-Service-Error-Code", discovery, stats, adr-32]
aliases: [micro, NATS micro, micro framework, service API, services API, nats micro, "$SRV", service discovery, micro service, nats service]
sources: [s-adr-32-service-api, s-docs-services-framework, s-docs-services-discovery-and-stats, s-docs-services-scaling, s-nats-server-services-observed, s-gh-4984-micro-with-jetstream]
created: 2026-09-04
updated: 2026-09-04
---

# Services framework

**A "service" is a convention in the client libraries, not a feature of the server: a named, versioned
request/reply responder that joins a queue group, answers three discovery verbs under `$SRV`, and
keeps per-endpoint counters.** `nats-server` knows nothing about it — `$SRV` appears nowhere in the
server's source, there is no registry, and nothing has to be enabled (source:
[[s-nats-server-services-observed]], [[s-docs-services-framework]]).

Everything an operator can see, secure or monitor is therefore a **subject**. This page is what those
subjects are and what they answer. For designing a service layer with them, see
[[services-on-core-nats]].

## What it is

The module is `micro` in Go and Python and `service`/`services` in JavaScript, Java, Rust and C#
(source: [[s-docs-services-framework]]); the C client implements `micro` too, though the docs' language
list omits it. The specification is **ADR-32**, revisions 1–6 between 2022-11-23 and 2025-02-17, and it
is the only versioned source: the docs' eleven services pages name no server version, no client version
and no ADR (source: [[s-adr-32-service-api]]).

Creating a service takes three things — a `name` ("really the *kind* of the service", restricted to
`A-Z a-z 0-9 - _`), a `version` (a real SemVer string), and an optional `description` — plus an
auto-generated `id` that identifies **this running copy**. Both the name rule and the SemVer rule are
validated at creation and a violation fails the call, so the service never starts. Optional `metadata`
is a string map that is **immutable once set** (source: [[s-adr-32-service-api]],
[[s-docs-services-framework]]).

## The subjects it creates

Each endpoint answers on one subject, built from the group it is in:

| what you declare | the subject |
|---|---|
| endpoint `check` on the service | `check` (the name is the default subject) |
| endpoint `check` in group `orders.inventory` | `orders.inventory.check` |
| endpoint `check` in group `inner` in group `outer` | `outer.inner.check` |
| endpoint with an explicit subject, on the service | that subject, no prefix |

"The subject a caller sends to is always `{group}.{endpoint}`. There's no separate routing layer"
(source: [[s-docs-services-framework]]). A group name must be a valid subject and may not contain `>`.

Alongside those, every instance subscribes to **nine** discovery subjects — three verbs at three
levels:

```
$SRV.PING     $SRV.PING.<name>     $SRV.PING.<name>.<id>
$SRV.INFO     $SRV.INFO.<name>     $SRV.INFO.<name>.<id>
$SRV.STATS    $SRV.STATS.<name>    $SRV.STATS.<name>.<id>
```

**Ten subscriptions is the floor for one instance with one endpoint**, and one more per further
endpoint — measured on 2.14.6 in `/subsz?subs=1&acc=$G` (source:
[[s-nats-server-services-observed]]). None of the nine carries a queue group, which is exactly why
discovery is a broadcast: every instance that matches answers.

A service never publishes to `$SRV`. "A service doesn't publish to `$SRV` itself; it subscribes there
and replies to your requests" (source: [[s-docs-services-discovery-and-stats]]). Nothing is announced
on startup, and there is no heartbeat — a service is discovered only when something asks.

## The three verbs, and what comes back

- **`PING`** — presence. The reply carries `type`, `name`, `id`, `version` and `metadata` and nothing
  else. There is no round-trip figure in it; the caller measures that itself.
- **`INFO`** — shape. Adds `description` (required by the schema) and `endpoints[]`, each with `name`,
  `subject`, `queue_group` and `metadata`.
- **`STATS`** — load. Adds `started` (RFC3339, UTC) and `endpoints[]` with the counters below.

The `type` strings are `io.nats.micro.v1.ping_response`, `…info_response` and `…stats_response`
(source: [[s-adr-32-service-api]], [[s-docs-services-discovery-and-stats]]).

**Discovery is broadcast, not load-balanced**, and this is the trap: a plain request-reply call takes
the first reply and stops, so "five running instances appear as one". Collect by deadline or by count
instead — `nats request '$SRV.INFO' '' --replies=0` waits out the timeout and prints every reply. Even
`nats service info <name>` shows only one instance when several are running; `nats service list` and
`nats service ping` gather properly (source: [[s-docs-services-discovery-and-stats]],
[[s-nats-server-services-observed]]).

## The counters, and their units

Per **endpoint**, per **instance** — never per service, and never aggregated by the server:

| field | what it holds |
|---|---|
| `num_requests` | requests this endpoint handled |
| `num_errors` | how many ended in a service error |
| `last_error` | the most recent error, formatted `"<code>:<description>"` |
| `processing_time` | total handler time, **integer nanoseconds** |
| `average_processing_time` | `processing_time / num_requests`, **integer nanoseconds** |
| `queue_group` | the group this endpoint joined (`""` when disabled) |
| `data` | free-form JSON from the service's own `StatsHandler` |

`last_error` is present as an empty string when there has been none — the schema marks it required
inside each endpoint entry. `Reset()` zeroes the counters **and** the `started` timestamp, so a
dashboard that assumes counters only grow will see a drop. A service-wide total is the reader's job:
sum across ids (source: [[s-docs-services-discovery-and-stats]], [[s-nats-server-services-observed]]).

There is no Prometheus bridge for these in the NATS tree. `nats service stats <name> --json` is the
scrape surface; [[metrics]] covers what the server itself exports, which does not include them.

## A service error is a delivered reply

A handler that fails answers with two headers — `Nats-Service-Error` (a human description) and
`Nats-Service-Error-Code` (a value "always safe to parse as a number") — and the framework bumps
`num_errors` and `last_error` in the same step (source: [[s-adr-32-service-api]],
[[s-docs-services-discovery-and-stats]]).

On the wire the difference from a missing service is stark. Both are `HMSG`; only the headers differ:

```
a service error   HMSG _INBOX.RAW.1 1 92 109
                  NATS/1.0
                  Nats-Service-Error: order total must be positive
                  Nats-Service-Error-Code: 400

                  {"field":"total"}

no responders     HMSG _INBOX.RAW.2 1 55 55
                  NATS/1.0 503
                  Nats-Subject: orders.inventory.nosuch
```

(source: [[s-nats-server-services-observed]], observed on 2.14.6). The 503 comes from the **server**
and has an empty body; the service error comes from the **service** and carries whatever body the
handler sent. A caller that only asks "did I get a reply" reads every service error as a success —
ADR-32 makes checking the headers a *must*. See [[nats-timeout]] for telling the three outcomes apart
in triage, and [[request-reply]] for the 503 itself.

## Scaling: the queue group is the whole mechanism

Every endpoint joins a queue group; the default name is **`q`**, shared by every instance of the
service, so a second copy load-balances with the first with no configuration at all. The name is set
at three levels, each overriding the one above: the service sets a default, a group overrides it for
its endpoints, an endpoint overrides it again; unset falls back to `q` (source:
[[s-docs-services-framework]]).

Disabling the queue group makes the endpoint a plain subscription, so **every instance answers every
request** — one reply per instance, of which a plain caller keeps one. Measured: one request to a
queue-group-disabled endpoint on two instances returned two replies (source:
[[s-nats-server-services-observed]]). That is fan-out, not scaling; [[queue-groups]] has the
selection rule.

Two things about the selection are worth knowing before sizing a fleet, because the docs state both
wrongly (docs issues #86 and #114):

- **The pick is random per request, not readiness-aware.** The server chooses a member with
  `fastrand` and never looks at whether a handler is busy.
- **A blocked member keeps its share.** Two instances with 3-second handlers, eight simultaneous
  requests: every request was delivered at once, split 3 / 5, each instance worked through its own
  queue one at a time, and **four of the eight callers timed out** while their replies arrived at
  20 s, 23 s and 26 s (source: [[s-nats-server-services-observed]], run C7).

Within one instance, though, **a blocked endpoint does not block its siblings**: each endpoint is its
own subscription with its own dispatcher, so `check` answered in 327 µs while `slow` was three seconds
into a block on the same connection (measured on nats.go v1.53.1; other clients may differ).

## Stopping one: `Stop()` drains, a signal does not

`Stop()` removes every subscription at once — the endpoints *and* the nine discovery subjects — and
returns in about a millisecond, leaving in-flight handlers running in the background. Measured: after
`Stop()` returned, the endpoint and `$SRV.PING` both answered `No responders` and `/subsz` showed none
of the instance's subscriptions, while the handler that was mid-flight still replied three seconds
later, because the process stayed alive (source: [[s-nats-server-services-observed]], run D1).

So the shutdown order is: `Stop()`, then wait for in-flight work, then exit. Exiting when `Stop()`
returns drops the work after all. A `kill -9` mid-handler loses it and the caller is told **nothing** —
the request was already accepted, so there is no no-responders answer and the caller only sees a
timeout. `nats service serve` has no graceful stop: Ctrl-C closes the connection abruptly, because
natscli never calls `Stop()`.

A rolling upgrade follows from this: start the new instances, then stop the old ones one at a time,
so the group is never empty. Endpoints and metadata are immutable, so any change of shape — a rename,
a new subject, different metadata — is a rolling restart, not a reload.

## What the operator has to configure: permissions

Permissions are the only isolation there is, and discovery and invocation separate cleanly:

```
# the callers
publish:   { allow: ["orders.>", "_INBOX.>"] }
# the tooling that discovers
publish:   { allow: ["$SRV.>", "_INBOX.>"] }
```

Measured on 2.14.6: a user without `$SRV.>` could call the endpoint and not discover; a user with only
`$SRV.>` could discover and not call. The server logged
`Publish Violation - Subject "$SRV.PING"`, and **neither client was told anything** — the refusal
arrives as an async error the CLI does not print, so it looks like a timeout (source:
[[s-nats-server-services-observed]]). [[subject-permissions]] has the general rules.

Two things follow that the docs do not say:

- **`$SRV` is not reserved by the server.** An ordinary client may publish to it (`Published 5 bytes
  to "$SRV.PING"`) and an ordinary subscriber on `$SRV.>` sees every discovery request, reply inbox
  included. The reservation is a convention among client libraries (docs issue #113).
- **An endpoint subject is an ordinary subscription.** A publish with no reply subject still runs the
  handler; the reply goes nowhere. A service cannot tell a request from a fire-and-forget publish.

## Across a cluster, a leafnode and an account

Discovery and endpoint subjects are ordinary subjects, so they propagate the way any subject does. A
service on a leaf node was listed, pinged and called from the hub with no configuration at all — but
**the queue group prefers the local member**: with one instance on each side, 8 of 8 requests from the
hub went to the hub instance and 8 of 8 from the leaf to the leaf instance, while discovery saw both
from either side (source: [[s-nats-server-services-observed]], run E). That is the ordinary
queue-group locality rule of [[queue-groups]] and [[leafnode]], and it means placing an instance beside
its callers keeps their traffic local whether or not you meant it to.

Across an **account**, the endpoint subject has to be exported and imported like any other service
(see [[cross-account-sharing]]), and `$SRV` has to be shared separately if the other account is to
discover anything. ADR-32 asks for an overridable prefix "in order to enable targetting tools to work
across accounts", but nats.go v1.53.1 declares `APIPrefix = "$SRV"` as a `const` with no configuration
path, and no docs page mentions an override at all (source: [[s-adr-32-service-api]],
[[s-nats-server-services-observed]]).

**Service latency is a different thing entirely.** The `io.nats.server.metric.v1.service_latency`
advisory is a server feature of a cross-account service export with `latency {}` configured; it has
nothing to do with the framework's counters. See [[advisories]] and [[system-subjects]].

## The CLI

```
nats service list [<name>] [--json]      # every service and instance, gathered by deadline
nats service info <name> [<id>] [--json] # one instance (the first to reply, unless <id> is given)
nats service stats <name> [<id>] [--json]
nats service ping [<name>]               # one line per instance — the count of live members
nats service request <name> <endpoint> [payload]
nats service serve <name>                # a demo echo service on <name>.echo; no graceful stop
```

`micro` is an alias for `service`; ADR-32 asks tooling to say "service". `nats request '$SRV.INFO' ''
--replies=0` is the raw form when you want the bodies. See [[nats-cli]].

## Limits and failure modes

- **Nothing survives an instance.** A service is at-most-once request/reply and stores nothing; a
  crash loses in-flight work with no signal to the caller. Durability is [[stream]]'s job — see
  [[core-nats-delivery]] and [[worker-pool]] for the JetStream-backed sibling. There is no supported
  way to give the framework acks: asked in public whether a handler could ack and nak against
  JetStream, a maintainer answered "roughly planned for a future itteration … No immediate plans" in
  2024 and "Still not on the immediate roadmap" in 2025 (source:
  [[s-gh-4984-micro-with-jetstream]]).
- **Instances share no memory.** Counters, caches and any "remaining stock" in a handler drift apart
  per instance; shared state belongs in a database or a [[key-value]] bucket.
- **A slow handler is a queue, not a rejection.** See the sizing note in [[services-on-core-nats]].
- **The name and version are validated once, fatally.** A space in the name or a `v1` version fails
  `AddService`; nothing starts.
- **There is no configuration reference.** Seven places in the docs hand off to a Reference page for
  "every service configuration field and its valid range"; no such page exists, and ADR-32 plus the
  three response schemas in `raw/jsm-go/` are the whole public specification (docs issue #109).

## Related

[[services-on-core-nats]] · [[request-reply]] · [[queue-groups]] · [[core-nats-delivery]] ·
[[nats-timeout]] · [[subject-permissions]] · [[system-subjects]] · [[cross-account-sharing]] ·
[[worker-pool]] · [[nats-cli]] · [[nats-go]] · [[advisories]] · [[metrics]]

## Sources

[[s-adr-32-service-api]] · [[s-docs-services-framework]] · [[s-docs-services-discovery-and-stats]] ·
[[s-docs-services-scaling]] · [[s-nats-server-services-observed]] · [[s-gh-4984-micro-with-jetstream]]
