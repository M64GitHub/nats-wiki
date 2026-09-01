# Scout — delivery timing: when a message comes back, and how to make it come later (2026-09-01)

**Why this topic.** The consolidation plan finished with the question bank at **105/83** and ★
complete (42/42). The 22 remaining rows need *sources*, not synthesis — so the next move is an
ingest, and this scout picks the ground. Six of the 22 form one coherent mechanism:

| row | question | state before this scout |
|---:|---|---|
| **16** | How do `ack_wait` and the duplicate window interact? | open |
| **17** | Does JetStream support exponential backoff for redelivery? | open |
| **18** | Why doesn't a NAK cause an immediate redelivery? | open |
| **19** | Does `NakWithDelay` hold a `max_ack_pending` slot and block other messages? | open |
| **29** | Can the server schedule a message for later, with cron-style patterns? | open |
| **30** | Message scheduler vs NAK-with-delay for scheduled work at scale — which one? | open |

They are one topic because they are one decision: **a message needs to arrive later than now — do you
delay the redelivery, or schedule the publish?** Rows 16–19 are the redelivery half, 29–30 the
scheduler half, and row 30 is the maintainer being asked to choose between them.

**Everything below was fetched or read on 2026-09-01.** Nothing is ingested. Quotes from remote pages
come from a **skim** and must be re-read verbatim into `raw/` at ingest time; quotes from local files
are exact, with line numbers.

---

## The candidates

