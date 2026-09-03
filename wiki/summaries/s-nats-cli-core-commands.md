---
title: "nats CLI 0.4.0 — request, reply, trace, server mappings, subscribe, publish help"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/natscli/releases/tag/v0.4.0
source-path: raw/nats-cli/help-core-0.4.0.md
author: nats-io (natscli, Apache-2.0); captured by this wiki
article: "nats request --help, nats reply --help, nats trace --help, nats server mappings --help, nats subscribe --help, nats publish --help on 0.4.0, verbatim"
date: 2026-09-03
version: "natscli 0.4.0"
tags: [nats-cli, request, reply, trace, mappings, subscribe, publish, NATS-RPLY-22, replies, reply-timeout, wait-for-empty, headers-only, subjects-only, inbox-prefix, connection-name]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# nats CLI 0.4.0 — the six core-NATS commands, from `--help`

The flags and defaults of the commands the core-NATS chapter uses, read from the binary rather than
from the docs, so a page can quote a default with its version.

## Key claims

- **`nats request <subject> [body]`** (alias `req`): `--replies=1` ("0 waits until timeout"),
  `--reply-timeout=300ms` ("Maximum time between replies when waiting for more than one"),
  `--wait-for-empty` ("until a empty message is received"), `--count=1`, `-H`, `--raw`, `--force-stdin`,
  `--send-on=eof`, `--[no-]templates`. The wait is the **global `--timeout=5s`** (`$NATS_TIMEOUT`).
- **`nats reply <subject> [body]`**: **`-q, --queue="NATS-RPLY-22"`** — every `nats reply` joins that
  queue group unless told otherwise; `--echo` ("Echo back what is received"); `--command` runs a
  program and answers with its output when it exits 0, with `{{1}}` … from the subject tokens,
  `{{.Request}}` for the body, and the environment `NATS_REQUEST_SUBJECT` / `NATS_REQUEST_BODY`;
  `--sleep=MAX` ("a random sleep delay between replies up to this duration max"); `--count`.
- **`nats trace <subject> [payload]`**: `--deliver` ("Deliver the message to the final destination"),
  `-T, --timestamp`, `-H`. No system-account requirement in the help, and none observed
  ([[s-nats-server-core-delivery-observed]] run E).
- **`nats server mappings [source] [dest] [subject]`** (alias `mapping`): "Test subject mapping patterns";
  no server connection is used.
- **`nats subscribe [subjects...]`** (alias `sub`): `--queue`, `--count`, `--headers-only`,
  `--subjects-only`, `--match-replies`, `-i/--inbox`, `--dump`, `--raw`, `--translate`,
  `-I/--ignore-subject`, `--wait` ("Unsubscribe after this amount of time without any traffic"),
  `--report-subjects` / `--report-subscriptions` / `--report-top=10`, `-t`, `-d`, `--graph`; the
  JetStream flags (`--stream`, `--durable`, `--all`, `--new`, `--last`, `--since`, `--last-per-subject`,
  `--start-sequence`, `-T`, `--ack`, `--direct`) switch it to a stream read — "Uses an ephemeral consumer
  without ack by default". Observed: `--subjects-only` still prints one `[#N] Received on "<subject>"`
  line per message (run F2), which is why the observed file counts them with `grep`.
- **`nats publish <subject> [body]`** (alias `pub`): `--reply`, `-H`, `--count=1`, `--sleep`,
  `--force-stdin`, `--send-on=eof`, `-J/--jetstream`, `--atomic`, `-q/--quiet`, the `--schedule-*`
  family, `--[no-]templates` with `Count`, `TimeStamp`, `Unix`, `UnixNano`, `Time`, `ID`,
  `Random(min, max)`.
- **Global flags every command shares**: `--server`, `--connection-name` ("Nickname to use for the
  underlying NATS Connection"), `--inbox-prefix`, `--timeout=5s`, `--trace` ("Trace API interactions"
  — also the `>>>` connection lines), `--[no-]tlsfirst`, `--socks-proxy`, `--js-domain`,
  `--js-api-prefix`, `--js-event-prefix`, the credential flags, `--context`.

## Practical takeaways

- Two `nats reply` processes on one subject are a queue group by default; use `--queue` to separate them
  when the aim is scatter-gather (step 2 measures this).
- `nats request --replies 0 --timeout 2s` is the CLI's scatter-gather; `--reply-timeout` is the gap
  between replies, `--timeout` the whole wait.
- `nats trace` and `nats server mappings` need nothing beyond a client connection and no connection at
  all, respectively.

## Relevance to the wiki

The cheat-sheet lines on [[nats-cli]] and the defaults quoted on [[core-nats-delivery]] and
[[subjects-and-wildcards]]; step 2's `request-reply` and `queue-groups` pages rest on the same file.

## Questions it answers

171 (the tools), and step 2's rows.

## Pages touched

[[nats-cli]] · [[core-nats-delivery]] · [[subjects-and-wildcards]]
