<!-- source: nats-server v2.14.6 binary (`nats-server --version` → `nats-server: v2.14.6`), nats CLI 0.4.0, macOS, 2026-09-01 · a three-node cluster run for inbox/plan-the-meta-layer-2026-09-01.md step 1 -->
# nats-server v2.14.6 — the JetStream meta layer, observed

The behavioural half of `jetstream-cluster-v2.14.6.md`: what a three-node cluster's meta group
does at start, on restart, when its leader is killed, when two of three servers are killed, when a
standalone server with data joins the cluster, and when a live server is peer-removed. Everything
below is the binary's own output; the source ranges that explain each number are cited by line in the
companion file. Store paths are shortened to `<store>`. Timestamps are the server's local time.

Configs: `n1`–`n3`, cluster `east`, client ports 4291–4293, cluster ports 6291–6293, monitor ports
8291–8293, each with a full `routes` list of its two peers, `jetstream { store_dir }`, and (from §2
on) `accounts { $SYS { users: [ { user: sys, password: sys } ] } }` so `nats server …` commands work.
`n4` (4294/6294/8294) is added in §10. Nothing else is configured: no `meta_compact*`, no
`extension_hint`, no domain.

## 1 · First start: bootstrap elects a meta leader in 150 ms

`n1.log`, first start, with nothing on disk:

```
21:35:26.465274 [INF] Starting JetStream cluster
21:35:26.465288 [INF] Creating JetStream metadata controller
21:35:26.467199 [INF] JetStream cluster bootstrapping
21:35:26.494279 [INF] Server is ready
21:35:26.595542 [WRN] Waiting for routing to be established...
21:35:26.596993 [WRN] JetStream has not established contact with a meta leader
21:35:26.747594 [INF] Self is new JetStream cluster metadata leader
```

`Creating JetStream metadata controller` → `Self is new JetStream cluster metadata leader` in
**282 ms** (bootstrap calls `Campaign()` early: `jetstream_cluster.go:1081–1083`). The other two
nodes log `JetStream cluster new metadata leader: n1/east`.

## 2 · Restart of all three: recovery waits the full election window

All three stopped with SIGTERM, restarted together with the `$SYS` user added:

```
n1: 21:37:23.576945 [INF] JetStream cluster recovering state
n1: 21:37:23.705689 [WRN] JetStream has not established contact with a meta leader
n1: 21:37:24.611580 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
n1: 21:37:25.669913 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
n1: 21:37:26.731329 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
n1: 21:37:27.797264 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
n1: 21:37:28.863190 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
n1: 21:37:28.901822 [INF] JetStream cluster new metadata leader: n3/east
n3: 21:37:28.901799 [INF] Self is new JetStream cluster metadata leader
```

`recovering state` → leader in **5.32 s**, inside the 4–9 s `minElectionTimeout`–`maxElectionTimeout`
window (`raft.go:290–291`); recovery does not campaign early. Every node logs
`Healthcheck failed: "…"` **once a second** until a leader exists. `/healthz?js-meta-only=true` on all
three answered `{"status":"ok"}` 6 s after the restart.

## 3 · What the meta group writes to disk

`<store>/jetstream/$SYS/_js_/_meta_/` on n1 (`setupMetaGroup`, `jetstream_cluster.go:1018`:
`StoreDir/<system account>/_js_/_meta_`):

```
_meta_/
  meta.inf        397 B   the filestore's stream config for the "_meta_" stream
  meta.sum         16 B
  msgs/2.blk      228 B   the Raft log, a filestore with defaultMetaFSBlkSize = 1 MB blocks
  obs/                    (empty)
  peers.idx        34 B   raft.go:5072 — the configured peer set, cluster size, extension state
  snapshots/snap.1.3 62 B
  tav.idx          16 B   term and vote
```

A **standalone** server has no `$SYS/_js_/_meta_` at all (§10) — its store is `$G/streams/<name>`
only.

## 4 · `/jsz` — `meta_cluster` is always present; `?meta=1` is not a parameter

A **follower**'s `/jsz` (n1, leader n3):

```json
"meta_cluster": {
  "name": "east", "leader": "n3", "peer": "BXScrY9i", "cluster_size": 3,
  "pending": 0, "pending_requests": 0, "pending_infos": 0,
  "snapshot": { "pending_entries": 2, "pending_size": 198, "last_time": "0001-01-01T00:00:00Z" }
}
```

