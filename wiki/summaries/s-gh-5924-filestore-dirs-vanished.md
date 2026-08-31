---
title: "gh#5924 — Stream directories disappeared under a running server"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/5924
source-path: raw/gh-discussions/gh-5924.md
author: "@anpatel1996 (asking), @neilalexander (maintainer, answering)"
article: "JetStream failed to store a msg on stream '$G > : error opening msg block file [\"\"]: open : no such file or directory"
date: 2024-09-25
version: "2.9.14, then 2.10.21"
tags: [filestore, tmpfs, ram-disk, store-dir, kubernetes, msg-block]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5924 — 45 of 50 stream directories gone, and the server still lists the streams

A two-month thread with **no chosen answer** but a maintainer diagnosis that is unambiguous. The
question-bank row that pointed here (**Q26**) was mined from the docs' phrasing "out of disk"; the
thread is about something else entirely, and the row has been corrected.

## Key claims

**The symptom.** After ~30 days of light traffic on **2.9.14**, publishes started failing with

```
JetStream failed to store a msg on stream '$G > : error opening msg block file [""]: open : no such file or directory
```

`nats stream info` still listed **all ~50 streams**; `jetstream/$G/streams/` on disk held **5
directories**. Upgrading to **2.10.21** did not change the behaviour.

**The server does not do this** (@neilalexander, 2024-09-25):

> "NATS shouldn't be deleting folders from the disk unless the streams themselves were deleted or
> moved off that node (due to a cluster resize/move)."

and again on 2024-11-21:

> "Yes, it's definitely not OK for filestore if directories/files disappear from under the server."

**The cause is the storage, and it took four exchanges to surface it.** The deployment was single-node
Kubernetes with `store_dir` on a **RAM disk** (tmpfs) volume-mounted into the pod — chosen, the
reporter says, for "faster access". The maintainer's answer:

> "Many Linux distributions have tools, such as `tmpwatch`, `tmpreaper` and `tmpfiles.d`, enabled by
> default to automatically delete files from tmpfs after they reach a certain age. You should never
> rely on RAM disks being anything other than temporary."

and the rule that follows:

> "pointing the file store to tmpfs is not a supported/endorsed configuration."

**File storage on tmpfs is not "memory storage".** The maintainer names the supported alternative
explicitly — a **memory** stream, "with the obvious caveat that the data goes away when the process
restarts". He also names the reason people reach for tmpfs and why it is unnecessary: "We do
in-memory caching of filestore blocks to help speed up accesses", and if the worry is disk usage,
"you should use stream limits".

**A red herring the thread rules out.** The reporter linked a 2016 `natsio` Google Group post with the
same shape; the maintainer notes it "is pre-JetStream (it is for the deprecated NATS Streaming)".

## Practical takeaways

- The pairing of *streams present in `nats stream info`* with *directories missing under `store_dir`*
  is diagnostic: stream **metadata** lives in the meta layer, message **blocks** live in the
  directory, and the two can disagree only if something outside the server removed files.
- Anything that reaps files by age under `store_dir` — `tmpwatch`, `tmpreaper`, `systemd-tmpfiles`,
  a container image cleaner — produces this. The default `store_dir` on a server with no
  `jetstream { store_dir }` set is under `os.TempDir()`, which is exactly where such tools look
  (see [[s-nats-server-jetstream-resources]]; the server logs `Temporary storage directory used,
  data could be lost on system reboot` when it falls back there).
- Age is the trigger, so the failure appears **weeks** after deployment on the *least* busy streams —
  which is why the reporter's first hypothesis was "inactivity".

## Relevance to the wiki

The symptom page is [[stream-directories-disappear]]. It also supplies the negative half of
[[jetstream-out-of-disk]]: an "I ran out of storage"-shaped error that is not a capacity problem at
all.

## Questions it answers

- The corrected **Q26** ("stream directories disappear from `store_dir` while the server still lists
  the streams").

## Pages touched

[[stream-directories-disappear]] · [[jetstream-out-of-disk]] · [[install-nats-server]] ·
[[jetstream-sizing]] · [[stream]]
