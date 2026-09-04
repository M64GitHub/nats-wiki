---
title: nats.py
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.py v2.15.0 · PyPI nats-py 2.15.0 / nats-core 0.2.0
verified-on: 2026-09-04
tags: [client, tier-1, python, asyncio, nats-py, nats-core]
aliases: [nats.py, "nats-io/nats.py", python client, nats-py, nats-core]
sources: [s-docs-ecosystem, s-github-repo-facts, s-gh-4535-unauthenticated-connections, s-docs-getting-started, s-docs-core-nats-subjects-and-mapping, s-nats-server-core-delivery-observed, s-client-releases-and-issues, s-docs-resilient-clients-reconnection-and-events]
created: 2026-08-31
updated: 2026-09-04
---

# nats.py

The **Python client** — "asyncio-based, Python 3 only" (source: [[s-docs-ecosystem]]). The repo is
mid-transition from one package to several, and which package you install decides which Python
version you need.

## Where it fits

Tier 1. The one official client where **the repository name and the installable package name differ**
in a way that currently matters.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.py` |
| tier | **1** |
| latest release | **v2.15.0**, 2026-06-05 |
| licence | Apache-2.0 |
| package (mature) | **`nats-py`** 2.15.0 — `requires_python >=3.7`; README says "compatible with at least Python +3.8" |
| package (new) | **`nats-core`** 0.2.0 — `requires_python >=3.13`, "NATS core implementation in Python" |
| also published | `nats-server` — a library for starting servers and clusters in tests |
| docs | `https://nats-io.github.io/nats.py/` |

```
pip install nats-py                 # the client the docs' examples use
pip install nats-core[websocket]    # the new core package, WebSocket transport behind an extra
```

## What an operator needs to know

- **There are two Python distributions from one repo, and the docs never say so in one place.** The
  README documents `nats-py` and `nats-server`; the repository root also holds `nats-core/`,
  `nats-jetstream/` and `nats-key-value/`; PyPI carries `nats-core` 0.2.0. The **only** mention of
  `nats-core` anywhere in docs.nats.io is a WebSocket page calling it "the new Python client",
  requiring **Python 3.13 or later**. Recorded as `inbox/docs-issues.md` #10.
- **The version floors are far apart.** `nats-py` runs on Python 3.7+; `nats-core` demands 3.13+. A
  service on an older interpreter has exactly one option today.
- **WebSocket is an optional extra in the new package.** "plain `pip install nats-core` can't open a
  `ws://` connection — install `nats-core[websocket]`"
  (`learn/websocket/your-first-websocket-connection.md`).
- **It once refused to send credentials the server did not ask for.** When a server's `INFO` omitted
  `auth_required` — the shape `no_auth_user` produces — the Python client sent no credentials at all,
  so an authenticated user silently landed as the anonymous one; **fixed in `nats-py` v2.4.0**, and
  the Go client never had the bug (source: [[s-gh-4535-unauthenticated-connections]]). Worth knowing
  because the server-side symptom is an account boundary that appears not to hold — see
  [[account]] and [[subject-permissions]].
- **The docs give no Python install line at all.** Five languages get one on
  `learn/getting-started`; Python, C, Zig, Swift, Ruby and Elixir get a repo link instead, which is why
  the `pip` lines above are read from the repo and PyPI rather than quoted from the docs
  (source: [[s-docs-getting-started]]).
- **Treat `nats-core` as early.** Version 0.2.0, no mention in the repo README, one mention in the
  docs. `nats-py` is what the docs' examples and this wiki's other pages assume.

## What the core-NATS chapter says about this client

- **`publish` skips the subject check**, so a subject with a space goes out as written and the server
  misroutes it — `orders.us created` arrives as subject `orders.us` with reply subject `created`
  (`learn/core-nats/subjects-and-wildcards.md:454`; source: [[s-docs-core-nats-subjects-and-mapping]]). The
  server's side of that is reproduced on 2.14.6 with a raw writer (source:
  [[s-nats-server-core-delivery-observed]], run A2); the client's side is the docs' word until step 8 of
  `inbox/plan-the-client-side-2026-09-03.md` reads the client's releases. The rule is on
  [[subjects-and-wildcards]].


## To verify

- Whether `nats-core` is intended to replace `nats-py` or to sit beside it, and on what timeline. No
  public source read states this; the repository layout suggests a modular split like [[nats-js]]'s,
  but that is inference, not a claim **(unverified)**.


## What bites you

Read from the last ten releases (v2.9.0 → v2.15.0, 2026-06-05, plus the `nats-core/v0.1.0` notes) and
the open issues at 2026-09-04 (source: [[s-client-releases-and-issues]]).

- **The maintainers publish a message-loss figure for this client.** The `nats-core/v0.1.0` notes
  (2025-12-19) benchmark the new package against `nats-py` — 1M messages, publisher and subscriber in
  one process on an Apple M3 Max — and footnote the `nats-py` column: "\* nats-py dropped 47-87% of
  messages under load", against "Zero message loss with nats-core across all configurations". The
  subscriber throughput in the same table is **8,769 msg/s** at 8 B for `nats-py` and **553,636** for
  `nats-core`. Read it as the shape rather than as a number for your hardware: the asyncio client's
  subscriber path is where a Python service loses messages, and it does so without the server
  reporting anything ([[slow-consumer-in-the-client]], [[slow-consumer-detected]]).
- **The reconnect buffer is 2 MB, the smallest of any client** (8 MB in Go and Java; documentation's
  word, source: [[s-docs-resilient-clients-reconnection-and-events]]). A publisher that keeps writing
  through a reconnect fills it four times sooner. Open issue **#461** (2023-06-19) reports the
  matching symptom: "OutboundBufferLimitError exception on connection after `drain_timeout` passed".
- **`publish` still does not check the subject.** The docs say so (`orders.us created` goes out as
  subject `orders.us`, reply subject `created`; source: [[s-docs-core-nats-subjects-and-mapping]]) and
  none of the last ten releases adds validation, where Go got it at v1.48.0 and Rust at v0.47.0. The
  server's half is reproduced on 2.14.6 (source: [[s-nats-server-core-delivery-observed]], run A2) —
  [[subjects-and-wildcards]].
- **Lame duck mode was only handled from v2.15.0** (2026-06-05, #869, "Lame duck mode handling for
  graceful reconnection"). A rolling upgrade against an older `nats-py` gets an ordinary disconnect
  where other clients get an orderly move — [[upgrade-a-cluster]].
- **Pull-consumer streams leak their disconnect and reconnect callbacks.** Open issue **#962**
  (2026-05-29): "never deregistered on stop()". A long-running service that creates and stops
  consumers accumulates them.
- **`fetch()` can still stall.** Open issue **#986** (2026-07-06): "fetch() still stalls on an orphan
  lingering request in 2.15.0 (regression / incomplete fix for #933)" — [[consumer]].
- **`nats-core` is a different client, not a version bump**, and it needs Python 3.13+. The loss
  figure above is the reason it exists.

## Related

[[orbit]] · [[nats-js]] · [[nats-go]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-gh-4535-unauthenticated-connections]] · [[s-docs-getting-started]] · [[s-docs-core-nats-subjects-and-mapping]] · [[s-nats-server-core-delivery-observed]] · [[s-client-releases-and-issues]] · [[s-docs-resilient-clients-reconnection-and-events]]
