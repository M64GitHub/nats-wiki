<!-- source: https://github.com/nats-io/nats-pure.rb through the GitHub REST API (`gh api repos/nats-io/nats-pure.rb/releases?per_page=10` and `gh api repos/nats-io/nats-pure.rb/issues?state=open --paginate`) · fetched 2026-09-04 · release bodies verbatim (CRLF normalised to LF); open issues as number, open date and title only, pull requests excluded -->
# nats-io/nats-pure.rb — the last 10 release bodies, and the open issues at 2026-09-04

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md` (*What bites you* on the client entities). The `learn/resilient-clients` chapter states each client's behaviour without a version; a client's own release notes are the only public record that dates it.

## Releases

### `v2.5.0` — Release v2.5.0 — published 2025-02-21

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.5.0

### Added

- Add Client#force_reconnect (#159)
- Implement Service API (#160)
- Implement KV watchers (#161)

```ruby
# Using a queue 
w = kv.watchall
entry = w.updates

# As Enumerables (requires at least Ruby 3.2)
entries = kv.watchall.take(10)

# Using a block
kv.watchall.each do |entry|
  puts "#{entry.key} -- #{entry.value}"   
end  

# Gather all keys
keys = kv.keys.to_a
puts keys
```

### Fixed

- Shutdown `subscription_executor` on close and reconnect (#155)

### Improved

- Support multi URI connection string with spaces after comma (#151)

---

### `v2.4.0` — Release v2.4.0 — published 2023-11-22

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.4.0

### Fixed

* Fixed loading Rails Engine by @palkan in (https://github.com/nats-io/nats-pure.rb/pull/132)
* Fixed crash when assigning URI port to default value by @cavalle in (https://github.com/nats-io/nats-pure.rb/pull/135)

### Added

* Add support for consumer multiple filters and streams/consumers metadata (https://github.com/nats-io/nats-pure.rb/pull/138)

```ruby
# Creating a stream with multiple subjects
js.add_stream(name: "MULTI_FILTER", subjects: ["foo.one.*", "foo.two.*", "foo.three.*"])

# PullSubscriber that takes an array and creates a consumer with multiple filters .
js.pull_subscribe(["foo.one.1", "foo.two.2"], "example")

# PushSubscriber that takes an array and creates a consumer with multiple filters .
js.subscribe(["foo.one.1", "foo.three.3"])

# via JetStream#add_consumer API
consumer = js.add_consumer("MULTI_FILTER", {
       name: "my-consumer",
       filter_subjects: ["foo.one.*", "foo.two.*"]
})

# Pass nil to both subject and durable consumer name to bind to already created consumer
js.pull_subscribe(nil, nil, name: "my-consumer", stream: "MULTI_FILTER")

