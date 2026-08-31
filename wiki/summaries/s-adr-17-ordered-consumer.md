---
title: "ADR-17 — Ordered Consumer"
type: summary
area: [jetstream, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-17.md
source-path: raw/adr/ADR-17.md
author: "@scottf"
article: "ADR-17: Ordered Consumer"
date: 2021-09-29
version: ""              # the ADR names no server version
tags: [ordered-consumer, gap-detection, heartbeats]
aliases: [ADR-17, ordered consumer]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-17 — Ordered Consumer

Status **Implemented**. Short ADR (53 lines) defining a **client-side** construct: an ordered push
subscription that detects a gap in the consumer sequence and silently rebuilds itself.

## Key claims

- The subscription **tracks the last good stream and consumer sequences**. When it observes a gap
  it **closes the subscription, releases its consumer, and creates a new one starting at the proper
  stream sequence**.
- **If heartbeats are missed** the consumer might be gone — deleted, lost after a reconnect, or
  lost to a node restart — and it is **recreated from the last known stream sequence**.
- The state may optionally be exposed to the user.

### It is deliberately restricted

An ordered consumer **cannot** be:

- a **pull** consumer;
- a **durable** consumer;
- bound, or "direct";
- used with **queues / deliver groups**.

### The configuration the client forces

If the user supplies a consumer configuration it **must be validated and rejected on mismatch**:

| field | rule |
|---|---|
| `durable_name` | must **not** be provided |
| `deliver_subject` | must **not** be provided |
| `ack_policy` | must not be provided, or must be `none`; set to `none` if absent |
| `max_deliver` | must not be provided, or must be `1`; set to `1` if absent |
| `flow_control` | must not be provided, or must be `true`; set to `true` if absent |
| `mem_storage` | must not be provided, or must be `true`; set to `true` if absent |
| `num_replicas` | must **not** be provided; set to `1` |

Set without erroring:

| field | value |
|---|---|
| `idle_heartbeat` | **5 seconds** if not provided |
| `ack_wait` | "something large like **22 hours**" (matching the Go implementation) |

## Why an operator cares

- An ordered consumer is **ephemeral, memory-storage, R1, `ack_policy: none`**. It leaves no
  durable state, and its consumer disappears and reappears under a new name whenever a gap or a
  heartbeat miss occurs.
- That churn is **visible in `nats consumer ls` and in consumer-count metrics** as short-lived
  consumers appearing and vanishing — which is exactly the "many short-lived consumers" pattern
  named as a memory cost in [[s-synadia-jetstream-memory-patterns]].
- `ack_wait` of ~22 hours means a stuck ordered consumer will **not** show up as a redelivery
  problem; it will look idle.

## Relevance to the wiki

The source for [[ordered-consumer]], and the explanation for a class of "why do consumers keep
appearing and disappearing" observations. KV watches and history are built on ordered consumers
(see [[s-adr-8-key-value-store]]), so this ADR also explains the consumer churn a busy KV bucket
generates.

## Questions it answers

None in the bank directly. It is a prerequisite for the KV rows (Q69, Q70) because watch and key
listing are ordered consumers underneath.

## Pages touched

[[ordered-consumer]] · [[consumer]] · [[key-value]]
