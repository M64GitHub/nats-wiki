---
title: "GHSA-55h8-8g96-x4hj / CVE-2026-33246 — leafnode spoofing of Nats-Request-Info"
type: summary
area: [security, topology]
source-url: https://github.com/advisories/GHSA-55h8-8g96-x4hj
source-path: raw/gh-advisories/GHSA-55h8-8g96-x4hj.md
author: NATS maintainers (advisory 2026-08; the canonical note is raw/gh-advisories/secnote-2026-08.txt)
article: "NATS: Leafnode connections allow spoofing of Nats-Request-Info identity headers"
date: 2026-03-24
version: "affects every nats-server before 2.11.15 and 2.12.0-RC.1 to 2.12.5; fixed in 2.11.15 and 2.12.6"
tags: [cve, CVE-2026-33246, Nats-Request-Info, leafnode, spoofing, advisory]
aliases: [CVE-2026-33246, GHSA-55h8-8g96-x4hj]
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# CVE-2026-33246 — a leafnode could forward a spoofed `Nats-Request-Info`

Medium, CVSS 6.4 (`AV:N/AC:L/PR:L/UI:N/S:C/C:L/I:L/A:N`), published 2026-03-24, NATS advisory ID
2026-08. Fixed in **2.11.15** and **2.12.6**; "Workarounds: None."

## Key claims

- The header's purpose, in the maintainers' words: it "is supposed to provide enough information to
  allow for account/user identification, such that NATS clients could make their own decisions on
  how to trust a message, provided that they trust the nats-server as a broker."
- The flaw: "A leafnode connecting to a nats-server is not fully trusted unless the system account is
  bridged too. Thus identity claims should not have propagated unchecked." Clients relying on the
  header "could be spoofed".
- Scope: "Does not directly affect the nats-server itself, but the CVSS Confidentiality and Integrity
  scores are based upon what a hypothetical client might choose to do with this NATS header."
- The fix is the leaf branch of the stamping code at 2.14.6: a header arriving over a leafnode is
  replaced with the leaf connection's identity ([[s-nats-server-service-imports]],
  `client.go:4950–4954`); the 2.11.15 body lists it as "Messages from leafnodes to non-shared
  service imports now correctly rebuild the request info header" ([[s-relnotes-2.11]]).

## Practical takeaways

- Any server that authorises on this header must be **2.11.15 / 2.12.6 or later** on every node a
  leafnode can reach; there is no configuration workaround.
- After the fix, a request through a leafnode identifies the *leaf connection*, not the end client
  behind the leaf — a design fact, not a bug.
- The advisory is the only public statement that trusting the header for identity is intended.

## Notable quotes

- "provided that they trust the nats-server as a broker"

## Relevance to the wiki

The authority for [[service-import-request-info]]'s "is this meant to be trusted" question, and a
version floor for [[leafnode]] deployments.

## Questions it answers

166.

## Pages touched

[[service-import-request-info]] · [[leafnode]]
