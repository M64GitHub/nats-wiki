---
title: "natscli v0.4.0 — the cross-domain and cross-account prompts in `nats stream add`"
type: summary
area: [jetstream, topology, security]
source-url: https://github.com/nats-io/natscli/blob/v0.4.0/cli/stream_command.go
source-path: raw/github-repos/nats-io__natscli.stream-external-v0.4.0.md
author: nats-io/natscli contributors
article: "cli/stream_command.go — askMirror and askSource at v0.4.0"
date: 2026-08-31
version: "natscli 0.4.0"
tags: [external, api-prefix, deliver-prefix, jetstream-domain, cross-account, stream-add, mirror, source]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# natscli v0.4.0 — the tool already knows how to do cross-domain sourcing

`external`, `api` and `deliver` appear nowhere in the 861-page docs tree (`inbox/docs-issues.md`
#21), and gh#7881 asks how to configure cross-domain sourcing with no maintainer reply. Meanwhile the
`nats` CLI's **interactive** `nats stream add` has walked users through it for years. Reading the
prompts is the closest thing to a specification.

## Key claims

### Two different questions, in this order

`askMirror` (`stream_command.go:3013–3052`) and `askSource` (`:3141–3181`) ask the same pair:

1. **"Import mirror from a different JetStream domain"** → then *"Foreign JetStream domain name"*,
   help text "The domain name from where to import the JetStream API". The CLI builds the prefix
   itself:

   ```go
   3023:		mirror.External.ApiPrefix = fmt.Sprintf("$JS.%s.API", domainName)
   ```

   The delivery prefix is asked next and is **optional** (no `survey.Required`), help text "Optional
   prefix of the delivery subject".

2. Otherwise, **"Import mirror from a different account"** → *"Foreign account API prefix"*, help
   "**The prefix where the foreign account JetStream API has been imported**" — **required** — and
   *"Foreign account delivery prefix"*, help "The prefix where the foreign account JetStream delivery
   subjects has been imported" — also **required**.

The two branches are mutually exclusive in the flow: domain first, account only if you decline.

### What that tells you that no prose source does

- **Cross-domain needs one value, cross-account needs two.** For a domain, the API prefix is
  mechanical (`$JS.<domain>.API`) and the delivery prefix is optional. For an account, both are
  required and both are **your local import subjects**, not the remote's.
- The account-branch help text names the precondition explicitly: the foreign JetStream API must
  already **have been imported** into your account. The `external` block does not create the import;
  it tells the stream which local prefix the import lives under.
- The server agrees on the domain form: `ExternalStream.Domain()` returns `tokenAt(ext.ApiPrefix, 2)`
  (`stream.go:432–437` at v2.14.6) — the second token of `$JS.<domain>.API`.

### The durable-consumer branch replaces the delivery prefix

Both functions gate the delivery-prefix question on `!askDurable` (`:3025`, `:3044`, `:3153`,
`:3174`). If you answer yes to "Configure a custom durable consumer" — filling
`StreamConsumerSource{Name, DeliverSubject}` (`:2934–2948`) — the delivery prefix is not asked at
all, because the deliver subject is given directly.

### It is displayed back

`nats stream info` prints `Ext. API Prefix` and `Ext. Delivery Prefix` (`:2426–2436`),
`nats stream report` has an API-prefix column for mirrors and sources (`:1656–1700`), and the
long-form source description prints `API Prefix: …` / `Delivery Prefix: …` (`:2298–2310`). So the
values are auditable after creation without reading JSON.

## Practical takeaways

- **The fastest correct way to build a cross-domain mirror or source is `nats stream add` with no
  flags** and answering the prompts — the CLI composes `$JS.<domain>.API` for you and cannot typo it.
- To automate it, capture the result: `nats stream add … --output stream.json`, then
  `nats stream add --config stream.json` elsewhere. `--validate` checks a config without creating
  anything.
- `Ext. API Prefix` in `nats stream info` is the one-line audit that a cross-domain source is
  configured the way you think it is.
- The CLI is not documentation, and the account branch in particular assumes you already built the
  export/import pair. It tells you *what* the stream needs, not *how* to authorise it.

## Relevance to the wiki

The operator-facing half of [[cross-domain-sourcing]], and the reason that page can give a real
procedure instead of a JSON field list. Extends [[mirrors-and-sources]] and [[nats-cli]].

## Questions it answers

- **Q43 / Q89** — how to set up cross-domain JetStream sourcing, on the client side.

## Pages touched

[[cross-domain-sourcing]] · [[mirrors-and-sources]] · [[jetstream-domain]] · [[nats-cli]] ·
[[cross-account-sharing]]
