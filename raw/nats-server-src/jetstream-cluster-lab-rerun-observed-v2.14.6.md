<!-- source: nats-server v2.14.6 binary (`nats-server --version` → `nats-server: v2.14.6`), nats CLI 0.4.0, macOS 26.6.2 arm64, 2026-09-02 · the same three-node cluster as jetstream-cluster-observed-v2.14.6.md, started this time by `bash tools/lab/cluster.sh` (inbox/plan-the-lab-2026-09-02.md step 3) · plus server/monitor.go at tag v2.14.6 from raw.githubusercontent.com, lines 3584–3589 · scratch paths written as <lab>, nothing else edited -->
# nats-server v2.14.6 — §1, §2 and §6 of the meta-layer run, repeated through `tools/lab/`

The point of this file is reproducibility, not new ground: the bootstrap election (§1), the
full restart with the election window (§2) and the meta stepdown (§6) of
`jetstream-cluster-observed-v2.14.6.md` (2026-09-01, hand-built configs) were run again on
2026-09-02 with the cluster started by `bash tools/lab/cluster.sh up 3` — the same names, ports,
routes list and `$SYS` user, rendered from `tools/lab/conf/node.conf.tmpl`. The transcript is
verbatim below; the measurements are compared to the originals at the end. One note in the original
turned out to be wrong and is corrected here with a separate probe and the source line: the
`Healthcheck failed` log line is written **once per `/healthz` request**, not once a second.

## Transcript — `scratchpad/rerun.sh`

The script: `down --purge`, `up 3` (§1), then `down` and `up 3` again on the kept stores (§2), then
`nats server cluster step-down --force` (§6), `nats server report jetstream`, `status`, `down`.
`up` returns when `/healthz?js-meta-only=true` answers 200 on every node; "issued at" is the wall
clock when the command was started, "returned after" its duration.

