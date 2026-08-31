---
title: "ADR-54 — KV codecs (Proposed, client-side)"
type: summary
area: [kv, clients]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-54.md
source-path: raw/adr/ADR-54.md
author: "@piotrpio"
article: ADR-54 KV Codecs
date: 2025-08-06
version: ""
tags: [kv, codecs, key-encoding, base64, path, encryption, orbit, proposed]
aliases: [ADR-54]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-54 — KV codecs, and the server-side constraint that makes them necessary

Status **Proposed**, tagged `orbit` — a **client** design, and by this wiki's scope mostly out of
it. Read for one thing an operator and an architect do need: the constraint it exists to work
around.

## Key claims

### The constraint: a KV key is a NATS subject

"The JetStream Key-Value store uses NATS subjects as keys and message payloads as values", so keys
containing "special characters (spaces, dots, etc.) that are invalid in NATS subjects" cannot be
stored as-is. A dot in a key is not an escape problem — it is a **token separator**, and changes
what a watcher matches. There is no server-side escaping and none is proposed; the ADR's answer is
entirely in the client.

### What it proposes, in one paragraph

Two interfaces, `KeyCodec` (string→string) and `ValueCodec` (bytes→bytes), wrapped around a normal
KV handle so every operation works unchanged; codecs may be chained ("decoded in reverse order");
and three built-ins — `NoOpCodec`, `Base64Codec` (URL-encoded base64: `"Acme Inc.contact"` becomes
`"QWNtZSBJbmMuY29udGFjdA=="`) and `PathCodec` (`user/profile/settings` → `user.profile.settings`,
with a leading slash encoded as `_root_` and trailing slashes trimmed).

### The one that bites: watching encoded keys

A codec that encodes a key also encodes the wildcards in a filter, so watching stops working unless
the codec handles it — hence the optional `FilterableKeyCodec` with `EncodeFilter`. Wildcard
handling is explicitly "optional when implementing custom codecs".

### Encryption is a value codec, not a server feature

The worked example is an AES `ValueCodec`. Values are encrypted before they reach the server, which
is a different thing from JetStream encryption at rest — the server sees ciphertext and can neither
index nor compact it meaningfully.

## Practical takeaways

- **Key characters are a design decision made before the first `Put`.** Spaces and dots in natural
  keys mean either a client-side codec or a different key scheme; there is no server switch.
- **If a codec is in play, keys in `nats kv ls` will not look like the application's keys**, and a
  watcher written against the raw key will match nothing.
- **A value codec makes server-side features blind**: compression, and any tooling that reads values.

## Relevance to the wiki

Gives [[key-value]] the reason keys are constrained and what clients may do about it, and closes the
ADR-54 item on its `## To verify`. Client APIs themselves stay out of scope (`CLAUDE.md`).

## Questions it answers

None in `inbox/question-bank.md`.

## Pages touched

[[key-value]]
