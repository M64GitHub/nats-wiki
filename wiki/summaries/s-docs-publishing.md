---
title: "docs — JetStream: Publishing"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/publishing.md
source-path: raw/nats-docs/learn/jetstream/publishing.md
author: nats-io docs
article: "learn/jetstream/publishing.md"
date: 2026-08-31          # fetched
version: ""               # states no server version; the dedup default it quotes matches 2.14.6
tags: [PubAck, Nats-Msg-Id, duplicate, duplicate_window, sequence, no-responders, jetstream-flag]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Publishing

The chapter page that defines the `PubAck` and the retry contract. Read for question-bank row
**Q23**. The article is prose plus a CLI example repeated in seven client languages; per `CLAUDE.md`
only the prose and the CLI are ingested.

## Key claims

**`nats pub` is a core publish; `nats pub --jetstream` reads the `PubAck`.**

```
nats pub --jetstream orders.created '{"order_id":"ord_8w2k", …}'
Stored in Stream: ORDERS Sequence: 1
```

"Sequence numbers start at `1` and only increase. The server gives each new message the next number
and never reuses one."

**A `PubAck` has three fields used day to day** — `stream`, `sequence`, and **`duplicate`**
(`false` for a new message, `true` when the server recognised a repeat) — "and can also include a few
situational fields, such as a `domain` for multi-tenant or leaf-node setups."

**The rule: "the `PubAck` is your only proof that the message was stored."** And the two failure
modes are not the same:

> "A subject that no stream captures fails immediately (a 'no responders' error), and nothing was
> stored. But a network timeout means no confirmation, not no write: the server may have stored the
> message and the ack got lost on the way back."

**Stored is not delivered.** "A `PubAck` confirms that the server stored the message. It does not
confirm that any consumer has received it."

**Dedup is `Nats-Msg-Id` plus the stream's window.** "The server refuses to store the same ID twice
within the stream's duplicate-tracking window." On the CLI:

```
nats pub --jetstream orders.created \
  --header "Nats-Msg-Id:ord_8w2k-created" '{"order_id":"ord_8w2k", …}'
```

Run twice and "the second call prints the same sequence number with `Duplicate: true`, and nothing
new is stored." Give every retryable publish "a stable `Nats-Msg-Id` that the producer can
recompute, such as an order ID, a request ID, or a hash of the payload." The window "is a stream
setting, not a header".

**The default window is stated here, in prose: two minutes.**

> "The duplicate-tracking window is two minutes by default, so a retry that arrives after that also
> stores a second copy."

That matches the server's `StreamDefaultDuplicatesWindow = 2 * time.Minute`
(`stream.go:1658`, source: [[s-nats-server-constants-2.14.6]]) — **so docs issue #5 needs narrowing:
the value is stated in the `learn` chapter and missing only from the generated reference where the
field is defined.**

**The `--jetstream` flag turns a silent miss into an error.** Verbatim from the pitfalls:

```
nats pub invoices.created "test"
# 17:31:21 Published 4 bytes to "invoices.created"

nats pub --jetstream invoices.created "test"
# 17:31:21 Published 4 bytes to "invoices.created"
# nats: error: nats: no responders available for request
```

## Practical takeaways

- A publish that timed out **may have been stored**. Retry it, but only with a stable `Nats-Msg-Id`.
- A retry that arrives more than the duplicate window later stores a second copy regardless of the
  header. The window bounds the guarantee.
- `nats pub` without `--jetstream` reports success on a subject no stream captures; that line is not
  proof of a write.

## Relevance to the wiki

The publish half of **Q23** and the source for the new [[publishing]] page. Also the second public
statement of the two-minute dedup default, which changes `inbox/docs-issues.md` #5.

## Questions it answers

**Q23** — the mechanism (`Nats-Msg-Id`, `duplicate: true`, a bounded window) and the honest limit:
this is at-least-once storage with duplicate suppression, not exactly-once.

## Pages touched

[[publishing]] · [[stream]] · [[nats-cli]]

## Sources

The doc page. The default it states is cross-checked against
[[s-nats-server-constants-2.14.6]].
