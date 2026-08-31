---
title: "nats-server v2.14.6 — authentication, TLS and the account trust chain"
type: summary
area: [security, monitoring, deploy]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/auth-tls-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/const.go, opts.go, auth.go, auth_callout.go, monitor.go, server.go, events.go, stream.go at v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [AUTH_TIMEOUT, TLS_TIMEOUT, tls_cert_not_after, verify_and_map, auth_callout, no_auth_user, external, api-prefix]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — authentication, TLS and the account trust chain

Read to settle six things the docs state loosely, wrongly, or not at all. Every claim below is a
line of `nats-server` at tag **v2.14.6**; the quoted ranges are in
`raw/nats-server-src/auth-tls-v2.14.6.md`.

## Key claims

### 1 · The auth and TLS handshake timeouts

```go
TLS_TIMEOUT  = 2 * time.Second   // const.go:108
AUTH_TIMEOUT = 2 * time.Second   // const.go:117
DEFAULT_TLS_HANDSHAKE_FIRST_FALLBACK_DELAY = 50 * time.Millisecond  // const.go:114
DEFAULT_LEAF_TLS_TIMEOUT = 2 * time.Second                          // const.go:165
```

```go
func getDefaultAuthTimeout(tls *tls.Config, tlsTimeout float64) float64 {   // opts.go:6191
	var authTimeout float64
	if tls != nil {
		authTimeout = tlsTimeout + 1.0
	} else {
		authTimeout = float64(AUTH_TIMEOUT / time.Second)
	}
	return authTimeout
}
```

**So `authorization { timeout }` has two defaults, not one: 2 seconds without TLS, and
`tls_timeout + 1` — 3 seconds at stock settings — with TLS.** `setDefaults` applies the same rule to
the client (`opts.go:6024`), cluster (`6034`), leafnode (`6079`) and gateway (`6147`) blocks.

**`tls { timeout }` defaults to 2 seconds on every listener that has one**: client (`6021`), cluster
(`6031`), leafnode (`6076`), gateway (`6144`), MQTT (`6166`), and a leafnode *remote*
(`DEFAULT_LEAF_TLS_TIMEOUT`, `opts.go:3155`). **`WebsocketOpts` has no `TLSTimeout` field at all** —
it carries `HandshakeTimeout` for the whole websocket handshake, and TLS is required unless `NoTLS`
is set.

The value parses as either "a float in seconds or a duration string" (`opts.go:5222–5232`).

### 2 · Certificate expiry is on the monitoring port

```go
TLSCertNotAfter time.Time `json:"tls_cert_not_after,omitzero"`   // monitor.go:1296
```

`/varz` carries **`tls_cert_not_after`** at the top level and once per connection type — the same
field name appears on the `cluster`, `gateway`, `leafnode`, `mqtt` and `websocket` sub-objects
(`monitor.go:1838–1845`). The value is the **`NotAfter` of the leaf certificate of the first
configured certificate** (`tlsCertNotAfter`, `monitor.go:1485–1498`); with no TLS on that listener
the zero time is omitted from the JSON (`omitzero`).