The **leader**'s `/jsz` (n3) adds `replicas`, one entry per *other* peer:

```json
"replicas": [
  { "name": "n1", "current": true, "active": 925171667, "peer": "fjFyEjc1" },
  { "name": "n2", "current": true, "active": 925175667, "peer": "44jzkV9D" }
]
```

`active` is nanoseconds since the peer was last heard from. The key set of `/jsz` and of
`/jsz?meta=1` is **identical**; `/jsz?bogus=1` also returns 200 with the same body. `HandleJsz`
(`monitor.go`) decodes `accounts`, `streams`, `consumers`, `direct-consumers`, `config`, `leader-only`,
`raft`, `stream-leader-only`, `acc`, `offset`, `limit` — there is no `meta` parameter; the object is
unconditional. This wiki previously wrote `/jsz?meta=1`; that works only because the parameter is
ignored.

`/jsz?raft=1&streams=1` on a stream member adds the stream's group to each `stream_detail.cluster`:

```json
"cluster": { "name": "east", "raft_group": "S-R3F-RCvvHwre", "leader": "n1",
             "leader_since": "2026-09-01T19:38:34.57084Z", "system_account": true,
             "traffic_account": "$SYS", "replicas": [ … ] }
```

## 5 · `nats server report jetstream` — the meta table

```
╭───────────────────────────────────────────────────────────────────────╮
│            RAFT Meta Group Information - Lead cluster: east           │
├─────────────────┬──────────┬────────┬─────────┬────────┬────────┬─────┤
│ Connection Name │ ID       │ Leader │ Current │ Online │ Active │ Lag │
├─────────────────┼──────────┼────────┼─────────┼────────┼────────┼─────┤
│ n1              │ fjFyEjc1 │        │ true    │ true   │ 174ms  │ 0   │
│ n2              │ 44jzkV9D │        │ true    │ true   │ 174ms  │ 0   │
│ n3              │ BXScrY9i │ yes    │ true    │ true   │ 0s     │ 0   │
╰─────────────────┴──────────┴────────┴─────────┴────────┴────────┴─────╯
```

The `JetStream Summary` table above it marks the meta leader with `*` (`n3*`). The command needs the
system account: without the `$SYS` user it produces nothing.

## 6 · Meta stepdown: half a second, and `--host` is honoured

```
$ nats server cluster step-down --force
21:38:34 Requesting leader step down of "n3" in a 3 peer RAFT group
21:38:35 New leader elected "n2"                           (0.53 s wall clock)

n1: 21:38:34.673008 [INF] JetStream cluster new metadata leader: n2/east
n2: 21:38:34.673120 [INF] Self is new JetStream cluster metadata leader
n3: 21:38:34.634755 [INF] JetStream cluster no metadata leader
n3: 21:38:34.687042 [INF] JetStream cluster new metadata leader: n2/east
```

The old leader logs `no metadata leader` **before** it learns the successor. With
`--host n1` the CLI warns `Using placement tags or node name required NATS Server 2.11 or newer` and
n1 became leader. A stepdown is a leadership *transfer* (`raft.go:2018–2095`): the leader picks a
peer heard from within `hbInterval*3` and sends an `EntryLeaderTransfer` — no election timer runs.

## 7 · SIGKILL the meta leader while an R3 stream is being written

`ORDERS` (R3, `orders.>`) existed; its leader and the meta leader were both **n1**. `kill -9` n1 at
**21:38:39.872**, then from n2 every ~1.1 s: `/healthz?js-meta-only=true`, `nats stream add T<k>
--replicas 1 --timeout 400ms`, and `nats pub orders.k<k> x -J --timeout 400ms`.

| since kill | `/healthz?js-meta-only=true` on n2 | `stream add` |
|---|---|---|
| 0.02 s | `{"status":"ok"}` | timed out |
| 1.65 s | `{"status":"unavailable","error":"JetStream is not current with the meta leader"}` | timed out |
| 3.27 s | same | **created** |
| 4.39 s | `{"status":"ok"}` | created |

```
n2: 21:38:43.342486 [INF] JetStream cluster new metadata leader: n3/east
n3: 21:38:43.342577 [INF] Self is new JetStream cluster metadata leader
```

