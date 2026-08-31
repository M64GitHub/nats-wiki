---
title: "gh#6070 — Lame Duck Mode (under systemd)"
type: summary
area: [deploy]
source-url: https://github.com/nats-io/nats-server/discussions/6070
source-path: raw/gh-discussions/gh-6070.md
author: "@zakk616 (asking), @derekcollison and @ripienaar (maintainers, replying)"
article: "Lame Duck Mode"
date: 2024-11-02
version: "2.10.19"
tags: [lame-duck, ldm, SIGUSR2, systemd, ExecStop, TimeoutStopSec, rolling-upgrade]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#6070 — Lame Duck Mode (under systemd)

An operator draining a server with `nats-server --signal ldm` while systemd owns the process, and
finding the unit ends `Active: failed`. **No accepted answer**, but both maintainer replies land on
the same point: under systemd, drain through the unit, not around it.

## Key claims

**The setup:** `nats-server` **2.10.19** under systemd, drained with

```
nats-server --signal ldm
systemctl status nats-server.service      # reports Active: failed, not Active: inactive
```

with, in the reporter's words, "the default `lame_duck_duration: 2m` and
`lame_duck_grace_period: 10s`" — an independent confirmation of the two defaults this wiki reads from
`server/const.go` ([[defaults-and-limits]]).

**A drain can finish early, and that is normal** (@derekcollison):

> "If the server does not have alot of client connections it can exit earlier then lame duck
> duration. If it has no clients it could exit immediately."

So **`lame_duck_duration` is a ceiling on the spread of disconnects, not a duration the server waits
out.** A quiet node exits at once.

**The reporter's own diagnosis is the useful part.** With 14 connections neither
`nats-server --signal ldm` nor `systemctl stop nats-server.service` stopped it gracefully — and his
unit read:

```ini
ExecStop=/bin/kill -s SIGINT $MAINPID
```

**SIGINT, not SIGUSR2.** A unit wired to SIGINT does not enter lame-duck mode at all; the drain the
operator thought he was configuring never happened.

**The maintainer's rule for systemd deployments** (@ripienaar):

> "I think if you're setting a `ExecStop` in the unit file you probably shouldn't make it exit using
> `nats-server --signal` but always using the `systemctl` command."

**The thread has no accepted answer** and the `Active: failed` status is never explained.

## Practical takeaways

- **The signal in `ExecStop` is the whole feature.** `SIGUSR2` drains; `SIGINT`/`SIGTERM` stop. The
  unit the server repo ships gets this right (`ExecStop=/bin/kill -s SIGUSR2 $MAINPID`, see
  [[s-nats-server-systemd-units]]); a hand-written unit is exactly where it goes wrong, and this
  thread is what that looks like from the operator's side.
- **Pick one drain path.** With systemd owning the process, `systemctl stop` and
  `nats-server --signal ldm` race each other — the second drains a process the first will also try to
  stop, and the unit's state machine is left describing something that did not happen.
- **Do not read a fast exit as a failed drain.** With few or no clients the server exits immediately
  by design.
- **`Active: failed` after a drain is unexplained in public sources.** Worth knowing before it is
  alarming: this wiki has no verified cause for it. *(unverified)*

## Notable quotes

> "If the server does not have alot of client connections it can exit earlier then lame duck
> duration." — @derekcollison

> "If you're setting a `ExecStop` in the unit file you probably shouldn't make it exit using
> `nats-server --signal` but always using the `systemctl` command." — @ripienaar

## Relevance to the wiki

Why [[install-nats-server]] states the `ExecStop` signal explicitly instead of leaving the unit to
the reader, and the drain step the rolling-upgrade runbook ([[upgrade-a-cluster]], step 2 of the
current plan) will build on.

## Questions it answers

**Q93** (added with this ingest); contributes to **Q63**.

## Pages touched

[[install-nats-server]] · [[defaults-and-limits]] · [[config-keys]]
