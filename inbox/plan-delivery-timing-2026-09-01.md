# Plan — delivery timing: when a message comes back, and how to make it come later (proposed 2026-09-01)

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how. One step at a
time, `status:` rewritten in place, `wiki/log.md` appended, `python3 tools/lint.py` run, question-bank
cells filled, and each step reported before the next begins.

**Where this comes from.** `inbox/scout-delivery-timing-2026-09-01.md`, written the same day. Read it
first: it has the candidate list, the URLs, and the two findings this plan exists to settle.

**Why this plan now.** The consolidation plan took unlanded ripples **252 → 0**, which means the
reader layer has absorbed everything the summary layer holds. The bank is at **105/83** with ★
complete (42/42), so the remaining work is not synthesis — it is **sources**. Six of the 22 open rows
are one mechanism, and eleven candidates cover them, four of them already sitting in `raw/`.

**What makes it worth doing before the other clusters.** Two things the scout turned up:

1. **Two sources contradict each other on whether a consumer backoff applies to a nak** — the docs say
   no, three times; a Synadia post says yes. An open, never-answered thread (row 18) sits exactly
   between them. **The local binary is v2.14.6, which is what [[ack-and-redelivery]] already cites**,
   so this is runnable and attributable today.
2. **The message scheduler has no prose in the docs at all** — verified against the live
   `docs.nats.io/llms.txt`, not just the mirror. A shipped 2.12 feature, extended in 2.14, with nine
   error codes and no chapter. That is both a docs issue and the clearest case this wiki has for a
   page that does not exist yet.

**Rows this plan is trying to close:** 16, 17, 18, 19, 29, 30. Expect **five**; row 18 may honestly
end as `no-public-answer` (see step 2).

---

## Step 1 — the three answered redelivery threads · status: open

*Operation: ingest*, three times. The cheapest step and the context the rest needs.

- `ingest https://github.com/nats-io/nats-server/discussions/6628` → `s-gh-6628-ackwait-vs-dupe-window`
- `ingest https://github.com/nats-io/nats-server/discussions/6350` → `s-gh-6350-exponential-backoff`
- `ingest https://github.com/nats-io/nats-server/discussions/4972` → `s-gh-4972-nak-with-delay-blocks`

Use `tools/extract-forum-posts.py`; record all three in `raw/sources.md`.

**Ripple, expected 5–15 pages:** [[ack-and-redelivery]] is the centre and takes all three.
[[publishing]] takes 6628's half of the distinction (the duplicate window bounds re-*publication* of a
`Nats-Msg-Id`, not re-*delivery*). [[consumer]] takes the pull-batch cause 6628 actually resolved on.
[[worker-pool]] and [[jetstream-sizing]] take 4972: **a nak'd message still occupies its
`max_ack_pending` slot for the whole delay**, "because max pending is used to manage ordering", so
delayed naks and a small cap stall a pool — which is the same shared-cap trap step 8b of the last plan
put on [[ack-and-redelivery]], now with a maintainer's reason attached.

**Watch for:** whether 6350's two-paths answer (consumer `Backoff` for an implicit failure,
`nakWithDelay` for an explicit one) is stated on [[ack-and-redelivery]] as *two* mechanisms rather
than one. If the page blurs them, that is the fix this step earns.

**Closes rows 16, 17, 19.** Do **not** touch row 18 here — it is step 2's.

## Step 2 — settle the nak-and-backoff contradiction on the binary · status: open

The step this plan is really for. *Operation: ingest*, then *Operation: record a docs issue* — and
the claim is **behavioural**, so the rulebook requires it to be **run**, not read.

1. `ingest https://www.synadia.com/blog/jetstream-reliable-delivery-dlq-replay` (Andrew Connolly,
   2026-07-24) → `s-synadia-reliable-delivery-dlq`. Capture the nak/backoff sentence **verbatim** into
   `raw/` — the scout's version is a skim and must not be quoted as a source.