```
### environment
nats-server: v2.14.6
0.4.0
ProductName:		macOS
ProductVersion:		26.6.2
arm64

### §1 rerun — fresh bootstrap
$ bash tools/lab/cluster.sh up 3      # issued at 21:25:39.325
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 4445  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
n2: pid 4465  client 127.0.0.1:4292  http 127.0.0.1:8292  log <lab>/n2/n2.log
n3: pid 4485  client 127.0.0.1:4293  http 127.0.0.1:8293  log <lab>/n3/n3.log
healthy: 3 nodes, /healthz?js-meta-only=true ok on every node; meta leader n3, cluster_size 3
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
up returned after 0.93 s

--- n1.log, JetStream lines
[4445] 2026/09/02 21:25:39.452091 [INF] Starting JetStream
[4445] 2026/09/02 21:25:39.453633 [INF] Starting JetStream cluster
[4445] 2026/09/02 21:25:39.453638 [INF] Creating JetStream metadata controller
[4445] 2026/09/02 21:25:39.455352 [INF] JetStream cluster bootstrapping
[4445] 2026/09/02 21:25:39.475629 [INF] Took 23.529625ms to start JetStream
[4445] 2026/09/02 21:25:39.475693 [INF] Server is ready
[4445] 2026/09/02 21:25:39.579197 [WRN] Waiting for routing to be established...
[4445] 2026/09/02 21:25:39.682474 [WRN] JetStream has not established contact with a meta leader
[4445] 2026/09/02 21:25:39.888747 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4445] 2026/09/02 21:25:40.065903 [INF] JetStream cluster new metadata leader: n3/east

--- n2.log, JetStream lines
[4465] 2026/09/02 21:25:39.605484 [INF] Starting JetStream
[4465] 2026/09/02 21:25:39.605938 [INF] Starting JetStream cluster
[4465] 2026/09/02 21:25:39.605941 [INF] Creating JetStream metadata controller
[4465] 2026/09/02 21:25:39.606603 [INF] JetStream cluster bootstrapping
[4465] 2026/09/02 21:25:39.622398 [INF] Took 16.910125ms to start JetStream
[4465] 2026/09/02 21:25:39.622431 [INF] Server is ready
[4465] 2026/09/02 21:25:39.723152 [WRN] Waiting for routing to be established...
[4465] 2026/09/02 21:25:39.723206 [WRN] JetStream has not established contact with a meta leader
[4465] 2026/09/02 21:25:40.065653 [INF] JetStream cluster new metadata leader: n3/east

--- n3.log, JetStream lines
[4485] 2026/09/02 21:25:39.768827 [INF] Starting JetStream
[4485] 2026/09/02 21:25:39.769262 [INF] Starting JetStream cluster
[4485] 2026/09/02 21:25:39.769266 [INF] Creating JetStream metadata controller
[4485] 2026/09/02 21:25:39.769953 [INF] JetStream cluster bootstrapping
[4485] 2026/09/02 21:25:39.781141 [INF] Took 12.309709ms to start JetStream
[4485] 2026/09/02 21:25:39.781179 [INF] Server is ready
[4485] 2026/09/02 21:25:39.883246 [WRN] Waiting for routing to be established...
[4485] 2026/09/02 21:25:39.883312 [WRN] JetStream has not established contact with a meta leader
[4485] 2026/09/02 21:25:40.072534 [INF] Self is new JetStream cluster metadata leader

### §2 rerun — SIGTERM all three, restart with data
$ bash tools/lab/cluster.sh down     # issued at 21:25:41.334
n1: stopped (SIGTERM, pid 4445)
n2: stopped (SIGTERM, pid 4465)
n3: stopped (SIGTERM, pid 4485)
stores kept under <lab> ('down --purge' deletes them)
$ bash tools/lab/cluster.sh up 3     # issued at 21:25:41.764
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
note: reusing existing store directories (this is a restart with data; 'down --purge' clears them)
n1: pid 4649  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
n2: pid 4669  client 127.0.0.1:4292  http 127.0.0.1:8292  log <lab>/n2/n2.log
n3: pid 4689  client 127.0.0.1:4293  http 127.0.0.1:8293  log <lab>/n3/n3.log
healthy: 3 nodes, /healthz?js-meta-only=true ok on every node; meta leader n2, cluster_size 3
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
up returned after 5.59 s

--- n1.log since restart
[4649] 2026/09/02 21:25:44.056158 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:44.338588 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:44.635773 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:44.933674 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:45.228929 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:45.523775 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:45.819673 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:46.114377 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:46.404649 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:46.699521 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:46.995537 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[4649] 2026/09/02 21:25:47.123277 [INF] JetStream cluster new metadata leader: n2/east

--- n2.log since restart
[4465] 2026/09/02 21:25:39.622431 [INF] Server is ready
[4465] 2026/09/02 21:25:39.723206 [WRN] JetStream has not established contact with a meta leader
[4465] 2026/09/02 21:25:40.065653 [INF] JetStream cluster new metadata leader: n3/east
[4669] 2026/09/02 21:25:42.055644 [INF] JetStream cluster recovering state
[4669] 2026/09/02 21:25:42.068952 [INF] Server is ready
[4669] 2026/09/02 21:25:42.170993 [WRN] JetStream has not established contact with a meta leader
[4669] 2026/09/02 21:25:47.123178 [INF] Self is new JetStream cluster metadata leader

--- n3.log since restart
[4485] 2026/09/02 21:25:39.781179 [INF] Server is ready
[4485] 2026/09/02 21:25:39.883312 [WRN] JetStream has not established contact with a meta leader
[4485] 2026/09/02 21:25:40.072534 [INF] Self is new JetStream cluster metadata leader
[4485] 2026/09/02 21:25:41.611556 [INF] JetStream cluster no metadata leader
[4689] 2026/09/02 21:25:42.227796 [INF] JetStream cluster recovering state
[4689] 2026/09/02 21:25:42.241053 [INF] Server is ready
[4689] 2026/09/02 21:25:42.342001 [WRN] JetStream has not established contact with a meta leader
[4689] 2026/09/02 21:25:47.123007 [INF] JetStream cluster new metadata leader: n2/east
n1 /healthz?js-meta-only=true -> {"status":"ok"}
n2 /healthz?js-meta-only=true -> {"status":"ok"}
n3 /healthz?js-meta-only=true -> {"status":"ok"}

### §6 rerun — meta stepdown
$ nats --server nats://sys:sys@127.0.0.1:4291 server cluster step-down --force     # issued at 21:25:48.481
21:25:48 Requesting leader step down of "n2" in a 3 peer RAFT group
21:25:49 New leader elected "n3"
returned after 0.54 s
--- n1.log
[4445] 2026/09/02 21:25:40.065903 [INF] JetStream cluster new metadata leader: n3/east
[4649] 2026/09/02 21:25:47.123277 [INF] JetStream cluster new metadata leader: n2/east
[4649] 2026/09/02 21:25:48.554059 [INF] JetStream cluster new metadata leader: n3/east
--- n2.log
[4669] 2026/09/02 21:25:47.123178 [INF] Self is new JetStream cluster metadata leader
[4669] 2026/09/02 21:25:48.509581 [INF] JetStream cluster no metadata leader
[4669] 2026/09/02 21:25:48.549576 [INF] JetStream cluster new metadata leader: n3/east
--- n3.log
[4485] 2026/09/02 21:25:41.611556 [INF] JetStream cluster no metadata leader
[4689] 2026/09/02 21:25:47.123007 [INF] JetStream cluster new metadata leader: n2/east
[4689] 2026/09/02 21:25:48.549618 [INF] Self is new JetStream cluster metadata leader

### report

╭───────────────────────────────────────────────────────────────────────╮
│            RAFT Meta Group Information - Lead cluster: east           │
├─────────────────┬──────────┬────────┬─────────┬────────┬────────┬─────┤
│ Connection Name │ ID       │ Leader │ Current │ Online │ Active │ Lag │
├─────────────────┼──────────┼────────┼─────────┼────────┼────────┼─────┤
│ n1              │ fjFyEjc1 │        │ true    │ true   │ 556ms  │ 0   │
│ n2              │ 44jzkV9D │        │ true    │ true   │ 556ms  │ 0   │
│ n3              │ BXScrY9i │ yes    │ true    │ true   │ 0s     │ 0   │
╰─────────────────┴──────────┴────────┴─────────┴────────┴────────┴─────╯

### status
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   4649    yes   4291   8291  200      200      n3          3
n2   4669    yes   4292   8292  200      200      n3          3
n3   4689    yes   4293   8293  200      200      n3          3
lab dir: <lab>   version gate: v2.14.6

### down
n1: stopped (SIGTERM, pid 4649)
n2: stopped (SIGTERM, pid 4669)
n3: stopped (SIGTERM, pid 4689)
stores kept under <lab> ('down --purge' deletes them)
```

