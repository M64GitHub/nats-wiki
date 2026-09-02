# Scout — the public form of the posed design rows 108–137 (2026-09-03)

Phase C, step 2 of `inbox/plan-discussions-triage-2026-09-03.md`; backlog §5(a). The 30 rows the
maintainer posed on 2026-09-02 (`own` in *asked at*, `design` in *flags*) were each searched for the
place somebody asked them in public, so `own` becomes evidence where it can.

**What was searched.** (1) `inbox/gh-discussions-toc.md` and its index — every title and original
post of the 484 `nats-io/nats-server` discussions (`raw/gh-discussions-index/`); (2) every comment
and reply of those threads, cached by `tools/triage-discussions.py --with-comments` under
`local/scratch/gh-index/` (808 comments; a cache, never cited); (3) the Stack Overflow `nats.io`,
`nats-jetstream` and `nats-server` tags through the Stack Exchange API (`/search/advanced`, 60 short
tag-scoped queries). Each row had five to ten regexes for its two options and its "how should I"
phrasing; every hit above the noise was read (original post and the chosen answer or first replies).
The verdict rule, from the plan: a row is **found** only when a thread asks **the row's question with
its trade-off** — one of its named options posed as a choice, or its "how should I" — not when a
thread merely touches the topic. A *partial* verdict names which half of the row the thread asks.

**Result: 21 found (13 whole, 8 partial), 9 searched and not found.** The bank cells were replaced
with the URL for the 21; the row text stayed. The 9 keep `own` and are recorded in
`inbox/scout-backlog.md` §5(a) so the search is not repeated. Nothing was ingested; the threads worth
a page are listed at the end for phase G's per-page scouts (§5(b)).

