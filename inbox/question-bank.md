# Question bank — what this wiki must answer

The map and the scoreboard. Every row is a question a solution architect, designer or operator
asks — either **asked in public**, with a link to where, or **posed here** because the reader would
ask it (`own` in *asked at*). A row is *answered* only when a page states the answer with a citation
and a version — not when a page merely touches the topic.

- `★` marks the questions that must be answerable for the wiki to be useful at all.
- `design` marks a solution-architecture question, written with its trade-off in the question
  rather than as a symptom; `kind: pattern` pages answer these.
- `no-public-answer` marks a row this wiki searched for and could not answer from public sources.
  Its `answered by` cell names the page that says so, in bold — a stated dead end is an answer; an
  empty cell is unfinished work.
- `answered by` holds `[[wikilinks]]`; the viewer counts filled rows as "ingested" and the
  filters at the top let you see what is still open.
- Add rows whenever a query, an ingest, a thread or a design session reveals a question the bank
  does not cover. Give the URL when someone asked it in public; write `own` when the maintainer or
  the user posed it, and replace `own` with a URL when one turns up. Until 2026-09-02 a row without
  a URL was not allowed; that rule was retired (`CLAUDE.md`, *The question bank*).

Seeded 2026-08-31 by mining `nats-io/nats-server` GitHub Discussions (484 threads read by title,
Q&A and General categories) and the Stack Overflow `nats-jetstream` / `nats.io` / `nats-server`
tags. Sources for each row are in the *asked at* column. The mining script and method are
described in `inbox/plan-first-ingests-2026-08-31.md`.

