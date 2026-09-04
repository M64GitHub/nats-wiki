<!-- source: https://github.com/nats-io/nats.ex through the GitHub REST API (`gh api repos/nats-io/nats.ex/releases?per_page=10` and `gh api repos/nats-io/nats.ex/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.ex — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v1.16.0` — 1.16.0 — published 2026-07-10

https://github.com/nats-io/nats.ex/releases/tag/v1.16.0

## What's Changed
* Add client name to NATS CONNECT settings by @ahamez in https://github.com/nats-io/nats.ex/pull/227

## New Contributors
* @ahamez made their first contribution in https://github.com/nats-io/nats.ex/pull/227

**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.15.2...v1.16.0

---

### `v1.15.2` — 1.15.2 — published 2026-07-01

https://github.com/nats-io/nats.ex/releases/tag/v1.15.2

## What's Changed
* refacotr(headers): gets rid of cowlib dep by @tank-bohr in https://github.com/nats-io/nats.ex/pull/226

## New Contributors
* @tank-bohr made their first contribution in https://github.com/nats-io/nats.ex/pull/226

**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.15.1...v1.15.2

---

### `v1.15.1` — 1.15.1 — published 2026-05-28

https://github.com/nats-io/nats.ex/releases/tag/v1.15.1

## What's Changed
* Fix large payload parsing performance by @cbecker in https://github.com/nats-io/nats.ex/pull/225

## New Contributors
* @cbecker made their first contribution in https://github.com/nats-io/nats.ex/pull/225

**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.15.0...v1.15.1

---

### `v1.15.0` — 1.15.0 — published 2026-05-20

https://github.com/nats-io/nats.ex/releases/tag/v1.15.0

## What's Changed
* add heartbeat checks by @mmmries in https://github.com/nats-io/nats.ex/pull/224

**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.14.1...v1.15.0

---

### `v1.14.1` — 1.14.1 — published 2026-05-10

https://github.com/nats-io/nats.ex/releases/tag/v1.14.1

## What's Changed
* use server defaults and omit any non-user-specified options by @mmmries in https://github.com/nats-io/nats.ex/pull/223


**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.14.0...v1.14.1

---

### `v1.14.0` — 1.14.0 — published 2026-04-23

https://github.com/nats-io/nats.ex/releases/tag/v1.14.0

## What's Changed

* Add `PullConsumer.handle_connected/2` optional callback to get consumer info
* Add `PullConsumer.handle_status/2` optional callback to observe status messages
* Added support for `batch_size` option in PullConsumer options to pull messages
  and acknowledge them in batches.
* Add `Gnat.Jetstream.API.KV.Entry` with `from_message/2` for parsing a raw
  NATS message from a KV bucket's underlying stream into a structured entry
  (operation, key, value, revision, created, delta). Intended to be shared
  between the built-in `KV.Watcher` and user-supplied `PullConsumer`
  implementations (e.g. caches that need to detect when they are caught up
  with the stream). Returns `:ignore` for messages that are not KV records.
* `KV.Watcher` now uses `KV.Entry` internally; its public callback API is
  unchanged. The push consumer it creates now enables server-driven flow
  control and a 5s idle heartbeat (matching nats.go's ordered-consumer
  defaults), so slow handlers apply backpressure instead of being dropped
  as slow consumers.
* **Behavior change (bugfix):** `PullConsumer` no longer forwards JetStream
  informational status messages (e.g. `100` idle heartbeat, `409` leadership
  change) to `c:handle_message/2`. These are not stream records and cannot
  be acked. In single-message mode the consumer now drops them and re-issues
  a pull request.
* Add an optional `c:handle_status/2` callback to `Gnat.Jetstream.PullConsumer`
  for users who want to observe status messages (e.g. log on `409`).


**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.13.1...v1.14.0

---

### `v1.13.1` — 1.13.1 — published 2026-03-20

https://github.com/nats-io/nats.ex/releases/tag/v1.13.1

## What's Changed
* Use flow_control for Object.get by @ppkn in https://github.com/nats-io/nats.ex/pull/217

## New Contributors
* @ppkn made their first contribution in https://github.com/nats-io/nats.ex/pull/217

**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.13.0...v1.13.1

---

### `v1.13.0` — 1.13.0 — published 2026-01-13

https://github.com/nats-io/nats.ex/releases/tag/v1.13.0

## What's Changed
* Document the Pager module and add support for from_datetime by @mmmries in https://github.com/nats-io/nats.ex/pull/216


**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.12.1...v1.13.0

---

### `v1.12.1` — 1.12.1 — published 2025-11-26

https://github.com/nats-io/nats.ex/releases/tag/v1.12.1

## What's Changed
* add an Elixir 1.19 entry to the testing matrix by @mmmries in https://github.com/nats-io/nats.ex/pull/214
* Add notification based on SubjectDeleteMarkerTTL by @0xAX in https://github.com/nats-io/nats.ex/pull/215


**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.12.0...v1.12.1

---

### `v1.12.0` — 1.12.0 — published 2025-11-22

https://github.com/nats-io/nats.ex/releases/tag/v1.12.0

## What's Changed
* Fetch KV keys without the contents by @djcarpe in https://github.com/nats-io/nats.ex/pull/210
  * Also improves the performance of fetching contents
* Implement AllowMsgTTL and SubjectDeleteMarkerTTL by @0xAX in https://github.com/nats-io/nats.ex/pull/212


**Full Changelog**: https://github.com/nats-io/nats.ex/compare/v1.11.1...v1.12.0

---

## Open issues at 2026-09-04 (14) — number, opened, title

- #211 — 2025-11-19 — Support for jetstream publish confirmation
- #209 — 2025-11-12 — Broadway integration is documented but not present
- #178 — 2024-10-30 — Nack with delay support?
- #173 — 2024-10-08 — Support using JWT/nkey credentials from a creds file
- #172 — 2024-09-18 — Support pagination for KV and Object `list_bucket`
- #171 — 2024-09-16 — Support the ability to seal an Object bucket
- #170 — 2024-09-15 — Add Gnat.Jetstream.API.Object.Watcher
- #166 — 2024-07-25 — Guard against nil publishes
- #160 — 2024-05-28 — Connection credential is printed out in error log
- #158 — 2024-04-24 — Add support for new consumer attributes
- #131 — 2022-09-29 — Make inbox optional
- #126 — 2022-06-09 — Validate the port number on connection settings
- #62 — 2017-07-18 — Investigate other patterns for resilient consumers/connections
- #58 — 2017-07-02 — Validate that queue_group is specified as a valid iolist entry
