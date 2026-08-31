---
title: "gh#7684 — How to detect when the certificates used by nats-server will expire?"
type: summary
area: [security, monitoring, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7684
source-path: raw/gh-discussions/gh-7684.md
author: "@jingzhaoyang (asked); @jan-krueger (answer), @neilalexander, @sciascid"
article: "GitHub Discussion 7684 (Q&A)"
date: 2025-12-30          # opened; answer chosen 2026-01-07
version: ""              # no server version stated by the participants
tags: [tls, expiry, handshake_first, openssl, varz, letsencrypt, reload]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7684 — detecting certificate expiry on a running server

Opened 2025-12-30 with a production incident, answered a week later, and closed out by a maintainer
pointing at a feature that had just shipped. The thread is the reason
[[rotate-tls-certificates]] has a monitoring section at all.

## Key claims

**The incident.** "The Let's Encrypt certificate was renewed correctly, but `nats-server --signal
reload=1` failed to reload the certificate", and clients then got:

```
nats: error: x509: certificate has expired or is not yet valid
```

"After restarting the NATS Server, everything returned to normal." *(Nobody in the thread diagnosed
why the reload did not take; nothing in the discussion establishes that reload is broken in general,
and the wiki does not claim it is — see [[rotate-tls-certificates]].)*

**Why `openssl s_client` returns nothing.** The asker's check produced no date:

```
echo | openssl s_client -connect localhost:4222 2>/dev/null | openssl x509 -noout -enddate
```

@jan-krueger reproduced it. Without `handshake_first` the server logs

```
[ERR] ... TLS handshake error: tls: received record with version 301 when expecting version 303
```

because the first bytes on a default NATS TLS port are the plaintext `INFO` line, not a TLS record.

**Two workarounds, both from the accepted answer:**

1. Set `handshake_first: true` and the same command works:

   ```
   notAfter=Mar  8 09:34:31 2026 GMT
   ```

   though "the NATS server still logs a parser error:
   `Client parser ERROR, state=0, i=0: proto='""...'`".
2. **Point `openssl` at the HTTPS monitoring port instead.** "This avoids the protocol mismatch
   entirely and allows you to verify the TLS certificate without requiring `handshake_first` on the
   main client listener, if that is a concern."

The asker's constraint is the ordinary one: "the server has already been deployed to production,
making further configuration changes impossible."

**A maintainer proposed the real fix and another confirmed it shipped.**

> "I think we can probably add something into `varz` to expose this in a more friendly way, I agree
> that having to open a TLS connection to find it out is not ideal." — @neilalexander, 2026-01-07

> "Certificate expiration dates have been exposed through the varz monitoring end point. See
> <https://github.com/nats-io/nats-server/pull/7709>" — @sciascid, 2026-01-12

**The asker wrote a Go tool** that reads the `INFO` line, forces a TLS upgrade on the same socket and
prints `Not Before` / `Not After` and days remaining. It is in the thread verbatim; the wiki does not
reproduce it, because two better options exist (`/varz` and `nats account tls`).

## Practical takeaways

- **`openssl s_client` against port 4222 failing is not evidence that TLS is broken.** It is the
  expected result of NATS's default handshake order.
- **The `/varz` field the thread asked for exists at v2.14.6**: `tls_cert_not_after`, top-level and
  per connection type — verified in [[s-nats-server-auth-and-tls]]. Nobody in the thread names the
  field, and neither do the docs.
- **Nobody in the thread mentions `nats account tls`**, which does exactly this job at natscli
  v0.4.0: it reads the chain off the CLI's own NATS connection, so no `handshake_first` is needed,
  and it warns on anything expiring within `--expire-warn` (default `1w`) — see
  [[s-natscli-account-tls]]. *(Whether it existed when the thread was open has not been checked; the
  only version read is v0.4.0.)*
- **Watch the whole chain, not the leaf.** The incident was an expired end-entity certificate, but an
  expiring intermediate or CA fails the same way and `/varz` reports only the leaf.

## Notable quotes

> "I have implemented a certificate detection tool to manage the validity period verification."
> — @jingzhaoyang, on being unable to change a deployed config

## Relevance to the wiki

Half of Q50 — the *detection* half the docs' Encryption & TLS page does not cover — plus the
evidence for docs issue #20.

## Questions it answers

Q50 (with [[s-docs-encryption-and-tls]] and [[s-natscli-account-tls]]).

## Pages touched

[[rotate-tls-certificates]] · [[tls-in-nats]] · [[monitoring-endpoints]] · [[nats-cli]] ·
[[reload-server-config]]
