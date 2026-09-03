---
title: "stream directories disappear from store_dir"
type: gotcha
area: [jetstream, deploy]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [filestore, store_dir, tmpfs, ram-disk, tmpreaper, msg-block, kubernetes]
aliases: ["error opening msg block file", "no such file or directory", "JetStream failed to store a msg", "missing stream directories", "tmpfs store_dir"]
sources: [s-gh-5924-filestore-dirs-vanished, s-nats-server-jetstream-resources, s-docs-hardening, s-gh-7749-hostpath-jetstream, s-relnotes-2.10]
created: 2026-08-31
updated: 2026-09-03
---

# Stream directories disappear from `store_dir`

`nats stream info` lists all your streams. The directory under `store_dir` holds a fraction of them.
Publishes fail with a missing file.

## Symptom

```
JetStream failed to store a msg on stream '$G > : error opening msg block file [""]: open : no such file or directory
```

and, on disk, far fewer directories than streams:

```
$ nats stream ls | wc -l          # ~50 streams
$ ls jetstream/$G/streams/ | wc -l
5
```

In the reported case this appeared after **~30 days** of light traffic and survived an upgrade from
2.9.14 to 2.10.21 (source: [[s-gh-5924-filestore-dirs-vanished]]).

## The one thing this tells you

**The server did not do it.** Stream *metadata* lives in the meta layer; message *blocks* live in the
directory. The two can only disagree if something outside `nats-server` removed files.

> "NATS shouldn't be deleting folders from the disk unless the streams themselves were deleted or
> moved off that node (due to a cluster resize/move)." — @neilalexander, 2024-09-25
>
> "Yes, it's definitely not OK for filestore if directories/files disappear from under the server."
> — @neilalexander, 2024-11-21

(source: [[s-gh-5924-filestore-dirs-vanished]])

## Quick triage

```
nats stream ls
ls -la <store_dir>/jetstream/<account>/streams/
findmnt -T <store_dir>            # what filesystem is this actually on?
systemctl list-timers | grep -i tmpfiles
```

`findmnt` is the one that usually ends the investigation.

## Causes, ranked

### 1. `store_dir` is on tmpfs, and something reaps it by age

The reported cause, and the only one confirmed. `store_dir` was a RAM disk mounted into the pod, for
"faster access".

> "Many Linux distributions have tools, such as `tmpwatch`, `tmpreaper` and `tmpfiles.d`, enabled by
> default to automatically delete files from tmpfs after they reach a certain age. You should never
> rely on RAM disks being anything other than temporary."
>
> "pointing the file store to tmpfs is not a supported/endorsed configuration."
> — @neilalexander, 2024-11-21

**How to confirm.** `findmnt -T <store_dir>` reports `tmpfs`, and `systemd-tmpfiles`/`tmpwatch`/
`tmpreaper` is enabled. The age trigger is why the *quietest* streams go first and why the failure
appears weeks after deployment — which is exactly why the reporter's first theory was "inactivity".

**The fix.** Move `store_dir` to persistent storage. If you actually want data in RAM, use a
**memory** stream (`--storage=memory`), which the maintainer names as the supported option "with the
obvious caveat that the data goes away when the process restarts". Note what memory storage costs
you: no snapshot backup at all (see [[backup-and-restore-jetstream]]).

**The performance reason for tmpfs does not hold.** "We do in-memory caching of filestore blocks to
help speed up accesses" — and if the concern was disk usage, "you should use stream limits".

### 2. `store_dir` was never set, so it defaults under the system temp directory

With no `jetstream { store_dir }`, the server places the store at `os.TempDir()/nats/jetstream` and
logs

```
Temporary storage directory used, data could be lost on system reboot
```

(`jetstream.go:2746–2749`, source: [[s-nats-server-jetstream-resources]]). That is `/tmp` on Linux —
precisely the directory age-based reapers are configured to clean. **Always set `store_dir`
explicitly**; [[install-nats-server]] does.

### 3. Something else on the host cleans the path

Container image pruners, a `PersistentVolume` with a `Delete` reclaim policy that got recycled, a
backup agent restoring a partial tree, a `hostPath` volume on a node that was replaced. All produce
the same log line. The `findmnt` and mount-source check narrows it.

### 4. The streams really were moved off this node

The one legitimate case in the maintainer's sentence: a cluster resize, a `peer-remove`, or a
`--replicas` change relocates a replica and removes the local directory. **Then `nats stream info`
also shows the new peer set**, so the symptom does not match — the whole point of this page is that
the stream is still assigned here.

## Prevention

- Set `store_dir` explicitly, on a real filesystem, and make sure nothing reaps it by age. The
  sandboxed unit in [[install-nats-server]] and the hardening guidance in [[s-docs-hardening]] both
  assume a persistent path.
- On Kubernetes, a `PersistentVolumeClaim` — not `emptyDir`, whose `Memory` medium is tmpfs, and not
  `hostPath` on a node pool that recycles. That is also the public answer to the question asked
  directly — "should we use `hostPath`… will this impact HA?" — whose reasoning is the same failure
  from the other end: a rescheduled pod with a `hostPath` store starts **empty**, so the replica has
  to resync from scratch (source: [[s-gh-7749-hostpath-jetstream]]). The whole argument, the chart
  values that implement it, and the ceiling to set alongside them are on [[kubernetes-storage]].
- Watch for `Temporary storage directory used, data could be lost on system reboot` at startup. It is
  a one-line warning that your entire JetStream store is in `/tmp`.

## Not this page

A missing block file is **not** [[jetstream-out-of-disk]] (that is capacity or reservation
arithmetic) and **not** [[malformed-or-corrupt-message]] (that is a block that exists and does not
parse). The server distinguishes them too: `os.IsNotExist` is filtered out of the critical-write-error
path and only logs `Resource not found: %v` (`raft.go:5160–5163`).

### Since 2.10.22 the server warns about a temporary store directory

"A warning will now be logged at startup if the JetStream store directory appears to be in a
temporary folder" (2.10.22, #5935 "Warn if using temp storage for JetStream") (source:
[[s-relnotes-2.10]]). On 2.10.22 or later that log line is the tmpfs case above announcing itself
before it bites; the thread this page rests on ran 2.9.14 to 2.10.21, the last release without it.
2.10.22 also gave the filestore and log files "safer default file permissions".


## Related

[[jetstream-out-of-disk]] · [[malformed-or-corrupt-message]] · [[stream]] ·
[[backup-and-restore-jetstream]] · [[install-nats-server]] · [[jetstream-sizing]] ·
[[nats-helm-charts]] · [[config-keys]]

## Sources

- [[s-gh-5924-filestore-dirs-vanished]] — the thread, the symptom and the maintainer's diagnosis.
- [[s-nats-server-jetstream-resources]] — the default `store_dir` and its warning, at v2.14.6.
- [[s-docs-hardening]] — the deployment shape that assumes a real, persistent store directory.
- [[s-gh-7749-hostpath-jetstream]] — the same failure asked about in advance, as `hostPath` on
  Kubernetes. · [[s-relnotes-2.10]]