# Stream with metadata
stream = js.add_stream({
    :name     => "WITH_METADATA",
    :metadata => {
      'foo': 'bar',
      'hello': 'world'
    }
})
```

**Full Changelog**: https://github.com/nats-io/nats-pure.rb/compare/v2.3.0...v2.4.0

---

### `v2.3.0` — Release v2.3.0 — published 2023-09-09

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.3.0

## What's Changed

* Update gemspec to automatically include .rb and .rbs files by @zaben903 in https://github.com/nats-io/nats-pure.rb/pull/95
* Fork detection and automatic reconnect in child process by @Envek in https://github.com/nats-io/nats-pure.rb/pull/114
* Reset stats and server_pool after_fork by @wallyqs in https://github.com/nats-io/nats-pure.rb/pull/118
* Delayed connection: allow to initialize client without connecting by @Envek in https://github.com/nats-io/nats-pure.rb/pull/116
* Handling subscription messages in a thread pool by @Envek in https://github.com/nats-io/nats-pure.rb/pull/117
* Show ellipsis when truncating data in message by @capps in https://github.com/nats-io/nats-pure.rb/pull/112
* Integrate with Rails Executor for subscription callbacks resource cleanup by @Envek in https://github.com/nats-io/nats-pure.rb/pull/120
* Include LICENSE and README into built gem package by @Envek in https://github.com/nats-io/nats-pure.rb/pull/126
* WebSocket feature by @Envek in https://github.com/nats-io/nats-pure.rb/pull/127
* Support connecting to NATS cluster over WebSocket by @Envek in https://github.com/nats-io/nats-pure.rb/pull/121
* Fix lazy connection after code reload in Rails by @Envek in https://github.com/nats-io/nats-pure.rb/pull/124

## New Contributors
* @Envek made their first contribution in https://github.com/nats-io/nats-pure.rb/pull/115
* @capps made their first contribution in https://github.com/nats-io/nats-pure.rb/pull/112
* @bruth made their first contribution in https://github.com/nats-io/nats-pure.rb/pull/130

**Full Changelog**: https://github.com/nats-io/nats-pure.rb/compare/v2.2.1...v2.3.0

---

### `v2.2.1` — Release v2.2.1 — published 2022-11-07

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.2.1

## What's Changed

* Added RBS definitions by @zaben903 in https://github.com/nats-io/nats-pure.rb/pull/82
* Added ability to edit an existing stream by @zaben903 in https://github.com/nats-io/nats-pure.rb/pull/83
* Split js.rb into smaller files to ease debugging and readability by @zaben903 in https://github.com/nats-io/nats-pure.rb/pull/80
* Fixed clustered example by @rodrigc in https://github.com/nats-io/nats-pure.rb/pull/90
* Fixed headers parser error when there were inline status and headers
* Fixed issue with activesupport ignoring `to_json` implementation
* Changed README example to clarify pull subscribe usage

**Full Changelog**: https://github.com/nats-io/nats-pure.rb/compare/v2.2.0...v2.2.1

---

### `v2.2.0` — Release v2.2.0 — published 2022-10-02

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.2.0

### Added

* Added client updates for NATS v2.9.0
* Added support for KeyValue direct mode and republish
* Added support to create consumers using `name`

**Full Changelog**: https://github.com/nats-io/nats-pure.rb/compare/v2.1.2...v2.2.0

---

### `v2.1.2` — Release v2.1.2 — published 2022-07-29

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.1.2

# Fixed

- Fixed being able to configure JetStream push consumers when created with susbcribe

```ruby
js.subscribe("custom", durable: 'example', config: { deliver_policy: 'new' })
```

# Added

- Updated JetStream StreamConfig and UpdatedConfig types to have more parity with latest version of the server

---

### `v2.1.0` — Release v2.1.0 — published 2022-06-09

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.1.0

### Added

- Added `ignore_discovered_urls` to ignore INFO advertisements from server (#73)

```ruby
NATS.connect(servers: ['nats://127.0.0.1:4444'], ignore_discovered_urls: true)
```

### Fixed

- Fixed issue with JetStream PullSubscription after reaching `pending_msgs_limit` (#76 )

- Fixed issued with NUID not being Ractor safe (#74)

---

### `v2.0.0` — Release v2.0.0 — published 2022-02-07

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.0.0

Revamped version of the with more similar APIs to the Go client, and initial support for JetStream.

To install add the following to your Gemfile:

```
gem 'nats-pure', '2.0.0'
```

```ruby
require 'nats'

# Connect to server that has JetStream support, e.g.
# 
#   nats-server -js
# 
nc = NATS.connect("localhost")

# Create JetStream context.
js = nc.jetstream

# Create Stream that will persist messages from foo subject.
begin
  info = js.add_stream(name: "sample-stream", subjects: ["foo"])
rescue => e
  puts "Error: #{e}"
end

# Send 10 messages and wait to get an ack that they have been persisted.
10.times do |i|
  ack = js.publish("foo", "hello world: #{i}", timeout: 2)
  puts "Published: #{ack.seq}"
end

# Create pull based consumer.
psub = js.pull_subscribe("foo", "psub")

# Fetch 3 messages from consumer.
msgs = psub.fetch(3)
msgs.each do |msg|
  puts "      ACK: Stream Seq: #{msg.metadata.sequence.stream} || Consumer Seq: #{msg.metadata.sequence.consumer}"
  msg.ack
