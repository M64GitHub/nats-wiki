# Plan — runbooks and security (proposed 2026-08-31)

Say **`start the plan`** to work this file; `CLAUDE.md` → *Operation: plan* says how. One step at a
time, `status:` rewritten in place, `wiki/log.md` appended, lint run, question-bank cells filled,
and each step reported before the next begins.

**Why this plan.** `inbox/plan-first-ingests-2026-08-31.md` finished with **22 of 35 ★ rows still
unanswered**, and they cluster hard: **eight are runbooks**, **six are security**, **four are
topology**. The concept and reference layers are now deep enough that the missing pages are almost
all *procedures* — the thing an operator does, in order, with verification and a rollback. Nine
finished pages already link to [[account]], which does not exist; [[upgrade-a-cluster]] is the only
reason Q63 and Q64 are still blank, and both were "covered in substance" by step 4.

**Done when:** every ★ row in the runbook, security and topology clusters has an `answered by` page,
and no page in `wiki/operations/` states a command that has not been read from a source.

**Already local — no fetching needed for steps 1–4:** `raw/nats-docs/learn/deployment/` (6 pages),
`learn/backup-recovery/` (5), `learn/security/` (9), `learn/topologies/` (7), plus
`learn/clustering/forming-a-cluster.md` and `scaling-and-peers.md`, which steps 1 and 5 of the last
plan skipped. Step 5 needs GitHub threads and is the only one that fetches.

---

## Step 1 — the install and cluster runbooks · status: open

```
ingest raw/nats-docs/learn/topologies/single-server.md
ingest raw/nats-docs/learn/topologies/your-first-cluster.md
ingest raw/nats-docs/learn/clustering/forming-a-cluster.md
ingest raw/nats-docs/learn/deployment/hardening.md
```

Creates [[install-nats-server]] and [[build-a-3-node-cluster]] (`kind: runbook`): goal,
preconditions, one `###` section per surface (`nats-server` config, `nats` CLI, systemd, Docker,
Kubernetes via [[nats-helm-charts]]), **verify with the command and its expected output**, rollback,
pitfalls. The install commands are already summarised in [[s-docs-getting-started]]; the hardening
page is where the service-unit limits (`LimitNOFILE=800000`) come from.

## Step 2 — upgrade, reload and rebalance · status: open

```
ingest raw/nats-docs/learn/deployment/rolling-upgrades.md
ingest raw/nats-docs/learn/deployment/config-management.md
ingest raw/nats-docs/learn/clustering/scaling-and-peers.md
```

Creates [[upgrade-a-cluster]] (**Q63, Q64** — held open through step 4 only for want of this page)
and a reload/rebalance runbook (**Q34, Q54, Q55**). `inbox/config-keys-table.md` already records
**411 reloadable keys of 621**, so Q55's answer is half-built: the runbook needs the *procedure* and
the classes of change that need a restart, then [[config-keys]] can cite it.

## Step 3 — backup, restore and disaster recovery · status: open

```
ingest raw/nats-docs/learn/backup-recovery/stream-backup-restore.md
ingest raw/nats-docs/learn/backup-recovery/config-and-jwt-backup.md
ingest raw/nats-docs/learn/backup-recovery/disaster-recovery.md
ingest raw/nats-docs/learn/backup-recovery/mirrors-and-sources.md
ingest raw/nats-docs/learn/jetstream/mirrors-and-sources.md
```

Creates [[backup-and-restore-jetstream]] (**Q32**, which explicitly asks about **memory** streams —
say plainly if the sources do not cover them) and [[mirrors-and-sources]], a wanted concept page
linked from four others. Disaster recovery feeds **Q39**. ADR-61 (*Unsafe meta group quorum rescue*,
2.15) is the matching ADR and is still unread.

## Step 4 — security and multi-tenancy · status: open — **the biggest gap in the wiki**

```
ingest raw/nats-docs/learn/security/authentication-basics.md
ingest raw/nats-docs/learn/security/authorization.md
ingest raw/nats-docs/learn/security/accounts-and-multitenancy.md
ingest raw/nats-docs/learn/security/operator-mode.md
ingest raw/nats-docs/learn/security/decentralized-auth.md
ingest raw/nats-docs/learn/security/cross-account.md
ingest raw/nats-docs/learn/security/encryption.md
ingest raw/nats-docs/learn/security/auth-callout.md
```

Creates the `security` facet, which is currently **empty**: [[account]] (the most-linked wanted page
in the wiki), an operator-mode runbook (**Q49**), [[rotate-tls-certificates]] (**Q50**), a
cross-account sharing page (**Q51**), and an auth-callout page. [[nsc]], [[nk]] and [[nats-cli]]
already carry the command surfaces these runbooks need — the runbooks should link them, not repeat
them.

## Step 5 — the second gotcha pass · status: open

Do **not** crawl. Take the ★ symptom rows still blank after steps 1–4 — **Q26** (out of disk),
**Q39** (corrupted cluster), **Q42** (streams invisible across a leafnode), **Q62** (JetStream
warnings in the log), **Q69** (KV watcher misses updates), **Q77** (`nats: timeout`) — open the
linked thread with `tools/extract-forum-posts.py`, and write one gotcha page per symptom. A page
with no confirmed fix is still worth writing; [[slow-consumer-detected]] is the model.

## Step 6 — topology · status: open

```
ingest raw/nats-docs/learn/topologies/leaf-nodes.md
ingest raw/nats-docs/learn/topologies/super-clusters.md
ingest raw/nats-docs/learn/topologies/jetstream-in-a-cluster.md
ingest raw/nats-docs/learn/topologies/putting-it-together.md
```

Creates [[leafnode]] and [[gateway]] (both wanted), a "which topology when" concept page (**Q41**)
and a multi-region pattern page (**Q45**). This is last because every topology question so far has
turned out to need the security model first — a leafnode is an account boundary before it is a
network one.

---

## Method notes

- **The docs-issue sweep is not optional** (`CLAUDE.md` → *Operation: record a docs issue*). The
  security and backup pages are hand-written rather than generated, so the failure mode to expect is
  **staleness**, as in `inbox/docs-issues.md` #8–9, not generator error as in #1–3.
- **Runbooks are where invented facts do the most damage.** A wrong flag in a concept page misleads;
  a wrong flag in a restore runbook loses data. Every command in `wiki/operations/` must be quoted
  from a source, and anything not sourced must be absent, not guessed.
- **Re-check the entity facts before citing them.** `python3 tools/fetch-repo-facts.py --refresh`
  re-reads all 32 repos in one pass; versions in [[s-github-repo-facts]] date from 2026-08-31.
- The question bank was mined 2026-08-31 and now holds **87 rows, 25 answered**. Re-mine when it
  goes stale; a row without a link to someone actually asking it does not belong in the table.
