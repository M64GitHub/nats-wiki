---
title: "docs — Monitoring: Profiling the server"
type: summary
area: [monitoring, deploy]
source-url: https://docs.nats.io/learn/monitoring/profiling.md
source-path: raw/nats-docs/learn/monitoring/profiling.md
author: nats-io docs
article: "learn/monitoring/profiling.md"
date: 2026-09-01
version: ""
tags: [pprof, profilez, prof_port, prof_block_rate, heap, goroutine, PROFILEZ]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — Monitoring: Profiling the server

The method behind a pointer [[jetstream-sizing]] has been making for five plans — "profile with Go's
`pprof`" — with no instructions attached.

## Key claims

**Two routes, both producing the same pprof file**: `nats server request profile` over the system
account, and the server's own HTTP profiling port.

**The system-account route needs no config change and no restart.** The request travels on
**`$SYS.REQ.SERVER.PING.PROFILEZ`**, "so your context has to be connected to the **system
account**. A normal account like `ACME` has no permission on `$SYS`, so the request gets no replies."
Every server that answers writes its own file:

```
nats server request profile heap
Server "n1-east" profile written: heap-20260824-141530-n1-east
```

named `<profile>-<timestamp>-<server>`. `--name`, `--host`, `--cluster` and `--tags` narrow which
servers answer, and they combine.

**Which profile answers which symptom:**

| profile | holds | ask when |
|---|---|---|
| `heap` | live objects only | memory is growing and you want to know what still holds it |
| `allocs` | every allocation since startup, freed included | memory churn |
| `goroutine` | a stack trace per live goroutine | the server looks stuck, or goroutines climb |
| `cpu` | stacks sampled over a fixed window | a node is pinning a core |

Also served: `block`, `mutex`, `threadcreate`. "Memory and goroutine profiles return immediately…
A CPU profile has to watch the process for a while, so the request blocks."

**CPU sampling has a 15-second server-side cap on the `$SYS` route.** "For `cpu`, the CLI reuses the
global `--timeout` flag as the sampling window. The default is `5s`… The server rejects a window longer
than **15 seconds** and returns an error instead of a profile, so a long capture has to come from the
profiling port."

**The profiling port is `prof_port`, and it is not reloadable.** "A SIGHUP won't pick it up and the
node has to restart before the port comes up." Once up,
`http://localhost:65432/debug/pprof/` serves the standard handlers, and `?seconds=30` is accepted
because "the 15-second cap is a limit of the system-account handler, not of `pprof`".

**Three pitfalls, and the first is a security one:**

- **`prof_port` has no authentication.** "Anyone who can reach `:65432` can pull a goroutine dump, and
  a goroutine dump shows subjects and internal state. The port also binds to the same host as the
  client port, `host`, which defaults to `0.0.0.0` and covers every interface; **there is no separate
  profiling host to narrow**." The `$SYS` route "carries no such exposure because it's authenticated
  like any other `$SYS` request, so prefer it."
- **Turning `prof_port` on costs a restart** — "not what you want mid-incident, when the state you're
  chasing may not survive the restart".
- **Block profiling is empty until enabled.** `prof_block_rate` must be above zero; unlike
  `prof_port` it **is** reloadable, "so you can raise it with a SIGHUP, take the profile, and drop it
  back to zero. Leave it off the rest of the time; block sampling slows the server down."

**Reading it**: `go tool pprof -top <file>` or `go tool pprof -http=:8080 cpu.prof`. "If you're
collecting the profile for someone else to read, you need neither; send the file as it is."

## Practical takeaways

- The ordering is the useful part: reach for `nats server request profile` first because it needs no
  config change and no restart, and only fall back to `prof_port` when you need a CPU window longer
  than 15 seconds.
- `prof_port` on `0.0.0.0` with no auth and no way to narrow the host is a genuine hardening item, not
  a theoretical one.

## Notable quotes

> "A goroutine dump shows subjects and internal state."

> "Leave `prof_port` unset in production."

## Relevance to the wiki

Closes a dangling forward reference on [[jetstream-sizing]], and adds `$SYS.REQ.SERVER.PING.PROFILEZ`
to [[monitoring-endpoints]]'s `$SYS` subjects. **No page was created for it**: no question in
`inbox/question-bank.md` asks about profiling, and a search of `nats-io/nats-server` discussions for
one returned nothing, so the scope test in `CLAUDE.md` says the material belongs on existing pages.

## Questions it answers

None. Recorded as such: the bank has no profiling row and none was invented.

## Pages touched

[[jetstream-sizing]] · [[monitoring-endpoints]] · [[config-keys]]

## Sources

`raw/nats-docs/learn/monitoring/profiling.md`