2. **Run it on v2.14.6** (`nats-server --version` first; it must still read `v2.14.6`, the version
   [[ack-and-redelivery]] cites). A consumer with an explicit `--backoff`, a bare `nats consumer next
   --nak`, and the measured time to redelivery — against a control with no backoff. Vary the one thing
   the sources might be splitting on: bare nak vs a nak carrying a delay. Record the exact config,
   commands and output in `raw/nats-server-src/nak-backoff-observed-v2.14.6.md`.
3. **Record the finding where it belongs**, which depends on the result:

| result | where it goes |
|---|---|
| backoff does **not** slow a nak | docs are right; a `wrong-value` row in `inbox/docs-issues.md` against the Synadia post — and row 18's symptom stays unexplained |
| backoff **does** slow a nak | `learn/jetstream/acknowledgment.md` is wrong in **three** places (lines 42, 298, 586) — `wrong-value`, `destination: nats-docs`, and row 18 is explained |
| it depends on something neither source names | `inbox/server-issues.md` as `SI-<n>` — an observation plus the question, because there is no authority above the server |

4. **Sweep the neighbours**, as the rulebook requires when a page is wrong: if the docs' acknowledgment
   chapter is wrong about nak-and-backoff, check its other timing claims against the same binary —
   `ack_wait` default, "setting a backoff replaces AckWait", `--nak` being immediate-only — and say in
   the entry how many were checked and how many were wrong.
5. Land the settled answer on [[ack-and-redelivery]], **with the disagreement stated on the page**, and
   re-check `verified-against` / `verified-on`.

**Row 18 closes only if the run explains the reported symptom.** If it does not, fill its `answered by`
with the page that says so **in bold** — the bank's own convention for a stated dead end — rather than
leaving the cell empty. A dead end that was actually investigated is worth more than a blank.

**Do not skip step 1.** 4972's "a retried message is pending" may already be half the answer to why a
nak looked slow to the reporter of gh#5631.

## Step 3 — the message scheduler, and the page that should exist · status: open

*Operation: ingest*, four sources, two of them already local — then the new page.

- `ingest raw/adr/ADR-51.md` → `s-adr-51-message-scheduler` (**Approved**, 8 revisions, 2.12 → 2.14)
- `ingest raw/nats-docs/reference/jetstream/api/headers.md` → `s-docs-jetstream-headers`
- `ingest https://github.com/nats-io/nats-server/discussions/7672` → `s-gh-7672-cron-schedules`
- `ingest https://github.com/nats-io/nats-server/discussions/7628` → `s-gh-7628-scheduler-vs-nak`

**The new page: `wiki/concepts/message-scheduling.md`.** The bank licenses it — rows 29 and 30 both
need it, and no page owns the material. Concept template. What it must carry, all of it from ADR-51
unless noted:

- `AllowMsgSchedules` / `allow_msg_schedules`, **permanent once set**, and that enabling it
  *implicitly* enables `AllowRollup` and clears `DenyPurge` — a security-relevant side effect that
  belongs on [[subject-permissions]] too;
- the header family and the worked example, from the headers reference;
- **what is 2.12 and what is 2.14**: single `@at` delays in 2.12; cron, `@every`, subject sampling and
  time zones in 2.14. gh#7672 is the operator-visible version of that boundary —
  `message schedules pattern is invalid` (**10189**) is what a 2.14 cron expression looks like on a
  2.12 server;
- the **six-field** cron (seconds first), the `@every 1m` minimum, and that
  `Nats-Schedule-Time-Zone` is cron-only;
- **error 10212** and the constraint behind it (`Nats-Scheduler` may not equal the publish subject, or
  the cancellation would be purged with the schedule by the auto-applied `Nats-Rollup: sub`);
- the limits: **Discard New unsupported** (rev 8, server version still "TBD" — say so), not available
  on mirrors or sourced streams (10186 / 10187), and the two-stream WorkQueue composition ADR-51 gives
  for interest retention;
- **the answer to row 30, quoted**: "Nak is not meant for that purpose and only really works as a
  workaround"; the scheduler is "built on top of the per-message TTL work", which is why it scales.