| row | verdict | public form | what it asks, in the asker's words | pages (phase G) |
|---|---|---|---|---|
| 108 | found | [gh#6100](https://github.com/nats-io/nats-server/discussions/6100) · Q&A 2024-11 · answered (maintainer) | "100 subjects: 100 streams, or 1 stream with 100 subjects and subject filters — which is optimal?" → one stream; every replicated stream carries its own Raft group; split only for a different retention | [[stream-topology-design]] |
| 109 | found (cardinality and token order) | [gh#4170](https://github.com/nats-io/nats-server/discussions/4170) · Q&A 2023-05 · answered (maintainer) | "how does JetStream index subjects for filtered consumers; how does it perform with millions of unique subjects over a long period; same ordering on `a.s1.eventType1` as on `a.s1`?" | [[subject-design]] |
| 110 | found | [gh#4499](https://github.com/nats-io/nats-server/discussions/4499) · Q&A 2023-09 · answered (maintainer) | fan-out to N apps that go offline and come back, built on a WorkQueue stream → "use Interest or Limits"; the thread is the *what breaks when I choose wrong* case | [[retention-policies]] |
| 111 | found | [gh#3405](https://github.com/nats-io/nats-server/discussions/3405) · Q&A 2022-08 · answered (maintainer) | "one big stream with many filtered consumers instead of overlapping streams — as data grows, does a filter that matches one message in a million walk the whole stream?" | [[stream-topology-design]] |
| 112 | **not found** | — | nearest: gh#3772's answer (expected-last-subject-sequence for event stores), gh#4417 (`Nats-Expected-*` as optimistic concurrency), gh#6737 (sequences monotonic); nobody poses dedup *versus* expected-sequence | [[publishing]] |
| 113 | found (the replica half) | [gh#6437](https://github.com/nats-io/nats-server/discussions/6437) · Q&A 2025-01 · answered (maintainer) · 4 upvotes | "what is the recommended replication factor for streams in a 3-node cluster; Kafka's min.isr=2 — do I need R3; replication overhead is high at high rates — replicate all streams R3?"; memory-vs-file is not asked as a design choice | [[replicas]] |
| 114 | found | [gh#6571](https://github.com/nats-io/nats-server/discussions/6571) · Q&A 2025-02 · answered | "Which setup is better: a WorkQueue source plus a Limits mirror for the slow analytics consumer, or one Limits stream with two consumers?" — the row's trade-off with pros and cons written out by the asker | [[stream-topology-design]] · [[mirrors-and-sources]] |
| 115 | found | [gh#5415](https://github.com/nats-io/nats-server/discussions/5415) · Q&A 2024-05 · answered (maintainer) | "distribute one subject to a dynamic pool of apps with pull readers — today a push consumer with a deliver queue group; can pull do it? like Kafka's consumer group" → one pull consumer, bind as many apps, drain on scale-down | [[worker-pool]] |
| 116 | **not found** | — | nearest: gh#5211 (row 15), gh#4972 (row 19), gh#2799 (queue-group-scoped `MaxAckPending`, an idea), so#67174521 (consume and commit by batch); nobody asks how to set the four together for a target | [[worker-pool]] |
| 117 | found (the liability half) | [gh#8174](https://github.com/nats-io/nats-server/discussions/8174) · Q&A 2026-05 · maintainer replied, no chosen answer | "pods join with random names, so every scale-out creates a new consumer — does NATS clean stale consumers, or will orphaned work queues hang indefinitely?" | [[consumer]] |
| 118 | found (the bucket-size half) | [gh#5334](https://github.com/nats-io/nats-server/discussions/5334) · Q&A 2024-04 · answered | "past 100k keys, writes are fine but `nats kv ls` and `kv compact` take 30+ minutes at 99% of a core — is KV not meant for this?"; bucket-per-tenant is not asked | [[kv-bucket-design]] · [[key-value]] |
| 119 | found | [gh#5468](https://github.com/nats-io/nats-server/discussions/5468) · Q&A 2024-05 · answered (maintainer) · ★ | "KV and Object Store as a database — which scenarios don't make sense for replacing Postgres?" → no-SQL, subject addressing and compare-and-set yes; SQL, joins, transactions no | [[key-value]] · [[kv-bucket-design]] |
| 120 | found | [so#78477337](https://stackoverflow.com/questions/78477337/is-anyone-using-nats-object-store-in-production) · 2024-05 · score 6 · **no answers** | "messages passed 8 MiB; raising `max_payload` warned about performance; the docs said use the Object Store; PoC works — is anyone running it in production, and what limit did my ticker hit?" | [[large-messages]] · [[object-store]] |
| 121 | found | [gh#6848](https://github.com/nats-io/nats-server/discussions/6848) · Q&A 2025-04 · maintainer replied, no chosen answer | "a server account must consume from thousands of edge accounts; importing every one makes the JWT too big for the server — easier way?" → one account, thousands of users, subject permissions; "all edges must use their own accounts due to separation requirements" | [[multi-tenancy-design]] · [[account]] |
| 122 | found (the moving-later half) | [gh#6739](https://github.com/nats-io/nats-server/discussions/6739) · Q&A 2025-03 · maintainer replied, no chosen answer | "our JWT authentication domain got messy; can we migrate the streams in place into a clean new operator?" → backup and restore; which model to start with is not asked in public | [[choosing-an-auth-model]] · [[operator-mode]] |
| 123 | **not found** | — | nearest: gh#5128 (how many streams and consumers a 3- or 5-node cluster takes), gh#4457 (streams from config); no thread asks how to apportion per-account JetStream limits | [[account]] |
| 124 | found | [gh#5317](https://github.com/nats-io/nats-server/discussions/5317) · Q&A 2024-04 · maintainer replied, no chosen answer | "a 3-data-centre 9-node supercluster adding JetStream: does Raft cross the data centres; where does stream A live; publish in DC2 and subscribe in DC1?" — already answered by the pages; only the URL is new | [[choosing-a-topology]] · [[multi-region-jetstream]] |
| 125 | found | [gh#5974](https://github.com/nats-io/nats-server/discussions/5974) · Q&A 2024-10 · answered (maintainer) | "1,700 stores, a leaf node in each, JetStream source and mirror to the cloud cluster so in-store apps survive Internet outages — is this the right approach; how do we limit the gossip?" → the same-cluster-name trick | [[edge-with-intermittent-links]] · [[leafnode]] |
| 126 | found (the quorum half) | [gh#3417](https://github.com/nats-io/nats-server/discussions/3417) · Q&A 2022-08 · answered (maintainer) | "the cluster can't tolerate more than one failure" → the quorum arithmetic for three; the two-zone layout is not asked | [[cluster-size-and-zones]] · [[raft-in-nats]] |
| 127 | **not found** | — | nearest: gh#2730 (moving a stream to a set of nodes), so#71587299 (parts of a stream on different servers — placement); nobody asks whether JetStream should run on every server or on dedicated ones, or how to partition roles | [[partitioning-roles-in-a-cluster]] |
| 128 | **not found** (design form) | — | nearest: so#70550060 (*Performance of NATS Jetstream*, score 18: how does it scale; "~250k small msgs/s for an R3 filestore"), gh#6879 (row 1), gh#7738 (row 11); the derivation is never asked as one question. Already answered by [[jetstream-sizing]] | [[jetstream-sizing]] |
| 129 | found — **already row 57's thread** | [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) · Q&A 2024-11 · unanswered | "which exporter metrics alert on cluster down, memory, store usage, drops, latency, throughput?" — row 129 is the design form of row 57; phase G6's `production-alerting` answers both | [[production-alerting]] · [[monitoring-endpoints]] |
| 130 | found (the not-rollback-safe half) | [gh#4201](https://github.com/nats-io/nats-server/discussions/4201) · Q&A 2023-05 · maintainer replied, no chosen answer | "upgrading a Helm-installed cluster from v2.8.0 to v2.9.17 — breaking changes that require migrating via an explicit version?"; node order and the mixed-version window are not asked | [[upgrade-a-cluster]] |
| 131 | **not found** | — | nearest: gh#6594 (row 68: throughput fell moving from Kubernetes to a VM), gh#7749 (row 66: `hostPath`), so#72917865 / so#75588016 (the chart's PVCs); nobody asks Kubernetes versus VMs versus bare metal as a choice | [[where-to-run-jetstream]] · [[kubernetes-storage]] |
| 132 | **not found** | — | nearest: gh#5614 (a full backup into a GCS bucket → a script over `nats` and `nsc`), so#68767392 (back up all streams → `nats account backup`); both ask *how to back up*, neither weighs snapshots against a mirror or R3. Already answered by [[disaster-recovery]] | [[disaster-recovery]] |
| 133 | **not found** | — | nearest: gh#4984 (*Nats micro with Jetstream*, 8 upvotes — wants micro handlers to ack and nak; a feature request, not a choice), so#74129868 (JetStream as the only source of truth like Kafka), gh#6274 (row 7); nobody asks how to decide core versus JetStream per flow | [[core-or-jetstream]] |
| 134 | **not found** | — | nearest: gh#2758 (cancelling the slower of competing responders), gh#4911 (routing request subjects by id ranges), gh#4761 (no-responders in multitenancy), so#67502707 (`NoRespondersException`); the service-layer design is not asked | [[services-on-core-nats]] |
| 135 | found | [gh#6320](https://github.com/nats-io/nats-server/discussions/6320) · Ideas 2025-01 · maintainer replied · 1 upvote | "a 40 MB put into KV failed at `max_payload` 64 MB — rather than raising the limit, should NATS chunk automatically the way the object store does, everywhere?" → "that's what the object store is for; NATS isn't optimised for big payloads, 2 or 3 MB max is a good rule" | [[large-messages]] |
| 136 | found | [gh#3654](https://github.com/nats-io/nats-server/discussions/3654) · Q&A 2022-11 · maintainer replied, no chosen answer · **15 upvotes** | "from RabbitMQ and a Kafka PoC: stateful services need one consumer per partition and a rebalance event when one disconnects — how do partitions, groups and rebalancing map onto JetStream?" | [[migrating-from-kafka-or-rabbitmq]] |
| 137 | found (the fit half) | [gh#5507](https://github.com/nats-io/nats-server/discussions/5507) · Ideas 2024-06 · maintainer replied · 2 upvotes | "planning to replace VerneMQ with NATS — does its MQTT support webhooks and mountpoints?" → not at this time; what sessions, QoS and retained messages cost in JetStream is not asked (gh#7533 shows it as a symptom) | [[mqtt]] |

## Second candidates, per row

Kept here so a page scout does not re-find them. None replaces the cell above; several are worth a
summary when the page is written.

- **108** — gh#5128 (*Inquiry on Limits for Streams and Consumers*, answered, 3 upvotes: "10, 100,
  1,000, 10,000 streams?" → "we limit servers to 2k HA assets; use muxed streams and let consumers
  filter"), gh#6437 (multiple streams, all R3?), gh#3772 (event store, 10 upvotes; already in the
  scratch cache for G1).
- **109** — gh#5097 (the 16-token guidance, answered), gh#8333 (row 9), gh#7468 (sharded workers).
- **110** — gh#4694 (retention on a leaf stream whose only reader is the hub's source; answered:
  WorkQueue there has bitten people), gh#3637 (row 21), gh#4778 (row 22).
- **111** — gh#6100 (the same trade-off from the stream side), gh#2933 (*NATS client-server architecture problem*, answered: one stream, mux the subjects, one filtered consumer per independently processed set — the same question again, so no bank row of its own), gh#4797 ("50 million consumers per
  stream" → not with ordinary consumers), gh#5128 Q2, gh#7863 (row 6), gh#4170.
- **113** — gh#8417 (row 76 measures file against memory), gh#5551 (128 R3 memory streams as
  partitions, 8 comments), gh#3739 (partitions for resilience → R3 instead).
- **114** — gh#6328 (a read replica of a KV bucket per region: supercluster or leaf nodes → leaf
  nodes sourcing from the cluster), gh#5889 (fan-in from N leaf nodes; "aggregate stream or one per
  source?"; sources can be added to a live stream).
- **115** — so#77443366 (*Modeling multiple, replicated consumers*, unanswered: MQTT shared
  subscriptions → JetStream), so#78460018 (several instances, same pull consumer), so#77939652
  (Kafka-like queue with groups), gh#2758.
- **117** — gh#7863 (row 6; "durable or ephemeral, R1 or R3?" from the maintainer's side).
- **118** — gh#6418 (an LRU bucket → `MaxMsgsPerSubject` / history), gh#4580 (revision is per
  bucket), gh#7264 (TTL precedence).
- **119** — gh#4803 (*locks/leases with KV similar to SETNX*: `DiscardNewPerSubject`, one message
  per subject, `max_age`), so#79400839 (*KV for distributed locking*, score 5, unanswered: R1 write
  with async replication?), so#75576454 (*Object Store or KV vs Redis Cache*, score 14).
- **120** — so#75576454, gh#6478 (*S3 next level*, **42 upvotes**, an offload/tiering idea),
  gh#4689 (no partial updates to an object; chunks are ordered), gh#6320.
- **121** — gh#5606 (rows 90, 96, 98: the import ceiling), gh#4761 (no-responders across accounts).
- **122** — gh#3145 (*nsc operator sharing/config*, 8 upvotes, unanswered: several people
  maintaining one operator), gh#7606 (user/password → JWT for multi-tenancy), gh#5813 (auth callout
  behind a leaf).
- **125** — gh#5889 (IoT devices as leaf nodes, syncing after disconnects), gh#6020 (100k ephemeral
  consumers on a leaf mirror raised hub CPU; unanswered), gh#4694.
- **126** — gh#5989 (consume from the same zone as the pod; DNS per cluster), gh#8007 (zone-aware
  reads, an idea), gh#6301 (three AZs on the Bitnami chart).
- **130** — gh#4781 (row 64), gh#3842 (a 2.0.4 → 2.9.7 core upgrade that "broke" for want of a
  cluster name, 12 comments).
- **136** — gh#3739, gh#8174, gh#7296 (Pulsar key-shared), so#77939652, gh#2626 (from REST).
- **137** — gh#4750, gh#6613, gh#7641 (QoS and retained specifics), gh#7533 (the cost as a symptom).

## For phase G's per-page scouts (§5(b))

Threads that should become summaries when their page is written, none fetched whole yet:
gh#6100, gh#5128, gh#6571 and gh#3405 (G1 `stream-topology-design`); gh#4170 (G1 `subject-design`);
gh#4499 (G1, the retention section); gh#5415 (G2 and [[worker-pool]]); gh#8174 (G2); gh#5468,
gh#4803, gh#5334 and so#79400839 (G3 `kv-bucket-design`); so#78477337, gh#6320 and gh#6478 (G3
`large-messages`); gh#6848 (G4 `multi-tenancy-design`); gh#6739 and gh#3145 (G4
`choosing-an-auth-model`); gh#5974, gh#5889 and gh#6020 (G5 `edge-with-intermittent-links`);
gh#3417 and gh#5989 (G5 `cluster-size-and-zones`); gh#5317 (G5, the placement section of
[[multi-region-jetstream]]); gh#6182 (G6 `production-alerting`, with row 57); gh#4201 (G6, a note on
[[upgrade-a-cluster]]); gh#4984 and so#74129868 (G7 `core-or-jetstream`); gh#3654, gh#3739 and
so#77939652 (G8 `migrating-from-kafka-or-rabbitmq`); gh#5507 (G8, the MQTT section).

## Status

Not an ingest — no summaries. Bank: 21 rows' *asked at* replaced (`own` → URL), 9 rows keep `own`
and are recorded in `inbox/scout-backlog.md` §5(a). The comment cache under `local/scratch/gh-index/`
stays until phase G has used it.
