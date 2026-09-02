---
title: nats-server 2.10
type: entity
kind: release
area: [deploy, jetstream, kv, objectstore]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.10, compression, kv-sources, kv-mirrors]
aliases: ["2.10", v2.10, v2.10.0, v2.10.29]
sources: [s-adr-8-key-value-store, s-adr-20-object-store, s-gh-4535-unauthenticated-connections, s-gh-5202-max-unique-subjects, s-relnotes-2.11.2]
created: 2026-08-31
updated: 2026-09-03
---

# nats-server 2.10

The oldest minor this wiki's facets know. Present here mainly as the version boundary for KV and
Object Store capabilities that later pages reference.

## Facts

| | |
|---|---|
| first release | **v2.10.0**, 2023-09-19 |
| latest release seen | **v2.10.29**, 2025-05-01 |
| releases in this line | 82 tags |
| license | Apache-2.0 |

Dates and tags from `raw/release-notes/_tags-and-dates.md` (GitHub releases API, fetched
2026-08-31).

> **No 2.10 upgrade guide or release body has been ingested.** The docs mirror carries only the
> 2.12 and 2.14 guides. This page lists only what other ingested sources attribute to 2.10 by name;
> it is **not a changelog**.

## What other sources attribute to 2.10

- **KV sourced buckets** and **read-replica mirror buckets** — ADR-8 revision 2 (2023-10-16), server
  requirement `2.10.0` (source: [[s-adr-8-key-value-store]]). See [[key-value]].
- **KV bucket compression** — ADR-8 revision 4 (2023-10-25), server requirement `2.10.0`.
- **KV bucket metadata** — ADR-8 revision 8 (2025-02-17), server requirement `2.10.0`.
- **Object Store compression** — ADR-20 revision 3 (2024-02-05), "Data Compression of Object Stores
  for NATS Server 2.10" (source: [[s-adr-20-object-store]]). See [[object-store]].
- **A security fix in v2.10.2**, and the only dated point release this page can name. Before it,
  declaring an `accounts` block "appears to outright ignore any users/creds defined in
  `authorization`" — so a config with a `$SYS` account and top-level `authorization` users accepted
  connections **with no credentials at all**, landing them in the still-active default `$G`. A
  maintainer confirmed it as a bug, filed
  [PR #4605](https://github.com/nats-io/nats-server/pull/4605), and stated the release: "Merged, will
  be in **2.10.2** release" (source: [[s-gh-4535-unauthenticated-connections]]). **Anything below
  v2.10.2 has this hole**; the narrower trap that survives it — `no_auth_user`, and `$G` staying alive
  when you name only the system account — is on [[account]].

## Redelivery of acked messages, fixed in 2.10.16 and 2.10.17

Two consecutive releases fixed the same complaint from the restart side: "Fix potential redelivery of
acked messages during server restarts (#5419)" in **2.10.16** (2024-05-21), then "Fix possible
redelivery after successful ack during rollout restarts (#5482)", "Follower stores no longer inherit
the redelivered consumer delivered sequence which could break ack gap fill (#5533)" and "Ensure ack
processing is consistent and correct between leader and followers for replicated consumers (#5524)"
in **2.10.17** (2024-06-27). 2.10.16 also carries a warning of its own — a possible startup panic on
zero-byte `tav.idx` files, with the work-around of deleting them (source: [[s-relnotes-2.11.2]]). A
2.10 cluster that redelivers acked messages around rolling restarts wants 2.10.17 or later; the
symptom page is [[consumer-keeps-redelivering]].


## Why the version still matters

It is the floor for **`compression: "s2"`** on KV and Object Store buckets, and for KV sources and
mirrors. A deployment still on 2.10 has those; anything the wiki tags `since: 2.11` or later it does
not.

## To verify

- The last 2.10 tag seen is **v2.10.29, 2025-05-01** — over a year before this page was written and
  before 2.12 shipped. Whether the line is still supported is **not stated by any source read**; no
  support-lifecycle document has been ingested.
- Everything on this page is second-hand attribution from ADRs. The 2.10 release notes themselves
  are a gap.

## The per-subject index, since 2.10.9

From **2.10.9** a file store's per-subject index is an in-memory adaptive radix tree ("stree"):
per subject, the message count and the first and last block, with path compression so only the
suffix is stored at the leaf. A maintainer stated it in answer to "how many unique subjects can one
stream hold" — no configured maximum; RAM for the tree is the bound (source:
[[s-gh-5202-max-unique-subjects]]; the cost per subject is on [[jetstream-sizing]]).


## Related

[[nats-server-2.11]] · [[key-value]] · [[object-store]] · [[stream]] · [[nats-server]]

## Sources

[[s-adr-8-key-value-store]] · [[s-adr-20-object-store]] · [[s-gh-4535-unauthenticated-connections]] · [[s-gh-5202-max-unique-subjects]] · [[s-relnotes-2.11.2]]