## Measurements against the 2026-09-01 run

| what | 2026-09-01 (hand-built) | 2026-09-02 (`tools/lab/`) | note |
|---|---|---|---|
| §1 bootstrap: `Creating JetStream metadata controller` → `Self is new JetStream cluster metadata leader` | **282 ms** (n1) | **303 ms** (n3: `21:25:39.769266` → `21:25:40.072534`) | bootstrap campaigns early; which node wins differs run to run — n1 first time, n3 this time |
| §1: cluster healthy after `up 3` was issued | not measured | 0.93 s | `/healthz?js-meta-only=true` 200 on all three |
| §2 restart: `JetStream cluster recovering state` → leader | **5.32 s** | **5.07 s** (n2: `21:25:42.055644` → `21:25:47.123178`) | inside the 4–9 s `minElectionTimeout`–`maxElectionTimeout` window; recovery does not campaign early |
| §2: all three `/healthz?js-meta-only=true` ok after restart | 6 s | 5.59 s (`up` returned) | |
| §6 stepdown: CLI wall clock | 0.53 s | 0.54 s | |
| §6 stepdown: old leader `no metadata leader` → new leader `Self is new …` | not measured | 40 ms (n2 `21:25:48.509581` → n3 `21:25:48.549618`) | the old leader logs `no metadata leader` before it learns the successor, as in the original |
| meta peer ids `n1` / `n2` / `n3` | `fjFyEjc1` / `44jzkV9D` / `BXScrY9i` | **identical**, on freshly purged stores | the id follows the server name, not the store (observed only; the derivation was not looked up in the source) |

Every number lands where the original and the source ranges it cites say it should. Nothing here
changes a page's claim except the healthcheck note below.

## The `Healthcheck failed` line follows the request, not a timer