**Ripple:** [[stream]] (the new field and its permanence) · [[message-ttl]] (the scheduler is built on
it — this is the load-bearing link) · [[retention-policies]] (the WorkQueue/Interest composition) ·
[[mirrors-and-sources]] (10186/10187) · [[publishing]] · [[error-codes]] (**nine codes join** — 10186,
10187, 10188, 10189, 10190, 10191, 10192, 10203, 10212; the page's scope is "the codes this wiki
cites", so citing them is what earns them their rows) · [[nats-server-2.12]] · [[nats-server-2.14]] ·
[[ack-and-redelivery]] (the row-30 comparison) · [[js-api-subjects]] · [[subject-permissions]].

**Also:** fill the summary column for **ADR-51** in `inbox/adr-toc.md` (`tools/triage-adrs.py`
preserves those links on re-run), and add [[message-scheduling]] to `wiki/index.md`.

**Record the docs gap.** The scout verified against the **live** `docs.nats.io/llms.txt` that no
`learn/` chapter mentions scheduling. Confirm that still holds on the day, then file it in
`inbox/docs-issues.md` as **`missing`**, `destination: nats-docs`, with the evidence: the feature
shipped in 2.12, nine error codes and eight headers in the reference tree, three lines of release
notes, and no prose page. This is a `missing` row and not an `enhancement` one — the rulebook's line
is that `enhancement` means "correct but unhelpful", and here there is nothing to be unhelpful.

**Closes rows 29 and 30.**

## Step 4 — the applied layer, and only the rows it earns · status: open

- `ingest https://www.synadia.com/blog/delayed-message-scheduling-nats-jetstream` (Peter Humulock,
  2026-04-09) → `s-synadia-delayed-scheduling`. Its value is four caveats stated more plainly than the
  spec states them, and each one is a *gotcha*, not a feature note: a **past-dated schedule fires
  immediately, including on server restart**; one schedule per subject, the latest replacing the
  prior; unavailable on mirrors and sourced streams; and **DST transitions may skip or duplicate** a
  cron execution. Land them on [[message-scheduling]] and check each against ADR-51 — where the blog
  and the spec differ, the ADR is the source and the difference is a docs issue.

- **The dead-letter page, but only if the bank earns it.** `s-synadia-reliable-delivery-dlq` (step 2)
  carries a DLQ pattern built on the max-deliveries advisory: capture the advisory, fetch the original
  by sequence, republish. The wiki has no such page and `CLAUDE.md` is explicit — **no question, no
  page**. So: search GitHub Discussions, Stack Overflow and the docs' FAQ for someone publicly asking
  how to do dead-lettering in NATS, add the row **with its URL**, and only then write
  `wiki/operations/dead-letter-queue.md` (`kind: pattern`). **If no real public question turns up, do
  not write the page** — record in `wiki/log.md` that the scope test refused it, which is the test
  doing its job rather than failing.

- Add every other bank row these five sources revealed, each with the URL of someone asking it.

**Finish**: re-run `python3 tools/lint.py`, confirm citation drift is still 0 and the unlanded count
is 0 (an ingest that leaves ripples unlanded is the thing the last plan spent eight steps undoing),
append to `wiki/log.md`, and write the two-line result at the top of this file.

---

## Order, and why

Step 1 before step 2 because 4972 may already explain half of gh#5631. Step 2 before step 3 because it
is the only step with a **falsifiable** outcome and the one most likely to change what other pages say
— and because a run deferred is a run that quietly turns into a guess. Step 3 before step 4 because the
spec is the authority and the blog is the gloss; reading the gloss first is how a wiki ends up
repeating a vendor's simplification. Step 4 last because it is the only step allowed to add pages, and
it has to earn them from the bank.

**Expected at the end:** bank **105/88** (or **105/87** with row 18 as a stated dead end), one new
concept page, one new pattern page *if* the bank earns it, at least one verified docs-issue row, and a
`raw/nats-server-src/` run that settles a disagreement three sources could not.