New meta leader **3.47 s** after the kill (the election timer counts from the last heartbeat, up to
1 s earlier). While it ran, `/healthz` said **`not current with the meta leader`**, not
`has not established contact` — `meta.GroupLeader()` still named the dead n1 until the term changed,
and `Healthy()` failed on `no recent leader contact` (`raft.go:1902–1907`). A control on the healthy
cluster afterwards created **10 of 10** streams inside the same 400 ms timeout.

The publish column of that run is **not trustworthy** and is omitted: `nats pub -J` prints
`Published 1 bytes to …` *before* it waits for the `PubAck` and prints `nats: error: nats: timeout`
on a second line (§9 shows both lines), and the run captured only the first matching line.

Restarting n1 with its store: `JetStream cluster recovering state` → `new metadata leader: n3/east`
in **0.55 s** — a node that rejoins learns the leader from the next heartbeat and holds no election.

## 8 · Two of three killed: the survivor claims leadership for another 10 s

n3 was the meta leader. `kill -9` n1 and n2 at ~21:40:13, then the survivor was asked three times:

| since kill | `/healthz?js-meta-only` | `/jsz` `meta_cluster.leader` | `nats stream add --timeout 3s` | `nats stream info ORDERS` |
|---|---|---|---|---|
| 5.1 s | `ok` (200) | `n3` | `context deadline exceeded` | `Leader:` *(empty)* |
| 13.2 s | `ok` (200) | `n3` | `context deadline exceeded` | `Leader:` *(empty)* |
| 21.4 s | `503 JetStream has not established contact with a meta leader` | *(none)* | **`JetStream system temporarily unavailable (10008)`** | `Leader:` *(empty)* |

```
n3: 21:40:23.115001 [WRN] JetStream cluster stream '$G > ORDERS' has NO quorum, stalled
n3: 21:40:23.355018 [INF] JetStream cluster no metadata leader
n3: 21:40:31.300089 [WRN] Healthcheck failed: "JetStream has not established contact with a meta leader"
```

Both groups gave up leadership **~10 s** after the kill: the leader's `lostQuorumCheck` ticker fires
every 10 s and a peer counts as present while heard from within `lostQuorumInterval` = 10 s
(`raft.go:295–296`, `3234`, `3345–3355`), so the worst case is ~20 s. Until then the lone server
**reports healthy and names itself leader**, and a create it accepts cannot commit, so the client
times out rather than being told. After it steps down, creates get `10008` immediately.

Other answers in that state:

```
$ nats server cluster peer-remove n1 --force --timeout 3s
nats: error: did not receive a response from the meta leader, ensure the account used has system privileges and appropriate permissions
$ nats server report jetstream --timeout 3s
(no output within 3 s)
$ nats consumer add ORDERS C1 --pull --defaults --timeout 3s          # after the stepdown
nats: error: Consumer creation failed: JetStream system temporarily unavailable (10008)
```

The peer-remove message blames credentials; the cause is that there is no meta leader to answer
(`ProposeRemovePeer` is forwarded to a leader that does not exist, `raft.go:1053–1065`).

## 9 · What a timed-out request becomes once quorum returns

Second run of §8 (n3 meta leader again, n1 and n2 killed at ~21:41:43), with full output:

```
$ nats pub orders.q1 x -J --timeout 3s                     # +3 s
21:41:46 Published 1 bytes to "orders.q1"
nats: error: nats: timeout
$ nats stream info ORDERS --timeout 3s                     # +3 s
                       Leader: n3 (1m14s)
                      Replica: n1, current, seen 6.23s ago
$ nats stream add Q1 --replicas 1 --timeout 3s             # +4 s
nats: error: could not create Stream: context deadline exceeded
n3: 21:41:55.798164 [WRN] JetStream cluster stream '$G > ORDERS' has NO quorum, stalled
n3: 21:41:58.432270 [INF] JetStream cluster no metadata leader              # +9.2 s
$ nats pub orders.q2 x -J --timeout 3s                     # +10 s, after the stepdown line
21:41:53 Published 1 bytes to "orders.q2"
nats: error: nats: timeout
$ nats stream add Q2 --replicas 1 --timeout 3s             # +10 s
nats: error: could not create Stream: context deadline exceeded
$ nats consumer add ORDERS C1 --pull --defaults --timeout 3s   # +13 s
nats: error: Consumer creation failed: JetStream system temporarily unavailable (10008)
```

