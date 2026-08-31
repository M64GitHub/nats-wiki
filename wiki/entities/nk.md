---
title: nk (nkeys)
type: entity
kind: tool
area: [security]
verified-against: nats-io/nkeys v0.4.16
verified-on: 2026-08-31
tags: [tool, nk, nkeys, ed25519, seeds, prefixes, libsodium]
aliases: [nk, nkeys, "nats-io/nkeys"]
sources: [s-docs-ecosystem, s-github-repo-facts]
created: 2026-08-31
updated: 2026-08-31
---

# nk (nkeys)

**The key tool, and the library under every NATS identity.** NKeys are Ed25519 keypairs in a
base32 encoding whose first letter tells you what kind of entity the key belongs to. The `nk`
command-line utility lives in `nats-io/nkeys`, "Located under the nk directory" (source:
[[s-github-repo-facts]]).

## Where it fits

Below [[nsc]] and `nats auth`: those tools mint and sign JWTs, and the signing is nkeys. `nk` is
what you reach for when you need a raw key without a store around it.

## Facts

| | |
|---|---|
| repo | `nats-io/nkeys` (the `nk/` directory holds the CLI) |
| latest release | **v0.4.16**, 2026-06-02 |
| licence | Apache-2.0 |
| algorithm | **Ed25519** — "fast and resistant to side channel attacks" |
| encoding | base32 with a CRC16 and a prefix byte, in the style of Stellar |
| library | `go get github.com/nats-io/nkeys`; per-language ports exist for JS, Java, .NET, Python, Ruby, Swift and Elixir |
| bundled in | [[nats-box]] |

**The prefix letters** — the fastest way to read a key at a glance:

| prefix | entity |
|---|---|
| `N` | server |
| `C` | cluster |
| `O` | operator |
| `A` | account |
| `U` | user |
| `P` | private key |
| `S…` | **seed** — the second letter is the type, so `SU` is a user seed, `SA` an account seed |

## What an operator needs to know

- **The seed is the only thing that must be stored.** "Generation of a seed key is all that is needed
  to be stored and kept safe, as the seed can generate both the public and private keys." Everything
  else is derivable; the seed is the secret.
- **The server never holds a private key.** "The NATS system will utilize Ed25519 keys, meaning that
  NATS systems will never store or even have access to any private keys. Authentication will utilize
  a random challenge response mechanism." This is the property that makes nkey auth safe to expose —
  a compromised server leaks no client identity.
- **Read the first letter before you debug.** A configuration that rejects a key is very often an
  `A` where a `U` belongs, or a public key pasted where a seed was wanted (`SU…`).
- **`nats auth nkey gen`** covers the same ground from [[nats-cli]] —
  `nats auth nkey gen user --output user.nk`, `nats auth nkey show user.nk`.

## Cheat sheet

```
nats auth nkey gen user  --output user.nk     # generate a user seed
nats auth nkey gen curve --output backup.nk   # a curve key, used to encrypt operator backups
nats auth nkey show user.nk                   # show the public key for a seed
```

```
go get github.com/nats-io/nkeys                # the library the CLI wraps
```

## Related

[[nsc]] · [[nats-cli]] · [[nats-box]] · [[account]] · [[nats-c]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]]
