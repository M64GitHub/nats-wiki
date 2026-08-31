---
title: "gh#7463 — How to find out what caused a corruption in JetStream Cluster?"
type: summary
area: [jetstream, topology, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7463
source-path: raw/gh-discussions/gh-7463.md
author: "@KenLR (asking), @ripienaar (maintainer, answering)"
article: "How to find out what caused a corruption in JetStream Cluster?"
date: 2025-10-22
version: "2.9.8, resolved by upgrading to 2.12.x"
tags: [raft, corruption, filestore, quorum, kubernetes, upgrade, wal]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7463 — A corrupt Raft WAL that "spread back" from the healthy replicas

The thread behind question-bank **Q39**, with a **chosen answer** and — unusually for this bank — a
confirmed fix reported by the person who asked. The answer is one sentence long and the whole value
of the thread is in what it rules out.

## Key claims

**The symptom, verbatim from a 3-node StatefulSet on `nats:2.9.8-alpine`, EBS gp3, R3 file-backed
WorkQueue streams:**

```
[WRN] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Wrong index, ae is &{leader:VNsg0pXW term:7 commit:3258048 ...}, index stored was 3258025, n.pindex is 3258048
[ERR] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Critical write error: malformed or corrupt message
[ERR] JetStream out of resources, will be DISABLED
[WRN] Failed to install snapshot for '$G > IDX_TRADE_P005 > WORK_TRADE' [C-R3F-atNRG1rP]: malformed or corrupt message
[INF] Initiating JetStream Shutdown...
[INF] JetStream Shutdown
```

and on the other pods:

```
[WRN] JetStream cluster stream '$G > IDX_TRADE_P005' has NO quorum, stalled
```

plus a second shape with an obviously impossible stored index:

```
[WRN] RAFT [xY6fvr60 - C-R3F-q6QNvUn0] Wrong index, ae is &{... pindex:108751 entries: 1}, index stored was 5066558170728645, n.pindex is 108751
[WRN] RAFT [xY6fvr60 - C-R3F-q6QNvUn0] Expected first catchup entry to be a snapshot and peerstate, will retry
[WRN] RAFT [xY6fvr60 - C-R3F-q6QNvUn0] Error storing entry to WAL: raft: could not store entry to WAL
```

**What it was not.** The reporter's own environment section rules out the obvious: the cluster had
run for **20 days**, storage was at **6–7% of 200 GB**, memory at **1.3 GB of a 2 GB limit**. This is
the thread's most useful contribution — it is a corruption with *no* resource pressure behind it,
even though the server's own log line says "out of resources".

**Three recovery attempts, all failed.** Restarting the pod re-hit the corruption on PVC reload;
deleting the stream CRD and letting ArgoCD recreate it changed nothing; **deleting the PVC entirely**
and letting the pod sync from the two healthy replicas reproduced the same
`Critical write error: malformed or corrupt message` — which is what made the reporter conclude the
corruption was spreading back from the other nodes.

**The answer** (@ripienaar, marked as the answer):

> "2.9.x is now very old, unsupported and 100s of bug fixes behind, we have invested a lot of time on
> improving the areas you mention.
>
> You need to upgrade to 2.12.x, we can't help with such old versions."

**It worked.** The reporter confirmed the same day:

> "Thanks! I should have checked before posting.. upgrading did fix the issue"

with the restore line he had stopped seeing:

```
[7] 2025/10/22 23:08:17.651214 [INF]   Restored 998,291 messages for stream '$G > IDX_TRADE_P001' in 13.513s
```

## Practical takeaways

- A fresh PVC that re-corrupts on catch-up looks like contagion and is not: the replica is replaying
  the leader's WAL through the **same defective code path**, so the same entry breaks it again.
- `Restored N messages for stream '<account> > <stream>'` at INFO on startup is the positive signal.
  Its **absence** for a stream that used to print it is the cheapest corruption check there is, and
  the reporter noticed exactly that.
- The version floor is the first question to answer, not the last. 2.9 reached this state; the same
  workload on 2.12 did not.

## Notable quotes

> "Even after deleting and recreating individual PVCs, the corruption spread back from other
> replicas." — @KenLR, framing the misdiagnosis the thread corrects.

## Relevance to the wiki

The symptom page is [[malformed-or-corrupt-message]]. The `JetStream out of resources, will be
DISABLED` line in this log is **not** a capacity message — it is the out-of-space handler being
called from the Raft write-error path — which is verified against the source in
[[s-nats-server-jetstream-resources]] and separates this page from [[jetstream-out-of-disk]].

## Questions it answers

- **Q39** — how do I find out what corrupted a JetStream cluster, and how do I recover it.

## Pages touched

[[malformed-or-corrupt-message]] · [[jetstream-out-of-disk]] · [[raft-in-nats]] ·
[[upgrade-a-cluster]] · [[disaster-recovery]] · [[nats-server-2.12]]