end

# Get latest consumer info.
cinfo = psub.consumer_info
puts "Consumer '#{cinfo.name}' Pending Messages: #{cinfo.num_pending}"

# Subscribe is now dispatched a NATS::Msg that may include headers
nc.subscribe("hello") do |msg|
  puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"
  msg.respond("OK") if msg.reply
end
sub = nc.subscribe("hello")

# Can use publish to send a message with headers.
nc.publish("hello", header: { 'quux': 'quuz'})
nc.publish_msg(NATS::Msg.new(subject: "hello", data: "world", header:{ 'foo': 'bar'}))

# Request also supports publishing with headers.
msg = nc.request("hello", header: { 'a': 'b'})
puts "Response #{msg.data}"

msg = nc.request_msg(NATS::Msg.new(subject: "hello", data: "world!!!", header:{ 'foo': 'bar'}))
puts "Response #{msg.data}"

# Can also use iterator style to consume messages now.
msg = sub.next_msg
puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"

msg = sub.next_msg(timeout: 2)
puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"

begin
  sub.next_msg(timeout: 1)
rescue NATS::Timeout => e
  # puts "Timeout since no new messages yet: #{e}"
end

nc.flush

nc.close
```

---

### `v2.0.0-pre-alpha` — Release v2.0.0 (pre-alpha) — published 2021-10-27

https://github.com/nats-io/nats-pure.rb/releases/tag/v2.0.0-pre-alpha

Revamped version of the with more similar APIs to the Go client, and initial support for JetStream.

To install add the following to your Gemfile:

```
gem 'nats-pure', '2.0.0.pre.alpha'
```

```ruby
require 'nats'

# Connect to server that has JetStream support, e.g.
# 
#   nats-server -js
# 
nc = NATS.connect("localhost")

# Create JetStream context.
js = nc.jetstream

# Create Stream that will persist messages from foo subject.
begin
  info = js.add_stream(name: "sample-stream", subjects: ["foo"])
rescue => e
  puts "Error: #{e}"
end

# Send 10 messages and wait to get an ack that they have been persisted.
10.times do |i|
  ack = js.publish("foo", "hello world: #{i}", timeout: 2)
  puts "Published: #{ack.seq}"
end

# Create pull based consumer.
psub = js.pull_subscribe("foo", "psub")

# Fetch 3 messages from consumer.
msgs = psub.fetch(3)
msgs.each do |msg|
  puts "      ACK: Stream Seq: #{msg.metadata.sequence.stream} || Consumer Seq: #{msg.metadata.sequence.consumer}"
  msg.ack
end

# Get latest consumer info.
cinfo = psub.consumer_info
puts "Consumer '#{cinfo.name}' Pending Messages: #{cinfo.num_pending}"

# Subscribe is now dispatched a NATS::Msg that may include headers
nc.subscribe("hello") do |msg|
  puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"
  msg.respond("OK") if msg.reply
end
sub = nc.subscribe("hello")

# Can use publish to send a message with headers.
nc.publish("hello", header: { 'quux': 'quuz'})
nc.publish_msg(NATS::Msg.new(subject: "hello", data: "world", header:{ 'foo': 'bar'}))

# Request also supports publishing with headers.
msg = nc.request("hello", header: { 'a': 'b'})
puts "Response #{msg.data}"

msg = nc.request_msg(NATS::Msg.new(subject: "hello", data: "world!!!", header:{ 'foo': 'bar'}))
puts "Response #{msg.data}"

# Can also use iterator style to consume messages now.
msg = sub.next_msg
puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"

msg = sub.next_msg(timeout: 2)
puts "Received on '#{msg.subject}': Data: #{msg.data} || Header: #{msg.header}"

begin
  sub.next_msg(timeout: 1)
rescue NATS::Timeout => e
  # puts "Timeout since no new messages yet: #{e}"
end

nc.flush

