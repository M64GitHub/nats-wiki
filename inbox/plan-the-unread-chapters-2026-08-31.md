# Plan — the last ★ rows, and the chapters nobody has read (proposed 2026-08-31)

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how. One step at a
time, `status:` rewritten in place, `wiki/log.md` appended, lint run, question-bank cells filled, and
each step reported before the next begins.

**Where the wiki stands.** `inbox/plan-drift-and-adrs-2026-08-31.md` finished all five steps:
**215 pages**, question bank **104 rows / 67 answered / ★ 36 of 42**, `inbox/docs-issues.md` at **33
verified findings**, staleness **0**, lint clean.

**Why this plan, and why it is not the one the last plan proposed.** That plan's result line proposed
`meta-layer` and `stream-leader-keeps-moving` next. Auditing the bank and the docs tree afterwards
changed the answer, and the reason is worth writing down:

- **Six ★ rows are open, and at least two of them are already answered.** `★` marks the questions
  that must be answerable "for the wiki to be useful at all". Q51 (share a stream or KV bucket
  between accounts) is answered in full on [[cross-account-sharing]] with two routes and citations;
  Q58 (find which consumer the server flagged as slow) is answered on [[slow-consumer-detected]] with
  `/connz?sort=pending` and the docs' own words. **The scoreboard is under-reporting.** Fixing that
  costs an hour and is the cheapest work available.
- **The docs tree is 861 pages and the wiki has read about 60 of them.** The chapters that carry
  production knowledge are done — `security` **9/9**, `topologies` **6/7**, `deployment` **5/6**,
  `clustering` **5/6**, `backup-recovery` **4/5**. But the **JetStream chapter, the declared centre of
  gravity, is 9 of 22**, and `key-value` is **0/6**, `object-store` **0/6**, `mqtt` **0/5**,
  `websocket` **0/5**, `monitoring` **2/6**.
- **The open rows sit almost exactly on top of those unread chapters.** Of the 31 open non-★ rows,
  **13** — Q24, Q29, Q30, Q60, Q61, Q73, Q74, Q75, Q76, Q78, Q79, Q80, Q81 — plus the ★ row **Q23**
  are answered by pages already sitting in `raw/nats-docs/`, unread. That is the highest ratio of
  *answers already fetched* to *work required* anywhere in the repo.
- **`interop` is a declared area of this wiki with one page in it** — the `nats-js` entity — and
  **zero summaries**. MQTT and WebSocket appear only as config keys scattered through
  [[config-keys]], [[defaults-and-limits]] and [[monitoring-endpoints]]. Nothing explains either.
- **`meta-layer` keeps.** `server/jetstream_cluster.go` is a genuinely large read and the two rows it
  serves (Q37, Q40) are **not ★**. It is the plan after this one, and it will be better for having
  the monitoring chapter's `/healthz` and advisory material read first.

**Done when:** every ★ row is either answered or carries a written reason why it cannot be; the
JetStream, KV, Object Store, MQTT, WebSocket and monitoring chapters have been read to the depth this
wiki's focus asks for; and `interop` has real pages rather than scattered config keys.

---

## Step 1 — the six open ★ rows, closed or explained · status: open

Mostly **not** an ingest. Four different kinds of work, and the point of the step is to stop treating
them as one.

**Audit and fill (probably already answered).** Read the page, check it states the answer *with a
citation and a version*, then fill the cell — or leave it empty and say in the log what is missing.

| row | question | the page that likely answers it |
|---|---|---|
| **Q51** | share a stream or KV bucket between accounts | [[cross-account-sharing]] — *Sharing JetStream* |
| **Q58** | find which consumer the server flagged as slow | [[slow-consumer-detected]] — `/connz?sort=pending` |

**Run it on the binary (Q97).** *"Does a config reload actually pick up a renewed certificate file, or
do I need a restart?"* [[rotate-tls-certificates]] states the docs' answer and its own `## To verify`
admits the server was never asked. This is settleable in ten minutes and is exactly the kind of claim
*Operation: record a docs issue* says must be **run**, not read:

```
# generate a self-signed cert, start the server with it, note /varz tls_cert_not_after
# replace the certificate file IN PLACE with a second one, different expiry, same path
nats-server --signal reload=<pid>
curl -s localhost:8222/varz | jq '.tls_cert_not_after'      # did it move?
```

Record the config, the two certificates' expiries and the exact output in
`raw/nats-server-src/tls-reload-observed-v2.14.6.md`. Keep the binary and `verified-against` aligned
(`nats-server --version` must read **2.14.6**). If the reload does *not* pick it up, that is a docs
issue **and** a correction to a runbook people will follow during an expiry incident.

**Scout before writing (Q65, Q103).**