n1 and n2 restarted; all three healthy 6 s later; n2 won the meta election
(`n3: 21:42:06.017207 [INF] JetStream cluster new metadata leader: n2/east`). Then:

| proposed while … | outcome after quorum returned |
|---|---|
| run 1: `Z3` at +1 s, `Z8` at +10 s — client timed out; **n3 re-won** the meta election on restart | **both exist**, `created` = the original proposal time (`19:40:14.989`, `19:40:23.160`) |
| run 1: `Z13` at +21 s — client got `10008` | does not exist |
| run 2: `Q1` at +4 s — client timed out; **n2 won** the meta election | **does not exist** |
| run 2: `Q2` at +10 s — client timed out, after the stepdown | does not exist |
| run 2: `orders.q1`, `orders.q2` — publisher got `nats: timeout`; **n3 stayed ORDERS leader** | **both stored**, sequences 21 and 22 |

A request that timed out on the client is an entry in the old leader's log. It is committed later if
that server wins the next election and discarded if another does — ordinary Raft, and the reason a
timed-out create must be re-checked (`nats stream info`) rather than assumed either way. Creates are
idempotent with an identical config (`jsClusteredStreamRequest` compares the config,
`jetstream_cluster.go:8250–8268`); a publish must be resent and deduplicated by `Nats-Msg-Id`.

The create right after the `no metadata leader` line (`Q2`) still timed out where the consumer create
3 s later got `10008`; a create 12 s after the stepdown (run 1, `Z13`) got `10008`. The transition
was not characterised more finely.

## 10 · A standalone server with a stream joins the cluster: the stream is deleted after 30 s

`n4` started **standalone** (no `cluster {}`), `ORPHAN` created R1 with 3 messages. Its log has no
`JetStream cluster` line at all; its store is `<store>/jetstream/$G/streams/ORPHAN` and nothing under
`$SYS`. Stopped, `cluster { name: east, routes: [n1, n2, n3] }` added, restarted with `-D`:

```
21:43:25.470195 [INF]   Restored 3 messages for stream '$G > ORPHAN' in 1ms
21:43:25.470278 [INF] Starting JetStream cluster
21:43:25.470285 [INF] Creating JetStream metadata controller
21:43:25.471371 [INF] JetStream cluster bootstrapping
21:43:25.471376 [DBG] JetStream cluster initial peers: [C7B8kAbl]
21:43:25.471385 [DBG] Determining expected peer size for JetStream meta group
21:43:25.471389 [DBG] Adjusting expected peer set size to 3 with 1 known
21:43:25.583102 [DBG] Recovered JetStream cluster metadata
21:43:26.018400 [INF] JetStream cluster new metadata leader: n2/east
21:43:55.584504 [DBG] JetStream cluster checking for orphans
21:43:55.584641 [WRN] Detected orphaned stream '$G > ORPHAN', will cleanup
```

