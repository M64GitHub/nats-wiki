---
title: "$JS.API subjects"
type: reference
area: [jetstream, security]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [js-api, subjects, acl, system-account]
aliases: ["JS.API", "$JS.API", js api subjects, jetstream api subjects]
sources: [s-adr-1-jetstream-json-api, s-docs-stream-config, s-docs-consumer-config, s-relnotes-2.14.0, s-nats-server-auth-and-tls, s-docs-auth-callout, s-gh-7854-jwt-push-timeout, s-nats-server-leafnode-js-domains, s-adr-60-reliable-sourcing, s-adr-61-meta-quorum-rescue, s-adr-10-extended-purge, s-adr-8-key-value-store, s-synadia-jetstream-anti-patterns, s-adr-59-sourcing-and-mirroring, s-docs-authorization, s-docs-stream-backup-restore, s-gh-5044-restrict-durable-consumers, s-gh-5606-cross-account-jetstream, s-gh-7881-cross-domain-sourcing]
created: 2026-08-31
updated: 2026-08-31
---

# `$JS.API` subjects

Every JetStream administrative operation is a request-reply on one of these subjects. The table
covers the **32 documented API pages in the 2.14 docs tree**; it does not cover the `$JS.ACK`,
`$JS.FC` or `$JS.EVENT.ADVISORY` subject spaces — those are [[ack-and-redelivery]] and
[[advisories]]. The one exception is below: `$JS.FC.>` needs an export of its own when replication
crosses an account, so it appears in the export-type table and nowhere else.

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

**`STREAM.PURGE` is three operations behind one subject.** An empty payload purges everything; a
JSON body takes `filter` (a subject, wildcards allowed), `seq` (purge below this sequence,
non-inclusive) and `keep` (retain at most this many). `seq` and `keep` are mutually exclusive and
the server rejects both together with `10003 bad request`; `filter` combines with either. Note the
JSON name is `filter` while the CLI flag is `--subject`
(source: [[s-adr-10-extended-purge]], verified at v2.14.6).

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
| **`$JS.API.DIRECT.GET.<stream>`** | [[direct-get]] — criteria in the request payload (`seq`, `last_by_subj`, `next_by_subj`, `batch`, `multi_last`, …). Queue group **`_sys_`** | [[s-adr-31-direct-get]] |
| **`$JS.API.DIRECT.GET.<stream>.>`** | **Subject-Appended** Direct Get: the tokens after the stream name *are* the `last_by_subj`. Exists so subject-level permissions and cross-account grants can restrict which subjects are readable. A request payload here is a `408` | [[s-adr-31-direct-get]] |
| **`$JS.API.META.RESCUE`** | **2.15 only** (not in 2.14.6): broadcast on the **system account**, body `{"quorum_needed": <n>}`, temporarily lowering each surviving server's effective meta quorum for 5 minutes so a leader can be elected and dead peers removed. Rejects with `10224`; a request on any other account is silently ignored — [[disaster-recovery]] | [[s-adr-61-meta-quorum-rescue]] |
| **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** | consumer delivery-state reset, **added in 2.14**. Empty payload = reset the delivery state, leaving the ack floor's *stream* sequence where it is; `{"seq":<n>}` = move that floor to one below `<n>`, so the next delivery is `msg.seq >= n`. Allowed only on `DeliverPolicy` `all`, `by_start_sequence` or `by_start_time`, and for the latter two only forward of what the start policy allowed. The reply is shaped like a consumer-create response plus the `ResetSeq` used | [[s-relnotes-2.14.0]] · [[s-adr-60-reliable-sourcing]] |
| **`$JS.API.CONSUMER.DURABLE.CREATE.<stream>.<consumer>`** | the **legacy** durable-create subject. Modern clients do not send it: they create durables on `$JS.API.CONSUMER.CREATE.<stream>.<name>` with the durable name in the **request body**. It matters for ACLs precisely because it is gone — a rule written against `DURABLE.CREATE` catches only clients that still send it | [[s-gh-5044-restrict-durable-consumers]] |

