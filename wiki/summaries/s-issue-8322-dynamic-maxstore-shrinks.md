---
title: "nats-server issues #8322 and #5871 — the dynamic max_file_store shrinks at every restart"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/issues/8322
source-path: raw/gh-issues/issue-8322.md
author: "@abferm and @rafsawicki (reporting), @MauriceVanVeen and @derekcollison (maintainers), @jivteshsingh (fixing)"
article: "JetStream dynamic MaxStore shrinks after restart because it is recomputed from current free disk (Bavail)"
date: 2026-06-16
version: "reported on 2.10.20 and 2.10.22; fixed by PR #8503, first shipped in nats-server 2.14.6"
tags: [max_file_store, dynamic-limits, 10047, restart, auto-sizing, bavail]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# issues #8322 and #5871 — the auto-sized disk limit that ratchets downwards

Two reports of the same defect, **two years apart**. `raw/gh-issues/issue-5871.md` (2024-09-10) was
closed with "we do not recommend auto-sizing"; `raw/gh-issues/issue-8322.md` (2026-06-16) was accepted
and fixed. Together they are the clearest public statement of what the JetStream storage default
actually is, and of the maintainers' position on it.

## Key claims

**The mechanism, stated by the reporter and confirmed by the code:**

> "On each restart, server computes MaxStore as ~75% of current filesystem **free** space
> (`diskAvailable`).
> As JetStream data grows, free space drops, so computed MaxStore also drops.
> … Net effect: storage ceiling ratchets downward over time in normal use."

**The failure it produces** — the same `10047` as [[s-issue-4281-insufficient-storage]], but arriving
at a restart with no configuration change:

```
nats: API error: code=500 err_code=10047 description=insufficient storage resources available
```

**#5871's reproduction is the one to quote**, because it is arithmetic anyone can follow:

> 1. Start NATS server with 512MB of empty storage attached, which results in a file store limit of 338MB
> 2. Create a stream with a limit of 300 MB
> 3. Send enough messages to fill in 250 MB storage in a stream
> 4. Restart a NATS server
> 5. A server sets a file store limit of 196 MB and then refuses to start, as it's unable to restore a
>    stream with an error `insufficient storage resources available (10047)`

**The maintainers' position, twice.** @derekcollison (2024-09-10):

> "We do not recommend auto-sizing for real world production uses. You should always configure
> JetStream to use as much disk as you want / need explicitly in the configuration.
>
> Auto detection is for development and testing."

@MauriceVanVeen (2026-06-18):

> "Production-grade systems (in my opinion anyway) shouldn't rely on these dynamic values, and instead
> explicitly set the allowed memory and storage space JetStream can use."

with the caveat that survives the fix: the limit is **computed only at startup**, so a shared disk
invalidates it either way, and `disk_avail_windows.go` is static.

**It is not in the docs, and the reporter asked** (@rafsawicki, 2024-09-11):

> "Is this recommendation to avoid the default value mentioned anywhere in the docs? … If not, it
> might be worth explicitly mentioning it there, or maybe even printing a warning in the console during
> the startup if unsafe defaults are used."

Answered with "Not sure about the docs, but any production system should be explicit about the disk
resources it utilizes." This is recorded as **docs issue #22**.

**`max_file_store: 0` does not mean unlimited** (@rafsawicki, 2024-09-11):

> "It also no longer seems to be possible to specify there should be no limit, as setting the value to
> 0 (as mentioned in the docs) prevents the creation of any stream."

Confirmed in the source: an explicitly-set `0` is taken literally, so JetStream gets **zero** file
storage.

**The fix.** PR **#8503**, *"[FIXED] Dynamic max_file_store shrinks on restart as the store grows"*,
merged **2026-08-24**. It adds `finalizeDynamicMaxStore`, which waits until file-based streams have
been recovered and then adds the recovered bytes back into the limit, scaled by the same 75%; while
recovery is in progress the limit is marked provisional and the reservation check is skipped. The
function is **absent from v2.14.4 and v2.14.5 and present in v2.14.6** — so **2.14.6 is the floor**
for this fix.

**Two follow-ups were split out and are not fixed** (@jivteshsingh, 2026-06-20): being able to disable
the global dynamic limit or make it additive, and the error message itself, which @abferm objects to:

> "the error message I received `insufficient storage resources available` seems to indicate a lack of
> physical storage rather than a configuration issue."

## Practical takeaways

- The JetStream file-storage default is **75% of what is free under `store_dir` at startup** — not 75%
  of the volume, and not 1 TB. Every byte JetStream itself has written lowers it, on every server
  before 2.14.6.
- The failure is a **restart** failure. It does not appear in testing, it appears the first time a
  loaded server is restarted, which is usually an upgrade — see [[upgrade-a-cluster]].
- Pin `max_file_store` to the volume. Both maintainers say so; [[jetstream-sizing]] already does.
- `max_file_store: 0` disables file storage. Do not use it to mean "no limit".

## Relevance to the wiki

Feeds [[jetstream-out-of-disk]] and confirms the pin in [[jetstream-sizing]] step 4 with a concrete
failure. Supplies **docs issue #22**: the generated `reference/config/jetstream` page documents the
1 TB *fallback* as the default and never mentions the auto-sizing caveat the maintainers state twice.

## Questions it answers

- The new **Q26** — what happens when JetStream runs out of disk (the dynamic-limit half).

## Pages touched

[[jetstream-out-of-disk]] · [[jetstream-sizing]] · [[config-keys]] · [[defaults-and-limits]] ·
[[upgrade-a-cluster]] · [[nats-server-2.14]]
