---
title: "nats-server v2.14.6 — the signal handler"
type: summary
area: [deploy]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/signal.go
source-path: raw/nats-server-src/signal-v2.14.6.md
author: nats-io/nats-server maintainers
article: "server/signal.go and the Command constants in server/const.go at tag v2.14.6"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [signals, SIGUSR2, SIGTERM, SIGHUP, SIGINT, SIGUSR1, lame-duck, log-rotation, signal-stop]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the signal handler

Twenty-nine lines of `server/signal.go` that decide what every stop, reload and drain in this wiki
actually does. Read to check one claim in [[s-docs-rolling-upgrades]] — that the server ignores
SIGTERM mid-drain — and worth more than that claim.

## Key claims

**The whole table** (`server/signal.go:57–86`, `:148–166`, `server/const.go:23–35`):

| signal | `--signal` name | what the server does |
|---|---|---|
| `SIGINT` | `quit` | `Shutdown()`, wait, `os.Exit(0)` — **immediate, no drain** |
| `SIGTERM` | `term` *(private)* | the same **unless a drain is already in progress**, in which case it is **ignored** |
| `SIGUSR1` | `reopen` | re-open the log file — this is log rotation |
| `SIGUSR2` | `ldm` *(private)* | `go s.lameDuckMode()` — the drain |
| `SIGHUP` | `reload` | `s.Reload()`; on failure logs `Failed to reload server configuration: <err>` |
| — | `stop` | **`SIGKILL`** |

**Every signal is logged before it is acted on:**

```go
func (s *Server) handleSignal(sig os.Signal) {
	s.Noticef("Trapped %q signal", sig)
```

So `Trapped "terminated" signal` / `Trapped "user defined signal 2" signal` in a log is the record of
what a node was asked to do, and the first thing to read when a shutdown did not behave.

**SIGTERM during a drain, verbatim** (`signal.go:64–76`):

```go
	case syscall.SIGTERM:
		// Shutdown unless graceful shutdown already in progress.
		s.mu.Lock()
		ldm := s.ldm
		s.mu.Unlock()

		if !ldm {
			s.Shutdown()
			s.WaitForShutdown()
			os.Exit(0)
		}
```

**`nats-server --signal stop` sends `SIGKILL`** (`signal.go:151–152`, name at `const.go:27`). It is
not a graceful stop and there is no handler for it — the kernel kills the process. The graceful ones
are `ldm` (drain) and `quit` (orderly shutdown, no drain).

**`ldm` and `term` are marked `// private for now`** in the constants, yet `--signal ldm` is what the
Helm chart's `preStop` hook runs (`-sl=ldm=…`) and what the docs teach.

## Practical takeaways

- **The docs' SIGTERM claim is exactly right, and the reason is one boolean.** A node already in
  lame-duck mode ignores SIGTERM, so on Kubernetes only `terminationGracePeriodSeconds` bounds the
  drain — after it, SIGKILL, which no code can catch ([[s-docs-rolling-upgrades]]).
- **A unit with `ExecStop=… SIGINT` (or SIGTERM) does not drain, it stops** — which is precisely the
  report in [[s-gh-6070-lame-duck-under-systemd]], now confirmed in the source rather than inferred.
- **`--signal stop` is the most dangerous string in the CLI surface.** It reads like `systemctl stop`
  and behaves like `kill -9`. Use `ldm` to drain, `quit` to stop.
- **`SIGUSR1` is log rotation**, and nothing in the deployment chapter mentions it. A logrotate
  `postrotate` running `nats-server --signal reopen` is the supported pattern *(the mapping is
  verified; the logrotate integration itself is not documented in any source read — treat the
  suggestion as (unverified))*.
- **`Trapped …` and `Reloaded server configuration` / `Failed to reload server configuration` are the
  three log lines** that tell you whether an operator action landed.

## Relevance to the wiki

The signal table in [[install-nats-server]], the drain step in [[upgrade-a-cluster]], and the reload
mechanism in [[reload-server-config]].

## Questions it answers

Contributes to **Q63** and **Q93**.

## Pages touched

[[install-nats-server]] · [[upgrade-a-cluster]] · [[reload-server-config]] · [[nats-server]]
