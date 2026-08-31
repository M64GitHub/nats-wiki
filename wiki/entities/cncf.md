---
title: CNCF
type: entity
kind: org
area: [core]
verified-against: cncf.io/projects/nats, fetched 2026-08-31
verified-on: 2026-08-31
tags: [org, cncf, governance, incubating, foundation, linux-foundation]
aliases: [cncf, "Cloud Native Computing Foundation"]
sources: [s-cncf-nats-project, s-nats-server-readme]
created: 2026-08-31
updated: 2026-08-31
---

# CNCF

The **Cloud Native Computing Foundation**, the neutral foundation that hosts NATS. Relevant to this
wiki for exactly one reason: it is the answer to "who owns this, and what happens if the company
behind it changes direction".

## Where it fits

NATS is a CNCF project; [[synadia]] is the company that maintains it. Those are two different
statements and both are true.

## Facts

| | |
|---|---|
| NATS accepted | **2018-03-15** |
| maturity level | **Incubating** |
| what the server README says | "NATS is part of the Cloud Native Computing Foundation ([CNCF](https://cncf.io))" |
| licence this implies | Apache-2.0 for [[nats-server]] and almost every repo around it |
| project page | `https://www.cncf.io/projects/nats/` |

CNCF's own definitions of the three levels, from the same page:

| level | definition |
|---|---|
| Graduated | "stable, widely adopted, and production ready, attracting thousands of contributors" |
| **Incubating** | "used successfully in production by a small number users with a healthy pool of contributors" |
| Sandbox | "Experimental projects not yet widely tested in production on the bleeding edge of technology" |

## What an architect needs to know

- **Incubating is a governance status, not a maturity verdict on the software.** It says the project
  cleared CNCF's incubation bar in 2018 and has not gone through graduation. Whether NATS is fit for
  your production is answered by the release history, the [[nats-server]] third-party security audit
  (Trail of Bits / OSTIF, April 2025) and your own testing — not by this row.
- **It is what makes the trademark and the code neutral.** The project cannot be relicensed or
  withdrawn by a single vendor, which is usually the real question behind "is this a Synadia
  product?".
- **CNCF publishes live project metrics** (health score, contributors) via LFX Insights. They move;
  quote them with a date or not at all. As of 2026-08-31: health score "Fair (67)", 6,482
  contributors.

## Related

[[nats-server]] · [[synadia]] · [[synadia-products]]

## Sources

[[s-cncf-nats-project]] · [[s-nats-server-readme]]