Both Direct Get subjects exist **only when the stream sets `allow_direct`** — otherwise there is no
responder and a request times out with no error. Mirrors with `mirror_direct` join the *upstream's*
queue group for both forms, which is how a read can be answered from another cluster
([[mirrors-and-sources]]). Direct Get answers are plain NATS messages with `Nats-Stream`,
`Nats-Sequence`, `Nats-Time-Stamp` and `Nats-Subject` headers, and status codes `204` (EOB), `404`,
`408` and `413` — not the JSON envelope the rest of `$JS.API` uses ([[js-api]]).

## `$SYS` subjects an operator must know

Not part of `$JS.API`, but read from the server source at **v2.14.6** and cited across this wiki's
security pages. They are what an account push and an auth callout actually travel on.

| subject | what it is | source |
|---|---|---|
| **`$SYS.REQ.CLAIMS.UPDATE`** | an **account push**. When nothing is subscribed here, the push fails with a bare `nats: timeout` and the server logs nothing | `events.go:46` |
| `$SYS.REQ.CLAIMS.LIST` | list the accounts the resolver holds | `events.go:45` |
| `$SYS.REQ.CLAIMS.DELETE` | delete an account JWT; needs `allow_delete: true` on the resolver | `events.go:47` |
| `$SYS.REQ.CLAIMS.PACK` | resolver-to-resolver reconciliation | `events.go:44` |
| `$SYS.REQ.ACCOUNT.<id>.CLAIMS.LOOKUP` | the server fetching one account JWT | `events.go:43` |
| **`$SYS.REQ.USER.AUTH`** | the [[auth-callout]] hand-off; carries the client's credentials **in the clear** unless `xkey` is set | `auth_callout.go:30` |
| `$SYS.REQ.USER.INFO` | what `nats account info` asks; a narrow publish allow-list silently blanks the answer ([[account]]) | cited by [[s-docs-accounts-and-multitenancy]] |

Two permission facts follow from this table:

- The temporary user a push uses is scoped to exactly `$SYS.REQ.CLAIMS.LIST`,
  `$SYS.REQ.CLAIMS.UPDATE` and `$SYS.REQ.CLAIMS.DELETE`, plus `_INBOX.>` on the subscribe side
  (source: [[s-gh-7854-jwt-push-timeout]]) — so narrowing the system account's permissions can break
  pushes and nothing else.
- On the account where auth callout runs, **the server denies publishing to `$SYS.REQ.USER.AUTH` for
  every user**, the auth service included. That stops forgery; it does not stop a subscriber reading
  every credential presented to the server.

The `$SYS.REQ.SERVER.PING.*` family is not listed here: it carries the monitoring endpoints over NATS
rather than HTTP — a mirror or source error, for instance, is readable over
`$SYS.REQ.SERVER.PING.JSZ` as well as at `/jsz` (source: [[s-adr-59-sourcing-and-mirroring]]). The
endpoints, their fields and that equivalence are on [[monitoring-endpoints]].


## Why the tokens matter

ADR-1 is explicit that the per-object tokens exist for authorisation
(source: [[s-adr-1-jetstream-json-api]]):

> "every API has a unique subject and generally the subjects include tokens indicating the item
> being accessed. **This is to assist in generating ACLs** giving people access to either subsets of
> API or even down to a single Stream or Consumer."

So `$JS.API.STREAM.INFO.ORDERS` can be granted without granting `$JS.API.STREAM.INFO.*`. The
mechanics are on [[js-api]].

**The coarse grant is `$JS.API.>`**, and it appears in three different roles. As an
[[subject-permissions|authorization]] rule it is the whole JetStream API for that user — and
`allow: [">"]` grants the server, `$JS.API.>` included (source: [[s-docs-authorization]]). As an
account **export** it is how one account reaches another's JetStream
([[s-gh-5606-cross-account-jetstream]]), and the same export is what a supercluster needs so its
leafnodes can use the API (source: [[s-gh-7881-cross-domain-sourcing]]). See
[[cross-account-sharing]].

