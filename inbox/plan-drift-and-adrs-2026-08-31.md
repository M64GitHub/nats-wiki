# Plan — drift detection, the docs-issue sweep, and the ADRs (proposed 2026-08-31)

**Result (2026-08-31).** All five steps done. Two tools now exist that did not — `check-defaults.py` swept all 216 documented defaults against v2.14.6 and `check-staleness.py` is wired into lint — the generated config reference has been swept end to end (**docs issues #27–#33**, taking the report from 26 findings to 33), and the wiki went from 200 to **215 pages** with the question bank at **67 of 104 answered, ★ 36 of 42**.
The last two open ★ sizing rows are closed: `filestore-layout` states the per-message record cost read at the tag *and* measured on the binary, so [[jetstream-sizing]] no longer has an unknown term except IOPS. **Next plan:** `inbox/plan-the-unread-chapters-2026-08-31.md` — written 2026-08-31 after auditing the bank and the docs tree, and **not** the `meta-layer` plan this line first proposed. The audit found two ★ rows already answered and never marked, and 13 more open rows whose answers are already sitting unread in `raw/nats-docs/` (the JetStream chapter is 9 of 22; `key-value`, `object-store`, `mqtt` and `websocket` are all zero). `meta-layer` and `stream-leader-keeps-moving` keep: they need `server/jetstream_cluster.go` read properly and the two rows they serve are not ★.

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how. One step at a
time, `status:` rewritten in place, `wiki/log.md` appended, lint run, question-bank cells filled, and
each step reported before the next begins.

**Why this plan.** `inbox/plan-runbooks-and-security-2026-08-31.md` finished with the wiki at **200
pages** and **every ★ row in the runbook, security and topology clusters answered**. The remaining
gaps are a different shape from the last two plans', and it is worth saying what changed:

- **The wiki is now big enough to rot.** All 200 pages read `verified-on: 2026-08-31` and
  `verified-against: nats-server 2.14.6`. When 2.14.7 ships, nothing tells you which of the ~90 pages
  that state a default is now lying. `CLAUDE.md` says "a stale page is worse than a missing one when
  someone is configuring production" and today nothing enforces that.
- **The docs-issue sweep pays better than any ingest.** 26 verified findings came out of reading
  roughly **5% of the docs**, and the ones with the most impact (#1–3, #19, #22, #23) are all
  **generated** reference pages where the value is mechanically checkable against a server constant.
  `inbox/config-keys-table.md` already holds **621 keys with 216 stated defaults**. Comparing them to
  the source is a script, not a reading task, and `inbox/docs-issues.md` is this wiki's most
  distinctive output — nothing else in the NATS ecosystem publishes such a report.
- **The ADRs are the last unread specification layer.** 8 of 54 read; **15 still flagged ★** in
  `inbox/adr-toc.md`, and several are named directly by open `## To verify` items on finished pages.

**Done when:** a stale page can be found by running a script rather than by remembering; the
generated config reference has been swept end to end against `nats-server` at a tag, with every
discrepancy verified and recorded; and no `## To verify` item on a finished page names an ADR that is
still unread.

---

## Step 1 — `tools/check-defaults.py`: sweep the generated config reference · status: done 2026-08-31 — 216 defaults swept, 3 new docs issues (#27–#29), s-nats-server-defaults-sweep

Not an ingest. A tool, then the findings it produces.

Write `tools/check-defaults.py` that takes `inbox/config-keys-table.md` (621 keys, 216 with a stated
default) and a `nats-server` tag, resolves each documented default against the source, and emits
three lists: **agrees**, **disagrees**, and **cannot be resolved automatically**. It does not need to
be clever — the four sweeps done by hand (#19 timeouts, #22 the `jetstream` block, #23 the listener
ports, plus the advisory subjects in #1–3) all reduce to "find the constant or the `if x == 0 { x =
… }` that fills this option and compare". Anything it cannot resolve goes on the third list for a
human, which is the honest output.

Then run it, verify every disagreement by hand against the source before recording it — the rule from
*Operation: record a docs issue* does not relax because a script found it — and add the rows to
`inbox/docs-issues.md`.

**Expected shape of the result, from the four hand sweeps so far:** the errors cluster in *generated*
pages and in *"Default" cells that describe a convention rather than what the server does*. Both are
exactly what a diff finds.

## Step 2 — `tools/check-staleness.py`: which pages are now lying · status: done 2026-08-31 — 0 stale today; 46 at a hypothetical 2.14.7; wired into lint.py and into llm-wiki-starter so it survives update-tools.sh

Also a tool. `tools/fetch-repo-facts.py --refresh` already re-reads all 32 repos; the analogue for
this wiki's own pages does not exist.

Flag every page whose `verified-against` is behind the current `nats-server` tag **and** which states
a default, a limit, a config key, a CLI flag, an API subject or an error code — the six things
`CLAUDE.md` says must carry a version. Pages that state none of those do not go stale the same way
and should not be flagged; that distinction is the whole value of the tool.

Output a table an operator can work: page, `verified-against`, what kind of claim it makes, and which
source it was verified from — so re-verification is a re-read of one named file, not a re-derivation.
Wire it into `tools/lint.py` as a warning, not an error.

## Step 3 — the ★ ADRs named by open `## To verify` items · status: done 2026-08-31 — ADR-59, 60, 61, 48, 57, 54 ingested; 13 pages rippled; three `## To verify` items closed

```
ingest raw/adr/ADR-48 (KV TTL)
ingest raw/adr/ADR-54 (KV codecs)
ingest raw/adr/ADR-57 (KV sources and mirrors)
ingest raw/adr/ADR-59 and ADR-60 (sourcing)
ingest raw/adr/ADR-61 (unsafe meta group quorum rescue, 2.15)
```

Take them in the order the wiki needs them, not in number order. Each of these is named by an open
`## To verify` item on a page that is otherwise finished — [[key-value]], [[mirrors-and-sources]],
[[disaster-recovery]] — so the ripple is known before the ingest starts, which is the cheapest kind
of ingest there is. Check the exact file names in `inbox/adr-toc.md` first; the numbers above come
from that table, not from the repo.

ADR-61 also closes the meta-quorum precondition that [[disaster-recovery]] currently states as a
design-time assumption.

## Step 4 — the remaining ★ ADRs · status: done 2026-08-31 — 15 triaged, 3 ingested (ADR-10, 35, 40), 12 skipped; 3 new pages, 10 rippled, docs issues #30–#32

The other ★ rows in `inbox/adr-toc.md` — **fifteen**, not ten; step 3 took six of the twenty-one that
were open. Triage them against `inbox/question-bank.md` first and **skip any that no open row needs**
— say so in the status line. An ADR that no question asks for is out of scope by the bank's own test,
however interesting it is.

**The triage, in full.** Three ADRs are named by an open row; twelve are not.

| ADR | title | open row it serves | verdict |
|---|---|---|---|
| 10 | JetStream Extended Purge | **Q27** — recover a stream full under `DiscardNew` | **ingested** |
| 35 | JetStream Filestore Compression | **Q31** — how compression works and what it costs | **ingested** |
| 40 | NATS Connection | **Q67** — LoadBalancer or seed URLs on Kubernetes | **ingested** |
| 2 | NATS Typed Messages | none | skip — client API surface, out of scope by `CLAUDE.md` |
| 4 | NATS Message Headers | none | skip — the HPUB/HMSG wire format and client `GET`/`SET` semantics; it does **not** define the reserved `Nats-*` headers an operator sees (those are in ADR-8/43 and the source) |
| 5 | Lame Duck Notification | Q93 already answered | skip — the client-visible `ldm` flag; the server side is on [[install-nats-server]] and [[upgrade-a-cluster]] |
| 26 | NATS Authorization Callouts | Q53 already answered | skip — [[auth-callout]] covers it from the docs and the source |
| 28 | JetStream RePublish | none | skip |
| 30 | Subject Transform | none | skip |
| 36 | Subject Mapping Transforms in Streams | none | skip — the sourcing half is already in [[s-adr-59-sourcing-and-mirroring]] |
| 38 | OCSP Peer Verification | none | skip — Q50/Q94/Q97 are certificate *rotation*, not revocation checking |
| 39 | Certificate Store | none | skip — Windows certificate store |
| 41 | Message Path Tracing | none open (Q77 is answered by [[nats-timeout]]) | skip — a strong 2.11 operator tool with no question behind it yet; scout a thread first |
| 44 | Versioning for JetStream Assets | none | skip — no bank row asks about asset versioning or downgrade metadata |
| 62 | JetStream desired state reconciliation | none | skip — 2.15, which exists only as a preview, and no open row |

Two of the three ingests produced findings against their own ADR (docs issues **#30** and **#31**),
and the purge sweep produced a third against the generated reference (**#32**). Everything stated on
the three new pages that could be run was run on the v2.14.6 binary:
`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`.

## Step 5 — the sizing rows nobody has answered · status: done 2026-08-31 — `filestore-layout` written; Q1 and Q2 answered; 8 pages rippled; docs issue #33

**Q1** (size a 3-node R3 cluster for a given rate, size and retention) and **Q2** (what a stream costs
on disk beyond the raw bytes) are the two oldest ★ rows in the bank and the only ones in the
*jetstream sizing* cluster still open. [[jetstream-sizing]] answers Q3 and gives the four resources;
what it cannot give is **bytes per message on disk**, because no source read so far states the
filestore's per-message overhead.

This step is therefore a **`filestore-layout` internals page or nothing.** Read
`server/filestore.go` at v2.14.6 for the block, index and per-subject-state structures, write the
page, and only then decide whether Q1 and Q2 can be answered honestly. If the arithmetic still does
not close, say so on [[jetstream-sizing]] and leave both rows open — an invented bytes-per-message
figure would be the single most damaging thing this wiki could publish.

`filestore-layout` is one of the four remaining wanted pages.

---

## Not in this plan, and why

- **Re-mining the question bank by body rather than title.** Still the right idea and still premature:
  62 of 104 rows are answered, so more demand signal we cannot meet would make the scoreboard worse,
  not better. Revisit when the open rows are mostly ones the wiki has decided not to answer.
- **`meta-layer` and `stream-leader-keeps-moving`**, two of the four wanted pages. Both need
  `server/jetstream_cluster.go` read properly, which is a plan of its own.
- **`consumer-keeps-redelivering`**, the fourth. [[ack-and-redelivery]] covers the mechanism well; the
  gotcha needs a public thread with a real symptom, and none has been found. Scout before writing.

## Method notes

- **Verify before recording, even when a script found it.** A diff produces suspicions;
  `inbox/docs-issues.md` takes evidence with a file and a line. The third output list — "cannot be
  resolved automatically" — is not a failure of the tool, it is the tool being honest about which
  keys need a human.
- **Both tools belong in `llm-wiki-starter` if they generalise.** `check-staleness.py` almost
  certainly does; `check-defaults.py` is NATS-specific in its resolver but not in its shape. Decide
  when they work, not before — and remember `tools/update-tools.sh` will overwrite local edits to the
  shared files.
- The question bank was last mined 2026-08-31 and holds **104 rows, 62 answered; ★ 34 of 42**.