- **Q65** — hostPath or PVC for JetStream on Kubernetes. `learn/deployment/kubernetes.md` is already
  ingested and **never uses the word `hostPath`**; the chart provisions through `volumeClaimTemplates`
  (`raw/github-repos/nats-io__k8s.values-nats-2.14.6.md`). So the comparison the question asks for
  exists nowhere in `raw/`. Scout for a public thread; if one exists it lands on
  [[jetstream-sizing]] or a new `kubernetes-storage` operation page, not on a fifth Kubernetes
  section.
- **Q103** — can a leaf region become the hub, or a cluster be converted to a leaf, without losing
  data? Already recorded as unknown in **two** places ([[choosing-a-topology]] and
  [[multi-region-jetstream]]). Scout **once**. If nothing public answers it, **write that on the row
  and stop** — `CLAUDE.md` says a question the wiki cannot answer is the most valuable row in the
  table, and three pages hedging the same unknown is worse than one that says nobody has published
  the answer.

**Q23 is not in this step** — its source is `learn/jetstream/advanced-publishing.md`, so it belongs to
step 2.

## Step 2 — the JetStream chapter's unread half · status: open

```
ingest raw/nats-docs/learn/jetstream/advanced-publishing.md
ingest raw/nats-docs/learn/jetstream/publishing.md
ingest raw/nats-docs/learn/jetstream/shaping-the-stream.md
ingest raw/nats-docs/learn/jetstream/altering-stream-state.md
ingest raw/nats-docs/learn/jetstream/filtering.md
ingest raw/nats-docs/learn/jetstream/reading-back.md
ingest raw/nats-docs/learn/jetstream/subject-mapping.md
```

**Thirteen of the chapter's 22 pages have never been read**, in the chapter `CLAUDE.md` names as the
centre of gravity. The seven above are the server-facing ones. Skip
`your-first-stream.md`, `ordered-consumer.md`, `priority-groups.md`, `message-ttl.md`, `pausing.md`
and `where-next.md` **unless the read reveals something the existing concept pages miss** — those six
already have pages built from the ADRs and the source, and re-reading a tutorial to confirm a page is
not an ingest. Say in the status line which of the six were checked and what, if anything, they added.