The stream is **restored from disk first**, the server joins the meta group (its own peer set is
itself; the expected size comes from the three `routes`, `raft.go:379–401`), and **exactly 30.0 s**
after `Recovered JetStream cluster metadata` the orphan timer (`jetstream_cluster.go`, `time.AfterFunc(30*time.Second, js.checkForOrphans)`)
deletes it. Afterwards `nats stream ls` on n4 lists `ORDERS Z3 Z8` (the cluster's streams);
`<store>/jetstream/$G/streams/` is empty; `/jsz` on n1 reports `cluster_size: 4`. The only
INFO/WARN-level trace of the deletion is the one `Detected orphaned stream` line. No configuration
was involved and no prompt was offered.

## 11 · Peer-removing a running server

With n4 a member (cluster size 4) and `nats sub '$JS.EVENT.ADVISORY.SERVER.REMOVED'` on the system
account:

```
$ nats server cluster peer-remove n4 --force
[#1] Received on "$JS.EVENT.ADVISORY.SERVER.REMOVED"
{"type":"io.nats.jetstream.advisory.v1.server_removed","id":"bzR3zrSqUL1nzvGi5ydtxI",
 "timestamp":"2026-09-01T19:43:59.026488Z","server":"n4",
 "server_id":"NDC35T3DSARUTDCY5LFIY6IH6ZQEBYS75ATG43HUTKLA6D67LGYH7NMK","cluster":"east"}

n4: 21:43:59.025554 [ERR] JetStream being DISABLED, our server was removed from the cluster
n4: 21:43:59.036747 [INF] Initiating JetStream Shutdown...
n4: 21:43:59.040453 [INF] JetStream Shutdown
```

Then on n4: `/healthz?js-enabled-only=true` → `503 {"status":"unavailable","error":"JetStream not
enabled (10076)"}`; `/jsz` → `"disabled": true` and no `meta_cluster` object. n1's `/jsz`:
`cluster_size: 3`. The removed server keeps serving core NATS.

**Restarted 88 s later, same config, same store:** `JetStream cluster bootstrapping` (its meta state
was deleted on removal), `has not established contact with a meta leader`, then
`new metadata leader: n2/east` 0.87 s later; `/healthz?js-meta-only=true` → `{"status":"ok"}`.
But the leader's `replicas` list stays `[n1, n3]` and `cluster_size` stays 3: the server follows the
group's heartbeats and reports healthy **without being a member**. `raft.go:3855–3882` (`trackPeer`)
re-adds a removed peer only after `peerRemoveTimeout` = 5 minutes; whether that happened is
recorded in §13.

## 12 · The documented peer-remove subject versus the server's

```
$ nats req '$JS.API.META.SERVER.REMOVE' '{"peer":"nope"}'        # docs: reference/jetstream/api/meta.md
{"type":"io.nats.jetstream.api.v1.system_response","error":{"code":503,"err_code":10039,"description":"JetStream not enabled for account"}}
$ nats req '$JS.API.SERVER.REMOVE' '{"peer":"nope"}'             # server: jetstream_api.go:195
{"type":"io.nats.jetstream.api.v1.meta_server_remove_response","error":{"code":400,"err_code":10044,"description":"server is not a member of the cluster"}}
```

Both on the system account. The documented subject falls through to the generic `$JS.API.>`
handler, which answers with an unrelated error; the server's subject reaches
`jsLeaderServerRemoveRequest`. Behind `inbox/docs-issues.md` #43.

The same for account purge, documented as `$JS.API.ACCOUNT.PURGE` (`reference/jetstream/api/account.md`)
where the server subscribes `$JS.API.ACCOUNT.PURGE.*` (`jetstream_api.go:200`):

```
$ nats req '$JS.API.ACCOUNT.PURGE' '' --timeout 2s
21:58:37 Sending request on "$JS.API.ACCOUNT.PURGE"
(no response within 2 s)
$ nats req '$JS.API.ACCOUNT.PURGE.NOPE' '' --timeout 2s
21:58:39 Received with rtt 315.083µs
{"type":"io.nats.jetstream.api.v1.account_purge_response","initiated":true}
n2: 21:54:50.460144 [INF] Purge request for account NOPE (streams: 0, consumer: 0, hasAccount: false)
```

Note in passing: the purge of an account that does not exist is reported as `initiated: true`.

## 13 · The removed server is re-added after five minutes

n4 was peer-removed at **21:43:59** and restarted, still configured for `east`, at 21:45:27. The
leader's view over the following minutes (`/jsz` on the leader, n2):

| time | `cluster_size` | leader's `replicas` |
|---|---|---|
| 21:46:32 | 3 | `n1`, `n3` |
| 21:49:57 | **4** | `n1`, `n3`, **`n4`** |

No INFO-level log line marks the re-add on either side. `peerRemoveTimeout` = 5 min expired at
21:48:59; the leader's `trackPeer` (`raft.go:3855–3882`) treats a removed peer that is still
answering as new after that and proposes `EntryAddPeer`. **A peer-remove is permanent only if the
server is stopped or reconfigured within five minutes**; otherwise the cluster quietly grows back.

## Not tested

A network partition (only SIGKILL and SIGTERM were used, so routes closed promptly); mixed mode
(servers without JetStream); a meta group spanning gateways; leafnode observer mode
(`extension_hint`); `meta_compact*`; what a 4-node cluster's quorum does during a rolling restart.
Exit codes of the `nats` commands were not captured (a zsh `PIPESTATUS` slip), so the error lines are
the evidence.
