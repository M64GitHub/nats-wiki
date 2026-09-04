# Scout — stream and subject design (2026-09-04)

*Operation: scout*, run for **phase G1** of the maintainer's programme —
`inbox/plan-stream-and-subject-design-2026-09-04.md`, step 1. Candidates for the four things that
plan writes: `subject-design` (bank row 109), `stream-topology-design` (108, 111, 114), a
`## Choosing retention` section on [[retention-policies]] (110), and row 144 (JetStream as an event
store). **Not ingested** — the user picks; the plan caps the ingest that follows at ~8 summaries.

Searched: the six bank-row threads (fetched whole), the 484-thread comment cache
`local/scratch/gh-index/threads-2026-09-03.md` re-swept with this group's terms, `synadia.com/blog`
end to end (111 posts listed), `natsbyexample.com`, and the Stack Exchange API on the
`nats-jetstream` and `nats.io` tags. Nothing was blocked; every URL below was fetched or skimmed.

---

## The finding that shapes the two pattern pages

**Three independent public sources tell you a subject may have at most 16 tokens, and the server
has no such limit.** Phase F step 1 settled this on the binary and recorded it as docs issues #81
and #82: `nats-server` v2.14.6 enforces no length and no token count — `max_control_line` (4096)
bounds the whole protocol line and `max_subscription_tokens` is an optional, restart-only cap that
is off by default ([[subjects-and-wildcards]]). Yet:

- the docs' own `concepts/subjects.md` primer states 16 tokens with no source
  ([[s-docs-core-nats-subjects-and-mapping]] already records this);
- **Synadia's own 2026-06-17 post** repeats it as "soft guidance: ≤16 tokens and ≤256 characters",
  and adds a **32-token stack-allocation threshold** (candidate S1);
- the **accepted answer on so#72585165** (score 7) repeats "a reasonable value of 16 tokens max"
  (candidate X1).

`subject-design` has to carry this: the rule everybody repeats, what the server actually enforces,
and — separately — whether the advice is still *good* advice for a reason other than the one given.
Do not let the page repeat the folklore, and do not let it sneer at it either. **Verify the 32-token
and 256-character claims against `server/sublist.go` and `subjectIsSubsetMatch`/`tokenizeSubject`
at v2.14.6 before either goes on a page** — a third value repeated from nowhere is a docs issue,
a real stack-array bound is a fact worth stating.

**And the two sources disagree on versioning a subject.** S1 says put a version token in from day
one (`orders.v1.customer.created`); X1's accepted answer says explicitly *not* to, and to version
the schema in a header instead. Both go on the page, per `CLAUDE.md` — this is a genuine design
disagreement in public, not an error to resolve.

**A second disagreement, on the row-108 question itself.** gh#6100's chosen maintainer answer says
stick to **one stream**, "it's rarely a good idea to have stream per subject", because each
replicated stream carries its own Raft group; Synadia's 2026-05-20 post (S3) recommends **one
stream per tenant** for per-tenant FIFO, "roughly hundreds to low thousands of tenants". These
answer different questions (per *subject* against per *tenant*) and the page's job is to say where
the line is — which is what step 3's runs are for.

---

## Candidates

Flags: **★** must-have · **◆** strong · **○** useful · `raw` already on disk · `new` never touched.

### For `subject-design` — row 109

