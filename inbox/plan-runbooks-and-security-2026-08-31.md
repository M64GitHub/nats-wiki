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

## Step 0 — pay off the four most-cited wanted pages · status: done 2026-08-31 — s-docs-get-direct, s-adr-31-direct-get, s-docs-worker-pool, s-docs-mirrors-and-sources, s-docs-mirrors-as-dr, s-docs-accounts-and-multitenancy → [[direct-get]], [[account]], [[worker-pool]], [[mirrors-and-sources]]. **ADR-31 ingested beyond the list** — the docs page names it as the authoritative spec and it carries the subjects, headers, status codes and `mirror_direct` rules the docs omit (`inbox/adr-toc.md` now shows 8 of 54 read). Ripple: [[js-api-subjects]] (both Direct Get subjects rewritten), [[error-codes]] (`10060`), [[replicas]] (reads served from outside the cluster). Answered Q88; extended Q15 and Q22; added Q88–Q91, two of them deliberately unanswered. Wanted pages 17 → 13; lint clean at 107 pages. **Step 4 must link [[account]], not restate it** — this page covers config mode only, and says so in its `## To verify`.

Added 2026-08-31 after measuring the link graph. These four are **already cited by other pages** and
resolve to nothing, so a reader hits a red link today; all four have their sources local. Cheapest
real improvement available, and it closes `## To verify` items on the pages that cite them.

```
ingest raw/nats-docs/learn/jetstream/get-direct.md
ingest raw/nats-docs/learn/jetstream/worker-pool.md
ingest raw/nats-docs/learn/jetstream/mirrors-and-sources.md
ingest raw/nats-docs/learn/backup-recovery/mirrors-and-sources.md
ingest raw/nats-docs/learn/security/accounts-and-multitenancy.md
```

| page | demand | type |
|---|---|---|
| [[direct-get]] | 11 links from 9 pages | concept |
| [[account]] | 11 links from 7 pages | concept |
| [[worker-pool]] | 10 links from 7 pages | operation, `kind: pattern` |
| [[mirrors-and-sources]] | 7 links from 6 pages | concept |

[[account]] is the **concept** page here — the operator-mode and cross-account *runbooks* stay in
step 4, which should link this page rather than restate it. Watch for overlap and say so in step 4's
status line.

## Step 1 — the install and cluster runbooks · status: done 2026-08-31 — s-docs-single-server, s-docs-your-first-cluster, s-docs-forming-a-cluster, s-docs-hardening, s-nats-server-systemd-units, s-nats-server-route-cluster-formation, s-gh-7190-asymmetric-cluster, s-gh-3569-connect-to-route-port, s-gh-6070-lame-duck-under-systemd → [[install-nats-server]], [[build-a-3-node-cluster]]. **Five ingests beyond the list**, all forced by the rule that a runbook may not quote a command it has not read: the docs' systemd extract turned out to omit `User=`, `Group=`, `ExecStop=` and `TimeoutStopSec=`, so `util/nats-server-hardened.service` was read at v2.14.6 and quoted instead; `server/route.go` was read to check a log line and produced **docs issue #11** (an *unset* `cluster.name` is adopted from the peer, not rejected — the docs describe only the configured-name branch); and three GitHub threads (gh#7190 unequal route counts from a multi-value DNS route address, gh#3569 `attempted to connect to route port`, gh#6070 a unit whose `ExecStop` sends SIGINT and never drains) each supplied a pitfall no docs page carries. Ripple: [[defaults-and-limits]] (`lame_duck_duration` `2m`, `lame_duck_grace_period` `10s`), [[error-codes]] (`10074`), [[config-keys]] (the lame-duck keys, `cluster.port`, **corrected reload counts**), [[monitoring-endpoints]] (the `127.0.0.1` bind that breaks Kubernetes probes), [[replicas]], [[jetstream-sizing]], [[nats-server]], [[nats-cli]], [[streams-deleted-when-clustering-a-standalone-server]]. **Tool bug fixed**: `tools/build-config-table.py` never read the root `reference/config.md`, so every top-level key lost the default and reload marking the docs *do* state — 179 → **216 stated defaults**, and the reload split moved to 261/150/174/36. Answered Q47, Q92, Q93; **93 rows, 29 answered**. Wanted pages 13 → 11; lint clean at 118 pages.

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

