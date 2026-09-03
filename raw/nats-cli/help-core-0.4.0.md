<!-- source: nats CLI 0.4.0 on macOS, `nats <cmd> --help` captured 2026-09-03 · six commands, each block verbatim · the global flags block repeats under every command and is the CLI's own -->
# nats CLI 0.4.0 — `request`, `reply`, `trace`, `server mappings`, `subscribe`, `publish` help, verbatim

`nats --version`: 0.4.0

## nats request --help

```
usage: nats request [<flags>] <subject> [<body>]

Generic request-reply request utility

Body and Header values of the messages may use Go templates to create unique
messages.

  nats request test --count 10 "Message {{Count}} @ {{Time}}"

Multiple messages with random strings between 10 and 100 long:

  nats request test --count 10 "Message {{Count}}: {{ Random 10 100 }}"

Available template functions are:

  Count            the message number
  TimeStamp        RFC3339 format current time
  Unix             seconds since 1970 in UTC
  UnixNano         nano seconds since 1970 in UTC
  Time             the current time
  ID               an unique ID
  Random(min, max) random string at least min long, at most max

Args:
  <subject>  Subject to subscribe to
  [<body>]   Message body

Flags:
  -r, --raw                  Show just the output received
  -H, --header=HEADER ...    Adds headers to the message using K:V format
      --count=1              Publish multiple messages
      --replies=1            Wait for multiple replies from services. 0 waits
                             until timeout
      --reply-timeout=300ms  Maximum time between replies when waiting for more
                             than one
      --wait-for-empty       Wait for multiple replies until a empty message is
                             received
      --translate=TRANSLATE  Translate the message data by running it through
                             the given command before output
      --force-stdin          Force reading from stdin
      --send-on=eof          When to send data from stdin: 'eof' (default) or
                             'newline'
      --[no-]templates       Enables template functions in the body and subject
                             (does not affect headers)

Command Aliases: req

Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```

## nats reply --help

```
usage: nats reply [<flags>] <subject> [<body>]

Generic service reply utility

The "command" supports extracting some information from the subject the request
came in on.

When the subject being listened on is "weather.>" a request on "weather.london"
can extract the "london" part and use it in the command string:

  nats reply 'weather.>' --command "curl -s wttr.in/{{1}}?format=3"

This will request the weather for london when invoked as:

  nats request weather.london ''

Use {{.Request}} to access the request body within the --command

The command gets also spawned with two ENVs:

  NATS_REQUEST_SUBJECT
  NATS_REQUEST_BODY

  nats reply 'echo' --command="printenv NATS_REQUEST_BODY"

The body and Header values of the messages may use Go templates to create unique
messages.

  nats reply test "Message {{Count}} @ {{Time}}"

Available template functions are:

  Count            the message number
  TimeStamp        RFC3339 format current time
  Unix             seconds since 1970 in UTC
  UnixNano         nano seconds since 1970 in UTC
  Time             the current time
  ID               an unique ID
  Request          the request payload
  Random(min, max) random string at least min long, at most max

Args:
  <subject>  Subject to subscribe to
  [<body>]   Reply body

Flags:
      --echo                  Echo back what is received
      --command=COMMAND       Runs a command and responds with the output if
                              exit code was 0
  -q, --queue="NATS-RPLY-22"  Queue group name
      --sleep=MAX             Inject a random sleep delay between replies up to
                              this duration max
  -H, --header=HEADER ...     Adds headers to the message using K:V format
      --count=COUNT           Quit after receiving this many messages


Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```

## nats trace --help

```
usage: nats trace [<flags>] <subject> [<payload>]

Trace message delivery within an NATS network

Args:
  <subject>    The subject to publish to
  [<payload>]  The message body to send

Flags:
      --deliver            Deliver the message to the final destination
  -T, --timestamp          Show event timestamps
  -H, --header=HEADER ...  Adds headers to the trace message using K:V format


Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```

## nats server mappings --help

```
usage: nats server mappings [<source>] [<dest>] [<subject>]

Test subject mapping patterns

Args:
  [<source>]   Source subject pattern
  [<dest>]     Destination subject pattern
  [<subject>]  Subject to transform

Command Aliases: mapping

Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```

## nats sub --help

```
usage: nats subscribe [<flags>] [<subjects>...]

Generic subscription client

Jetstream will be activated when related options like --stream, --durable,
direct or --ack are supplied.

  E.g. nats sub <subject that is bound to a stream> --all

Uses an ephemeral consumer without ack by default.

For specific consumer options please pre-create a consumer using 'nats consumer
add'.app.

  E.g. when explicit acknowledgement is required.

Use nats stream view <stream> for inspecting messages.

Args:
  [<subjects>]  Subjects to subscribe to

Flags:
      --queue=QUEUE              Subscribe to a named queue group
      --durable=DURABLE          Use a durable consumer (requires JetStream)
  -r, --raw                      Show the raw data received
      --translate=TRANSLATE      Translate the message data by running it
                                 through the given command before output
      --[no-]ack                 Acknowledge JetStream message that have the
                                 correct metadata
      --match-replies            Match replies to requests
  -i, --inbox                    Subscribes to a generated inbox
      --count=COUNT              Quit after receiving this many messages
      --dump=DIRECTORY           Dump received messages to files, 1 file per
                                 message. Specify - for null terminated STDOUT
                                 for use with xargs -0
      --headers-only             Do not render any data, shows only headers
      --subjects-only            Prints only the messages' subjects
      --start-sequence=SEQUENCE  Starts at a specific Stream sequence (requires
                                 JetStream)
      --all                      Delivers all messages found in the Stream
                                 (requires JetStream)
      --new                      Delivers only future messages (requires
                                 JetStream)
      --last                     Delivers the most recent and all future
                                 messages (requires JetStream)
      --since=DURATION           Delivers messages received since a duration
                                 like 1d3h5m2s(requires JetStream)
      --last-per-subject         Deliver the most recent messages for each
                                 subject in the Stream (requires JetStream)
  -T, --terminate-at-end         Stops consuming messages from JetStream once
                                 all messages were received
      --stream=STREAM            Subscribe to a specific stream (required
                                 JetStream)
  -I, --ignore-subject=SUBJECT ...  
                                 Subjects for which corresponding messages
                                 will be ignored and therefore not shown in the
                                 output
      --wait=WAIT                Unsubscribe after this amount of time without
                                 any traffic
      --report-subjects          Subscribes to subject patterns and builds
                                 a de-duplicated report of active subjects
                                 receiving data
      --report-subscriptions     Subscribes to subject patterns and builds a
                                 de-duplicated report of active subscriptions
                                 receiving data
      --report-top=10            Number of subjects to show when doing
                                 'report-subjects'
  -t, --timestamp                Show timestamps in output
  -d, --delta-time               Show time since start in output
      --graph                    Graph the rate of messages received
      --direct                   Subscribe using batched direct gets instead of
                                 a durable consumer (requires JetStream)

Command Aliases: sub

Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```

