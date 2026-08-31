---
title: "Critical write error: malformed or corrupt message"
type: gotcha
area: [jetstream, topology, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [raft, corruption, wal, filestore, quorum, resetClusteredState, upgrade]
aliases: ["malformed or corrupt message", "Critical write error", "Wrong index", "Error storing entry to WAL", "JetStream out of resources will be DISABLED", "corrupted JetStream cluster"]
sources: [s-gh-7463-jetstream-corruption, s-nats-server-jetstream-log-warnings, s-nats-server-jetstream-resources, s-docs-rolling-upgrades]
created: 2026-08-31
updated: 2026-08-31
---

# "Critical write error: malformed or corrupt message"

A stream loses quorum, JetStream shuts down on one node, and rebuilding that node from a blank
volume reproduces the failure — which looks like the corruption spreading and is not.

## Symptom

On the affected node:

```
[WRN] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Wrong index, ae is &{leader:VNsg0pXW term:7 commit:3258048 ...}, index stored was 3258025, n.pindex is 3258048
[ERR] RAFT [xY6fvr60 - C-R3F-atNRG1rP] Critical write error: malformed or corrupt message
[ERR] JetStream out of resources, will be DISABLED
[WRN] Failed to install snapshot for '$G > IDX_TRADE_P005 > WORK_TRADE' [C-R3F-atNRG1rP]: malformed or corrupt message
[INF] Initiating JetStream Shutdown...
```

on the others:

```
[WRN] JetStream cluster stream '$G > IDX_TRADE_P005' has NO quorum, stalled
```

and sometimes an index that cannot be real:

```
[WRN] RAFT [...] Wrong index, ae is &{... pindex:108751 entries: 1}, index stored was 5066558170728645, n.pindex is 108751
[WRN] RAFT [...] Expected first catchup entry to be a snapshot and peerstate, will retry
[WRN] RAFT [...] Error storing entry to WAL: raft: could not store entry to WAL
```

(source: [[s-gh-7463-jetstream-corruption]], a 3-node StatefulSet on `nats:2.9.8-alpine`)

## Read two things before anything else

**1. `JetStream out of resources, will be DISABLED` here does not mean the disk is full.** The
out-of-space handler is also called from the Raft critical-write-error path:

```go
if isOutOfSpaceErr(err) {
	// For now since this can be happening all under the covers, we will call up and disable JetStream.
	go n.s.handleOutOfSpace(nil)
}
```

(`raft.go:5183–5186`, source: [[s-nats-server-jetstream-resources]]). In the reported case storage was
at **6–7% of 200 GB** and memory at 1.3 GB of a 2 GB limit. If the volume genuinely is full, you are
on [[jetstream-out-of-disk]] instead.

**2. On 2.12 and later the error names the file.** The message is built by

```go
return fmt.Sprintf("malformed or corrupt message in %s: %s", filepath.Base(e.fn), e.detail)
```

(`filestore.go:8859`). In **2.9, 2.10 and 2.11** it was a bare sentinel with no file name, which is
why the log above says nothing about which block failed. Upgrading buys you the diagnostic before it
buys you anything else (source: [[s-nats-server-jetstream-log-warnings]]).

## Quick triage

```
nats server list                       # which node is missing / not current
nats stream cluster step-down <stream>
nats server report jetstream
df -h <store_dir>                      # rule cause 3 in or out in one command
```

Then grep the startup log for the line that proves a stream loaded:

```
[INF]   Restored 998,291 messages for stream '$G > IDX_TRADE_P001' in 13.513s
```

Its **absence** for a stream that used to print it is the cheapest corruption check available, and it
is what the reporter noticed himself.

## Causes, ranked

### 1. The server version is too old — the confirmed answer

The only answer this thread got, and it worked.

> "2.9.x is now very old, unsupported and 100s of bug fixes behind, we have invested a lot of time on
> improving the areas you mention. You need to upgrade to 2.12.x, we can't help with such old
> versions." — @ripienaar, 2025-10-22 (marked as the answer)

> "Thanks! I should have checked before posting.. upgrading did fix the issue" — @KenLR, same day

**How to confirm.** `nats server list` or the startup banner. Anything on 2.9 or 2.10 that reaches
this state has no other diagnosis worth pursuing first.

**The fix.** Upgrade, following [[upgrade-a-cluster]] — the ordering rules matter more than usual on a
cluster with a stalled stream, because the meta leader must go **last** and every replica must read
`current` before the next node is touched.

### 2. Why a fresh PVC re-corrupts, and why that is not contagion

The reporter deleted the pod's PVC and let it sync from the two healthy replicas; the new,
empty volume hit `Critical write error: malformed or corrupt message` again. That is not the
corruption spreading — the replica is replaying the leader's log through **the same defective code
path** and breaking on the same entry. Replacing storage cannot fix a code-path defect.

**The consequence for recovery:** on an old server, restoring one node from its peers is not a
recovery step. Upgrade first, then rebuild.

### 3. The disk or filesystem really is at fault

`Critical write error` is raised by `fs.error(…)` in the filestore (`filestore.go:5301`) and by
`n.error(…)` in Raft (`raft.go:5167`), and in both cases the node **stops**: `n.werr = err` followed
by `n.shutdown()`. Two error classes are filtered out first and only warn — a permission error, and
`os.IsNotExist`, which logs `Resource not found: %v` and returns (`raft.go:5155–5163`). So a genuine
I/O error, a full volume, or a filesystem that lies about `fsync` all land here.

**How to confirm.** `dmesg`, the volume's own metrics, and `df -h`. Network-attached storage that
acknowledges writes it has not durably taken is the classic producer; [[replicas]] explains why
`sync_interval` and `sync_always` exist.

**The fix.** Replace the volume, then let the node rebuild — after cause 1 is ruled out.

### 4. The server tried to heal it and refused

When an entry cannot be applied, the apply loop calls `resetClusteredState`
(`jetstream_cluster.go:3912`), which steps the node down and rebuilds the Raft state. It **declines**
in four cases, each with its own warning:

```
Will not reset stream '<acc> > <stream>', stream is closed
Will not reset stream '<acc> > <stream>', raft group "X" was replaced by "Y"
Will not reset stream '<acc> > <stream>', server resources exceeded
Stream '<acc> > <stream>' errored, account resources exceeded
```

The last two are real capacity problems blocking the repair — fix those first ([[jetstream-out-of-disk]])
and the reset can proceed. When it does proceed you get

```
Resetting stream cluster state for '<acc> > <stream>'
```

and **messages are preserved** unless the error was `errFirstSequenceMismatch`, which is the one case
that deletes them (`jetstream_cluster.go:3974`). A `Critical write error` with no `Resetting stream
cluster state` after it is a stream that did not heal.

### 5. It is not corruption, it is a missing file

`error opening msg block file […]: no such file or directory` is a different failure with a different
cause — see [[stream-directories-disappear]]. The server separates them too: `os.IsNotExist` never
reaches the critical-write-error path.

## Recovery, in order

1. **Check the version.** Below 2.12, upgrade before anything else.
2. **Keep quorum.** Two healthy replicas of three means the stream is stalled, not lost. Do not
   delete a second node's state.
3. **Step down the affected stream** (`nats stream cluster step-down <stream>`) so a healthy replica
   leads.
4. **Rebuild the bad node's state**, one node at a time, gated on `nats stream info` showing every
   replica `current` before touching the next — the discipline in [[rebalance-streams]].
5. If quorum is already lost, you are in [[disaster-recovery]], and the decision is which copy to
   promote.

## Prevention

- Stay on a supported minor. This whole thread is one version check.
- Alert on `$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST` and
  `$JS.EVENT.ADVISORY.SERVER.OUT_OF_STORAGE` — see [[advisories]].
- Watch for the `Restored N messages for stream` lines at startup and alert on a stream that stops
  printing one.
- Real disks. See [[stream-directories-disappear]] for what happens when `store_dir` is not one.

## Explained by

[[raft-in-nats]] for the append→commit→apply loop the `Wrong index` warnings come out of;
[[s-nats-server-jetstream-log-warnings]] for each format string at v2.14.6.

## Related

[[raft-in-nats]] · [[jetstream-out-of-disk]] · [[stream-directories-disappear]] ·
[[upgrade-a-cluster]] · [[disaster-recovery]] · [[rebalance-streams]] · [[replicas]] ·
[[advisories]] · [[nats-server-2.12]] · [[stream-has-high-message-lag]]

## Sources

- [[s-gh-7463-jetstream-corruption]] — the thread, its logs, the three failed recovery attempts and
  the answer.
- [[s-nats-server-jetstream-log-warnings]] — every format string and `resetClusteredState`, at
  v2.14.6, with the 2.9→2.12 change in the corrupt-message error.
- [[s-nats-server-jetstream-resources]] — why the out-of-resources line appears on a nearly empty
  disk.
- [[s-docs-rolling-upgrades]] — the upgrade procedure the fix requires.
