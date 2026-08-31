---
title: "ADR-31 — JetStream Direct Get"
type: summary
area: [jetstream, kv]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-31.md
source-path: raw/adr/ADR-31.md
author: "@mh, @ivan, @derekcollison, @alberto, @tbeets, @ripienaar"
article: ADR-31 JetStream Direct Get
date: 2022-08-03
version: "2.11"
tags: [direct-get, allow_direct, mirror_direct, EOB, headers, status-codes, queue-group]
aliases: [ADR-31]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-31 — JetStream Direct Get

The authoritative spec: the subjects, the request payload, the response headers and status codes,
and the `mirror_direct` rules that decide whether a mirror joins the upstream's read pool.
Status **Implemented**, tagged `2.11`.

## Key claims

**The mechanism is a queue group of stream peers.** "Direct Get … enables all stream peers (R>1),
not just the stream leader, to respond to stream read calls as a service responder *queue group*.
The responder sources its local message store. With Direct Get the number of servers eligible to
respond to read requests is the same as the replica count of the stream."

**The subjects**, both with the fixed queue group **`_sys_`**:

| subject | form |
|---|---|
| `$JS.API.DIRECT.GET.<stream>` | request payload carries the criteria |
| `$JS.API.DIRECT.GET.<stream>.>` | **Subject-Appended**: the tokens after the stream name *are* the `last_by_subj` |
| `$JS.API.STREAM.MSG.GET.<stream>` | the **regular** Get, routed to the leader |

The Subject-Appended form exists "so that environments may choose to apply subject-based interest
restrictions (user permissions within an account and/or cross-account export/import grants) such that
only specific subjects in stream may be read". Sending a payload to it "is an error (408)".

**`allow_direct` defaults to `false` and is opt-in.** "The server does not enable it implicitly based
on other stream settings" — and the ADR explicitly retracts an earlier revision: "Earlier revisions
of this document described the server auto-promoting `allow_direct: true` when [`max_msgs_per_subject`
was set] … servers leave `allow_direct` untouched regardless of `max_msgs_per_subject`."

**With `allow_direct` false there is no responder at all**: "Clients that make requests will receive
no reply message and will time out."

**Request fields** (same payload shape as the regular Get):

```
seq, last_by_subj, next_by_subj, batch, max_bytes,
start_time, multi_last, up_to_seq, up_to_time
```

- `{start_time}` — "get the first message at or newer than the time specified in RFC 3339 format
  (**since server 2.11**)".
- `{multi_last: [string]}` — last message per subject, wildcards allowed; bounded by `up_to_seq`,
  `up_to_time` or `batch`.
- **`batch` omitted or `0` means a single-message Get** — "the server returns exactly one matching
  message and does not emit an EOB sentinel or `Nats-Num-Pending`. Use `batch >= 1` to opt into
  batched behavior."
- If neither `seq` nor `start_time` bounds a batch, "the server defaults to `seq: 1`".

**Batches have no flow control.** "The server will send multiple messages without any flow control to
the reply subject, it will send up to `max_bytes` messages. When `max_bytes` is unset the server will
use the `max_pending` configuration setting or the **server default (currently 64MB)**."

**The end-of-batch sentinel.** After a batch, a zero-length message arrives with `Status: 204`,
`Description: EOB`, and the `Nats-Num-Pending` / `Nats-Last-Sequence` headers. "When requests are
made against servers that do not support `batch` the first response will be received and nothing will
follow. Old servers can be detected by the absence of the `Nats-Num-Pending` header in the first
reply."

**Status codes**: `204` end of batch (`EOB`) · `404` valid request, no matching message · `408`
empty or invalid request · **`413` when a multi-subject get matches too many subjects**. Returned as
a header (`NATS/1.0 408 Bad Request`); success is `NATS/1.0` with no code.

**Response headers**: `Nats-Stream`, `Nats-Sequence`, `Nats-Time-Stamp`, `Nats-Subject`,
`Nats-Num-Pending`, `Nats-Last-Sequence`, and `Nats-UpTo-Sequence` for multi-subject gets. The reply
is "a *regular* (not JSON-encoded) NATS message".

**Pagination of a multi-subject get** is defined: carry `Nats-UpTo-Sequence` back as `up_to_seq` "so
subsequent pages see the same point-in-time view", advance `seq` to `Nats-Last-Sequence + 1`, and
stop "when `Nats-Num-Pending` reaches `0` on the EOB".

**`mirror_direct` — a mirror can serve the upstream's reads.** Set on the **mirror's** config, it
"governs whether the mirror's peers join the upstream's Direct Get queue group; it has no meaning
when set on a non-mirror stream". A mirror with `mirror_direct: true` queue-subscribes its peers to
the *upstream's* `$JS.API.DIRECT.GET.<SRC>` and `…<SRC>.>` in the same `_sys_` group. Because mirrors
"need not be in the same cluster as the upstream", this places read responders near distant clients
and keeps reads available "when the upstream is offline".

**Four `mirror_direct` rules that bite:**

1. At create time, if the upstream is visible, the mirror's `mirror_direct` is **set to match the
   upstream's `allow_direct`**; a disagreeing user value "is rejected in pedantic mode and silently
   aligned with the upstream in non-pedantic mode".
2. If the upstream is not visible (an External mirror across domains), the user value is preserved.
3. A mirror joins the queue group **only once it has caught up** to within a small lag window, "so a
   freshly-created mirror does not yet contribute to read availability".
4. **`mirror_direct` is captured at create time and never refreshed.** "Toggling the upstream's
   `allow_direct` therefore desynchronises mirrors until each mirror is itself updated via
   `STREAM.UPDATE`" — an operator must change the upstream **and** re-issue an update on every
   mirror. The ADR's own advice: "always set `mirror_direct` to their desired value."

**Read-after-write, stated formally.** The regular Get "provides read-after-write coherency by routing
requests to a stream's current peer leader (R>1) or single server (R=1)". Direct Get "does not assure
read-after-write coherency as responders may be non-leader stream servers (that may not have yet
applied the latest consensus writes) or MIRROR downstream servers that have not yet *consumed* the
latest consensus writes from upstream."

## Practical takeaways

- **`_sys_` is the queue group name to look for** when reasoning about who answers a direct read.
- **The `413` is the multi-subject guard rail** — a `multi_last` over a wide wildcard is not free.
- **Toggling `allow_direct` on a stream that has mirrors is a two-step operation.** Doing only the
  first step leaves mirrors in a state the ADR calls desynchronised, and nothing reports it.
- **A `408` from Subject-Appended Direct Get usually means the client sent a payload**, not that the
  request was malformed in some subtler way.

## Notable quotes

> "Due to the ambiguity and non-deterministic behavior it's suggested that users always set
> `mirror_direct` to their desired value."

## Relevance to the wiki

The specification behind [[direct-get]] and the `mirror_direct` half of [[mirrors-and-sources]];
adds three subjects to [[js-api-subjects]].

## Questions it answers

None of the bank's rows directly; it is the reference behind [[direct-get]].

## Pages touched

[[direct-get]] · [[mirrors-and-sources]] · [[js-api-subjects]] · [[key-value]] · [[replicas]] ·
[[defaults-and-limits]] · [[nats-architecture-and-design]]
