<!-- source: https://github.com/nats-io/nats-server/issues/8322 (GitHub GraphQL API) · fetched 2026-08-31 -->
# nats-server issue #8322 — JetStream dynamic MaxStore shrinks after restart because it is recomputed from current free disk (Bavail), causing previously valid stream limits to fail

State: CLOSED — closed 2026-08-24 by PR #8503 ([FIXED] Dynamic max_file_store shrinks on restart as the store grows) · opened 2026-06-16 by @abferm

## Original post

### Observed behavior

- JetStream starts in dynamic storage mode (no explicit max_file_store).
- On each restart, server computes MaxStore as ~75% of current filesystem free space (diskAvailable).
- As JetStream data grows, free space drops, so computed MaxStore also drops.
- After restart, existing stream configs (sum of max_bytes) that previously worked can fail update/recreate with:
  - nats: API error: code=500 err_code=10047 description=insufficient storage resources available
- Net effect: storage ceiling ratchets downward over time in normal use.

### Expected behavior

- Dynamic startup limit should not regress simply because JetStream already uses disk.
- Dynamic limit logic should account for existing JetStream usage so restart does not reduce allowable total below already-valid stream budgets.

### Server and client version

In process server github.com/nats-io/nats-server/v2@v2.10.22

### Host environment

NATS Server: v2.10.22
JetStream: enabled
OS: Linux (ext4)
Deployment: single-node embedded/server process
Storage mode: file store, dynamic (no explicit max_file_store)

### Steps to reproduce

1. Start NATS with JetStream enabled and file store, without explicit max_file_store.
2. Create streams whose total configured max_bytes is valid under initial dynamic MaxStore.
3. Publish enough data so JetStream consumes significant disk space.
4. Restart server.
5. Observe startup Max Storage is lower than before (derived from reduced free space).
6. Attempt stream update/recreate (or startup path that does CreateOrUpdateStream).
7. Observe failure with err_code=10047 insufficient storage resources available.

## Comment — @abferm (2026-06-16)

Offending code can be found here:
https://github.com/nats-io/nats-server/blob/c16afd1db4006237eb156ccaa77117f1ecd1835a/server/jetstream.go#L2726
and
https://github.com/nats-io/nats-server/blob/c16afd1db4006237eb156ccaa77117f1ecd1835a/server/disk_avail.go#L23

## Comment — @jivteshsingh (2026-06-18)

Hi @abferm, thanks for the detailed write-up. I dug into the code and I think I follow the root cause:

In dynamic mode (`server/jetstream.go` ~L2726), `MaxStore` is set from `diskAvailable()`, which (`server/disk_avail.go` L31) computes `Bavail * Bsize * 3/4` i.e. **75% of currently *free* disk only**. Since that excludes the space JetStream's own `StoreDir` already consumes, each restart recomputes a smaller ceiling as usage grows which is exactly the downward ratchet described here.

Proposed direction: when computing the dynamic limit, add the current size of `StoreDir` back to the free space before applying the 75%, so the limit reflects *total space available to JetStream* (free + already-used-by-JS) and stays stable across restarts.

A few things I'd appreciate maintainer guidance on before opening a PR:
1. Preferred location : compute existing `StoreDir` usage at the caller (`jetstream.go`, OS-agnostic) vs inside `diskAvailable` (which has per-OS implementations)?
2. Is there an existing helper for directory size I should reuse?
3. Any concern with the 75% headroom now applying to (free + used) -> e.g. over-allocation edge cases you'd want guarded?

Happy to implement this with tests if the direction looks right. First-time contributor here, so pointers are welcome!

## Comment — @MauriceVanVeen (2026-06-18)

Production-grade systems (in my opinion anyway) shouldn't rely on these dynamic values, and instead explicitly set the allowed memory and storage space JetStream can use.

Even though this method of calculating available disk is flawed, it works well enough as a default and when used for local/ephemeral server instances that are only used for testing, etc.

Optionally you could assume that all streams are allowed to be loaded on startup if the limit is dynamic, afterward get the available disk space and then loop over the file-based streams and their reported bytes size and add that back into the dynamic limit.

But then again, this may be fine for local setups, but becomes problematic anyway if the disk is shared by multiple processes (since the limit is only computed on startup) and the limit is static anyway for some OS's like in `disk_avail_windows.go`, hence my suggestion to set it explicitly for production setups.

---

Side-note: 2.10.22 has been out of support for some time. I'd highly recommend upgrading to latest 2.12 or 2.14.

## Comment — @jivteshsingh (2026-06-18)

Thanks @MauriceVanVeen, really helpful context and fair that production setups should set explicit `max_file_store` rather than lean on the dynamic default.

Since dynamic mode is still the out-of-the-box default, would a best-effort improvement be welcome? i.e. on startup, after recovering file-based streams, add their reported bytes back into the dynamic limit (as you described) so a restart doesn't shrink the ceiling for the local/ephemeral case. Or given the shared-disk and static `disk_avail_windows.go` caveats, do you consider this effectively wont fix in favor of explicit limits?

Happy to open a PR for the best-effort version if it'd be accepted. Also good call on the version, I've been working against latest `main` (2.15-dev), not 2.10.22.

## Comment — @MauriceVanVeen (2026-06-19)

> Since dynamic mode is still the out-of-the-box default, would a best-effort improvement be welcome? i.e. on startup, after recovering file-based streams, add their reported bytes back into the dynamic limit (as you described) so a restart doesn't shrink the ceiling for the local/ephemeral case. Or given the shared-disk and static `disk_avail_windows.go` caveats, do you consider this effectively wont fix in favor of explicit limits?

An improvement in this area would be welcome! 🙂 

Restoring the streams first, and then adding back the reported bytes to the dynamic limit would at least ensure that the server can still start up, even if the overall dynamic mode is still best-effort.

## Comment — @abferm (2026-06-19)

Some more feedback for consideration.

First off, I would like to mention that I have worked around this issue by setting explicit limits, and I do consider this a workaround. I had to upgrade to do so, as the version I first encountered this issue on was affected by #8160 .

Second, while I understand the sentiment that the limit should be explicitly set in production, dynamic mode is there and is the default. I think many users including myself would prefer to set per-stream limits only. This gives a smaller number of parameters to adjust if you expand you EBS volume in AWS for example. It might be nice if we could disable the global limit entirely or have the global limit be in addition to streams with explicit size limits.

Third, I think a big aspect of the issue is that the error message I received `insufficient storage resources available` seems to indicate a lack of physical storage rather than a configuration issue.

## Comment — @jivteshsingh (2026-06-20)

Thanks @abferm agree the dynamic default should "just work" for the per-stream-limits-only case; that's the spirit of this fix.

The PR I just opened (#8328) is scoped to the specific regression you reported (the dynamic limit shrinking on restart). The two broader ideas feel like they deserve their own issues so they get proper visibility:

- being able to disable the global dynamic limit entirely, or have it be additive to explicitly-sized streams - that's more of a design call for the maintainers,
- and the misleading `insufficient storage resources available` message (it reads like a physical-disk problem rather than a config/limit one) - that one looks like a small, self-contained improvement; happy to take a crack at it as a follow-up if useful.

Keeping this PR focused on the restart regression so it stays easy to review, but +1 on all three as worth addressing.