This shipped in [PR #7709](https://github.com/nats-io/nats-server/pull/7709) after
[[s-gh-7684-certificate-expiry]] asked for it. **No page in the 861-page docs mirror mentions the
field** — see docs issue #20.

### 3 · How `verify_and_map` picks a user

`auth.go:1345–1395` — the order the docs state, confirmed, with two details they omit:

1. `cert.EmailAddresses` (email SANs), 2. `cert.DNSNames`, 3. `cert.URIs` — each falls through to the
   next;
4. then the subject, matched first with `ldap.FromRawCertSubject` ("Match using the raw subject to
   avoid ignoring attributes"), then as an RDN sequence string.

- **Only the first peer certificate is considered.** With more, the server logs at debug level
  `Multiple peer certificates found, selecting first`.
- With no SANs and no subject: `User required in cert, none found`.
- Each successful branch logs at debug level which one matched —
  `Using email found in cert for auth`, `Using SAN found in cert for auth`,
  `Using URI found in cert for auth`, `Using DistinguishedNameMatch for auth`. **That debug line is
  the fastest way to see why a mapping went to the wrong user.**

### 4 · Auth callout does not check the client's credential

```go
*opts = jwt.ConnectOptions{                 // auth_callout.go:490
	JWT:         ujwt,
	Nkey:        o.Nkey,
	SignedNonce: o.Sig,
	Token:       o.Token,
	Username:    o.Username,
	Password:    o.Password,
	…
}
```

`fillConnectOpts` **copies what the client sent, verbatim, with no verification**. So
`connect_opts.nkey` in an authorization request is a claim, not a fact — the callout service must
verify it itself. The server does hand over the material to do so: when the client supplied a
signature, the server also fills in the nonce it issued —

```go
if claim.ConnectOptions.SignedNonce != _EMPTY_ {     // auth_callout.go:379
	claim.ClientInformation.Nonce = string(c.nonce)
}
```

so a service can verify `SignedNonce` over `Nonce` against `Nkey` and get the challenge-response the
server skipped. This is the exact answer [[s-gh-7505-auth-callout-nkey]] asked for.

Other facts from the same file:

- the subject is `AuthCalloutSubject = "$SYS.REQ.USER.AUTH"` and the encryption header is
  `AuthRequestXKeyHeader = "Nats-Server-Xkey"` (`auth_callout.go:30–32`);
- **the callout deadline is `authorization { timeout }`** — `authTimeout := secondsToDuration(
  s.getOpts().AuthTimeout)`, used both as the request claim's expiry and as the reply wait
  (`auth_callout.go:371`, `:447`);
- the `AuthCallout` config struct is exactly five fields: `Issuer`, `Account`, `AuthUsers`, `XKey`,
  `AllowedAccounts` — "If empty then all accounts will be delegated" (`opts.go:394–407`).

### 5 · Why "unauthenticated clients still connect" after adding accounts

```go
// If we have defined a system account here check to see if its just us and the $G account.
// … Only do this if non-operator mode and we did not have an authorization block defined.
if len(opts.TrustedOperators) == 0 && numAccounts == 2 && opts.NoAuthUser == _EMPTY_ && !opts.authBlockDefined {
	…
	uname = fmt.Sprintf("nats-%s", b[:])
	opts.Users = append(opts.Users, &User{Username: uname, Password: uname[6:], Account: s.gacc})
	opts.NoAuthUser = uname
}
```
`server.go:1445–1462`

**The server fabricates a user in `$G` and points `no_auth_user` at it** when all four conditions
hold: not operator mode, exactly two accounts (the system account and `$G`), no `no_auth_user` set,
and **no top-level `authorization` block**. That is the whole mechanism behind "adding a `$SYS`
account reopened my server".

The fabricated user is then treated specially in the `INFO` line:

```go
if info.AuthRequired && opts.NoAuthUser != _EMPTY_ && opts.NoAuthUser != s.sysAccOnlyNoAuthUser {
	info.AuthRequired = false
}
```
`server.go:3290`

so **`auth_required` stays `true`** for it — the server advertises that authentication is required
and admits unauthenticated clients anyway. It is also skipped by the plaintext-password warning
(`auth.go:259`).

Adding *any* second real account, or a top-level `authorization` block, takes `numAccounts` past 2 or
sets `authBlockDefined`, and the branch does not fire. The `authBlockDefined` condition is the fix
from [[s-gh-4535-unauthenticated-connections]].

### 6 · JetStream on the system account, and reaching a stream in another account

```go
if sa := s.SystemAccount(); sa != nil && len(sa.jsLimits) > 0 {
	s.Fatalf("Not allowed to enable JetStream on the system account")
}
```
`server.go:2429` — a **fatal**, at boot, not a warning.

```go
// ExternalStream allows you to qualify access to a stream source in another account or domain.
type ExternalStream struct {
	ApiPrefix     string `json:"api"`
	DeliverPrefix string `json:"deliver"`
}
```
`stream.go:425–429`, reachable as `external` on both `StreamSource` and the mirror config. The
prefix is applied by textual substitution on the API subject:

```go
subject = strings.Replace(subject, JSApiPrefix, source.External.ApiPrefix, 1)   // stream.go:2818
```

`ExternalStream.Domain()` reads the domain out of `api` as its **second token**
(`tokenAt(ext.ApiPrefix, 2)`), which is why a domain prefix is written `$JS.<domain>.API`.

Three error codes guard it: **10021** `stream external api prefix {prefix} must not overlap with
{subject}`, **10022** `stream external delivery prefix {prefix} overlaps with stream subject
{subject}`, **10024** `stream external delivery prefix {prefix} must not contain wildcards`
(`server/errors.json` at the same tag).

### 7 · The account-claims subjects

```go
accLookupReqSubj = "$SYS.REQ.ACCOUNT.%s.CLAIMS.LOOKUP"
accPackReqSubj   = "$SYS.REQ.CLAIMS.PACK"
accListReqSubj   = "$SYS.REQ.CLAIMS.LIST"
accClaimsReqSubj = "$SYS.REQ.CLAIMS.UPDATE"
accDeleteReqSubj = "$SYS.REQ.CLAIMS.DELETE"
```
`events.go:43–47`

`$SYS.REQ.CLAIMS.UPDATE` is what an account push publishes to — the subject that times out when a
push fails ([[s-gh-7854-jwt-push-timeout]]).

## Practical takeaways

- Alert on `/varz`'s `tls_cert_not_after` rather than opening a TLS connection to the client port;
  the port only answers `openssl s_client` when `handshake_first` is on.
- Budget the callout service's latency against `authorization { timeout }` — the same key, and its
  default is 3s when TLS is configured, not 2s.
- A server whose only declared account is the system account is open, and its `INFO` says otherwise.
- Debug logging is the only way to see which certificate field `verify_and_map` matched on.

## Relevance to the wiki

The authority behind docs issues **#19**, **#20** and **#21**, and the verified backbone of
[[tls-in-nats]], [[auth-callout]], [[rotate-tls-certificates]],
[[unauthenticated-clients-still-connect]] and [[cross-account-sharing]].

## Questions it answers

Q50, Q53, Q56, Q51 (partly), Q90 (partly).

## Pages touched

[[tls-in-nats]] · [[auth-callout]] · [[rotate-tls-certificates]] ·
[[unauthenticated-clients-still-connect]] · [[cross-account-sharing]] · [[monitoring-endpoints]] ·
[[defaults-and-limits]] · [[config-keys]] · [[error-codes]] · [[account]]