**Cross-account replication needs three subjects with the right export *type*,** and the wrong type
fails silently — ADR-59 says so in as many words: "Getting the type wrong (e.g., using a stream
import for the API subject) will cause silent failures."

| subject | type | purpose |
|---|---|---|
| `$JS.API.CONSUMER.>` | **service** | consumer create/delete (request/reply) |
| the delivery prefix, e.g. `deliver.mirror.>` | **stream** | one-way delivery of replicated messages |
| `$JS.FC.>` | **service** | flow control back to the origin |

(source: [[s-adr-59-sourcing-and-mirroring]]; the configuration is on [[cross-account-sharing]] and
[[cross-domain-sourcing]].)

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

## The domain-prefixed form

When `jetstream { domain: <name> }` is set, the server installs a mapping into **every non-system
account** that makes the whole API reachable under a second prefix
(`generateJSMappingTable`, `jetstream_api.go:326–352`; source:
[[s-nats-server-leafnode-js-domains]] · [[s-adr-10-extended-purge]]):

| domain-prefixed subject | maps to |
|---|---|
| `$JS.<domain>.API.INFO` | `$JS.API.INFO` |
| `$JS.<domain>.API.STREAM.>` | `$JS.API.STREAM.>` |
| `$JS.<domain>.API.CONSUMER.>` | `$JS.API.CONSUMER.>` |
| `$JS.<domain>.API.DIRECT.>` | `$JS.API.DIRECT.>` |
| `$JS.<domain>.API.META.>` | `$JS.API.META.>` |
| `$JS.<domain>.API.SERVER.>` | `$JS.API.SERVER.>` |
| `$JS.<domain>.API.ACCOUNT.>` | `$JS.API.ACCOUNT.>` |
| `$JS.<domain>.API.$KV.>` | `$KV.>` |
| `$JS.<domain>.API.$OBJ.>` | `$OBJ.>` |

The last two are the odd ones, and the source says so: `$KV` and `$OBJ` are independent subject
spaces rather than living under `$JS.API`, which the server's own comment calls "very very very
ugly".

This prefix is what a client names to address another domain — `nats --js-domain <name> …`, or the
`api` field of an `external` block, whose value the server parses as `$JS.<domain>.API` and reads the
domain back out of as the **second token** (`stream.go:432–437`). See [[jetstream-domain]] and
[[cross-domain-sourcing]].


## Related

[[js-api]] · [[error-codes]] · [[stream]] · [[consumer]] · [[account]] · [[advisories]] ·
[[direct-get]] · [[raft-in-nats]] · [[subject-permissions]] · [[auth-callout]] ·
[[operator-mode]] · [[cross-account-sharing]] · [[jetstream-domain]] · [[cross-domain-sourcing]]

## Sources

[[s-adr-1-jetstream-json-api]] · [[s-docs-stream-config]] · [[s-docs-consumer-config]] ·
[[s-relnotes-2.14.0]] · [[s-adr-8-key-value-store]] · [[s-synadia-jetstream-anti-patterns]] · [[s-nats-server-auth-and-tls]] · [[s-docs-auth-callout]] · [[s-gh-7854-jwt-push-timeout]] · [[s-nats-server-leafnode-js-domains]] · [[s-adr-10-extended-purge]] ·
[[s-adr-60-reliable-sourcing]] · [[s-adr-61-meta-quorum-rescue]] ·
[[s-adr-59-sourcing-and-mirroring]] · [[s-docs-authorization]] · [[s-docs-stream-backup-restore]] · [[s-gh-5044-restrict-durable-consumers]] · [[s-gh-5606-cross-account-jetstream]] · [[s-gh-7881-cross-domain-sourcing]]
