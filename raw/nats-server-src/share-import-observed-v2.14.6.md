<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, macOS, 2026-09-03 · one standalone server per scene on port 14222, configs written by share-import-run.sh beside this file (share-import-rawsub.py is the raw subscriber of scene C) · the transcript is the script's output verbatim except that bash's "Terminated: 15" job-control lines are dropped -->
# nats-server v2.14.6 — `Nats-Request-Info` across a service import, observed

The behavioural half of `service-imports-v2.14.6.md`, for `wiki/concepts/service-import-request-info.md`.
Four scenes, each on its own server: **A** two accounts, the import without `share` and then with
`share: true` applied by `--signal reload`; **B** a two-hop chain `APP -> MID -> SVC` with `share` on one
hop or the other; **C** `max_payload: 256` and a shared import, with a raw subscriber that prints the
`HMSG` line the responder receives; **D** `share: true` on a *stream* import, config mode, `nats-server -t`.
`--connection-name=tenant-agent-1` names the requester so the `name` field is recognisable. Nothing is
edited except the dropped job-control lines.

## What each scene shows

- **A1 → A2**: without `share` the responder gets `{"acc":"APP","rtt":…}`; with `share: true` it gets
  `start`, `host`, `id`, `acc`, `user`, `name`, `lang`, `ver`, `rtt`, `server`, `kind`, `client_type`.
  A config-mode user has no JWT, so `jwt`, `issuer_key`, `name_tag` and `tags` are absent here.
- **B1**: `share: false` on APP's import and `share: true` on MID's — no `user`; the second hop added
  `"svc":"MID"` and `"server"`. **B2**: the reverse — the full user block, plus `"svc":"MID"`. The first
  hop's `share` decides (`client.go:4932–4935` in the source half).
- **C1**: a 250-byte request under `max_payload: 256` is accepted and delivered as `HMSG … 257 507` —
  257 header bytes, 507 in total, 250 of body. **C2**: 260 bytes is refused by the client itself
  (`nats: maximum payload exceeded`), so the server never saw it. This is issue #8271 on 2.14.6.
- **D**: `share: true` on a stream import is a valid config (`exit: 0`); the key is applied to service
  imports only (`opts.go:4505–4509`), so it is silently ignored — where the JWT library rejects it.

## Transcript

```
### versions
nats-server: v2.14.6
0.4.0

### scene A — two accounts, the import without share, then share: true by reload
--- A1: no share key
[#1] Received on "svc.remote" with reply "_R_.mk4vfl.qG9lMU"
Nats-Request-Info: {"acc":"APP","rtt":278167}
1
--- A2: share: true
[#1] Received on "svc.remote" with reply "_R_.mk4vfl.YgCX72"
Nats-Request-Info: {"start":"2026-09-03T16:29:15.891833+02:00","host":"127.0.0.1","id":10,"acc":"APP","user":"app","name":"tenant-agent-1","lang":"go","ver":"1.51.0","rtt":262292,"server":"sharelab","kind":"Client","client_type":"nats"}

### scene B — a chain APP -> MID -> SVC: which hop's share decides
--- B1: APP import share: false, MID import share: true
[#1] Received on "svc.remote" with reply "_R_.KQm51E.XA8c8p"
Nats-Request-Info: {"acc":"APP","svc":"MID","rtt":480167,"server":"sharelab"}
--- B2: APP import share: true, MID import share: false
[#1] Received on "svc.remote" with reply "_R_.dkJF9j.abaIyB"
Nats-Request-Info: {"start":"2026-09-03T16:29:21.108671+02:00","host":"127.0.0.1","id":9,"acc":"APP","svc":"MID","user":"app","name":"tenant-agent-1","lang":"go","ver":"1.51.0","rtt":294166,"server":"sharelab","kind":"Client","client_type":"nats"}

### scene C — max_payload: 256 and a shared import; a raw subscriber prints the HMSG line
--- C1: a 250-byte request (under max_payload 256) from APP
16:29:23 Sending request on "svc.local"
HMSG svc.remote 1 _R_.itCe0T.Yg3jSh 257 507
header bytes: 257 total bytes: 507 body bytes: 250
NATS/1.0\r\nNats-Request-Info: {"start":"2026-09-03T16:29:23.761525+02:00","host":"127.0.0.1","id":8,"acc":"APP","user":"app","name":"NATS CLI Version 0.4.0","lang":"go","ver":"1.51.0","rtt":186208,"server":"sharelab","kind":"Client","client_type":"nats"}\r\n\r\n
--- C2: a 260-byte request (over max_payload) from APP — the control
nats: error: nats: maximum payload exceeded

### scene D — share: true on a stream import, config mode: does the config load?
nats-server: configuration file d.conf is valid (sha256:58b2e1d8f77ed43ce8d64c8d563ecfb03359ed72a502aedf0a1c08c567481169)
exit: 0
```
