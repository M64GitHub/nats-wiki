<!-- source: https://github.com/nats-io/nats.c through the GitHub REST API (`gh api repos/nats-io/nats.c/releases?per_page=10` and `gh api repos/nats-io/nats.c/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.c — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v3.13.0` — Release v3.13.0 — published 2026-06-01

https://github.com/nats-io/nats.c/releases/tag/v3.13.0

## Changelog

### Added

- The name of a connection can now be retrieved with the `natsConnection_GetName` API by @kozlovic in https://github.com/nats-io/nats.c/pull/946 and https://github.com/nats-io/nats.c/pull/953. This was proposed by @julio77it in https://github.com/nats-io/nats.c/issues/945
- The connection that created a subscription can now be accessed with `natsSubscription_GetConnection` by @kozlovic in https://github.com/nats-io/nats.c/pull/954. This was proposed by @julio77it in https://github.com/nats-io/nats.c/issues/947
- A `ThreadStartedHandler` callback (and `ThreadStartedHandlerClosure`) can now be set on `natsClientConfig` to be invoked when a thread created by the library starts, allowing further per-thread configuration such as CPU affinity, by @kozlovic in https://github.com/nats-io/nats.c/pull/957, resolves https://github.com/nats-io/nats.c/issues/956
- Clients can now bypass the internal buffer and write directly to the socket with `natsConnection_Send`, `natsConnection_SendMsg`, and `natsConnection_SendRequest` by @kozlovic in https://github.com/nats-io/nats.c/pull/973, resolves https://github.com/nats-io/nats.c/issues/970
- Clients can now be configured to opt out of aborting subsequent reconnect attempts if server returns the same auth error twice with `natsOptions_SetIgnoreAuthErrorAbort` by @kozlovic in https://github.com/nats-io/nats.c/pull/974
- JetStream pubacks can now be configured to use the connection's response muxer instead of creating its own internal subscription with the `MuxReplies` field in `jsOptionsPublishAsync` by @kozlovic in https://github.com/nats-io/nats.c/pull/985
- `kvWatchOptions` now have `Heartbeat` and `ResumeFromRevision` fields by @kozlovic in https://github.com/nats-io/nats.c/pull/989, issue raised by @afigegoznaet in https://github.com/nats-io/nats.c/issues/988
- Added support for Nats-Marker-Reason on kvOp eval by @afigegoznaet in https://github.com/nats-io/nats.c/pull/994
- Added support for nats-server 2.12 features:
  - Streams can now be configured to flush asynchronously with the `PersistMode` field in `jsStreamConfig` by @AdamPayzant in https://github.com/nats-io/nats.c/pull/961
  - `jsClusterInfo` now also includes `RaftGroup`, `LeaderSince`, `SystemAcc`, and `TrafficAcc` fields by @AdamPayzant in https://github.com/nats-io/nats.c/pull/964
  - `jsFetchRequest` can now be configured with a `Priority` field for use with Pull Consumer Priority Groups by @AdamPayzant in https://github.com/nats-io/nats.c/pull/965
  - Filtering against wildcard subjects can now be done with `ExpectLastSubjectSeqSubject` in `jsPubOptions` by @AdamPayzant in https://github.com/nats-io/nats.c/pull/969
- Added support for nats-server 2.14 features:
  - Ability to reset a consumer's delivery state without deleting and recreating it via `js_ResetConsumer` by @AdamPayzant in https://github.com/nats-io/nats.c/pull/992
  - Ability to schedule JetStream messages for future delivery with the `Schedule` field in `jsPubOptions` by @AdamPayzant in https://github.com/nats-io/nats.c/pull/991
- Added support for orbit.c features:
  - `AllowBatched` stream configuration option to allow fast publish by @AdamPayzant in https://github.com/nats-io/nats.c/pull/993
  - `AllowMsgCounter` stream configuration option to allow use of counters by @AdamPayzant in https://github.com/nats-io/nats.c/pull/990

