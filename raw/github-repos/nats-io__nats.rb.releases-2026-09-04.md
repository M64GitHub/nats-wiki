<!-- source: https://github.com/nats-io/nats.rb through the GitHub REST API (`gh api repos/nats-io/nats.rb/releases?per_page=10` and `gh api repos/nats-io/nats.rb/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats.rb — the last 9 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v0.11.0` — Release v0.11.0 — published 2019-06-11

https://github.com/nats-io/nats.rb/releases/tag/v0.11.0

Release with support for [NATS v2 auth features](https://nats-io.github.io/docs/whats_new/whats_new_20.html)

## Added

- Support for user credentials that contain a JWT/NKEY to auth against NATS v2 servers

```ruby
require 'nats/client'

NATS.start("tls://connect.ngs.global", user_credentials: "/path/to/creds") do |nc|
  nc.subscribe("hello") do |msg|
    puts "[Received] #{msg}"
  end
  nc.publish('hello', 'world')
end
```

- Support to authenticate against NATS v2 servers that use NKEYS

```ruby
require 'nats/client'

NATS.start("tls://connect.ngs.global", nkeys_seed: "path/to/seed.txt") do |nc|
  nc.subscribe("hello") do |msg|
    puts "[Received] #{msg}"
  end
  nc.publish('hello', 'world')
end
```

- Added `--creds` option to `nats-pub`, `nats-sub`, `nats-queue` tools

## Changed

- Internal changes to process initial INFO message from the server

## Fixed

- Fixed being able to use 'tls' as the scheme when connecting with a single URL

  ```ruby
  NATS.connect("tls://demo.nats.io:4443")
  ```

---

### `v0.10.0` — Release v0.10.0 — published 2018-08-31

https://github.com/nats-io/nats.rb/releases/tag/v0.10.0

### Added

- Support for `drain mode` (https://github.com/nats-io/ruby-nats/pull/157)

  This feature allows clients to gracefully disconect, letting the subscribers
  handle any inflight messages that may have been sent by the server already.

  ```ruby
  NATS.start(drain_timeout: 1) do |nc|
    NATS.subscribe('foo', queue: "workers") do |msg, reply, sub|
      nc.publish(reply, "ACK:#{msg}")
    end

    NATS.subscribe('bar', queue: "workers") do |msg, reply, sub|
      nc.publish(reply, "ACK:#{msg}")
    end

    NATS.subscribe('quux', queue: "workers") do |msg, reply, sub|
      nc.publish(reply, "ACK:#{msg}")
    end

    EM.add_timer(2) do
      next if NATS.draining?

      # Drain gracefully closes the connection.
      NATS.drain do
        puts "Done draining. Connection is closed."
      end
    end
  end
  ```

- Support for `no_echo` mode (https://github.com/nats-io/ruby-nats/pull/155)

  When connected to a NATS Server v1.2.0 or above, a client can now opt to avoid
  receiving messages that it itself has published.

  ```ruby
  NATS.connect(no_echo: true)
  ```

### Improved

- `NATS.connect` API is now more similar to how it works in the Go client (https://github.com/nats-io/ruby-nats/pull/156):

  ```ruby
  # Assume 'nats://' scheme
  NATS.connect("demo.nats.io:4222")

  # Complete with scheme a la Go client classic usage.
  NATS.connect("nats://demo.nats.io:4222")

  # Use default 4222 port.
  NATS.connect("demo.nats.io")

  # Explicit cluster list still supported
  NATS.connect(servers: ["nats://demo.nats.io:4222"])
  ```

### Fixed

- Client now supports token based authorization

  ```ruby
  NATS.connect(token: "deadbeef")

  NATS.connect(uri: "nats://deadbeef@127.0.0.1:4222")

  NATS.connect("nats://deadbeef@127.0.0.1:4222")
  ```

### Deprecated

- Removed Ruby 2.2 from build since [no longer supported](https://www.ruby-lang.org/en/news/2018/06/20/support-of-ruby-2-2-has-ended/)

---

### `v0.9.2` — Release v0.9.2 — published 2018-07-27

https://github.com/nats-io/nats.rb/releases/tag/v0.9.2

Minor version release including fixes to support multiple CAs when using secure connections.  

### Fixed

TLS Peer verification: `ssl_verify_peer` does not support multiple CAs 

https://github.com/nats-io/ruby-nats/issues/151  Thanks to @h4xnoodle  @pivotal-jamil-shamy for the contribution.

---

### `v0.9.0` — Release v0.9.0 — published 2018-06-27

https://github.com/nats-io/nats.rb/releases/tag/v0.9.0

### Added

- Support new style request/response using Fibers (https://github.com/nats-io/ruby-nats/pull/149)

### Changed

- Inboxes are now NUID based (https://github.com/nats-io/ruby-nats/pull/149/commits/8ced98d40ee698dd8cbb69b9d502902b9591809c)

---

### `v0.8.4` — Release v0.8.4 — published 2018-02-23

https://github.com/nats-io/nats.rb/releases/tag/v0.8.4

### Added

- Support to include connection `name` as part of CONNECT options (https://github.com/nats-io/ruby-nats/pull/145)

### Fixed

- Fixed support for Ruby 2.5 due to missing OpenSSL `require` (https://github.com/nats-io/ruby-nats/pull/144)

### Removed

- nats-top script not distributed with the gem now
  (use Go version at https://github.com/nats-io/nats-top )

---

### `v0.8.2` — v0.8.2 — published 2017-03-14

https://github.com/nats-io/nats.rb/releases/tag/v0.8.2

- Allow setting name from client on connect (#129)
- Add discovered servers helper for servers announced via async INFO (#136)
- Add time based reconnect backoff (#139)
- Modify lang sent on connect when using jruby (#135)
- Update eventmachine dependencies (#134)

---

### `v0.8.0` —  — published 2016-08-11

https://github.com/nats-io/nats.rb/releases/tag/v0.8.0

- Added cluster auto discovery handling which is supported on v0.9.2 server release (#125)
- Added jruby part of the build (both in openjdk and oraclejdk runtimes) (#122 #123)
- Fixed ping interval accounting (#120)

---

### `v0.7.1` —  — published 2016-07-08

https://github.com/nats-io/nats.rb/releases/tag/v0.7.1

Minor release which changes nats client dependencies so that only Eventmachine > 1.2 is required

---

### `v0.7.0` —  — published 2016-07-08

https://github.com/nats-io/nats.rb/releases/tag/v0.7.0

- Eventmachine bumped to 1.2 series
- Upgraded TLS support, certs and verify peer functionality

---

## Open issues at 2026-09-04 (3) — number, opened, title

- #169 — 2020-02-05 — does not resend auto unsubscribe with updated value
- #167 — 2020-01-27 — Fix IPv6 address being sent to `gethostname` still containing []'s
- #164 — 2019-07-16 — TLS connection error `oversize record received`