## Step 2 — upgrade, reload and rebalance · status: done 2026-08-31 — s-docs-rolling-upgrades, s-docs-config-management, s-docs-scaling-and-peers, s-nats-server-signals, s-nats-server-lame-duck, s-nats-helm-chart-values-2.14.6 → [[upgrade-a-cluster]], [[reload-server-config]], [[rebalance-streams]]. **Three pages, not the one the plan named**: reload and rebalance are different operations with different questions (Q54/Q55 vs Q34) and merging them would have produced a page that answers neither cleanly. **Three ingests beyond the list**, all verification that turned into sources: `server/signal.go` (what each signal does — `--signal stop` is **SIGKILL**, `SIGUSR1` is log rotation, SIGTERM is ignored mid-drain, which confirms the docs), the Helm chart's `values.yaml` **at its release tag** (the lame-duck defaults leave *zero* slack: 10 + 30 + 20 = 60 exactly), and `Server.lameDuckMode()` itself — which produced **docs issue #13**: `lame_duck_duration` governs client disconnects only, the Raft stepdown and JetStream shutdown happen *before* the timer with a fixed 1s wait, the spread is `duration − grace`, and the per-client interval is capped at 1s. The docs' sizing advice and its matching pitfall both aim at the wrong knob. **#14** records the same page using "grace period" for two keys with opposite requirements two paragraphs apart. Ripple: [[error-codes]] (`10075`, `10202`), [[config-keys]], [[defaults-and-limits]], [[raft-in-nats]] (meta election vs stream election, and why the meta-leader goes last), [[nats-helm-charts]] (three chart facts read from the chart), [[nats-cli]], [[install-nats-server]], [[build-a-3-node-cluster]]. Answered **Q34, Q54, Q55, Q63, Q64** and completed Q93 — **93 rows, 34 answered**. Wanted pages 11 → 10; lint clean at 127 pages.

```
ingest raw/nats-docs/learn/deployment/rolling-upgrades.md
ingest raw/nats-docs/learn/deployment/config-management.md
ingest raw/nats-docs/learn/clustering/scaling-and-peers.md
```

Creates [[upgrade-a-cluster]] (**Q63, Q64** — held open through step 4 only for want of this page)
and a reload/rebalance runbook (**Q34, Q54, Q55**). `inbox/config-keys-table.md` already records
**411 reloadable keys of 621**, so Q55's answer is half-built: the runbook needs the *procedure* and
the classes of change that need a restart, then [[config-keys]] can cite it.

## Step 3 — backup, restore and disaster recovery · status: done 2026-08-31 — s-docs-stream-backup-restore, s-docs-disaster-recovery, s-docs-config-and-jwt-backup, s-nats-server-snapshot-restore, s-natscli-backup-restore, s-gh-4342-memory-stream-backup → [[backup-and-restore-jetstream]], [[disaster-recovery]], [[backup-and-restore-identity]]. The plan's last two ingests were **already done in step 0** ([[mirrors-and-sources]] exists), so the three remaining docs pages were read plus **three sources the work forced**: `memstore.go`/`jetstream_api.go`/`stream.go` (the snapshot path), `natscli` **v0.4.0** `stream_command.go` (every backup/restore flag), and **gh#4342**, the thread Q32 was mined from. **Q32's memory-stream half is now answered with the real error**: a memory stream fails with **`snapshot failed: no impl` (10064)**, not the documented `memory streams do not support snapshots` — **docs issue #15 ★**. Three more followed: **#16** (the restore rename message is the CLI's, and plural), **#17** (`chunk_size`'s documented maximum is int64; the server clamps to **1 MiB**), **#18** (`nats stream restore` takes `--config`, `--cluster`, `--tag`, `--replicas` — a snapshot can be restored into another cluster at a different replica count, which the whole backup chapter omits). Ripple: [[error-codes]] (`10064`, `10065`, `10130`), [[stream]] (memory storage gives up backup, not just durability), [[replicas]] (**R3 is not a backup**), [[mirrors-and-sources]], [[nats-cli]]. **Two question-bank rows were corrected rather than filled**: gh#6892 (Q40) turns out to ask how to *evict a sick-but-alive node by IP*, which no page answers — the row's wording was fixed and left open; and a row citing gh#4342 for identity backup was removed after reading the thread, which is about memory streams. **[[backup-and-restore-identity]] has no bank row**: searches of `nats-io/nats-server` discussions and `nats-io/nsc` issues found nobody asking about identity backup in public. The page stays — a restored stream nobody can authenticate against is not a recovery — and the gap is recorded here rather than papered over with an invented source. Answered **Q32**; **93 rows, 35 answered**. Wanted pages 10 → 9; lint clean at 136 pages.

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

