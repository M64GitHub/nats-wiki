---
title: nats.py
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats.py v2.15.0 · PyPI nats-py 2.15.0 / nats-core 0.2.0
verified-on: 2026-08-31
tags: [client, tier-1, python, asyncio, nats-py, nats-core]
aliases: [nats.py, "nats-io/nats.py", python client, nats-py, nats-core]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
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
- **Treat `nats-core` as early.** Version 0.2.0, no mention in the repo README, one mention in the
  docs. `nats-py` is what the docs' examples and this wiki's other pages assume.

## To verify

- Whether `nats-core` is intended to replace `nats-py` or to sit beside it, and on what timeline. No
  public source read states this; the repository layout suggests a modular split like [[nats-js]]'s,
  but that is inference, not a claim **(unverified)**.

## Related

[[orbit]] · [[nats-js]] · [[nats-go]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
