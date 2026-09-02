---
title: "nats-server v2.14.6 — the meta-layer run repeated through tools/lab/"
type: summary
area: [jetstream, topology, monitoring]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/jetstream-cluster-lab-rerun-observed-v2.14.6.md
author: nats-io/nats-server contributors
article: "§1, §2 and §6 of raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md run again on 2026-09-02 with the cluster started by `bash tools/lab/cluster.sh up 3`, a probe of the `Healthcheck failed` log line, and server/monitor.go lines 3573–3589 at v2.14.6"
date: 2026-09-02
version: "2.14.6"
tags: [meta-layer, meta-leader, election, healthz, lab, reproducibility, bootstrap, stepdown]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# nats-server v2.14.6 — the meta-layer run repeated through `tools/lab/`

The first run made through the wiki's lab (`tools/lab/cluster.sh`, added 2026-09-02): three sections
of the 2026-09-01 meta-layer run were repeated with the cluster started by one command instead of
hand-built configs, to prove the lab reproduces what the pages cite. It did — and it caught one
wrong note in the original record. Read for [[meta-layer]], [[build-a-3-node-cluster]] and
[[monitoring-endpoints]].

## Key claims

- **The lab reproduces the shape exactly.** `bash tools/lab/cluster.sh up 3` renders `n1`–`n3`,
  cluster `east`, client ports 4291–4293, route ports 6291–6293, monitoring 8291–8293, full `routes`
  lists and the `$SYS` user `sys`, from `tools/lab/conf/node.conf.tmpl`. The meta peer ids the
  cluster reports (`fjFyEjc1`, `44jzkV9D`, `BXScrY9i` for n1–n3) are **identical to the
  2026-09-01 run** although the stores were freshly purged: the id follows the server name, not the
  store. (Observed; the derivation was not looked up in the source.)
- **Bootstrap election, §1:** `Creating JetStream metadata controller` →
  `Self is new JetStream cluster metadata leader` in **303 ms** on the winning node (n3 this time;
  n1 and 282 ms in the original). The whole cluster answered `/healthz?js-meta-only=true` with 200
  **0.93 s** after `up 3` was issued.
- **Full restart with data, §2:** all three stopped with SIGTERM (`down`, stores kept) and
  restarted (`up 3`): `JetStream cluster recovering state` → leader in **5.07 s** (5.32 s in the
  original), inside the 4–9 s election window; every node healthy 5.59 s after the restart was
  issued (6 s in the original).
- **Meta stepdown, §6:** `nats server cluster step-down --force` returned in **0.54 s** (0.53 s);
  the old leader logged `JetStream cluster no metadata leader` **40 ms before** the successor logged
  `Self is new JetStream cluster metadata leader`, the same order as the original.
- **Correction — `Healthcheck failed` is logged once per request, not once a second.** The
  original record said each node "logs `Healthcheck failed: "…"` once a second until a leader
  exists". In the re-run the node the lab polled every 0.25 s logged the line every ~0.3 s, and the
  two nodes it had not polled yet logged it **zero times** during the same 5 s leaderless window. A
  separate probe on a leaderless survivor (two of three stopped): **0 lines in 5 s** with no
  request, then **exactly one line per `/healthz` request**, for `?js-meta-only=true` and plain
  `/healthz` alike. The line is written by the HTTP handler: `server/monitor.go` at v2.14.6,
  `HandleHealthz`, lines 3584–3589 — `if hs.Error != _EMPTY_ { s.Warnf("Healthcheck failed: %q",
  hs.Error) }`. The once-a-second cadence in the original was the original probe's own polling.
- **Two of three stopped by SIGTERM:** the survivor logged `JetStream cluster no metadata leader`
  **19.85 s** after the stops. The original §8 saw ~10 s after SIGKILL; both lie inside the 10–20 s
  range the 10 s `lostQuorumCheck` ticker and the 10 s `lostQuorumInterval` give (`raft.go:295–296`,
  quoted in [[s-nats-server-jetstream-cluster]]).

## Practical takeaways

- A `Healthcheck failed` line in the log is **your probe's footprint**: a Kubernetes liveness probe
  produces one per `periodSeconds`, a one-second poll one a second, and a server nobody polls logs
  nothing while it has no meta leader. Counting the lines measures the probe, not the outage; use
  the timestamps of `recovering state` and `new metadata leader` for the outage.
- The election numbers on [[meta-layer]] (0.3 s bootstrap, 4–9 s restart, 0.5 s stepdown) hold on a
  second run made by a different route; they are safe to design against.
- `bash tools/lab/cluster.sh up 3` is the starting point for any run that needs the cluster the
  observed files describe; `down` keeps the stores for a restart-with-data experiment, `stop k -9`
  and `start k` for a crash and rejoin.

## Notable quotes

- `monitor.go:3585–3586`: `if hs.Error != _EMPTY_ { s.Warnf("Healthcheck failed: %q", hs.Error) }`
- The transcript's restart lines: `21:25:42.055644 [INF] JetStream cluster recovering state` →
  `21:25:47.123178 [INF] Self is new JetStream cluster metadata leader` (n2).

## Relevance to the wiki

Phase A of the maintainer's programme: every `raw/*-observed-*` claim should be re-runnable by
whoever clones the repo. This is the proof for the meta-layer numbers, and the first correction the
re-run produced — a raw observation that was an artefact of its own probe. Not a docs issue: the
wrong sentence was in this wiki's own record, not in a public source, so the pages are fixed
directly and cite this summary.

## Questions it answers

None new. Q36 and Q38 (already answered by [[meta-layer]]) gain a second run behind their numbers.

## Pages touched

[[meta-layer]] (the restart row of the outage table and the log-line legend) ·
[[build-a-3-node-cluster]] (the restart sentence in *Verify*) ·
[[monitoring-endpoints]] (the `?js-meta-only=true` paragraph)
