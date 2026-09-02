# Plan — the lab: reproducible runs (proposed 2026-09-02)

> **Result (2026-09-02): finished, all four steps in one session.** `tools/lab/cluster.sh` and its
> templates start the observed files' cluster in one command with a version gate; `tools/lab/README.md`
> and `README.md` say how; the meta-layer run repeated through it to within a few percent and corrected
> one of the wiki's own observations (`Healthcheck failed` is one line per `/healthz` request). 286
> pages, bank 137 / 101 unchanged, drift 0, unlanded 0. **Next:** phase B of the megaplan — scout 1
> from `inbox/scout-backlog.md` (rows 76, 91, 105), then scout 2, then `consumer-keeps-redelivering`.

Say **`start the plan inbox/plan-the-lab-2026-09-02.md`** to work this file — name it explicitly, a
bare `start the plan` takes the newest `inbox/plan-*.md`. `CLAUDE.md` → *Operation: plan* says how:
one step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run, question-bank
cells filled, each step reported before the next begins.

**Where the wiki stands (2026-09-02, commit `5cda0f5`).** 285 pages; question bank 137 rows, 101
answered, 36 open; wanted 1; `(unverified)` 12 across 9 pages; citation drift 0, unlanded ripples 0;
staleness 0 behind nats-server 2.14.6; docs issues 48, server issues 2. Binary `nats-server v2.14.6`
(Homebrew, arm64), `nats` CLI 0.4.0.

**Why this plan.** Fourteen files under `raw/nats-server-src/*-observed-v2.14.6.md` record what the
binary did on this machine — the meta layer's timings, the filestore's block sizes, `/jsz` fields,
the KICK/LDM requests, MQTT replica derivation. Every one of them describes its cluster in prose
("n1–n3, cluster `east`, ports 4291–4293 …") and none of them ships the configs or a way to start
them. Whoever clones the repo can read the numbers but cannot re-run them, and every later phase of
the programme (B's recovery and mirror runs, F's client failover runs, G's placement runs, H's sizing
runs) starts by re-deriving the same scratch cluster. This plan puts the recipe into `tools/lab/`
once, proves it reproduces one existing experiment, and tells the reader how.

**Two constraints on top of *Operation: plan*.** The lab never writes into the repo: store
directories, logs and pid files live under a scratch directory outside it. And the script refuses to
start a binary that is not the release the caller names, so a run can always be attributed to the
version the wiki's `verified-against` fields carry (`CLAUDE.md` → *Operation: record a docs issue*:
"the local binary must be the same release the page cites").

**Done when** `bash tools/lab/cluster.sh up 3` yields a healthy R3 cluster in one command on a fresh
clone, `tools/lab/README.md` says how, one existing experiment has been re-run through it and
recorded in `raw/`, and `README.md` gains *Reproducing the observed runs*.

---

## Step 1 — `tools/lab/cluster.sh` and its config templates · status: done 2026-09-02 — `tools/lab/cluster.sh` (up, down, status, logs, conf, plus stop/start for one node and url) and `tools/lab/conf/{node,standalone}.conf.tmpl`. Verified on this machine: `up 3` healthy in 0.9 s with the meta leader printed; `status` one line per node; `nats server report jetstream` shows the meta table with the **same peer ids as the 2026-09-01 run** (`fjFyEjc1`, `44jzkV9D`, `BXScrY9i`); `down` leaves no process; `up 1` standalone; `up 4`; `stop 2 -9` then `start 2` rejoins; `NATS_LAB_VERSION=v2.14.5` refused before any process starts. No page changed, no bank cell moved.

Write `tools/lab/cluster.sh up|down|status|logs [n]` and `tools/lab/conf/`:

- `n` is 1, 3 or 4; default 3. Node `k` listens on `127.0.0.1:429k` (clients), `629k` (routes),
  `829k` (monitoring) — the ports every observed file already uses, so nothing in `raw/` has to be
  re-read with a translation table. Server names `n1`…`n4`, cluster name `east`.
- Each node's config is rendered from a template in `tools/lab/conf/` with a full `routes` list of
  its peers, `jetstream { store_dir }` under the scratch dir, and
  `accounts { $SYS { users: [ { user: sys, password: sys } ] } }` so every `nats server …` command
  works. `n=1` renders a standalone config with no `cluster {}` block, the way n4 started in §10 of
  `jetstream-cluster-observed-v2.14.6.md`. Nothing else: no `meta_compact*`, no domain, no
  `extension_hint` — the observed files were run without them.
- Scratch dir: `$NATS_LAB_DIR`, default `${TMPDIR:-/tmp}/nats-lab`, never the repo; `up` creates
  `<dir>/n<k>/{store,log,conf,pid}`, `down` stops the processes and leaves the stores (so a
  restart-with-data experiment is possible), `down --purge` deletes them.
