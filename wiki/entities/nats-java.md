---
title: nats.java
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.java 2.26.2
verified-on: 2026-08-31
tags: [client, tier-1, java, jvm, kotlin, scala, jnats]
aliases: [nats.java, "nats-io/nats.java", java client, jnats, "io.nats:jnats"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-core-nats-request-reply]
created: 2026-08-31
updated: 2026-09-03
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


## Related

[[orbit]] · [[nats-go]] · [[nats-server]] · [[consumer]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] · [[s-docs-core-nats-request-reply]]