| # | source | flag | one line | rows | pages |
|---|---|---|---|---|---|
| G1 | [gh#4170 — Subject Indexing and Ordering Internals](https://github.com/nats-io/nats-server/discussions/4170) · `raw/gh-discussions/gh-4170.md` | ★ `raw` | @derekcollison's chosen answer: indexed by sequence **and** by subject; "the subject addressing layer to a stream takes more memory the more unique subjects that you have"; core ordering is per publishing connection. Asked *for an event-sourcing store*, with a concrete `events.{tenant}.{arType}.{arId}.{eventType}` design and its cardinalities. The 2025-07 follow-up (how are sparse subjects indexed, is there a skip scan, can we walk backwards) is **unanswered**. | 109, 144 | [[subjects-and-wildcards]] · [[filestore-layout]] · [[core-nats-delivery]] |
| S1 | [Synadia — *How to Design NATS Subject Hierarchies (Patterns, Pitfalls & Best Practices)*](https://www.synadia.com/blog/designing-nats-subject-hierarchies), Andrew Connolly, 2026-06-17 | ★ `new` | The only public article that is *exactly* row 109. Three named patterns (namespace-first, identifier-first, multi-dimensional) with a selection rule; reserved prefixes including **`$JSC.`, `$NRG.`, `_R_.`, `_GR_.`** (check each against the server); cardinality (never put a correlation id in a subject — headers instead); permissions as the second consumer of the hierarchy; an evolution strategy (version tokens, then subject mappings, in the order stream filters → consumer filters → permissions); and the numbers to verify: **16 tokens**, **256 characters**, **32-token stack array**, **100,000 per-subject metadata entries per request**. | 109, 108 | [[subjects-and-wildcards]] · [[subject-transforms]] · [[subject-permissions]] · [[stream]] |
| X1 | [so#72585165 — *Nats/Jetstream: naming conventions for commands' subjects*](https://stackoverflow.com/questions/72585165) (score 5, accepted answer score 7) | ◆ `new` | The community convention as it actually circulates: lowercase dotted, reverse-DNS grouping, `public.`/`private.` prefixes, `js.in.`/`js.out.` for JetStream, 16 tokens — and **do not put a version in the subject**, version the schema in a header. Contradicts S1 head-on. | 109 | [[subjects-and-wildcards]] |
| N1 | [NATS by Example — *Subject-Mapped Partitions* (CLI)](https://natsbyexample.com/examples/jetstream/partitions/cli/) | ◆ `new` | The first source from natsbyexample.com in this wiki. `mappings: { "events.*": "events.{{wildcard(1)}}.{{partition(5,1)}}" }` with five streams on `events.*.$i`, `nats server mapping` to test it, and three measured publish shapes (7,152 / 74,794 / 92,590 msgs/s) on a 2-core GitHub runner — the authors' own caveat about the environment included. | 109, 108, 111 | [[subject-transforms]] · [[stream]] · [[jetstream-sizing]] |
| G2 | [gh#3908 — Ordering guarantees per entity](https://github.com/nats-io/nats-server/discussions/3908) | ◆ `new` | @bruth: relative order per entity is guaranteed by one stream and one consumer; to scale out, **define partitioning as a subject mapping and give each partition its own stream and consumer**. Also names the KV-lease active/failover trick. The asker wanted Kafka's automatic partition rebalancing and is told it does not exist. | 109, 111, 115 | [[subject-transforms]] · [[worker-pool]] · [[key-value]] |
| X2 | [so#74482528 — *Designing stream and subject names in NATS*](https://stackoverflow.com/questions/74482528) (score 3, **unanswered**) | ○ `new` | Row 109 asked in public and never answered — evidence for the bank, worth a line on the page rather than a summary of its own. | 109 | — |

### For `stream-topology-design` — rows 108, 111, 114

| # | source | flag | one line | rows | pages |
|---|---|---|---|---|---|
| G3 | [gh#6100 — Does Stream Per Subject have any performance benifits…](https://github.com/nats-io/nats-server/discussions/6100) · `raw/gh-discussions/gh-6100.md` | ★ `raw` | The chosen answer to row 108: many consumers on one stream as the starting point, "rarely a good idea to have stream per subject", each replicated stream carrying its own Raft group, the exception being **different retention policies per subject**; consumer leaders spread across replicas. The follow-up asking for documentation of the internals is answered with "you would need to dig the source code" and a consulting offer — which is why this wiki exists. | 108 | [[stream]] · [[consumer]] · [[raft-in-nats]] · [[replicas]] |
| G4 | [gh#3405 — Consumer Filtering Performance](https://github.com/nats-io/nats-server/discussions/3405) · `raw/gh-discussions/gh-3405.md` | ★ `raw` | Row 111's core fact, from @derekcollison and @jnmoyne in 2022 (2.9): a filtered consumer over one matching message in a million-message stream does **not** table-scan; indexing finds first and last efficiently. Old, so it must be re-checked on 2.14.6 (step 3 run C). | 111 | [[consumer]] · [[filestore-layout]] · [[jetstream-slows-as-consumers-grow]] |
| G5 | [gh#6571 — Which NATS JetStream Setup is Better?](https://github.com/nats-io/nats-server/discussions/6571) · `raw/gh-discussions/gh-6571.md` | ★ `raw` | Row 114 as an operator poses it: WorkQueue source + Limits mirror against one Limits stream with a fast and a slow consumer. @jnmoyne: "It's not because a stream is larger that delivery of messages to consumers takes longer" — approach 2, and the only side effect named is memory from per-subject indexing. | 114, 110 | [[mirrors-and-sources]] · [[retention-policies]] · [[consumer]] |
| S2 | [Synadia — *Mirror Streams in NATS JetStream: One-Way Replication Made Simple*](https://www.synadia.com/blog/mirror-streams-jetstream), Peter Humulock, 2026-02-18 | ◆ `new` | Substantial, not marketing: CLI (`nats str add events2 --cluster c2 --mirror events --defaults`) and Go (`Mirror: &jetstream.StreamSource{…}`), the limitations stated (deletes do not replicate, partial WorkQueue support) and **"NATS 2.12 introduced mirror promotion"** — check that against [[mirrors-and-sources]] and [[disaster-recovery]], which describe a manual five-step promotion. | 114 | [[mirrors-and-sources]] · [[disaster-recovery]] · [[nats-server-2.12]] |
| S3 | [Synadia — *Designing NATS JetStream for per-tenant FIFO processing*](https://www.synadia.com/blog/nats-jetstream-per-tenant-fifo-processing), Andrew Connolly, 2026-05-20 | ◆ `new` | Row 108 answered the other way from G3: **one stream per tenant**, because it separates ordering from parallelism and one blocked tenant does not stall another; "roughly hundreds to low thousands of tenants", deliberately no hard limit, and it stops working when tenants churn. Conceptual — no keys, no versions. | 108 | [[stream]] · [[account]] · [[retention-policies]] |
| S4 | [Synadia — *Partitioned Consumer Groups in NATS JetStream*](https://www.synadia.com/blog/partitioned-consumer-groups), Peter Humulock, 2026-07-15 | ◆ `new` | Deterministic `{{partition(N, token…)}}` plus **pinned-client** pull consumers plus a group abstraction, shipped as an **Orbit** library (`pcgroups.CreateStatic/Elastic…`) and a `cg` CLI; "requires NATS Server 2.11+", partitioning since 2.10. No numbers. Where row 111's "many small streams" answer actually goes in practice. | 111, 115 | [[priority-groups]] · [[subject-transforms]] · [[orbit]] · [[worker-pool]] |
| S5 | [Synadia — *Mirror, Merge, or Consume: How to Choose Your Edge-to-Core Streaming Pattern*](https://www.synadia.com/blog/nats-edge-event-architecture-8-mirror-merge-or-consume), Bruno Baloi, 2026-05-18 | ○ `new` | Row 114's three shapes named and given a decision rule (consume when logic belongs at the ingest boundary; mirror for compliance and DR; merge for cross-site analytics). **Conceptual only** — no config, no numbers. Take the decision rule, cite it, and get the mechanics from S2 and the runs. | 114, 125 | [[mirrors-and-sources]] · [[multi-region-jetstream]] |
| S6 | [Synadia — *Scaling Dynamic Dashboard Subscriptions with JetStream and Core NATS*](https://www.synadia.com/blog/scaling-dynamic-dashboard-subscriptions-jetstream-core-nats), Andrew Connolly, 2026-05-20 | ○ `new` | Many users each watching a dynamic, overlapping set of subject filters over one JetStream data set — the shape row 111 becomes when the consumer count is driven by users rather than by services. Pairs with [[jetstream-slows-as-consumers-grow]]'s *Designing consumers away*. | 111 | [[jetstream-slows-as-consumers-grow]] · [[direct-get]] · [[core-nats-delivery]] |

### For `## Choosing retention` — row 110

| # | source | flag | one line | rows | pages |
|---|---|---|---|---|---|
| G6 | [gh#4499 — JetStream and Work retention policy Stream with Durable consumers and fan-out](https://github.com/nats-io/nats-server/discussions/4499) · `raw/gh-discussions/gh-4499.md` | ★ `raw` | Row 110 exactly, and it is a *mistake* story rather than a comparison: a fan-out design built on WorkQueue, `filtered consumer not unique on workqueue stream (10100)`, @ripienaar's "dont use WorkQueue … Use Interest or limits", and the asker's confirmation two weeks later that Limits was the answer. The full `nats stream add` and `nats consumer add` lines are in the thread, including `--max-deliver=9999999999999` because the asker did not know `-1` was allowed. | 110 | [[retention-policies]] · [[consumer]] · [[worker-pool]] · [[error-codes]] |
| N2 | NATS by Example — [limits-stream](https://natsbyexample.com/examples/jetstream/limits-stream/go), [interest-stream](https://natsbyexample.com/examples/jetstream/interest-stream/go), [workqueue-stream](https://natsbyexample.com/examples/jetstream/workqueue-stream/go) | ○ `new` | One runnable example per retention policy, in a dozen languages. Useful as the *shape* of each policy's canonical use and as an outbound link; nothing here that [[retention-policies]] does not already state from the docs and the server. | 110 | [[retention-policies]] |

### For row 144 — JetStream as an event store

| # | source | flag | one line | rows | pages |
|---|---|---|---|---|---|
| G7 | [gh#3772 — Using Nats Jetstream as an event store](https://github.com/nats-io/nats-server/discussions/3772) · `raw/gh-discussions/gh-3772.md` | ★ `raw` | 10 upvotes, chosen answer by @bruth: a subject per aggregate under one stream; OCC with `Nats-Expected-Last-Sequence` (stream) or `Nats-Expected-Last-Subject-Sequence` (subject); "Subjects are indexed within a stream, so the OCC check does not add overhead"; a filtered replay scans only "the blocks between the earliest and latest events for that subject"; concurrent appends across subjects do not contend while the stream keeps a total order. And the dead end: **tiered storage is not built in**, an archiving consumer is the substitute. Dated 2023-01-08 — every claim re-checked on 2.14.6 before it goes on a page. | 144, 109, 112 | [[stream]] · [[publishing]] · [[filestore-layout]] · [[retention-policies]] |
| G8 | [gh#3871 — Is Tiered Storage currently planned?](https://github.com/nats-io/nats-server/discussions/3871) | ◆ `new` | The cold-storage half of row 144, with a date on it: @derekcollison 2023-02-16 "We have it planned but no schedule yet", asked again 2024-10-31 and 2024-12-07 (against Kafka's and Pulsar's tiered storage) with **no further maintainer commitment**. Three and a half years of "planned" is the answer an architect needs. | 144 | [[stream]] · [[nats-server-2.15-preview]] · [[nats-streaming]] |
| S7 | [Synadia — *JetStream Expected Sequence Headers: Optimistic Concurrency Without Locks*](https://www.synadia.com/blog/understanding-jetstream-expected-sequence-headers), Peter Humulock, 2026-01-20 | ◆ `new` | The OCC half in detail, and it names a **third header the wiki has never mentioned** — `Nats-Expected-Last-Subject-Sequence-Subject` (per-pattern validation) — plus the failure string `wrong last sequence: <n>`. States no minimum server version; find it in the source. **Check [[publishing]] and [[stream-and-consumer-config]] against this before writing.** | 144, 112 | [[publishing]] · [[stream]] · [[stream-and-consumer-config]] · [[error-codes]] |
| G9 | [gh#4417 — I cannot find any documentation … how Nats-Rollup is intended to work](https://github.com/nats-io/nats-server/discussions/4417) | ○ `new` | @bruth on `Nats-Expected-*`: "the server enforcing optimistic concurrency control at the stream or subject level", with the two-concurrent-publishers example; plus the 2023 docs PR and the promise of a headers table that row 144's page can check has since been kept. Names the server's own tests (`TestJetStreamRollup`, …). | 144, 112 | [[publishing]] · [[object-store]] |

---

## Seen and deliberately not in G1

Recorded so a later phase does not re-scout `synadia.com/blog` from scratch — it was read end to end
on 2026-09-04 (111 posts).

| source | date | for |
|---|---|---|
| [Using NATS JetStream or KV for Per-Service Configuration](https://www.synadia.com/blog/jetstream-service-configuration-kv-watchers) | — | **G3**, rows 118, 119 |
| [Designing Tenant-Isolated Edge Cold Starts with JetStream](https://www.synadia.com/blog/tenant-isolated-edge-cold-starts-jetstream) | 2026-05-20 | **G5**, row 125 |
| [Scaling NATS for Per-User Real-Time Notifications](https://www.synadia.com/blog/scaling-nats-per-user-notifications) | 2026-05-20 | **G5/H**, rows 111, 126 |
| [Scaling Global AI Inference with NATS JetStream](https://www.synadia.com/blog/scaling-global-ai-inference-with-nats-jetstream) | 2026-01-19 | **G5**, row 124 |
| [MQTT vs. NATS for Fleet Management](https://www.synadia.com/blog/nats-vs-mqtt-technical-comparison-iot-fleet-management) | 2026-02-17 | **G8**, row 137 |
| [NATS and Kafka Compared](https://www.synadia.com/blog/nats-and-kafka-compared) · [Total cost of ownership: NATS vs Kafka](https://www.synadia.com/blog/nats-io-total-cost-of-ownership-tco-comparison-with-kafka) · [How Sophotech Cut Latency 3x Migrating from RabbitMQ](https://www.synadia.com/blog/rabbitmq-to-nats-sophotech-migration) | 2024–2025 | **G8**, row 136 |
| [Jepsen: NATS 2.12.1](https://www.synadia.com/blog/jepsen-nats-2-12-1), Neil Twigg | 2025-12-22 | **I** — an external audit of the consistency claims [[replicas]] and [[raft-in-nats]] make; the strongest unread source about correctness in the whole ecosystem |
| [Multi-Region Consistency: Have Your Cake and Eat it Too!](https://www.synadia.com/blog/multi-cluster-consistency-models), @jnmoyne | 2024-04-17 | **G5**, rows 124, 125 |
| [Consumer Pausing in NATS 2.11](https://www.synadia.com/blog/consumer-pausing-nats-2-11) | 2026-01-06 | **G2**, row 117 |
| [Distributed Counters](https://www.synadia.com/blog/distributed-counter-crdt) · [Atomic Batch Publishing in NATS 2.12](https://www.synadia.com/blog/atomic-batch-publishing-nats-2-12) · [Pull Consumer Priority Groups](https://www.synadia.com/blog/pull-consumer-priority-groups) · [Message Tracing in NATS 2.11](https://www.synadia.com/blog/message-tracing-nats) · [Per-Message TTL](https://www.synadia.com/blog/per-message-ttl-nats-2-11) | 2026 | **I** — each maps to a concept page already written ([[publishing]], [[priority-groups]], [[message-ttl]]); ingest if the page's version notes are thin |
| gh#4457 (API-first stream management, @ripienaar on why streams are not config) | 2023-08-31 | **G4**, rows 121–123 |
| [NATS by Example — Multi-Stream Consumption (legacy)](https://natsbyexample.com/examples/jetstream/multi-stream-consumption/go/) | — | fan-in with one `DeliverSubject` across push consumers; marked *legacy* on the site, so it is a **deprecation note** for [[consumer]] rather than a pattern to recommend |

**Not found, do not search again without a new source:** no public thread, post or answer weighs
**one stream with a tenant prefix against one stream per tenant with numbers** — S3 asserts a range
("hundreds to low thousands") without a measurement and G3 asserts the opposite default without one.
Step 3's runs are the only way this wiki can answer row 108 honestly, and the page must say that the
numbers are its own.

---

## Recommendation

Ingest **G1, G3, G4, G5, G6, G7** (the six threads, already in `raw/`) plus **S1** and **S7** — eight
summaries, the plan's cap. S1 because it is the only article that is row 109 and because verifying its
four numbers is itself a deliverable; S7 because it names a header the wiki does not have. Take **G2,
G8, N1, S2, S4** in a second pass if the pages need them; **X1** as a cited line inside `subject-design`
rather than a summary of its own.

**Status (2026-09-04).** The user took the recommendation whole. **Ingested in step 2** — eight
summaries: `s-gh-6100-stream-per-subject-or-one` (G3), `s-gh-4170-subject-indexing-internals` (G1),
`s-gh-4499-workqueue-fanout-retention` (G6), `s-gh-3405-consumer-filtering-performance` (G4),
`s-gh-6571-source-mirror-or-one-stream` (G5), `s-gh-3772-jetstream-as-an-event-store` (G7),
`s-synadia-subject-hierarchies` (S1) and `s-synadia-expected-sequence-headers` (S7), with 15 ripples
and docs issue **#123**.

**Not ingested, still open** — a second pass if the pages need them: **G2** (gh#3908, partitioning as a
subject mapping), **G8** (gh#3871, tiered storage), **N1** (NBE subject-mapped partitions), **N2** (the
three retention examples), **S2** (mirror streams — its *mirror promotion in 2.12* claim is unchecked),
**S4** (partitioned consumer groups / Orbit `pcgroups`), **S5**, **S6**, **G9** (gh#4417), **X1** and
**X2** (cited inline rather than summarised).

**One candidate the ingest itself turned up**: gh#3772's last comment (2025-03-26) points at
[gh#6478](https://github.com/nats-io/nats-server/discussions/6478) — *"S3 next level"* — as the general
approach to storage tiering and "DB-Stream duality". Not read. It is the natural companion to G8 when
row 144's page is written.

**Bank**: gh#3871 became **row 198** (tiered storage as its own asked question); row 112's cell now
names the new `publishing` section. Rows 108–111, 114 and 144 stay open by design — a row is answered
when a page states the answer, and those pages are steps 4–7.