- `up` prints `nats-server --version` and refuses to start when it differs from
  `$NATS_LAB_VERSION` (default `v2.14.6`, the release every `verified-against` in the wiki names).
  `up` waits for `/healthz` on every node and, for `n ≥ 3`, for `/healthz?js-meta-only=true` on
  every node, then prints the meta leader from `/jsz`.
- `status` prints per node: pid, alive or not, `/healthz`, `/jsz` `meta_cluster.leader` and
  `cluster_size`. `logs [k]` tails the node's log.
- The script is POSIX-ish bash (`#!/usr/bin/env bash`, `set -euo pipefail`), needs only
  `nats-server`, `curl` and `python3` (for JSON fields), and works on macOS and Linux.

Verify: `bash tools/lab/cluster.sh up 3` from a clean scratch dir; `status` shows three alive nodes
and one meta leader; `nats --server nats://sys:sys@127.0.0.1:4291 server report jetstream` prints the
meta table; `down` leaves no `nats-server` process on the lab ports; `up 1` starts a standalone
server; a deliberately wrong `NATS_LAB_VERSION=v2.14.5` is refused before anything starts.

## Step 2 — `tools/lab/README.md` · status: done 2026-09-02 — ports table, commands, scratch layout, the version gate, the fourteen observed files with the shape each ran on (two on this cluster, one section of a third, the rest single servers or hub/leaf pairs on their own ports), and how to record a run.

What it starts (the table of names and ports), where the store lives, the `$SYS` user, the
environment variables, how to tear down and how to keep the stores, and the list of observed files
under `raw/nats-server-src/` whose runs it reproduces — with, per file, which sections used this
cluster and which used a different single server (the filestore, object-store, NAK, schedule,
priority-group and TLS runs each ran one server on its own port and are listed as *not this
cluster*). One line on the binary-version gate and why it exists.

## Step 3 — re-run one experiment through the lab · status: done 2026-09-02 — `raw/nats-server-src/jetstream-cluster-lab-rerun-observed-v2.14.6.md` and `s-nats-server-meta-layer-rerun-observed`. §1 bootstrap 303 ms (282 ms originally), §2 restart 5.07 s (5.32 s), §6 stepdown 0.54 s (0.53 s), the same three peer ids on purged stores. One correction: `Healthcheck failed` is logged once per `/healthz` request (`monitor.go:3584–3589`, probe: 0 lines in 5 s unpolled, 1 per request), not once a second as the original record and three pages said — `meta-layer`, `build-a-3-node-cluster`, `monitoring-endpoints` fixed and citing the summary. Not a docs issue (the wrong sentence was the wiki's own). Unlanded ripples 0 → 0.

Re-run **§1, §2 and §6** of `raw/nats-server-src/jetstream-cluster-observed-v2.14.6.md` through the
script — the bootstrap election (`Creating JetStream metadata controller` → `Self is new JetStream
cluster metadata leader`), the full restart with the election window, and a `nats server cluster
step-down` — and record the run verbatim as
`raw/nats-server-src/jetstream-cluster-lab-rerun-observed-v2.14.6.md`, with the same measurements
next to the originals and a note on every difference. Add the row to `raw/sources.md`'s
`nats-server-src` notes. If a number falls outside the window the source cites (4–9 s for a restart
election; a stepdown well under a second), that is a finding for `inbox/server-issues.md`, not a
reason to adjust the page. `wiki/internals/meta-layer.md` gains a one-line pointer to the re-run
under its `## Sources` (no new claim; a second run of the same thing).

## Step 4 — `README.md` and the log · status: done 2026-09-02 — README gains *Reproducing the observed runs* and a `tools/lab/` layout row; log entries per step; lint clean (286 pages, drift 0, unlanded 0); no bank cell changed, as expected. Fresh-clone check: the `tools/lab/` directory copied outside the repo and run with its own `NATS_LAB_DIR` gave a healthy three-node cluster in one command.

`README.md`: a *Reproducing the observed runs* section (three commands, the version gate, the link
to `tools/lab/README.md`) and a `tools/lab/` row in the layout table. `wiki/log.md`: one entry for
the plan with the files created and the re-run's numbers. Lint clean. Question bank: no cell changes
expected — this plan builds a tool, not a page — say so in the report.

---

## Not in this plan

- A Kubernetes or Docker variant of the lab (the Helm chart is its own runbook, [[nats-helm-charts]]).
- Leafnode, gateway or TLS topologies (`topology-observed`, `object-store-across-leafnode-observed`,
  `tls-reload-observed` each ran their own shape); a `tools/lab/leaf.sh` can follow when phase B or G
  needs one.
- Re-running every observed file. One is the proof; the README lists the rest.
