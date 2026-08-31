---
title: Ack and redelivery
type: concept
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [ack, nak, term, ack_wait, max_deliver, max_ack_pending, backoff, advisories]
aliases: [acknowledgement, acknowledgment, ack, nak, term, at-least-once, AckWait, MaxDeliver]
sources: [s-docs-delivery-and-acknowledgment, s-docs-acknowledgment, s-docs-pull-consumers, s-docs-consumer-config, s-nats-server-constants-2.14.6]
created: 2026-08-31
updated: 2026-08-31
---

# Ack and redelivery

JetStream's **at-least-once** delivery is two halves: the durable [[stream]] holds the message, and
the [[consumer]]'s ack/redeliver loop keeps handing it out until a reader confirms it. A reader can
crash, a handler can throw, a process can be killed — the message comes back instead of vanishing.
This page is the loop: what a client can answer, and what the server does when the answer is late
or never comes.

## How it behaves

A message on a consumer moves through three states (source:
[[s-docs-delivery-and-acknowledgment]]):

1. **Delivered, in flight** — the consumer has handed the message to a reader. The message stays in
   the stream and the consumer's **acknowledgment floor** has not moved past it.
2. **Acked** — the reader answers; the floor advances past the message.
3. **Redelivered** — no answer arrived within `ack_wait`, so the server assumes the reader failed
   and delivers the message again, to the same reader or another one on the same consumer.

The gap between the last delivered sequence and the acknowledgment floor is the **in-flight set**,
and `max_ack_pending` is the cap on its size.

The **delivery count rides on the message** — the CLI prints `tries: 1` on a first delivery,
`tries: 2` on a redelivery — so a reader always knows how many times it has seen one without
calling `nats consumer info`.

### Redelivery is in delivery order, not stream order

A consumer normally has several messages in flight, so while one waits to be redelivered the
consumer keeps handing out later ones. **A redelivered message can arrive after messages with
higher stream sequences.** Setting `max_ack_pending` to `1` is the only way to get strict in-order
processing: the consumer delivers one message at a time and will not move past it until it is
acked, so a redelivery always comes back before anything new. That costs throughput — no overlap
between handlers — so use it only when order actually matters (source:
[[s-docs-delivery-and-acknowledgment]]).

## The four answers

A client answers a delivered message in **exactly one of four ways**
(source: [[s-docs-acknowledgment]]):

| answer | effect |
|---|---|
| **ack** | the work succeeded; the server clears the pending entry and never delivers the message again |
| **nak** | redeliver. A plain nak asks for redelivery **immediately**, or after a delay the client attaches |
| **term** | give up — this message can never be handled. Clears the pending entry and moves the ack floor exactly as an ack does, but records that the work never happened |
| **in-progress** | *not* a final answer — it **resets the `ack_wait` timer** so a long job does not trip redelivery |

**A delayed nak is a client-library call.** The CLI's `--nak` only asks for immediate redelivery;
to space out redeliveries from the CLI, set a consumer `backoff` instead.

**A nak returns the message to the consumer, not to the worker that nak'd it** — with a
[[worker-pool|worker pool]] sharing one consumer, the redelivery can land on a different worker.

**After a term** the message is gone from *this* consumer but stays in the stream under the default
`limits` retention: other consumers still see it and it ages out with the stream's limits. On a
`workqueue` or `interest` stream a term removes it just as an ack would — see
[[retention-policies]].

### Plain ack vs double ack

A plain ack is **fire-and-forget**: the client sends it and moves on. If the ack is lost in flight,
the server never advances the floor, `ack_wait` elapses, and the message is redelivered to a reader
that already handled it.

A **double ack** sends the ack as a request and waits for the server to confirm it landed. It costs
a round trip per message, so it is a deliberate choice for work where reprocessing is harmful and
the handler cannot be made idempotent. There is no CLI flag — it is a client-library call, named
`DoubleAck` (Go), `ackAck` (JavaScript), `ack_sync` (Python), `ackSync` (Java), `AckAsync` with the
double-ack option (.NET) and `double_ack` (Rust) (source: [[s-docs-delivery-and-acknowledgment]]).

## What configures it

Values below are as the 2.14 docs state them (source: [[s-docs-acknowledgment]],
[[s-docs-pull-consumers]]) and, where a line reference is given, confirmed against the server at
**v2.14.6** (source: [[s-nats-server-constants-2.14.6]]) — the docs' consumer reference does not
expose these at all, which is issue 4 in `inbox/docs-issues.md`.

| setting | CLI flag | default | what it does |
|---|---|---|---|
| `ack_wait` | `--wait` | **`30s`** (`consumer.go:573`) | how long the server waits for an answer before redelivering |
| `max_deliver` | `--max-deliver` | **`-1` (unlimited)** (`consumer.go:589`) | how many times one message may be delivered before the server gives up |
| `max_ack_pending` | `--max-pending` | **`1000`** (`consumer.go:580`) | how many messages the consumer delivers before they are acked |
| `backoff` | `--backoff=linear --backoff-steps=N --backoff-min=… --backoff-max=…` | unset | a growing wait between redeliveries |
| `ack_policy` | `--ack` | `explicit` in the docs' walkthrough | see below |

### Backoff

`backoff` is a list of delays, one per attempt. Three rules matter
(source: [[s-docs-acknowledgment]]):

- It **only shapes redeliveries that fire when the `ack_wait` timer runs out.** It does **not**
  slow a nak — to delay a nak, the client attaches the delay to the nak itself.