### Changed

- TLS is now automatically enabled when a URL with the `tls://` scheme is used by @johnweldon in https://github.com/nats-io/nats.c/pull/951

### Fixed
- CRL was loaded but never enabled, fixed by @thierryba in https://github.com/nats-io/nats.c/pull/943, reported in https://github.com/nats-io/nats.c/issues/942
- Threads could potentially attempt to lock a mutex that failed to initialize by @kozlovic in https://github.com/nats-io/nats.c/pull/952
- `natsSock_ReadLine()` could miss the `\r\n` terminator of the server's initial `INFO` line when a socket read split the CRLF across two reads, causing the connect to hang until timeout by @kozlovic in https://github.com/nats-io/nats.c/pull/959, reported by @yanyongcheng in https://github.com/nats-io/nats.c/issues/958
- Non-thread safe `rand`/`srand` replaced by internal `lcg` implementation by @Kirskov in https://github.com/nats-io/nats.c/pull/963
- Builds did not properly account for absolute paths when generating `libnats.pc`, fixed by @Kirskov in https://github.com/nats-io/nats.c/pull/966, issue raised by @alexshpilkin in https://github.com/nats-io/nats.c/issues/542
- Some environment variables were not being properly loaded, fixed by @kozlovic in https://github.com/nats-io/nats.c/pull/972
- `DEV_MODE` was not enabling correctly, fixed by @kozlovic in https://github.com/nats-io/nats.c/pull/976
- `nats_CloseAndWait` could cause seg fault when trying to access freed lock created by `nats_Open`, fixed by @hhassoubi-rivianvw and @kozlovic in https://github.com/nats-io/nats.c/pull/979
- `natsConnection_Close` could fail to properly flush if data was just written to the socket and the buffer is empty, fixed by @kozlovic in https://github.com/nats-io/nats.c/pull/982
- JetStream async pull could cause a double free of a message, fixed by @kozlovic in https://github.com/nats-io/nats.c/pull/984
- Single message would be leaked if `kvWatcher_Stop` is called, fixed by @tyler92 in https://github.com/nats-io/nats.c/pull/987

### Non-code Changes
- Fixed typos in documentation and codebase by @paoloteti in https://github.com/nats-io/nats.c/pull/948 and https://github.com/nats-io/nats.c/pull/955
- Move flaky-test job into nightly by @kozlovic in https://github.com/nats-io/nats.c/pull/949
- Test mirror can be promoted to a stream by @AdamPayzant in https://github.com/nats-io/nats.c/pull/962
- Updated KeyValueKeysWithFilters test to reflect updated handling of overlapping subjects by @kozlovic in https://github.com/nats-io/nats.c/pull/968
- Added CLAUDE.md by @Jarema in https://github.com/nats-io/nats.c/pull/975
- CI actions version bump by @kozlovic in https://github.com/nats-io/nats.c/pull/981
- Fixed claude code review by @kozlovic in https://github.com/nats-io/nats.c/pull/983
- Fixed automated doc generation CI by @kozlovic in https://github.com/nats-io/nats.c/pull/986

## New Contributors
- @hhassoubi-rivianvw made their first contribution in #979
- @afigegoznaet made their first contribution in https://github.com/nats-io/nats.c/pull/994

---

### `v3.12.0` — Release v3.12.0 — published 2025-11-24

https://github.com/nats-io/nats.c/releases/tag/v3.12.0

## Changelog

This release contains a fix to the ObjectStore that caused the meta subject of objects to be incorrectly encoded, which would cause other NATS libraries to fail to retrieve some of the objects (it would depend on the result of object name encoding). The fix here could cause now the C client to be unable to retrieve objects that it previously stored. A tool has been provided to repair the object stores that may have been affected. See PR #934 and #936 for more details.

### Changed
* KeyValue
  * "const" correctness for some of the `kvStore` APIs by @nigels-com and @kozlovic in #929, #930 and #931
