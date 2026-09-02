---
title: "nats.go v1.53.1 — how the KV and object-store clients address a mirrored bucket"
type: summary
area: [clients, kv, objectstore]
source-path: raw/nats-go-src/kv-object-mirror-v1.53.1.md
source-url: https://github.com/nats-io/nats.go/blob/v1.53.1/jetstream/kv.go
author: "nats-io/nats.go (Apache-2.0)"
article: "jetstream/kv.go and jetstream/object.go at v1.53.1, selected ranges"
date: 2026-08-11
version: "nats.go v1.53.1 (nats-server 2.14.6 in the runs)"
tags: [nats.go, kv, objectstore, mirror, putPre, kvSubjectsPreTmpl, OBJ_, subject-transform, client-behaviour]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# nats.go v1.53.1 — what the client does with a mirror bucket

Read to explain three observations in [[s-nats-server-mirrors-observed]]: a same-domain KV mirror
that `nats kv get` cannot read by its own name, a cross-domain one it can, and an object-store mirror
that lists as empty until a transform is added. The `nats` CLI 0.4.0 is built on this client, so
these are the CLI's rules too.

## Key claims

**Creating a KV bucket with `Mirror` set** (`jetstream/kv.go:695–702`) prefixes the mirror name with
`KV_` if needed and sets `scfg.MirrorDirect = true`. **It adds no subject transform** — exactly what
ADR-57 specifies for mirrors, and unlike sources, which get `$KV.<src>.>` → `$KV.<bucket>.>`
generated for them.

**Binding a bucket** (`mapStreamToKVS`, `1593–1620`) sets the read prefix `kv.pre` to
`$KV.<this bucket>.` (line 1599). For a mirror, `kv.putPre` — writes — is pointed at the origin
(`$KV.<origin>.`), and **only if the mirror has an `external.api` prefix** is `kv.pre` rewritten to
the origin's too (`1613–1615`), with `useJSPfx` cleared. The same-domain case (`1616–1617`) leaves
the read prefix on the mirror's own name:

```go
  1610		if m := info.Config.Mirror; m != nil {
  1611			bucket := strings.TrimPrefix(m.Name, kvBucketNamePre)
  1612			if m.External != nil && m.External.APIPrefix != "" {
  1613				kv.useJSPfx = false
  1614				kv.pre = fmt.Sprintf(kvSubjectsPreTmpl, bucket)
  1615				kv.putPre = fmt.Sprintf(kvSubjectsPreDomainTmpl, m.External.APIPrefix, bucket)
  1616			} else {
  1617				kv.putPre = fmt.Sprintf(kvSubjectsPreTmpl, bucket)
  1618			}
  1619		}
```

So a same-domain mirror `DNS_FILE` of `DNS` is read at `$KV.DNS_FILE.<key>`, which the mirror does
not hold (it holds `$KV.DNS.<key>`); a cross-domain mirror `CFG_M` of `CFG` is read at
`$KV.CFG.<key>`, which it does. Both are direct gets addressed to the mirror's own stream
(`$JS.API.DIRECT.GET.KV_<mirror>.…`). Writes through either go to the origin.

**The object store binds by stream name** (`jetstream/object.go:598–606`): `ObjectStore(ctx, bucket)`
calls `js.Stream(ctx, "OBJ_"+bucket)` — no lookup by subject, which is what nats.go #1568 changed in
2024-02 so that a mirror (which answers no subject lookup) can be opened at all. The chunk and
metadata subjects are then `$O.<bucket>.C.>` / `$O.<bucket>.M.>` from the *bucket* name (`480–483`),
so a mirror named `dms_mirror` is read at `$O.dms_mirror.…` and must carry the transform
`$O.dms.>` → `$O.dms_mirror.>`. There is no mirror branch in `object.go` at all.

## Practical takeaways

- To read a **same-domain** KV mirror by its own name, build it as a stream with the transform
  `$KV.<origin>.>` → `$KV.<mirror>.>` (the CLI's `nats kv add --mirror` will not). Or address the
  origin's name and let `mirror_direct` route the read — the design ADR-57 describes.
- A **cross-domain** KV mirror (`--mirror-domain`) is readable by its own name because of the branch
  above; do not expect the same-domain one to behave the same.
- An object-store mirror is never first-class in this client (nats.go #1874 open since 2025-05); it
  is a hand-built `OBJ_<name>` stream with the transform, and then every operation works.

## Questions it answers

- **Q105** (why the listing fails and what the mirror gives you), the client half; **Q76**'s CLI
  observations.

## Pages touched

[[key-value]] · [[object-store]] · [[nats-go]] · [[nats-cli]]
