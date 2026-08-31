---
title: "nats-server v2.14.6 — lame-duck mode as implemented"
type: summary
area: [deploy, jetstream]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/server.go#L4439
source-path: raw/nats-server-src/lame-duck-v2.14.6.md
author: nats-io/nats-server maintainers
article: "Server.lameDuckMode(), validateOptions() and transferRaftLeaders() at tag v2.14.6"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [lame-duck, ldm, lame_duck_duration, lame_duck_grace_period, stepdown, drain, log-lines]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — lame-duck mode as implemented

Read to check one piece of sizing advice in [[s-docs-rolling-upgrades]] — that
`lame_duck_duration` should cover how long JetStream needs to move leadership off the node. **The
code puts that work before the timer starts**, so the duration does not govern it. Everything else on
that page holds, and the code adds three numbers the docs do not give.

## Key claims

**The drain, in the order the code runs it** (`server/server.go:4439–4565`):

1. `s.Noticef("Entering lame duck mode, stop accepting new clients")`, set `s.ldm = true`, send the
   `$SYS` shutdown event, **close the client listener** (and the websocket server).
2. **`transferRaftLeaders()`** — `StepDown()` on **every** Raft node this server holds, then
   `SetObserver(true)` on each so it stops campaigning. If anything transferred, wait a **fixed one
   second** (`case <-time.After(time.Second)`).
3. `shutdownJetStream()`, then `shutdownRaftNodes()`.
4. Wait for the accept loops to finish, so no new client can arrive.
5. **If no clients remain, `Shutdown()` immediately** — the drain is over.
6. Compute the close schedule, send `INFO ldm:true` to routes and clients.
7. Wait `lame_duck_grace_period`, log `Closing existing clients`.
8. Close each connection with a randomised pause between them, then `Shutdown()`.

**The arithmetic the docs do not state** (`server.go:4496–4518`):

```go
	dur := int64(opts.LameDuckDuration)
	dur -= int64(gp)
	if dur <= 0 {
		dur = int64(time.Second)
	}
	numClients := int64(len(s.clients))
	…
	si = dur / numClients
	…
	} else if si > int64(time.Second) {
		// Conversely, there is no need to sleep too long between clients
		// and spread say 10 clients for the 2min duration. Sleeping no
		// more than 1sec.
		si = int64(time.Second)
	}
```

So:

- **the spread window is `lame_duck_duration` − `lame_duck_grace_period`**, not the whole duration;
- **the interval between closes is capped at one second**, so a node with few clients finishes long
  before the duration — 10 clients drain in about 10 seconds no matter how large the duration is;
- the actual pause is **randomised**, at least `si/2` (`rand.Int63n(si)`), which is what keeps the
  reconnects from arriving in lockstep;
- with very many clients the closes are **batched** (`batch = numClients / dur`) with a 1 ns interval.

**The grace period's real purpose is stated in the code comment** (`server.go:4533–4535`), and it is
not the one the docs give:

> "Delay start of closing of client connections in case we have several servers that we want to
> signal to enter LD mode and not have their client reconnect to each other."

It exists for the case where you signal **several** nodes at once — the delay keeps clients from
reconnecting onto another node that is also leaving.

**The grace-period rule is enforced at startup** (`server.go:1152–1155`):

```go
	if o.LameDuckDuration > 0 && o.LameDuckGracePeriod >= o.LameDuckDuration {
		return fmt.Errorf("lame duck grace period (%v) should be strictly lower than lame duck duration (%v)",
```

and `lame_duck_duration`'s 30-second minimum is enforced at config parse
(`opts.go:1467`): `invalid lame_duck_duration of %v, minimum is 30 seconds`.

**The two log lines a drain writes**: `Entering lame duck mode, stop accepting new clients` and, one
grace period later, `Closing existing clients`.

## Practical takeaways

- **`lame_duck_duration` governs client disconnects and nothing else.** Raft stepdown, JetStream
  shutdown and Raft-node shutdown all happen *before* the timer starts, and the only wait they get is
  a fixed one second. Sizing the duration up does not give JetStream more time; it spreads client
  reconnects further apart.
- **A quiet node exits at once**, which is why an operator watching `systemctl` sees a "drain" that
  took no time — the behaviour a maintainer describes in [[s-gh-6070-lame-duck-under-systemd]],
  here visible as an explicit early `Shutdown()`.
- **The useful mental model is `grace + min(duration − grace, ~1s × clients)`.** On a node with 10
  clients and the defaults, that is about 20 seconds, not 2 minutes.
- **The draining node's Raft groups become observers**, so it cannot win an election on the way out
  even if the stepdown lost a race.
- **Grace period matters when draining several nodes at once**, which is exactly what a careful
  rolling upgrade does *not* do — one node at a time makes it close to free.

## Notable quotes

> "Delay start of closing of client connections in case we have several servers that we want to
> signal to enter LD mode and not have their client reconnect to each other."

## Relevance to the wiki

The drain section and the timing advice in [[upgrade-a-cluster]], and the reason that page states
what `lame_duck_duration` does *not* cover. Recorded upstream as `inbox/docs-issues.md` #13.

## Questions it answers

**Q63** in part; explains the behaviour behind **Q93**.

## Pages touched

[[upgrade-a-cluster]] · [[install-nats-server]] · [[defaults-and-limits]] · [[config-keys]] ·
[[raft-in-nats]]
