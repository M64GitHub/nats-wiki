---
title: "$JS.API subjects"
type: reference
area: [jetstream, security]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [js-api, subjects, acl, system-account]
aliases: ["JS.API", "$JS.API", js api subjects, jetstream api subjects]
sources: [s-adr-1-jetstream-json-api, s-docs-stream-config, s-docs-consumer-config, s-relnotes-2.14.0]
created: 2026-08-31
updated: 2026-08-31
---

# `$JS.API` subjects

Every JetStream administrative operation is a request-reply on one of these subjects. The table
covers the **32 documented API pages in the 2.14 docs tree**; it does not cover the `$JS.ACK`,
`$JS.FC` or `$JS.EVENT.ADVISORY` subject spaces — those are [[ack-and-redelivery]] and
[[advisories]].

The **System Account** column is the docs' own, and it is the column that matters for
[[account|permissions]]: a `Yes` means the request must come from the system account.

## Stream

| operation | subject | system account |
|---|---|---|
| Create stream | `$JS.API.STREAM.CREATE.<stream>` | No |
| Update stream | `$JS.API.STREAM.UPDATE.<stream>` | No |
| Delete stream | `$JS.API.STREAM.DELETE.<stream>` | No |
| Stream info | `$JS.API.STREAM.INFO.<stream>` | No |
| List streams | `$JS.API.STREAM.LIST` | No |
| Stream names | `$JS.API.STREAM.NAMES` | No |
| Get message | `$JS.API.STREAM.MSG.GET.<stream>` | No |
| Delete message | `$JS.API.STREAM.MSG.DELETE.<stream>` | No |
| Purge stream | `$JS.API.STREAM.PURGE.<stream>` | No |
| Leader stepdown | `$JS.API.STREAM.LEADER.STEPDOWN.<stream>` | No |
| Remove peer | `$JS.API.STREAM.PEER.REMOVE.<stream>` | No |
| Restore stream | `$JS.API.STREAM.RESTORE.<stream>` | No |
| Snapshot stream | `$JS.API.STREAM.SNAPSHOT.<stream>` | No |

**Publish acknowledgement** has no subject of its own: messages are published directly to the
stream's own subjects and the `PubAck` comes back as the reply.

## Consumer

| operation | subject | system account |
|---|---|---|
| Create consumer | `$JS.API.CONSUMER.CREATE.<stream>.<consumer>` | No |
| Delete consumer | `$JS.API.CONSUMER.DELETE.<stream>.<consumer>` | No |
| Consumer info | `$JS.API.CONSUMER.INFO.<stream>.<consumer>` | No |
| List consumers | `$JS.API.CONSUMER.LIST.<stream>` | No |
| Consumer names | `$JS.API.CONSUMER.NAMES.<stream>` | No |
| Get next message | `$JS.API.CONSUMER.MSG.NEXT.<stream>.<consumer>` | No |
| Leader stepdown | `$JS.API.CONSUMER.LEADER.STEPDOWN.<stream>.<consumer>` | No |
| Pause consumer | `$JS.API.CONSUMER.PAUSE.<stream>.<consumer>` | No |
| Unpin consumer | `$JS.API.CONSUMER.UNPIN.<stream>.<consumer>` | No |

The consumer name is **optional** on create (source: [[s-docs-consumer-config]]).

## Account

| operation | subject | system account |
|---|---|---|
| Account info | `$JS.API.INFO` | No |
| Account purge | `$JS.API.ACCOUNT.PURGE` | No |

`$JS.API.INFO` is also the call clients should use to **assert the stream API level** rather than
reading the connected server's version string — see [[key-value]] and [[message-ttl]].

## Meta

| operation | subject | system account |
|---|---|---|
| Meta leader stepdown | `$JS.API.META.LEADER.STEPDOWN` | **Yes** |
| Meta server remove | `$JS.API.META.SERVER.REMOVE` | **Yes** |

These two are the only system-account entries in the documented set. See [[raft-in-nats]].

## Documented elsewhere, absent from the API index

Three subjects this wiki cites are **not in the docs' API reference tree**, which is worth knowing
if you are building ACLs from that tree alone:

| subject | what it is | source |
|---|---|---|
| **`$JS.API.DIRECT.GET.<stream>.<subject>`** | Direct Get — the read path for KV, answerable by **any replica** | `learn/key-value/under-the-hood.md`; [[s-adr-8-key-value-store]] |
| **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** | consumer delivery-state reset, **added in 2.14** | [[s-relnotes-2.14.0]] |
| `$JS.API.DIRECT.GET` batch form | Batch Get, **2.11+** | [[s-synadia-jetstream-anti-patterns]] |

## Why the tokens matter

ADR-1 is explicit that the per-object tokens exist for authorisation
(source: [[s-adr-1-jetstream-json-api]]):

> "every API has a unique subject and generally the subjects include tokens indicating the item
> being accessed. **This is to assist in generating ACLs** giving people access to either subsets of
> API or even down to a single Stream or Consumer."

So `$JS.API.STREAM.INFO.ORDERS` can be granted without granting `$JS.API.STREAM.INFO.*`. The
mechanics are on [[js-api]].

## Conventions

- An **empty request body** may be nil, an empty string, or `{}`.
- **Listing APIs are paged** — replies carry `total`, `offset` and `limit`, and the documented
  default `limit` is **1024**. Page with `{"offset": 1024}`.
- **Every reply carries a `type`** such as `io.nats.jetstream.api.v1.stream_info_response`;
  requests do not, because the subject implies them.
- Durations on the wire are **nanoseconds**; timestamps are **RFC 3339**.

## How this was derived

From `raw/nats-docs/reference/jetstream/api/` in the 2.14 docs tree — 32 pages. The four index
pages (`api/stream.md`, `api/consumer.md`, `api/account.md`, `api/meta.md`) each carry a
`| Name | Subject | System Account |` table, and those tables are the source of the four sections
above verbatim. Each individual page repeats its own subject under a `## Subject` heading.

To regenerate: re-read the `## Subject` line of every `*.md` under
`raw/nats-docs/reference/jetstream/api/`, and the three index tables for the system-account column.
The three "absent from the index" rows are hand-kept and come from the sources named beside them.

## Related

[[js-api]] · [[error-codes]] · [[stream]] · [[consumer]] · [[account]] · [[advisories]] ·
[[direct-get]] · [[raft-in-nats]]

## Sources

[[s-adr-1-jetstream-json-api]] · [[s-docs-stream-config]] · [[s-docs-consumer-config]] ·
[[s-relnotes-2.14.0]] · [[s-adr-8-key-value-store]] · [[s-synadia-jetstream-anti-patterns]]
