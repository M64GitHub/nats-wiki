<!-- source: nats CLI 0.4.0 on macOS, `nats <cmd> --help` captured 2026-09-03 · the global flags below each command are the CLI's own and repeat -->
# nats CLI 0.4.0 — `stream add`, `stream edit`, `consumer add`, `consumer edit` help, verbatim

`nats --version`: 0.4.0

## nats stream add --help

```
usage: nats stream add [<flags>] [<stream>]

Create a new stream

Args:
  [<stream>]  Stream name

Flags:
      --config=CONFIG            JSON file to read configuration from
      --validate                 Only validates the configuration against the
                                 official Schema
      --output=FILE              Save configuration instead of creating
      --subjects=SUBJECTS ...    Subjects that are consumed by the stream
      --description=DESCRIPTION  Sets a contextual description for the stream
      --storage=STORAGE          Storage backend to use (file, memory)
      --compression=COMPRESSION  Compression algorithm to use (file storage
                                 only)
      --replicas=REPLICAS        When clustered, how many replicas of the data
                                 to create
      --tag=TAG ...              Place the stream on servers that has specific
                                 tags (pass multiple times)
      --cluster=CLUSTER          Place the stream on a specific cluster
      --[no-]ack                 Acknowledge publishes
      --retention=RETENTION      Defines a retention policy (limits, interest,
                                 work)
      --discard=DISCARD          Defines the discard policy (new, old)
      --[no-]discard-per-subject  
                                 Sets the 'new' discard policy and applies it to
                                 every subject in the stream
      --first-sequence=FIRST-SEQUENCE  
                                 Sets the starting sequence
      --max-age=""               Maximum age of messages to keep
      --max-bytes=BYTES          Maximum bytes to keep
      --max-consumers=-1         Maximum number of consumers to allow
      --max-msg-size=BYTES       Maximum size any 1 message may be
      --max-msgs=0               Maximum amount of messages to keep
      --max-msgs-per-subject=0   Maximum amount of messages to keep per subject
      --dupe-window=""           Duration of the duplicate message tracking
                                 window
      --mirror=MIRROR            Completely mirror another stream
      --source=STREAM ...        Source data from other streams, merging into
                                 this one
      --[no-]allow-batch         Allow atomic batch publishing
      --[no-]allow-fast          Allow fast batch publishing
      --allow-counter            Configures the stream as a distributed counter
      --[no-]allow-rollup        Allows roll-ups to be done by publishing
                                 messages with special headers
      --[no-]deny-delete         Deny messages from being deleted via the API
      --[no-]deny-purge          Deny entire stream or subject purges via the
                                 API
      --[no-]allow-direct        Allows fast, direct, access to stream data via
                                 the direct get API
      --[no-]allow-mirror-direct  
                                 Allows fast, direct, access to stream data via
                                 the direct get API on mirrors
      --allow-msg-ttl            Allows per-message TTL handling
      --[no-]allow-schedules     Allows message schedules
      --subject-del-markers-ttl=DURATION  
                                 How long delete markers should persist in the
                                 stream
      --transform-source=SOURCE  Stream subject transform source
      --transform-destination=DEST  
                                 Stream subject transform destination
      --metadata=META ...        Adds metadata to the stream
      --republish-source=SOURCE  Republish messages to --republish-destination
      --republish-destination=DEST  
                                 Republish destination for messages in
                                 --republish-source
      --republish-headers        Republish only message headers, no bodies
      --limit-consumer-inactive=THRESHOLD  
                                 The maximum Consumer inactive threshold the
                                 stream allows
      --limit-consumer-max-pending=PENDING  
                                 The maximum Consumer Ack Pending the stream
                                 Allows
      --persist-mode=PERSIST-MODE  
                                 Configures the persistence mode
  -j, --json                     Produce JSON output
      --defaults                 Accept default values for all prompts

Command Aliases: create, new

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
  -a, --all                     When listing or selecting streams show all
                                streams including system ones

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

## nats stream edit --help

```
usage: nats stream edit [<flags>] [<stream>]

Edits an existing stream

Args:
  [<stream>]  Stream to retrieve edit

