<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/monitor.go, server/store.go, server/raft.go · fetched 2026-09-01 · plus calls against the v2.14.6 binary the same day -->
# nats-server v2.14.6 — `/raftz`, read and run

Only the ranges this wiki quotes are stored, verbatim, with their real line numbers, so each value
links to `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.

Read for `inbox/plan-the-meta-layer-2026-09-01.md` step 3: the `/raftz` field set that
`wiki/internals/raft-in-nats.md` had left under *To verify*, against a documentation page
(`raw/nats-docs/reference/system/monitor/raftz.md`, re-fetched live on 2026-09-01, 173 bytes) that
lists two request options and **no response fields**. §Observed below is the endpoint called on the
four-node cluster of `jetstream-cluster-observed-v2.14.6.md`.

## server/monitor.go — `/raftz`

### `server/monitor.go` lines 3021–3024 — `RaftzOptions` — the system-request payload fields (`account`, `group`)

```go
  3021	type RaftzOptions struct {
  3022		AccountFilter string `json:"account"`
  3023		GroupFilter   string `json:"group"`
  3024	}
```

### `server/monitor.go` lines 4195–4232 — `RaftzGroup`, `RaftzGroupPeer`, `RaftzStatus` — the response, field by field

```go
  4195	type RaftzGroup struct {
  4196		ID            string                    `json:"id"`
  4197		State         string                    `json:"state"`
  4198		Size          int                       `json:"size"`
  4199		QuorumNeeded  int                       `json:"quorum_needed"`
  4200		Observer      bool                      `json:"observer,omitempty"`
  4201		Paused        bool                      `json:"paused,omitempty"`
  4202		Overrun       bool                      `json:"overrun,omitempty"`
  4203		OverrunCount  uint64                    `json:"overrun_count,omitempty"`
  4204		Committed     uint64                    `json:"committed"`
  4205		Applied       uint64                    `json:"applied"`
  4206		CatchingUp    bool                      `json:"catching_up,omitempty"`
  4207		Leader        string                    `json:"leader,omitempty"`
  4208		LeaderSince   *time.Time                `json:"leader_since,omitempty"`
  4209		EverHadLeader bool                      `json:"ever_had_leader"`
  4210		Term          uint64                    `json:"term"`
  4211		Vote          string                    `json:"voted_for,omitempty"`
  4212		PTerm         uint64                    `json:"pterm"`
  4213		PIndex        uint64                    `json:"pindex"`
  4214		SystemAcc     bool                      `json:"system_account"`
  4215		TrafficAcc    string                    `json:"traffic_account"`
  4216		IPQPropLen    int                       `json:"ipq_proposal_len"`
  4217		IPQEntryLen   int                       `json:"ipq_entry_len"`
  4218		IPQRespLen    int                       `json:"ipq_resp_len"`
  4219		IPQApplyLen   int                       `json:"ipq_apply_len"`
  4220		WAL           StreamState               `json:"wal"`
  4221		WALError      error                     `json:"wal_error,omitempty"`
  4222		Peers         map[string]RaftzGroupPeer `json:"peers"`
  4223	}
  4224	
  4225	type RaftzGroupPeer struct {
  4226		Name                string `json:"name"`
  4227		Known               bool   `json:"known"`
  4228		LastReplicatedIndex uint64 `json:"last_replicated_index,omitempty"`
  4229		LastSeen            string `json:"last_seen,omitempty"`
  4230	}
  4231	
  4232	type RaftzStatus map[string]map[string]RaftzGroup
```

### `server/monitor.go` lines 4234–4254 — `HandleRaftz` — the HTTP query parameters are **`acc`** and `group`

```go
  4234	func (s *Server) HandleRaftz(w http.ResponseWriter, r *http.Request) {
  4235		if s.raftNodes == nil {
  4236			w.WriteHeader(404)
  4237			w.Write([]byte("No Raft nodes registered"))
  4238			return
  4239		}
  4240	
  4241		groups := s.Raftz(&RaftzOptions{
  4242			AccountFilter: r.URL.Query().Get("acc"),
  4243			GroupFilter:   r.URL.Query().Get("group"),
  4244		})
  4245	
  4246		if groups == nil {
  4247			w.WriteHeader(404)
  4248			w.Write([]byte("No Raft nodes returned, check supplied filters"))
  4249			return
  4250		}
  4251	
  4252		b, _ := json.MarshalIndent(groups, "", "   ")
  4253		ResponseHandler(w, r, b)
  4254	}
