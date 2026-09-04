---
title: nats.rb (legacy)
type: entity
kind: client
area: [clients, core]
verified-against: nats v0.11.0
verified-on: 2026-09-04
tags: [client, tier-2, ruby, legacy, eventmachine]
aliases: [nats.rb, "nats-io/nats.rb", legacy ruby client]
sources: [s-docs-ecosystem, s-github-repo-facts, s-client-releases-and-issues, s-nats-pure-rb-client-source]
created: 2026-08-31
updated: 2026-09-04
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
  block form). Its defaults — a reconnect budget of 10, a publisher that blocks rather than fails, a
  four-minute keepalive — are read from that client's source and stated there and on
  [[client-defaults]] (source: [[s-nats-pure-rb-client-source]]); none of them is documented for
  either Ruby client anywhere on docs.nats.io.


## What bites you

Read from its nine release bodies (v0.5.0.beta.12, 2013 → v0.11.0, 2019-06-11) and its three open
issues at 2026-09-04 (source: [[s-client-releases-and-issues]]).

- **Everything the server has gained since 2019-06-11 is absent**, which for an operator means
  JetStream in every form, headers, per-message TTL and priority groups. The gem still connects and
  still publishes: core NATS has not changed under it, which is exactly why an old Gemfile keeps
  working and nobody notices.
- **It does have a drain**, from v0.10.0 (2018-08-31, "Support for `drain mode`"), taken as a block
  that runs when the connection has closed — so a migration to [[nats-pure-rb]] is not a step down
  here, and the drain rules on that page apply the same way.
- **`no_echo` is also v0.10.0** — the option that stops a connection receiving its own publishes.
  Useful to know when an old service appears to consume its own messages.
- **The reactor is the migration cost.** EventMachine dictates the shape of the host process; the
  replacement is thread-based, so the change is structural rather than a `require` swap.
- **Its three open issues are not about the connection** — none concerns drain, reconnect, slow
  consumers or no-responders. For a client with no releases in seven years, the absence is a
  statement about usage, not about quality.

## Related

[[nats-pure-rb]] · [[nats-streaming]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-client-releases-and-issues]] · [[s-nats-pure-rb-client-source]]
