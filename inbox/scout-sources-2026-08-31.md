# Scout — the NATS source landscape (2026-08-31)

What is available to build this wiki from, in layers. Every URL below was fetched or checked on
2026-08-31; byte counts and version numbers are from that check. Nothing here is ingested yet —
`inbox/plan-first-ingests-2026-08-31.md` picks the order.

## Reference layer — the documentation

| candidate | what it gives | flags |
|---|---|---|
| [docs.nats.io llms.txt](https://docs.nats.io/llms.txt) | the complete documentation index: 863 links under `concepts/`, `learn/`, `reference/`. Every page is served as Markdown by appending `.md` — no HTML scraping needed | ★ start here |
| [learn/deployment/sizing-and-resources.md](https://docs.nats.io/learn/deployment/sizing-and-resources.md) | the docs' own sizing guidance (15.6 kB) | ★ answers Q1 |
| [learn/clustering/](https://docs.nats.io/llms.txt) — `forming-a-cluster`, `placement`, `raft-and-leaders`, `replication-and-r3`, `scaling-and-peers` | the clustering spine, including R3 cost and leader behaviour | ★ |
| [learn/jetstream/](https://docs.nats.io/llms.txt) — 20 pages incl. `delivery-and-acknowledgment`, `policies`, `retention-policies`, `pull-consumers`, `priority-groups`, `message-ttl`, `mirrors-and-sources`, `surviving-node-loss` | the JetStream behaviour spine | ★ |
| [learn/deployment/](https://docs.nats.io/llms.txt) — `config-management`, `hardening`, `kubernetes`, `rolling-upgrades`, `sizing-and-resources` | the runbook spine | ★ |
| [reference/config.md](https://docs.nats.io/reference/config.md) | the config reference root (32 kB); the `reference/config` tree has **728 links**, one per key, generated rather than hand-written — the source for the config-keys and defaults tables | ★ generated |
| `reference/upgrade-to-2.12`, `reference/upgrade-to-2.14` | version-migration notes — the change layer, already written as reference | ★ |
| [learn/monitoring.md](https://docs.nats.io/learn/monitoring.md) + `learn/backup-recovery/*` | monitoring endpoints, backup/restore, disaster recovery | |

## Internals layer — the ADRs

[nats-io/nats-architecture-and-design](https://github.com/nats-io/nats-architecture-and-design) —
**54 ADRs**, each with `Date / Author / Status / Tags` metadata. Already copied into `raw/adr/`
and triaged into `inbox/adr-toc.md` (22 flagged ★ = server-tagged and shipped). Status spread:
26 Implemented, 14 Approved, 7 Partially Implemented, 4 Proposed, 3 Deprecated. This is where
KV/Object-Store-on-streams, ordered consumers, priority groups, per-message TTL, batch publish
and the JetStream API design are actually specified.

## Change layer — releases

[nats-io/nats-server releases](https://github.com/nats-io/nats-server/releases) — latest stable
**v2.14.6** (2026-08-27); maintained minors **2.10, 2.11, 2.12, 2.14** (there is no 2.13 — `v2.13.0`
is a 404), plus `v2.15.0-preview.1` (2026-08-24). One summary per minor release, plus the
patch-level notes that change a default or fix a gotcha.

## Applied layer — blog and examples

| candidate | what it gives | flags |
|---|---|---|
| [JetStream Anti-Patterns: Avoid these pitfalls to scale more efficiently](https://www.synadia.com/blog/jetstream-design-patterns-for-scale) (2026-06-06, Andrew Connolly) | a ready-made gotchas section: e.g. hundreds of disjoint consumer subject filters cause slowness and instability | ★ gotchas |
| [Understanding JetStream Memory Usage Patterns](https://www.synadia.com/blog/nats-jetstream-high-ram-usage) | RAM behaviour — feeds sizing and the memory gotcha (Q10) | ★ sizing |
| [Pull Consumer Priority Groups](https://www.synadia.com/blog/pull-consumer-priority-groups) | overflow / pinned / prioritized routing — pairs with ADR-42 | technique |
| [Partitioned Consumer Groups](https://www.synadia.com/blog/partitioned-consumer-groups) | ordered, scalable processing — the partitioning pattern people keep asking for | pattern |
| [Mirror Streams in NATS JetStream](https://www.synadia.com/blog/mirror-streams-jetstream) | one-way replication — DR patterns | pattern |
| [Scaling NATS for Per-User Real-Time Notifications](https://www.synadia.com/blog/scaling-nats-per-user-notifications) | a worked scale story | |
| [NATS by Example](https://natsbyexample.com) | runnable examples per client and use case | reference |

## Gotcha layer — public Q&A

- [nats-io/nats-server Discussions](https://github.com/nats-io/nats-server/discussions) — **484
  threads** read by title on 2026-08-31 (351 Q&A, 99 General, 33 Ideas, 1 Show and tell). This is
  the richest operator-symptom source there is; 76 of the 82 rows in `inbox/question-bank.md` come
  from here. Ingest by searching for the question, not by crawling.
- Stack Overflow tags `nats-jetstream`, `nats.io`, `nats-server` — 257 unique questions collected;
  weaker than Discussions but covers the client-side framing of the same problems.
- [nats-io/nats-server issues](https://github.com/nats-io/nats-server/issues) — 544 open on
  2026-08-31; useful for "is this a known bug in version X" once a gotcha page exists.

## Ground-truth layer — the source

[nats-io/nats-server](https://github.com/nats-io/nats-server) (20.6k stars, default branch `main`)
— not for wholesale ingestion. Two uses: the **defaults and limits** table built from the
constants in the code (with file path and version next to every value), and the internals pages
on filestore, raft and the meta layer where the ADRs stop.

## Tooling entities worth their own page

[natscli](https://github.com/nats-io/natscli) (the `nats` CLI), [k8s / Helm charts](https://github.com/nats-io/k8s),
`nsc`, the Prometheus exporter, `nats-top`. Each gets an entity page with a cheat sheet; the
viewer collects those plus the per-tool `###` sections of the operations pages.

## Status

Nothing ingested yet except `raw/adr/` (copied, not summarized). Next: the plan file.