* ObjectStore
  * Use proper encoding for meta subject of objects. The wrong encoding would prevent other libraries (or the NATS CLI tool) from retrieving some objects by @kozlovic in #934, #936. The issue was reported by @Zabrimus in #933.


### Fixed
* Failure to reconnect in some conditions during the first connect. This would happen with option `natsOptions_SetRetryOnFailedConnect` by @Matus-p in #926

### Non-code changes
* Tests
  * Fixed `JetStreamSubscribePullAsync` to work with latest server versions by @kozlovic in #927


### New Contributors
* @nigels-com made their first contribution in #929, #930
* @Zabrimus made their first contribution in #933

---

### `v3.11.0` — Release v3.11.0 — published 2025-09-26

https://github.com/nats-io/nats.c/releases/tag/v3.11.0

## Changelog

This release contains some breaking changes. See the "Changed" section below.

### Changed
* Build
  * Disable NATS Streaming by default by @mtmk in #770
  * TLS
    * Require OpenSSL 1.1.1+ to compile. Removed the `NATS_BUILD_TLS_USE_OPENSSL_1_1_API` CMake variable by @kozlovic in #905
    * The option `natsOptions_SetSSLVerificationCallback` signature was changed to replace the use of `SSL_verify_cb` (which required OpenSSL dependency in the `nats.h` file), to the new callback `natsSSLVerifyCb`. See documentation of `natsSSLVerifyCb` to see the cast needed to compile with this new header file by @kozlovic in #908
* Modification of a `natsOptions` object if it has TLS/SSL configuration and is actively used by connections will now return a `NATS_ILLEGAL_STATE` by @kozlovic in #912


### Added
* Options
  * Ability to load the trusted CA certificates from a directory using the new option `natsOptions_LoadCATrustedCertificatesPath` by @kerbert101 in #862
  * Ability to connect via HTTP proxy for instance by adding a proxy connection handler using the new option `natsOptions_SetProxyConnHandler` by @wolfkor in #871 and @kozlovic in #897
  * Ability to load the certificate chain and key from a file on every connection attempt using the new option `natsOptions_LoadCertificatesChainDynamic` by @Matus-p in #901
  * Ability to perform concurrent TLS handshakes that may improve time it takes for concurrent connections to be established using the new option `natsOptions_AllowConcurrentTLSHandshakes ` by @kozlovic in #914. Issue was reported by @yanyongcheng in #899
* JetStream
  * Per-message TTL support (a NATS Server v2.11 feature) by @levb in #863
  * Pull consumer priority groups (a NATS Server v2.11 feature) by @levb in #869
* ObjectStore support by @kozlovic in #902. Thanks to @jfflynn41 and @alex1891 for the feedback in #876

### Improved
* JetStream 
  * Handling of publish asynchronous timeouts by @kozlovic in #886. Issue reported by @yanyongcheng in #880
* Timer insertion by @kozlovic in #883. Issue reported by @yanyongcheng in #881


### Fixed
* EventLoop:
  * Handling of possible failure on initial attach by @kozlovic in #918
  * LibEvent: `natsConnection_Close()` not closing the TCP connection by @kozlovic in #882. Issue was reported by @yanyongcheng in #879
  * Libuv: Possible crash if connection is destroyed while receiving data by @kozlovic in #889. Issue was reported by @yanyongcheng in #888  
* KeyValue
  * Keys, History or watcher's next may incorrectly return `NATS_TIMEOUT` by @kozlovic in #917/ Issue was reported by @ArashPartow in #916
* MicroServices:
  * Wrong marshaling of `average_processing_time` by @kozlovic in #892. Issue was reported by @Archie3d in #890
  * Statistics error was always incremented by @kozlovic in #894. Issue was reported by @Archie3d in #893
