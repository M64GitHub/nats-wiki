---
title: jsm.go
type: entity
kind: repo
area: [jetstream, clients, deploy]
verified-against: jsm.go v0.4.1
verified-on: 2026-08-31
tags: [repo, jsm, schemas, schema-registry, management-library, generator]
aliases: [jsm.go, jsm, "nats-io/jsm.go"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-jsm-go-config-schemas]
created: 2026-08-31
updated: 2026-09-03
---

# jsm.go

**The JetStream management library under the tooling — and the canonical home of the JetStream API
JSON schemas.** The docs' `reference/jetstream/` tree is generated from these schemas, which makes
this repo the upstream of a large part of what this wiki cites (source: [[s-docs-ecosystem]]).

## Where it fits

Below [[nats-cli]], [[nack]] and the Terraform provider; beside [[nats-go]], not under it. Its own
README is blunt about the audience: "For typical end users we suggest the nats.go package."

## Facts

| | |
|---|---|
| repo | `nats-io/jsm.go` |
| created | 2020-03-04 |
| latest release | **v0.4.1**, 2026-05-01 |
| licence | Apache-2.0 |
| used by | the `nats` CLI, the Terraform provider, the NATS GitHub Actions, and the Kubernetes CRDs ([[nack]]) |
| holds | the JSON Schemas for "All the JetStream API messages and some events and advisories produced by the NATS Server" |
| schema access from the CLI | `nats schemas` — list, search, view and validate |

## What an operator needs to know

- **It is why the tools agree with each other.** `nats stream info`, a NACK `.status` block and the
  Terraform provider's state all come from one schema set. A field means the same thing in all three.
- **It is why the docs' reference pages look generated — they are.** That is also why the three wrong
  advisory subjects in `inbox/docs-issues.md` #1–3 are all on generated pages while the hand-written
  learn pages have them right: the generator's mapping was wrong, not the writer.
- **`nats schemas` is a legitimate operator tool.** Validating a stream config against the schema
  before applying it is cheaper than discovering the mismatch through a `$JS.API` error.
- **It requires knowing the API.** "It's essentially a direct wrapping of the JetStream API with few
  userfriendly features and requires deep technical knowledge of the JetStream internals." Use it
  when you are building tooling, not applications.

## The two schemas this wiki reads directly

`schemas/jetstream/api/v1/stream_configuration.json` and `consumer_configuration.json` at **v0.4.1**
are in `raw/jsm-go/`: 38 stream properties matching the server's `StreamConfig` field for field, and
34 consumer properties (the server's `sourcing` is internal). Because the docs collapse the consumer
schema (docs issue #4), the consumer descriptions and schema defaults — `ack_policy: none`,
`max_waiting: 512`, `ack_wait: "30000000000"` — are readable only here; one description is wrong
(`opt_start_time` names `DeliverByStartSequence`, docs issue #74). The field tables built from them
are [[stream-and-consumer-config]] (source: [[s-jsm-go-config-schemas]]).


## Related

[[nats-cli]] · [[nack]] · [[js-api]] · [[js-api-subjects]] · [[advisories]] · [[nats-go]] ·
[[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-jsm-go-config-schemas]]