```

### `server/monitor.go` lines 4256–4268 — `Raftz` — with no account filter, only the **system account's** groups are listed

```go
  4256	func (s *Server) Raftz(opts *RaftzOptions) *RaftzStatus {
  4257		afilter, gfilter := opts.AccountFilter, opts.GroupFilter
  4258	
  4259		if afilter == _EMPTY_ {
  4260			if sys := s.SystemAccount(); sys != nil {
  4261				afilter = sys.Name
  4262			} else {
  4263				return nil
  4264			}
  4265		}
  4266	
  4267		groups := map[string]RaftNode{}
  4268		infos := RaftzStatus{} // account -> group ID
```

## server/monitor.go — the HTTP query names the other handlers read

Each line is the handler's own parameter decode, quoted with its line number; the docs' request schema for the same page is in `inbox/docs-issues.md` #48.

### `HandleAccountz` (lines 2770–2784)

```go
  2774		if l, err := s.Accountz(&AccountzOptions{r.URL.Query().Get("acc")}); err != nil {
```

### `HandleJsz` (lines 3400–3471)

```go
  3404		accounts, err := decodeBool(w, r, "accounts")
  3408		streams, err := decodeBool(w, r, "streams")
  3412		consumers, err := decodeBool(w, r, "consumers")
  3416		directConsumers, err := decodeBool(w, r, "direct-consumers")
  3420		config, err := decodeBool(w, r, "config")
  3424		offset, err := decodeInt(w, r, "offset")
  3428		limit, err := decodeInt(w, r, "limit")
  3432		leader, err := decodeBool(w, r, "leader-only")
  3436		rgroups, err := decodeBool(w, r, "raft")
  3441		sleader, err := decodeBool(w, r, "stream-leader-only")
  3447			Account:          r.URL.Query().Get("acc"),
```

### `HandleLeafz` (lines 2507–2529)

```go
  2512		subs, err := decodeBool(w, r, "subs")
  2516		l, err := s.Leafz(&LeafzOptions{subs, r.URL.Query().Get("acc")})
```

### `HandleSubsz` (lines 1104–1148)

```go
  1109		subs, err := decodeBool(w, r, "subs")
  1113		offset, err := decodeInt(w, r, "offset")
  1117		limit, err := decodeInt(w, r, "limit")
  1121		testSub := r.URL.Query().Get("test")
  1123		filterAcc := r.URL.Query().Get("acc")
```

### `HandleGatewayz` (lines 2368–2407)

```go
  2377		accs, err := decodeBool(w, r, "accs")
  2381		gwName := r.URL.Query().Get("gw_name")
  2382		accName := r.URL.Query().Get("acc_name")
```

### `HandleConnz` (lines 734–796)

```go
   735		sortOpt := SortOpt(r.URL.Query().Get("sort"))
   736		auth, err := decodeBool(w, r, "auth")
   744		offset, err := decodeInt(w, r, "offset")
   748		limit, err := decodeInt(w, r, "limit")
   752		cid, err := decodeUint64(w, r, "cid")
   761		user := r.URL.Query().Get("user")
   762		acc := r.URL.Query().Get("acc")
   763		mqttCID := r.URL.Query().Get("mqtt_client")
```

## server/store.go — the `wal` object

### `server/store.go` lines 167–180 — `StreamState` — what `/raftz`'s `wal` carries

```go
   167	type StreamState struct {
   168		Msgs        uint64            `json:"messages"`
   169		Bytes       uint64            `json:"bytes"`
   170		FirstSeq    uint64            `json:"first_seq"`
   171		FirstTime   time.Time         `json:"first_ts"`
   172		LastSeq     uint64            `json:"last_seq"`
   173		LastTime    time.Time         `json:"last_ts"`
   174		NumSubjects int               `json:"num_subjects,omitempty"`
   175		Subjects    map[string]uint64 `json:"subjects,omitempty"`
   176		NumDeleted  int               `json:"num_deleted,omitempty"`
   177		Deleted     []uint64          `json:"deleted,omitempty"`
   178		Lost        *LostStreamData   `json:"lost,omitempty"`
   179		Consumers   int               `json:"consumer_count"`
   180	}
```

## server/raft.go — the append-entry batch that the docs say `/raftz` documents

### `server/raft.go` lines 3249–3251 — `runAsLeader` — proposals are batched into append entries of at most 256 KB or 512 entries

```go
  3249			case <-n.prop.ch:
  3250				const maxBatch = 256 * 1024
  3251				const maxEntries = 512
```


## Observed — the endpoint on the running cluster (n1–n4, cluster `east`, 2026-09-01)

### A bare `/raftz` shows only the system account's groups

`/raftz` on n1, a follower (indented as the server prints it, `json.MarshalIndent` with three spaces):

```json
{
 "$SYS": {
  "_meta_": {
   "id": "fjFyEjc1", "state": "FOLLOWER", "size": 4, "quorum_needed": 3,
   "committed": 84, "applied": 84, "leader": "44jzkV9D", "ever_had_leader": true,
   "term": 8, "voted_for": "44jzkV9D", "pterm": 8, "pindex": 84,
   "system_account": true, "traffic_account": "$SYS",
   "ipq_proposal_len": 0, "ipq_entry_len": 0, "ipq_resp_len": 0, "ipq_apply_len": 0,
   "wal": { "messages": 0, "bytes": 0, "first_seq": 85, "first_ts": "0001-01-01T00:00:00Z",
            "last_seq": 84, "last_ts": "2026-09-01T19:48:59.020964Z", "consumer_count": 0 },
   "peers": {
    "44jzkV9D": { "name": "n2", "known": true, "last_seen": "101.224417ms" },
    "BXScrY9i": { "name": "n3", "known": true },
    "C7B8kAbl": { "name": "n4", "known": true }
   }
  }
 }
}
```

The same group from the **leader** (n2, via `nats server request raft --group _meta_`, which returns
the identical object under `data`): `"state": "LEADER"`, `"leader_since": "2026-09-01T19:42:06.01775Z"`,
and every peer carries `"last_replicated_index": 84` and a `last_seen` — a follower reports
`last_seen` for the leader only, and `last_replicated_index` for nobody. `voted_for` is absent on the
two followers that had not voted in term 8. `wal.messages: 0` with `first_seq: 85` and `last_seq: 84`
is a log fully compacted by the last snapshot.

### Filters, tried

| request | result |
|---|---|
| `/raftz` | `{"$SYS": {"_meta_": …}}` — the system account only |
| `/raftz?acc=$G` | `{"$G": {"S-R3F-RCvvHwre": …}}` — the `ORDERS` stream's group |
| `/raftz?acc=NOPE` | `{}` (HTTP 200) |
| `/raftz?group=S-R3F-RCvvHwre` | `{}` — the group exists, but the account filter defaulted to `$SYS`; both are needed |
| `/raftz?group=NOPE` | `{}` |
| **`/raftz?account=NOPE`** | `{"$SYS": {"_meta_": …}}` — **the documented parameter name is ignored** |

### The documented parameter names on the sibling endpoints

```
/accountz?account=NOPE   → 200, the normal page          (documented name, ignored)
/accountz?acc=NOPE       → 400 "Account NOPE does not exist"   (the handler's name)
/raftz?account=NOPE      → 200, {"$SYS": {"_meta_": …}}
/raftz?acc=NOPE          → 200, {}
/jsz?account=NOPE  and  /jsz?acc=NOPE   → both 200 with the summary and no account_details (indistinguishable on this cluster)
```

`nats server request raft --account <a> --group <g>` — the **system-request** form
(`$SYS.REQ.SERVER.PING.RAFTZ`) — takes the names the docs print, because those are `RaftzOptions`'s
JSON tags. The HTTP handler reads `acc`.
