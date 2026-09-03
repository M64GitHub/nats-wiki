<!-- source: `nats auth account exports add --help` and `nats auth account imports add --help` on nats CLI 0.4.0 (`nats --version`), macOS, captured verbatim · fetched 2026-09-03 -->
# nats CLI 0.4.0 — `nats auth account exports add` and `imports add`: the flags

The share flag is on the import; the export side has `--token-position` and no `--private` (no activation tokens in `nats auth` v0.4.0). Read for `wiki/concepts/service-import-request-info.md` and `wiki/concepts/cross-account-sharing.md`.

## `nats auth account exports add --help`

```
usage: nats auth account exports add [<flags>] <name> <subject> [<account>]

Adds an Export

Args:
  <name>       A unique name for the Export
  <subject>    The Subject to export
  [<account>]  Account to act on

Flags:
  --operator=OPERATOR        Operator hosting the account
  --description=DESCRIPTION  Friendly description
  --url=URL                  Sets a URL for further information
  --token-position=TOKEN-POSITION  
                             The position to use for the Account name
  --advertise                Advertise the Export
  --service                  Sets the Export to be a Service rather than a
                             Stream

Command Aliases: new, a, n

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

## `nats auth account imports add --help`

```
usage: nats auth account imports add [<flags>] <name> <subject> [<account>]

Adds an Import

Args:
  <name>       A unique name for the import
  <subject>    The Subject to import
  [<account>]  Account to import into

Flags:
  --source=SOURCE      The account public key to import from
  --local=LOCAL        The local Subject to use for the import
  --share              Shares connection information with the exporter
  --traceable          Enable tracing messages across Stream imports
  --service            Sets the import to be a Service rather than a Stream
  --operator=OPERATOR  Operator hosting the account

Command Aliases: new, a, n

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
