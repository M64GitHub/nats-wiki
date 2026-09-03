---
title: "nats-server v2.14.6 — Nats-Request-Info across a service import, observed"
type: summary
area: [security, core]
source-url: https://github.com/nats-io/nats-server/releases/tag/v2.14.6
source-path: raw/nats-server-src/share-import-observed-v2.14.6.md
author: this wiki (runs on the v2.14.6 binary with nats CLI 0.4.0, 2026-09-03; script share-import-run.sh and the raw subscriber share-import-rawsub.py beside the file)
article: "four scenes: without and with share, a two-hop chain, max_payload: 256, and share on a stream import"
date: 2026-09-03
version: "2.14.6"
tags: [service-import, Nats-Request-Info, share, max_payload, chain, observed]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats-server v2.14.6 — `Nats-Request-Info` across a service import, observed

The behavioural half of [[s-nats-server-service-imports]]: one standalone server per scene, config
mode, the responder in `SVC` printing what arrives on `svc.remote`, the requester in `APP` sending to
its imported `svc.local` with `--connection-name=tenant-agent-1`.

## Key claims

- **A1, the import without `share`**: the responder saw
  `Nats-Request-Info: {"acc":"APP","rtt":278167}`.
- **A2, `share: true` added and applied with `nats-server --signal reload`**:
  `{"start":"2026-09-03T16:29:15.891833+02:00","host":"127.0.0.1","id":10,"acc":"APP","user":"app","name":"tenant-agent-1","lang":"go","ver":"1.51.0","rtt":262292,"server":"sharelab","kind":"Client","client_type":"nats"}`.
  A config-mode user has no JWT, so `jwt`, `issuer_key`, `name_tag`, `tags` are absent.
- **B, the chain `APP → MID → SVC`** (MID imports SVC's `svc.remote` as `svc.mid` and exports
  `svc.mid`; APP imports that as `svc.local`). **B1**, `share: false` on APP's import and `true` on
  MID's: `{"acc":"APP","svc":"MID","rtt":480167,"server":"sharelab"}` — no user. **B2**, the reverse:
  the full user block plus `"svc":"MID"`. **The first hop decides.**
- **C, `max_payload: 256` and a shared import.** A 250-byte request was accepted and the raw
  subscriber in `SVC` received `HMSG svc.remote 1 _R_.itCe0T.Yg3jSh 257 507` — **257 header bytes,
  507 in total**, for 250 bytes of body: issue #8271 reproduced on 2.14.6. The control, 260 bytes,
  never left the client: `nats: error: nats: maximum payload exceeded`.
- **D, `share: true` on a stream import**: `nats-server -t` says `configuration file d.conf is valid`,
  exit 0. The key is silently ignored on a stream import in config mode; the jwt library rejects it
  ([[s-jwt-imports-exports-activation]]) — `inbox/server-issues.md` SI-6.

## Practical takeaways

- The header's two shapes are exactly the source's `getClientInfo(detailed)` split; nothing in the
  config-mode user block changes them except `share`.
- Budget for the header: about 250 bytes in config mode, plus the user JWT's length in operator mode.
- A reload flips `share` on a live import with no reconnect.

## Notable quotes

- `HMSG svc.remote 1 _R_.itCe0T.Yg3jSh 257 507` — the delivered frame that is larger than the
  server's own `max_payload`.

## Relevance to the wiki

Re-runnable evidence for [[service-import-request-info]]'s two shapes, the first-hop rule and the
`max_payload` overshoot, and the observation behind SI-6.

## Questions it answers

166, 168 (with [[s-nats-server-service-imports]]).

## Pages touched

[[service-import-request-info]] · [[cross-account-sharing]] · [[publishing]]
