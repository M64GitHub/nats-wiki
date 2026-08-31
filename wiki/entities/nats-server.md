---
title: nats-server
type: entity
kind: repo
area: [core, jetstream, topology, security, deploy]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [repo, server, cncf, apache-2.0, security-audit, docker, single-binary]
aliases: [nats-server, "nats-io/nats-server", the server, nats server]
sources: [s-nats-server-systemd-units, s-docs-hardening, s-nats-server-readme, s-github-repo-facts, s-docs-ecosystem, s-docs-getting-started, s-nats-server-constants-2.14.6]
created: 2026-08-31
updated: 2026-08-31
---

# nats-server

**The whole system, in one binary.** Clustering, JetStream, leafnodes, gateways, MQTT and WebSocket
are configuration on the same process — "there are no separate components to install" (source:
[[s-docs-ecosystem]]). It is also this wiki's **authority**: when a doc page and the server disagree,
the server at a release tag wins.

## Where it fits

Everything else in `wiki/entities/` is either a client that talks to it, a tool that inspects it, or
a release of it.

## Facts

| | |
|---|---|
| repo | `nats-io/nats-server` |
| created | 2012-10-29 |
| latest release | **v2.14.6**, 2026-08-27 |
| licence | **Apache-2.0** |
| foundation | **CNCF** — "NATS is part of the Cloud Native Computing Foundation" |
| language | Go (v2.14.0 built with Go 1.26.2) |
| Docker | the Docker Official Image **`_/nats`** |
| Helm | Artifact Hub, `helm/nats/nats` — see [[nats-helm-charts]] |
| security contact | `security@nats.io` (not public issues) |
| known minors | 2.10, 2.11, 2.12, 2.14 — **there is no 2.13**; 2.15 exists only as a preview |
| clients | "over 40 client language implementations" counting community ones; twelve are Synadia-maintained |

## Security

A **third-party security audit** was performed by **Trail of Bits**, engaged through the **Open
Source Technology Improvement Fund (OSTIF)**, with the full report published **April 2025** in the
`trailofbits/publications` repository (source: [[s-nats-server-readme]]). The project also carries a
CII Best Practices badge (project 1895).

This is the answer to the procurement question, and it is public, dated and attributable — worth
knowing before someone asks.

## Running it

```
nats-server                      # core NATS only
nats-server -m 8222              # + the HTTP monitoring port
nats-server -js                  # + JetStream
nats-server -c server.conf -DV   # a config file, with debug and trace logging
docker run -p 4222:4222 -p 8222:8222 nats:latest
```

Ports, all four of which have a documented default and none of which listens unless configured
(beyond 4222): **4222** clients, **6222** cluster routes, **7222** gateways, **8222** HTTP monitoring
(source: [[s-docs-getting-started]], [[s-docs-hardening]]). JetStream is off until you turn it on, and
so is the monitoring port.

**The repo ships its own systemd units** — `util/nats-server.service` and
`util/nats-server-hardened.service` — and they, not the docs' extract, are what
[[install-nats-server]] quotes. Both wire `SIGHUP` to reload and **`SIGUSR2` to a lame-duck drain**
(source: [[s-nats-server-systemd-units]]).

## What an operator needs to know

- **The single binary is a deployment property, not a slogan.** Adding leafnodes or MQTT does not add
  a process to run, monitor or upgrade — it adds a config block. The blast radius of a restart is
  correspondingly wide.
- **The source is readable, and this wiki reads it.** Defaults the docs never state are quoted here
  from `server/*.go` at tag v2.14.6 with file and line — see [[defaults-and-limits]] and
  [[s-nats-server-constants-2.14.6]]. Anyone can check them:
  `https://github.com/nats-io/nats-server/blob/v2.14.6/server/const.go`.
- **Release notes are the change log that matters.** The per-minor entity pages
  ([[nats-server-2.14]], [[nats-server-2.12]], [[nats-server-2.11]], [[nats-server-2.10]],
  [[nats-server-2.15-preview]]) carry what changed and what it costs to move.
- **The server can be embedded.** `go get github.com/nats-io/nats-server/v2` is a supported way to run
  a server inside a Go test — which is why [[nats-py]] ships a `nats-server` package doing the same
  thing for Python.

## Related

[[nats-server-2.14]] · [[nats-server-2.12]] · [[nats-server-2.11]] · [[nats-server-2.10]] ·
[[nats-server-2.15-preview]] · [[nats-architecture-and-design]] · [[nats-cli]] ·
[[defaults-and-limits]] · [[config-keys]] · [[monitoring-endpoints]] · [[cncf]] · [[synadia]] ·
[[nats-go]] · [[install-nats-server]]

## Sources

[[s-nats-server-readme]] · [[s-github-repo-facts]] · [[s-docs-ecosystem]] ·
[[s-docs-getting-started]] · [[s-nats-server-constants-2.14.6]] ·
[[s-nats-server-systemd-units]] · [[s-docs-hardening]]
