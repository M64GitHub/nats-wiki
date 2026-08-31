---
title: "docs.nats.io — Reading messages directly"
type: summary
area: [jetstream, kv]
source-url: https://docs.nats.io/learn/jetstream/get-direct.md
source-path: raw/nats-docs/learn/jetstream/get-direct.md
author: NATS documentation (Synadia Communications, Inc.)
article: Reading messages directly
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [direct-get, allow_direct, last_by_subj, batch, Nats-Num-Pending, read-after-write]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Reading messages directly

The point read: one message by sequence or by subject, with no consumer, no ack and no cursor —
and the three ways people get it wrong.

## Key claims

**Two different reads, and the difference is which server answers.**

- `nats stream get` — "goes to the leader", so it is **always current**.
- **Direct Get** — "the same by-sequence and by-subject reads, answered by *any* server that holds a
  copy of the stream, not only the leader", including **mirrors**.

**Direct Get is the stream's `allow_direct` setting.** "Check it with `nats stream info ORDERS`: its
output carries a `Direct Get: true` line when the setting is on, and no such line when it's off. The
CLI enables it for new streams."

```
nats stream get ORDERS 2                          # by sequence, from the leader
nats stream get ORDERS --last-for orders.shipped  # last message on a subject
nats stream edit ORDERS --allow-direct            # turn Direct Get on
nats sub --stream ORDERS --direct --start-sequence 1 --count 3   # batch, one request
```

**`--last-for` is the KV primitive.** The docs say it outright: "This is the read a key-value lookup
is built on: 'the latest value for a key' is 'the last message on its subject'."

**A batch is one request, not one round trip each.** "Ask Direct Get for a range and the server
streams the matching messages back over one request." Every message carries a **`Nats-Num-Pending`**
header counting down, reaching `0` on the last one:

```
[#1] ... seq 1 ...   Nats-Num-Pending: 2
[#2] ... seq 2 ...   Nats-Num-Pending: 1
[#3] ... seq 3 ...   Nats-Num-Pending: 0
```

Request fields named: `batch`, `max_bytes`, `multi_last`, plus `--last-per-subject`.

**On a direct read the subject arrives in a header, not in the message subject.** The .NET example
says it explicitly: "On a direct get the stream sequence and original subject come back in headers,
not in `msg.Subject` (which is the reply subject)" — `Nats-Sequence` and `Nats-Subject`.

**Client support is uneven.** "`nats.js` sends a batched Direct Get directly; Go, Rust, Java, and C#
reach it through the [Synadia Orbit](https://github.com/synadia-io) helper libraries."

**Direct Get or a consumer?** The docs draw the line:

- Direct Get for "a point read: one message by sequence, the latest value on a subject, or a bounded
  batch snapshot. Nothing is acked, no position is kept, and any replica can answer."
- A consumer to "work through the log … keep a durable position across restarts, ack as you go, and
  pick up new messages."
- "A direct read never moves a consumer's position and never removes a message."

**Three pitfalls, stated as such:**

1. **"Direct Get is off, so the read hangs."** With `allow_direct` unset, "no server answers the
   Direct Get subject and the request times out with nothing returned."
2. **"A direct read can be stale."** "Direct Get answers from any replica or mirror, which may trail
   the leader. **Don't use it for read-after-write checks** — confirming a publish landed, reading a
   value you wrote a moment ago."
3. **"A batch isn't a subscription."** It "returns the stored messages that match and stops. Code
   that expects to keep receiving new messages from it reads the backlog once and then sits idle."

## Practical takeaways

- **The failure mode of a missing `allow_direct` is a timeout, not an error.** That is the worst
  shape for a first deployment: nothing to grep for, no error code, just a hanging client.
- **"Any replica" is the whole point and the whole risk.** It is what makes Direct Get cheap and
  geographically useful, and it is exactly why it cannot confirm a write.
- **`--last-per-subject` / `multi_last` is a point-in-time snapshot across a subject space** — the
  cheap alternative to standing up a consumer just to read current state.

## Notable quotes

> "Don't use it for read-after-write checks."

> "A direct read never moves a consumer's position and never removes a message."

## Relevance to the wiki

The behavioural half of [[direct-get]]; [[s-adr-31-direct-get]] supplies the subjects, headers and
status codes.

## Questions it answers

Supports the Direct Get half of Q7 and the anti-pattern advice on
[[jetstream-slows-as-consumers-grow]] — "read state without a consumer".

## Pages touched

[[direct-get]] · [[stream]] · [[replicas]] · [[key-value]] · [[mirrors-and-sources]] ·
[[jetstream-slows-as-consumers-grow]] · [[nats-js]] · [[orbit]]