## Step 4 — security and multi-tenancy · status: done 2026-08-31 — s-docs-authentication-basics, s-docs-authorization, s-docs-cross-account, s-docs-operator-mode, s-docs-decentralized-auth, s-docs-auth-callout, s-docs-encryption-and-tls, s-docs-security-checklist, s-nats-server-auth-and-tls, s-natscli-account-tls, s-gh-7854-jwt-push-timeout, s-gh-7684-certificate-expiry, s-gh-7017-kv-across-accounts, s-gh-5044-restrict-durable-consumers, s-gh-7505-auth-callout-nkey, s-gh-4535-unauthenticated-connections, s-gh-5606-cross-account-jetstream → [[subject-permissions]], [[operator-mode]], [[auth-callout]], [[tls-in-nats]], [[cross-account-sharing]], [[set-up-operator-mode]], [[rotate-tls-certificates]], [[unauthenticated-clients-still-connect]]. **[[account]] was linked, not restated**, as step 0 required — its three `## To verify` items are now resolved and it gained a *two configuration models* section pointing at [[operator-mode]]. **Nine ingests beyond the list**, each forced by a bank row the docs do not answer: seven GitHub threads (one per open ★/unresolved row), `nats-server` v2.14.6 across eight files, and `natscli` v0.4.0. Three findings no source carries: **`nats account tls`** — a chain-wide certificate check with `--expire-warn` (default `1w`) and a non-zero exit, named by neither the docs nor gh#7684, and the real answer to Q50's detection half; **auth callout verifies nothing the client presented** (`fillConnectOpts` copies `Nkey`/`SignedNonce`/`Token`/`Username`/`Password` verbatim — but the server fills `client_info.nonce`, so the service can do the challenge-response itself); and **the `$G` user the server invents** (`server.go:1445`, four exact conditions, with `auth_required` left `true` at `server.go:3290`) — which narrows the 2023 rule of thumb behind gh#4535 to what the 2.10.2 fix actually left. **Docs issues #19–#21, all ★**: #19 is the biggest sweep yet — **15 timeout defaults** in the generated reference, **10 verified wrong** (`tls.timeout` `500ms` vs **2s**; `authorization.timeout` `1` vs **2s / `tls_timeout + 1`**), one documenting an option (`websocket.tls.timeout`) the server does not have; #20 `/varz`'s `tls_cert_not_after` exists since PR #7709 and the 861-page tree never names it; #21 the `external` block is required, undocumented, and pointed at a reference page that omits it — which is why gh#7017 has sat unanswered since 2025-06-29. **A wiki bug fixed, not just recorded**: [[config-keys]] had repeated `500ms`/`1` *and rationalised the discrepancy*; both sections are rewritten against the server and the page now states the server-over-docs rule. Ripple: [[account]], [[config-keys]], [[defaults-and-limits]], [[monitoring-endpoints]], [[error-codes]] (10021/10022/10024), [[js-api-subjects]] (a `$SYS` claims/callout table), [[key-value]], [[nats-cli]], [[nsc]], [[install-nats-server]], [[build-a-3-node-cluster]], [[reload-server-config]], [[backup-and-restore-identity]]. Answered **Q49, Q50, Q52, Q53, Q56, Q90**; added Q94–Q98. **98 rows, 44 answered.** **Q51 stays open deliberately** — the wiki names both routes and their fields, but no public source gives the configuration, and the bank now records why. Wanted pages 9 → 8; lint clean at 161 pages.

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

