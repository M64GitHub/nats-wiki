---
title: "nats-server v2.11.2 release notes (2025-04-25) — acked messages redelivered after a consumer leader change, with the redelivery lines of v2.10.16 and v2.10.17"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.11.2
source-path: raw/release-notes/v2.11.2.md
author: "nats-io/nats-server maintainers"
article: "Release v2.11.2 body (GitHub release), plus the redelivery lines of raw/release-notes/v2.10.16.md and v2.10.17.md"
date: 2025-04-25
version: "2.11.2"
tags: [release, 2.11.2, 2.11.3, 2.10.16, 2.10.17, redelivery, ack, leader-change, replicated-consumers, restart, regression, withdrawn]
aliases: [v2.11.2, v2.10.16, v2.10.17]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.11.2 (2025-04-25), and the 2.10 lines — three times "acked, then redelivered" was the server

Read for the version layer of one symptom: a message the client acknowledged comes back. The public
notes record three occasions on which that was a server defect, all around **restarts and leader
changes of replicated consumers**; this summary holds the three lines and the release that carries
each. Phase D will fold them into the per-minor summaries; the whole bodies are in
`raw/release-notes/`.

## Key claims — v2.11.2

- **The release is withdrawn.** The body opens with a banner: "This version contains a regression that
  has since been fixed in 2.11.3. Please upgrade to that version instead." So the floor for what
  follows is **2.11.3**, not 2.11.2.
- **The fix, unnumbered** (Fixed, JetStream): "Fix clustered consumer consistency problems by waiting
  for delivered state to reach quorum before delivering new messages, resolving issues where
  acknowledged messages could be redelivered after a consumer leader change" — with a note attached:
  "**NOTE:** This may negatively impact the throughput of replicated consumers. R1 consumers,
  consumers with `AckNone` ack policy and ordered consumers are not affected and may be more suitable
  for high-speed processing."
- **Its companion**: "Preserve the redelivered state if the consumer leader is placed on a server that
  is a lagging stream follower to keep accounting correct (#6698)".
- Other consumer-side fixes in the same body: "Use the correct floor when using `AckAll` in R1
  consumers (#6790)"; "Correctly remove messages from an interest-based stream when using `AckAll`
  consumers (#6587)"; "Correctly handle acks for subjects that include a `@` character (#6777)"; "Push
  consumers are no longer incorrectly marked as inactive after a delivery failure if there is
  continued interest (#6807)"; "Consumer priority groups will no longer get stuck in a tight-loop …
  (#6749)".
- Also in 2.11.2: "Correctly enforce the 32MB maximum publish size limit into JetStream, avoiding
  filestore corruption from overflowing the maximum record length (#6798)"; "Servers that have been
  `peer-remove`'d can now be re-admitted automatically after 5 minutes without a server restart
  (#6815)"; a new `trace_headers` option "to ensure that trace logging only emits headers and not
  message payloads (#6638)"; "Subject delete markers are now placed for messages that have aged out
  due to their TTL and not just because of the `MaxAge` policy (#6741)".

## The lines from v2.10.16 (2024-05-21) and v2.10.17 (2024-06-27)

- **v2.10.16**: "Fix potential redelivery of acked messages during server restarts (#5419)"; "Fix
  various delivery counter logic (#5338, #5361)". The body also carries a warning banner of its own —
  "A possible regression may result in a server panic at startup when `tav.idx` files were incorrectly
  truncated down to zero bytes", with the work-around of deleting zero-byte `tav.idx` files.
- **v2.10.17**: "Fix possible redelivery after successful ack during rollout restarts (#5482)";
  "Follower stores no longer inherit the redelivered consumer delivered sequence which could break
  ack gap fill (#5533)"; "Ensure ack processing is consistent and correct between leader and followers
  for replicated consumers (#5524)"; "Ensure consistency of the delivered stream sequence in `/jsz`
  filtered consumer reporting (#5528)"; and, for the other page this feeds, "Fixed a bug that would
  return “no message found” for last_per_subject (#5578)".

## Practical takeaways

- **The shape to recognise**: a replicated (R3) consumer, a rolling restart or a consumer leader move,
  and messages that were acked before it coming back afterwards. On a 2.10 older than **2.10.17** or a
  2.11 older than **2.11.3**, suspect the server before the handler; on anything newer, look
  elsewhere first.
- **The 2.11.2 fix has a stated cost**: replicated consumers wait for their delivered state to reach
  quorum before delivering more. The note's own exemptions — R1 consumers, `AckNone`, ordered
  consumers — are the shapes to choose when throughput matters more than exactly-once-after-failover.
- **2.11.2 itself is not a version to run**: the banner sends everyone to 2.11.3.

## Questions it answers

- Version layer for **row 14** — the *known defect* cause on [[consumer-keeps-redelivering]], the
  restart and leader-change rows of its table.

## Pages touched

[[consumer-keeps-redelivering]] · [[nats-server-2.11]] · [[nats-server-2.10]] ·
[[ack-and-redelivery]] · [[consumer]]