- If the list has fewer entries than `max_deliver` allows, the server **reuses the last entry** for
  the remaining attempts.
- **Setting a backoff replaces `ack_wait`**: the first entry becomes the wait before the first
  redelivery, and therefore the ack deadline for the first delivery too. A `--backoff-min=1s` drops
  the effective ack deadline to 1 second, overriding any `--wait` set earlier. Pick a
  `--backoff-min` at least as long as normal processing takes.

### Ack policies

| value | behaviour |
|---|---|
| `explicit` | each message is answered on its own — the right default for work that must not be lost, and what everything on this page assumes |
| `none` | no answer required; the server treats a message as done the moment it is delivered. No pending list, no ack wait, no redelivery |
| `all` | one ack retires every earlier message too — cheaper, but only fits a consumer that processes strictly in order |
| `flow_control` | used by the push consumers the server creates for durable mirrors and sources; acks ride the flow-control responses and behave like `all` |

`ack_policy` is **fixed at creation** (source: [[s-docs-policies]]).

## Limits and failure modes

Ranked by how often they are the answer.

1. **A handler that processes but never acks looks exactly like a crashed reader.** The message
   stays in flight, `ack_wait` elapses, and with the default `max_deliver: -1` that repeats
   **forever**. Always ack on the success path.
2. **`ack_wait` shorter than real processing time causes double work.** The server decides the
   worker stopped and redelivers a message that is still being handled, so two workers run the same
   job. Either raise `ack_wait` to cover the slow case, or send **in-progress** to reset the timer
   while a long job runs.
3. **A plain nak retries with no delay.** A transient failure then retries in the same instant,
   fails again, and pins one worker on one message. Nak *with a delay*; a consumer backoff will not
   help, because backoff only spaces out `ack_wait` timeouts.
4. **A poison message with no term path burns every delivery attempt** and holds up the messages
   behind it. When the code can tell no future attempt will succeed, answer **term** so the message
   leaves the pending list at once. Use term only when that is genuinely knowable; when in doubt,
   nak with a delay and let `max_deliver` decide.
5. **`max_deliver` drops a message with no dead-letter.** **JetStream has no built-in dead-letter
   queue.** When a message hits the limit the server removes it from the consumer's pending list
   and never delivers it again; the message stays in the stream but the consumer's normal output
   says nothing. Watch the max-deliveries advisory (below) or the drop is invisible.
6. **`ack_policy: all` on a consumer with `max_ack_pending` above 1 is silent data loss.** Acking
   message 10 also retires a message 7 that failed and was waiting to come back. Strict order is a
   thing you have to create with `max_ack_pending: 1`, not something a consumer does by default.
7. **Acking twice does nothing useful.** Go and Python reject the second ack locally with
   *"message was already acknowledged"*; other clients ignore or resend it, and the server ignores
   the duplicate either way. Ack each delivery exactly once, in one place in the handler.

## What you can observe

Three advisories make the loop visible (source: [[s-docs-acknowledgment]]):

| event | subject |
|---|---|
| nak | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>` |
| term | `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.<stream>.<consumer>` |
| delivery-limit drop | `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>` |

**`MSG_NAKED`, not `MSG_NAK`.** The docs' advisory reference page gives the shorter form and it is
wrong — the server publishes `MSG_NAKED` (`jetstream_api.go:244` at v2.14.6, used at
`consumer.go:1244`). A subscription to `MSG_NAK` receives nothing, silently. See [[advisories]] and
issue 1 in `inbox/docs-issues.md`.

The terminated advisory carries the stream and consumer sequence, the delivery count, and an
optional reason attached to the term. The full set will live in [[advisories]].

`nats consumer info` prints the controls and the state:

```
Configuration:
           Ack Policy: Explicit
             Ack Wait: 10.00s
        Replay Policy: Instant
   Maximum Deliveries: 5
      Max Ack Pending: 1,000
```

and `num_ack_pending`, `num_redelivered`, `num_pending` and `ack_floor` in the JSON
(source: [[s-docs-consumer-config]]).

## Cheat sheet

```
nats consumer edit ORDERS shipping --ack=explicit --wait=10s --max-deliver=5
nats consumer edit ORDERS shipping --backoff=linear --backoff-steps=5 --backoff-min=1s --backoff-max=30s
nats consumer next ORDERS shipping --ack
nats consumer next ORDERS shipping --no-ack
nats consumer next ORDERS shipping --term
nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping'
nats events --js-advisory --no-srv-advisory
```

## To verify

- The 2.14 docs state that **a plain nak redelivers immediately**. Question-bank Q23's neighbour
  Q18 ("why doesn't a NAK cause an immediate redelivery?") asserts the opposite from a real
  thread — the thread behind Q18 has not been read yet, so the wiki does not claim an answer.
- Whether a **delayed nak holds a `max_ack_pending` slot** while it waits (question-bank Q19) is
  not stated by any source ingested so far.
- No source ingested so far gives **metrics** (as opposed to advisories) for acked / naked /
  terminated / redelivered counts (question-bank Q59).

## Related

[[consumer]] · [[stream]] · [[retention-policies]] · [[worker-pool]] · [[advisories]] ·
[[consumer-keeps-redelivering]]

## Sources

[[s-docs-delivery-and-acknowledgment]] · [[s-docs-acknowledgment]] · [[s-docs-pull-consumers]] ·
[[s-docs-consumer-config]] · [[s-docs-policies]] · [[s-nats-server-constants-2.14.6]]
