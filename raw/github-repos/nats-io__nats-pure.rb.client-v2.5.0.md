<!-- source: https://github.com/nats-io/nats-pure.rb/blob/v2.5.0/lib/nats/io/client.rb (`gh api repos/nats-io/nats-pure.rb/contents/lib/nats/io/client.rb?ref=v2.5.0`, blob sha 90fa11968b7e077e557f4b8247c700d246614e05, tag sha 685083f35901de251e65b4e1cfb397763286272a) · fetched 2026-09-04 · quoted ranges, verbatim, line numbers as in the file at that tag -->
# nats-pure.rb v2.5.0 — `lib/nats/io/client.rb`, the ranges this wiki quotes

Fetched for step 8 of `inbox/plan-the-client-side-2026-09-03.md`. The Ruby client is named in **none** of the eight `learn/resilient-clients` pages and its ten release bodies state no default, so its own source is the only public statement of what it does. The ranges below are the constants block, the drain entry point, the stale-connection check, the outbound queue, the reconnect budget, the per-subscription limits and the slow-consumer path.

### `lib/nats/io/client.rb:1863–1898` — the constants: reconnect budget, ping interval, timeouts, pending limits

```ruby
  module IO
    include Status

    # Client creates a connection to the NATS Server.
    Client = ::NATS::Client

    MAX_RECONNECT_ATTEMPTS = 10
    RECONNECT_TIME_WAIT = 2

    # Maximum accumulated pending commands bytesize before forcing a flush.
    MAX_PENDING_SIZE = 32768

    # Maximum number of flush kicks that can be queued up before we block.
    MAX_FLUSH_KICK_SIZE = 1024

    # Maximum number of bytes which we will be gathering on a single read.
    # TODO: Make dynamic?
    MAX_SOCKET_READ_BYTES = 32768

    # Ping intervals
    DEFAULT_PING_INTERVAL = 120
    DEFAULT_PING_MAX = 2

    # Default IO timeouts
    DEFAULT_CONNECT_TIMEOUT = 2
    DEFAULT_READ_WRITE_TIMEOUT = 2
    DEFAULT_DRAIN_TIMEOUT = 30
    DEFAULT_CLOSE_TIMEOUT = 30

    # Default Pending Limits
    DEFAULT_SUB_PENDING_MSGS_LIMIT = 65536
    DEFAULT_SUB_PENDING_BYTES_LIMIT = 65536 * 1024

    DEFAULT_TOTAL_SUB_CONCURRENCY = 24
    DEFAULT_SINGLE_SUB_CONCURRENCY = 1

```

### `lib/nats/io/client.rb:837–850` — `drain` — the comment and the thread it starts

```ruby
    # drain will put a connection into a drain state. All subscriptions will
    # immediately be put into a drain state. Upon completion, the publishers
    # will be drained and can not publish any additional messages. Upon draining
    # of the publishers, the connection will be closed. Use the `on_close`
    # callback option to know when the connection has moved from draining to closed.
    def drain
      return if draining?

      synchronize do
        @drain_t ||= Thread.new { do_drain }
      end
    end

    # Create a JetStream context.
```

### `lib/nats/io/client.rb:1414–1430` — `ping_interval_loop` — the stale-connection check

```ruby
    def ping_interval_loop
      loop do
        sleep @options[:ping_interval]

        # Skip ping interval until connected
        next if !connected?

        if @pings_outstanding >= @options[:max_outstanding_pings]
          process_op_error(NATS::IO::StaleConnectionError.new("nats: stale connection"))
          return
        end

        @pings_outstanding += 1
        send_command(PING_REQUEST)
        @flush_queue << :ping
      end
    rescue => e
```

### `lib/nats/io/client.rb:455–460` — the outbound queue is a `SizedQueue`

```ruby

      # Initialize queues and loops for message dispatching and processing engine
      @flush_queue = SizedQueue.new(NATS::IO::MAX_FLUSH_KICK_SIZE)
      @pending_queue = SizedQueue.new(NATS::IO::MAX_PENDING_SIZE)
      @pings_outstanding = 0
      @pongs_received = 0
```

### `lib/nats/io/client.rb:1710–1723` — the reconnect budget is per server

```ruby
    def can_reuse_server?(server)
      return false if server.nil?

      # We can always reuse servers with infinite reconnects settings
      return true if @options[:max_reconnect_attempts] < 0

      # In case of hard errors like authorization errors, drop the server
      # already since won't be able to connect.
      return false if server[:error_received]

      # We will retry a number of times to reconnect to a server.
      server[:reconnect_attempts] <= @options[:max_reconnect_attempts]
    end

```

### `lib/nats/io/client.rb:527–545` — the per-subscription pending limits and their `SizedQueue`

```ruby
        sub.nc = self
        sub.sid = sid
      end
      opts[:pending_msgs_limit] ||= NATS::IO::DEFAULT_SUB_PENDING_MSGS_LIMIT
      opts[:pending_bytes_limit] ||= NATS::IO::DEFAULT_SUB_PENDING_BYTES_LIMIT

      sub.subject = subject
      sub.callback = callback
      sub.received = 0
      sub.queue = opts[:queue] if opts[:queue]
      sub.max = opts[:max] if opts[:max]
      sub.pending_msgs_limit = opts[:pending_msgs_limit]
      sub.pending_bytes_limit = opts[:pending_bytes_limit]
      sub.pending_queue = SizedQueue.new(sub.pending_msgs_limit)
      sub.processing_concurrency = opts[:processing_concurrency] if opts.key?(:processing_concurrency)

      send_command("SUB #{subject} #{opts[:queue]} #{sid}#{CR_LF}")
      @flush_queue << :sub

```

### `lib/nats/io/client.rb:1037–1053` — the slow-consumer path: the message is dropped, not queued

```ruby
          return
        elsif sub.pending_queue
          # Async subscribers use a sized queue for processing
          # and should be able to consume messages in parallel.
          if (sub.pending_queue.size >= sub.pending_msgs_limit) \
            || (sub.pending_size >= sub.pending_bytes_limit)
            err = NATS::IO::SlowConsumer.new("nats: slow consumer, messages dropped")
          else
            hdr = process_hdr(header)

            # Only dispatch message when sure that it would not block
            # the main read loop from the parser.
            msg = Msg.new(subject: subject, reply: reply, data: data, header: hdr, nc: self, sub: sub)

            sub.dispatch(msg)
          end
        end
```
