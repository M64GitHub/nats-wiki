---
title: Nats-Request-Info across a service import
type: concept
area: [security, core]
since: [2.10]   # present at v2.10.0 (accounts.go:132); the arrival is older than the release archive
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [Nats-Request-Info, share, service-import, ClientInfo, identity, multi-tenancy, 8271, CVE-2026-33246]
aliases: [Nats-Request-Info, request info header, request-info header, "share: true", service import share, client info header, ClientInfo]
sources: [s-nats-server-service-imports, s-nats-server-share-import-observed, s-jwt-imports-exports-activation, s-nsc-imports-exports-activation, s-natscli-auth-exports-imports, s-issue-8271-request-info-max-payload, s-ghsa-2026-08-request-info-spoofing, s-docs-config-accounts-exports-imports, s-nats-server-system-subjects-observed]
created: 2026-09-03
updated: 2026-09-03
---

# `Nats-Request-Info` across a service import

**When a request crosses a service import, the server stamps a `Nats-Request-Info` header on it: a
JSON description of the requester, written by the server, not by the client.** By default it names the
requester's *account* and nothing more; with `share: true` on the import it names the *user* as well.
It is the only server-vouched identity a service in one account has for a caller in another — the
thing a multi-tenant service authorises on, and the thing a tenant has to opt into
(source: [[s-nats-server-service-imports]]).

## What it is

The header is set inside the server's service-import path, once per request and never on the reply,
and it survives routes and gateways (`client.go:4930–4993`). The same `ClientInfo` block appears as the
`requestor` of a service-latency event when the export samples latency, which is what the flag was
written for: the setter is commented "Used for service latency tracking at the moment"
(source: [[s-nats-server-service-imports]]; the latency event observed in
[[s-nats-server-system-subjects-observed]] carried `requestor: {"acc":"APP","rtt":356292}`).

Whether it is *meant* to be trusted is answered by the maintainers' own advisory for CVE-2026-33246:
the header "is supposed to provide enough information to allow for account/user identification, such
that NATS clients could make their own decisions on how to trust a message, provided that they trust
the nats-server as a broker" (source: [[s-ghsa-2026-08-request-info-spoofing]]).

## How it behaves

**Two shapes, decided by the import's `share` flag** — observed on 2.14.6, config mode, the requester
connected as user `app` in account `APP` with the connection name `tenant-agent-1`
(source: [[s-nats-server-share-import-observed]]):

| the import | the responder in the exporting account sees |
|---|---|
| no `share` | `Nats-Request-Info: {"acc":"APP","rtt":278167}` |
| `share: true` | `{"start":"2026-09-03T16:29:15.891833+02:00","host":"127.0.0.1","id":10,"acc":"APP","user":"app","name":"tenant-agent-1","lang":"go","ver":"1.51.0","rtt":262292,"server":"sharelab","kind":"Client","client_type":"nats"}` |

`acc` and `rtt` are always set; everything else only when `share` is on (`getClientInfo(detailed)`,
`client.go:6590–6622`). The full field list, with its JSON names, is `events.go:309–333`: `start`,
`host`, `id`, `acc`, `svc`, `user`, `name`, `lang`, `ver`, `rtt`, `server`, `cluster`, `alts`, `stop`,
`jwt`, `issuer_key`, `name_tag`, `tags`, `kind`, `client_type`, `client_id`, `nonce`, `reply`. In
**operator mode** the shared shape therefore also carries **`jwt` — the whole user JWT** — plus
`issuer_key`, `name_tag` and `tags`; a config-mode user has none of those, which is why the run above
does not show them (source: [[s-nats-server-service-imports]]).

**What `user` holds** depends on how the requester authenticated (`getRawAuthUser`,
`client.go:6765–6777`): an NKey login gives the public key; a username gives the username; a **JWT
login gives the user's public key** (`c.pubKey`), not a name; a bare token gives the literal
`[REDACTED]`. `name` is the client-chosen connection name and proves nothing; `host` is the client's
address (source: [[s-nats-server-service-imports]]).

**On a chain of imports the first hop decides.** When a request passes through two service imports —
`APP → MID → SVC`, MID re-exporting what it imports — the header is built at the first hop and carried
forward, and only the first import's `share` counts (`client.go:4932–4935`). Observed: `share: true`
on MID's import and `false` on APP's gave `{"acc":"APP","svc":"MID","rtt":480167,"server":"sharelab"}`
— no user; the reverse gave the full user block plus `"svc":"MID"`
(source: [[s-nats-server-share-import-observed]]). The tenant-facing hop is the one that matters.

**Across a leafnode the header names the leaf connection.** A header arriving over a leafnode is
replaced with "the identity of the authenticated leaf connection instead of trusting forwarded
values" (`client.go:4950–4954`), and `acc` is rewritten to the hub-side account name when the leaf's
account is mapped to a different one (`checkLeafClientInfoHeader`, `client.go:5756–5783`). A tenant
that reaches the service through its own leafnode server presents the leaf's user, never the end
client's (source: [[s-nats-server-service-imports]]; [[leafnode]]).

**A stream strips it.** Messages stored in a stream lose the header first — "For now remove.
TODO(dlc) - Should this be opt-in or opt-out?" (`stream.go:6354–6358`). A service that persists
requests and authorises later has to capture the identity on receipt
(source: [[s-nats-server-service-imports]]).

**JetStream itself runs on it.** The system account's `$JS.API.>` import into every JetStream-enabled
account is forced to `share = true` (`jetstream.go:787–797`), and the JetStream API lets a request
without the header through only from the system account (`jetstream_api.go:809–815`). The mechanism is
not an add-on: it is how the API knows which account and user is asking ([[js-api]])
(source: [[s-nats-server-service-imports]]).

