---
title: "nats-server — repository README (v2.14.6)"
type: summary
area: [core, deploy, security]
source-url: https://raw.githubusercontent.com/nats-io/nats-server/v2.14.6/README.md
source-path: raw/nats-server-src/README-v2.14.6.md
author: nats-io/nats-server maintainers
article: README.md at tag v2.14.6
date: 2026-08-31          # fetch date; the README carries no date
version: "2.14.6"
tags: [cncf, apache-2.0, security-audit, ostif, trail-of-bits, docker, slack]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server — repository README (v2.14.6)

Twenty lines of prose that pin the governance, licence and security facts the docs never state.
Short, but it is the only public source read by this wiki for NATS's foundation membership and for
the third-party security audit.

## Key claims

- **CNCF.** "NATS is part of the Cloud Native Computing Foundation ([CNCF](https://cncf.io))."
- **Licence.** "Unless otherwise noted, the NATS source files are distributed under the Apache
  Version 2.0 license found in the LICENSE file." The GitHub API records the repo licence as
  `Apache-2.0` (see [[s-github-repo-facts]]).
- **Reach.** "NATS has over **40 client language implementations**, and its server can run
  on-premise, in the cloud, at the edge, and even on a Raspberry Pi." The 40 counts community
  clients; [[s-docs-ecosystem]] lists twelve Synadia-maintained ones.
- **Third-party security audit.** "A third party security audit was performed by **Trail of Bits**
  following engagement by the **Open Source Technology Improvement Fund (OSTIF)**", with the "full
  report from April 2025" published in the `trailofbits/publications` repository.
- **Vulnerability reporting** goes to `security@nats.io`, not to public issues.
- **Official Docker image** is the Docker Hub library image `_/nats`; the Helm chart is published to
  **Artifact Hub** under `helm/nats/nats`.
- **CII Best Practices** badge, project 1895.
- Community channels: `slack.nats.io`, the `natsio` Google Group, `@nats_io` on X/Twitter. The
  roadmap lives at `nats.io/about/#roadmap`.

## Practical takeaways

- **The audit is a procurement fact.** Security review of an open-source broker is a question that
  reaches architects from compliance, and the answer is public, dated (April 2025) and attributable
  (Trail of Bits / OSTIF) rather than "trust us".
- **CNCF membership fixes the governance question** — trademark, project neutrality and the
  relationship to [[synadia]] all follow from it.
- **`_/nats` is a Docker Official Image**, which is why `docker run -p 4222:4222 nats:latest` in
  [[s-docs-getting-started]] needs no registry prefix.

## Notable quotes

> "NATS is part of the Cloud Native Computing Foundation (CNCF)."

> "A third party security audit was performed by Trail of Bits following engagement by the Open
> Source Technology Improvement Fund (OSTIF)."

## Relevance to the wiki

Supplies the governance and licence rows of [[nats-server]], and is the only source behind [[cncf]].

## Questions it answers

None of the bank's rows directly — it answers the procurement questions that sit behind them.

## Pages touched

[[nats-server]] · [[cncf]] · [[synadia]] · [[nats-box]]
