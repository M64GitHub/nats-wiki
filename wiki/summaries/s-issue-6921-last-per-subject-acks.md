---
title: "nats-server issue #6921 — explicit acks on a last-per-subject consumer stop registering, and the messages redeliver (2.11.0–2.11.4)"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-server/issues/6921
source-path: raw/gh-issues/issue-6921.md
author: "@Jgfrausing (reporter); @osery (second reporter, bisected the fix); @neilalexander (maintainer); @swb2-izu-ssp"
article: "GitHub issue 6921 (defect, closed as completed), 15 comments"
date: 2025-10-01          # closed; opened 2025-05-23
version: "2.11.1"         # the reporter's server; reproduced on 2.11.4; fixed in 2.11.5 by a second reporter's bisect
tags: [redelivery, ack, ack-floor, last_per_subject, max_msgs_per_subject, interior-deletes, defect, fixed-in-2.11.5, dotnet, rust]
aliases: ["Explicit Acks on JetStream with multiple messages per subject causes deadlock"]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# Issue #6921 — a `last_per_subject` consumer whose acks stop taking

Opened 2025-05-23 as a repost of nats.net #860, labelled *defect*, and closed 2025-10-01 after a
second reporter bisected the fix to **2.11.5**. It is the one public thread in which "my consumer keeps
redelivering messages I acknowledged" turned out to be a **server bug with a version range**, not a
client mistake — and the reason the wiki's `consumer-keeps-redelivering` page has a *known defect*
cause with a table.

## Key claims

- **The setup.** Stream `CONTRACTS` on `contracts.>`, R1, file storage, `max_msgs_per_subject: 5`
  (the reporter's own annotation: "This seems to be the cause of the issue"), `max_age` two days. A
  consumer with `AckPolicy: Explicit` and `DeliverPolicy: LastPerSubject`. Server **2.11.1**; the
  client version is given as `0.1.6`.
- **The symptom.** "After a few successfully ACKed messages the producer stalls as it no longer
  receives the ACK. After the wait time the messages are being redelivered, but ACK are still not
  registered." Visible as the `Acknowledgment Floor` no longer moving and `Unprocessed messages`
  staying put; `Outstanding Acks` at "1000 out of maximum 1000"; raising the ack wait from the
  client's default of 2 s to 30 s changed nothing.
- **Work-arounds the reporter found**: `AckPolicy: None`, or `DeliverPolicy: All`. A commenter's
  `max_msgs_per_subject: 1` was declined — "just because one consumer needs only the last, it might
  be, that others need more" — and the second reporter's stream is read by a mix of `LastPerSubject`
  and `New` consumers.
- **Still there on 2.11.4**, which the maintainer had hoped fixed it (#6899, "a deadlock … when
  calculating the first sequence number for a consumer with a deliver-last-per-subject deliver
  policy"). The reporter's `nats consumer info` with `Max Ack Pending: 1` to make the stall
  deterministic: `Last Delivered Message: Consumer sequence: 3 Stream sequence: 77,826,706`,
  `Acknowledgment Floor: Consumer sequence: 1 Stream sequence: 77,826,605 Last Ack: 56.18s ago`,
  `Outstanding Acks: 1 out of maximum 1`, `Redelivered Messages: 1`, `Unprocessed Messages: 70,382`;
  metadata `_nats.ver: 2.11.4`. The same code with `Deliver Policy: All`: consumer sequence 308,
  floor 307, each ack about a millisecond after delivery.
- **The minimal recipe** (2025-06-06): `docker run … nats -js`; `nats stream add
  --max-msgs-per-subject=5 --subjects "five.>" --max-age 1h --storage file FIVE --defaults`; two
  publishes to each of `five.1` … `five.5`; a `LastPerSubject` + `Explicit` + `MaxAckPending 1`
  consumer that acks every message. Fails in C# and in Rust. It "worked" in Go for a month —
  because the Go code **omitted `MaxAckPending: 1`** and ran at the default of 1000 (@osery spotted
  it); with the cap added, Go stalled too. The reporter: the cap is not the cause, it "makes it more
  likely to occur" — production hit it at the default with more than 50,000 messages and up to five
  per subject. @osery: "We had the same issue with 1000, just happening less often."
- **Range and fix.** @osery: "server versions 2.11.0+", and it was "blocking us in updating past
  version 2.11.0"; on 2025-10-01: "I bisected, and the issues seems to have been fixed in 2.11.5."
  Closed the same minute. **No pull request is linked on the issue**; the v2.11.5 release notes name
  it — "The consumer `DeliverLastPerSubject` delivery policy now correctly deliver messages and
  handles acks when there are interior deletes, such as when `MaxMsgsPerSubject` limits are in use on
  the stream (#7005)" ([[s-relnotes-2.11.5]]).
- **Cross-referenced** from #6795 ("MaxMsgsPerSubject not working as intended [v2.11.1]") and #6772
  ("Jetstream / MessageConsumer not working in Kubernetes environment").
- **Re-run on 2.14.6** ([[s-nats-server-redelivery-observed]], run G): the recipe with `--max-pending
  1` delivers the five last-per-subject messages once each, the floor follows every ack to 5 / 10, no
  redelivery. The defect is gone at the release the wiki cites.

## Practical takeaways

- **The shape to recognise**: deliver policy `last_per_subject`, `ack_policy: explicit`, and a stream
  whose per-subject limit removes older messages — `max_msgs_per_subject` above 1 with several
  messages per subject, which is interior deletes. On **2.11.0–2.11.4** the floor freezes after the
  first acks and every redelivery's ack is lost too; on 2.11.5 and later it does not happen.
- **How to tell it apart from a client problem**: the server version (`_nats.ver` in the consumer's
  metadata, `nats server info`, `nats server list`) inside the range; `Deliver Policy: Last Per
  Subject`; a floor that stops while `Last Ack` ages and `Outstanding Acks` sits at the cap; and the
  same handler on a `Deliver Policy: All` consumer acking normally.
- **The fix is the upgrade** — 2.11.5 or later; every 2.12 and 2.14 release carries it. Until then:
  `DeliverPolicy: All` with the last-value selection in the client, or `ack_policy: none` when the
  consumer really only wants the latest value and can lose one.
- **A reproduction that differs by one setting is a different test.** One omitted field kept the Go
  version "working" and the bug report unresolved for a month.

## Notable quotes

> "After a few successfully ACKed messages the producer stalls as it no longer receives the ACK. After
> the wait time the messages are being redelivered, but ACK are still not registered."
> — @Jgfrausing, 2025-05-23

> "I bisected, and the issues seems to have been fixed in 2.11.5." — @osery, 2025-10-01

## Relevance to the wiki

The source the wiki's last wanted page was waiting for. It supplies the *known server defect* cause
of [[consumer-keeps-redelivering]] — with a shape, a version range and a fix release — and a version
note for [[consumer]] and [[nats-server-2.11]]. It also shows what the symptom looks like when the
cause is not the handler: the floor stops while everything else looks calm.

## Questions it answers

Row 14 — one of its causes, the only one that is a server bug.

## Pages touched

[[consumer-keeps-redelivering]] · [[consumer]] · [[nats-server-2.11]] · [[ack-and-redelivery]]