**Warning about the unit of ingestion.** These pages carry the same example in **seven languages**
(CLI, JS, Go, Python, Java, Rust, C#, C). `CLAUDE.md` puts per-language client API documentation out
of scope. The article being ingested is the **prose and the CLI**, not the code blocks; a summary that
paraphrases a Go snippet has ingested the wrong thing.

**Rows this should close:** **Q23** (★ — exactly-once and the dedup window; `advanced-publishing.md`
names `Nats-Msg-Id` and the lost-ack case explicitly), **Q29** and **Q30** (message scheduling, and
scheduler vs NAK-with-delay), **Q24** (what ordering JetStream guarantees, and per what).

**Ripple to expect:** [[stream]] (the `duplicate_window` `## To verify` item, and *The deduplication
window*), [[ack-and-redelivery]], [[retention-policies]], [[direct-get]], [[message-ttl]],
[[defaults-and-limits]], [[js-api-subjects]].

**Watch for docs issues.** [[stream]] already records that the `StreamConfig` schema says only
`"0 for default"` for `duplicate_window` and never states the substituted value — that is **docs issue
#5**. If `publishing.md` or `advanced-publishing.md` states a number, check it against the server; if
it states none either, the issue gets a second `where`.

## Step 3 — `learn/key-value`, the five articles · status: open

```
ingest raw/nats-docs/learn/key-value/under-the-hood.md
ingest raw/nats-docs/learn/key-value/history-and-revisions.md
ingest raw/nats-docs/learn/key-value/ttl-and-limits.md
ingest raw/nats-docs/learn/key-value/watching.md
ingest raw/nats-docs/learn/key-value/your-first-bucket.md
```

**Zero of six read** — five articles plus `where-next.md`, which is a table of contents and is
not an ingest — for a store `CLAUDE.md` names in the same breath as JetStream.
`under-the-hood.md` opens *"A bucket is a stream"* and walks the real `KV_<bucket>` config —
`Discard Policy: New`, `Direct Get: true`, `Allows Rollups: true`, `$KV.<bucket>.>` — which is exactly
the layer [[key-value]] is built on and currently sources from the ADRs alone.

**Rows this should close:** **Q73** (when KV is the wrong tool), **Q74** (a distributed lock or lease
with KV), **Q76** (why a KV mirror on file storage is slower than on memory).

**`## To verify` items it should settle:** on [[key-value]] — whether a mirror on file storage is
materially slower (Q76), and the KV-watcher gap; on [[mirrors-and-sources]] — the same mirror
question.

`ttl-and-limits.md` should be checked against [[message-ttl]]'s open item: **the server-side default
for `subject_delete_marker_ttl`**, which no source read so far states.

## Step 4 — `learn/object-store`, the five articles · status: open

```
ingest raw/nats-docs/learn/object-store/under-the-hood.md
ingest raw/nats-docs/learn/object-store/chunking.md
ingest raw/nats-docs/learn/object-store/watching-and-listing.md
ingest raw/nats-docs/learn/object-store/metadata-and-links.md
ingest raw/nats-docs/learn/object-store/your-first-object.md
```

**Zero of six read**, same shape as step 3: five articles and a `where-next.md` to skip.
`under-the-hood.md` gives the two subject spaces verbatim —
`$O.<bucket>.C.>` for chunks and `$O.<bucket>.M.>` for metadata — which [[object-store]] currently
carries from ADR-20 only.

**Rows this should close:** **Q75** (why listing a bucket is slow or times out while uploads run) —
`watching-and-listing.md` is named for it.

**`## To verify` items it should settle:** on [[object-store]] — the slow-listing question, and
whether any source gives guidance on choosing a chunk size beyond "clients may tune this".

`chunking.md` is the **one page in the whole 861-page tree** that mentions per-message overhead, and
it does so without a number. Now that [[filestore-layout]] has the number, that page is worth
re-reading with docs issue **#33** in hand — it may deserve a second `where`.

## Step 5 — `interop`: WebSocket and MQTT · status: open

```
ingest raw/nats-docs/learn/mqtt/qos-sessions-and-retained.md
ingest raw/nats-docs/learn/mqtt/auth-and-clustering.md
ingest raw/nats-docs/learn/mqtt/topics-and-subjects.md
ingest raw/nats-docs/learn/mqtt/your-first-mqtt-client.md
ingest raw/nats-docs/learn/websocket/tls-and-proxies.md
ingest raw/nats-docs/learn/websocket/leaf-nodes-over-websocket.md
ingest raw/nats-docs/learn/websocket/browsers-and-origins.md
ingest raw/nats-docs/learn/websocket/your-first-websocket-connection.md
```

Both chapters are five pages, the fifth being `where-next.md` — a table of contents, not an article.
`your-first-websocket-connection.md` has been *quoted* before (it is one of the `where` paths on docs
issue **#10**) but never ingested; there is no summary with it as `source-path`.

The filenames map almost one-to-one onto the open rows, which is why this step is worth its size:

| page | row it should answer | what else it gives |
|---|---|---|
| `mqtt/qos-sessions-and-retained.md` | **Q80** — how QoS 1/2 maps onto JetStream and what it costs | the streams the MQTT layer creates on your behalf |
| `mqtt/auth-and-clustering.md` | **Q81** — restricting MQTT client ids per account with JWT | MQTT in a cluster, which no wiki page mentions |
| `mqtt/topics-and-subjects.md` | — | the topic↔subject translation, and what `/` and `.` do to each other |
| `websocket/tls-and-proxies.md` | **Q79** — WebSocket behind nginx or another proxy | the TLS termination question that comes with it |
| `websocket/browsers-and-origins.md` | — | origin checking: a security surface [[subject-permissions]] and [[tls-in-nats]] never touch |
| `websocket/leaf-nodes-over-websocket.md` | — | a leafnode dialled over WebSocket, which [[leafnode]] does not mention |

**Q78** (how many WebSocket connections one server sustains) may not be answered by any of them — it
is a sizing number and the docs rarely give those. Leave it open with a note rather than inferring
one from `max_connections`.

The wiki declares `interop` as one of its ten areas and has **one page** carrying it (the `nats-js`
entity) and **zero summaries**. MQTT and WebSocket exist in this wiki only as config keys scattered
across [[config-keys]], [[defaults-and-limits]] and [[monitoring-endpoints]] — including the two MQTT
defaults corrected as docs issues **#28** and **#29**, which is a wiki that can tell you a default is
wrong but not what the feature does.

**Rows this should close:** **Q79**, **Q80**, **Q81** — see the table above. **Q78** is the doubtful
one, for the reason given there.

**Expected new pages:** a `websocket` concept and an `mqtt` concept at minimum; possibly a
`run-nats-behind-a-proxy` runbook if Q79's answer is procedural. Both concepts must carry `since:` —
MQTT and WebSocket arrived in specific releases and this wiki has never stated which.

**Q80 is the one to be careful with.** "What does QoS 2 cost" is a behavioural claim about streams
the MQTT layer creates on your behalf. If the docs describe the mapping without naming the streams,
**look at the server** — and if a claim is testable, the binary is right here and
[[filestore-layout]] has just shown what running it buys.

## Step 6 — `learn/monitoring`'s three unread articles · status: open

```
ingest raw/nats-docs/learn/monitoring/advisories-and-events.md
ingest raw/nats-docs/learn/monitoring/jetstream-health.md
ingest raw/nats-docs/learn/monitoring/profiling.md
```

Four of the chapter's six pages are unread; the fourth is `where-next.md`, a table of contents.
The smallest step, kept last because it is the one that makes the earlier ones checkable.

- `advisories-and-events.md` (two sections: *Advisories*, *System events*) against
  [[advisories]] — which was built from the generated reference, the tree where **docs issues #1–#3**
  live. A hand-written chapter covering the same subjects is the best available cross-check on those
  three subject-name errors.
- `jetstream-health.md` — stream state, consumer state, and *"Lag is a number you compute"* — against
  [[stream-has-high-message-lag]] and [[monitoring-endpoints]].
- `profiling.md` — `$SYS.REQ.SERVER.PROFILEZ` and the profiling port. [[jetstream-sizing]] currently
  ends its memory section with *"profile with Go's `pprof`"* and no method. This page is the method.

**Rows this should close:** **Q60** (how CPU % in `/varz` is measured and why it looks wrong in
containers), **Q61** (how the RTT values in `/routez` and `/connz` are measured) — both if the pages
state it, and both left open with a note if they do not.

---

## Not in this plan, and why

- **`meta-layer` and `stream-leader-keeps-moving`.** The two remaining wanted pages, both needing
  `server/jetstream_cluster.go` read properly. **This is the next plan.** It also owns Q37 (quorum
  loss after days of stable operation), Q40 (evicting a sick node), and the `## To verify` items on
  [[raft-in-nats]] (heartbeat interval, the 4–9 s election window, the `/raftz` field set),
  [[replicas]] (the meta group's replica count) and [[gateway]] / [[choosing-a-topology]] (whether a
  super-cluster's stream creation really "relies on a global quorum").
- **`consumer-keeps-redelivering`**, the third wanted page. [[ack-and-redelivery]] covers the
  mechanism; the gotcha still needs a public thread with a real symptom and none has been found.
  Scout it alongside Q65 and Q103 in step 1 if the scouting is cheap; otherwise leave it.
- **`learn/core-nats`, 0 of 11.** Q24 and Q25 (ordering guarantees) want it, and Q24 is picked up by
  step 2 instead. Most of the chapter — `connecting.md`, `publish-subscribe.md`, `request-reply.md`,
  `scatter-gather.md` — is application-development material that `CLAUDE.md` puts out of scope. The
  server-facing minority (`subjects-and-wildcards.md`, `subject-mapping.md`, `queue-groups.md`,
  `headers.md`, `debugging-delivery.md`) is a small plan of its own, best run with the core-NATS
  ordering question as its spine.
- **`learn/resilient-clients`, 0 of 8** — client-side reconnect, drain and slow-consumer handling.
  Out of scope by the letter of `CLAUDE.md`; `drain-and-shutdown.md` and `slow-consumers.md` are the
  two that touch server behaviour and can be pulled in individually if a row asks.
- **The 14 chapter landing pages** (`learn/jetstream.md` and friends). Tables of contents, not
  articles. Never ingest them.
- **The remaining 12 ★ ADRs.** Triaged and skipped with written reasons in
  `inbox/plan-drift-and-adrs-2026-08-31.md` step 4. Do not re-open one without a bank row behind it.
- **Citation drift (22 pages) and unlanded ripples (252 across 63 pages).** Both are lint *warnings*,
  not defects — "pages touched" often means "relevant to" rather than "edited". Keep unioning drift
  on pages a step already has open, as the last two plans did; do not make a sweep of it a step.

## Method notes

- **Fill the scoreboard before adding to it.** Step 1 exists because two ★ rows were answered and
  never marked. Before any step declares a row open, re-read the page that plausibly answers it.
- **The unit of ingestion is the article, and these articles are mostly code.** Seven language
  variants of one example is one claim, not seven. Summarise the prose and the CLI; name the
  languages the page covers and move on.
- **A chapter that confirms an existing page is still a result.** Say so in the log — "read, added
  nothing" is information, and it is what stops the same page being re-read in three plans' time.
- **Keep running things.** The last plan's step 5 got its best findings from eleven experiments on the
  binary, not from reading. Q97 in step 1 and Q80 in step 5 are both runnable. The binary must stay
  at **2.14.6** to match `verified-against`, and `raw/` gets the config and the output.
- **Question-bank arithmetic to beat:** 104 rows, **67 answered**, ★ **36 of 42**. The 19 rows this
  plan names are Q23, Q24, Q29, Q30, Q51, Q58, Q60, Q61, Q65, Q73, Q74, Q75, Q76, Q78, Q79, Q80,
  Q81, Q97, Q103. Landing all of them gives **86 answered** and **★ 42 of 42** — but three are
  already flagged as doubtful (Q78 is a sizing number the docs may not give; Q65 and Q103 depend on a
  scout finding a public thread). **83 and ★ 40 of 42 is the realistic landing zone**, and a row
  closed with a written "nobody has published this" counts as work done, not as a miss.
