<!-- source: https://github.com/nats-io/nats-server/issues/8271 and https://github.com/nats-io/nats-server/pull/8278 (GitHub GraphQL API: repository.issue, repository.pullRequest with comments, reviews and cross-references) · fetched 2026-09-03 -->
# nats-server issue #8271 — Service-import request metadata can exceed max_payload

State: OPEN — opened 2026-06-07 by @0xasritha · labels: stale, defect · closed: — · cross-referenced by PR #8278 (OPEN, merged: —)

## Original post

### Observed behavior

NATS enforces `max_payload` when parsing an inbound client `PUB` or `HPUB` operation. For header-bearing messages, this check uses the total inbound message size declared by the client.

When the message matches a service import, the service-import path adds a `Nats-Request-Info` header before delivering the request into the destination account. That internal header addition can make the delivered message larger than the configured `max_payload`, but the service-import path does not repeat the payload-size check after adding the metadata.

The result is that a request accepted at ingress because it is just under `max_payload` can be delivered to the imported service after server-added metadata has pushed it over the same limit.

This was reproduced with a normal NATS client request. With `max_payload: 128`, a caller in the importing account successfully published a 128-byte request to the imported service. The service-side subscriber then received an `HMSG` with a 62-byte header block and a 190-byte total message size after the server added `Nats-Request-Info`.

This requires:

- a configured service import;
- a low or tight `max_payload` setting; and
- an imported service request whose original size is under the limit but close
  enough that `Nats-Request-Info` pushes the delivered message over the limit.

### Expected behavior

`max_payload` should be enforced consistently for messages delivered by the server, including messages modified by service-import processing.

If service-import metadata makes a request exceed `max_payload`, the server should reject or drop the imported request instead of delivering an oversized message to the destination account.


### Server and client version

nats-server version: v2.15.0-dev
nats-server source commit: 63537e843269
nats.go client: v1.51.0
go version: go1.25.10 darwin/arm64


### Host environment

OS: Darwin 25.4.0
Arch: arm64
Runtime: local nats-server checkout, no container runtime required


### Steps to reproduce

Verified validation procedure:

1. Start a local `nats-server` with a small `max_payload`.

2. Configure two accounts:

```text
SERVICE:
  owns a service responder on svc.remote

CALLER:
  imports SERVICE's svc.remote as svc.local
```

Programmatically, the relevant setup is equivalent to:

```go
serviceAcc, _ := s.RegisterAccount("SERVICE")
callerAcc, _ := s.RegisterAccount("CALLER")
require_NoError(t, callerAcc.AddServiceImport(serviceAcc, "svc.local", "svc.remote"))
```

3. Connect one client in `SERVICE` and subscribe to `svc.remote`.

4. Connect one client in `CALLER`.

5. From the caller client, publish a request on `svc.local` with a message whose
   inbound total size is less than or equal to `max_payload`, but close to the
   limit. For example, choose the payload size so that:

```text
original request size <= max_payload
original request size + generated Nats-Request-Info header > max_payload
```

6. Inspect the message received by the `SERVICE` responder. A direct way to
   validate the defect is to subscribe with a raw header-capable client and read
   the delivered protocol frame:

```text
HMSG svc.remote 1 _INBOX.issue16 62 190
```

For the verified reproduction, the caller used `nats.go` to send:

```go
payload := bytes.Repeat([]byte("A"), 128)
err := nc.PublishRequest("svc.local", "_INBOX.issue16", payload)
```

Vulnerable behavior: the `SERVICE` subscriber receives the imported request with the added `Nats-Request-Info` metadata, and the resulting delivered message is larger than the configured `max_payload`. In the verified reproduction, the inbound request payload was 128 bytes, `max_payload` was 128 bytes, and the delivered `HMSG` total size was 190 bytes.

Expected behavior: once the service-import metadata is added, the server should apply the same payload ceiling and reject or suppress delivery if the final message exceeds `max_payload`.

No JetStream stream or consumer is required for this reproduction.

## Comment by @0xasritha — 2026-06-07T23:46:20Z

Opened a patch PR for this at #8278.

Implemented:
- check the expanded service-import request size after `Nats-Request-Info` is added
- suppress oversized imported requests and clean up the temporary response import
- regression coverage for an ingress-valid request that exceeds `max_payload` after service-import metadata

PR: https://github.com/nats-io/nats-server/pull/8278


---

# Pull request #8278 — Enforce service import max payload

State: OPEN — opened 2026-06-07 by @0xasritha · merged: — · closed: — · files changed: 3 · reviews: @chatgpt-codex-connector COMMENTED 2026-06-08

## Description

Closes #8271

## Summary
- Check the expanded service-import request size after `Nats-Request-Info` is added.
- Suppress oversized imported requests and clean up temporary response imports.
- Add regression coverage for a request accepted at ingress that exceeds `max_payload` after service-import metadata.

## Testing
- go test ./server -run '^TestServiceImportRequestInfoRespectsMaxPayload$' -count=1
- go test ./server -run '^TestServiceImport' -count=1
- go test ./server -run '^TestAccountDuplicateServiceImportSubject$' -count=1
- git diff --check
- go build
- golangci-lint run --timeout=5m --config=.golangci.yml ./server

