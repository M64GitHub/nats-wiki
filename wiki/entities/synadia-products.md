---
title: Synadia commercial products
type: entity
kind: product
area: [deploy, monitoring, security]
verified-against: synadia.com site navigation captured 2026-08-31
verified-on: 2026-08-31
tags: [product, commercial, synadia-cloud, synadia-platform, insights, protect, managed-nats]
aliases: ["Synadia Cloud", "Synadia Platform", "Synadia Deploy", "Synadia Insights", "Synadia Protect", NGS]
sources: [s-github-repo-facts, s-synadia-jetstream-anti-patterns]
created: 2026-08-31
updated: 2026-08-31
---

# Synadia commercial products

A **thin "where they sit" layer**, deliberately. This wiki is about running open-source
`nats-server`; the commercial offerings are here so you can tell which problem each one removes, and
nothing more. One page rather than five, because the public sources this wiki has read give one
sentence per product and no more — five near-empty pages would be worse than one honest table.

## The five, as Synadia names them

| product | what it is, in Synadia's words |
|---|---|
| **Synadia Platform** | "Single-tenant, fully managed NATS in your cloud. Enterprise control without operating it yourself." |
| **Synadia Cloud** | "Multi-tenant, hosted NATS. Build quickly with NATS, don't operate it." |
| **Synadia Deploy for Kubernetes** | "Self-serve NATS & Synadia Platform deployment for Kubernetes environments." |
| **Synadia Insights** | "Granular, NATS-native observability including 100+ audit checks from our experts." |
| **Synadia Protect** | "A security gateway for NATS. Enforce policy on every connection and message." |

## Where they sit against the open-source stack

- **Platform / Cloud / Deploy replace the operating.** The open-source equivalents in this wiki are
  [[nats-helm-charts]] plus the runbooks — you keep the same [[nats-server]], you stop running it
  yourself. Cloud is multi-tenant and hosted; Platform is single-tenant in your own cloud account;
  Deploy is the self-serve Kubernetes path into both.
- **Insights replaces the monitoring assembly.** The open-source path is
  [[prometheus-nats-exporter]] or [[nats-surveyor]] into Prometheus and Grafana, with your own
  thresholds ([[monitoring-endpoints]]). The `nats-surveyor` README names Insights directly as the
  commercial alternative: "If you want a 'batteries-included' approach to high-cardinality NATS
  monitoring and observability, try the standalone Synadia Insights" (source:
  [[s-github-repo-facts]]).
- **Protect sits in front of the connection.** The open-source equivalents are accounts,
  permissions, JWT-based authorization and auth callout — configuration on the server rather than a
  gateway in front of it.

## What an architect needs to know

- **Nothing here is required to run NATS in production.** Every capability this wiki documents is in
  the Apache-2.0 server. The products remove operational work; they do not unlock protocol features.
- **The open-source server is the same server.** Synadia maintains [[nats-server]] as a [[cncf]]
  project; a decision to buy is a decision about who operates it, not about which NATS you get.
- **This page is intentionally shallow.** Comparing tiers, prices or SLAs is out of scope for this
  wiki — go to Synadia. If a *behaviour* difference ever turns out to matter to an operator, that
  belongs on the relevant concept page with a public source, not here.

## Related

[[synadia]] · [[cncf]] · [[nats-server]] · [[nats-surveyor]] · [[prometheus-nats-exporter]] ·
[[nats-helm-charts]] · [[monitoring-endpoints]]

## Sources

[[s-github-repo-facts]] (the `nats-surveyor` README's reference to Insights) ·
[[s-synadia-jetstream-anti-patterns]]. The five product names and their one-line descriptions are
read from the site navigation captured verbatim in
`raw/synadia-blog/nats-jetstream-high-ram-usage.txt`, lines 7–11.
