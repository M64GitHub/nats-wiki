<!-- source: https://github.com/nats-io/nats-server at tags v2.14.6 and v2.15.0-preview.1, files server/opts.go, server/const.go, server/leafnode.go, server/feature_flags.go, server/jetstream_api.go, read from raw.githubusercontent.com · fetched 2026-09-03 · excerpts with line numbers, quoted for the 2.14 and 2.15 release-note ingest (inbox/plan-change-layer-2026-09-03.md, step 6) -->
# nats-server source excerpts: `dial_timeout`, the feature flags, and the 2.15 preview's API subjects

Read 2026-09-03 while ingesting the 2.14 release bodies and the v2.15.0-preview.1 body. Each excerpt
names the tag, the file and the line so it can be re-read. Nothing here was run; these are reads.

## 1. Leafnode `dial_timeout` — v2.14.5 (#8427), read at v2.14.6

`server/opts.go` (tag v2.14.6):

```
232	// DialTimeout is the amount of time the server will wait for the TCP
233	// connection to a remote server to be established. This is useful on high
234	// latency links where the default (DEFAULT_ROUTE_DIAL, 1 second) is not
235	// enough for the handshake to complete. It applies to all remotes, but can
236	// be overridden on a per-remote basis with RemoteLeafOpts.DialTimeout.
237	// If not set (or <= 0), DEFAULT_ROUTE_DIAL is used.
238	DialTimeout time.Duration `json:"-"`
...
275	// DialTimeout is the amount of time the server will wait for the TCP
276	// connection to this remote server to be established. This is useful on
277	// high latency links where the default is not enough for the handshake to
278	// complete. If not set (or <= 0), the server-wide LeafNodeOpts.DialTimeout
279	// is used, which itself defaults to DEFAULT_ROUTE_DIAL (1 second).
280	DialTimeout time.Duration `json:"-"`
...
2872		case "dial_timeout":
2873			opts.LeafNode.DialTimeout = parseDuration("dial_timeout", tk, mv, errors, warnings)
...
3211			case "dial_timeout":
3212				remote.DialTimeout = parseDuration(k, tk, v, errors, warnings)
```

Line 2872 is inside the `leafnodes { }` block parser; line 3211 inside the parser of one entry of
`leafnodes { remotes [ … ] }`. Both accept a duration.

`server/const.go` (tag v2.14.6):

```
155	// DEFAULT_ROUTE_DIAL Route dial timeout.
156	DEFAULT_ROUTE_DIAL = 1 * time.Second
```

`server/leafnode.go` (tag v2.14.6):

```
604	s.leafNodeOpts.dialTimeout = opts.LeafNode.DialTimeout
605	if s.leafNodeOpts.dialTimeout <= 0 {
606		// Use same timeouts as routes for now.
607		s.leafNodeOpts.dialTimeout = DEFAULT_ROUTE_DIAL
608	}
...
760	// A remote can override the server-wide dial timeout. This is useful on
761	// high latency links where the default is too short for the TCP handshake
762	// to complete.
763	if remote.DialTimeout > 0 {
764		dialTimeout = remote.DialTimeout
765	}
```

Docs check, 2026-09-03: `grep -rli dial_timeout raw/nats-docs/` matches **no file** (861 pages fetched
2026-08-31). `raw/nats-docs/reference/config/leafnodes/` lists `advertise, authorization, compression,
host, isolate_leafnode_interest, listen, min_version, no_advertise, port, reconnect, remotes, tls,
write_deadline, write_timeout`; `…/leafnodes/remotes/` lists `account, compression, credentials,
deny_exports, deny_imports, disabled, first_info_timeout, hub, ignore_discovered_servers,
isolate_leafnode_interest, jetstream_cluster_migrate, nkey, no_randomize, proxy, request_isolation,
tls, url, ws_compression, ws_no_masking`. No `dial_timeout` at either level.