## nats pub --help

```
usage: nats publish [<flags>] <subject> [<body>]

Generic data publish utility

Body and Header values of the messages may use Go templates to create unique
messages.

  nats pub test --count 10 "Message {{Count}} @ {{Time}}"

Multiple messages with random strings between 10 and 100 long:

  nats pub test --count 10 "Message {{Count}}: {{ Random 10 100 }}"

Available template functions are:

  Count            the message number
  TimeStamp        RFC3339 format current time
  Unix             seconds since 1970 in UTC
  UnixNano         nano seconds since 1970 in UTC
  Time             the current time
  ID               an unique ID
  Random(min, max) random string at least min long, at most max

Args:
  <subject>  Subject to publish to
  [<body>]   Message body

Flags:
      --reply=SUBJECT            Sets a custom reply to subject
  -H, --header=K:V ...           Adds headers to the message using K:V format
      --atomic                   Atomic batch publish to JetStream (implies
                                 --jetstream)
      --count=1                  Publish multiple messages
      --force-stdin              Force reading from stdin
  -J, --jetstream                Publish messages to JetStream
  -q, --quiet                    Show just the output received
      --schedule-after=DURATION  Schedule the message after a certain duration
                                 (implies --jetstream)
      --schedule-at=TIME         Schedule the message at a certain RFC3339 time
                                 (implies --jetstream)
      --schedule-cron=CRON       Cron definition for a scheduled message
                                 (implies --jetstream)
      --schedule-dest=SUBJECT    Subject the message will publish to when the
                                 schedule fires (implies --jetstream)
      --schedule-every=DURATION  Schedules the message every interval (implies
                                 --jetstream)
      --schedule-source=SUBJECT  Reads a specific subject when scheduling
                                 (implies --jetstream)
      --schedule-ttl=DURATION    How long generated messages should live in the
                                 stream
      --send-on=eof              When to send data from stdin: 'eof' (default)
                                 or 'newline'
      --sleep=SLEEP              When publishing multiple messages, sleep
                                 between publishes
      --[no-]templates           Enables template functions in the body and
                                 subject (does not affect headers)

Command Aliases: pub

Global Flags:
  -h, --help                    Show context-sensitive help
      --version                 Show application version.
  -s, --server=URL              NATS server urls ($NATS_URL)
      --user=USER               Username or Token ($NATS_USER)
      --password=PASSWORD       Password ($NATS_PASSWORD)
      --token=TOKEN             Token ($NATS_TOKEN)
      --connection-name=NAME    Nickname to use for the underlying NATS
                                Connection
      --creds=FILE              User credentials ($NATS_CREDS)
      --nkey=FILE               User NKEY ($NATS_NKEY)
      --jwt=JWT                 User JWT ($NATS_JWT)
      --seed=SEED               User seed ($NATS_SEED)
      --tlscert=FILE            TLS public certificate ($NATS_CERT)
      --tlskey=FILE             TLS private key ($NATS_KEY)
      --tlsca=FILE              TLS certificate authority chain ($NATS_CA)
      --[no-]tlsfirst           Perform TLS handshake before expecting the
                                server greeting
      --timeout=5s              Time to wait on responses from NATS
                                ($NATS_TIMEOUT)
      --socks-proxy=PROXY       SOCKS5 proxy for connecting to NATS server
                                ($NATS_SOCKS_PROXY)
      --js-api-prefix=PREFIX    Subject prefix for access to JetStream API
      --js-event-prefix=PREFIX  Subject prefix for access to JetStream
                                Advisories
      --js-domain=DOMAIN        JetStream domain to access
      --inbox-prefix=PREFIX     Custom inbox prefix to use for inboxes
      --colors=SCHEME           Sets a color scheme to use ($NATS_COLOR)
      --context=NAME            Configuration context ($NATS_CONTEXT)
      --trace                   Trace API interactions
      --no-context              Disable the selected context

LLM Information:
  This application supports LLM friendly output when ran with LLMFORMAT=1

  The application applies tags to its commands that are visible in help output:

    - scope:user - Operates at user level, no system credentials needed
    - scope:system - Operates at system level, requires system credentials
    - impact:ro - Read only operation, does not modify NATS data or state
    - impact:rw - Read and write operation, modifies NATS data or state

  LLM optimized help output can be obtained using --help-llm for any command.
  You must set LLMFORMAT=1 for all invocations of this command including when
  looking for help.

```
