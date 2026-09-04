---
title: "gh#2961 — JS and Core can use a cluster together"
type: summary
area: [jetstream, core, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/2961
source-path: raw/gh-discussions/gh-2961.md
author: "@ltDamon (asker); @wallyqs and @ripienaar (maintainers)"
date: 2022-03-25
version: ""
article: "GitHub discussion 2961, General, 3 comments, no chosen answer, 1 upvote"
tags: [mixed-deployment, one-cluster, memory, core-performance, jetstream-enabled]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# gh#2961 — JS and Core Can Use a cluster together

Three comments, two of them from maintainers, and **the only public statement found on running core
NATS and JetStream in the same cluster**. Scouted for step 7 of
`inbox/plan-the-client-side-2026-09-03.md` (`inbox/scout-core-or-jetstream-2026-09-04.md`, candidate 4)
after a sweep of all 484 threads with their comments found nothing that asks the choice itself.

## The question

@ltDamon, 2022-03-25: "If I want to use these two features at the same time，JetStream and Core. I must
to deploy two cluster?" — asked while reading a docs sentence about a cluster "where none of the
nats-server instances are configured to enable JetStream", and concluding from it that the two need
separate clusters.

## Key claims

- **@wallyqs**: "You can use both at the same time with the same cluster." No qualification, no
  configuration named.
- **The follow-up is the useful one.** @ltDamon: "Just wanna check if i enable the JetStream. it
  affect the affect efficiency of 'core nats'."
- **@ripienaar**: "Enabling jetstream will increase memory use on the server - and using it again also
  will increase memory use. **But core nats performance will remain the same essentially**."

That is the whole thread. Nobody names a figure, a version, or a config key.

## Practical takeaways

- The mixed deployment is not a pattern to build — it is the default. One cluster carries both, and
  the core NATS path is unchanged by `jetstream { }` being present.
- The cost @ripienaar names is **memory, twice**: once for enabling JetStream at all, and again per
  use. Neither is quantified here; the wiki's figures come from [[jetstream-sizing]].
- The confusion is worth designing against: a docs sentence that describes a *core-only* cluster reads
  to a newcomer as a *requirement* that the two be separate. An architecture page should say "one
  cluster" out loud.

## Notable quotes

> "You can use both at the same time with the same cluster." — @wallyqs, 2022-03-25

> "Enabling jetstream will increase memory use on the server… But core nats performance will remain
> the same essentially." — @ripienaar, 2022-03-26

## Relevance to the wiki

The *One cluster, not two* section of [[core-or-jetstream]], and the public evidence that the mixed
design of that page is what the maintainers expect rather than an invention of this wiki.

## Questions it answers

Row 194 (added with this ingest); row 133 in part.

## Pages touched

[[core-or-jetstream]] · [[jetstream-sizing]] · [[core-nats-delivery]]