## 2. `feature_flags` — v2.14.0 (#7866), read at v2.14.6 and at v2.15.0-preview.1

`server/feature_flags.go` (tag v2.14.6, 130 lines):

```
22	const (
23		FeatureFlagJsAckFormatV2     = "js_ack_fc_v2"
24		FeatureFlagJsRaftDeleteRange = "js_raft_delete_range"
25	)
26
27	var featureFlags = map[string]bool{
28		// Use v2 format for `$JS.ACK.>` and `$JS.FC.>`.
29		// - Introduced: 2.14.0, both v1 and v2 supported, only using v1.
30		// - Enabled: TBD, both supported, v2 becomes the default.
31		//
32		// - v1: $JS.ACK.<stream name>.<consumer name>.<num delivered>.<stream sequence>.<consumer sequence>.<timestamp>.<num pending>
33		// - v2: $JS.ACK.<domain>.<account hash>.<stream name>.<consumer name>.<num delivered>.<stream sequence>.<consumer sequence>.<timestamp>.<num pending>
34		// See also: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-15.md#jsack
35		FeatureFlagJsAckFormatV2: false,
36
37		// Propose delete range gaps as a single `deleteRangeOp` Raft append entry
38		// instead of one entry per deleted sequence. Dramatically reduces Raft cost
39		// on mirrors whose origin has a large number of interior deletes.
40		// - Introduced: 2.14.0, apply-side always supports receiving `deleteRangeOp`.
41		// - Enabled: TBD, once all supported versions carry the apply-side.
42		//
43		// WARNING: Only enable once every peer in the cluster is on a version that
44		// supports receiving `deleteRangeOp`. Older peers panic on apply of an
45		// unknown stream entry operation.
46		FeatureFlagJsRaftDeleteRange: false,
47	}
...
53	func (o *Options) getFeatureFlag(k string) bool {
54		defaultValue, ok := featureFlags[k]
55		if !ok {
56			return false // Not supported.
57		}
58		if userValue, ok := o.FeatureFlags[k]; ok {
59			return userValue
60		}
```

