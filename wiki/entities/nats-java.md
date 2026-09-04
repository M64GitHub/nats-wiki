---
title: nats.java
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.java 2.26.2
verified-on: 2026-09-04
tags: [client, tier-1, java, jvm, kotlin, scala, jnats]
aliases: [nats.java, "nats-io/nats.java", java client, jnats, "io.nats:jnats"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-core-nats-request-reply, s-client-releases-and-issues]
created: 2026-08-31
updated: 2026-09-04
---

# nats.java

The **JVM client** — "usable from Kotlin and Scala" (source: [[s-docs-ecosystem]]). Published to
Maven Central under a different name from its repo: the artifact is `io.nats:jnats`.

## Where it fits

Tier 1. The JVM is where NATS most often meets an existing Kafka or JMS estate, so this client tends
to arrive with a bridge ([[s-docs-ecosystem]] lists `nats-kafka` and `nats-java-vertx-client`).

## Facts

| | |
|---|---|
| repo | `nats-io/nats.java` |
| tier | **1** |
| latest release | **2.26.2**, 2026-08-13 (snapshot line 2.26.3-SNAPSHOT) |
| licence | Apache-2.0 |
| artifact | **`io.nats:jnats`** on Maven Central |
| API docs | `javadoc.io/doc/io.nats/jnats` |

```groovy
dependencies { implementation 'io.nats:jnats:2.26.2' }
```

```xml
<dependency><groupId>io.nats</groupId><artifactId>jnats</artifactId><version>2.26.2</version></dependency>
```

The docs' install snippet pins **2.25.2**, one minor behind the current release — quote it as an
example, not as the version to use (source: [[s-docs-getting-started]]).

## What an operator needs to know

- **The artifact name is `jnats`, not `nats.java`.** Dependency scanners, SBOMs and CVE feeds key on
  `io.nats:jnats`; searching for the repo name finds nothing.
- **"Simplification" is a real API boundary.** The README carries a `Simplification` section
  alongside `Consumer Info Calls`, `Subject Validation` and `Connection Options Executors` — the
  modern JetStream surface is separate from the original one, as in [[nats-go]]. Which one an
  application is on changes its consumer behaviour.
- **It has an Orbit counterpart** (`synadia-io/orbit.java`), and the README documents the Client/Orbit
  split directly — see [[orbit]].

## What bites you

- **A missing service is a timeout, not a no-responders error, unless you ask.** The Java client
  needs the `reportNoResponders()` connect option to surface the server's `503` (as a
  `JetStreamStatusException` with status 503); without it a request to a subject nobody is subscribed
  to waits out its full timeout — the docs' word (`learn/core-nats/request-reply.md:380`,
  `concepts/request-reply.md:1040–1046`; source: [[s-docs-core-nats-request-reply]]). Every other
  client the docs cover reports no responders by default — [[request-reply]].



## What bites you — the connection

Read from the last ten releases (2.23.x → 2.26.2, 2026-08-13) and the open issues at 2026-09-04
(source: [[s-client-releases-and-issues]]). The one above — no-responders is opt-in — is the docs'
word; these are the release record's.

- **`drain()`'s future says `true` even when the drain timed out.** Open issue **#1616**
  (2026-08-18). A shutdown that branches on the boolean cannot tell a completed drain from an expired
  one, so in-flight work can be dropped by a path that reported success. Until it is fixed, measure
  the elapsed time against the `Duration` you passed rather than trusting the result.
- **A DNS name with several A records used to burn the reconnect budget once per address.** Fixed in
  **2.26.1** (2026-08-04, #1595): "Count connect failure once per server, not once per resolved IP".
  Before it, a `nats://nats.svc:4222` that resolves to three pods spent `maxReconnects` three times as
  fast — exactly the shape a Kubernetes headless service produces ([[nats-helm-charts]]).
- **`max_payload` counts the headers.** "'Payload Size' includes header bytes, not just data" —
  **2.25.2** (2026-03-03, #1525). A publisher sized against the server's `max_payload`
  ([[config-keys]] · [[client-defaults]]) with large headers was measuring the
  wrong number before that release.
- **Subject validation arrived at 2.25.1** (2026-01-15, #1501, plus #1503 "Subject validation readme
  and backfill"). Before it, Java published a subject with a space as written and the server split it
  into subject and reply-to — [[subjects-and-wildcards]].
- **Reconnect has been reworked twice recently**: "fix race condition in reconnect" (2.25.2, #1523),
  "Reconnect Delay Behavior and options cleanup" (2.26.0, #1578) and "Address forceReconnectImpl
  reader/writer stop race" (2.26.1, #1601). A JVM service pinned below 2.25.2 is on the pre-fix path.
- **`discardWhenFull` miscounted until 2.25.1** ("[bug] Properly count message/bytes when in
  discardWhenFull mode", #1498) — so the pending-limit accounting a slow-consumer alarm reads was
  wrong on the mode designed for slow consumers ([[slow-consumer-in-the-client]]).
- **The docs' install snippet is a minor behind** (2.25.2 against 2.26.2) — quote it as an example,
  not as the version to pin.

## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[consumer]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-docs-core-nats-request-reply]] · [[s-client-releases-and-issues]]
