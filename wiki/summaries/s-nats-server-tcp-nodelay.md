---
title: "nats-server 2.14.6 — TCP_NODELAY, read from two source trees"
type: summary
area: [core, deploy, clients]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6
source-path: raw/nats-server-src/tcp-nodelay-v2.14.6.md
author: nats-io/nats-server (v2.14.6) and the Go standard library (go1.27.0)
article: "grep for SetNoDelay across the server tree, and net/tcpsock.go's newTCPConn"
date: 2026-09-04
version: "2.14"
tags: [tcp, nagle, tcp-nodelay, latency, sockets, go]
aliases: [TCP_NODELAY, Nagle, nagle's algorithm, SetNoDelay]
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# nats-server 2.14.6 — `TCP_NODELAY`, read from two source trees

Question-bank row 148 asks whether Nagle's algorithm is disabled on client and route connections
([gh#4267](https://github.com/nats-io/nats-server/discussions/4267)). The answer is not in the
server's source at all, and that absence is the answer.

## Key claims

- **The server never touches the option.** A grep of the whole v2.14.6 release tree — `server/`,
  `internal/`, `logger/`, `util/`, `test/`, `conf/`, `main.go` — for `SetNoDelay`, `NoDelay` and
  `TCP_NODELAY` returns **no matches**. There is no configuration key either: nothing shaped like
  `no_delay`, `nodelay` or `tcp_nodelay` in `server/opts.go` or `conf/`.
- **Go sets it, unconditionally, for every TCP connection.** `net.newTCPConn` — the constructor every
  accepted and every dialled `*TCPConn` passes through — begins `setNoDelay(fd, true)`
  (`$GOROOT/src/net/tcpsock.go:289–290`, go1.27.0). The exported method's comment states the default
  in words: "The default is true (no delay), meaning that data is sent as soon as possible after a
  Write."
- **So Nagle is off on every connection the server accepts or dials** — client, route, leafnode,
  gateway, WebSocket and MQTT — and it is off because Go set it, not because NATS chose it. It cannot
  be turned on through configuration.
- **The same holds for the Go clients** (nats.go, and the `nats` CLI built on it). Nothing here says
  what a client in another language does; a runtime whose sockets default to Nagle **on** would have
  to disable it itself.

## Practical takeaways

- Do not look for a `no_delay` knob when chasing latency; it does not exist and would not help.
- A 40 ms-shaped latency artefact on a NATS link is not Nagle on the NATS sockets. Look at the path
  instead — a proxy, a load balancer or a sidecar that terminates the connection has its own socket
  options ([[run-nats-behind-a-proxy]]).
- If you write a non-Go client, set the option yourself.

## Notable quotes

> "The default is true (no delay), meaning that data is sent as soon as possible after a Write."
> — `net/tcpsock.go`, `SetNoDelay`'s doc comment, go1.27.0

## Relevance to the wiki

It closes a question the wiki could not answer from the docs — no docs.nats.io page mentions
`TCP_NODELAY` — with a reading of the two trees that actually decide it.

## Questions it answers

148.

## Pages touched

[[defaults-and-limits]] · [[wire-protocol]]

## Sources

*(no wiki summary is a source for this page: it is a first reading of two source trees)*