`server/opts.go` (tag v2.14.6): the `feature_flags` block is parsed at lines 1842–1862 as a map of
name → bool; a non-boolean value is the error `error parsing feature flag "<name>": expected bool,
got <type>`; the struct field is `FeatureFlags map[string]bool` (line 570, "They will be included in
'Z' responses"). `server/server.go` line 2284 calls `s.printFeatureFlags(opts)` at startup.

`server/feature_flags.go` (tag **v2.15.0-preview.1**):

```
23		FeatureFlagJsAckFormatV2     = "js_ack_fc_v2"
24		FeatureFlagJsRaftDeleteRange = "js_raft_delete_range"
25		FeatureFlagJsSnapshotSources = "js_snapshot_sources"
...
30		// - Introduced: 2.14.0, both v1 and v2 supported, only using v1.
31		// - Enabled: TBD, both supported, v2 becomes the default.
...
36		FeatureFlagJsAckFormatV2: false,
...
54		// - Introduced: 2.15.0, both encoding versions are accepted, only emitting v1.
55		// - Enabled: TBD, once all supported versions accept v2.
...
59		FeatureFlagJsSnapshotSources: false,
```

So at the preview tag `js_ack_fc_v2` still defaults to `false` — the v2.14.0 body's "this will be
enabled by default in v2.15" has not happened in the preview.

Docs check, 2026-09-03: `raw/nats-docs/reference/config/feature_flags.md` (whole page): "Available
since NATS Server `2.14` · Requires Restart · Toggles for features that are not yet on by default.
Names are server-internal and change between releases." Type `{ string: boolean }`. No flag is named.
`js_ack_fc_v2` appears only in `release-notes/upgrade-to-2.14.md`; `js_raft_delete_range` and
`js_snapshot_sources` appear nowhere in the docs tree.

## 3. The consumer reset subject — v2.14.0 (#7489), read at v2.14.6

`server/jetstream_api.go` (tag v2.14.6):

```
159	JSApiConsumerResetT = "$JS.API.CONSUMER.RESET.%s.%s"
```

Docs check, 2026-09-03: `raw/nats-docs/reference/jetstream/api/consumer.md` lists nine consumer
endpoints (CREATE, DELETE, INFO, LIST, NAMES, MSG.NEXT, LEADER.STEPDOWN, PAUSE, UNPIN) and
`…/api/consumer/` holds nine pages; `RESET` is on neither. `release-notes/upgrade-to-2.14.md` line 22
describes the "Consumer reset API" without its subject. `grep -rl CONSUMER.RESET raw/nats-docs/`
matches only the upgrade guide.

## 4. The 2.15 preview's new API subjects — read at v2.15.0-preview.1

`server/jetstream_api.go` (tag v2.15.0-preview.1, 5,740 lines):

```
179	// JSApiStreamEvacuatePeer is the endpoint to evacuate a peer from a clustered stream and its consumers.
180	// Will return JSON response.
181	JSApiStreamEvacuatePeer  = "$JS.API.STREAM.PEER.EVACUATE.*"
182	JSApiStreamEvacuatePeerT = "$JS.API.STREAM.PEER.EVACUATE.%s"
183
184	// JSApiStreamCancelMove is the endpoint to cancel an in-progress stream reconfiguration,
185	// rolling the stream back to the config and peers it had before the reconfiguration
186	// started. This is not limited to moves, any in-flight desired state is rolled back,
187	// which includes a scale up/down or a retention change.
188	// Will return JSON response.
189	JSApiStreamCancelMove  = "$JS.API.STREAM.CANCEL_MOVE.*"
190	JSApiStreamCancelMoveT = "$JS.API.STREAM.CANCEL_MOVE.%s"
...
212	// JSApiEvacuateServer is the endpoint to evacuate a peer server from the cluster.
213	// Only works from system account.
214	// Will return JSON response.
215	JSApiEvacuateServer = "$JS.API.SERVER.EVACUATE"
216
217	// JSApiMetaRescue is the endpoint to unsafely lower the meta group's quorum
218	// requirement on the surviving servers for disaster recovery.
219	// This is a broadcast subject, every online server evaluates and responds
220	// to the request independently.
221	// Only works from system account.
222	// Will return JSON response.
223	JSApiMetaRescue = "$JS.API.META.RESCUE"
...
242	JSApiServerStreamCancelMove  = "$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.*.*"
243	JSApiServerStreamCancelMoveT = "$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.%s.%s"
```

The account-level `$JS.API.STREAM.CANCEL_MOVE.<stream>` (line 189) is **new in the preview**; the
system-account `$JS.API.ACCOUNT.STREAM.CANCEL_MOVE.<account>.<stream>` (line 242) already exists at
v2.14.6 (`jetstream_api.go` line 212 there). None of `EVACUATE`, `META.RESCUE` or the account-level
`CANCEL_MOVE` exist in the v2.14.6 file.

## 5. `AckFlowControl` — the constraints, read at v2.14.6

`server/consumer.go` (tag v2.14.6): the policy's JSON name is `flow_control` (line 351); a consumer
with it must be push-based with a `deliver_subject` (line 760), have `flow_control` on (763), a
heartbeat of exactly `1s` (`sourceHealthHB`, 766–768, "since those are used for ephemeral sourcing
consumers as well"), a positive `max_ack_pending` (772), no `ack_wait` and no `backoff` (775), no
`max_deliver` (778). `server/stream.go` lines 3770–3773 (mirror) and 4210–4213 (source): when the
upstream consumer is durable, the server requires `AckFlowControl` and otherwise sets
`NewJSMirrorConsumerRequiresAckFCError` / `NewJSSourceConsumerRequiresAckFCError` and retries.