Flags:
      --config=CONFIG            JSON file to read configuration from
  -f, --force                    Force edit without prompting
  -i, --[no-]interactive         Edit the configuring using your editor
      --dry-run                  Only shows differences, do not edit the stream
      --subjects=SUBJECTS ...    Subjects that are consumed by the stream
      --description=DESCRIPTION  Sets a contextual description for the stream
      --compression=COMPRESSION  Compression algorithm to use (file storage
                                 only)
      --replicas=REPLICAS        When clustered, how many replicas of the data
                                 to create
      --tag=TAG ...              Place the stream on servers that has specific
                                 tags (pass multiple times)
      --cluster=CLUSTER          Place the stream on a specific cluster
      --[no-]ack                 Acknowledge publishes
      --retention=RETENTION      Defines a retention policy (limits, interest,
                                 work)
      --discard=DISCARD          Defines the discard policy (new, old)
      --[no-]discard-per-subject  
                                 Sets the 'new' discard policy and applies it to
                                 every subject in the stream
      --max-age=""               Maximum age of messages to keep
      --max-bytes=BYTES          Maximum bytes to keep
      --max-consumers=-1         Maximum number of consumers to allow
      --max-msg-size=BYTES       Maximum size any 1 message may be
      --max-msgs=0               Maximum amount of messages to keep
      --max-msgs-per-subject=0   Maximum amount of messages to keep per subject
      --dupe-window=""           Duration of the duplicate message tracking
                                 window
      --mirror=MIRROR            Completely mirror another stream
      --no-mirror                Removes current mirror configuration
      --source=STREAM ...        Source data from other streams, merging into
                                 this one
      --[no-]allow-batch         Allow atomic batch publishing
      --[no-]allow-fast          Allow fast batch publishing
      --allow-counter            Configures the stream as a distributed counter
      --[no-]allow-rollup        Allows roll-ups to be done by publishing
                                 messages with special headers
      --[no-]deny-delete         Deny messages from being deleted via the API
      --[no-]deny-purge          Deny entire stream or subject purges via the
                                 API
      --[no-]allow-direct        Allows fast, direct, access to stream data via
                                 the direct get API
      --[no-]allow-mirror-direct  
                                 Allows fast, direct, access to stream data via
                                 the direct get API on mirrors
      --allow-msg-ttl            Allows per-message TTL handling
      --[no-]allow-schedules     Allows message schedules
      --subject-del-markers-ttl=DURATION  
                                 How long delete markers should persist in the
                                 stream
      --transform-source=SOURCE  Stream subject transform source
      --transform-destination=DEST  
                                 Stream subject transform destination
      --no-transform             Removes current subject transform configuration
      --metadata=META ...        Adds metadata to the stream
      --republish-source=SOURCE  Republish messages to --republish-destination
      --republish-destination=DEST  
                                 Republish destination for messages in
                                 --republish-source
      --republish-headers        Republish only message headers, no bodies
      --no-republish             Removes current republish configuration
  -j, --json                     Produce JSON output

Command Aliases: update

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
  -a, --all                     When listing or selecting streams show all
                                streams including system ones

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

## nats consumer add --help

