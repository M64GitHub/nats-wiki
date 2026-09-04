<!-- source: https://github.com/nats-io/nats.py through the GitHub REST API (`gh api repos/nats-io/nats.py/releases?per_page=10` and `gh api repos/nats-io/nats.py/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.py — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v2.15.0` — Release v2.15.0 — published 2026-06-05

https://github.com/nats-io/nats.py/releases/tag/v2.15.0

Minor release of the `nats-py` client.

```
pip install nats-py
```

## Added
- Lame duck mode handling for graceful reconnection (#869)
- `rtt` method to `Client` for measuring round-trip time (#858)
- `client_ip` property to `Client` (#861)
- `consumer_limits` support to `StreamConfig` (#780)
- `first_seq` support to `StreamConfig` (#779)
- `limit_marker_ttl` support for KV watchers (#911)
- `updates_only` mode to object store watch (#666)
- Stream created datetime to `StreamInfo` (#772)
- JetStream direct get timestamp parsing (#810)
- Send `auth_token` alongside nkey/JWT in `CONNECT` (#900)

## Changed
- Replace `email.parser` path in `_process_headers` with a byte-level parser (#928)
- Restrict `msg_ttl` to the create and purge key-value operations (#834)
- Validate stream and consumer names before API requests (#890)
- Avoid `$JS.API.STREAM.NAMES` call since the stream name is known (#807)
- Use a string default in `connect()` to avoid a mutable default argument (#884)
- Replace deprecated `asyncio.iscoroutinefunction` (#932)
- Migrate the build from setuptools to `uv_build` (#813)
- Include the `LICENSE` file in the nats-py sdist (#840)

## Fixed
- Avoid hang when `KeyWatcher.stop()` runs on a full queue (#899)
- Fix `PullSubscription.fetch` hang due to an orphan lingering request (#934)
- Fix flush hanging when internal tasks are cancelled externally (#853)
- Avoid cancelling the current task on close (#841)
- Guard `close()` against a `None` `_io_reader` (#839)
- Fix dropped message when cancelling the subscription messages iterator (#804)
- Handle CAS error code 10164 in KV update (#883)
- Strip whitespace from nkeys seed input (#882)
- Disable WebSocket max message size (#855)
- Handle non-binary WebSocket frame types (#893)
- Normalize ISO timestamp fractional seconds to 6 digits for Python <3.11 (#796)
- Fix error in UTC to ISO conversion (#846)

**Full Changelog**: https://github.com/nats-io/nats.py/compare/v2.14.0...v2.15.0

---

### `nats-jetstream/v0.3.0` — nats-jetstream/v0.3.0 — published 2026-05-10

https://github.com/nats-io/nats.py/releases/tag/nats-jetstream/v0.3.0

# 0.3.0

### Added

- Atomic batch publishing — `allow_atomic`/`allow_batched` on `StreamConfig`, `Nats-Batch-*` header constants, and `batch_id`/`batch_size` on `PublishAck` (ADR-50, #922)
- Message schedules — `allow_msg_schedules` on `StreamConfig` and `Nats-Schedule-*` header constants (ADR-51, #923)
- Counter streams — `allow_msg_counter` on `StreamConfig` and `value` on `PublishAck` (ADR-49, #926)
- Stream sourcing with pre-created push-durable consumers — `StreamConsumerSource` on `StreamSource` (ADR-60, #921)
- `Stream.reset_consumer()` for the `$JS.API.CONSUMER.RESET` endpoint, plus `ConsumerReset` and `ConsumerInvalidResetError` (#920)
- `persist_mode` on `StreamConfig` for R1 async persistence (ADR-56, #929)
- Re-export of `new` from `nats.jetstream` (#880)

### Fixed

- `Stream.get_message()` now raises `MessageNotFoundError` on a 404 from the direct-get path instead of leaking the underlying status error (#881)

---

### `nats-key-value/v0.1.0` — nats-key-value/v0.1.0 — published 2026-05-08

https://github.com/nats-io/nats.py/releases/tag/nats-key-value/v0.1.0

Initial release of `nats-key-value`, a Python client for the NATS Key-Value
store, built on `nats-jetstream`.

### Features

- **Buckets** - Create, update, and delete key-value buckets
- **Keys** - Put, get, create, update, delete, and purge values
- **Optimistic concurrency** - Compare-and-swap updates via revision numbers
- **History** - Per-key revision history
- **TTL** - Per-key time-to-live
- **Watches** - Subscribe to changes with key pattern filters
- **Listing** - Enumerate keys and inspect bucket statuses

### Requirements

- Python 3.13+
- NATS server with JetStream enabled

### Installation

```bash
pip install nats-key-value
```

### Quick Start

```python
import asyncio
from nats.client import connect
from nats.jetstream import new as new_jetstream
from nats.key_value import KeyValueConfig, create_or_update_key_value

async def main():
    client = await connect("nats://localhost:4222")
    js = new_jetstream(client)

    kv = await create_or_update_key_value(js, KeyValueConfig(bucket="config"))

    await kv.put("greeting", b"Hello World!")

    entry = await kv.get("greeting")
    print(f"{entry.key} = {entry.value.decode()} (revision {entry.revision})")

    await kv.delete("greeting")

    await client.close()

if __name__ == "__main__":
    asyncio.run(main())
```

---

### `nats-jetstream/v0.2.0` — nats-jetstream/v0.2.0 — published 2026-04-14

https://github.com/nats-io/nats.py/releases/tag/nats-jetstream/v0.2.0

# 0.2.0

### Added

- Ordered consumers with automatic sequence tracking, gap detection, and consumer recovery (#832)
- `close()` and async context manager support on `Consumer` protocol (#872)
- `stop()` method on `MessageStream` protocol (#871)

### Changed

- `MessageBatch` and `MessageStream` protocols extend `AsyncIterable` (#866, #865)
- `Consumer.messages()` returns `MessageStream` instead of `AsyncIterator` (#864)
- `ConsumerConfig` timestamp fields (`opt_start_time`, `pause_until`) use `datetime` instead of raw values (#826)
- Build backend from setuptools to uv_build (#813)

---

### `nats-core/v0.2.0` — nats-core/v0.2.0 — published 2026-04-14

https://github.com/nats-io/nats.py/releases/tag/nats-core/v0.2.0

# 0.2.0

### Added

- `Client.rtt()` method to measure round-trip time to the server (#859)

### Changed

- Request/reply multiplexed over a single inbox subscription instead of creating a new subscription per request (#825)
- Build backend from setuptools to uv_build (#813)

### Fixed

- Various type annotation issues in client and protocol handling (#827)

---

### `v2.14.0` — Release v2.14.0 — published 2026-02-23

https://github.com/nats-io/nats.py/releases/tag/v2.14.0

## Overview

This release adds ability to [reconnect to a specific server](https://github.com/nats-io/nats-architecture-and-design/pull/388).

## Added
* Add server pool management and reconnect handler by @caspervonb in https://github.com/nats-io/nats.py/pull/829

## Fixed
* Fix flaky example tests by @caspervonb in https://github.com/nats-io/nats.py/pull/824
* Fix opt_start_time and other datetime fields by @caspervonb in https://github.com/nats-io/nats.py/pull/823
* Improve KeyValue and ObjectStore watchers: Fix watching past history replay by @fielding in https://github.com/nats-io/nats.py/pull/644


## New Contributors
* @fielding made their first contribution in https://github.com/nats-io/nats.py/pull/644

**Full Changelog**: https://github.com/nats-io/nats.py/compare/v2.13.1...v2.14.0

---

### `v2.13.1` — Release v2.13.1 — published 2026-02-05

https://github.com/nats-io/nats.py/releases/tag/v2.13.1

## Overview

A patch release that fixes broken cluster fields introduced in `2.13.0` (#818)

**Full Changelog**: https://github.com/nats-io/nats.py/compare/v2.13.0...v2.13.1

---

### `v2.13.0` — Release v2.13.0 — published 2026-02-04

https://github.com/nats-io/nats.py/releases/tag/v2.13.0

### Added

* Add token callback support [#812](https://github.com/nats-io/nats.py/pull/812)

  The `token` parameter on `connect` now accepts a callable that is invoked on
  each connection attempt, enabling dynamic token refresh on reconnect:

  ```python
  def get_token():
      return fetch_token_from_auth_service()

  nc = await nats.connect("nats://localhost:4222", token=get_token)
  ```

* Add per-message TTL support for KV operations [#783](https://github.com/nats-io/nats.py/pull/783)

  KV `create`, `delete`, and `purge` now accept a `msg_ttl` parameter
  (in seconds). Requires nats-server 2.11+.

  ```python
  kv = await js.create_key_value(bucket="SESSIONS")
  await kv.create("sess-123", b"user-data", msg_ttl=3600)
  await kv.delete("sess-123", msg_ttl=60)
  ```

* Add consumer-configured `inbox_prefix` for JetStream `pull_subscribe` methods [#781](https://github.com/nats-io/nats.py/pull/781)

  A custom `inbox_prefix` can be passed to `pull_subscribe` and
  `pull_subscribe_bind` to control the deliver subject prefix:

  ```python
  sub = await js.pull_subscribe("orders.>", "my-consumer", inbox_prefix=b"_CUSTOM_INBOX.")
  msgs = await sub.fetch(10)
  ```

* Add `persist_mode` to `StreamConfig` [#773](https://github.com/nats-io/nats.py/pull/773)
* Add `raft_group`, `leader_since`, and `traffic_acc` to `ClusterInfo` [#766](https://github.com/nats-io/nats.py/pull/766)

### Fixed

* Fix `StreamConfig` omitempty fields for nats-server > 2.12 [#788](https://github.com/nats-io/nats.py/pull/788)

---

### `nats-core/v0.1.0` — nats-core/v0.1.0 — published 2025-12-19

https://github.com/nats-io/nats.py/releases/tag/nats-core/v0.1.0

Initial release of `nats-core`, a lean and fast Python client for the NATS messaging system.

### Features

- **Publish/Subscribe** - Core pub/sub messaging with wildcard subscriptions
- **Request/Reply** - Synchronous request-response pattern with timeout support
- **Queue Groups** - Load balancing across subscribers
- **Message Headers** - Multi-value header support (NATS 2.2+)
- **Automatic Reconnection** - Configurable reconnect with backoff and jitter
- **TLS Support** - Secure connections with custom SSL contexts
- **Authentication** - Token, username/password, NKey, and JWT/credentials file support
- **Async Context Manager** - Clean resource management with `async with`
- **Connection Statistics** - Track messages/bytes sent and received
- **Slow Consumer Detection** - Configurable pending limits with callbacks

### Requirements

- Python 3.13+
- No required dependencies (optional `nkeys` for NKey authentication)

### Installation

```bash
# For now, this is standalone outside of the nats-py package.
pip install nats-core
```

### Quick Start

```python
import asyncio

from nats.client import connect

async def main():
    async with await connect("nats://localhost:4222") as client:
        sub = await client.subscribe("greet")
        await client.publish("greet", b"Hello, NATS!")
        msg = await sub.next()
        print(f"Received: {msg.data.decode()}")

asyncio.run(main())
```

### Performance

Performance is substantially improved compared to nats-py.

Benchmarks on Apple M3 Max (1M messages, publisher and subscriber in same process):

**Queue Mode (subscriber throughput):**

| Size | nats-core CPython | nats-core PyPy | nats-py CPython | nats-py PyPy |
|------|-------------------|----------------|-----------------|--------------|
| 8 B | 553,636 msg/s | 2,336,040 msg/s | 8,769 msg/s* | 8,755 msg/s* |
| 128 B | 418,524 msg/s | 1,402,979 msg/s | 8,758 msg/s* | 8,756 msg/s* |
| 1 KB | 338,365 msg/s | 493,128 msg/s | 2,232 msg/s* | 2,232 msg/s* |

\* nats-py dropped 47-87% of messages under load

Zero message loss with nats-core across all configurations.

---

### `v2.12.0` — Release v2.12.0 — published 2025-10-31

https://github.com/nats-io/nats.py/releases/tag/v2.12.0

### Added 

* Add options to send custom WebSocket headers on connect

    ```python
    custom_headers = {
        "Authorization": ["Bearer MySecretToken"],
        "X-Client-ID": ["my-client-123"],
        "Accept": ["application/json", "text/plain"]
    }
    
    nc = await nats.connect(
        "ws://localhost:4222",
        ws_connection_headers=custom_headers
    )
    ```

### Fixed

* Fix filter_subject overriding filter_subjects [#711](https://github.com/nats-io/nats.py/pull/711)
* Fix EOF processing while client is connecting [#719](https://github.com/nats-io/nats.py/pull/719)
* Fix error when closing ws transport
* Fix test_object_list [#728](https://github.com/nats-io/nats.py/pull/728)

### Improved

* Add consumer pause/resume support [#761](https://github.com/nats-io/nats.py/pull/761)
* Add `time` field to `RawStreamMsg`
* Add `allow_msg_schedules` to StreamConfig [#765](https://github.com/nats-io/nats.py/pull/765)
* Add per-message TTL support [#763](https://github.com/nats-io/nats.py/pull/763)
* Add allow_batch to StreamConfig [#764](https://github.com/nats-io/nats.py/pull/764)
* Add test for direct get returning no responders [#767](https://github.com/nats-io/nats.py/pull/767)

---

## Open issues at 2026-09-04 (53) — number, opened, title

- #1010 — 2026-08-26 — KV mutations ignore JetStream domain and publish to the local $KV subject
- #1006 — 2026-08-18 — Websocket URL Secrets in Cleartext in Logs
- #1000 — 2026-08-14 — Annotate connect timeout and reconnect wait as float
- #999 — 2026-08-10 — Signed CONNECT branch cannot send `pass` alongside `jwt`+`sig` (auth-callout credential)
- #997 — 2026-07-31 — Unreadable user credentials are retried instead of raising PermissionError
- #986 — 2026-07-06 — fetch() still stalls on an orphan lingering request in 2.15.0 (regression / incomplete fix for #933)
- #985 — 2026-06-28 — publish_async ack errors are swallowed (logged as "nats: encountered error") instead of being raised on the returned future
- #977 — 2026-06-16 — Unable to add metadata to a KeyValue bucket
- #962 — 2026-05-29 — Pull consumer message streams leak disconnect/reconnect callbacks (never deregistered on stop())
- #811 — 2026-01-26 — Atomic batch publish with `js.publish()` raises error
- #784 — 2025-11-13 — Missing support for jetstream consumer groups
- #778 — 2025-11-07 — deliver policy can not be updated after the container reconstructed
- #768 — 2025-10-29 — KeyValue.keys() with filters fetches all keys from server causing performance issues
- #735 — 2025-09-25 — Raise `MaxReconnectAttemptsExceededError`
- #718 — 2025-08-05 — Infinite Loop when trying to connect with wrong settings (e.g. TLS)
- #703 — 2025-06-13 — Get from Object Stores are extremely slow
- #700 — 2025-06-03 — Inconsistent behaviour when watching for KV updates
- #695 — 2025-05-20 — Add http_proxy support for websockets
- #676 — 2025-03-19 — Support JetStream pull-specific consumer configuration
- #667 — 2025-02-19 — nats aio client request using _request_new_style doesn't receive messages if it looses the  subscrption
- #663 — 2025-02-14 — Missing option to control initial connection behavior
- #643 — 2024-12-20 — Jetstream PullSubscription disconnects when reference is copied
- #639 — 2024-12-03 — JSONDecodeError after a valid JetStream publish() call
- #625 — 2024-10-28 — Docs site is missing a version or versions
- #603 — 2024-09-11 — JetStreamContext.subscribe() and JetStreamContext.pull_subscribe() ignore "durable_name" from ConsumerConfig when looking up for consumer info. 
- #580 — 2024-07-08 — Impossible to watch forever
- #668 — 2024-07-07 — Object Store times out (python SDK, CLI)
- #565 — 2024-06-07 — Nats object store image with header data
- #562 — 2024-05-31 — KV's `Entry.operation` should have a literal type
- #556 — 2024-05-07 — Bug in URL Normalization from List in client.py class
- #541 — 2024-02-27 — Using the async iterator is significantly slower compared to using callbacks in a subscription
- #538 — 2024-02-21 — Placement setting has no effect when creating a new key-value bucket
- #529 — 2024-02-09 — Message publish failure after reconnection
- #505 — 2023-10-10 — Key Value and Object store do not always work with mirrored streams
- #504 — 2023-10-09 — jestream pull_subscribe() not reconnecting after server reboot
- #501 — 2023-09-20 — BUG: NatsJS `subscribe` rewrites original `ConsumerConfig(filter_sibject=...)` option
- #472 — 2023-07-25 — Document KV and Watching keys
- #461 — 2023-06-19 — OutboundBufferLimitError exception on connection after `drain_timeout` passed
- #458 — 2023-06-09 — Fail to decode seed when it is decorated with `-----BEGIN USER PRIVATE KEY-----`
- #429 — 2023-02-25 — KeyValue watch with callback
- #413 — 2023-01-19 — Implement MaxBytes for pull requests
- #411 — 2023-01-18 — Implement Bind subscribe validation
- #408 — 2023-01-18 — Implement IgnoreDiscoveredURLs on reconnect option
- #398 — 2022-11-30 — KeyValue creation time not returned when using get method
- #392 — 2022-11-23 — js pull consumer lost messages
- #382 — 2022-11-11 — Client does not retry if TLS handshake fails
- #363 — 2022-10-05 — Implement Connection DisconnectedErr Callback
- #352 — 2022-09-16 — Reconnection logic should not apply for the first connection attempt
- #303 — 2022-04-27 — Micro optimization: Json encoding includes whitespace
- #300 — 2022-04-21 — unexpected EOF resulting in unable to reconnect
- #284 — 2022-03-03 — Initialize signature_cb when only user_jwt defined
- #204 — 2021-08-06 — Client stops trying to connect if `disconnected_cb` raises exception
- #193 — 2021-01-22 — Reconnect on nats-server when the JWT is expired