* TLS
  * Unknown type name `SSL_verify_cb` by @kozlovic in #878. Issue was reported by @philipfoulkes in #877
  * Initialization and cleanup code related to OpenSSL was removed since it was deprecated for versions post OpenSSL 1.1. A cleanup function pertinent to 1.1+ code was possibly causing a problem. By @kozlovic in #905. Issue was reported by @vdeters in #904
  * Possible hang during handshake by @kozlovic in #907. Issue was reported by @etrochim in #906
  * Protect calls to `SSL_read` and `SSL_write` with a mutex. Since the same `SSL` object is shared between different threads, the OpenSSL library requires a mutex to be used by @kozlovic in #913
* Memory allocation check by @wooffie in #868
* Add missing status text string by @oldnick85 in #872 and @kozlovic in #874 (the issue was not present in any published release and was introduced in #869)
* Parsing of message headers with `NULL` or all-whitespace values by @habbbe in #873
* Removed some unused code related to handling of responses and added custom inbox with very long prefix test by @kozlovic in #885. Issue was reported by @yanyongcheng in #884
* Connection drain could cause missed reply and/or a 100ms delay by @kozlovic in #915. Issue was reported by @T-Maxxx in #911


### Non-code changes
* Build
  * Deprecated Ubuntu 20.04 in GitHub actions by @levb in #864
  * Removed the older compiler jobs by @levb in #865
  * Fixed Windows build to use the NATS Server main branch by @levb in #866


### New Contributors
* @kerbert101 made their first contribution in #862
* @habbbe made their first contribution in #873
* @wolfkor made their first contribution in #871
* @Matus-p made their first contribution in #901

---

### `v3.10.1` — v3.10.1 — published 2025-03-14

https://github.com/nats-io/nats.c/releases/tag/v3.10.1

## Fixed
- #857 a build issue caused by the introduction of natsOptions_SetSSLVerificationCallback, now marked as experimental.

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.10.0...v3.10.1

---

### `v3.10.0` — v3.10.0 — published 2025-02-28

https://github.com/nats-io/nats.c/releases/tag/v3.10.0

## Added
* Added UpdatesOnly to kwWatchOptions by @levb in https://github.com/nats-io/nats.c/pull/818
* Add SSL cert validation callback by @ckasabula in https://github.com/nats-io/nats.c/pull/826
* [ADDED] natsConnection_ReadLastError replaces natsConnection_GetLastE… by @levb in https://github.com/nats-io/nats.c/pull/846

