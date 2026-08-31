---
title: "natscli v0.4.0 — nats stream backup / restore"
type: summary
area: [jetstream, deploy]
source-url: https://github.com/nats-io/natscli/blob/v0.4.0/cli/stream_command.go
source-path: raw/github-repos/nats-io__natscli.stream-backup-v0.4.0.md
author: nats-io/natscli maintainers
article: "cli/stream_command.go — the backup and restore command definitions at tag v0.4.0"
date: 2026-05-01          # v0.4.0 publish date
version: "0.4.0"
tags: [nats-cli, backup, restore, snapshot, --config, --cluster, --replicas, --check]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# natscli v0.4.0 — `nats stream backup` / `nats stream restore`

Every flag the two commands take, read because the docs use three of them and never mention the
three that matter most in a disaster: `--config`, `--cluster` and `--replicas` on restore.

## Key claims

**`nats stream backup`** — aliased **`snapshot`** (`cli/stream_command.go:417–425`):

| flag | default | what it does |
|---|---|---|
| `--progress` | `true` | progress bar |
| `--check` | off | "Checks the stream for health prior to backup" — the API's `jsck` field |
| `--consumers` | **`true`** | "Enable or disable consumer backups" — `--no-consumers` turns it off |
| `--chunk-size` | server default 128 KiB | "Sets a specific chunk size that the server will send" |
| `--window-size` | server default 8 MiB | "Sets a specific window size that the server will send" |

Both size flags are parsed as byte strings (`64k`, `1m`) and passed through to the snapshot request,
where the server clamps them ([[s-nats-server-snapshot-restore]]).

**`nats stream restore`** (`:427–434`) — the three flags the docs never mention:

| flag | what it does |
|---|---|
| `--config <file>` | "Load a different configuration when restoring the stream" |
| `--cluster <name>` | "Place the stream in a specific cluster" |
| `--tag <tag>` | "Place the stream on servers that has specific tags (pass multiple times)" |
| `--replicas <n>` | "Override how many replicas of the data to create" |

`--cluster` and `--tag` are assembled into a `Placement` on the restored stream
(`:1313–1318`), so **a snapshot can be restored into a different cluster, onto tagged servers, at a
different replica count** ([[stream-placement]]).

**The rename check is client-side, and only fires with `--config`** (`:1296–1312`):

```go
	if c.inputFile != "" {
		cfg, err = c.loadConfigFile(c.inputFile)
		…
		// we need to confirm this new config has the same stream
		// name as the snapshot else the server state can get confused
		// see https://github.com/nats-io/nats-server/issues/2850
		if bm.Config.Name != cfg.Name {
			return fmt.Errorf("stream names may not be changed during restore")
		}
	}
```

Two corrections to the docs follow: the message is the **CLI's**, not the server's, and it reads
`stream names may not be changed during restore` — **plural**. The server's own rejection is error
**10060**, "expected stream does not match".

**`nats stream backup` does not pre-check storage type.** There is no memory-stream branch in the
command, which is why a memory stream fails with the server's `no impl` rather than a CLI message.

## Practical takeaways

- **A restore is a placement decision, not just a copy.** `--cluster`, `--tag` and `--replicas` make
  "restore the production snapshot into the DR site at R1" a one-liner. This is the single most
  useful thing the docs' backup chapter leaves out.
- **`--check` is the pre-flight the DR page asks for** when it says an untested snapshot is
  unverified — it verifies message checksums before the copy is taken.
- **The name is the one thing that cannot change**, and the reason is linked in the source:
  `nats-server` issue #2850, "else the server state can get confused".
- **`--consumers` defaults to true**, so the risk is only in explicitly passing `--no-consumers`.

## Relevance to the wiki

The command surface of [[backup-and-restore-jetstream]] and the cross-site restore option in
[[disaster-recovery]]; the flags are added to [[nats-cli]]'s cheat sheet.

## Questions it answers

**Q32**; contributes to **Q39**.

## Pages touched

[[backup-and-restore-jetstream]] · [[disaster-recovery]] · [[nats-cli]] · [[stream-placement]] ·
[[replicas]]