### Redelivery — rows 16–19

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---|---|---|
| 1 | [gh#6628 — ack-wait and dupe-window behavior](https://github.com/nats-io/nats-server/discussions/6628) | @MauriceVanVeen: the two settings "are not related to each other" — dupe window is a **stream** setting bounding re-*publication* of the same `Nats-Msg-Id`; `ack_wait` is a **consumer** setting bounding re-*delivery*. The asker's real cause was a pull batch of 100. Closed, not formally accepted | 16 | [[ack-and-redelivery]] · [[publishing]] · [[consumer]] | ★ closes 16 |
| 2 | [gh#6350 — exponential backoff](https://github.com/nats-io/nats-server/discussions/6350) | **Accepted answer** (@jnmoyne, 2025-01-10): two paths, and they are not the same path — consumer `Backoff` for an *implicit* failure (no ack before `AckWait`), `nakWithDelay` for an *explicit* one | 17 | [[ack-and-redelivery]] · [[consumer]] | ★ closes 17 |
| 3 | [gh#5631 — Nak does not immediately redeliver](https://github.com/nats-io/nats-server/discussions/5631) | **Zero comments, still Unanswered.** Server 2.10.14, C# client 1.0.4, "cannot be reproduced in isolation", no error on `Nak`. The reported symptom: redelivery arrives after the ack timeout instead of at once | 18 | [[ack-and-redelivery]] · [[consumer-keeps-redelivering]] (wanted) | ★ **the contradiction below is about exactly this** |
| 4 | [gh#4972 — does NakWithDelay block the queue?](https://github.com/nats-io/nats-server/discussions/4972) | Two maintainers, **working as designed**: @ripienaar — "Any messages that was once delivered and had to be retried is pending, its an important constraint as max pending is used to manage ordering to name but one case… there's no alternative today." The reporter set `MaxAckPending: 10`, nak'd ten with a one-minute delay, and the consumer stopped | 19 | [[ack-and-redelivery]] · [[worker-pool]] · [[jetstream-sizing]] | ★ closes 19 |
| 5 | [`learn/jetstream/acknowledgment.md`](https://docs.nats.io/learn/jetstream/acknowledgment.md) — **already mirrored and ingested** ([[s-docs-acknowledgment]]) | not a new candidate: the reference point for the contradiction below. Says three times that backoff does not slow a nak (lines 42, 298, 586 of the local copy) | 17 · 18 | — | already in |
| 6 | [Reliable Message Delivery in NATS JetStream: Acks, Retries, Dead Letters, and Replay](https://www.synadia.com/blog/jetstream-reliable-delivery-dlq-replay) — Andrew Connolly, **2026-07-24** | the applied layer: nak vs nak-with-delay vs backoff, sizing `MaxDeliver` against the length of the backoff schedule, and a **dead-letter pattern** built on the max-deliveries advisory (capture the advisory, fetch the original by sequence, republish). The wiki has no DLQ page | 17 · 18 (+ new rows) | [[ack-and-redelivery]] · [[advisories]] · [[consumer]] · a wanted **dead-letter-queue** pattern page | ★ **and it contradicts the docs — see below** |

### The scheduler — rows 29–30

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---|---|---|
| 7 | **ADR-51 — JetStream Message Scheduler** · already at `raw/adr/ADR-51.md`, 293 lines | the spec, **Approved**, 8 revisions from 2025-03-21 to 2026-05-27 tracking 2.12 → 2.14. `AllowMsgSchedules` / `allow_msg_schedules`, the `Nats-Schedule*` header family, the `@every 1m` minimum, `Nats-Schedule-Time-Zone` (cron only — "not allowed to be used if the schedule is not a Cron schedule"), `Nats-Schedule-Rollup: sub`, error **10212** and why it exists, **Discard New not supported** (rev 8, server version "TBD"), that enabling the feature *implicitly* enables `AllowRollup` and clears `DenyPurge`, and a two-stream WorkQueue composition for interest retention | 29 · 30 | a new **message-scheduling** concept page · [[stream]] · [[message-ttl]] · [[retention-policies]] · [[error-codes]] · [[nats-server-2.12]] · [[nats-server-2.14]] | ★★ the spine of the topic, **local, no fetch needed** |
| 8 | [gh#7672 — cron-like schedules](https://github.com/nats-io/nats-server/discussions/7672) | **Accepted answer** (@MauriceVanVeen): only single scheduled messages shipped in **2.12**; "The remaining items, like cron-like schedules, will be part of version 2.14". The asker's error is the operator-visible tell: `message schedules pattern is invalid` (= **10189**) — a version problem wearing a syntax problem's clothes | 29 | message-scheduling · [[error-codes]] · [[nats-server-2.12]] | ★ closes 29 |
| 9 | [gh#7628 — scheduler vs NakWithDelay at scale](https://github.com/nats-io/nats-server/discussions/7628) | **Accepted answer** (@MauriceVanVeen, 2025-12-09), and it answers row 30 directly: "Would definitely recommend using the new 2.12 scheduling feature over NakWithDelay, since **Nak is not meant for that purpose** and only really works as a workaround because the 2.12 scheduling feature wasn't there before. It should support a very large amount of schedules since it's **built on top of the per-message TTL work**… But, it's always good to test for your use case." Asked in the context of 100K+ pending schedules | 30 · 19 | message-scheduling · [[ack-and-redelivery]] · [[message-ttl]] | ★ closes 30 |
| 10 | [`reference/jetstream/api/headers.md`](https://docs.nats.io/reference/jetstream/api/headers.md) — **already mirrored** at `raw/nats-docs/reference/jetstream/api/headers.md`, **not ingested** | the header table with a worked example (line 205): `Nats-Schedule`, `Nats-Schedule-Time-Zone`, `Nats-Schedule-TTL`, `Nats-Schedule-Target`, `Nats-Schedule-Source`, `Nats-Schedule-Rollup`, `Nats-Schedule-Next` (RFC3339 or `purge`), `Nats-Scheduler`. Also carries the rest of the JetStream header space | 29 | message-scheduling · [[publishing]] · [[js-api-subjects]] · [[message-ttl]] | ★ local, cheap |
| 11 | [Delayed Message Scheduling in NATS JetStream](https://www.synadia.com/blog/delayed-message-scheduling-nats-jetstream) — Peter Humulock, **2026-04-09** | the applied layer for the scheduler: the six-field cron (seconds first), what is 2.12 vs 2.14, and four caveats a spec states less plainly — a past-dated schedule fires **immediately, including on server restart**; one schedule per subject, latest replaces prior; not available on mirrors or sourced streams; **DST transitions may skip or duplicate** a cron execution | 29 · 30 | message-scheduling · [[mirrors-and-sources]] | ★ needs fetching into `raw/` |

**Nothing was blocked.** All six discussions, both blog posts and the live `docs.nats.io/llms.txt`
returned content; ADR-51 and the headers reference are already in `raw/`.

---

## The find: two sources disagree about whether backoff applies to a nak

This is the reason the scout is worth more than its candidate list, and it is
[*Operation: record a docs issue*](../CLAUDE.md) shaped — **verify against the server at a release
tag before anything else**.

**The docs say a backoff does not slow a nak**, three times, in
`raw/nats-docs/learn/jetstream/acknowledgment.md`:

> line 298 — "A **backoff** on the consumer grows the wait automatically, but it only shapes
> redeliveries that fire when the AckWait timer runs out — **it doesn't slow a nak**."

> line 586 — "A bare nak redelivers right away, and a configured backoff doesn't slow it — to delay a
> nak, the client attaches the delay to the nak itself."

> line 42 — "the CLI's `--nak` only asks for immediate redelivery".

**The Synadia post (candidate 6, 2026-07-24) says the opposite** — that the backoff schedule applies
to redeliveries triggered by a negative acknowledgement, not only to `AckWait` expiry. *(Read from a
skim; the exact sentence must be captured into `raw/` before this is recorded as an issue.)*

**And row 18 is an operator standing between them**: gh#5631 reports a nak that did **not** redeliver
immediately, on 2.10.14, with no error — the symptom you would expect if something *were* delaying it.
Nobody has ever replied to that thread.

So three sources, three positions, and the wiki's own [[ack-and-redelivery]] currently states the
docs' one. **The server at v2.14.6 settles it**, and the claim is behavioural, not a constant — so per
the rulebook it has to be *run*, not just read: a consumer with a backoff, a bare nak, and the
observed time to redelivery, recorded in `raw/nats-server-src/`. Three outcomes, three destinations:

- backoff does **not** apply to a nak → the docs are right, the blog is wrong; a row in
  `inbox/docs-issues.md` against the blog's publisher, and row 18's symptom is still unexplained;
- backoff **does** apply → the docs are wrong in three places, which is a `wrong-value` row against
  `nats-docs`, and row 18 is *explained*;
- it depends on something neither says (client version, `nak` vs `nakWithDelay(0)`, whether
  `max_deliver` is bounded) → an `inbox/server-issues.md` observation, because there is no authority
  above the server to call it an error.

**Do not guess which.** Whatever the run shows, [[ack-and-redelivery]] gets the sentence and the
disagreement gets recorded.

## A second, smaller find: the scheduler has no prose anywhere in the docs

Checked against the **live** `docs.nats.io/llms.txt` on 2026-09-01, not just the 2026-08-31 mirror:
**no `learn/` chapter mentions message scheduling, scheduled messages, cron or delayed publishing.**
The feature exists in the docs only as a header table (`reference/jetstream/api/headers.md`), nine
error codes (`reference/jetstream/errors.md`: 10186, 10187, 10188, 10189, 10190, 10191, 10192, 10203,
10212) and three lines of release notes.

That is a shipped 2.12 feature, extended in 2.14, with a whole header family and nine error codes and
**no page telling anyone how to use it** — an `enhancement`-kind row for `nats-docs` once confirmed,
and the clearest reason this wiki should have a message-scheduling page: there is currently no
readable account of the feature outside the ADR and one vendor blog post.

**Not a gap, for the record:** `wiki/reference/error-codes.md` carries none of those nine codes, and
that is *correct* — the page says outright that "the full 222-row table is not reproduced here… This
page gives the structure, the lookup, and **the codes this wiki cites**." The nine join it when a page
cites them, not before.

## What this scout does *not* reach

- **Row 18 may not close.** Its thread has no answer and never has. The honest outcome could be a
  `no-public-answer` row whose `answered by` names the page that says so — unless the server run above
  explains the symptom, which is the one thing that would close it properly.
- The other 16 open bank rows are untouched: the scale-ceiling cluster (4, 5, 9, 13), the
  performance cluster (8, 10, 11, 68, 76, 91), the failure-operations cluster (37, 40, 66), core
  ordering (25), import limits (98) and the object-store mirror (105). Those want their own scouts;
  several look like genuine `no-public-answer` rows and should be scouted expecting that.

## Status

Nothing ingested. This section maps candidates to summaries once they are.

| candidate | summary |
|---|---|
| 1 · gh#6628 | |
| 2 · gh#6350 | |
| 3 · gh#5631 | |
| 4 · gh#4972 | |
| 6 · Synadia — reliable delivery / DLQ | |
| 7 · ADR-51 | |
| 8 · gh#7672 | |
| 9 · gh#7628 | |
| 10 · `reference/jetstream/api/headers.md` | |
| 11 · Synadia — delayed message scheduling | |
