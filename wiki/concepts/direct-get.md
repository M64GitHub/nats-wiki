---
title: Direct Get
type: concept
area: [jetstream, kv, objectstore]
since: [2.11]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [direct-get, allow_direct, mirror_direct, last_by_subj, multi_last, batch, EOB]
aliases: [direct get, allow_direct, "$JS.API.DIRECT.GET", direct read, mirror_direct]
sources: [s-docs-get-direct, s-adr-31-direct-get, s-docs-mirrors-and-sources]
created: 2026-08-31
updated: 2026-08-31
---

# Direct Get

A **point read straight from a stream's store** — one message by sequence or by subject, or a bounded
batch — answered by **any server holding a copy of the stream**, not only the leader. No consumer, no
ack, no cursor (source: [[s-docs-get-direct]]).

It is the read [[key-value]] and [[object-store]] are built on, and the standard answer when a
service needs *current state* rather than a position in a log.

## How it behaves

**Two reads, and the difference is who answers.**

| | `$JS.API.STREAM.MSG.GET.<stream>` | `$JS.API.DIRECT.GET.<stream>` |
|---|---|---|
| CLI | `nats stream get` | `nats stream get --direct`, `nats sub --stream … --direct` |
| answered by | the **leader** (R>1) or the single server | **any peer**, in queue group `_sys_` — and mirrors with `mirror_direct` |
| read-after-write | **guaranteed** | **not guaranteed** |
| batching | no | yes |
| requires | always available | `allow_direct: true` on the stream |

"With Direct Get the number of servers eligible to respond to read requests is the same as the
replica count of the stream" (source: [[s-adr-31-direct-get]]). A mirror can join the *upstream's*
responder pool, which is how reads get served near a distant client — see
[[mirrors-and-sources]].

**A direct read never moves a consumer's position and never removes a message.** It only reads what
is stored.

**Two request subjects.** Both are subscribed with the fixed queue group `_sys_`:

- `$JS.API.DIRECT.GET.<stream>` — criteria in the request payload.
- `$JS.API.DIRECT.GET.<stream>.>` — **Subject-Appended**: the tokens after the stream name *are* the
  `last_by_subj`. It exists so subject-level permissions and cross-account grants can restrict which
  subjects of a stream are readable. Sending a payload to this form is an error (`408`).

**The request fields** (same shape as the regular Get):

```
seq, last_by_subj, next_by_subj, batch, max_bytes,
start_time, multi_last, up_to_seq, up_to_time
```

- `{last_by_subj}` — the last message on a subject. "The latest value for a key" *is* "the last
  message on its subject", which is exactly what a KV get does.
- `{next_by_subj}` — the first (lowest sequence) message on a subject.
- `{start_time}` — first message at or newer than an RFC 3339 time, **since 2.11**.
- `{multi_last: [...]}` — the last message for each of several subjects, wildcards allowed; a
  point-in-time snapshot across a subject space, bounded by `up_to_seq`, `up_to_time` or `batch`.

**Batching has no flow control.** `batch >= 1` opts in; **`batch` omitted or `0` is a single-message
get** that emits no sentinel. The server sends up to `max_bytes`, and when `max_bytes` is unset it
uses `max_pending` or **the server default, 64MB**. The batch ends with a zero-length message
carrying `Status: 204`, `Description: EOB` and the pending counters.

**Response headers** — note that on a direct read the subject arrives in a header; the message's own
subject is the reply inbox:

| header | meaning |
|---|---|
| `Nats-Stream` | stream name |
| `Nats-Sequence` | message sequence |
| `Nats-Time-Stamp` | publish timestamp |
| `Nats-Subject` | the message's real subject |
| `Nats-Num-Pending` | batched: how many still match; `0` on the last |
| `Nats-Last-Sequence` | batched: the previous message's stream sequence |
| `Nats-UpTo-Sequence` | multi-subject: carry back as `up_to_seq` for a consistent page |

**Status codes**: `204` end of batch · `404` valid request, nothing matched · `408` empty or invalid
request · `413` a multi-subject get matched **too many subjects**.

## What configures it

**`allow_direct`** on the stream, **default `false`**, opt-in:

```
nats stream info ORDERS          # shows "Direct Get: true" when on, no such line when off
nats stream edit ORDERS --allow-direct
```

The `nats` CLI enables it for streams it creates. The server does **not** enable it implicitly — an
earlier revision of ADR-31 described auto-promotion when `max_msgs_per_subject` was set, and the ADR
explicitly retracts that: "servers leave `allow_direct` untouched regardless of
`max_msgs_per_subject`."

**`mirror_direct`** on a *mirror's* config decides whether that mirror's peers join the **upstream's**
Direct Get queue group. It is meaningless on a non-mirror stream. See [[mirrors-and-sources]] for
its four alignment rules — in particular that it is captured at create time and never refreshed.

## Limits and failure modes

- **`allow_direct` off ⇒ the read hangs.** There is no responder at all, so "clients that make
  requests will receive no reply message and will time out." No error, no code — check
  `nats stream info` for `Direct Get: true` first.
- **A direct read can be stale.** Responders may be non-leader peers that have not applied the latest
  consensus writes, or mirrors that have not consumed them. **Never use Direct Get for a
  read-after-write check** — confirming a publish landed, or reading a value you just wrote. Use the
  regular get against the leader for that.
- **A batch is not a subscription.** It returns what is stored and stops; code expecting to keep
  receiving reads the backlog once and then sits idle. Use a [[consumer]] to follow a stream.
- **`413` on a wide `multi_last`.** A multi-subject get over a broad wildcard can match too many
  subjects and is refused.
- **Old servers are detected by absence.** A server without batch support "sends the first response
  and nothing follows" — the tell is a missing `Nats-Num-Pending` on the first reply.

## Why an operator cares

- **It is the escape route from consumer sprawl.** When a service only needs current state, a direct
  read replaces a consumer entirely — the alternative [[jetstream-slows-as-consumers-grow]]
  recommends when consumer counts become the bottleneck.
- **It spreads read load across replicas** instead of concentrating it on the leader, which is one of
  the few ways [[replicas]] buys throughput rather than only durability.
- **Client coverage is uneven.** `nats.js` sends a batched Direct Get directly; Go, Rust, Java and C#
  reach batched direct reads through [[orbit]] helper libraries (source: [[s-docs-get-direct]]).

## Related

[[stream]] · [[consumer]] · [[key-value]] · [[object-store]] · [[mirrors-and-sources]] ·
[[replicas]] · [[js-api-subjects]] · [[jetstream-slows-as-consumers-grow]] · [[orbit]]

## Sources

[[s-docs-get-direct]] · [[s-adr-31-direct-get]] · [[s-docs-mirrors-and-sources]]