## Fixed
* [FIXED] EventLoop: Socket now closed only after event loop done polling by @kozlovic in https://github.com/nats-io/nats.c/pull/815
* [FIXED] microservice cleanup (flapping MicroServiceStops... tests) by @levb in https://github.com/nats-io/nats.c/pull/816
* [NIT] removed line-trailing whitespace in the code by @levb in https://github.com/nats-io/nats.c/pull/817
* [FIXED] Examples: Add missing 'stream' and 'durable' params in usage by @kozlovic in https://github.com/nats-io/nats.c/pull/821
* Fixed JetStreamBackOffRedeliveries test by @kozlovic in https://github.com/nats-io/nats.c/pull/822
* [FIXED] build error (#819) by @oldnick85 in https://github.com/nats-io/nats.c/pull/820
* [FIXED] Build: failure with mingw by @kozlovic in https://github.com/nats-io/nats.c/pull/828
* [FIXED] microService_AddEndpoint() could crash if subject is invalid by @kozlovic in https://github.com/nats-io/nats.c/pull/831
* [FIXED] C++ compiler errors by @mtmk in https://github.com/nats-io/nats.c/pull/832
* [FIXED] Build: failure with Android NDK by @mtmk in https://github.com/nats-io/nats.c/pull/830
* [FIXED] GH-823 deadlock in js_MaybeFetchMore by @levb in https://github.com/nats-io/nats.c/pull/834
* [FIXED] Default statistics handler of microservice had unnecessary check by @kozlovic in https://github.com/nats-io/nats.c/pull/837
* [FIXED] Added missing `NATS_EXTERN` on some functions. by @kozlovic in https://github.com/nats-io/nats.c/pull/836
* fix: some nulls checks by @wooffie in https://github.com/nats-io/nats.c/pull/840
* fix: double free and deref after free in js.c by @wooffie in https://github.com/nats-io/nats.c/pull/839
* fix: typo in clear routine by @wooffie in https://github.com/nats-io/nats.c/pull/842
* fix: better cleanup if js clone config fails by @wooffie in https://github.com/nats-io/nats.c/pull/844
* Fix possible null deref in pub by @wooffie in https://github.com/nats-io/nats.c/pull/848
* fix: srvpool typo by @wooffie in https://github.com/nats-io/nats.c/pull/849

## Non-code changes
* Generate cnats-config-version.cmake by @rolflussi in https://github.com/nats-io/nats.c/pull/813
* Removed [EXPERIMENTAL] from KV API by @levb in https://github.com/nats-io/nats.c/pull/838
* Removed all remaining EXPERIMENTAL (micro)services documentation references by @levb in https://github.com/nats-io/nats.c/pull/847

## New Contributors
* @rolflussi made their first contribution in https://github.com/nats-io/nats.c/pull/813
* @oldnick85 made their first contribution in https://github.com/nats-io/nats.c/pull/820
* @ckasabula made their first contribution in https://github.com/nats-io/nats.c/pull/826
* @wooffie made their first contribution in https://github.com/nats-io/nats.c/pull/840

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.9.0...v3.10

---

### `v3.9.3` — v3.9.3 — published 2025-02-28

https://github.com/nats-io/nats.c/releases/tag/v3.9.3

## Fixed:

- microService_AddEndpoint() could crash if subject is invalid #831 
- deadlock in js_MaybeFetchMore #834
- double free and deref after free in js.c#839
- some nulls checks #840
- typo in clear routine #842
- better cleanup if js clone config fails #844
- possible null deref #848
- srvpool typo #849

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.9.2...v3.9.3

---

### `v3.9.2` — v3.9.2 — published 2024-12-09

https://github.com/nats-io/nats.c/releases/tag/v3.9.2

## Fixed
- EventLoop: Socket now closed only after event loop done polling #815
- microservice cleanup (flapping MicroServiceStops... tests) #816
- removed line-trailing whitespace in the code #817
- Examples: Add missing 'stream' and 'durable' params in usage #821
- JetStreamBackOffRedeliveries test #822

## Build
- Generate cnats-config-version.cmake #813
- build error #820

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.9.1...v3.9.2

---

### `v3.9.1` — Release v3.9.1 — published 2024-10-02

https://github.com/nats-io/nats.c/releases/tag/v3.9.1

## What's Changed
* Fixed the version string to remove `-beta`

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.9.0...v3.9.1

---

### `v3.9.0` — v3.9.0 — published 2024-10-01

https://github.com/nats-io/nats.c/releases/tag/v3.9.0

## Added
* `js_PauseConsumer` support (also changed jsConsumerConfig, jsCo… by @levb in https://github.com/nats-io/nats.c/pull/726
* Expose `MaxPendingBytes` on the `natsOptions` by @LaurensVergote in https://github.com/nats-io/nats.c/pull/700
* `kvStore_WatchMulti`, `js_Subscribe[Sync]Multi` by @levb in https://github.com/nats-io/nats.c/pull/750
* `natsConnection_Reconnect` by @levb in https://github.com/nats-io/nats.c/pull/757
* Support %-encoded username/password in server URLs by @levb in https://github.com/nats-io/nats.c/pull/765
* Support linking with MinGW toolchains on Linux by @XJ-0461 in https://github.com/nats-io/nats.c/pull/763
* TLS: `natsOptions_TLSHandshakeFirst()` by @kozlovic in https://github.com/nats-io/nats.c/pull/780
* Adding SNI extension if available by @thierryba in https://github.com/nats-io/nats.c/pull/787
* Add filtering to KV method returning all keys by @saurabhojha in https://github.com/nats-io/nats.c/pull/797
* `js_PullSubscribeAsync` by @levb in https://github.com/nats-io/nats.c/pull/785
* [BREAKING] Services: queue group now configurable and can be disabled by @levb in https://github.com/nats-io/nats.c/pull/800
* `nats_GetJWTOrSeed` to understand Windows \r\n lines by @levb in https://github.com/nats-io/nats.c/pull/801

## Fixed
* Moved micro_args to examples by @levb in https://github.com/nats-io/nats.c/pull/731
* Modify JetStream examples (Add comments to SubjectsLen) by @pch-blog in https://github.com/nats-io/nats.c/pull/734
* Build: issue on Android with `NATS_EXTRA_LIB` by @kozlovic in https://github.com/nats-io/nats.c/pull/739
* GH-738, do not prefix endpoint name with the group prefix by @levb in https://github.com/nats-io/nats.c/pull/741
* GH-736: added extern to micro_Errors by @levb in https://github.com/nats-io/nats.c/pull/743
* Fix heap buffer overflow in _fetch by @tyler92 in https://github.com/nats-io/nats.c/pull/749
* Improve Windows build support by @mtmk in https://github.com/nats-io/nats.c/pull/760
* refactored nats.c, prep for `js_PullSubscribeAsync` by @levb in https://github.com/nats-io/nats.c/pull/778
* Fixing setting handshake_first without setting secure in the natsOptions by @thierryba in https://github.com/nats-io/nats.c/pull/789

## Non-code changes
* [ADDED] GitHub action to update docs by @levb in https://github.com/nats-io/nats.c/pull/720
* [FIXED] doxygen GH action skip ci, include release_* by @levb in https://github.com/nats-io/nats.c/pull/725
* [FIXED] More fixes for doxygen autoupdate by @levb in https://github.com/nats-io/nats.c/pull/729
* [FIXED] flapping test: Test_KeyValueMirrorCrossDomains by @levb in https://github.com/nats-io/nats.c/pull/747
* [ADDED] Build with GitHub actions by @levb in https://github.com/nats-io/nats.c/pull/748
* [CI only]: Nightly test server main, latest release by @levb in https://github.com/nats-io/nats.c/pull/751
* [TEST only] increased Test_KeyValueMirrorCrossDomains timeout value by @levb in https://github.com/nats-io/nats.c/pull/753
* [CI only] Adjusted coverage targets/thresholds by @levb in https://github.com/nats-io/nats.c/pull/752
* [CI only] run tests once, not x3 except for main, release by @levb in https://github.com/nats-io/nats.c/pull/759
* [TEST ONLY] Fixed Test_JetStreamSubscribeIdleHeartbeat by @levb in https://github.com/nats-io/nats.c/pull/764
* [CI only] Skip codecov for forks until they resolve tokenless uploads… by @levb in https://github.com/nats-io/nats.c/pull/768
* [FIXED] cleaning up sanitize=thread found several races by @levb in https://github.com/nats-io/nats.c/pull/771
* benchmark for SubscribeAsync by @levb in https://github.com/nats-io/nats.c/pull/774
* Fixed test_JetStreamInfoAlternates flapper by @kozlovic in https://github.com/nats-io/nats.c/pull/775
* [CHANGED] sub benchmark tuned by @levb in https://github.com/nats-io/nats.c/pull/777
* Fixed flappers and test_SSLHandshakeFirst by skipping if server is < 2.10.0 by @kozlovic in https://github.com/nats-io/nats.c/pull/784
* Fixed test SSLVerifyHostName when build NATS_FORCE_HOST_VERIFICATION=OFF by @kozlovic in https://github.com/nats-io/nats.c/pull/788
* nats.c is available on conan.io/center by @mathi-m in https://github.com/nats-io/nats.c/pull/791
* [TEST ONLY] test fixes for 2.11 server changes by @levb in https://github.com/nats-io/nats.c/pull/798

## New Contributors
* @github-actions made their first contribution in https://github.com/nats-io/nats.c/pull/732
* @pch-blog made their first contribution in https://github.com/nats-io/nats.c/pull/734
* @LaurensVergote made their first contribution in https://github.com/nats-io/nats.c/pull/700
* @mtmk made their first contribution in https://github.com/nats-io/nats.c/pull/760
* @XJ-0461 made their first contribution in https://github.com/nats-io/nats.c/pull/763
* @thierryba made their first contribution in https://github.com/nats-io/nats.c/pull/787
* @mathi-m made their first contribution in https://github.com/nats-io/nats.c/pull/791
* @saurabhojha made their first contribution in https://github.com/nats-io/nats.c/pull/797

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.8.0...v3.9.0

---

### `v3.8.3` — Release v3.8.3 — published 2024-10-01

https://github.com/nats-io/nats.c/releases/tag/v3.8.3

## Changes
- Fix heap buffer overflow in _fetch #749
- Changed "Ws2_32" to "ws2_32" for MinGW compatibility with no adverse e…#763
- Changed `nats_GetJWTOrSeed` to understand Windows \r\n lines #801

## Test-only changes
- Fixed flapping test: Test_KeyValueMirrorCrossDomains #747
- Increased Test_KeyValueMirrorCrossDomains timeout value #753 
- Fixed Test_JetStreamSubscribeIdleHeartbeat #764
- Test fixes for 2.11 server changes #798

**Full Changelog**: https://github.com/nats-io/nats.c/compare/v3.8.2...v3.8.3

---

## Open issues at 2026-09-04 (29) — number, opened, title

- #1007 — 2026-08-05 — libuv adapter: parser not destroyed on disconnect
- #1005 — 2026-08-05 — libuv adapter: crash after silent-failure disconnect
- #941 — 2025-11-26 — TLS: OCSP stapling support
- #843 — 2025-02-19 — natsStatus s = natsConnection_Subscribe() handler calling two times on single message
- #795 — 2024-09-04 — Errno Variable getting set after calling js_PullSubscribe method from nats.c client
- #761 — 2024-06-06 — nats c client hanging forever on natsConnection_PublishString
- #737 — 2024-03-22 — microEndpoint in microErrorHandler doesn't seem useful
- #735 — 2024-03-20 — callbacks on natsConnection are called after natsConnection_destroy
- #723 — 2024-03-10 — natsOptions_SetTimeout() not being respected under certain conditions
- #716 — 2024-02-16 — auth callout
- #712 — 2024-01-19 — single-threaded mode?
- #698 — 2023-11-20 — Ability to use async functions in the microservices
- #695 — 2023-11-15 — segfault when calling js_Subscribe for an ephemeral subscription
- #690 — 2023-10-26 — Subscription Data Disorder Problem
- #674 — 2023-07-12 — Test flappers
- #661 — 2023-06-05 — Support core affinity for subscription threads
- #646 — 2023-04-03 — Alternative TLS implementation using WinAPI Schannel
- #574 — 2022-08-15 — Compile Using MinGW-w64 w/ pthreads
- #540 — 2022-05-11 — WebTransport support
- #539 — 2022-05-06 — Meson WrapDB package
- #449 — 2021-08-04 — The async for natsConnection_RequestString
- #428 — 2021-06-04 — Does anyone ran nats.c on mips64 architecture? Did you faced any issue?
- #391 — 2020-12-24 — Question: immediately finish requests on disconnect
- #278 — 2019-10-24 — Setup windows CI builds
- #261 — 2019-08-19 — C++ wrapper and mock for gtest
- #221 — 2019-05-22 — Run a fuzzer on the NATS parser code
- #216 — 2019-05-22 — No visibility attributes on functions
- #181 — 2018-09-24 — Is it possible to get statistics of channel message log?
- #152 — 2018-07-28 — To subscribe to multiple subjects in one subscription