The original file (§2) says every node "logs `Healthcheck failed: "…"` once a second until a leader
exists". In this re-run n1, which `cluster.sh` polls every 0.25 s while waiting, logged the line
every ~0.3 s; n2 and n3, not polled until n1 was healthy, logged it **zero** times during the same
5 s leaderless window (see the `--- n2.log since restart` and `--- n3.log since restart` blocks
above). The original's once-a-second cadence was the original probe's own polling interval.

Confirmed with a separate probe (`scratchpad/probe.sh`): `up 3`, SIGTERM n2 and n3, wait for n1 to
drop leadership by polling `/jsz` only (which does not log), then count the lines with and without
`/healthz` requests:

```
cluster up at 21:26:49.858; meta leader: n1
$ cluster.sh stop 2; cluster.sh stop 3          # at 21:26:49.890
n2: stopped (SIGTERM, pid 5671)
n3: stopped (SIGTERM, pid 5691)
waiting for n1 to report no meta leader, polling /jsz only (never /healthz) …
n1 /jsz meta_cluster.leader is empty at 21:27:10.238 (after 37 polls of 0.5 s)
[5651] 2026/09/02 21:27:09.735746 [INF] JetStream cluster no metadata leader
Healthcheck failed lines so far: 0 (the ones cluster.sh's own health wait produced at 'up', before a leader existed)
--- 5 s with no /healthz request, from 21:27:10.260
lines now: 0  (+0)
--- three /healthz?js-meta-only=true requests 0.5 s apart, from 21:27:15.320
  21:27:15.344 -> {"status":"unavailable","error":"JetStream has not established contact with a meta leader"} [503]
  21:27:15.910 -> {"status":"unavailable","error":"JetStream has not established contact with a meta leader"} [503]
  21:27:16.482 -> {"status":"unavailable","error":"JetStream has not established contact with a meta leader"} [503]
lines now: 3  (+3)
--- and two plain /healthz requests
  21:27:17.061 -> {"status":"unavailable","error":"JetStream has not established contact with a meta leader"} [503]
  21:27:17.634 -> {"status":"unavailable","error":"JetStream has not established contact with a meta leader"} [503]
lines now: 5  (+2)
--- the last five Healthcheck lines in n1.log
[5651] 2026/09/02 21:27:15.353708 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[5651] 2026/09/02 21:27:15.925476 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[5651] 2026/09/02 21:27:16.498170 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[5651] 2026/09/02 21:27:17.075165 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
[5651] 2026/09/02 21:27:17.649816 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
```

Zero lines in five seconds with no request; exactly one line per request, for
`/healthz?js-meta-only=true` and for plain `/healthz` alike. The line is written by the HTTP handler
itself — `server/monitor.go` at v2.14.6, inside `HandleHealthz`:

```go
 3573		hs := s.healthz(&HealthzOptions{
 3574			JSEnabled:     jsEnabled,
 3575			JSEnabledOnly: jsEnabledOnly,
 3576			JSServerOnly:  jsServerOnly,
 3577			JSMetaOnly:    jsMetaOnly,
 3578			Account:       r.URL.Query().Get("account"),
 3579			Stream:        r.URL.Query().Get("stream"),
 3580			Consumer:      r.URL.Query().Get("consumer"),
 3581			Details:       includeDetails,
 3582		})
 3583	
 3584		code := hs.StatusCode
 3585		if hs.Error != _EMPTY_ {
 3586			s.Warnf("Healthcheck failed: %q", hs.Error)
 3587		} else if len(hs.Errors) != 0 {
 3588			s.Warnf("Healthcheck failed: %d errors", len(hs.Errors))
 3589		}
```

So a probe that polls once a second sees one line a second, a Kubernetes liveness probe sees one per
its `periodSeconds`, and a server nobody polls logs nothing while it has no leader. (Note in passing
from the probe: with two of three servers stopped by SIGTERM, n1 logged `JetStream cluster no metadata
leader` **19.85 s** after the stops — the original §8 saw ~10 s after SIGKILL; both are inside the
10–20 s range `lostQuorumCheck` + `lostQuorumInterval` give, `raft.go:295–296`.)

## Not tested

Nothing beyond §1, §2, §6 and the healthcheck probe: §7–§13 (leader SIGKILL under load, quorum loss
and the timed-out requests, the orphan deletion, peer-remove and the five-minute re-add) were not
repeated. `up 4` was exercised only for health, not for §10's standalone-then-join sequence.
