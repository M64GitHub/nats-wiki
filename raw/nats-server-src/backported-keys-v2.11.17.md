<!-- source: https://github.com/nats-io/nats-server at tags v2.10.29 and v2.11.17, file server/opts.go, from the release tarballs `tools/check-defaults.py` caches under .cache/ · read 2026-09-03 · excerpts with line numbers, for docs issue #64 and the default diff of inbox/plan-change-layer-2026-09-03.md step 8 -->
# nats-server source excerpts: config keys the docs date to 2.12 that the 2.11 line parses

Read 2026-09-03 after `python3 tools/check-defaults.py --tag v2.10.29 / v2.11.17 / v2.12.15`: the
resolver found `cluster.write_deadline`, `gateway.write_deadline`, `leafnodes.write_deadline` and
`websocket.ping_interval` resolvable at **v2.11.17** and not at **v2.10.29**, while the docs'
generated reference says each is "Available since NATS Server `2.12`". These are the parse sites.

## `server/opts.go` at tag v2.11.17

```
1301	case "write_deadline":
1302		o.WriteDeadline = parseDuration("write_deadline", tk, v, errors, warnings)
1303	case "write_timeout":
...
1815	func parseCluster(v any, opts *Options, errors *[]error, warnings *[]error) error {
...
1948		case "write_deadline":
1949			opts.Cluster.WriteDeadline = parseDuration("write_deadline", tk, mv, errors, warnings)
1950		case "write_timeout":
1951			opts.Cluster.WriteTimeout = parseWriteDeadlinePolicy(tk, mv.(string), errors)
...
2056	func parseGateway(v any, o *Options, errors *[]error, warnings *[]error) error {
...
2138		case "write_deadline":
2139			o.Gateway.WriteDeadline = parseDuration("write_deadline", tk, mv, errors, warnings)
2140		case "write_timeout":
...
2547	func parseLeafNodes(v any, opts *Options, errors *[]error, warnings *[]error) error {
...
2636		case "write_deadline":
2637			opts.LeafNode.WriteDeadline = parseDuration("write_deadline", tk, mv, errors, warnings)
2638		case "write_timeout":
...
5110	func parseWebsocket(v any, o *Options, errors *[]error, warnings *[]error) error {
...
5211		case "ping_interval":
5212			o.Websocket.PingInterval = parseDuration("ping_interval", tk, mv, errors, warnings)
```

## `server/opts.go` at tag v2.10.29

`grep -c '"write_timeout"'` → **0**. `"write_deadline"` occurs once, at line 1173, in
`processConfigFileLine` (the top-level key); no block-level case. `"ping_interval"` occurs for the
top level (line 1099) and the `cluster` block (line 1790); none in `parseWebsocket`.

## The release bodies that announce each key

- `write_timeout`: `raw/release-notes/v2.11.11.md` line 25 — "Added `write_timeout` option for
  clients, routes, gateways and leafnodes which controls the behaviour on reaching the
  `write_deadline`" (2025-11-13; also v2.12.2).
- `websocket { ping_interval }`: `raw/release-notes/v2.11.12.md` line 26 — "Added WebSocket-specific
  ping interval configuration with `ping_internal` in the `websocket` block (#7614)" (2026-01-27;
  also v2.12.3).
- block-level `write_deadline`: announced only in `raw/release-notes/v2.12.1.md` (#7405,
  2025-10-14); **no 2.11 body names it** — v2.11.10 (2025-10-14, the same-day twin) does not, yet
  the v2.11.17 parser has it. Which 2.11 patch carried it was not determined.

## The docs' lines

`raw/nats-docs/reference/config/cluster/write_deadline.md`, `gateway/write_deadline.md`,
`leafnodes/write_deadline.md`, `write_timeout.md`, `websocket/ping_interval.md` — each: "Available
since NATS Server `2.12`" (fetched 2026-08-31).
