---
title: "The connection closed after an auth error and never came back"
type: gotcha
area: [clients, security]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6, nats.go v1.53.1, nats CLI 0.4.0
verified-on: 2026-09-04
tags: [creds, jwt-expiry, authorization-violation, user-authentication-expired, IgnoreAuthErrorAbort, credential-rotation, revocation]
aliases: ["User Authentication Expired", "Account Authentication Expired", "Authorization Violation", "nats: authentication expired", "IgnoreAuthErrorAbort", "auth error abort"]
sources: [s-docs-resilient-clients-tls-and-auth, s-nats-go-subscription, s-nats-server-client-errors, s-nats-server-client-faults-observed, s-docs-system-errors, s-nats-go-connection]
created: 2026-09-04
updated: 2026-09-04
---

# The connection closed after an auth error and never came back

An application that had been running for hours goes to CLOSED within seconds and stays there, while
the `nats` CLI on the same credentials appears to carry on. Both are behaving as designed: an
authentication error is the one failure the reconnect loop deliberately refuses to retry forever,
and the CLI opts out of that rule.

## Symptom

On the connection's error callback, then the closed handler, inside about four seconds:

```
ErrorHandler: nats: authentication expired   (status CONNECTED)
Disconnected: err=EOF  (status RECONNECTING)
ErrorHandler: nats: authorization violation   (status RECONNECTING)
ErrorHandler: nats: authorization violation   (status CLOSED)
CLOSED. LastError=nats: Authorization Violation
```

On the wire, at the instant of expiry (source: [[s-nats-server-client-faults-observed]], B1):

```
-ERR 'User Authentication Expired'
```

then EOF. In the server log:

```
[DBG] … - User Authentication Expired - Account:ADR2…/APP - jwt:UCBL…
[DBG] … - Client connection closed: Authentication Expired
```

The same shape with `-ERR 'Account Authentication Expired'` when it is the **account** JWT that
expired (B5) — one account expiring closes every connection in it at once
(source: [[s-nats-server-client-errors]]).

## Quick triage

```
# 1. What did the server think? The reason survives the connection.
curl -s 'http://127.0.0.1:8222/connz?state=closed' | jq '.connections[] | {name, reason, stop}'
```

`Authentication Expired` distinguishes an expiry from `Authentication Failure`
(`AuthenticationViolation`) and from `Revocation`. The wire string does **not**: every rejection
other than the four credential paths is sent as the single `Authorization Violation`, "regardless of
the authErr override" (source: [[s-nats-server-client-errors]]).

```
# 2. Is the credential actually expired?
nats context validate                       # if the creds live in a context
# or, on the stored user (nats auth, 0.4.0):
nats auth user info order-svc ORDERS        # the stored user's expiry, if any
```

([[nsc]] has the `nsc` equivalents, and [[operator-mode]] the rule that a user JWT from
`nats auth user add` never expires — only `nats auth user credential … --expire` mints one that does.)

```
# 3. Does a fresh connection get in at all?
nats server check connection --creds ./order-svc.creds -s nats://n1:4222
```

If step 3 succeeds, the credentials are fine now and the closed connection is history: the client
gave up during a window that has since passed.

## Causes, ranked

### 1. The user JWT expired while the connection was live

The server arms a timer at the JWT's expiry and fires it on the *connected* client
(`setExpiration` → `time.AfterFunc(d, c.authExpired)`, source: [[s-nats-server-client-errors]]).
That is the first `-ERR`; the socket closes; the client reconnects; the reconnect is rejected; the
client aborts.

**Confirm**: `/connz?state=closed` shows `Authentication Expired`, and the client's first error was
`nats: authentication expired` **while still CONNECTED** — not on a reconnect.

**How long you actually have**, measured on 2.14.6 with nats.go v1.53.1
(source: [[s-nats-server-client-faults-observed]], B3 and B6):

| `ReconnectWait` | reconnect attempts before the abort | time from expiry to CLOSED |
|---|---|---|
| 500 ms | **1** | 0.51 s |
| 2 s (the nats.go default) | **2** | 4.12 s |

The count is not fixed because the *server's answer changes with time*. `jwt/v2` checks
`now > Expires` at **one-second resolution**, so a reconnect landing inside the expiry second is
accepted and then expired at once with `User Authentication Expired` again — the same error from the
same server, which aborts immediately. A second later the JWT fails validation at CONNECT and the
answer becomes `Authorization Violation` — a *different* error, so that attempt is retried, and the
abort comes on the one after.

**Fix**: refresh before expiry. Either a credential callback (`UserJWT(userCB, sigCB)` in nats.go, an
authenticator in nats.js, `user_jwt_cb`/`signature_cb` in nats.py, an `AuthHandler` in nats.java,
`ConnectOptions::with_auth_callback` in nats.rs, `NatsAuthOpts.AuthCredCallback` in nats.net —
source: [[s-docs-resilient-clients-tls-and-auth]]), or issue user JWTs that do not expire and rely on
revocation instead. Do **not** plan on the retry window: it is one or two attempts wide.

### 2. The rule is "the same error twice from the same server", not "two auth errors"

nats.go's abort:

```go
	if nc.current.lastErr == err && !nc.Opts.IgnoreAuthErrorAbort {
		nc.ar = true
	} else {
		nc.current.lastErr = err
	}
```

