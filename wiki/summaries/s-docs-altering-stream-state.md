---
title: "docs — JetStream: Altering stream state"
type: summary
area: [jetstream]
source-url: https://docs.nats.io/learn/jetstream/altering-stream-state.md
source-path: raw/nats-docs/learn/jetstream/altering-stream-state.md
author: nats-io docs
article: "learn/jetstream/altering-stream-state.md"
date: 2026-08-31
version: ""
tags: [rmm, purge, no_erase, SecureDeleteMsg, deny_purge, sequence, gaps]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs — JetStream: Altering stream state

Manual removal: one message, or the whole stream. Short, and it carries one fact about the CLI that
nothing else the wiki has read states.

## Key claims

**`nats stream rmm` securely erases by default.** "The server overwrites the stored bytes so the old
contents can't be read back… That's the right default for a message that held data it shouldn't
have." It prompts (`Really remove message 2 from Stream ORDERS`); `--force` skips it.

**The client libraries default the other way.** "`DeleteMsg(seq)` marks the message erased but leaves
its bytes in place until they're later overwritten, which is cheap. `SecureDeleteMsg(seq)` overwrites
them right away the way the CLI does, and is slower for it. **The only difference the server sees is
a single `no_erase` flag on the delete request.**"

**Purge keeps the stream and the counter.** `nats stream purge ORDERS` "removes every message… The
stream itself stays: same config, same consumers, same name". "Purge sets the stream's first sequence
to one past its last", so the next publish continues from there, never from `1`. Contrast
`nats stream rm ORDERS`, which "deletes the whole stream, config and consumers included".

**The three narrowing flags, and the one combination that is refused:** `--subject` (one subject),
`--seq` (drop everything below a sequence), `--keep` (retain the newest N). "You can't use `--seq`
and `--keep` together, since one works from each end, but either one can pair with `--subject`."

**Sequence numbers never backfill.** "The server does not renumber `3` down to close the gap, and it
never hands `2` out again to a future message." Two consequences the page draws:

- "Consumers handle the gaps without trouble. A consumer… never blocks waiting for a deleted
  message, and a missing `2` is not redelivered."
- "**A stored sequence is a stable address.** If you saved 'order `ord_8w2k` is at sequence 2'
  alongside your business record, that pointer either still points at the same message or points at
  nothing. It never points at a different message."

**`DenyPurge` is permanent.** "The server refuses any later update that turns it off, so the only way
to purge that stream again is to delete and recreate it."

**Don't derive one number from another.** "Don't work out 'the next message' as `count + 1`, and
don't read a message count as the highest sequence."

## Practical takeaways

- The CLI's `rmm` is the *expensive* delete; a program calling `DeleteMsg` gets the cheap one. If you
  are removing a message because its contents were sensitive, make sure you used the erasing form.
- A sequence is a safe external reference. A count is not.
- `--seq` and `--keep` are mutually exclusive; the server answers `10003 bad request` for the pair
  (source: [[s-adr-10-extended-purge]]).

## Relevance to the wiki

Adds the delete/erase distinction and the "sequences are stable addresses" rule, neither of which any
page carried. [[retention-policies]] already has the purge flags.

## Questions it answers

Contributes to **Q24** — the ordering and numbering guarantee a stream gives, including what a
deletion does to it.

## Pages touched

[[stream]] · [[retention-policies]] · [[nats-cli]]

## Sources

The doc page. The `--seq`+`--keep` exclusion and its error code are from
[[s-adr-10-extended-purge]].
