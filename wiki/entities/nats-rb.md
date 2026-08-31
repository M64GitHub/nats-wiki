---
title: nats.rb (legacy)
type: entity
kind: client
area: [clients, core]
verified-against: nats v0.11.0
verified-on: 2026-08-31
tags: [client, tier-2, ruby, legacy, eventmachine]
aliases: [nats.rb, "nats-io/nats.rb", legacy ruby client]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nats.rb (legacy)

The **original EventMachine-based Ruby client**. The docs' guidance is unambiguous:
"EventMachine-based; **use `nats-pure.rb` for new code**" (source: [[s-docs-ecosystem]]).

## Where it fits

Tier 2, legacy. Kept here because it is still installable and still appears in old Gemfiles, not
because it is a choice anyone should be making now.

## Facts

| | |
|---|---|
| repo | `nats-io/nats.rb` |
| tier | **2 (legacy)** |
| latest release | **v0.11.0**, **2019-06-11** |
| licence | Apache-2.0 |
| gem | **`nats`** (ships `nats-sub` / `nats-pub` binaries) |
| requires | EventMachine |
| nkey support | via the separate `nkeys` gem, added at v0.11.0 |

## What an operator needs to know

- **No release since 2019-06-11.** Anything the server has gained since — JetStream in every form,
  per-message TTL, priority groups — is not here.
- **Its own README redirects you**: "If you're looking for a non-EventMachine alternative, check out
  the `nats-pure` gem."
- **The migration target is [[nats-pure-rb]]**, which uses the same `require 'nats/client'` path but
  a different connection API (`NATS.connect(...)` returning an object, rather than the `NATS.start`
  block form).

## Related

[[nats-pure-rb]] · [[nats-streaming]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
