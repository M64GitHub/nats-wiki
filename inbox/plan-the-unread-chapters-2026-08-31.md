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

## Step 1 — the six open ★ rows, closed or explained · status: done 2026-08-31 — s-nats-server-tls-reload, s-gh-7749-hostpath-jetstream, s-k8s-760-jetstream-pvc-per-replica, s-nats-helm-chart-values-2.14.6 (extended)

**Result: ★ 41 of 42.** Q51 and Q58 were audited and filled (Q58 had already been filled by
consolidation step 4, so the bank started at 68 answered, not 67). Q97 was **run on the binary** and
closed, with a docs issue (#34) and a new `raw/` observation file. Q65 was scouted, found, and
answered on a new page [[kubernetes-storage]]. Q103 was scouted and **closed as "nobody has published
an answer"**, stated once on [[choosing-a-topology]] instead of hedged on two pages. Only **Q23**
remains open among the ★ rows, and it belongs to step 2. Bank: 104 rows, **72 answered** (was 68),
★ **41 of 42** (was 37). Unlanded ripples **206 → 206**; citation drift 0 → 0; lint clean; 215 → 219
pages.

**Q97, run rather than read** — eight experiments and two controls on the v2.14.6 binary
(`raw/nats-server-src/tls-reload-observed-v2.14.6.md`). The reload **does** pick up a renewed
certificate, on a client listener and on a leafnode remote, with the file replaced in place and with
the path changed in the config, and with a fresh keypair. The finding worth having is the second one:
a reload that changed nothing prints the same four `Reloaded:` lines, `config_digest` never moves
(it digests the config *text*), and `nats-server --signal reload` **exits 0 even when the server
refused the reload** — so `tls_cert_not_after` is the only observable that distinguishes a landed
rotation from a no-op or a refusal. That is a sufficient explanation for the gh#7684 reporter's
conclusion without the reload being broken. Docs issue **#34** records the six leafnode-remote TLS
keys whose "On 2.11/2.12 …" caveat never says whether it still applies; three were tested and all
three reload.

**Q65, scouted and landed.** Two public threads, neither previously in `raw/`: `gh#7749`
(the question, answered five months later by a **community member**, never by a maintainer — the
provenance is on the summary) and `nats-io/k8s#760`, the first file here from a repo other than
`nats-server`, carrying the chart maintainer's rationale: *"JetStream needs fast block based storage.
Should not use NFS or other slow file based storage with it. Most fast block based storage in the
cloud only works with a single host as a writer."* Reading the chart at `nats-2.14.6` to check the
answer's YAML found two things the answer does not have: the key path is
`config.jetstream.fileStore.*` (the answer uses an older generation's `nats.jetstream.fileStorage.*`),
and **`grep hostPath values.yaml` returns nothing** — the chart offers no such value at all. It also
turned up a finding for docs issue **#33**: `files/config/jetstream.yaml` renders `max_file_store`
equal to `fileStore.pvc.size` when `fileStore.maxSize` is unset, so a stock install runs a 10Gi
ceiling on a 10Gi volume — the docs' own unsafe example, shipped.

**Q103, closed as a dead end.** The two questions in gh#7438 (2025-10-20) were never replied to;
searched again on 2026-08-31 across the docs, ADRs, GitHub and blogs with nothing found. The finding
now lives in one place — *Choosing the hub is a one-way decision* on [[choosing-a-topology]] — and
[[multi-region-jetstream]] points at it instead of hedging twice. The row carries a new
`no-public-answer` flag, documented in the bank's legend.

**Scouted in passing, not ingested:** `nats-io/nats-server` **issue #6921** (open, opened 2025-05-23,
labelled *defect*, assigned to @neilalexander) — explicit acks stalling on a stream with
`max_msgs_per_subject: 5` and a `LastPerSubject` deliver policy, ack floor frozen, resolved by
changing `AckPolicy` to `None` or `DeliverPolicy` to `All`. The best candidate found so far for the
wanted `consumer-keeps-redelivering` page; left for the plan that writes it.


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

## Step 2 — the JetStream chapter's unread half · status: done 2026-08-31 — s-docs-publishing, s-docs-advanced-publishing, s-docs-shaping-the-stream, s-docs-altering-stream-state, s-docs-subject-mapping, s-docs-reading-back, s-docs-filtering

**Result: ★ 42 of 42 — every starred row in the bank is answered.** All seven pages ingested, two new
reader pages written ([[publishing]], [[subject-transforms]]), and docs issue **#5 corrected and
narrowed** by what the reading found. Bank: 104 rows, **74 answered** (was 72), ★ **42 of 42** (was
41). Unlanded ripples **206 → 206**; citation drift 0 → 0; lint clean; 219 → 228 pages.

**Rows closed: Q23** (★ — [[publishing]] · [[stream]]) and **Q24** ([[publishing]] · [[stream]] ·
[[subject-transforms]]).

**Rows the plan expected and this step cannot close: Q29 and Q30.** The plan predicted message
scheduling here; it is **not in the `learn/jetstream` chapter at all**. A grep of the whole 861-page
tree for `allow_msg_schedules`, `Nats-Schedule` and "message schedul" returns three files, none of
them in `learn/`: `release-notes/upgrade-to-2.14.md`, `reference/jetstream/api/headers.md` and
`reference/jetstream/errors.md`. Both rows stay open, and the material for them is named here so the
next plan does not re-derive it.

**The two gaps the chapter exposed**, neither of which the wiki had a page for:

- **Publishing itself.** The wiki knew `allow_atomic` (2.12) and `allow_batched` (2.14) as flags in a
  config table and nothing about what they do. [[publishing]] now carries the `PubAck` contract, the
  two failure modes (`no responders` = nothing stored; a timeout = *unknown*), the honest shape of
  "exactly once", the async **order trap**, and the four modes with their headers and costs.
- **Subject transforms and republish.** A whole mechanism — the `{{wildcard}}`/`{{partition}}`
  language, deterministic sharding, republish's five headers — with no page.
  [[subject-transforms]] is it.

**The eleven batch error codes** (`10176`, `10179`, `10199`, `10201`, `10210`; `10205`–`10209`,
`10211`) were in `raw/nats-docs/reference/jetstream/errors.md` and in **none** of them was in
[[error-codes]]. They are now, with the two `429`s called out — the only two in that table.

**The six tutorial pages the plan said to skip were checked**, as it asked:

| page | what it added |
|---|---|
| `your-first-stream.md` | **`Duplicate Window: 2m0s`** in a `nats stream info` block and in prose — part of the evidence that narrowed docs issue #5 |
| `priority-groups.md` | the CLI accepts a comma list for `--overflow-groups`/`--pinned-groups`, **the server accepts it too, and silently uses only the first**. Landed on [[priority-groups]] |
| `pausing.md` | a pause deadline **in the past does nothing**, and a pause does not stop publishers, so the stream's limits keep discarding. Landed on [[consumer]] |
| `ordered-consumer.md` | two readers each get their own ordered consumer, so they **both read the whole stream** rather than splitting it. Landed on [[ordered-consumer]] |
| `message-ttl.md` | **read, added nothing** — [[message-ttl]] already had the irreversibility of `allow_msg_ttl` with its error codes |
| `where-next.md` | a table of contents, not read |

Those four additions cite the doc **path**, not a summary: they are spot-checks, not ingests, and the
pages are marked as un-ingested in the citation so a later plan can tell the difference.

**Docs issue #5 corrected.** It claimed the two-minute `duplicate_window` default was stated nowhere
public except a Synadia blog post. The `learn` chapter states it in **three** pages, correctly. The
row is now scoped to the generated reference — the page where the field is *defined* and where a
reader looks for a default — and its severity drops from medium to low. Recorded as a correction in
the issue itself, not as a silent edit.

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

## Step 3 — `learn/key-value`, the five articles · status: done 2026-08-31 — s-docs-kv-under-the-hood, s-docs-kv-watching, s-docs-kv-history-and-revisions, s-docs-kv-ttl-and-limits, s-docs-kv-your-first-bucket

**Result.** All five ingested; `where-next.md` skipped as a recap, though its production checklist
supplied the bucket-name charset. Bank: 104 rows, **76 answered** (was 74), ★ **42 of 42**. Unlanded
ripples **206 → 206**; citation drift 0 → 0; lint clean; 228 → 233 pages.

**Rows closed: Q73** (when a bucket is the wrong tool — the KV half; the Object Store half is step 4)
and **Q74** (a distributed lock or lease). **Q76 stays open** and is now *known* to be unanswerable
from this chapter: `learn/key-value` mentions mirrors exactly once, in its closing recap, with no
performance claim of any kind.

**The two `## To verify` items the plan named, both resolved — one settled, one hardened:**

- **The KV-watcher gap is settled, and the answer is client-side.** The docs call it "the most common
  watch bug": the end-of-initial-data signal arrives as a **nil entry** in Go and Python, an
  `isUpdate` flag in JavaScript, an `endOfData()` callback in Java, an `OnNoData` option in C#, and
  **not at all in Rust**. A loop that treats the nil entry as end-of-stream reads the snapshot and
  quits before the first live change — a watcher that appears to miss every update while the server
  did nothing wrong.
- **The mirror question (Q76) is confirmed uncovered**, which is a result rather than a gap: the row
  and [[key-value]]'s *To verify* now say the chapter was read end to end and states nothing.

**`subject_delete_marker_ttl` still has no documented default.** `ttl-and-limits.md` always passes
`--marker-ttl` explicitly. The open item on [[message-ttl]] survives a second source, and now says so.

**The findings worth carrying**, none of which the wiki had:

- **A revision is the stream sequence, so the counter is bucket-wide.** One key's revisions run `2`,
  `5`, `9`; the gaps are other keys' writes. Never derive anything from them.
- **`put` over a TTL'd key silently makes it permanent** — no error, the new revision simply carries
  no TTL. On a lease or session bucket that is an outage.
- **`deny_delete` does not stop a raw publish.** It blocks the message-delete API only; a
  `nats pub` to `$KV.<bucket>.<key>` lands a bare message a watcher cannot distinguish from a real
  put. The only real protection is an ACL — landed on [[subject-permissions]].
- **`*` is a whole token in a key filter**, so `widget-*` over flat hyphenated keys matches nothing.
  Key naming decides, once, whether a subset can ever be watched cheaply.
- **CAS is two operations**: `create` (revision 0) and `update` (a named revision), a rejected update
  is **dropped, not queued**, and value+revision must come from a single `get`.

**Q74 answered with its limits stated.** No public source publishes a lock recipe; every primitive is
documented, so [[key-value]] now composes them and spends more words on what the composition is *not*
— a lease rather than mutual exclusion, no fencing beyond the revision, no blocking acquire, and the
`put`-renewal trap that makes a lock immortal.

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
