---
title: Synadia
type: entity
kind: org
area: [core, clients, deploy]
verified-against: synadia.com site chrome captured 2026-08-31
verified-on: 2026-08-31
tags: [org, synadia, maintainer, tier-1, orbit, commercial]
aliases: [synadia, "Synadia Communications, Inc.", synadia-io]
sources: [s-docs-ecosystem, s-github-repo-facts, s-synadia-jetstream-anti-patterns, s-synadia-jetstream-memory-patterns, s-cncf-nats-project, s-nats-server-readme]
created: 2026-08-31
updated: 2026-09-01
---

# Synadia

**The company that maintains NATS.** Synadia Communications, Inc. employs the maintainers, owns the
`synadia-io` GitHub org, publishes the docs, and sells commercial products built on NATS. The code
itself is a [[cncf]] project under Apache-2.0 — those two facts sit side by side and both matter.

## Where it fits

| what | who |
|---|---|
| the project, trademark and neutrality | **[[cncf]]** — Incubating since 2018-03-15 (source: [[s-cncf-nats-project]]) |
| the maintainers, the docs, the release cadence | **Synadia** |
| the licence | Apache-2.0, for [[nats-server]] and effectively all of `nats-io` |
| commercial offerings | [[synadia-products]] |

## Facts

| | |
|---|---|
| legal name | **Synadia Communications, Inc.** (site footer: "© 2026 Synadia Communications, Inc.") |
| self-description | "The creators of NATS" |
| GitHub orgs | **`nats-io`** (the project) and **`synadia-io`** ([[orbit]], the auth-callout SDKs, the Flink connector) |
| docs | `docs.nats.io` is published by Synadia and carries its copyright |
| client tiers | Synadia defines them: tier 1 "track new server features at release", tier 2 "may lag behind" |
| community | the NATS Slack (`slack.nats.io`) and the `natsio` Google Group |

## What this means for an operator

- **"Official" means Synadia-maintained.** Every tier 1 and tier 2 client on [[s-docs-ecosystem]] is
  a Synadia commitment; community clients are not. When a client lags a server release, that is a
  Synadia scheduling question, not a community one. The scale of the gap is in the server's own
  README: "NATS has over **40 client language implementations**" against the **twelve** Synadia
  maintains (source: [[s-nats-server-readme]]) — so most of the ecosystem carries no such commitment.
- **Incubating is a governance status, not a verdict on production-readiness**, and it is the row an
  architect gets asked about. CNCF's own definitions put *Incubating* at "used successfully in
  production by a small number users with a healthy pool of contributors", below *Graduated*. What
  speaks to production-readiness is elsewhere: the release history, and the **Trail of Bits** security
  audit commissioned through **OSTIF**, full report April 2025
  (sources: [[s-cncf-nats-project]], [[s-nats-server-readme]]). CNCF membership is also what fixes the
  trademark and neutrality question that Synadia's ownership would otherwise raise — see [[cncf]] and
  [[nats-server]].
- **The `synadia-io` org is a deliberate boundary.** [[orbit]] lives there rather than in `nats-io`
  precisely so that its API guarantees can be weaker than a core client's. Read the org name in a
  dependency URL as a stability signal.
- **The docs are a Synadia product too.** They are generated in part from [[jsm-go]], which is why
  `inbox/docs-issues.md` finds errors clustered in generated reference pages rather than in
  hand-written prose.
- **The public engineering blog is a first-class source** for behaviour the docs do not carry —
  two of this wiki's sizing and anti-pattern pages rest on it
  ([[s-synadia-jetstream-memory-patterns]], [[s-synadia-jetstream-anti-patterns]]). Paraphrase and
  attribute; the posts are copyrighted.

## Related

[[cncf]] · [[synadia-products]] · [[nats-server]] · [[orbit]] · [[nats-surveyor]] ·
[[s-docs-ecosystem]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-synadia-jetstream-anti-patterns]] ·
[[s-synadia-jetstream-memory-patterns]] · [[s-cncf-nats-project]] · [[s-nats-server-readme]]. Company name, self-description and product names are read
from the site navigation and footer captured verbatim in
`raw/synadia-blog/nats-jetstream-high-ram-usage.txt` (lines 1–12 and 138–145).
