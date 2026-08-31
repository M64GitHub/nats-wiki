# Question bank — what this wiki must answer

The scope test and the scoreboard. Every row is a question an operator or architect actually
asked **in public**, with a link to where it was asked. A page belongs in this wiki if it helps
answer a row here; a row is *answered* only when a page states the answer with a citation and a
version — not when a page merely touches the topic.

- `★` marks the questions that must be answerable for the wiki to be useful at all.
- `no-public-answer` marks a row this wiki searched for and could not answer from public sources.
  Its `answered by` cell names the page that says so, in bold — a stated dead end is an answer; an
  empty cell is unfinished work.
- `answered by` holds `[[wikilinks]]`; the viewer counts filled rows as "ingested" and the
  filters at the top let you see what is still open.
- Add rows whenever a query, an ingest or a thread reveals a question the bank does not cover.
  Never add a question without a source for someone asking it — that is a guess, not a question.

Seeded 2026-08-31 by mining `nats-io/nats-server` GitHub Discussions (484 threads read by title,
Q&A and General categories) and the Stack Overflow `nats-jetstream` / `nats.io` / `nats-server`
tags. Sources for each row are in the *asked at* column. The mining script and method are
described in `inbox/plan-first-ingests-2026-08-31.md`.

| # | question | area | asked at | flags | answered by |
|---|---|---|---|---|---|
| 1 | How do I size a 3-node R3 JetStream cluster (disk, RAM, IOPS) for a given message rate, size and retention? | jetstream deploy | [gh#6879](https://github.com/nats-io/nats-server/discussions/6879) | ★ sizing | [[jetstream-sizing]] · [[filestore-layout]] |
| 2 | How much disk does a stream actually use beyond the raw message bytes (blocks, index, per-subject state)? | jetstream | [gh#5742](https://github.com/nats-io/nats-server/discussions/5742) | ★ sizing internals | [[filestore-layout]] · [[jetstream-sizing]] |
| 3 | What does a stream actually cost in resources, and how do I run JetStream in the most resource-effective way? | jetstream | [gh#4227](https://github.com/nats-io/nats-server/discussions/4227) | ★ sizing | [[jetstream-sizing]] |
| 4 | Is there a practical cap on the number of messages in a single stream? | jetstream | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) | sizing | |
| 5 | What is the largest known-good value for MaxMsgs on a stream? | jetstream | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) | sizing config | |
| 6 | How many consumers can one stream and one server support before it hurts? | jetstream | [gh#7863](https://github.com/nats-io/nats-server/discussions/7863) | ★ sizing | [[jetstream-slows-as-consumers-grow]] · [[jetstream-sizing]] |
| 7 | Why does publisher throughput collapse when many consumers attach to the stream? | jetstream | [gh#6274](https://github.com/nats-io/nats-server/discussions/6274) | ★ sizing gotcha | [[jetstream-slows-as-consumers-grow]] |
| 8 | Why is my async publish throughput far below the numbers in the docs? | jetstream | [gh#7599](https://github.com/nats-io/nats-server/discussions/7599) | sizing gotcha | |
| 9 | Does a high-cardinality subject space hurt stream performance? | jetstream | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) | sizing | |
| 10 | Why does server memory grow with the number of unacknowledged (pending) messages? | core jetstream | [gh#6820](https://github.com/nats-io/nats-server/discussions/6820) | sizing gotcha | |
| 11 | How do I scale core NATS for bursty traffic — bigger nodes, more nodes, or partitioning? | core topology | [gh#7738](https://github.com/nats-io/nats-server/discussions/7738) | sizing | |
| 12 | What breaks if I raise max_payload above 8MB, and what is the real limit? | core | [gh#7068](https://github.com/nats-io/nats-server/discussions/7068) | ★ config sizing | [[jetstream-sizing]] · [[defaults-and-limits]] |
| 13 | Why is JetStream startup and recovery slow with tens of millions of messages? | jetstream | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) | gotcha sizing | |
| 14 | Why does my consumer keep redelivering messages that were acknowledged? | jetstream | [so#78603662](https://stackoverflow.com/questions/78603662/nats-jetstream-messages-being-processed-multiple-times-by-my-consumer-even-when) | ★ gotcha | [[ack-and-redelivery]] |
| 15 | What does max_ack_pending actually do, and what happens when it is reached? | jetstream | [gh#5211](https://github.com/nats-io/nats-server/discussions/5211) | ★ config gotcha | [[ack-and-redelivery]] · [[consumer]] · [[worker-pool]] |
| 16 | How do ack_wait and the duplicate window interact? | jetstream | [gh#6628](https://github.com/nats-io/nats-server/discussions/6628) | gotcha config | |
| 17 | Does JetStream support exponential backoff for redelivery? | jetstream | [gh#6350](https://github.com/nats-io/nats-server/discussions/6350) | config | |
| 18 | Why doesn't a NAK cause an immediate redelivery? | jetstream | [gh#5631](https://github.com/nats-io/nats-server/discussions/5631) | gotcha | |
| 19 | Does NakWithDelay hold a max_ack_pending slot and block other messages? | jetstream | [gh#4972](https://github.com/nats-io/nats-server/discussions/4972) | gotcha | |
| 20 | What happens when several consumers share a durable name with different filter subjects on a WorkQueue stream? | jetstream | [gh#6044](https://github.com/nats-io/nats-server/discussions/6044) | ★ gotcha | [[retention-policies]] |
| 21 | What does "disjoint filter subjects" mean for a WorkQueue stream? | jetstream | [gh#3637](https://github.com/nats-io/nats-server/discussions/3637) | config | [[retention-policies]] |
| 22 | How do I inspect which messages are still pending in a work-queue stream? | jetstream monitoring | [gh#4778](https://github.com/nats-io/nats-server/discussions/4778) | ★ monitoring | [[consumer]] · [[worker-pool]] |
| 23 | Does JetStream give exactly-once delivery, and how does the dedup window work? | jetstream | [so#72814502](https://stackoverflow.com/questions/72814502/nats-jetstream-exactly-once-delivery) | ★ concept | [[publishing]] · [[stream]] |
| 24 | What ordering does JetStream guarantee, and per what — stream, subject, key? | jetstream | [so#68984906](https://stackoverflow.com/questions/68984906/does-nats-jetstream-provide-message-ordering-by-a-key) | concept | [[publishing]] · [[stream]] · [[subject-transforms]] |
| 25 | What ordering guarantees does core NATS give? | core | [gh#7577](https://github.com/nats-io/nats-server/discussions/7577) | concept | |
| 26 | Why do stream directories disappear from `store_dir` while `nats stream info` still lists the streams? | jetstream deploy | [gh#5924](https://github.com/nats-io/nats-server/discussions/5924) | ★ gotcha | [[stream-directories-disappear]] |
| 27 | How do I recover a stream that is full under a DiscardNew policy? | jetstream | [gh#2794](https://github.com/nats-io/nats-server/discussions/2794) | gotcha runbook | [[maximum-messages-exceeded]] · [[retention-policies]] |
| 28 | How do per-message TTLs and subject delete markers behave? | jetstream | [gh#7227](https://github.com/nats-io/nats-server/discussions/7227) | config | [[message-ttl]] |
| 29 | Can the server schedule a message for later, with cron-style patterns? | jetstream | [gh#7672](https://github.com/nats-io/nats-server/discussions/7672) | config | |
| 30 | Message scheduler vs NAK-with-delay for scheduled work at scale — which one? | jetstream | [gh#7628](https://github.com/nats-io/nats-server/discussions/7628) | pattern | |
| 31 | How does JetStream filestore compression work and what does it cost? | jetstream | [gh#5259](https://github.com/nats-io/nats-server/discussions/5259) | sizing internals | [[stream-compression]] · [[jetstream-sizing]] |
| 32 | How do I back up and restore JetStream, including memory streams? | jetstream | [gh#4342](https://github.com/nats-io/nats-server/discussions/4342) | ★ runbook | [[backup-and-restore-jetstream]] · [[disaster-recovery]] |
| 33 | Can I change the replica count of a live stream, and why does it fail with "no suitable peers for placement"? | jetstream topology | [gh#7982](https://github.com/nats-io/nats-server/discussions/7982) | ★ gotcha | [[stream-placement]] · [[replicas]] · [[no-suitable-peers-for-placement]] |
| 34 | How do I rebalance streams after adding nodes to a cluster? | topology | [gh#7215](https://github.com/nats-io/nats-server/discussions/7215) | ★ runbook | [[rebalance-streams]] |
| 35 | How do I move a stream to a different set of peers? | topology | [gh#2730](https://github.com/nats-io/nats-server/discussions/2730) | runbook | [[stream-placement]] |
| 36 | Why does the cluster report no quorum and stall on JetStream consumers? | topology | [gh#3210](https://github.com/nats-io/nats-server/discussions/3210) | ★ gotcha | [[raft-in-nats]] · [[disaster-recovery]] |
| 37 | What causes unexpected quorum loss after days of stable operation? | topology | [gh#7533](https://github.com/nats-io/nats-server/discussions/7533) | gotcha | |
| 38 | Why were my streams marked orphan and deleted when converting a standalone server into a cluster? | topology | [gh#7831](https://github.com/nats-io/nats-server/discussions/7831) | ★ gotcha | [[streams-deleted-when-clustering-a-standalone-server]] |
| 39 | How do I find out what corrupted a JetStream cluster, and how do I recover it? | topology | [gh#7463](https://github.com/nats-io/nats-server/discussions/7463) | ★ gotcha runbook | [[malformed-or-corrupt-message]] |
| 40 | How do I evict a sick-but-not-dead node (and its clients) from a cluster during a hardware failure? | topology | [gh#6892](https://github.com/nats-io/nats-server/discussions/6892) | runbook | |
| 41 | Leafnode, gateway or cluster — when do I use which? | topology | [gh#6328](https://github.com/nats-io/nats-server/discussions/6328) | ★ concept | [[choosing-a-topology]] · [[leafnode]] · [[gateway]] |
| 42 | Why aren't my streams visible on both ends of a leafnode connection? | topology | [gh#7834](https://github.com/nats-io/nats-server/discussions/7834) | ★ gotcha | [[streams-not-visible-across-a-leafnode]] |
| 43 | How do I set up cross-domain JetStream sourcing? | topology | [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) | runbook | [[cross-domain-sourcing]] · [[jetstream-domain]] |
| 44 | Why do I get duplicate messages on a leafnode cluster connected to a supercluster? | topology | [gh#4823](https://github.com/nats-io/nats-server/discussions/4823) | gotcha | [[duplicate-messages-across-a-leafnode]] |
| 45 | How do I get multi-region availability without paying for cross-region latency? | topology | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | ★ pattern | [[multi-region-jetstream]] · [[choosing-a-topology]] |
| 46 | What causes performance degradation in a global supercluster? | topology | [gh#7494](https://github.com/nats-io/nats-server/discussions/7494) | gotcha | [[supercluster-slows-when-a-remote-subscriber-joins]] · [[gateway]] |
| 47 | Why does an asymmetric cluster configuration fail to form? | topology | [gh#7190](https://github.com/nats-io/nats-server/discussions/7190) | gotcha | [[build-a-3-node-cluster]] · [[monitoring-endpoints]] |
| 48 | How do I restrict which subjects a leafnode exports and imports? | topology security | [gh#5941](https://github.com/nats-io/nats-server/discussions/5941) | config | [[leafnode]] · [[cross-account-sharing]] |
| 49 | How do I set up operator / account / user JWTs correctly? | security | [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) | ★ runbook | [[set-up-operator-mode]] · [[operator-mode]] |
| 50 | How do I rotate TLS certificates without downtime, and how do I detect expiry? | security | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | ★ runbook | [[rotate-tls-certificates]] · [[tls-in-nats]] |
| 51 | How do I share a stream or KV bucket between accounts? | security jetstream | [gh#7017](https://github.com/nats-io/nats-server/discussions/7017) | ★ config | [[cross-account-sharing]] · [[mirrors-and-sources]] |
| 52 | How do I prevent a user from creating durable consumers or exceeding account limits? | security | [gh#5044](https://github.com/nats-io/nats-server/discussions/5044) | config | [[subject-permissions]] · [[account]] |
| 53 | When should I use auth callout, and what does the server validate before calling it? | security | [gh#7505](https://github.com/nats-io/nats-server/discussions/7505) | concept | [[auth-callout]] |
| 54 | How do I add accounts and reload a running cluster without dropping clients? | security deploy | [gh#5890](https://github.com/nats-io/nats-server/discussions/5890) | ★ runbook | [[reload-server-config]] · [[account]] |
| 55 | Which configuration changes actually take effect on reload, and which need a restart? | deploy | [gh#7126](https://github.com/nats-io/nats-server/discussions/7126) | ★ config gotcha | [[reload-server-config]] · [[config-keys]] |
| 56 | How do I deny unauthenticated connections without breaking system users? | security | [gh#4535](https://github.com/nats-io/nats-server/discussions/4535) | gotcha | [[unauthenticated-clients-still-connect]] · [[account]] |
| 57 | Which endpoints and metrics should I actually alert on for a JetStream cluster? | monitoring | [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) | ★ runbook | [[monitoring-endpoints]] · [[advisories]] |
| 58 | How do I find which consumer the server has flagged as slow? | monitoring | [gh#6605](https://github.com/nats-io/nats-server/discussions/6605) | ★ gotcha | [[slow-consumer-detected]] · [[monitoring-endpoints]] |
| 59 | Are there metrics for acked, naked, terminated and redelivered messages? | monitoring jetstream | [gh#6962](https://github.com/nats-io/nats-server/discussions/6962) | monitoring | [[advisories]] · [[consumer]] |
| 60 | How is CPU % in /varz measured, and why does it look wrong in containers? | monitoring | [gh#7483](https://github.com/nats-io/nats-server/discussions/7483) | gotcha | |
| 61 | How are the RTT values in /routez and /connz measured? | monitoring | [gh#7362](https://github.com/nats-io/nats-server/discussions/7362) | monitoring | |
| 62 | How do I read and act on JetStream warnings in the server log? | monitoring jetstream | [gh#6490](https://github.com/nats-io/nats-server/discussions/6490) | ★ gotcha | [[stream-has-high-message-lag]] |
| 63 | How do I roll a cluster onto a new server version safely? | deploy | [gh#3778](https://github.com/nats-io/nats-server/discussions/3778) | ★ runbook | [[upgrade-a-cluster]] |
| 64 | What are the data-integrity risks when upgrading across minor versions? | deploy | [gh#4781](https://github.com/nats-io/nats-server/discussions/4781) | ★ runbook | [[upgrade-a-cluster]] |
| 65 | Should JetStream use hostPath or a PVC on Kubernetes? | deploy | [gh#7749](https://github.com/nats-io/nats-server/discussions/7749) | ★ config | [[kubernetes-storage]] |
| 66 | How do I grow the JetStream volume on Kubernetes? | deploy | [gh#6601](https://github.com/nats-io/nats-server/discussions/6601) | gotcha runbook | |
| 67 | LoadBalancer or seed URLs — how should clients reach a cluster on Kubernetes? | deploy clients | [gh#6094](https://github.com/nats-io/nats-server/discussions/6094) | pattern | [[how-clients-reach-a-cluster]] |
| 68 | Why did throughput drop after moving from Kubernetes to a standalone VM (or back)? | deploy | [gh#6594](https://github.com/nats-io/nats-server/discussions/6594) | sizing gotcha | |
| 69 | How do I watch many KV keys at once without creating a watcher for each one? | kv | [gh#6746](https://github.com/nats-io/nats-server/discussions/6746) | ★ gotcha | [[key-value]] · [[kv-watchers-stall-the-cluster]] |
| 70 | How do I count the keys in a KV bucket without fetching them all? | kv | [gh#7365](https://github.com/nats-io/nats-server/discussions/7365) | gotcha | [[key-value]] |
| 71 | Does KV support a TTL per key, and since which version? | kv | [gh#7264](https://github.com/nats-io/nats-server/discussions/7264) | config | [[message-ttl]] · [[key-value]] |
| 72 | Why doesn't deleting or purging keys reclaim disk space in a bucket? | kv | [gh#6015](https://github.com/nats-io/nats-server/discussions/6015) | ★ gotcha | [[key-value]] · [[filestore-layout]] |
| 73 | When is KV or Object Store the wrong tool — where does Redis or a database win? | kv objectstore | [so#75576454](https://stackoverflow.com/questions/75576454/nats-object-store-or-key-value-store-vs-redis-cache) | concept | [[key-value]] |
| 74 | How do I implement a distributed lock or lease with KV? | kv | [so#79400839](https://stackoverflow.com/questions/79400839/how-to-use-nats-kv-for-distributed-locking) | pattern | [[key-value]] |
| 75 | Why is listing an object-store bucket slow (or timing out) while uploads run? | objectstore | [gh#6836](https://github.com/nats-io/nats-server/discussions/6836) | gotcha | |
| 76 | Why is a KV mirror on file storage far slower than on memory storage? | kv | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) | gotcha internals | |
| 77 | What does an unexpected `nats: timeout` actually mean, and how do I trace it? | core | [gh#5859](https://github.com/nats-io/nats-server/discussions/5859) | ★ gotcha | [[nats-timeout]] |
| 78 | How many WebSocket connections can a single server sustain? | interop | [gh#2770](https://github.com/nats-io/nats-server/discussions/2770) | sizing | |
| 79 | How do I run NATS WebSocket behind nginx or another proxy? | interop deploy | [gh#7375](https://github.com/nats-io/nats-server/discussions/7375) | runbook | |
| 80 | How does MQTT QoS 1/2 map onto JetStream, and what does it cost? | interop | [gh#7641](https://github.com/nats-io/nats-server/discussions/7641) | concept | |
| 81 | How do I restrict MQTT client ids per account with JWT? | interop security | [gh#7397](https://github.com/nats-io/nats-server/discussions/7397) | config | |
| 82 | How do I track client connect and disconnect events? | monitoring core | [gh#6445](https://github.com/nats-io/nats-server/discussions/6445) | runbook | [[advisories]] |
| 83 | How do I get consumer pending metrics out of nats-surveyor or the Prometheus exporter, and what are the series called? | monitoring jetstream | [gh#3857](https://github.com/nats-io/nats-server/discussions/3857) | monitoring | [[prometheus-nats-exporter]] · [[nats-surveyor]] |
| 84 | Exporter or surveyor — which do I run for cluster-level alerts, and what does each need? | monitoring topology | [gh#6145](https://github.com/nats-io/nats-server/discussions/6145) | monitoring runbook | [[nats-surveyor]] · [[prometheus-nats-exporter]] |
| 85 | What is the ideal way to set metrics up at all — exporter, surveyor, Prometheus, Grafana, checks? | monitoring | [gh#6224](https://github.com/nats-io/nats-server/discussions/6224) | monitoring runbook | [[prometheus-nats-exporter]] · [[nats-surveyor]] · [[monitoring-endpoints]] |
| 86 | Are partitioned consumer groups a server feature, or a client-side construct? | jetstream clients | [gh#7296](https://github.com/nats-io/nats-server/discussions/7296) | concept clients | [[orbit]] |
| 87 | The Orbit docs show `orbit.go` — is the same module available for my language (C#, Java, Python…)? | clients | [gh#7296](https://github.com/nats-io/nats-server/discussions/7296) | clients | [[orbit]] |
| 88 | Are there trade-offs to turning on `allow_direct` for a stream? | jetstream | [gh#3984](https://github.com/nats-io/nats-server/discussions/3984) | config | [[direct-get]] |
| 89 | How do I set up cross-domain JetStream sourcing or mirroring? | jetstream topology security | [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) | ★ config runbook | [[cross-domain-sourcing]] |
| 90 | How do I manage streams and KV buckets across several accounts with one user? | security jetstream | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | config | [[cross-account-sharing]] |
| 91 | Why does mirror catch-up slow down when a consumer reads the mirror at the same time? | jetstream | [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) | gotcha internals | |
| 92 | What does `attempted to connect to route port` in the server log mean? | topology core | [gh#3569](https://github.com/nats-io/nats-server/discussions/3569) | gotcha config | [[build-a-3-node-cluster]] |
| 93 | Why doesn't lame-duck mode shut the server down gracefully under systemd? | deploy | [gh#6070](https://github.com/nats-io/nats-server/discussions/6070) | ★ runbook gotcha | [[install-nats-server]] · [[upgrade-a-cluster]] |
| 94 | Why does `openssl s_client` return nothing against the NATS TLS port? | security monitoring | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | gotcha | [[tls-in-nats]] · [[rotate-tls-certificates]] |
| 95 | Why does `nsc push` / `nats auth account push` time out with nothing in the server log? | security | [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) | gotcha runbook | [[set-up-operator-mode]] · [[nsc]] |
| 96 | Can I enable JetStream on the system account to manage all tenants from one place? | security jetstream | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | config | [[cross-account-sharing]] |
| 97 | Does a config reload actually pick up a renewed certificate file, or do I need a restart? | security deploy | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | ★ gotcha | [[rotate-tls-certificates]] · [[reload-server-config]] |
| 98 | Is there a limit on how many accounts one account can import from? | security topology | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | sizing | |
| 99 | What happens when JetStream runs out of disk, and why does `insufficient storage resources available (10047)` appear on an almost empty volume? | jetstream deploy | [issue#4281](https://github.com/nats-io/nats-server/issues/4281) | ★ gotcha sizing | [[jetstream-out-of-disk]] |
| 100 | Why does the auto-sized `max_file_store` get smaller every time the server restarts? | jetstream deploy | [issue#8322](https://github.com/nats-io/nats-server/issues/8322) | ★ gotcha config | [[jetstream-out-of-disk]] · [[config-keys]] |
| 101 | Why does a cluster stop recovering when a thousand clients each open a KV watcher? | kv topology | [gh#5243](https://github.com/nats-io/nats-server/discussions/5243) | ★ gotcha sizing | [[kv-watchers-stall-the-cluster]] |
| 102 | Does a leafnode need its own JetStream domain, and what does setting one actually change? | jetstream topology | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | concept config | [[jetstream-domain]] |
| 103 | Can a leaf region later become the hub, or a regular cluster be converted into a leaf cluster without losing data? | topology deploy | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | ★ concept no-public-answer | **nobody has published an answer** — scouted 2026-08-31 across the docs, ADRs, GitHub and blogs; the two questions in the thread were never replied to. The finding is stated on [[choosing-a-topology]] |
| 104 | Why does `nats-server -t` accept a config the server then refuses to start? | deploy | [learn/topologies/putting-it-together](https://docs.nats.io/learn/topologies/putting-it-together) | gotcha config | [[reload-server-config]] · [[build-a-3-node-cluster]] |

## Thread titles behind the rows

The exact title of the linked thread, so a row can be checked against its source.

1. [gh#6879](https://github.com/nats-io/nats-server/discussions/6879) — Jetstream in Kubernetes Storage Size
2. [gh#5742](https://github.com/nats-io/nats-server/discussions/5742) — Jetstream file storage internals
3. [gh#4227](https://github.com/nats-io/nats-server/discussions/4227) — How to config a single nats-server with jetstream in most resource-effective way
4. [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) — Is jetstream message count capped at 1 billion for a single stream?
5. [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) — Maximum known-good value for `MaxMsgs` in a JetStream stream
6. [gh#7863](https://github.com/nats-io/nats-server/discussions/7863) — Maximum number of consumers
7. [gh#6274](https://github.com/nats-io/nats-server/discussions/6274) — Jetstreams publisher perfomance decreases rapidly with large number of parallel consumers. Publisher throughput decreases by 50 times for 100 consumers
8. [gh#7599](https://github.com/nats-io/nats-server/discussions/7599) — JetStream async publish throughput much lower than documentation example (400k vs 130k msgs/sec)
9. [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) — Is there performance issues possible with a high cardinality subjects for a stream?
10. [gh#6820](https://github.com/nats-io/nats-server/discussions/6820) — Why increasing of "Unprocessing Messages" leads to increasing nats memory usage?
11. [gh#7738](https://github.com/nats-io/nats-server/discussions/7738) — Hot scaling core NATS (no JetStream) for bursty traffic — patterns and operator experience ?
12. [gh#7068](https://github.com/nats-io/nats-server/discussions/7068) — max_payload - issues if we increate it to more than 8MB
13. [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) — JetStream startup seems slow for ~50M messages
14. [so#78603662](https://stackoverflow.com/questions/78603662/nats-jetstream-messages-being-processed-multiple-times-by-my-consumer-even-when) — NATS JetStream messages being processed multiple times by my consumer even when messages are acknowledged
15. [gh#5211](https://github.com/nats-io/nats-server/discussions/5211) — Max Ack Pending per Subject?
16. [gh#6628](https://github.com/nats-io/nats-server/discussions/6628) — ack-wait and dupe-window behavior when used together
17. [gh#6350](https://github.com/nats-io/nats-server/discussions/6350) — Does NATS support exponential backoff consumption retry？
18. [gh#5631](https://github.com/nats-io/nats-server/discussions/5631) — Nak does not immediately lead to a message redelivery
19. [gh#4972](https://github.com/nats-io/nats-server/discussions/4972) — Doesn't NakWithDelay reduce the MaxAckPending counter and block the execution of other messages?
20. [gh#6044](https://github.com/nats-io/nats-server/discussions/6044) — What Happens When multiple Consumers share a same durable Name with different topic Filter in WorkQueue Jetstream?
21. [gh#3637](https://github.com/nats-io/nats-server/discussions/3637) — WorkQueuePolicy - understand "disjoint filter subjects"
22. [gh#4778](https://github.com/nats-io/nats-server/discussions/4778) — jetstream newbie questions: How do I inspect the contents of a workqueue stream to see what all messages are pending?
23. [so#72814502](https://stackoverflow.com/questions/72814502/nats-jetstream-exactly-once-delivery) — Nats Jetstream Exactly Once Delivery
24. [so#68984906](https://stackoverflow.com/questions/68984906/does-nats-jetstream-provide-message-ordering-by-a-key) — Does NATS Jetstream provide message ordering by a key?
25. [gh#7577](https://github.com/nats-io/nats-server/discussions/7577) — Message ordering guarantees in core NATS
26. [gh#5924](https://github.com/nats-io/nats-server/discussions/5924) — JetStream failed to store a msg on stream '$G > : error opening msg block file [""]: open : no such file or directory
27. [gh#2794](https://github.com/nats-io/nats-server/discussions/2794) — how to recover from DiscardNew policy?
28. [gh#7227](https://github.com/nats-io/nats-server/discussions/7227) — How does SubjectDeleteMarkerTTL work?
29. [gh#7672](https://github.com/nats-io/nats-server/discussions/7672) — Cron schedule supports ?
30. [gh#7628](https://github.com/nats-io/nats-server/discussions/7628) — Message Scheduler vs NAK-with-delay for scheduled notifications at scale (PS: Slack Invite broken?)
31. [gh#5259](https://github.com/nats-io/nats-server/discussions/5259) — How does compression work?
32. [gh#4342](https://github.com/nats-io/nats-server/discussions/4342) — Backup data in nats-server with jetstream enabled where storage is memory
33. [gh#7982](https://github.com/nats-io/nats-server/discussions/7982) — Unable to increase stream replicas from `1` to `3` due to `no suitable peers for placement (10005)`
34. [gh#7215](https://github.com/nats-io/nats-server/discussions/7215) — How to rebalance jetstream streams after increasing cluster replicas
35. [gh#2730](https://github.com/nats-io/nats-server/discussions/2730) — What are strategies for moving a stream to a different set of nodes in the cluster?
36. [gh#3210](https://github.com/nats-io/nats-server/discussions/3210) — has NO quorum, stalled on jetstream consumers
37. [gh#7533](https://github.com/nats-io/nats-server/discussions/7533) — Unexpected JetStream Quorum Loss and MQTT Session Errors After Several Days of Stable Operation
38. [gh#7831](https://github.com/nats-io/nats-server/discussions/7831) — Streams marked orphan and deleted when converting standalone to cluster
39. [gh#7463](https://github.com/nats-io/nats-server/discussions/7463) — How to find out what caused a corruption in JetStream Cluster?
40. [gh#6892](https://github.com/nats-io/nats-server/discussions/6892) — How to Handle System Failures Caused by Hardware Issues in NATS Clusters
41. [gh#6328](https://github.com/nats-io/nats-server/discussions/6328) — Is non-clustered JetStream possible with Gateways?
42. [gh#7834](https://github.com/nats-io/nats-server/discussions/7834) — JetStream on cluster should be shared with leafnode, all using TLS. But streams aren't visible on both ends
43. [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) — Cross-domain JetStream sourcing, how do I set that up?
44. [gh#4823](https://github.com/nats-io/nats-server/discussions/4823) — Duplicate messages on a leafnode cluster connected to a supercluster.
45. [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) — Multi-Region Without Sacrificing Availability
46. [gh#7494](https://github.com/nats-io/nats-server/discussions/7494) — Performance degradation in a global NATS super-cluster
47. [gh#7190](https://github.com/nats-io/nats-server/discussions/7190) — Asymmetric Cluster Formation Problem
48. [gh#5941](https://github.com/nats-io/nats-server/discussions/5941) — Proper way to configure Leaf Nodes to only export some subjects
49. [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) — Example JWT setup from the docs is not working.. at all.
50. [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) — How to detect when the certificates used by nats-server will expire?
51. [gh#7017](https://github.com/nats-io/nats-server/discussions/7017) — Sharing a KV Store with Multiple Accounts – Is It Supported?
52. [gh#5044](https://github.com/nats-io/nats-server/discussions/5044) — Prevent a NATS user from creating durable consumers
53. [gh#7505](https://github.com/nats-io/nats-server/discussions/7505) — Does NATS validate `connect_opts.nkey` before passing it to auth callout?
54. [gh#5890](https://github.com/nats-io/nats-server/discussions/5890) — Accounts - Best way to add new accounts and reload running servers in a cluster
55. [gh#7126](https://github.com/nats-io/nats-server/discussions/7126) — it seems than reload doesn't work for changing listening ip address.
56. [gh#4535](https://github.com/nats-io/nats-server/discussions/4535) — Issue with denying unauthenticated connections
57. [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) — Setting Up Monitoring and Alerts for NATS Cluster with Prometheus Metrics
58. [gh#6605](https://github.com/nats-io/nats-server/discussions/6605) — How to find which consumer has been detected as slow?
59. [gh#6962](https://github.com/nats-io/nats-server/discussions/6962) — Metric count of messages Ack'ed / Term'ed / Nak'ed
60. [gh#7483](https://github.com/nats-io/nats-server/discussions/7483) — Clarification on CPU % in VARZ for NATS running on AWS Fargate
61. [gh#7362](https://github.com/nats-io/nats-server/discussions/7362) — How are NATS routez/connz rtt measured?
62. [gh#6490](https://github.com/nats-io/nats-server/discussions/6490) — Understanding jetstream warnings
63. [gh#3778](https://github.com/nats-io/nats-server/discussions/3778) — How to easily and elegantly roll-up nats-server instances to the latest version within a cluster
64. [gh#4781](https://github.com/nats-io/nats-server/discussions/4781) — Cluster 2.10.x upgrade and data integrity
65. [gh#7749](https://github.com/nats-io/nats-server/discussions/7749) — Should we use hostPath for jetstream cluster running in K8S
66. [gh#6601](https://github.com/nats-io/nats-server/discussions/6601) — Increasing disk size through helm throws "Forbidden Updating resource except replica"
67. [gh#6094](https://github.com/nats-io/nats-server/discussions/6094) — Accessing NATS on Kubernetes: LoadBalancer vs Seed URL for Failover
68. [gh#6594](https://github.com/nats-io/nats-server/discussions/6594) — Loss in Throughput after migrating to standalone Nats VM from K8s
69. [gh#6746](https://github.com/nats-io/nats-server/discussions/6746) — Watch different keys without creating a watcher for each key?
70. [gh#7365](https://github.com/nats-io/nats-server/discussions/7365) — How to get count of keys from Key/Value store without retrieving them all?
71. [gh#7264](https://github.com/nats-io/nats-server/discussions/7264) — Key Value with TTL
72. [gh#6015](https://github.com/nats-io/nats-server/discussions/6015) — Remove deleted/purged data from bucket not possible?
73. [so#75576454](https://stackoverflow.com/questions/75576454/nats-object-store-or-key-value-store-vs-redis-cache) — NATS Object Store or Key Value Store vs Redis Cache
74. [so#79400839](https://stackoverflow.com/questions/79400839/how-to-use-nats-kv-for-distributed-locking) — How to use NATS KV for distributed locking
75. [gh#6836](https://github.com/nats-io/nats-server/discussions/6836) — Nats object store list in a bucket slow, sometimes timeout, when there is uploading file process
76. [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) — JetStream file-store ~65x slower than memory-store on KV mirror (83% of seq space is deleted)
77. [gh#5859](https://github.com/nats-io/nats-server/discussions/5859) — Symptom: Unexpected `nats: timeout`
78. [gh#2770](https://github.com/nats-io/nats-server/discussions/2770) — Max Number of WebSocket Connections that a Single Nats Server can Sustain Reliably
79. [gh#7375](https://github.com/nats-io/nats-server/discussions/7375) — How to deply nats behind nginx when using websocket?
80. [gh#7641](https://github.com/nats-io/nats-server/discussions/7641) — [Question] how to publish with MQTT QOS 1/2
81. [gh#7397](https://github.com/nats-io/nats-server/discussions/7397) — MQTT: Only allow specific client ids via JWT/NSC?
82. [gh#6445](https://github.com/nats-io/nats-server/discussions/6445) — Recording Connection & Disconnection events.
83. [gh#3857](https://github.com/nats-io/nats-server/discussions/3857) — Can anyone tell me how to get information about consumer pending metrics on  nats-surveyor or prometheus-nats-exporter
84. [gh#6145](https://github.com/nats-io/nats-server/discussions/6145) — Configuring NATS Monitoring: Cluster-Level Alerts with Prometheus Exporter
85. [gh#6224](https://github.com/nats-io/nats-server/discussions/6224) — Ideal way to set up metrics
86–87. [gh#7296](https://github.com/nats-io/nats-server/discussions/7296) — Are Client-side Partitioned Consumer Groups equivilent to Pulsar Key-Shared subscriptions? One thread, two questions: the body asks whether the mechanism is client- or server-side, and closes with "the blog mentions Orbit.go, is this supported for C# libraries as well".

All three metrics threads (83–85) are **Q&A discussions with no accepted answer** as of 2026-08-31,
which is why they are worth answering here.
88. [gh#3984](https://github.com/nats-io/nats-server/discussions/3984) — Are there tradeoffs with `AllowDirect: true`?
89. [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) — Cross-domain JetStream sourcing, how do I set that up?
90. [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) — Manage streams / KVs across multiplea accounts with one user
91. [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) — Mirror Stream sync is ~2.9× slower when a Consumer cold-scans the mirror during catch-up
92. [gh#3569](https://github.com/nats-io/nats-server/discussions/3569) — ERR Log "attempted to connect to route port"
93. [gh#6070](https://github.com/nats-io/nats-server/discussions/6070) — Lame Duck Mode
94. [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) — How to detect when the certificates used by nats-server will expire? *(sub-question in the accepted answer)*
95. [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) — Example JWT setup from the docs is not working.. at all.
96. [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) — Manage streams / KVs across multiplea accounts with one user *(sub-question: `[FTL] Not allowed to enable JetStream on the system account`)*
97. [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) — same thread, opening report: "the Let's Encrypt certificate was renewed correctly, but `nats-server --signal reload=1` failed to reload the certificate"
98. [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) — same thread: "is there a theoretical maximum number of imports for a single account?" 
99. [issue#4281](https://github.com/nats-io/nats-server/issues/4281) — nats: error: could not create Stream: insufficient storage resources available (10047)
100. [issue#8322](https://github.com/nats-io/nats-server/issues/8322) — JetStream dynamic MaxStore shrinks after restart because it is recomputed from current free disk (Bavail), causing previously valid stream limits to fail
101. [gh#5243](https://github.com/nats-io/nats-server/discussions/5243) — 1000 nats cli watchers leads to unrecoverable state of servers.
102. [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) — Multi-Region Without Sacrificing Availability (the JS-domain half of the maintainer's answer)
103. [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) — Multi-Region Without Sacrificing Availability (the asker's two follow-ups, **both unanswered**)
104. [learn/topologies/putting-it-together](https://docs.nats.io/learn/topologies/putting-it-together) — the chapter's composed config, which `-t` accepts and the server rejects (`inbox/docs-issues.md` #24). Not a thread: mined from the docs while writing the topology pages, and reproduced.

**Row 89 was closed in the topology pass, row 91 stays open.** [[cross-domain-sourcing]] now gives
the procedure for the **same-account, two-domain** case end to end, because the `nats` CLI builds it
(`$JS.<domain>.API` composed for you, delivery prefix optional) and the server validates it — see
[[s-natscli-stream-external]]. The **cross-account** half of the same runbook is written as far as
the sources go and stops there: the export and import entries that authorise it are stated by no
public source, and the page says so in its `## To verify` rather than inventing them. That residual
gap is what row 51 tracks. Row 91 is untouched — nothing read explains mirror catch-up contention.

**Row 103 is new and deliberately unanswered.** The asker of
[gh#7438](https://github.com/nats-io/nats-server/discussions/7438) asked twice whether a leaf region
can later become the hub, and whether a regular cluster can be converted into a leaf cluster without
losing data — "This is the information I find missing from the docs / videos, i.e. the cons of each
architecture." **Neither question has been answered**, and the docs' claim that every topology layer
"is reversible: the layer below never changed" is about routes and gateways, not about JetStream
state. [[choosing-a-topology]] and [[multi-region-jetstream]] both record the silence and tell the
reader to treat the choice of hub as hard to reverse. Filling this row would take a maintainer
answer or an experiment this wiki has not run.

**Row 51 stays open after the security pass, deliberately.** [[cross-account-sharing]] states both
routes to a stream or KV bucket in another account — importing the owning account's `$JS.API.>` as a
service export, and mirroring or sourcing with an `external` block — and names the fields from the
server source. What no public source gives is the **configuration**: the exact export and import
entries, and whether the export can be narrowed below the account's whole JetStream API. The thread
it was mined from ([gh#7017](https://github.com/nats-io/nats-server/discussions/7017)) has had **no
reply since 2025-06-29**, and the fields appear nowhere in the docs (`inbox/docs-issues.md` #21).
Marking it answered would be the kind of "a page touches the topic" claim this bank exists to
prevent.

**Rows 97 and 98 are new and open.** 97 is a reported reload failure nobody diagnosed — the server's
reload path looks sound on inspection, so [[rotate-tls-certificates]] carries it as `(unverified)`
rather than either confirming or dismissing it. 98 was asked in public and never answered; this wiki
states no number.

**Row 52 is answered with its limit stated.** [[subject-permissions]] gives the subject-level lever
and then says plainly why it cannot separate a durable consumer from an ephemeral one — the durable
name is in the request payload — and points at per-account limits as the enforceable control. That is
the answer; there is no cleaner one in public.

**Rows 26 and 69 were corrected, not filled.** Both were mined from thread *titles* and both titles
mislead. gh#5924 is titled around an "out of disk"-shaped error and is actually about filestore
directories being reaped off a tmpfs `store_dir`, so row 26 now asks that and the genuine
out-of-disk question moved to new rows **99** and **100**, sourced to the two GitHub *issues* that
ask it. gh#6746 asks how to watch several KV keys on one watcher and says nothing about missed
updates, so row 69 lost the "why does my watcher miss updates" half — a search of
`nats-io/nats-server` discussions on 2026-08-31 found **nobody publicly reporting a missed KV
update**, so no row was invented for it and the wanted page `kv-watcher-misses-updates` was retired
(see [[key-value]] → *To verify*).

**Rows 99–101 are new and answered by the pages they produced.** 99 and 100 come from
`nats-io/nats-server` **issues** rather than discussions — the first `gh-issues` sources this wiki
has taken — because the question "what happens when JetStream runs out of disk" is asked there and
nowhere in the discussion tree. Issue #4281 is **still open**, so [[jetstream-out-of-disk]] states
the mechanism and then says which case nobody has explained. 101 is [[kv-watchers-stall-the-cluster]],
a page with **no confirmed fix**: the thread is unanswered, and the page says so in its first
paragraph.

**Row 62 is answered with a caveat worth stating.** The thread asks a broad question ("how do I read
JetStream warnings") and got a narrow answer about one warning.
[[stream-has-high-message-lag]] answers the narrow case from the maintainer's reply and then carries
a table of the **thirteen** neighbouring JetStream warnings read from `nats-server` v2.14.6, each
with what it measures — which is the general answer, built from the server rather than claimed from
the thread. The first reporter's own question, why it happened under no load and why only a restart
cleared it, remains **unanswered upstream** and the page says so.
