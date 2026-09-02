---
title: "Observed on nats-server v2.14.6 — issue #6921's recipe, a redelivery loop from the outside, and a 10 µs ack deadline"
type: summary
area: [jetstream]
source-path: raw/nats-server-src/redelivery-observed-v2.14.6.md
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/consumer.go
author: "run locally; server source by the nats-io authors"
article: "runs G, H and I on nats-server v2.14.6 with nats CLI 0.4.0 through tools/lab, plus server/consumer.go at the tag"
date: 2026-09-03
version: "2.14.6"
tags: [redelivery, ack, ack_wait, backoff, max_deliver, last_per_subject, tries, num_redelivered, trace, observed, measured]
aliases: [redelivery observed, run G, run H, run I]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# Observed on v2.14.6 — three runs behind `consumer-keeps-redelivering`

Made for step 5 of `inbox/plan-the-runnable-scouts-2026-09-02.md` on one standalone server from
`NATS_LAB_FLAGS=-DV bash tools/lab/cluster.sh up 1`; scripts `redelivery-runG.sh`, `-runI.sh`,
`-runH.sh`, `-runH-batch.py`, `-runH-repeat.sh` beside the record. **Every number is one laptop and a
localhost round trip** — evidence of a mechanism, not a figure to size by.

## Key claims

**1 · Issue #6921's recipe does not reproduce on 2.14.6 (run G).** The reporter's stream and
publishes verbatim (`FIVE`, `--max-msgs-per-subject=5`, two messages on each of `five.1`–`five.5`),
a consumer with `--deliver subject --filter '>' --ack explicit --max-pending 1 --max-deliver 3 --wait
30s`: five messages delivered once each, `tries: 1` throughout, `Acknowledgment Floor: Consumer
sequence: 5 Stream sequence: 10`, `Redelivered Messages: 0`, the sixth pull a timeout. The 2.11.4
report showed the floor stuck at consumer sequence 1 ([[s-issue-6921-last-per-subject-acks]]).

**2 · What a redelivery loop looks like (run I)**, `ack_wait: 2s`, three messages fetched with
`--no-ack`, then again after three seconds:

- The CLI prints the delivery count: `tries: 1` … then `tries: 2` with the same `str seq` and a new
  `cons seq` (4, 5, 6). The count is the first number after the consumer name in the message's reply
  subject — `$JS.ACK.LOOP.worker.2.1.4.<ts>.0` is delivery 2 of stream sequence 1, consumer sequence
  4 — and the `-DV` trace shows that subject on every `->> [MSG …]` line.
- `nats consumer info`: `Last Delivered Message: Consumer sequence: 6 Stream sequence: 3` climbing,
  `Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0` fixed, `Outstanding Acks: 3`,
  `Redelivered Messages: 3`. JSON: `num_ack_pending: 3, num_redelivered: 3, ack_floor.stream_seq: 0,
  delivered.consumer_seq: 6`.
- **The server log has nothing.** Zero `INF`/`WRN`/`ERR` lines mention the stream or subject across
  the run. Acks, when sent, are `<<- [PUB $JS.ACK.<stream>.<consumer>.… ]` trace lines from the client.
- Acking clears it: `Outstanding Acks: 0`, `Redelivered Messages: 0` — `num_redelivered` is the count
  currently tracked, not a lifetime tally.

**3 · `backoff: [10000]` is a ten-microsecond ack deadline (run H.1).** Created through
`$JS.API.CONSUMER.CREATE` with the Stack Overflow poster's numbers (`max_deliver: 2`, `backoff:
[10000]`), the server stores `ack_wait: 10000` and the CLI prints `Ack Wait: 10µs`. With
`max_deliver` omitted it is `-1`; with `max_deliver: 1` against a one-entry backoff the create is
accepted.

**4 · Acked on arrival, the ack usually beats the timer — on localhost (run H.2).** One pull of
`batch: 100` kept open, every message acked the instant it arrives: six fresh pulls of seven
delivered every message once; the seventh redelivered the same ten messages **ninety times in six
milliseconds** (delivery counts up to 15) until the batch was used up, and its state was clean
afterwards. Acks are queued off the read loop and processed by the consumer's goroutine
(`processInboundAcks`, `consumer.go:5182`; pushed at `:2778–2779`) while `checkPending` expires
them; at ten pending nothing arbitrates (`:6031` yields to in-flight acks only above 1024).

**5 · With 5 ms of work before the ack, the timer wins every time (run H.3).** `max_deliver: 2`:
**every message delivered exactly twice**, all twenty deliveries acked — the Stack Overflow report to
the letter ([[s-so-78603662-acked-but-redelivered]]). `max_deliver: -1`: **ten times each**, the
batch of 100 exhausted. `ack_wait: 30s`: once. Counters clean in every case; the only trace of the
doubled work is `delivered.consumer_seq` (10 against 100).

**6 · A redelivery needs a pull waiting when the deadline passes.** Batch 10 against ten messages,
three pulls in a row, 5 ms ack delay, `max_deliver: 2`: once each, and pulls two and three return
nothing. The first pull was satisfied before the timer fired; the expired messages went on the
redelivery queue, the acks landed and cleared them, and the next pull found it empty. A consume loop's
open pull is what lets the tail of a batch come straight back; `nats consumer next` one at a time
does not.

**7 · The mechanism, `server/consumer.go` at v2.14.6:** `:658` — `config.AckWait = config.BackOff[0]`;
`checkPending` `:6003–6110` — `deadline = int64(o.cfg.BackOff[dc])` (`:6066`), `if elapsed >=
deadline` (`:6072`) → the redelivery queue (`:6088`) unless `hasMaxDeliveries` (`:2372`) drops it; the
timer re-armed with the smallest entry (`:6025`); `processAckMsgLocked` `:3717–3731` — an explicit ack
clears `pending[sseq]`, the redelivery count and the queue entry **whichever delivery it names**, so
the second ack of a doubled message finds nothing and the floor ends correct.

## Practical takeaways

- **Read `Ack Wait:` in `nats consumer info` before reading anything else.** A backoff's first entry
  is that number, in nanoseconds on the API; `10µs` means every delivery is a race the handler cannot
  win, and `max_deliver` is how many times each message will be processed.
- **"Intermittent" is the race.** The same configuration processes once on a laptop and twice across
  a network, because the ack's arrival is what stops the redelivery and the timer does not wait.
- **The redelivery loop leaves no log line.** Watch `num_redelivered`, `ack_floor` and `tries:`, or
  start the server with `-DV` and grep for `$JS.ACK`; the default log will not tell you.
- **Issue #6921's shape is closed at 2.14.6**; the page states it against the 2.11.0–2.11.4 range the
  reporters saw, not as current behaviour.

## Relevance to the wiki

The measured half of [[consumer-keeps-redelivering]]: its *Symptom* section is run I verbatim, its
first cause is run H, and its known-defect table's first row is run G's negative. It also adds to
[[ack-and-redelivery]] the rule that a redelivery needs a waiting pull, and to [[consumer]] the
`$JS.ACK` reply-subject fields the CLI reads `tries:` from.

## Questions it answers

Row 14 (the mechanism, measured), row 16 (the batch on the clock — with the open pull that brings the
tail back), row 17 (the backoff's unit and its first entry as the deadline).

## Pages touched

[[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[consumer]] · [[nats-net]]
