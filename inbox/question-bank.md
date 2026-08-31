# Question bank — what this wiki must answer

The scope test and the scoreboard. Every row is a question an operator or architect actually
asked **in public**, with a link to where it was asked. A page belongs in this wiki if it helps
answer a row here; a row is *answered* only when a page states the answer with a citation and a
version — not when a page merely touches the topic.

- `★` marks the questions that must be answerable for the wiki to be useful at all.
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
| 1 | How do I size a 3-node R3 JetStream cluster (disk, RAM, IOPS) for a given message rate, size and retention? | jetstream deploy | [gh#6879](https://github.com/nats-io/nats-server/discussions/6879) | ★ sizing | |
| 2 | How much disk does a stream actually use beyond the raw message bytes (blocks, index, per-subject state)? | jetstream | [gh#5742](https://github.com/nats-io/nats-server/discussions/5742) | ★ sizing internals | |
| 3 | What does a stream actually cost in resources, and how do I run JetStream in the most resource-effective way? | jetstream | [gh#4227](https://github.com/nats-io/nats-server/discussions/4227) | ★ sizing | |
| 4 | Is there a practical cap on the number of messages in a single stream? | jetstream | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) | sizing | |
| 5 | What is the largest known-good value for MaxMsgs on a stream? | jetstream | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) | sizing config | |
| 6 | How many consumers can one stream and one server support before it hurts? | jetstream | [gh#7863](https://github.com/nats-io/nats-server/discussions/7863) | ★ sizing | |
| 7 | Why does publisher throughput collapse when many consumers attach to the stream? | jetstream | [gh#6274](https://github.com/nats-io/nats-server/discussions/6274) | ★ sizing gotcha | |
| 8 | Why is my async publish throughput far below the numbers in the docs? | jetstream | [gh#7599](https://github.com/nats-io/nats-server/discussions/7599) | sizing gotcha | |
| 9 | Does a high-cardinality subject space hurt stream performance? | jetstream | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) | sizing | |
| 10 | Why does server memory grow with the number of unacknowledged (pending) messages? | core jetstream | [gh#6820](https://github.com/nats-io/nats-server/discussions/6820) | sizing gotcha | |
| 11 | How do I scale core NATS for bursty traffic — bigger nodes, more nodes, or partitioning? | core topology | [gh#7738](https://github.com/nats-io/nats-server/discussions/7738) | sizing | |
| 12 | What breaks if I raise max_payload above 8MB, and what is the real limit? | core | [gh#7068](https://github.com/nats-io/nats-server/discussions/7068) | ★ config sizing | |
| 13 | Why is JetStream startup and recovery slow with tens of millions of messages? | jetstream | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) | gotcha sizing | |
| 14 | Why does my consumer keep redelivering messages that were acknowledged? | jetstream | [so#78603662](https://stackoverflow.com/questions/78603662/nats-jetstream-messages-being-processed-multiple-times-by-my-consumer-even-when) | ★ gotcha | |
| 15 | What does max_ack_pending actually do, and what happens when it is reached? | jetstream | [gh#5211](https://github.com/nats-io/nats-server/discussions/5211) | ★ config gotcha | |
| 16 | How do ack_wait and the duplicate window interact? | jetstream | [gh#6628](https://github.com/nats-io/nats-server/discussions/6628) | gotcha config | |
| 17 | Does JetStream support exponential backoff for redelivery? | jetstream | [gh#6350](https://github.com/nats-io/nats-server/discussions/6350) | config | |
| 18 | Why doesn't a NAK cause an immediate redelivery? | jetstream | [gh#5631](https://github.com/nats-io/nats-server/discussions/5631) | gotcha | |
| 19 | Does NakWithDelay hold a max_ack_pending slot and block other messages? | jetstream | [gh#4972](https://github.com/nats-io/nats-server/discussions/4972) | gotcha | |
| 20 | What happens when several consumers share a durable name with different filter subjects on a WorkQueue stream? | jetstream | [gh#6044](https://github.com/nats-io/nats-server/discussions/6044) | ★ gotcha | |
| 21 | What does "disjoint filter subjects" mean for a WorkQueue stream? | jetstream | [gh#3637](https://github.com/nats-io/nats-server/discussions/3637) | config | |
| 22 | How do I inspect which messages are still pending in a work-queue stream? | jetstream monitoring | [gh#4778](https://github.com/nats-io/nats-server/discussions/4778) | ★ monitoring | |
| 23 | Does JetStream give exactly-once delivery, and how does the dedup window work? | jetstream | [so#72814502](https://stackoverflow.com/questions/72814502/nats-jetstream-exactly-once-delivery) | ★ concept | |
| 24 | What ordering does JetStream guarantee, and per what — stream, subject, key? | jetstream | [so#68984906](https://stackoverflow.com/questions/68984906/does-nats-jetstream-provide-message-ordering-by-a-key) | concept | |
| 25 | What ordering guarantees does core NATS give? | core | [gh#7577](https://github.com/nats-io/nats-server/discussions/7577) | concept | |
| 26 | What happens when JetStream runs out of disk? | jetstream | [gh#5924](https://github.com/nats-io/nats-server/discussions/5924) | ★ gotcha | |
| 27 | How do I recover a stream that is full under a DiscardNew policy? | jetstream | [gh#2794](https://github.com/nats-io/nats-server/discussions/2794) | gotcha runbook | |
| 28 | How do per-message TTLs and subject delete markers behave? | jetstream | [gh#7227](https://github.com/nats-io/nats-server/discussions/7227) | config | |
| 29 | Can the server schedule a message for later, with cron-style patterns? | jetstream | [gh#7672](https://github.com/nats-io/nats-server/discussions/7672) | config | |
| 30 | Message scheduler vs NAK-with-delay for scheduled work at scale — which one? | jetstream | [gh#7628](https://github.com/nats-io/nats-server/discussions/7628) | pattern | |
| 31 | How does JetStream filestore compression work and what does it cost? | jetstream | [gh#5259](https://github.com/nats-io/nats-server/discussions/5259) | sizing internals | |
| 32 | How do I back up and restore JetStream, including memory streams? | jetstream | [gh#4342](https://github.com/nats-io/nats-server/discussions/4342) | ★ runbook | |
| 33 | Can I change the replica count of a live stream, and why does it fail with "no suitable peers for placement"? | jetstream topology | [gh#7982](https://github.com/nats-io/nats-server/discussions/7982) | ★ gotcha | |
| 34 | How do I rebalance streams after adding nodes to a cluster? | topology | [gh#7215](https://github.com/nats-io/nats-server/discussions/7215) | ★ runbook | |
| 35 | How do I move a stream to a different set of peers? | topology | [gh#2730](https://github.com/nats-io/nats-server/discussions/2730) | runbook | |
| 36 | Why does the cluster report no quorum and stall on JetStream consumers? | topology | [gh#3210](https://github.com/nats-io/nats-server/discussions/3210) | ★ gotcha | |
| 37 | What causes unexpected quorum loss after days of stable operation? | topology | [gh#7533](https://github.com/nats-io/nats-server/discussions/7533) | gotcha | |
| 38 | Why were my streams marked orphan and deleted when converting a standalone server into a cluster? | topology | [gh#7831](https://github.com/nats-io/nats-server/discussions/7831) | ★ gotcha | |
| 39 | How do I find out what corrupted a JetStream cluster, and how do I recover it? | topology | [gh#7463](https://github.com/nats-io/nats-server/discussions/7463) | ★ gotcha runbook | |
| 40 | How should a cluster survive hardware failure of one or more nodes? | topology | [gh#6892](https://github.com/nats-io/nats-server/discussions/6892) | runbook | |
| 41 | Leafnode, gateway or cluster — when do I use which? | topology | [gh#6328](https://github.com/nats-io/nats-server/discussions/6328) | ★ concept | |
| 42 | Why aren't my streams visible on both ends of a leafnode connection? | topology | [gh#7834](https://github.com/nats-io/nats-server/discussions/7834) | ★ gotcha | |
| 43 | How do I set up cross-domain JetStream sourcing? | topology | [gh#7881](https://github.com/nats-io/nats-server/discussions/7881) | runbook | |
| 44 | Why do I get duplicate messages on a leafnode cluster connected to a supercluster? | topology | [gh#4823](https://github.com/nats-io/nats-server/discussions/4823) | gotcha | |
| 45 | How do I get multi-region availability without paying for cross-region latency? | topology | [gh#7438](https://github.com/nats-io/nats-server/discussions/7438) | ★ pattern | |
| 46 | What causes performance degradation in a global supercluster? | topology | [gh#7494](https://github.com/nats-io/nats-server/discussions/7494) | gotcha | |
| 47 | Why does an asymmetric cluster configuration fail to form? | topology | [gh#7190](https://github.com/nats-io/nats-server/discussions/7190) | gotcha | |
| 48 | How do I restrict which subjects a leafnode exports and imports? | topology security | [gh#5941](https://github.com/nats-io/nats-server/discussions/5941) | config | |
| 49 | How do I set up operator / account / user JWTs correctly? | security | [gh#7854](https://github.com/nats-io/nats-server/discussions/7854) | ★ runbook | |
| 50 | How do I rotate TLS certificates without downtime, and how do I detect expiry? | security | [gh#7684](https://github.com/nats-io/nats-server/discussions/7684) | ★ runbook | |
| 51 | How do I share a stream or KV bucket between accounts? | security jetstream | [gh#7017](https://github.com/nats-io/nats-server/discussions/7017) | ★ config | |
| 52 | How do I prevent a user from creating durable consumers or exceeding account limits? | security | [gh#5044](https://github.com/nats-io/nats-server/discussions/5044) | config | |
| 53 | When should I use auth callout, and what does the server validate before calling it? | security | [gh#7505](https://github.com/nats-io/nats-server/discussions/7505) | concept | |
| 54 | How do I add accounts and reload a running cluster without dropping clients? | security deploy | [gh#5890](https://github.com/nats-io/nats-server/discussions/5890) | ★ runbook | |
| 55 | Which configuration changes actually take effect on reload, and which need a restart? | deploy | [gh#7126](https://github.com/nats-io/nats-server/discussions/7126) | ★ config gotcha | |
| 56 | How do I deny unauthenticated connections without breaking system users? | security | [gh#4535](https://github.com/nats-io/nats-server/discussions/4535) | gotcha | |
| 57 | Which endpoints and metrics should I actually alert on for a JetStream cluster? | monitoring | [gh#6182](https://github.com/nats-io/nats-server/discussions/6182) | ★ runbook | |
| 58 | How do I find which consumer the server has flagged as slow? | monitoring | [gh#6605](https://github.com/nats-io/nats-server/discussions/6605) | ★ gotcha | |
| 59 | Are there metrics for acked, naked, terminated and redelivered messages? | monitoring jetstream | [gh#6962](https://github.com/nats-io/nats-server/discussions/6962) | monitoring | |
| 60 | How is CPU % in /varz measured, and why does it look wrong in containers? | monitoring | [gh#7483](https://github.com/nats-io/nats-server/discussions/7483) | gotcha | |
| 61 | How are the RTT values in /routez and /connz measured? | monitoring | [gh#7362](https://github.com/nats-io/nats-server/discussions/7362) | monitoring | |
| 62 | How do I read and act on JetStream warnings in the server log? | monitoring jetstream | [gh#6490](https://github.com/nats-io/nats-server/discussions/6490) | ★ gotcha | |
| 63 | How do I roll a cluster onto a new server version safely? | deploy | [gh#3778](https://github.com/nats-io/nats-server/discussions/3778) | ★ runbook | |
| 64 | What are the data-integrity risks when upgrading across minor versions? | deploy | [gh#4781](https://github.com/nats-io/nats-server/discussions/4781) | ★ runbook | |
| 65 | Should JetStream use hostPath or a PVC on Kubernetes? | deploy | [gh#7749](https://github.com/nats-io/nats-server/discussions/7749) | ★ config | |
| 66 | How do I grow the JetStream volume on Kubernetes? | deploy | [gh#6601](https://github.com/nats-io/nats-server/discussions/6601) | gotcha runbook | |
| 67 | LoadBalancer or seed URLs — how should clients reach a cluster on Kubernetes? | deploy clients | [gh#6094](https://github.com/nats-io/nats-server/discussions/6094) | pattern | |
| 68 | Why did throughput drop after moving from Kubernetes to a standalone VM (or back)? | deploy | [gh#6594](https://github.com/nats-io/nats-server/discussions/6594) | sizing gotcha | |
| 69 | Why does my KV watcher miss updates, and how do I watch many keys at once? | kv | [gh#6746](https://github.com/nats-io/nats-server/discussions/6746) | ★ gotcha | |
| 70 | How do I count the keys in a KV bucket without fetching them all? | kv | [gh#7365](https://github.com/nats-io/nats-server/discussions/7365) | gotcha | |
| 71 | Does KV support a TTL per key, and since which version? | kv | [gh#7264](https://github.com/nats-io/nats-server/discussions/7264) | config | |
| 72 | Why doesn't deleting or purging keys reclaim disk space in a bucket? | kv | [gh#6015](https://github.com/nats-io/nats-server/discussions/6015) | ★ gotcha | |
| 73 | When is KV or Object Store the wrong tool — where does Redis or a database win? | kv objectstore | [so#75576454](https://stackoverflow.com/questions/75576454/nats-object-store-or-key-value-store-vs-redis-cache) | concept | |
| 74 | How do I implement a distributed lock or lease with KV? | kv | [so#79400839](https://stackoverflow.com/questions/79400839/how-to-use-nats-kv-for-distributed-locking) | pattern | |
| 75 | Why is listing an object-store bucket slow (or timing out) while uploads run? | objectstore | [gh#6836](https://github.com/nats-io/nats-server/discussions/6836) | gotcha | |
| 76 | Why is a KV mirror on file storage far slower than on memory storage? | kv | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) | gotcha internals | |
| 77 | What does an unexpected `nats: timeout` actually mean, and how do I trace it? | core | [gh#5859](https://github.com/nats-io/nats-server/discussions/5859) | ★ gotcha | |
| 78 | How many WebSocket connections can a single server sustain? | interop | [gh#2770](https://github.com/nats-io/nats-server/discussions/2770) | sizing | |
| 79 | How do I run NATS WebSocket behind nginx or another proxy? | interop deploy | [gh#7375](https://github.com/nats-io/nats-server/discussions/7375) | runbook | |
| 80 | How does MQTT QoS 1/2 map onto JetStream, and what does it cost? | interop | [gh#7641](https://github.com/nats-io/nats-server/discussions/7641) | concept | |
| 81 | How do I restrict MQTT client ids per account with JWT? | interop security | [gh#7397](https://github.com/nats-io/nats-server/discussions/7397) | config | |
| 82 | How do I track client connect and disconnect events? | monitoring core | [gh#6445](https://github.com/nats-io/nats-server/discussions/6445) | runbook | |

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