## Step 5 — the second gotcha pass · status: done 2026-08-31 — s-gh-5924-filestore-dirs-vanished, s-gh-7463-jetstream-corruption, s-gh-7834-leafnode-same-js-domain, s-gh-6490-high-message-lag, s-gh-6746-watch-many-keys, s-gh-5243-kv-watchers-at-scale, s-gh-5859-unexpected-nats-timeout, s-issue-4281-insufficient-storage, s-issue-8322-dynamic-maxstore-shrinks, s-nats-server-jetstream-resources, s-nats-server-leafnode-js-domains, s-nats-server-jetstream-log-warnings → [[jetstream-out-of-disk]], [[stream-directories-disappear]], [[malformed-or-corrupt-message]], [[streams-not-visible-across-a-leafnode]], [[stream-has-high-message-lag]], [[kv-watchers-stall-the-cluster]], [[nats-timeout]]. **Seven pages for six rows, and two of the six rows were wrong.** Reading the linked threads first — which is what the step asked for — showed that **gh#5924 is not about running out of disk** (it is filestore directories being reaped off a tmpfs `store_dir`; @neilalexander: "pointing the file store to tmpfs is not a supported/endorsed configuration") and that **gh#6746 is not about missed KV updates** (it asks how to watch many keys on one watcher, and the asker answered himself in an hour). Q26 and Q69 were **corrected rather than filled**, and the genuine out-of-disk question was re-sourced to two GitHub **issues** — a new `raw/gh-issues/` collection, because #4281 and #8322 carry a state, a closing PR and a fix version that discussions do not. **Five ingests beyond the list**: three issues (#4281 open since 2023-06-29 with six reporters; #8322 and #5871, the same defect two years apart), gh#5243 (the KV-watcher failure people actually report), and `nats-server` v2.14.6 across ten files plus `nats.go` v1.53.1. **Four findings no source carries**: `10047` compares **reservations** — the sum of every stream's `max_bytes`, counted as used from creation — never actual usage, so a `/varz` dump reads *4 MB stored, 35 GiB reserved*; `finalizeDynamicMaxStore` is **absent from v2.14.5 and present in v2.14.6**, which pins PR #8503's fix to a release the notes do not mention; the leafnode source contains an **explicit guard** against two identical JetStream domain names, with a comment saying it "will only cover some forms of this issue", which explains every one of gh#7834's four observations including the one the reporter called "really weird"; and the JetStream API queue **drains entirely** when `request_queue_limit` is reached, discarding every pending request with no reply of any kind — the sharpest server-side cause of a client-side `nats: timeout`. **Docs issue #22 ★, the highest-impact sweep yet**: the generated `jetstream` block states ten defaults and **four are wrong**, including `max_file_store` — documented as "up to 1TB if available" when 1 TB is the `statfs`-failure fallback and the real default is **75% of the space *free* under `store_dir`**, recomputed at every restart. That description is what makes operators leave the key unset, and leaving it unset is what broke restarts for two years. The maintainers' "auto-sizing is for development and testing" appears nowhere in the 861-page tree, and `max_file_store: 0` silently means *no storage*. Ripple: [[jetstream-sizing]] (step 4 rewritten, two new rules of thumb, `reserved_storage` added to the measurement commands, *what runs out first* re-ranked), [[defaults-and-limits]] (the whole JetStream block re-read from source; six values added), [[config-keys]] (four corrected), [[error-codes]] (10028, 10047), [[monitoring-endpoints]] (a `reserved_storage` section), [[advisories]], [[raft-in-nats]] (`resetClusteredState`), [[key-value]], [[ordered-consumer]], [[install-nats-server]], [[nats-server-2.14]], plus link-level updates to eight more. **The wanted page `kv-watcher-misses-updates` was retired, not written** — no public source reports the symptom, and inventing one would have been the cheapest way to close a red link and the worst. Answered **Q26, Q39, Q42, Q62, Q69, Q77**; added Q99–Q101, all three answered. **101 rows, 53 answered; ★ 31 of 41.** Wanted pages 8 → 6; lint clean at 180 pages.

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

## Candidates for the plan after this one

Surfaced 2026-08-31 by measuring the wiki rather than by ingesting. Recorded here so they are not
lost; **re-evaluate when this plan finishes**, because their value depends on what the runbook pass
turns up. Neither is an ingest — both are tools.

- **Mechanize the docs-issue sweep.** 10 verified findings came out of reading **2.4% of the docs**
  (21 of 863 pages), and 3 of the 4 confirmed errors were in *generated* reference pages where a
  hand-written page had the right value. That is a pattern a script can exploit:
  `inbox/config-keys-table.md` already holds **621 keys with 179 stated defaults**, and comparing
  each against `nats-io/nats-server` at a tag is a mechanical diff. Nothing else in the NATS
  ecosystem publishes such a report, and `inbox/docs-issues.md` is this wiki's most distinctive
  output.
- **Drift detection.** Every page reads `verified-on: 2026-08-31`. When 2.14.7 ships, nothing tells
  you which of the 97 pages is now lying. `tools/fetch-repo-facts.py --refresh` covers the entity
  layer; the analogue for defaults and versions — flag every page whose `verified-against` is behind
  the current tag *and* which states a default — would keep the wiki honest as it ages. `CLAUDE.md`
  says a stale page is worse than a missing one, and today nothing enforces that.
- **The remaining 47 ADRs**, 15 still flagged ★ in `inbox/adr-toc.md`. Several are named directly by
  open `## To verify` items: ADR-48 (KV TTL), ADR-54 (KV codecs), ADR-57 (KV sources and mirrors),
  ADR-59/60 (sourcing), ADR-61 (meta-group quorum rescue).
- **Re-mine the question bank by body, not by title.** The 87 rows were mined from thread titles,
  which gives a list but not a *ranking*. Reading bodies and clustering would show which problems
  recur, turning the bank into a priority order. Worth doing only once the current 62 open rows are
  substantially answered — more demand signal we cannot meet makes the scoreboard worse, not better.

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
