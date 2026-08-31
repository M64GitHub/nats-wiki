---
title: "gh#7834 — JetStream shared with a leafnode, but streams aren't visible on both ends"
type: summary
area: [topology, jetstream, security]
source-url: https://github.com/nats-io/nats-server/discussions/7834
source-path: raw/gh-discussions/gh-7834.md
author: "@tbalbers (asking; nobody answered)"
article: "JetStream on cluster should be shared with leafnode, all using TLS. But streams aren't visible on both ends"
date: 2026-02-16
version: "not stated by the reporter"
tags: [leafnode, jetstream-domain, system-account, tls, verify_and_map, unanswered]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7834 — The same JetStream domain on both ends, and nothing crosses

The thread behind question-bank **Q42**. **Nobody answered it**; the reporter posted a partial
self-diagnosis, then "na.. I'll start over" and closed it the next day. It is recorded here because
the configuration is complete and quoted in full, and because the server source explains every one of
the reporter's four observations — including the one he called "really weird".

## Key claims

**The setup.** A 3-node cluster plus one leafnode, all mTLS from one CA, `verify_and_map: true`, the
certificate SAN e-mail mapped to a user. `jetstream { domain: nlx000013 }` set to **the same value on
all four servers**. The leafnode remote connects with `account: SENTINEL` — **not** the system
account.

**The four observations, verbatim:**

> "a) If I create a jetstream stream on the cluster, it doesn't show up on the leafnode.
> b) If I create a jetstream stream on the leafnode, it doesn't show up on the cluster.
> c) If I do a 'server report jetstream' on the leafnode, it only lists the leafnode.
> d) If I do a 'server report jetstream' on the cluster, it only lists the cluster nodes."

**And the one that looks backwards:**

> "e) If I change the jetstream domain to be e.g. "nlx000013" on the cluster nodes and
> "notnlx000013" on the leafnode (using `--js-domain`), and I then create a jetstream stream on
> either the cluster or the leafnode, it shows up in both places. That is really weird."

**The reporter's partial answer**, posted the same day and never confirmed:

> "Just leave out the jetstream domain name on the leaf node.
>
> When I do that, and create a stream on the leafnode, it shows up in the cluster. But does it then
> have disk persistency on the leafnode if the connection to the cluster is lost?"

That last question is left hanging, and it is the right question: with the domain removed and the
system account **still not shared**, what he was seeing was the client reaching the *cluster's*
JetStream through the leafnode, not two JetStreams merged.

**He also names the reason he was stuck:**

> "the documentation is unfortunately very limited when it comes to using TLS."

and, on the system account:

> "it seems impossible to be able to specify a password for a user on the system_account when using
> TLS."

— which is a real consequence of `verify_and_map`: the certificate *is* the identity, so a system
account user has no password to give a leafnode remote. His `SYSTEM` account does contain both a
bcrypt-password user and a certificate-mapped user, but the remote is pointed at `SENTINEL`.

## Practical takeaways

The server source settles all of it (see [[s-nats-server-leafnode-js-domains]]):

- Extending JetStream across a leafnode requires **the system account on the connection *and*
  identical domains**. `SENTINEL` is not the system account, so extension was never on the table —
  observations (a)–(d) are the expected result, not a bug.
- With `domain` set and JetStream on, the server installs the `$JS.<domain>.API.>` **mapping** into
  every non-system account. With **different** domains each side can address the other explicitly,
  which is exactly what made (e) work.
- With **identical** domains and no shared system account, the server additionally **denies
  publishing `$JS.<domain>.API.>` outward** over that leafnode, with a source comment naming this
  configuration as a "miss-config".

## Relevance to the wiki

The symptom page is [[streams-not-visible-across-a-leafnode]]; the mechanism is on
[[s-nats-server-leafnode-js-domains]]. The thread is also evidence for a documentation gap: the docs'
leafnode chapter has not yet been ingested, and no page in the tree read so far states the
system-account requirement next to the domain requirement.

## Questions it answers

- **Q42** — why aren't my streams visible on both ends of a leafnode connection.

## Pages touched

[[streams-not-visible-across-a-leafnode]] · [[account]] · [[tls-in-nats]] · [[operator-mode]]
