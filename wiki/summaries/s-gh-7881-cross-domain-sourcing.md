---
title: "gh#7881 — Cross-domain JetStream sourcing, how do I set that up?"
type: summary
area: [topology, jetstream, security]
source-url: https://github.com/nats-io/nats-server/discussions/7881
source-path: raw/gh-discussions/gh-7881.md
author: "@tbalbers (asker), @mg1986jp (community comment)"
article: "GitHub Discussion 7881, nats-io/nats-server, Q&A"
date: 2026-02-26
version: ""
tags: [jetstream-domain, sourcing, external, api-prefix, service-import, unanswered, tls]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7881 — the exact question the docs cannot answer

Opened 2026-02-26. **No maintainer has replied.** One community comment arrived three months later
and is not marked as the answer. The thread is the clearest public evidence for
`inbox/docs-issues.md` #21 — that `external`, `api` and `deliver` appear nowhere in the 861-page docs
tree — and it names the error you get without them.

## Key claims

### The setup

- "2x3 NATS nodes set up in a supercluster (cluster01) with JetStream enabled"
- "2 leafnodes (leaf01a and leaf01b) who are standalone, also running JetStream"
- "Everything is set up to use TLS … certificate-based authentication"
- **"The system account is not shared between the supercluster and the leafnodes."** — which, per
  [[s-nats-server-leafnode-js-domains]], is what makes these separate JetStream systems rather than
  one extended one.

The goal is bidirectional replication between per-tenant accounts on the hub and on each leaf.

### The error

> ```
> Error adding service import "$JS.leaf01a.API.CONSUMER.CREATE.tank": service import not authorized
> ```

That subject is the domain-mapped JetStream API from `generateJSMappingTable`
(source: [[s-nats-server-leafnode-js-domains]]) — so the asker has the shape right and is missing the
**export** on the other side. `CONSUMER.CREATE` is a request/reply subject, so it must be a
**service** export, not a stream export.

### What the asker could not find

> "A) Can anyone point me to where I can find some documentation for setting this up? I've been
> through NATS by example, 'jetstream-leaf-nodes-demo' and a bunch of other places without any luck
> at all.
>
> B) I also find it close to impossible to figure out what all the different messages in the log about
> adding JetStream domain mapping etc. means.
>
> C) Furthermore it's unclear to me if all 3 accounts should exist in the config files on all hosts."

He also rules out the one path most examples take: "in the documentation and examples I've found
either this is not done using TLS, or it's done using `nsc` which I haven't been able to get to work
… (and we also have a requirement to use plaintext (readable) config files for automation, so JWT is
probably not going to be acceptable)."

### The one reply, unaccepted

@mg1986jp, 2026-05-28, three months later and **not marked as the answer**:

> "In your supercluster account config, you need to export the `$JS.API.>` subjects so the leafnodes
> can access them. On the leafnode side, import those subjects into the same account… If the accounts
> are different, you'll also need to set the `external` field in the source config with the `api`
> prefix pointing to the imported JetStream API subject."

The `external` / `api` half matches the server (`ExternalStream` at `stream.go:425–429`, source:
`inbox/docs-issues.md` #21). The rest is unverified and comes from a non-maintainer; this wiki treats
it as a hypothesis that agrees with the source, not as an answer.

## Practical takeaways

- The failure mode is a **service import that has no matching export**, and the error names the exact
  subject — read the subject to learn which of the three prefixes is missing.
- `$JS.<domain>.API.CONSUMER.CREATE.*` is request/reply, so the export type is `service`. Getting
  this wrong is one of the two silent failures on [[mirrors-and-sources]].
- Config-file (non-JWT) cross-domain sourcing with TLS has **no public worked example**. This wiki
  writes [[cross-domain-sourcing]] from the server source and the field definitions, and says on the
  page which steps are unverified rather than inventing them.

## Relevance to the wiki

The demand behind [[cross-domain-sourcing]], and the second public thread (with
[[s-gh-7017-kv-across-accounts]]) sitting unanswered on the same documentation gap.

## Questions it answers

- **Q43 / Q89** — it *asks* them. It answers neither; the wiki page does, from the source, with the
  unverified parts marked.

## Pages touched

[[cross-domain-sourcing]] · [[jetstream-domain]] · [[mirrors-and-sources]] ·
[[cross-account-sharing]] · [[js-api-subjects]] · [[leafnode]]