## What configures it

**`share` is a field of the importing account's import, and of nothing else.** In the account JWT it
is `Import.Share` (JSON `share`), valid on **service** imports only — on a stream import the library
rejects it with `sharing information (for latency tracking) is only valid for services`
(source: [[s-jwt-imports-exports-activation]]). The exporting account cannot require it or see
whether it is set, except by what arrives in the header.

| where | how |
|---|---|
| `nsc` | `nsc add import --service --src-account <key> --remote-subject <subject> --share` — "share data when tracking latency (service only)" (source: [[s-nsc-imports-exports-activation]]) |
| `nats auth` 0.4.0 | `nats auth account imports add <name> <subject> <account> --service --source <key> --share` — "Shares connection information with the exporter" (source: [[s-natscli-auth-exports-imports]]) |
| config mode | `share: true` on the import; applied by `nats-server --signal reload=<pid>` to a live import without a reconnect (source: [[s-nats-server-share-import-observed]]) |

```
accounts {
  SVC: {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.remote", accounts: [APP] } ]
  }
  APP: {
    users: [ { user: app, password: app } ]
    imports: [ { service: { account: SVC, subject: "svc.remote" }, to: "svc.local", share: true } ]
  }
}
```

The config key is **documented on no page of docs.nats.io** — the generated reference lists `stream`,
`service`, `prefix` and `to` for an import and nothing else — recorded as docs issue #79
(source: [[s-docs-config-accounts-exports-imports]]).

## Limits and failure modes

- **The header can push a request over `max_payload`, and the maintainers lean towards leaving it
  so.** The size check runs on the inbound `PUB`; the header is added afterwards with no second check
  (`client.go:4989–4993`). Observed on 2.14.6: `max_payload: 256`, a 250-byte request accepted,
  delivered as `HMSG … 257 507` — 257 header bytes, 507 in total. Issue #8271 is open, its fix PR
  #8278 unmerged, and the two maintainers on the PR wrote that `max_payload` "is generally about what
  the client sends not what the server needs to add to it for tracking purposes" and that silently
  dropping requests after ingest is worse. Budget for it: about 250 bytes in config mode, plus the
  user JWT's length in operator mode, below `max_payload` (source:
  [[s-issue-8271-request-info-max-payload]]; [[s-nats-server-share-import-observed]]; [[publishing]]).
- **Before 2.11.15 / 2.12.6 a leafnode could spoof it** — CVE-2026-33246, medium, "Workarounds:
  None". Any server that authorises on the header must be at or past those releases on every node a
  leafnode can reach (source: [[s-ghsa-2026-08-request-info-spoofing]]).
- **What a tenant hands over.** With `share: true` every request carries the client host, the
  connection name, the client library and version, and in operator mode the user's full JWT. Say so
  when you ask a tenant to enable it.
- **`share` on a stream import is silently accepted in config mode.** `nats-server -t` calls the
  config valid; the parser applies the key to service imports only, so it does nothing — where the
  JWT library rejects the same thing (`inbox/server-issues.md` SI-6)
  (source: [[s-nats-server-share-import-observed]]).
- **`name` is not identity.** It is whatever the client put in its `CONNECT`; authorise on `acc` and
  `user` (or `jwt`), never on `name`.

## Designing a multi-tenant service on it

The shape that works: the service in its **own account**; every tenant account **imports** the
service's export; per-tenant identity from `acc`, per-user identity from `user` — which needs
`share: true` on *that tenant's* import, and nothing on the service's side. Consequences:

- **Treat a header without `user` as "this tenant did not opt in"** and fail the per-user path
  explicitly. Do not fall back to account-level grants silently; the difference is invisible
  otherwise.
- **Verify the opt-in at onboarding** with a probe request and a check for `user` in the header,
  rather than trusting the import was written correctly.
- **Chains and leafnodes both change who the header names.** A tenant behind an intermediate
  account is identified by the first hop's `share`; a tenant behind a leafnode is identified as the
  leaf connection.
- **Who may import at all** is the export's business, not the header's — the three guards (a
  config-mode `accounts` list, an activation token per importer, `account_token_position`) are on
  [[cross-account-sharing]]; in operator mode only the last two exist.

## Version notes

- **Present at v2.10.0**: the header name (`accounts.go:132`) and `share = claim.Share` (`:1919`);
  the arrival is older than the release archive this wiki holds
  (source: [[s-nats-server-service-imports]]).
- **2.11.15 / 2.12.6**: CVE-2026-33246 fixed — a header forwarded by a leafnode is rebuilt from the
  leaf connection's identity; the release body's line is "Messages from leafnodes to non-shared service
  imports now correctly rebuild the request info header" (source:
  [[s-ghsa-2026-08-request-info-spoofing]]).
- **2.14.6**: the `max_payload` overshoot (#8271) is unfixed; verified by a run.

## Related

[[cross-account-sharing]] · [[account]] · [[operator-mode]] · [[leafnode]] · [[js-api]] ·
[[publishing]] · [[nsc]] · [[nats-cli]] · [[auth-callout]] · [[system-subjects]]

## Sources

[[s-nats-server-service-imports]] · [[s-nats-server-share-import-observed]] ·
[[s-jwt-imports-exports-activation]] · [[s-nsc-imports-exports-activation]] ·
[[s-natscli-auth-exports-imports]] · [[s-issue-8271-request-info-max-payload]] ·
[[s-ghsa-2026-08-request-info-spoofing]] · [[s-docs-config-accounts-exports-imports]] ·
[[s-nats-server-system-subjects-observed]]