| # | question | area | asked at | flags | answered by |
|---|---|---|---|---|---|
| 1 | How do I size a 3-node R3 JetStream cluster (disk, RAM, IOPS) for a given message rate, size and retention? | jetstream deploy | [gh#6879](https://github.com/nats-io/nats-server/discussions/6879) | ★ sizing | [[jetstream-sizing]] · [[filestore-layout]] |
| 2 | How much disk does a stream actually use beyond the raw message bytes (blocks, index, per-subject state)? | jetstream | [gh#5742](https://github.com/nats-io/nats-server/discussions/5742) | ★ sizing internals | [[filestore-layout]] · [[jetstream-sizing]] |
| 3 | What does a stream actually cost in resources, and how do I run JetStream in the most resource-effective way? | jetstream | [gh#4227](https://github.com/nats-io/nats-server/discussions/4227) | ★ sizing | [[jetstream-sizing]] |
| 4 | Is there a practical cap on the number of messages in a single stream? | jetstream | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) | sizing measured | [[stream]] · [[jetstream-sizing]] |
| 5 | What is the largest known-good value for MaxMsgs on a stream? | jetstream | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) | sizing config | [[stream]] · [[jetstream-sizing]] · [[retention-policies]] |
| 6 | How many consumers can one stream and one server support before it hurts? | jetstream | [gh#7863](https://github.com/nats-io/nats-server/discussions/7863) | ★ sizing | [[jetstream-slows-as-consumers-grow]] · [[jetstream-sizing]] |
| 7 | Why does publisher throughput collapse when many consumers attach to the stream? | jetstream | [gh#6274](https://github.com/nats-io/nats-server/discussions/6274) | ★ sizing gotcha | [[jetstream-slows-as-consumers-grow]] |
| 8 | Why is my async publish throughput far below the numbers in the docs? | jetstream | [gh#7599](https://github.com/nats-io/nats-server/discussions/7599) | sizing gotcha | |
| 9 | Does a high-cardinality subject space hurt stream performance? | jetstream | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) | sizing measured | [[jetstream-sizing]] · [[filestore-layout]] · [[jetstream-recovery-is-slow]] |
| 10 | Why does server memory grow with the number of unacknowledged (pending) messages? | core jetstream | [gh#6820](https://github.com/nats-io/nats-server/discussions/6820) | sizing gotcha | |
| 11 | How do I scale core NATS for bursty traffic — bigger nodes, more nodes, or partitioning? | core topology | [gh#7738](https://github.com/nats-io/nats-server/discussions/7738) | sizing | |
| 12 | What breaks if I raise max_payload above 8MB, and what is the real limit? | core | [gh#7068](https://github.com/nats-io/nats-server/discussions/7068) | ★ config sizing | [[jetstream-sizing]] · [[defaults-and-limits]] |
| 13 | Why is JetStream startup and recovery slow with tens of millions of messages? | jetstream | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) | gotcha sizing measured | [[jetstream-recovery-is-slow]] · [[mirrors-and-sources]] · [[filestore-layout]] |
| 14 | Why does my consumer keep redelivering messages that were acknowledged? | jetstream | [so#78603662](https://stackoverflow.com/questions/78603662/nats-jetstream-messages-being-processed-multiple-times-by-my-consumer-even-when) | ★ gotcha | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] |
| 15 | What does max_ack_pending actually do, and what happens when it is reached? | jetstream | [gh#5211](https://github.com/nats-io/nats-server/discussions/5211) | ★ config gotcha | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[consumer]] · [[worker-pool]] · [[stream-and-consumer-config]] |
| 16 | How do ack_wait and the duplicate window interact? | jetstream | [gh#6628](https://github.com/nats-io/nats-server/discussions/6628) | gotcha config | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[publishing]] · [[consumer]] · [[stream-and-consumer-config]] |
| 17 | Does JetStream support exponential backoff for redelivery? | jetstream | [gh#6350](https://github.com/nats-io/nats-server/discussions/6350) | config | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[consumer]] · [[stream-and-consumer-config]] |
| 18 | Why doesn't a NAK cause an immediate redelivery? | jetstream | [gh#5631](https://github.com/nats-io/nats-server/discussions/5631) | gotcha measured | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] — *What a delayed nak actually waits*; the reporting thread itself was **never answered** ([[s-gh-5631-nak-not-immediate]]) |
| 19 | Does NakWithDelay hold a max_ack_pending slot and block other messages? | jetstream | [gh#4972](https://github.com/nats-io/nats-server/discussions/4972) | gotcha measured | [[consumer-keeps-redelivering]] · [[ack-and-redelivery]] · [[worker-pool]] · [[jetstream-sizing]] |
| 20 | What happens when several consumers share a durable name with different filter subjects on a WorkQueue stream? | jetstream | [gh#6044](https://github.com/nats-io/nats-server/discussions/6044) | ★ gotcha | [[retention-policies]] |
| 21 | What does "disjoint filter subjects" mean for a WorkQueue stream? | jetstream | [gh#3637](https://github.com/nats-io/nats-server/discussions/3637) | config | [[retention-policies]] · [[stream-and-consumer-config]] |
| 22 | How do I inspect which messages are still pending in a work-queue stream? | jetstream monitoring | [gh#4778](https://github.com/nats-io/nats-server/discussions/4778) | ★ monitoring | [[consumer]] · [[worker-pool]] · [[metrics]] |
| 23 | Does JetStream give exactly-once delivery, and how does the dedup window work? | jetstream | [so#72814502](https://stackoverflow.com/questions/72814502/nats-jetstream-exactly-once-delivery) | ★ concept | [[publishing]] · [[stream]] |
| 24 | What ordering does JetStream guarantee, and per what — stream, subject, key? | jetstream | [so#68984906](https://stackoverflow.com/questions/68984906/does-nats-jetstream-provide-message-ordering-by-a-key) | concept | [[publishing]] · [[stream]] · [[subject-transforms]] |
| 25 | What ordering guarantees does core NATS give? | core | [gh#7577](https://github.com/nats-io/nats-server/discussions/7577) | concept | [[core-nats-delivery]] — *Ordering: per publisher connection, across every subject*, from the maintainers' answer in the thread |
| 26 | Why do stream directories disappear from `store_dir` while `nats stream info` still lists the streams? | jetstream deploy | [gh#5924](https://github.com/nats-io/nats-server/discussions/5924) | ★ gotcha | [[stream-directories-disappear]] · [[jetstream-out-of-disk]] |
| 27 | How do I recover a stream that is full under a DiscardNew policy? | jetstream | [gh#2794](https://github.com/nats-io/nats-server/discussions/2794) | gotcha runbook | [[maximum-messages-exceeded]] · [[retention-policies]] |
| 28 | How do per-message TTLs and subject delete markers behave? | jetstream | [gh#7227](https://github.com/nats-io/nats-server/discussions/7227) | config | [[message-ttl]] · [[stream-and-consumer-config]] |
| 29 | Can the server schedule a message for later, with cron-style patterns? | jetstream | [gh#7672](https://github.com/nats-io/nats-server/discussions/7672) | config measured | [[message-scheduling]] · [[nats-server-2.12]] · [[nats-server-2.14]] |
| 30 | Message scheduler vs NAK-with-delay for scheduled work at scale — which one? | jetstream | [gh#7628](https://github.com/nats-io/nats-server/discussions/7628) | pattern | [[message-scheduling]] · [[ack-and-redelivery]] · [[message-ttl]] |
| 31 | How does JetStream filestore compression work and what does it cost? | jetstream | [gh#5259](https://github.com/nats-io/nats-server/discussions/5259) | sizing internals | [[stream-compression]] · [[jetstream-sizing]] |
| 32 | How do I back up and restore JetStream, including memory streams? | jetstream | [gh#4342](https://github.com/nats-io/nats-server/discussions/4342) | ★ runbook | [[backup-and-restore-jetstream]] · [[disaster-recovery]] · [[stream]] · [[replicas]] · [[upgrade-a-cluster]] |
| 33 | Can I change the replica count of a live stream, and why does it fail with "no suitable peers for placement"? | jetstream topology | [gh#7982](https://github.com/nats-io/nats-server/discussions/7982) | ★ gotcha | [[stream-placement]] · [[replicas]] · [[no-suitable-peers-for-placement]] |
| 34 | How do I rebalance streams after adding nodes to a cluster? | topology | [gh#7215](https://github.com/nats-io/nats-server/discussions/7215) | ★ runbook | [[rebalance-streams]] |
| 35 | How do I move a stream to a different set of peers? | topology | [gh#2730](https://github.com/nats-io/nats-server/discussions/2730) | runbook | [[stream-placement]] · [[rebalance-streams]] · [[replicas]] |
| 36 | Why does the cluster report no quorum and stall on JetStream consumers? | topology | [gh#3210](https://github.com/nats-io/nats-server/discussions/3210) | ★ gotcha | [[raft-in-nats]] · [[disaster-recovery]] · [[meta-layer]] |
| 37 | What causes unexpected quorum loss after days of stable operation? | topology | [gh#7533](https://github.com/nats-io/nats-server/discussions/7533) | gotcha no-public-answer | **[[stream-leader-keeps-moving]]** — the thread had no reply when read 2026-09-01; the page maps every line of its sequence to a verified mechanism and names the one it cannot explain (`wrong last sequence: 0` before the loss) |
| 38 | Why were my streams marked orphan and deleted when converting a standalone server into a cluster? | topology | [gh#7831](https://github.com/nats-io/nats-server/discussions/7831) | ★ gotcha | [[streams-deleted-when-clustering-a-standalone-server]] · [[replicas]] · [[backup-and-restore-jetstream]] · [[meta-layer]] |
| 39 | How do I find out what corrupted a JetStream cluster, and how do I recover it? | topology | [gh#7463](https://github.com/nats-io/nats-server/discussions/7463) | ★ gotcha runbook | [[malformed-or-corrupt-message]] · [[disaster-recovery]] · [[upgrade-a-cluster]] |
| 40 | How do I evict a sick-but-not-dead node (and its clients) from a cluster during a hardware failure? | topology | [gh#6892](https://github.com/nats-io/nats-server/discussions/6892) | runbook observed | [[evict-a-sick-server]] · [[meta-layer]] — assembled from the server source and a run; the thread itself was never answered |
| 41 | Leafnode, gateway or cluster — when do I use which? | topology | [gh#6328](https://github.com/nats-io/nats-server/discussions/6328) | ★ concept | [[choosing-a-topology]] · [[leafnode]] · [[gateway]] · [[key-value]] |
| 42 | Why aren't my streams visible on both ends of a leafnode connection? | topology | [gh#7834](https://github.com/nats-io/nats-server/discussions/7834) | ★ gotcha | [[streams-not-visible-across-a-leafnode]] |
| 43 | How do I set up cross-domain JetStream sourcing? | topology | [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) | runbook | [[cross-domain-sourcing]] · [[jetstream-domain]] |
| 44 | Why do I get duplicate messages on a leafnode cluster connected to a supercluster? | topology | [gh#4823](https://github.com/nats-io/nats-server/discussions/4823) | gotcha | [[duplicate-messages-across-a-leafnode]] |
| 45 | How do I get multi-region availability without paying for cross-region latency? | topology | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | ★ pattern | [[multi-region-jetstream]] · [[choosing-a-topology]] |
| 46 | What causes performance degradation in a global supercluster? | topology | [gh#7494](https://github.com/nats-io/nats-server/discussions/7494) | gotcha | [[supercluster-slows-when-a-remote-subscriber-joins]] · [[gateway]] |
| 47 | Why does an asymmetric cluster configuration fail to form? | topology | [gh#7190](https://github.com/nats-io/nats-server/discussions/7190) | gotcha | [[build-a-3-node-cluster]] · [[monitoring-endpoints]] |
| 48 | How do I restrict which subjects a leafnode exports and imports? | topology security | [gh#5941](https://github.com/nats-io/nats-server/discussions/5941) | config | [[leafnode]] · [[cross-account-sharing]] · [[account]] · [[subject-permissions]] · [[operator-mode]] |
| 49 | How do I set up operator / account / user JWTs correctly? | security | [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) | ★ runbook | [[set-up-operator-mode]] · [[operator-mode]] · [[nk]] |
| 50 | How do I rotate TLS certificates without downtime, and how do I detect expiry? | security | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | ★ runbook | [[rotate-tls-certificates]] · [[tls-in-nats]] |
| 51 | How do I share a stream or KV bucket between accounts? | security jetstream | [gh#7017](https://github.com/nats-io/nats-server/discussions/7017) | ★ config | [[cross-account-sharing]] · [[mirrors-and-sources]] |
| 52 | How do I prevent a user from creating durable consumers or exceeding account limits? | security | [gh#5044](https://github.com/nats-io/nats-server/discussions/5044) | config | [[subject-permissions]] · [[account]] · [[direct-get]] · [[jetstream-slows-as-consumers-grow]] |
| 53 | When should I use auth callout, and what does the server validate before calling it? | security | [gh#7505](https://github.com/nats-io/nats-server/discussions/7505) | concept | [[auth-callout]] |
| 54 | How do I add accounts and reload a running cluster without dropping clients? | security deploy | [gh#5890](https://github.com/nats-io/nats-server/discussions/5890) | ★ runbook | [[reload-server-config]] · [[account]] · [[system-subjects]] |
| 55 | Which configuration changes actually take effect on reload, and which need a restart? | deploy | [gh#7126](https://github.com/nats-io/nats-server/discussions/7126) | ★ config gotcha | [[reload-server-config]] · [[config-keys]] |
| 56 | How do I deny unauthenticated connections without breaking system users? | security | [gh#4535](https://github.com/nats-io/nats-server/discussions/4535) | gotcha | [[unauthenticated-clients-still-connect]] · [[account]] |
| 57 | Which endpoints and metrics should I actually alert on for a JetStream cluster? | monitoring | [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) | ★ runbook | [[monitoring-endpoints]] · [[advisories]] · [[metrics]] |
| 58 | How do I find which consumer the server has flagged as slow? | monitoring | [gh#6605](https://github.com/nats-io/nats-server/discussions/6605) | ★ gotcha | [[slow-consumer-detected]] · [[monitoring-endpoints]] |
| 59 | Are there metrics for acked, naked, terminated and redelivered messages? | monitoring jetstream | [gh#6962](https://github.com/nats-io/nats-server/discussions/6962) | monitoring | [[advisories]] · [[consumer]] · [[metrics]] |
| 60 | How is CPU % in /varz measured, and why does it look wrong in containers? | monitoring | [gh#7483](https://github.com/nats-io/nats-server/discussions/7483) | gotcha measured | [[monitoring-endpoints]] · [[jetstream-sizing]] · [[metrics]] |
| 61 | How are the RTT values in /routez and /connz measured? | monitoring | [gh#7362](https://github.com/nats-io/nats-server/discussions/7362) | monitoring measured | [[monitoring-endpoints]] |
| 62 | How do I read and act on JetStream warnings in the server log? | monitoring jetstream | [gh#6490](https://github.com/nats-io/nats-server/discussions/6490) | ★ gotcha | [[stream-has-high-message-lag]] · [[js-api]] · [[jetstream-sizing]] |
| 63 | How do I roll a cluster onto a new server version safely? | deploy | [gh#3778](https://github.com/nats-io/nats-server/discussions/3778) | ★ runbook | [[upgrade-a-cluster]] |
| 64 | What are the data-integrity risks when upgrading across minor versions? | deploy | [gh#4781](https://github.com/nats-io/nats-server/discussions/4781) | ★ runbook | [[upgrade-a-cluster]] |
| 65 | Should JetStream use hostPath or a PVC on Kubernetes? | deploy | [gh#7749](https://github.com/nats-io/nats-server/discussions/7749) | ★ config | [[kubernetes-storage]] |
| 66 | How do I grow the JetStream volume on Kubernetes? | deploy | [gh#6601](https://github.com/nats-io/nats-server/discussions/6601) | gotcha runbook | |
| 67 | LoadBalancer or seed URLs — how should clients reach a cluster on Kubernetes? | deploy clients | [gh#6094](https://github.com/nats-io/nats-server/discussions/6094) | pattern | [[how-clients-reach-a-cluster]] |
| 68 | Why did throughput drop after moving from Kubernetes to a standalone VM (or back)? | deploy | [gh#6594](https://github.com/nats-io/nats-server/discussions/6594) | sizing gotcha | |
| 69 | How do I watch many KV keys at once without creating a watcher for each one? | kv | [gh#6746](https://github.com/nats-io/nats-server/discussions/6746) | ★ gotcha | [[key-value]] · [[kv-watchers-stall-the-cluster]] · [[jetstream-slows-as-consumers-grow]] · [[ordered-consumer]] |
| 70 | How do I count the keys in a KV bucket without fetching them all? | kv | [gh#7365](https://github.com/nats-io/nats-server/discussions/7365) | gotcha | [[key-value]] |
| 71 | Does KV support a TTL per key, and since which version? | kv | [gh#7264](https://github.com/nats-io/nats-server/discussions/7264) | config | [[message-ttl]] · [[key-value]] · [[stream-and-consumer-config]] |
| 72 | Why doesn't deleting or purging keys reclaim disk space in a bucket? | kv | [gh#6015](https://github.com/nats-io/nats-server/discussions/6015) | ★ gotcha | [[key-value]] · [[filestore-layout]] |
| 73 | When is KV or Object Store the wrong tool — where does Redis or a database win? | kv objectstore | [so#75576454](https://stackoverflow.com/questions/75576454/nats-object-store-or-key-value-store-vs-redis-cache) | concept | [[key-value]] · [[object-store]] |
| 74 | How do I implement a distributed lock or lease with KV? | kv | [so#79400839](https://stackoverflow.com/questions/79400839/how-to-use-nats-kv-for-distributed-locking) | pattern | [[key-value]] |
| 75 | Why is listing an object-store bucket slow (or timing out) while uploads run? | objectstore | [gh#6836](https://github.com/nats-io/nats-server/discussions/6836) | gotcha measured | [[object-store-list-is-slow]] |
| 76 | Why is a KV mirror on file storage far slower than on memory storage? | kv | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) | gotcha internals | [[consumer-slow-on-a-sparse-stream]] · [[key-value]] |
| 77 | What does an unexpected `nats: timeout` actually mean, and how do I trace it? | core | [gh#5859](https://github.com/nats-io/nats-server/discussions/5859) | ★ gotcha | [[nats-timeout]] · [[build-a-3-node-cluster]] · [[js-api]] |
| 78 | How many WebSocket connections can a single server sustain? | interop | [gh#2770](https://github.com/nats-io/nats-server/discussions/2770) | sizing no-public-answer | **[[websocket]]** |
| 79 | How do I run NATS WebSocket behind nginx or another proxy? | interop deploy | [gh#7375](https://github.com/nats-io/nats-server/discussions/7375) | runbook | [[run-nats-behind-a-proxy]] · [[websocket]] |
| 80 | How does MQTT QoS 1/2 map onto JetStream, and what does it cost? | interop | [gh#7641](https://github.com/nats-io/nats-server/discussions/7641) | concept measured | [[mqtt]] |
| 81 | How do I restrict MQTT client ids per account with JWT? | interop security | [gh#7397](https://github.com/nats-io/nats-server/discussions/7397) | config no-public-answer | **[[mqtt]]** |
| 82 | How do I track client connect and disconnect events? | monitoring core | [gh#6445](https://github.com/nats-io/nats-server/discussions/6445) | runbook | [[advisories]] · [[system-subjects]] |
| 83 | How do I get consumer pending metrics out of nats-surveyor or the Prometheus exporter, and what are the series called? | monitoring jetstream | [gh#3857](https://github.com/nats-io/nats-server/discussions/3857) | monitoring | [[prometheus-nats-exporter]] · [[nats-surveyor]] · [[metrics]] |
| 84 | Exporter or surveyor — which do I run for cluster-level alerts, and what does each need? | monitoring topology | [gh#6145](https://github.com/nats-io/nats-server/discussions/6145) | monitoring runbook | [[nats-surveyor]] · [[prometheus-nats-exporter]] · [[metrics]] |
| 85 | What is the ideal way to set metrics up at all — exporter, surveyor, Prometheus, Grafana, checks? | monitoring | [gh#6224](https://github.com/nats-io/nats-server/discussions/6224) | monitoring runbook | [[prometheus-nats-exporter]] · [[nats-surveyor]] · [[monitoring-endpoints]] · [[metrics]] |
| 86 | Are partitioned consumer groups a server feature, or a client-side construct? | jetstream clients | [gh#7296](https://github.com/nats-io/nats-server/discussions/7296) | concept clients | [[orbit]] |
| 87 | The Orbit docs show `orbit.go` — is the same module available for my language (C#, Java, Python…)? | clients | [gh#7296](https://github.com/nats-io/nats-server/discussions/7296) | clients | [[orbit]] — *Facts*, *The module set differs per language*: seven repos exist (`orbit.go`, `.js`, `.py`, `.java`, `.rs`, `.net`, `.c`), versioned **per module**, and three of them (`orbit.py`, `orbit.net`, `orbit.c`) have **published no release** — so the answer is per module, not per language (re-checked against the READMEs 2026-09-04) |
| 88 | Are there trade-offs to turning on `allow_direct` for a stream? | jetstream | [gh#3984](https://github.com/nats-io/nats-server/discussions/3984) | config | [[direct-get]] · [[stream-and-consumer-config]] |
| 89 | How do I set up cross-domain JetStream sourcing or mirroring? | jetstream topology security | [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) | ★ config runbook | [[cross-domain-sourcing]] |
| 90 | How do I manage streams and KV buckets across several accounts with one user? | security jetstream | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | config | [[cross-account-sharing]] · [[account]] |
| 91 | Why does mirror catch-up slow down when a consumer reads the mirror at the same time? | jetstream | [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) | gotcha internals | [[consumer-slow-on-a-sparse-stream]] · [[mirrors-and-sources]] |
| 92 | What does `attempted to connect to route port` in the server log mean? | topology core | [gh#3569](https://github.com/nats-io/nats-server/discussions/3569) | gotcha config | [[build-a-3-node-cluster]] · [[install-nats-server]] |
| 93 | Why doesn't lame-duck mode shut the server down gracefully under systemd? | deploy | [gh#6070](https://github.com/nats-io/nats-server/discussions/6070) | ★ runbook gotcha | [[install-nats-server]] · [[upgrade-a-cluster]] |
| 94 | Why does `openssl s_client` return nothing against the NATS TLS port? | security monitoring | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | gotcha | [[tls-in-nats]] · [[rotate-tls-certificates]] |
| 95 | Why does `nsc push` / `nats auth account push` time out with nothing in the server log? | security | [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) | gotcha runbook | [[set-up-operator-mode]] · [[nsc]] · [[account]] |
| 96 | Can I enable JetStream on the system account to manage all tenants from one place? | security jetstream | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | config | [[account]] · [[cross-account-sharing]] |
| 97 | Does a config reload actually pick up a renewed certificate file, or do I need a restart? | security deploy | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | ★ gotcha | [[rotate-tls-certificates]] · [[reload-server-config]] |
| 98 | Is there a limit on how many accounts one account can import from? | security topology | [gh#5606](https://github.com/nats-io/nats-server/discussions/5606) | sizing | |
| 99 | What happens when JetStream runs out of disk, and why does `insufficient storage resources available (10047)` appear on an almost empty volume? | jetstream deploy | [issue#4281](https://github.com/nats-io/nats-server/issues/4281) | ★ gotcha sizing | [[jetstream-out-of-disk]] |
| 100 | Why does the auto-sized `max_file_store` get smaller every time the server restarts? | jetstream deploy | [issue#8322](https://github.com/nats-io/nats-server/issues/8322) | ★ gotcha config | [[jetstream-out-of-disk]] · [[config-keys]] |
| 101 | Why does a cluster stop recovering when a thousand clients each open a KV watcher? | kv topology | [gh#5243](https://github.com/nats-io/nats-server/discussions/5243) | ★ gotcha sizing | [[kv-watchers-stall-the-cluster]] |
| 102 | Does a leafnode need its own JetStream domain, and what does setting one actually change? | jetstream topology | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | concept config | [[jetstream-domain]] |
| 103 | Can a leaf region later become the hub, or a regular cluster be converted into a leaf cluster without losing data? | topology deploy | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | ★ concept no-public-answer | **nobody has published an answer** — scouted 2026-08-31 across the docs, ADRs, GitHub and blogs; the two questions in the thread were never replied to. The finding is stated on [[choosing-a-topology]] |
| 104 | Why does `nats-server -t` accept a config the server then refuses to start? | deploy | [learn/topologies/putting-it-together](https://docs.nats.io/learn/topologies/putting-it-together) | gotcha config | [[reload-server-config]] · [[build-a-3-node-cluster]] |
| 105 | Why does `nats object ls <bucket>` fail on a **mirror** of an object-store bucket, and what does mirroring one across a leafnode with two JetStream domains actually give you? | objectstore topology | [gh#5106](https://github.com/nats-io/nats-server/issues/5106) | gotcha internals | [[object-store]] · [[cross-domain-sourcing]] |
| 106 | How do I do dead-lettering in NATS, and why doesn't a message move to a DLQ when `ack_wait` expires with no clients fetching? | jetstream | [gh#4994](https://github.com/nats-io/nats-server/discussions/4994) | ★ pattern gotcha | [[dead-letter-queue]] · [[ack-and-redelivery]] |
| 107 | The max-deliveries advisory carries no payload — how do I keep the failed message itself? | jetstream | [gh#7590](https://github.com/nats-io/nats-server/discussions/7590) | pattern measured | [[dead-letter-queue]] · [[advisories]] |

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
108. [gh#6100](https://github.com/nats-io/nats-server/discussions/6100) — Does Stream Per Subject have any performance benifits over multiple subjects within same stream
109. [gh#4170](https://github.com/nats-io/nats-server/discussions/4170) — Subject Indexing and Ordering Internals
110. [gh#4499](https://github.com/nats-io/nats-server/discussions/4499) — JetStream and Work retention policy Stream with Durable consumers and fan-out
111. [gh#3405](https://github.com/nats-io/nats-server/discussions/3405) — Consumer Filtering Performance
113. [gh#6437](https://github.com/nats-io/nats-server/discussions/6437) — Need Some General Info Regarding Client Design & partitioning (question 2, the replication factor)
114. [gh#6571](https://github.com/nats-io/nats-server/discussions/6571) — Which NATS JetStream Setup is Better?
115. [gh#5415](https://github.com/nats-io/nats-server/discussions/5415) — JetStream. "Queue group" feature with pull subscribers
117. [gh#8174](https://github.com/nats-io/nats-server/discussions/8174) — Is Consumer Group prunes old members? (the stale-consumer question)
118. [gh#5334](https://github.com/nats-io/nats-server/discussions/5334) — kvBuckets are unexpectedly slow
119. [gh#5468](https://github.com/nats-io/nats-server/discussions/5468) — Jetstream KV/ObjectStore as a database?
120. [so#78477337](https://stackoverflow.com/questions/78477337/is-anyone-using-nats-object-store-in-production) — Is anyone using Nats Object Store in production? (Stack Overflow, unanswered)
121. [gh#6848](https://github.com/nats-io/nats-server/discussions/6848) — Sharing many distributed account Jetstreams with a server-side account
122. [gh#6739](https://github.com/nats-io/nats-server/discussions/6739) — Migrating streams to a new authentication domain
124. [gh#5317](https://github.com/nats-io/nats-server/discussions/5317) — Nats SuperCluster with Gateways Adding Jetstream
125. [gh#5974](https://github.com/nats-io/nats-server/discussions/5974) — Use thousands of leaf nodes at the edge
126. [gh#3417](https://github.com/nats-io/nats-server/discussions/3417) — Cluster can't tolerate more than one service failure
129. [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) — Setting Up Monitoring and Alerts for NATS Cluster with Prometheus Metrics (the same thread as row 57)
130. [gh#4201](https://github.com/nats-io/nats-server/discussions/4201) — Upgrading NATS from v2.8.0 to v2.9.17
135. [gh#6320](https://github.com/nats-io/nats-server/discussions/6320) — Automatic Chunking
136. [gh#3654](https://github.com/nats-io/nats-server/discussions/3654) — Distribute all partitions to a delivery group & trigger rebalance events on disconnected consumers.
137. [gh#5507](https://github.com/nats-io/nats-server/discussions/5507) — Does MQTT in NATS supports features like Webhooks and Mountpoints which are available in Verne MQ?
138. [gh#2760](https://github.com/nats-io/nats-server/discussions/2760) — Specializing Websocket connections between "read-only" (subscribe) vS "write-only" (publish)
139. [gh#2818](https://github.com/nats-io/nats-server/discussions/2818) — Are the metrics for in/out bytes and message-count reported by the nats-server 100% accurate or approximations?
140. [gh#3095](https://github.com/nats-io/nats-server/discussions/3095) — message timestamp and clock skew
141. [gh#3198](https://github.com/nats-io/nats-server/discussions/3198) — How to achieve horizontal scaling with multiple Nats Server?
142. [gh#3495](https://github.com/nats-io/nats-server/discussions/3495) — Sharding Jetstream
143. [gh#3507](https://github.com/nats-io/nats-server/discussions/3507) — Will Jetstream support external DB like postgres for persistence
144. [gh#3772](https://github.com/nats-io/nats-server/discussions/3772) — Using Nats Jetstream as an event store
145. [gh#3790](https://github.com/nats-io/nats-server/discussions/3790) — How to remove existing instances/nodes from the nats/jetstream cluster?
146. [gh#3944](https://github.com/nats-io/nats-server/discussions/3944) — Getting info about existing subjects in stream
147. [gh#3955](https://github.com/nats-io/nats-server/discussions/3955) — NATS Jetstream Internals
148. [gh#4267](https://github.com/nats-io/nats-server/discussions/4267) — Disabling Nagle's algorithm
149. [gh#4639](https://github.com/nats-io/nats-server/discussions/4639) — How to use authorization via JWT for KV Buckets
150. [gh#4761](https://github.com/nats-io/nats-server/discussions/4761) — support for "no-responders" in multitenancy
151. [gh#4883](https://github.com/nats-io/nats-server/discussions/4883) — Is there a way to update or delete a message in a stream?
152. [gh#4989](https://github.com/nats-io/nats-server/discussions/4989) — Using websocket with NoTLS behind a TLS terminating proxy
153. [gh#5128](https://github.com/nats-io/nats-server/discussions/5128) — Inquiry on Limits for Streams and Consumers in a NATS JetStream Cluster
154. [gh#6005](https://github.com/nats-io/nats-server/discussions/6005) — New sequence clipping behavior seems to broke sourcing from memory streams
155. [gh#6748](https://github.com/nats-io/nats-server/discussions/6748) — CVE-2025-30215 - Docker image available?
156. [gh#7328](https://github.com/nats-io/nats-server/discussions/7328) — NATS supercluster server/cluster discovery from client
157. [gh#7623](https://github.com/nats-io/nats-server/discussions/7623) — Is there a recommended GUI for monitoring NATs?
158. [gh#8362](https://github.com/nats-io/nats-server/discussions/8362) — MQTT 5.0 support — guidance on how to structure the PR(s)? (the maintainers' answer: no)
162. [gh#5902](https://github.com/nats-io/nats-server/discussions/5902) — Subscribe to LEAFNODE.CONNECT and LEAFNODE.DISCONNECT events
163. [gh#5768](https://github.com/nats-io/nats-server/discussions/5768) — How can I track connected clients if my system account misses a connection event?
169. [gh#5097](https://github.com/nats-io/nats-server/discussions/5097) — Subject token limit; and [gh#2855](https://github.com/nats-io/nats-server/discussions/2855) — Could I publish message with wildcards (the publish-side half)
170. [gh#5172](https://github.com/nats-io/nats-server/discussions/5172) — Docu about programatic configuration of subject mapping.

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

**Row 75 is answered by measurement, not by a source.** The thread it comes from
([gh#6836](https://github.com/nats-io/nats-server/discussions/6836)) has one comment — the asker's own
follow-up — and no reply from anyone else, sixteen months on. `learn/object-store/watching-and-listing.md`,
the docs page that covers listing, says only that "a list is cheap: it reads metadata, never chunks"
and never mentions concurrency. So [[object-store-list-is-slow]] answers it from nine experiments on
the v2.14.6 binary (`raw/nats-server-src/object-store-observed-v2.14.6.md`): object count is nearly
free (25× the objects for 1.6× the time), concurrent writes to the same bucket cost 2–7×, and a list
is an ephemeral `last_per_subject` consumer created and destroyed on every call. The `measured` flag
marks rows answered this way.

**Row 105 was added by step 4 of `inbox/plan-the-unread-chapters-2026-08-31.md`** and the wiki cannot
answer it. The maintainer's reply in the thread — that the CLI assumes the metadata and chunk subjects
align with the stream name, which a mirror breaks, and that listing streams by subject excludes
mirrors — is on no page here. It is the nearest public question to a finding that has **no** public
question behind it: that a JetStream domain isolates a KV bucket across a leafnode and does **not**
isolate an object-store bucket. That finding is recorded on [[object-store]], [[jetstream-domain]],
[[leafnode]] and [[streams-not-visible-across-a-leafnode]], and as docs issue #35 — deliberately
without a bank row of its own, because nobody has been found asking it.

**Rows 78 and 81 are closed as dead ends, not as answers**, and both cells are bold to say so.

**Row 78** — how many WebSocket connections one server sustains. `learn/websocket` gives no number,
the generated reference gives none, and `max_connections` bounds every connection kind together, so it
is not an answer to the question as asked. Recorded once, on [[websocket]]'s *To verify*, rather than
hedged across pages. It was not measured: a connection-count benchmark says more about the machine
than about the server, and this wiki does not publish sizing numbers it cannot attribute.

**Row 81** — restricting which MQTT client ids a user may present, via JWT/nsc. The thread has been
open and **unanswered since 2025-10-06**, and `learn/mqtt/auth-and-clustering.md` — the page named for
it — restricts a user to a *connection type* and hands devices a bearer JWT, but nothing there
constrains a client id. **What this step could do instead was explain the problem behind the
question.** The reporter's devices rotate client ids and publish at QoS 1, and they find "messages
never get deleted since the stale clients block deletion". That is reproducible on 2.14.6:
`$MQTT_msgs` uses **interest retention**, and a stale session's durable consumer still holds interest,
so nothing is ever removed — reconnecting each dead client id once with the clean-session flag empties
the stream. Both the mechanism and the remedy are on [[mqtt]]; the restriction the row asks for still
has no public answer.

**Row 80 is answered by measurement.** `learn/mqtt` describes the QoS contract in full and **never
names a single stream**, so "what does it cost" was unanswerable from it. Fifteen runs on the v2.14.6
binary named all five `$MQTT_*` streams and priced each level: QoS 0 costs nothing, QoS 1 and QoS 2
cost **the same** stored bytes (194 for a 100-byte payload), and a retained message costs 174 bytes
even at QoS 0 (`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`).

**Rows 60 and 61 were both answered from the server source, not from the chapter named for them.**
`learn/monitoring` never states how either number is measured — profiling is about CPU *profiles*, not
the `/varz` `cpu` field, and the endpoints page prints `rtt` values without saying what produces them.

**Row 60**: `cpu` is a percentage of **one core** — `100.0` is one core fully consumed — and it is
relative to neither the host's core count nor a container's CPU allocation. On Linux it is sampled once
a second by a background timer over `/proc/<pid>/stat`. The asker's thread was **closed with zero
comments**, and their `cpu: 10` on a 0.25 vCPU Fargate task is 40 % of their allocation, not 10 % of
anything.

**Row 61**: `rtt` is a PING/PONG measurement, floored at 1ns — but a **client's** refreshes only when
`rtt == 0` or more than **an hour** has passed (`DEFAULT_RTT_MEASUREMENT_INTERVAL`), and its *first*
value is the connection setup time rather than a ping at all. Routes, gateways and spoke leafnodes
refresh at the ping interval instead. The public thread's chosen answer is correct and omits the
period, and the reporter's follow-up — "I don't see these values getting updated, even if we wait
minutes" — is right and never answered.

**No profiling row was added.** `learn/monitoring/profiling.md` was ingested in the same step, and a
search of `nats-io/nats-server` discussions for a public question about profiling returned **nothing**.
`CLAUDE.md`'s scope test says a page needs a question behind it, so the material landed as sections on
[[jetstream-sizing]] and [[monitoring-endpoints]] rather than as a runbook, and no question was
invented to justify one.
| 108 | One stream per tenant or service, or one stream with a tenant prefix in the subject — which, and at what count does "many streams" start to cost you (meta layer, account limits, consumers)? | jetstream security | [gh#6100](https://github.com/nats-io/nats-server/discussions/6100) | design pattern sizing |  |
| 109 | How should I design a subject hierarchy for JetStream — token order, where the wildcards go, and what subject cardinality costs the filestore and filtered consumers? | jetstream core | [gh#4170](https://github.com/nats-io/nats-server/discussions/4170) | design pattern |  |
| 110 | Limits, Interest or WorkQueue — how do I choose retention for a task queue, an event log and a cache, and what breaks when I choose wrong? | jetstream | [gh#4499](https://github.com/nats-io/nats-server/discussions/4499) | design concept |  |
| 111 | Filtered consumers on one large stream, or many small streams — which scales better for fan-out to N services, and where do `max_consumers` and per-consumer state bite? | jetstream | [gh#3405](https://github.com/nats-io/nats-server/discussions/3405) | design pattern sizing |  |
| 112 | `Nats-Msg-Id` deduplication or `Nats-Expected-Last-Subject-Sequence` — which gives me exactly-once-ish publishing for my case, and what does each cost? | jetstream | own | design pattern | [[publishing]] · [[stream]] |
| 113 | R1, R3 or R5, memory or file — how do I pick a stream's replica count and storage for a given availability, durability and throughput target? | jetstream | [gh#6437](https://github.com/nats-io/nats-server/discussions/6437) | design sizing | [[replicas]] |
| 114 | Mirror, source, or a filtered consumer on the original stream — which replication shape for read replicas, fan-in and cross-region copies, and what does each cost? | jetstream topology | [gh#6571](https://github.com/nats-io/nats-server/discussions/6571) | design pattern |  |
| 115 | Pull or push, ordered or not, a queue group or one pull consumer shared by every replica — what is the consumer design for a service with N replicas reading one stream? | jetstream clients | [gh#5415](https://github.com/nats-io/nats-server/discussions/5415) | design pattern | [[worker-pool]] |
| 116 | How do I set `max_ack_pending`, batch size, `ack_wait` and `max_deliver` together for a worker pool with a throughput target and a failure budget? | jetstream | own | design sizing | [[worker-pool]] · [[ack-and-redelivery]] · [[stream-and-consumer-config]] |
| 117 | Durable or ephemeral consumers — when does a durable consumer become a liability (inactive threshold, orphaned state, a redelivery storm after a long outage)? | jetstream | [gh#8174](https://github.com/nats-io/nats-server/discussions/8174) | design gotcha |  |
| 118 | One KV bucket per tenant or one bucket with key prefixes; how much history and which TTL — what does each cost, and how big can a bucket get before watchers and key listing suffer? | kv | [gh#5334](https://github.com/nats-io/nats-server/discussions/5334) | design pattern sizing |  |
| 119 | KV as a config store, a service registry, a cache or a coordination primitive — which uses fit, which should be a stream or a database, and what does a KV get promise during a leader change? | kv | [gh#5468](https://github.com/nats-io/nats-server/discussions/5468) | design pattern |  |
| 120 | Object store or external blob storage — when is the NATS object store the right choice, and how do chunk size, `max_payload` and bucket limits constrain the design? | objectstore | [so#78477337](https://stackoverflow.com/questions/78477337/is-anyone-using-nats-object-store-in-production) | design pattern |  |
| 121 | Accounts or subject-prefix permissions for tenant isolation — when does a tenant need its own account, and what do imports and exports cost as tenants multiply? | security | [gh#6848](https://github.com/nats-io/nats-server/discussions/6848) | design pattern |  |
| 122 | Operator mode with JWTs, config-file accounts, or auth callout — which authentication model for which organisation, and how hard is moving between them later? | security | [gh#6739](https://github.com/nats-io/nats-server/discussions/6739) | design pattern |  |
| 123 | How should per-account JetStream limits (`max_memory`, `max_file`, `max_streams`, `max_consumers`) be apportioned in a shared cluster, and what does a tenant see at the limit? | security jetstream | own | design sizing |  |
| 124 | Cluster, supercluster or leafnodes for multi-region — for a given latency and failure-domain requirement, which topology, and where does stream placement go? | topology | [gh#5317](https://github.com/nats-io/nats-server/discussions/5317) | design pattern | [[choosing-a-topology]] · [[multi-region-jetstream]] |
| 125 | Edge sites with intermittent connectivity: a leafnode with its own JetStream domain mirroring to the hub, or direct clients to the hub — how do I design for the link being down? | topology jetstream | [gh#5974](https://github.com/nats-io/nats-server/discussions/5974) | design pattern |  |
| 126 | Three or five servers, and how spread across availability zones — what is the quorum arithmetic, and what fails in a two-zone layout? | topology deploy | [gh#3417](https://github.com/nats-io/nats-server/discussions/3417) | design sizing |  |
| 127 | Should JetStream run on every server or on dedicated nodes, and should the system account, monitoring and client traffic share them — how do I partition roles in a cluster? | topology deploy | own | design pattern |  |
| 128 | Capacity planning: how do I derive node count, disk, RAM and IOPS from message rate, size, retention, replicas and consumer count — and what runs out first? | deploy jetstream | own | design sizing | [[jetstream-sizing]] |
| 129 | What is the minimum alert set for production JetStream — quorum, lag, disk, consumer pending, redeliveries — and which endpoint or metric feeds each? | monitoring | [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) | design runbook | [[metrics]] — *The series behind the alerts*: quorum, lag, disk, consumer pending, redeliveries, each with the tool and server version it holds for and what has no series; the runbook that wires them is phase G6's `production-alerting` |
| 130 | Rolling upgrade design: node order, the mixed-version window, API levels, and when a minor upgrade is not rollback-safe? | deploy | [gh#4201](https://github.com/nats-io/nats-server/discussions/4201) | design runbook | [[upgrade-a-cluster]] |
| 131 | Kubernetes, VMs or bare metal for JetStream — storage classes, a PVC per replica, anti-affinity, and what the Helm chart decides for you? | deploy | own | design pattern |  |
| 132 | Backup and disaster-recovery design: snapshots, a mirror in a second cluster, or trusting R3 — what RPO and RTO does each give, at what cost? | deploy jetstream | own | design pattern | [[disaster-recovery]] · [[backup-and-restore-jetstream]] |
| 133 | Core NATS or JetStream for a given flow — how do I decide per subject, and what does a mixed design (core for request/reply, JetStream for events) look like? | core jetstream | own | design pattern | [[core-or-jetstream]] |
| 134 | Request/reply at scale without JetStream: queue groups, timeouts, scatter-gather and no-responders — how do I design a service layer on core NATS? | core | own | design pattern | [[services-on-core-nats]] · [[services-framework]] |
| 135 | Large messages: raise `max_payload`, chunk in the application, or use the object store — where is each the right answer? | core objectstore | [gh#6320](https://github.com/nats-io/nats-server/discussions/6320) | design pattern |  |
| 136 | Migrating from Kafka or RabbitMQ: how do topics, partitions, consumer groups and offsets map onto streams, subjects, consumers and acks — and where do the semantics differ? | jetstream interop | [gh#3654](https://github.com/nats-io/nats-server/discussions/3654) | design pattern |  |
| 137 | Built-in MQTT or a broker in front of NATS — when does each fit, and what do sessions, QoS levels and retained messages cost in JetStream storage? | interop | [gh#5507](https://github.com/nats-io/nats-server/discussions/5507) | design pattern |  |
| 138 | One client connection for both subscribing and publishing, or one per direction — what does a single connection cost (head-of-line blocking on the subscriptions), and when are two worth it? | clients core | [gh#2760](https://github.com/nats-io/nats-server/discussions/2760) | design | [[core-nats-delivery]] · [[request-reply]] — *A single connection is one FIFO*: start with one; head-of-line blocking is on the subscription side, so move a latency-sensitive subscription to a second connection only when a heavy one delays it (the chosen answer) |
| 139 | Are the `in_msgs` / `out_msgs` and byte counters in `/varz`, `/connz` and `nats-top` exact, or sampled approximations? | monitoring | [gh#2818](https://github.com/nats-io/nats-server/discussions/2818) | monitoring | [[metrics]] · [[nats-top]] · [[monitoring-endpoints]] |
| 140 | Which clock stamps a JetStream message's timestamp — the leader's — and does a cluster need synchronised clocks (NTP)? | jetstream deploy | [gh#3095](https://github.com/nats-io/nats-server/discussions/3095) | config | [[stream-and-consumer-config]] · [[stream]] |
| 141 | Coming from a single broker: how do I scale NATS horizontally — a cluster behind one DNS name — and what do clients need to know about it? | core topology | [gh#3198](https://github.com/nats-io/nats-server/discussions/3198) | concept | [[build-a-3-node-cluster]] · [[how-clients-reach-a-cluster]] |
| 142 | When I publish to a replicated stream, which servers do the work — is the leader a bottleneck, and when do I actually need to shard a stream? | jetstream | [gh#3495](https://github.com/nats-io/nats-server/discussions/3495) | sizing | [[replicas]] · [[subject-transforms]] |
| 143 | Can JetStream persist to an external database such as Postgres, as NATS Streaming could? | jetstream interop | [gh#3507](https://github.com/nats-io/nats-server/discussions/3507) | concept | [[stream]] — *Two storage backends, and there is no third*; [[nats-streaming]] — *What the migration loses*; [[core-or-jetstream]] |
| 144 | Is JetStream suitable as an event store — millions of events, one subject per aggregate, optimistic concurrency on publish, and tiering to cold storage? | jetstream | [gh#3772](https://github.com/nats-io/nats-server/discussions/3772) | design pattern |  |
| 145 | How do I remove a server from a JetStream cluster for good — lame duck, then peer-remove — and why does it come back? | topology jetstream | [gh#3790](https://github.com/nats-io/nats-server/discussions/3790) | runbook | [[rebalance-streams]] · [[evict-a-sick-server]] |
| 146 | How do I find out which subjects a stream actually holds, and consume all of them except one? | jetstream | [gh#3944](https://github.com/nats-io/nats-server/discussions/3944) | config | [[stream-and-consumer-config]] · [[js-api-subjects]] |
| 147 | How is JetStream built — which Raft groups exist, how a stream's data is stored, and whether reads have to go through the leader? | jetstream | [gh#3955](https://github.com/nats-io/nats-server/discussions/3955) | internals | [[raft-in-nats]] · [[meta-layer]] · [[filestore-layout]] · [[direct-get]] |
| 148 | Is Nagle's algorithm (`TCP_NODELAY`) disabled on client and route connections? | core deploy | [gh#4267](https://github.com/nats-io/nats-server/discussions/4267) | config | [[defaults-and-limits]] — *The socket options the server never sets*; [[wire-protocol]] — *The one socket option, which the server does not set*: **yes, on every connection kind** — the server never calls `SetNoDelay` anywhere at v2.14.6 and has no key for it; Go's `net.newTCPConn` sets it on every TCP connection it makes, so Nagle is off and cannot be turned on |
| 149 | How do I grant a user access to one KV bucket, or one key prefix, with subject permissions or a JWT? | kv security | [gh#4639](https://github.com/nats-io/nats-server/discussions/4639) | config |  |
| 150 | Does "no responders" work across an account import — why does a cross-account request time out instead of failing fast? | security core | [gh#4761](https://github.com/nats-io/nats-server/discussions/4761) | gotcha measured | [[cross-account-sharing]] · [[request-reply]] · [[s-relnotes-2.10]] — *Run on 2.14.6*: the 503 in 37 ms across the import, `Nats-Subject` naming the importer's subject |
| 151 | Can I update or delete a single message in a stream, and what does a secure delete do? | jetstream | [gh#4883](https://github.com/nats-io/nats-server/discussions/4883) | config | [[stream]] · [[s-docs-altering-stream-state]] · [[stream-and-consumer-config]] |
| 152 | Is a WebSocket listener with `no_tls: true` behind a TLS-terminating proxy safe, and can the startup warning be silenced? | deploy security | [gh#4989](https://github.com/nats-io/nats-server/discussions/4989) | config | [[run-nats-behind-a-proxy]] · [[websocket]] |
| 153 | How many streams and consumers can a 3- or 5-node cluster hold — is there a number, and what is an "HA asset"? | jetstream | [gh#5128](https://github.com/nats-io/nats-server/discussions/5128) | sizing | [[metrics]] · [[jetstream-sizing]] · [[stream-placement]] · [[jetstream-slows-as-consumers-grow]] |
| 154 | Why did a stream sourcing from a memory stream on a leaf node stop receiving after the leaf restarted (2.10.21), and what changed? | jetstream topology | [gh#6005](https://github.com/nats-io/nats-server/discussions/6005) | gotcha | [[mirrors-and-sources]] · [[stream-has-high-message-lag]] · [[s-gh-6005-sourcing-memory-stream-restart]] |
| 155 | A CVE fix shipped as a binary release — when do the official Docker images follow, and who builds them? | deploy security | [gh#6748](https://github.com/nats-io/nats-server/discussions/6748) | concept | [[install-nats-server]] · [[nats-server-2.10]] · [[s-gh-6748-cve-binary-release-docker-images]] |
| 156 | Does a client discover the other clusters of a supercluster, and how do I fail clients over to another cluster? | topology clients | [gh#7328](https://github.com/nats-io/nats-server/discussions/7328) | concept | [[gateway]] — *A client never learns another cluster exists*; [[how-clients-reach-a-cluster]] — *Discovery stops at the cluster edge*; [[client-connection-lifecycle]] — *Connecting*: **no** — `connect_urls` is fed by routes only (all three call sites in `server/route.go`), so failover across clusters is your URL list or one name in front of both |
| 157 | Is there a recommended GUI for inspecting streams, consumers and KV buckets? | monitoring | [gh#7623](https://github.com/nats-io/nats-server/discussions/7623) | concept |  |
| 158 | Does nats-server support MQTT 5, or will it? | interop | [gh#8362](https://github.com/nats-io/nats-server/discussions/8362) | concept | [[mqtt]] |
| 159 | Which patch release of my minor should I be on — what did each 2.10, 2.11, 2.12 and 2.14 patch fix, and which releases are withdrawn or carry a warning? | deploy | own | runbook config | [[nats-server-2.14]] · [[nats-server-2.12]] · [[nats-server-2.11]] · [[nats-server-2.10]] · [[upgrade-a-cluster]] — the *Which patch to be on* section on each release entity, from the 70 release bodies |
| 160 | When did a config key, default, subject or header arrive, and in which release did a default change? | deploy config | own | config reference | [[defaults-and-limits]] · [[config-keys]] · [[js-api-subjects]] · [[monitoring-endpoints]] — the *Defaults that moved* / *Keys that arrived* tables per minor, plus `since:` on every reader page (phase D) · [[stream-and-consumer-config]] |
| 161 | Which `$SYS` subjects does a server answer on and publish to, which of the monitoring names are request-only with no HTTP form, and what may a monitoring user or an ordinary user be granted? | monitoring security | own | config monitoring reference | [[system-subjects]] · [[monitoring-endpoints]] |
| 162 | Can I subscribe to leafnode connect and disconnect events from the system account, and why do they never arrive on a single hub? | monitoring topology | [gh#5902](https://github.com/nats-io/nats-server/discussions/5902) | gotcha monitoring | [[system-subjects]] · [[leafnode]] |
| 163 | How do I re-read who is connected after my system-account listener missed a `CONNECT` event, and does a per-server request cover the whole cluster? | monitoring core | [gh#5768](https://github.com/nats-io/nats-server/discussions/5768) | runbook monitoring | [[system-subjects]] |
| 164 | Which stream and consumer fields can be changed after creation, which are fixed, and which are one-way — and what does the server say when it refuses? | jetstream | own | config reference | [[stream-and-consumer-config]] · [[stream]] · [[consumer]] |
| 165 | Why does `nats_consumer_num_pending` differ between the nodes of a cluster — 3 / 0 / 3 across three pods — and which node's exporter do I alert on? | monitoring jetstream | [exporter#218](https://github.com/nats-io/prometheus-nats-exporter/issues/218) | monitoring gotcha | [[metrics]] · [[consumer]] · [[prometheus-nats-exporter]] · [[nats-surveyor]] |
| 166 | A service in its own account authenticates callers from the `Nats-Request-Info` header the server stamps on a service import — what is in the header, when does it carry the user and not only the account, and is `share: true` on the import a supported setting to build on? | security core | own | design config | [[service-import-request-info]] · [[cross-account-sharing]] |
| 167 | For an export every tenant imports, can I restrict who may import with an activation token per tenant instead of listing accounts on the export — and which of the three guards (`accounts`, `token_req`, `account_token_position`) changes the exporter's account JWT when a tenant joins or leaves? | security topology | own | design pattern config | [[cross-account-sharing]] · [[operator-mode]] · [[nsc]] |
| 168 | Can the `Nats-Request-Info` header the server adds on a service import push a request that passed `max_payload` at ingress over the limit at delivery? | core security | [gh#8271](https://github.com/nats-io/nats-server/issues/8271) | gotcha | [[service-import-request-info]] · [[publishing]] |
| 169 | Which characters, prefixes and lengths are legal in a subject — is there a token or length limit, and can I publish to a wildcard? | core | [gh#5097](https://github.com/nats-io/nats-server/discussions/5097) | concept config measured | [[subjects-and-wildcards]] · [[core-nats-delivery]] — the three rules the server enforces (run on 2.14.6), no length limit, `max_control_line` and `max_subscription_tokens` as the real bounds; the publish-side half is [gh#2855](https://github.com/nats-io/nats-server/discussions/2855) |
| 170 | Rename, split or shard a subject on the server without changing publishers — account-level `mappings` or a stream transform, and which belongs where? | core jetstream | [gh#5172](https://github.com/nats-io/nats-server/discussions/5172) | config pattern measured | [[subject-transforms]] · [[subjects-and-wildcards]] — *Account-level `mappings`*: weights, the remainder rule (literal and wildcard, measured), partition, `cluster`, reload, and the maintainer's placement rule |
| 172 | Scatter-gather on core NATS — gather by count, by deadline or by sentinel: how long does each wait, what does a missing responder cost, and which clients ship a helper? | core clients | own | design measured | [[request-reply]] — *Scatter-gather: every responder answers*: ADR-47's four stop conditions, each timed on 2.14.6 through natscli 0.4.0's flags |
| 173 | Does a queue group route around a busy or slow member — is the pick readiness-aware, round-robin or random? | core | own | measured | [[queue-groups]] — *The pick: random, not round-robin, not readiness-aware*, run C on 2.14.6: the busy member kept its share |
| 174 | How does a queue group split its load across the servers of a cluster, across a leafnode and across a gateway — is the publisher's own server preferred? | core topology | own | measured topology | [[queue-groups]] · [[leafnode]] · [[gateway]] — uniform per member inside a cluster (run E), the publisher's side outright across a leafnode with the hub's own split skewed (run H, SI-8), an exclusion list across a gateway |
| 171 | A message was published and never arrived — which tool shows why: a wire tap, `/subsz?test=`, `/connz?subs=true`, or `nats trace`, and what does each need? | core monitoring | own | gotcha runbook measured | [[core-nats-delivery]] · [[monitoring-endpoints]] — *Debugging delivery: the four surfaces*, each run on 2.14.6 |
| 175 | What does a client actually do at connect time — how many servers does it try, in what order, and how long does each dial block? | core clients | own | design | [[client-connection-lifecycle]] — *Connecting*; [[client-defaults]] |
| 176 | How does a client learn about the servers it was not configured with, and what makes that discovery stop working? | core topology clients | own | design | [[client-connection-lifecycle]] — *Connecting*; [[how-clients-reach-a-cluster]] — *What the client does with the list* |
| 177 | A node is stopped or put into lame duck under load — what does a connected client see, and what is lost? | core topology clients | own | measured | [[client-connection-lifecycle]] — *Reconnecting*, *Lame duck, as the client sees it*; [[core-nats-delivery]] — *The reconnect gap is at-most-once, measured*; [[upgrade-a-cluster]] |
| 178 | A server is up but not answering — how long before a client notices, and can I make that shorter? | core clients monitoring | own | measured gotcha | [[client-connection-lifecycle]] — *The keepalive*; [[client-defaults]]; [[run-nats-behind-a-proxy]] |
| 179 | How do I stop a client without losing the work it is holding — and what does drain not cover? | core clients jetstream | own | design measured | [[client-connection-lifecycle]] — *Draining, and closing*; [[worker-pool]]; [[queue-groups]] |
| 180 | My application is losing messages while the connection stays up and the server logs nothing — where did they go, and how do I bound it? | core clients | own | gotcha measured | [[slow-consumer-in-the-client]]; [[client-defaults]] — *Pending limits*; [[slow-consumer-detected]] — *The client-side sibling* |
| 181 | A credential expired or was rejected — how long does the client keep trying, what closes it, and how much of a window is there to rotate into? | security clients | own | gotcha measured | [[connection-closed-after-auth-error]]; [[operator-mode]] — *What expiry looks like on the wire, and when*; [[client-defaults]] — *The auth-error abort, per client* |
| 182 | The server closed a connection and the client only saw EOF — how do I find out why? | core monitoring clients | own | gotcha | [[monitoring-endpoints]] — *`/connz?state=closed`*; [[error-codes]] — *The other error list*; [[slow-consumer-detected]] |
| 183 | My client logged `-ERR '<something>'` — which server setting produced it, and should the client reconnect or keep going? | core clients | own | reference measured | [[wire-protocol]] — *`-ERR` — every string, its setting, and whether the connection survives* |
| 184 | I have a port and no client library — how do I tell whether it is a client, route, gateway or leafnode listener, and what version is behind it? | core topology deploy | own | runbook measured | [[wire-protocol]] — *Smoke-testing a port*; [[build-a-3-node-cluster]] — *Checking a route port without a client* |
| 185 | I am reading a packet capture between two servers — what do `RS+`, `RMSG`, `LS+`, `LMSG`, `$LDS.` and `_GR_.` mean? | topology core | own | reference measured | [[wire-protocol]] — *The verbs, by connection kind*, *Prefixes seen on the wire*; [[leafnode]] — *What a leafnode connection puts on the wire*; [[gateway]] |
| 186 | I am writing or debugging a client against the raw protocol — what must a `CONNECT` carry, and what does leaving a field out actually mean? | clients core | own | reference measured | [[wire-protocol]] — *`CONNECT` — the fields a client sends*; [[client-connection-lifecycle]] — *`CONNECT {}` is a verbose connection* |
| 187 | Does a gateway still start in optimistic mode and switch to interest-only, and is that switch something I need to size for? | topology design | own | design measured | [[gateway]] — *Interest-only is the default, and has been since 2.9.0*; [[supercluster-slows-when-a-remote-subscriber-joins]] — *Not the interest-mode switch* |
| 188 | What does a services-framework instance actually put on my server — how many subscriptions, on which subjects, and with which queue groups? | core clients monitoring | own | measured reference | [[services-framework]] — *The subjects it creates*; [[monitoring-endpoints]] — *What a services instance adds to `/subsz`* |
| 189 | If one instance of a service blocks, does the queue group route around it — and how should that shape my caller's timeout? | core clients | own | design measured | [[services-on-core-nats]] — *Size the timeout from the queue, not from the handler*; [[queue-groups]] — *The services framework's queue groups* |
| 190 | How do I tell a service that rejected my request from one that is not running from one that is merely slow? | core clients | own | measured | [[services-framework]] — *A service error is a delivered reply*; [[nats-timeout]] — *A fourth outcome when the responder is a service* |
| 191 | Who may see `$SRV`, and how do I let operations tooling discover services without letting it call them? | security clients | own | config measured | [[services-framework]] — *What the operator has to configure: permissions*; [[subject-permissions]] — *`$SRV.>` is an ordinary permission*; [[services-on-core-nats]] |
| 192 | Do `$SRV` discovery and service endpoints cross a leafnode, and does an instance at the edge add capacity to the hub? | topology clients | own | design measured | [[leafnode]] — *Where that leaves a service at the edge*; [[services-framework]] — *Across a cluster, a leafnode and an account* |
| 193 | Can a services-framework handler ack and nak against JetStream, so a failed request is redelivered? | core jetstream clients | [gh#4984](https://github.com/nats-io/nats-server/discussions/4984) | design | [[services-on-core-nats]] — *When not to use it*; [[worker-pool]] — *The core-NATS sibling, and where the line falls* |
| 194 | Do I need two clusters to use core NATS and JetStream, and does enabling JetStream slow core NATS down? | jetstream deploy topology | [gh#2961](https://github.com/nats-io/nats-server/discussions/2961) | design | [[core-or-jetstream]] — *One cluster, not two*; [[jetstream-sizing]] — *What enabling JetStream costs a cluster that also carries core NATS*; [[choosing-a-topology]] |
| 195 | Why does a JetStream publish fail with `no responders` during a leader election, and should my client retry it? | jetstream clients | own | measured config | [[publishing]] — *Why a publish can 503*; [[nats-timeout]] — *On a JetStream publish, `no responders` has two causes*; [[nats-go]] — *The publish retry, at v1.53.1* |
| 196 | What happens if a stream captures a subject that is already being used for request/reply? | jetstream core | own | measured gotcha | [[core-or-jetstream]] — *A stream laid over a request/reply subject answers the requests itself*; [[stream]] — *Choosing the subject list*; [[request-reply]] — *A fourth outcome* |
| 197 | Can JetStream be the only source of truth — keep every message forever and replay from the beginning, the way Kafka is used? | jetstream | [so#74129868](https://stackoverflow.com/questions/74129868/is-nats-jetstream-suitable-for-persiting-messages-forever) | design | [[core-or-jetstream]] — *Trade-offs and costs*; [[retention-policies]]; [[stream]] |

**Rows 108–137 were searched for their public form on 2026-09-03** (`inbox/scout-posed-rows-public-form-2026-09-03.md`, phase C step 2): every title, original post, comment and reply of the 484 `nats-io/nats-server` discussions, then the Stack Overflow tags. Twenty-one rows got a URL — a thread that asks the row's question with its trade-off, or one half of it (the scout file says which) — and the row text stayed. Nine (112, 116, 123, 127, 128, 131, 132, 133, 134) keep `own`: searched, not found, recorded in `inbox/scout-backlog.md` §5(a). Row 129's thread is row 57's — 129 is its design form.

**Rows 138–158 were added on 2026-09-03 from the discussions triage** (`inbox/gh-discussions-toc.md`, phase C step 3): every ★ thread — answered and upvoted by someone other than its author, or design-shaped and answered — that no row cited yet. Twenty-four qualified; three were left out with a reason (gh#2933 asks rows 108/111's question again and is listed as a second candidate in the scout file; gh#3164 is a Go test-helper import path; gh#6301 is a defect in a third-party Helm chart, fixed there). `answered by` is filled only where a page already states the answer with a citation and a version — eight rows; the other thirteen are open work. **Row 150 records a contradiction to settle with the binary:** the maintainer's answer in gh#4761 says a request over a service import never gets `No responders` because the import itself is a subscription, while [[cross-account-sharing]] says a matched import with nobody answering fails fast; whichever the server does on 2.14.6 goes on the page, the other into `inbox/docs-issues.md` or the log.

**Rows 159–160 were added on 2026-09-03 from the change layer** (`inbox/plan-change-layer-2026-09-03.md`, phase D step 9): the two questions the release archive answers that no public thread asks in that form — `inbox/gh-discussions-toc.md` and the comment cache were searched for *release notes*, *changelog*, *what's new*, *which version* and *patch release* on 2026-09-03 and hold only gh#3778 (row 63) and a maintainer's "be current with the latest version and patched release". Both are answered on arrival.

**Rows 161–163 were added on 2026-09-03 from the reference layer** (`inbox/plan-the-reference-layer-2026-09-03.md`, phase E step 1): 161 is posed (the discussions index was searched for `$SYS.REQ`, `statsz`, `nats server request` and `system account` — the threads found ask narrower questions, which became rows 162 and 163), and all three were answered on arrival by `reference/system-subjects`, read from `events.go` at v2.14.6 and run on the binary.

**Row 164 was added on 2026-09-03 from the reference layer** (phase E step 2): posed — the discussions index was searched for *storage type*, *cannot change*, *stream edit*, *immutable* and found no thread asking it in this form — and answered on arrival by `reference/stream-and-consumer-config`, read from `stream.go` and `consumer.go` at v2.14.6 and run on the binary (three passes of raw API updates).

**Row 165 was added on 2026-09-03 from the reference layer** (phase E step 3): asked — `nats-io/prometheus-nats-exporter` issue #218, open and unanswered since 2023-04-11, is the public form of the leader-only `num_pending` finding the exporter and surveyor runs produced — and answered on arrival by `reference/metrics` from `consumer.go:5628–5632` at v2.14.6. Rows 139 and 153 were filled by the same step (the counters are exact; `ha_assets` is the Raft-node count and "2k per server" is the maintainers' figure), and row 129 by the page's *The series behind the alerts* table, with the runbook form left to phase G6.

**Rows 166–168 were added on 2026-09-03 from a query** (*Operation: query*, the question of a service in its own account that authorises callers from `Nats-Request-Info` over a service import). 166 and 167 are posed: the discussions index was grepped for `Nats-Request-Info`, `share`, `activation` and `token_req` and no thread asks either in this form. 168 is asked — `nats-io/nats-server` issue #8271, open since 2026-06-07 with the fix PR #8278 unmerged on 2026-09-03. Answered the same day by `concepts/service-import-request-info` (166, 168) and the *Who may import* section of `concepts/cross-account-sharing` (167), written from the query's findings (server at v2.14.6, `client.go:4932–4993`, `accounts.go:2863–2882`, `3046–3087`; jwt v2.8.2 `imports.go:42`, `exports.go:115,120`; a two-account run on 2.14.6 in `local/scratch/runs/share-import/`) are in `wiki/log.md` and wait for a page — a *Cross-account sharing* section or a `service-import-request-info` concept page. Docs issues #79 and #80 came out of the same read.


**Rows 169–171 were added on 2026-09-03 from the client side** (`inbox/plan-the-client-side-2026-09-03.md`,
phase F step 1). 169 and 170 are asked: the discussions comment cache was searched for *subject mapping*,
*mappings*, *max_subscription_tokens*, *nats trace*, *subject length*, *reserved prefix* and *wire tap*
before the rows were posed, and gh#5097 (the docs' 16-token guidance, "probably not strictly enforced"),
gh#2855 ("Wildcards are only applicable for subscriptions") and gh#5172 (the maintainer's rule for where a
mapping belongs) ask them in public. 171 stays `own`: the eight cache lines matching *never arrived* /
*not received* are JetStream consumer threads, none asks the core question. All three answered on arrival
by `concepts/core-nats-delivery`, `concepts/subjects-and-wildcards` and the *Account-level `mappings`*
section of `concepts/subject-transforms`, written from the core-NATS chapter, the server source at
v2.14.6 and eight runs on the binary. Row 25 was filled by the same step from gh#7577's chosen answer.

**Rows 172–174 were added on 2026-09-03 from the client side** (phase F step 2). All three are posed: the
discussions comment cache was grepped for *scatter*, *request many*, *requestMany*, *queue group* with
*busy* / *slow* / *ready* / *round robin* / *load balanc*, and *leaf* with *queue group* before the rows were
written — the one queue-group line found ("Queue subscribers can work on the same subject and round-robin",
gh#7341) is a JetStream thread, and gh#6320's "request many" is a maintainer pointing at orbit.go for
chunked responses. All three answered on arrival by `concepts/request-reply` and `concepts/queue-groups`,
written from the core-NATS chapter, ADR-4 and ADR-47, the server source at v2.14.6 and natscli 0.4.0, and
eight runs in four passes (a standalone server, the lab, a hub with a leafnode). Rows 138 (gh#2760's chosen
answer) and 150 (run G) were filled by the same step.

**Rows 175–179 were added on 2026-09-04 from the client side** (`inbox/plan-the-client-side-2026-09-03.md`,
phase F step 3): all five are posed. The discussions comment cache (`local/scratch/gh-index/`, all 484
`nats-io/nats-server` threads with their comments and replies) was searched first for the public form of
each — *lost/dropped/missing during a reconnect*, *stale connection*, *ping interval* with *detect*,
*drain* with *shutdown / SIGTERM / graceful / in-flight*, *lame duck* with *client / reconnect /
connect_urls*, *max reconnect*, *readiness or liveness probe* — and found only threads that touch the
topic from the **server's** side: gh#6070 (lame duck under systemd, already row 93), gh#3778 (rolling a
cluster), gh#4314 (how nodes work in a cluster), gh#17296's rebalancing advice. Nobody asks these in the
form an application owner holds them, which is exactly the gap phase F exists to close. All five were
answered on arrival by `concepts/client-connection-lifecycle` and `reference/client-defaults`, written
from the `learn/resilient-clients` chapter, nats.go at v1.53.1, natscli at 0.4.0 and five runs in four
passes on nats-server 2.14.6.

**Rows 180–182 were added on 2026-09-04 from the client side** (`inbox/plan-the-client-side-2026-09-03.md`,
phase F step 4): all three are posed. The discussions comment cache (`local/scratch/gh-index/`) was
searched first — *slow consumer*, *messages dropped*, *pending limits*, *authentication expired*,
*authorization violation*, *auth error*, *creds* with *expire*, *IgnoreAuthErrorAbort* — and every
"slow consumer" hit is the **server's** version of the failure (gh#4975 on route slow consumers,
gh#3571's `WriteDeadline`, a `nats top` thread showing two slow consumers with `Pending: 0`), not the
client's own buffer; on the auth side the cache holds one line, a leafnode `Authorization Violation`
in an unrelated thread. Nobody asks these in the form an application owner holds them. All three were
answered on arrival by `gotchas/slow-consumer-in-the-client`, `gotchas/connection-closed-after-auth-error`
and the ripples onto `reference/monitoring-endpoints` and `reference/error-codes`, written from the
`learn/resilient-clients` chapter, `reference/system/errors.md` swept against the server, nats.go at
v1.53.1, and runs A–C on nats-server 2.14.6.
