<!-- source: https://github.com/nats-io/nats.zig through the GitHub REST API (`gh api repos/nats-io/nats.zig/releases?per_page=10` and `gh api repos/nats-io/nats.zig/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.zig — the last 1 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v0.1.0` — nats.zig v0.1.0 — published 2026-04-28

https://github.com/nats-io/nats.zig/releases/tag/v0.1.0

Initial release of `nats.zig`, the official NATS client library for Zig 0.16.0.

  This release provides a pure Zig implementation built on `std.Io`, with support for Core NATS, JetStream,
  Key-Value, and Micro services.

  ## Highlights

  - Pure Zig implementation with no external C dependencies
  - Core NATS pub/sub, request/reply, headers, wildcard subjects, and queue groups
  - TLS 1.2/1.3 support via `std.crypto.tls`
  - NKey/JWT authentication via `std.crypto.sign.Ed25519`
  - Reconnection with backoff and connection event notifications
  - Callback-based and polling-style message dispatch
  - JetStream stream and consumer management
  - Sync and async JetStream publish with acknowledgements
  - Pull, push, and ordered JetStream consumers
  - JetStream message operations and ack protocol support
  - Key-Value bucket management, CRUD, optimistic concurrency, watches, key listing, and purge deletes
  - NATS Micro service API support
  - Examples, NATS by Example docs, and integration test coverage

  ## Installation

  ```sh
  zig fetch --save https://github.com/nats-io/nats.zig/archive/refs/tags/v0.1.0.tar.gz

  ## Validation

  This release was verified with:

  - zig build fmt-check
  - zig build
  - zig build test
  - zig build test-integration-tls
  - zig build test-integration
  - zig build test-integration -Doptimize=ReleaseFast

  ## Notes

  Object Store support is not included in this initial release.

  As this is a 0.x release, the public API may still evolve before 1.0.

---

## Open issues at 2026-09-04 (2) — number, opened, title

- #15 — 2026-07-19 — Busy wait burning CPU + memory usage unreasonable
- #14 — 2026-06-17 — Failed to cross compile target mipsel-linux-musleabi
