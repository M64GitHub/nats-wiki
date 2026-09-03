---
title: "natscli v0.4.0 — nats request and nats reply in the source: the gather loop, the exit paths, the reply handler"
type: summary
area: [core, clients]
source-url: https://github.com/nats-io/natscli/tree/v0.4.0/cli
source-path: raw/nats-cli/request-reply-0.4.0.md
author: nats-io (natscli source at tag v0.4.0, from the Go module cache; go.mod pins nats.go v1.51.0)
date: 2026-09-03
version: ""
article: "cli/req_command.go (the flags, the gather loop, --wait-for-empty), cli/reply_command.go (the flags, echo mode, the QueueSubscribe handler with --sleep and --command)"
tags: [natscli, 0.4.0, source, nats-request, nats-reply, replies, reply-timeout, wait-for-empty, exit-code, NewRespInbox, QueueSubscribe, --command, --sleep, NATS-RPLY-22]
aliases: []
sources: []
created: 2026-09-03
updated: 2026-09-03
---

# natscli v0.4.0 — `nats request` and `nats reply` in the source

Why the CLI behaves as [[s-nats-server-request-reply-observed]] runs A–D and F saw it behave, with
line numbers at the tag. Read from the published module (`natscli@v0.4.0` in the Go module cache),
whose `go.mod` pins nats.go v1.51.0.

## Key claims

### `nats request` (`req_command.go`)

- A request is a **sync subscription on `nc.NewRespInbox()`** — the connection's shared
  `_INBOX.<nuid>.*` mux with a fresh last token — and a `PublishMsg` with that reply (`:113–121`).
- The first wait is the whole `--timeout` ("Honor the overall timeout for the first response. No
  responders will circuit break", `:132–134`). Then the loop (`:139–192`):
  - `ErrTimeout` → `break` — **nothing is printed** and the command goes on to its next `--count`
    message or returns `nil`, so **exit 0** (`:143–146`, `:205`);
  - `ErrNoResponders` → `log.Printf("No responders are available")` and `return nil` — **exit 0**
    (`:147–150`);
  - each reply prints `Received with rtt <d>`, its headers and body (`:155–170`);
  - the gather ends when `rc == --replies` (`:175–177`) **or when a reply has an empty body**
    (`if c.replyCount > 0 && len(m.Data) == 0 { break }`, `:179–181`) — with or without
    `--wait-for-empty`;
  - with `--replies 0` the next wait is `--timeout` minus the time elapsed (`:183–187`); with `--replies
    N` it is the **average reply time so far plus `--reply-timeout`** (`:188–191`).
- `--wait-for-empty` sets `replyCount = math.MaxInt16` — it is `--replies 32767` (`:222–224`).
- The subscription is unsubscribed after the gather (`:194–195`).

### `nats reply` (`reply_command.go`)

- Flags: `--command` "Runs a command and responds with the output if exit code was 0"; `--sleep`
  "Inject a random sleep delay between replies up to this duration max"; `-q, --queue` default
  `NATS-RPLY-22` (`:89–91`, `help-core-0.4.0.md`).
- No body, no command and no `--echo` → "No body or command supplied, enabling echo mode" (`:106–108`);
  a responder cannot be told to answer an empty body directly — a `--command` whose output is empty
  does it (run D8).
- The responder is **one `nc.QueueSubscribe` callback** (`:114`): every request is logged, then
  `--sleep` sleeps `rand.Intn(max)` (`:125–127`), then the reply is built — `--echo` copies the request's
  headers and adds `NATS-Reply-Counter` (`:138–146`); `--command` substitutes `{{n}}` with the subject's
  tokens, splits the string shell-style, runs it **synchronously** with `NATS_REQUEST_SUBJECT` and
  `NATS_REQUEST_BODY` in its environment, and the combined output becomes the reply body (`:151–189`).
  A nats.go subscription's callbacks run one at a time, so a slow command holds every later request
  on that member (run C).

## Practical takeaways

- Scripts cannot use `$?` to tell a timed-out `nats request` from a served one; grep the output.
- `--replies N` counts *any* reply, and an empty one ends the gather early; a responder that answers
  an empty body is a sentinel whether or not you asked for one.
- `--reply-timeout` is a gap, measured from the average reply time, and read only when gathering by
  count or sentinel.

## Notable quotes

- `if c.replyCount > 0 && len(m.Data) == 0 { break }` (`req_command.go:179–181`).

## Relevance to the wiki

The explanation behind run D and run F on [[request-reply]] and the `nats request` / `nats reply` lines
on [[nats-cli]]; docs issue #89 (destination natscli).

## Questions it answers

172.

## Pages touched

[[request-reply]] · [[nats-cli]] · [[nats-timeout]]