nc.close
```

---

### `v0.7.2` — Release v0.7.2 — published 2021-08-25

https://github.com/nats-io/nats-pure.rb/releases/tag/v0.7.2

### Added

- Added `NATS.connect` module method that returns a `NATS::IO::Client`

```ruby
# Returns a new NATS::IO::Client.new instance
nc = NATS.connect("nats://demo.nats.io:4222")
nc = NATS.connect(servers: ["nats://demo.nats.io:4222"])
```

- Added logic to prevent multiple uses of `connect` when using the same client instance across different threads.

```ruby
nc = NATS::IO::Client.new
nc.connect("nats://demo.nats.io:4222")
nc.connect("nats://demo.nats.io:4222") # Will not reattempt to connect if already called once.
```

### Fixed

- Fixed `old_request` handling of NATS +v2.2 servers when there are no responders

---

## Open issues at 2026-09-04 (43) — number, opened, title

- #183 — 2026-08-21 — Deadlock in Client#close: Thread#exit can orphan the client monitor
- #178 — 2026-04-05 — KV `watchall` / ordered push consumer exhibits a severe performance cliff between 50k and 100k messages
- #171 — 2025-09-26 — Add support HTTP Headers to WSS
- #169 — 2025-05-28 — When client @pending_queue is full, the library blocks the process
- #153 — 2024-12-06 — Subscription threads not being closed
- #147 — 2024-06-20 — Add filtering to KV method returning all keys
- #142 — 2024-02-27 — Implement Consumer Pause
- #140 — 2024-02-01 — List of keys from jetstream KV
- #139 — 2023-12-10 — NATS connection with username / password with URI Escape characters fails
- #136 — 2023-11-07 — Implement support for Jetstream consumers with multiple subject filters
- #113 — 2023-04-26 — pull_consumer behaving oddly
- #110 — 2023-01-19 — Implement MaxBytes for pull requests
- #109 — 2023-01-19 — Implement new pull consumer and ephemeral consumer options
- #108 — 2023-01-18 — Implement Bind subscribe validation
- #107 — 2023-01-18 — Implement StreamInfo request changes to retrieve subjects
- #106 — 2023-01-18 — Implement Support Consumer Retry Backoff and Nak delays
- #105 — 2023-01-18 — Implement Allow consumer filter subject to be updated
- #103 — 2023-01-06 — Don't Auto ack when Ack Policy is No Ack
- #102 — 2023-01-06 — Default Error Listener
- #101 — 2023-01-05 — Review and verify that on create of streams and consumers, naming errors are surfaced in the client
- #100 — 2022-12-26 — KV History
- #99 — 2022-12-26 — Nats-Expected-Last-Msg-Id
- #98 — 2022-12-26 — Nats-Expected-Last-Sequence
- #97 — 2022-12-26 — Flow Control
- #96 — 2022-12-26 — Alternate Prefixes
- #89 — 2022-10-06 — Implement Properly Randomize Discovered Servers
- #88 — 2022-10-06 — Implement Default Flush Timeout of 10s
- #87 — 2022-10-06 — Implement Discovered Servers
- #86 — 2022-10-05 — Implement ClientIP - What is the IP address of the client from connection
- #85 — 2022-10-05 — Implement LameDuckMode Callback
- #84 — 2022-10-05 — Implement Connection DisconnectedErr Callback
- #79 — 2022-08-22 — Long running jobs get killed when draining
- #53 — 2021-09-02 — Multi-threaded use problems
- #45 — 2020-07-13 — Threads not being cleaned up when no reply.
- #44 — 2020-04-27 — Add RTT helper method
- #43 — 2020-04-15 — Message is not published in multiprocess environment
- #40 — 2019-11-11 — nats: timeout on client.flush
- #35 — 2018-08-11 — Add drain mode 
- #32 — 2018-06-29 — Add support for no echo
- #23 — 2018-02-12 — Spec failure: `should be able to receive response to requests`
- #13 — 2017-02-20 — callback logging
- #12 — 2017-02-20 — Additional stats
- #9 — 2017-01-05 — updating the server list
