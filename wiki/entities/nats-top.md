---
title: nats-top
type: entity
kind: tool
area: [monitoring]
verified-against: nats-top v0.6.4
verified-on: 2026-08-31
tags: [tool, nats-top, monitoring, connections, slow-consumers, mit]
aliases: [nats-top, "nats-io/nats-top"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-gh-2818-counters-exact-or-sampled, s-nats-server-traffic-counters-and-ha-assets]
created: 2026-08-31
updated: 2026-09-03
---

# nats-top

A **`top`-like live view of one server** — connections, subscriptions, pending bytes and slow
consumers, refreshed on an interval (source: [[s-docs-ecosystem]]).

## Where it fits

Between `curl`-ing [[monitoring-endpoints]] by hand and running a Prometheus stack. It reads the
same monitoring port as [[prometheus-nats-exporter]], but for a human, now, on one node.

## Facts

| | |
|---|---|
| repo | `nats-io/nats-top` |
| latest release | **v0.6.4**, 2026-03-26 |
| licence | **MIT** (not Apache-2.0, unlike most of the ecosystem) |
| reads | the HTTP monitoring port, `-m` (or `-ms` for HTTPS) |
| bundled in | [[nats-box]] |

```
curl -sf https://binaries.nats.dev/nats-io/nats-top@latest | sh
go install github.com/nats-io/nats-top@latest
```

## What an operator needs to know

- **It answers "who is the noisy connection" faster than anything else.** The per-connection table
  carries `SUBS`, `PENDING`, `MSGS_TO/FROM`, `BYTES_TO/FROM`, `LANG`, `VERSION` and last activity —
  and `-sort by` orders it. Sorting by pending is the first move when a server logs a slow consumer
  (see [[slow-consumer-detected]]).
- **The header line is a whole-server summary**: uptime, CPU, memory, **`Slow Consumers`** count, and
  in/out message and byte rates.
- **It is a node-local tool.** It reads one server's monitoring port; a cluster-wide picture is
  `nats server report` ([[nats-cli]]) or [[nats-surveyor]].
- **`-o FILE` makes it scriptable** — takes the first snapshot, writes it, exits. With `-l DELIMITER`
  the output is delimited rather than the grid, which is how you get a one-shot sample into a file
  without a metrics stack.

## Cheat sheet

```
nats-top                                   # default: localhost:8222, refresh every 1s
nats-top -s n1-east -m 8222                # a specific server and monitoring port
nats-top -n 1024                           # limit connections requested (default 1024)
nats-top -d 5                              # refresh every 5 seconds
nats-top -r 1                              # refresh once, then exit
nats-top -o snapshot.txt -l ,              # one snapshot to a file, comma-delimited ('-' = stdout)
nats-top -sort pending                     # sort the connection table
nats-top -u                                # show the subscriptions column
nats-top -ms 8443 -cert c.pem -key k.pem -cacert ca.pem   # over HTTPS
```

## The counters it shows are exact, and per server

The message and byte counts are not sampled: every inbound message adds one and its payload length to
the server's counters atomically (`client.go:4345–4346`, `:1607–1633`, v2.14.6), and `/varz` and
`/connz` read them with an atomic load (`monitor.go:1900–1907`) — "Yes that is correct", in the
maintainer's words, with the caveat "it's per server though — nats top is not cluster aware". The byte
figures are payload bytes, not wire bytes. A cluster total is the sum over every node's
[[prometheus-nats-exporter]] ([[metrics]]) (source: [[s-gh-2818-counters-exact-or-sampled]],
[[s-nats-server-traffic-counters-and-ha-assets]]).


## Related

[[monitoring-endpoints]] · [[nats-cli]] · [[nats-surveyor]] · [[prometheus-nats-exporter]] ·
[[slow-consumer-detected]] · [[nats-box]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-gh-2818-counters-exact-or-sampled]] · [[s-nats-server-traffic-counters-and-ha-assets]]
