---
title: nats-pure.rb
type: entity
kind: client
area: [clients, jetstream]
verified-against: nats-pure v2.5.0
verified-on: 2026-08-31
tags: [client, tier-2, ruby, pure-ruby, thread-safe]
aliases: [nats-pure.rb, "nats-io/nats-pure.rb", nats-pure, ruby client]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nats-pure.rb

The **preferred Ruby client** — "Pure Ruby — preferred Ruby client" (source: [[s-docs-ecosystem]]),
thread-safe and with no EventMachine dependency, unlike the legacy [[nats-rb]].

## Where it fits

Tier 2. It is the Ruby client both the docs and the legacy client's own README point new work at.

## Facts

| | |
|---|---|
| repo | `nats-io/nats-pure.rb` |
| tier | **2** |
| latest release | **v2.5.0**, 2025-02-21 |
| licence | Apache-2.0 |
| gem | **`nats-pure`** |
| implementation | "A thread safe Ruby client … written in pure Ruby" |

```
gem install nats-pure
```

```ruby
require 'nats/client'
nats = NATS.connect("demo.nats.io")
```

## What an operator needs to know

- **`require 'nats/client'` is the same require path as the legacy gem.** Both gems answer to it, so
  a Gemfile that still lists `nats` alongside `nats-pure` is ambiguous — pick one.
- **Thread-safe, no reactor.** The legacy client's EventMachine reactor dictated the shape of the
  host application; this one does not.
- **Tier 2 means check before assuming a new server feature is exposed** — the docs say so directly,
  and the release cadence here is slower than tier 1.

## Related

[[nats-rb]] · [[nats-server]] · [[nats-ex]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