`nc.current` is the pool entry being tried (source: [[s-nats-go-subscription]]). Two *different*
auth errors do not abort; two identical ones from two *different* servers do not abort. The abort
applies **regardless of the retry budget** — unlimited reconnects do not override it
(source: [[s-docs-resilient-clients-tls-and-auth]]).

`learn/resilient-clients/connection-events.md:244` states this as "receiving the same authentication
error twice", dropping the per-server part; that is docs issue #93.

Not every client has the rule at all:

| client | on a repeated auth error |
|---|---|
| nats.go, nats.js, nats.java, nats.net | **abort** — the connection closes (nats.net names the state `Failed`) |
| nats.py | no abort — cycles until every server exceeds `max_reconnect_attempts` (60 by default) |
| nats.rs | no abort — cycles until `max_reconnects` runs out (unlimited by default) |
| `nats` CLI | no abort — it sets `IgnoreAuthErrorAbort` **and** unlimited reconnects |

(source: [[s-docs-resilient-clients-tls-and-auth]]; the full table is on [[client-defaults]].)

### 3. The CLI looks fine and is not

Under the same expired credential, `nats sub` printed **two lines in 45 seconds** — the subscribe
line and `>>> Disconnected due to: EOF, will attempt reconnect` — while the server rejected it
**eleven times** (source: [[s-nats-server-client-faults-observed]], B2). It never names the reason
and never stops. So "the CLI still works" is not evidence that the credential is valid, and "the CLI
is quiet" is not evidence that nothing is wrong. Check the *server's* log or `/connz`, not the CLI's
output.

### 4. The credential was revoked rather than expired

A revoked user gets `-ERR 'User Authentication Revoked'` (`accounts.go:3991`, `:4006`, `:4012`) and
closes with the `Revocation` reason. nats.go maps it to `ErrAuthRevoked`, which goes through the same
abort rule (source: [[s-nats-go-subscription]]). Nothing you do on the client fixes this — the
account's revocation list has to change, and the account JWT has to reach the server's resolver.
See [[operator-mode]].

### 5. The creds file was rotated in place and read half-written

nats.go re-reads the `.creds` file on **every** connect and reconnect attempt: `UserCredentials`
stores callbacks, and `userFromFile` does `os.ReadFile` inside one of them
(source: [[s-nats-go-subscription]]). A reconnect that lands mid-write reads a partial file, fails
to parse it, and never sends a `CONNECT` — a client-side load error, retried as a transient failure.
It recovers on its own, but the window is avoidable.

**Fix**: write the new file to a temporary path in the same directory and `rename` it into place, so
a reader sees either the old file or the new one. The clients that load once (nats.js, nats.rs,
nats.net) will not see the new file at all without a credential callback
(source: [[s-docs-resilient-clients-tls-and-auth]]).

### 6. A permissions error mistaken for this one

`-ERR 'Permissions Violation for Subscription to "orders.>"'` is **not** an auth error and does not
close the connection: nats.go routes it through `processTransientError`, which fires the callback
and records the failure on the one subscription (source: [[s-nats-go-subscription]]). If your
connection is alive but one subject is silent, read [[subject-permissions]], not this page. The
same applies to a client whose subscribe permissions do not cover `_INBOX.>` — that needs
`CustomInboxPrefix`, not new credentials (see [[request-reply]]).

## Prevention

- **Rotate by draining onto a new connection**, not by overwriting a file under a live one. A live
  connection keeps the identity it authenticated with; the change only takes effect at the next
  connection cycle (source: [[s-docs-resilient-clients-tls-and-auth]]).
- Wire the **closed handler**. In the four clients with the abort rule, CLOSED is terminal — nothing
  brings the connection back, and only the closed handler tells the application to fetch fresh
  credentials or exit.
- Alert on `/connz?state=closed` reasons `Authentication Expired`, `Authentication Failure` and
  `Revocation` rather than on client logs; the wire string is deliberately uninformative.
- Give user JWTs an expiry **longer** than your rotation interval, and rotate on a schedule rather
  than on failure.
- Do not set `IgnoreAuthErrorAbort` to "make it more resilient": it converts a clear terminal state
  into an endless rejected-reconnect loop — 46 attempts in 45 seconds, one rejection every ~0.55 s
  (source: [[s-nats-server-client-faults-observed]], B4).

## Explained by

[[client-connection-lifecycle]] — the reconnect loop this rule interrupts, and the CLOSED state;
[[operator-mode]] — where the JWT, the expiry and the revocation list come from.

## Related

- [[set-up-operator-mode]] — issuing and distributing the credentials
- [[rotate-tls-certificates]] — the other rotation, with the same "both sides" trap
- [[tls-in-nats]] — the CA failure that looks similar at the connect boundary and is not
- [[client-defaults]] — the per-client abort and reconnect table
- [[subject-permissions]] — the auth error that does *not* close the connection

## Sources

- [[s-docs-resilient-clients-tls-and-auth]] — the per-client abort rules and the rotation guidance
- [[s-nats-go-subscription]] — `processAuthError`, `checkAuthError`, `UserCredentials`
- [[s-nats-go-connection]] — the reconnect loop and `ReconnectWait`
- [[s-nats-server-client-errors]] — the four credential strings, `setExpiration`, the account timer
- [[s-nats-server-client-faults-observed]] — runs B1–B7 on nats-server 2.14.6
- [[s-docs-system-errors]] — the documented error tables, swept