```
usage: nats consumer add [<flags>] [<stream>] [<consumer>]

Creates a new consumer

Args:
  [<stream>]    Stream name
  [<consumer>]  Consumer name

Flags:
  --config=CONFIG               JSON file to read configuration from
  --validate                    Only validates the configuration against the
                                official Schema
  --output=FILE                 Save configuration instead of creating
  --ack=ACK                     Acknowledgment policy (none, all, explicit,
                                flow_control)
  --bps=0                       Restrict message delivery to a certain bit per
                                second
  --backoff=MODE                Creates a consumer backoff policy using a
                                specific pre-written algorithm (none, linear)
  --backoff-steps=10            Number of steps to use when creating the backoff
                                policy
  --backoff-min=1m              The shortest backoff period that will be
                                generated
  --backoff-max=20m             The longest backoff period that will be
                                generated
  --deliver=POLICY              Start policy (all, new, last, subject, 1h,
                                msg sequence)
  --deliver-group=GROUP         Delivers push messages only to subscriptions
                                matching this group
  --description=DESCRIPTION     Sets a contextual description for the consumer
  --ephemeral                   Create an ephemeral consumer
  --filter=SUBJECTS ...         Filter Stream by subjects
  --flow-control                Enable Push consumer flow control
  --heartbeat=HEARTBEAT         Enable idle Push consumer heartbeats (-1
                                disable)
  --[no-]headers-only           Deliver only headers and no bodies
  --max-deliver=TRIES           Maximum amount of times a message will be
                                delivered
  --max-pending=-1              Maximum pending Acks before consumers are paused
  --max-waiting=PULLS           Maximum number of outstanding pulls allowed
  --max-pull-batch=BATCH_SIZE   Maximum size batch size for a pull request to
                                accept
  --max-pull-expire=EXPIRES     Maximum expire duration for a pull request to
                                accept
  --max-pull-bytes=BYTES        Maximum max bytes for a pull request to accept
  --pull                        Deliver messages in 'pull' mode
  --replay=POLICY               Replay Policy (instant, original)
  --sample=-1                   Percentage of requests to sample for monitoring
                                purposes
  --target=SUBJECT              Push based delivery target subject
  --wait=-1s                    Acknowledgment waiting time
  --inactive-threshold=THRESHOLD  
                                How long to allow an ephemeral consumer to be
                                idle before removing it
  --memory                      Force the consumer state to be stored in memory
                                rather than inherit from the stream
  --replicas=REPLICAS           Sets a custom replica count rather than inherit
                                from the stream
  --metadata=META ...           Adds metadata to the consumer
  --pause=PAUSE                 Pause the consumer for a duration after start
                                or until a specific timestamp (eg 2026-09-03
                                04:16:07)
  --pinned-groups=GROUPS ...    Create a Pinned Client consumer based on these
                                groups
  --pinned-ttl=TTL              The time to allow for a client to pull before
                                losing the pinned status
  --overflow-groups=GROUPS ...  Create a Overflow consumer based on these groups
  --prioritized-groups=GROUPS ...  
                                Create a Prioritized consumer based on these
                                groups
  --defaults                    Accept default values for all prompts

Command Aliases: create, new

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
  -a, --all                     Operate on all streams including system ones

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

## nats consumer edit --help

```
usage: nats consumer edit [<flags>] [<stream>] [<consumer>]

Edits the configuration of a consumer

Args:
  [<stream>]    Stream name
  [<consumer>]  Consumer name

Flags:
      --config=CONFIG            JSON file to read configuration from
  -f, --force                    Force removal without prompting
  -i, --[no-]interactive         Edit the configuring using your editor
      --dry-run                  Only shows differences, do not edit the stream
      --backoff=MODE             Creates a consumer backoff policy using a
                                 specific pre-written algorithm (none, linear)
      --backoff-steps=10         Number of steps to use when creating the
                                 backoff policy
      --backoff-min=1m           The shortest backoff period that will be
                                 generated
      --backoff-max=20m          The longest backoff period that will be
                                 generated
      --description=DESCRIPTION  Sets a contextual description for the consumer
      --filter=SUBJECTS ...      Filter Stream by subjects
      --[no-]headers-only        Deliver only headers and no bodies
      --max-deliver=TRIES        Maximum amount of times a message will be
                                 delivered
      --max-pending=-1           Maximum pending Acks before consumers are
                                 paused
      --max-pull-batch=BATCH_SIZE  
                                 Maximum size batch size for a pull request to
                                 accept
      --max-pull-expire=EXPIRES  Maximum expire duration for a pull request to
                                 accept
      --max-pull-bytes=BYTES     Maximum max bytes for a pull request to accept
      --sample=-1                Percentage of requests to sample for monitoring
                                 purposes
      --target=SUBJECT           Push based delivery target subject
      --wait=-1s                 Acknowledgment waiting time
      --inactive-threshold=THRESHOLD  
                                 How long to allow an ephemeral consumer to be
                                 idle before removing it
      --replicas=REPLICAS        Sets a custom replica count rather than inherit
                                 from the stream
      --metadata=META ...        Adds metadata to the consumer

Command Aliases: update

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
  -a, --all                     Operate on all streams including system ones

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