Review: `codex review --base upstream/main` reported no actionable findings.

## Comment by @MauriceVanVeen — 2026-06-08T07:07:14Z

Could you apply the following patch, since `TestNoRaceJetStreamStreamInfoSubjectDetailsLimits` currently fails?

```diff
diff --git a/server/norace_1_test.go b/server/norace_1_test.go
index 5e1ffa26b..5263ec709 100644
--- a/server/norace_1_test.go
+++ b/server/norace_1_test.go
@@ -4274,7 +4274,7 @@ func TestNoRaceJetStreamStreamInfoSubjectDetailsLimits(t *testing.T) {
                  default: {
                        jetstream: true
                        users: [ {user: me, password: pwd} ]
-                       limits { max_payload: 512 }
+                       limits { max_payload: 768 }
                  }
                }
        `, t.TempDir())))
@@ -4291,11 +4291,11 @@ func TestNoRaceJetStreamStreamInfoSubjectDetailsLimits(t *testing.T) {
        // Make sure to flush so we process the 2nd INFO.
        nc.Flush()
 
-       // Make sure we cannot send larger than 512 bytes.
+       // Make sure we cannot send larger than 768 bytes.
        // But we can receive larger.
        sub, err := nc.SubscribeSync("foo")
        require_NoError(t, err)
-       err = nc.Publish("foo", []byte(strings.Repeat("A", 600)))
+       err = nc.Publish("foo", []byte(strings.Repeat("A", 800)))
        require_Error(t, err, nats.ErrMaxPayload)
        sub.Unsubscribe()
```

@claude, brief review.

## Comment by @synadia-claude-reviewer — 2026-06-08T07:07:28Z

**Claude finished @MauriceVanVeen's task in 1m 44s** —— [View job](https://github.com/nats-io/nats-server/actions/runs/27121578199)

---
### Tasks

- [x] Gather context
- [x] Read `server/norace_1_test.go` around the target test
- [x] Apply patch (`max_payload: 512 → 768`, payload `600 → 800`)
- [ ] ~~Commit and push~~ — push failed (bot lacks write permission to `nats-io/nats-server`)
- [x] Brief review

---

### Patch applied locally — push blocked

The patch was applied correctly and matches the provided diff exactly. A commit was created, but pushing to the branch was denied:

```
remote: Permission to nats-io/nats-server.git denied to synadia-claude-reviewer[bot].
```

The three-line change is straightforward to apply manually:

```diff
-			limits { max_payload: 512 }
+			limits { max_payload: 768 }
```
```diff
-	// Make sure we cannot send larger than 512 bytes.
+	// Make sure we cannot send larger than 768 bytes.
 	sub, err := nc.SubscribeSync("foo")
 	require_NoError(t, err)
-	err = nc.Publish("foo", []byte(strings.Repeat("A", 600)))
+	err = nc.Publish("foo", []byte(strings.Repeat("A", 800)))
```

---

### Brief review

**Why the test breaks.** `TestNoRaceJetStreamStreamInfoSubjectDetailsLimits` sends JetStream API requests (e.g., `$JS.API.STREAM.INFO.TEST`) which route through service import. The new enforcement in `processServiceImport` (`client.go:4956–4961`) now calls `serviceImportMaxPayloadExceeded()` **after** `setHeader` has appended the `Nats-Request-Info` / `ClientInfoHdr` header and updated `c.pa.size` to the expanded size. A JetStream stream info request carrying `SubjectsFilter: "X.*"` with `JSMaxSubjectDetails` entries is pushed over the 512-byte limit by the added header bytes, causing the call to be silently suppressed and the test to hang or fail.

**Is the fix correct?** Yes. Raising the account limit to 768 provides enough headroom for the header while keeping the rest of the test meaningful:
- The direct-publish assertion (`Publish("foo", 800 bytes)`) still exceeds the 768-byte limit, so the client-side rejection path continues to be exercised.
- The JetStream API requests (which grow legitimately due to the added header) now fit within the limit and the stream info response can come back.

**Minor observations:**
1. The 768 value is not documented with a comment explaining _why_ that number was chosen (e.g. "JS stream-info request + ClientInfo header ≈ N bytes; 768 gives ~100 bytes headroom"). That would make a future regression more understandable, but it's a minor nit.
2. The test still passes the old limit logic end-to-end — it verifies both the "reject on direct oversized publish" and the "accept on larger receive" paths, so the intent is preserved.

The patch is correct and minimal. No other concerns.

## Comment by @MauriceVanVeen — 2026-06-08T09:25:49Z

I'm starting to doubt whether this should be done.. the max payload is already checked at least once, and it is generally about what the client sends not what the server needs to add to it for tracking purposes. Here the request is then also essentially silently swallowed.

@neilalexander, what do you think?

## Comment by @neilalexander — 2026-06-15T16:53:41Z

I'd be inclined to agree, I don't think it's good if requests are silently dropped after ingest into the system. I think the question is more whether or not they might traverse an account boundary and then hit a payload limit on an upstream connection type, but to my knowledge this hasn't been an issue to this point. @derekcollison would probably have more thoughts on this too.
