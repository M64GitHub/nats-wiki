<!-- source: https://docs.nats.io/learn/resilient-clients/request-reply-resilience.md · fetched 2026-08-31 · section: request-reply-resilience -->
# Request-Reply Resilience

So far this chapter has hardened the connection underneath one-way traffic: `order-svc` publishes orders, and the subscribers receive them. But `order-svc` also asks questions. Before it confirms an order it sends a request on `orders.inventory.check` and waits for the `inventory` responder to answer. A fault on that call has the biggest impact, because the application is blocked on the reply.

Core NATS already taught you the mechanics of request-reply: the client sends a request, the responder answers on a private `_INBOX` subject, and the reply is routed back to the requester. Clients can change the `_INBOX` prefix (nats.js calls the option `inboxPrefix`; Go calls it `CustomInboxPrefix`). That matters when a user's permissions are restricted: a client whose subscribe permissions don't cover the default `_INBOX.>` can't receive replies, so the operator grants subscribe permission on a dedicated prefix and the client sets it ([Security → Authorization](/learn/security/authorization.md#restricting-order-svc) covers the permission side). This page assumes that machinery and covers what happens when the reply doesn't come. A request can fail in two different ways, and the two mean different things, so the client must tell them apart before it retries.

This page introduces two new ideas: telling the two failures apart (a timeout versus the no-responders signal), and retrying safely (backoff plus idempotency). We'll define each before we use it.

## A request has three outcomes

A bare `request` from Core NATS sends a subject and a payload and waits under a **timeout**: the deadline by which a reply must arrive. Some clients take the deadline on the call, others set it once on the connection. Wait on it and exactly one of three things happens.

The first is the happy path: the `inventory` responder answers, and the reply comes back inside the deadline. The application reads it and moves on.

The second is a timeout. The deadline passes with no reply. A timeout doesn't mean the responder is gone, only that no answer arrived *in time*. The `inventory` responder may be up but slow, for example because of a long database query, a GC pause, or a burst of load. The request was delivered to a matching subscription; the reply just didn't come back in time.

The third is **no responders**. The moment the client sends the request, the server already knows whether any subscription is listening on `orders.inventory.check`. If none is, the server sends back an immediate no-responders signal (a 503 status with no body) and the request call returns at once instead of waiting out the timeout. No responder means the `inventory` service isn't running, isn't registered, or its account can't see the subject. Rather than a slow answer, this means there is no one to answer.

Here's `order-svc` asking the inventory question with a timeout set. The CLI prints the reply on success. If the deadline passes it exits without printing a reply, and if nobody is listening it prints `No responders are available` at once:

#### CLI

```
#!/bin/bash

# order-svc asks the inventory question and waits for a reply, with a

# timeout that bounds how long it blocks.

#

# A request has exactly three outcomes:

#   - a reply arrives inside the deadline       -> printed below

#   - the deadline passes with no reply         -> a timeout

#   - no subscription is listening              -> an immediate 503

#                                                  (no responders)

#

# --timeout sets the deadline. Keep it at two or three times the

# responder's p99 latency so a slow-but-healthy answer is not mistaken

# for a fault. Most client libraries surface the same three outcomes as a

# reply, a timeout error, and a no-responders error; Java needs the

# reportNoResponders() connect option and the future-based request to tell

# the two failures apart.



nats request orders.inventory.check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --timeout 2s
```

#### C

```
// Ask the inventory question with a two-second deadline. Exactly one

// of three things happens: a reply arrives in time, the deadline

// passes (NATS_TIMEOUT), or nobody is listening and the server says

// so at once (NATS_NO_RESPONDERS).

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

switch (s)

{

    case NATS_OK:

        printf("inventory replied: %.*s\n",

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

        natsMsg_Destroy(reply);

        break;

    case NATS_TIMEOUT:

        // The responder is there but slow; no answer arrived in time.

        printf("inventory did not answer within the deadline\n");

        break;

    case NATS_NO_RESPONDERS:

        // Nothing subscribes to the subject; this returns immediately.

        printf("no inventory responder is running\n");

        break;

    default:

        printf("request failed: %s\n", natsStatus_GetText(s));

        break;

}
```

The request carries the same canonical order shape used everywhere in this chapter:

```
{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}
```

Here we cover only the options that change how a request behaves under fault; the exact option names and defaults live in your client's API reference, while [Reference](/reference/.md) covers the wire protocol and server configuration.

## Why no-responders is useful

You might treat both failures as the same missing answer and stop there. But the no-responders signal is the most useful failure NATS gives you, because it's fast and certain. Without it, a request to a subject nobody listens on would sit until the timeout expired: two seconds of the application blocked, without learning anything it didn't already know.

With it, the client finds out in a single round trip that there's no `inventory` responder at all. That lets the two failures drive different behavior. A timeout means someone is there, so the client should try again soon. No responders means nobody is there yet, so the client should give them a moment to start. The retry strategy in the next section turns that distinction into code.

The animation below shows the difference. One request times out, waits, retries, and finally gets a reply; the no-responders path returns the instant it's sent:

**Message flow — Request timeout and retry (animated):** Two outcomes for a request. When the inventory responder is present but slow, the first request times out with no reply, the client waits a backoff, retries, and the retry gets a reply. When no responder is subscribed at all, the server returns a no-responders 503 immediately instead of leaving the caller to wait for a timeout.

* order-svc → server
* server → inventory
* inventory → server (subject: reply)
* server → order-svc
* order-svc → server (subject: timeout — no reply)
* server → order-svc (subject: 503 no responders)
* order-svc → order-svc (subject: backoff…)

The no-responders signal needs a server new enough to send the 503 and a client that advertised support for it during the connect handshake. Both have been the default for years; you get it for free on any current setup. You can see it yourself by requesting a subject nobody answers:

#### CLI

```
#!/bin/bash

# See the no-responders signal for yourself.

#

# Request a subject that nobody is listening on. With no inventory

# responder running, the server knows immediately that no subscription

# exists on orders.inventory.check, and returns a 503 no-responders

# signal at once -- the request does NOT wait out the --timeout.

#

# Run this with no `nats reply orders.inventory.check ...` running, and

# the CLI prints the no-responders error right away. Start a responder

# and the same request gets an answer instead. Most client libraries

# surface this as a distinct no-responders error you can branch on,

# separate from a timeout; in Java you opt in with

# Options.Builder.reportNoResponders() and use the CompletableFuture-based

# request.



nats request orders.inventory.check \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \

  --timeout 2s
```

#### C

```
// Request a subject nobody is listening on. The server knows no

// subscription matches orders.inventory.check and sends back a 503

// at once: the call returns NATS_NO_RESPONDERS immediately instead

// of waiting out the two-second deadline.

const char *order = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                    "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

natsMsg    *reply = NULL;



s = natsConnection_RequestString(&reply, conn, "orders.inventory.check",

                                 order, 2000);

if (s == NATS_NO_RESPONDERS)

    printf("no responders: the inventory service is not running\n");

else if (s == NATS_OK)

{

    // Start a responder on orders.inventory.check and the same

    // request gets an answer instead.

    printf("inventory replied: %.*s\n",

           natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

    natsMsg_Destroy(reply);

}
```

## Retry differently per failure

Knowing the two failures apart is only useful if the client acts differently on each. That's **retry with backoff**: re-sending a failed request, with a growing wait between attempts so an overloaded responder gets time to recover instead of receiving more requests.

The two failures call for different timing. A timeout means the responder is up but slow, so a fast retry is reasonable; it may answer on the second try. No responders means nothing is listening, so an immediate retry is wasted; the responder is likely starting up, and the client should back off with a growing wait to give it time to register. Use a short, bounded retry for a timeout and an exponential backoff for no responders.

Either way the retry loop must be **bounded**. An unbounded retry against a responder that never comes back is a busy loop that never ends. Cap the attempts (five is a reasonable default) and add jitter to the wait so a fleet of requesters doesn't retry in lockstep and overwhelm the responder the instant it returns.

There's one more thing a retry needs to be safe: **idempotency**. A retried request is a *duplicate* request. If the first attempt actually reached the `inventory` responder and only the reply was lost, the retry asks the same question a second time. If asking twice causes two effects (two stock reservations, two charges), the retry has corrupted state.

The fix is to make a duplicate a no-op. `order-svc` keys every inventory check by its `order_id` (`ord_8w2k` here), and the `inventory` responder remembers recently seen IDs. A request whose `order_id` it has already answered returns the cached reply instead of reserving stock again. The ID is already in the payload, so making the call idempotent costs nothing on the wire; it's a discipline on both ends, not a new message.

A request in flight when the connection drops is lost outright; NATS doesn't persist it. The inbox re-subscribes automatically on reconnect (the reconnection page covered that), so a retry after the link returns works normally. And because the retry is idempotent, replaying it is safe even if the original had reached the responder before the drop.

## Pitfalls

A few traps turn request resilience into either a hang or corrupted state. Each is scoped to this page's two ideas: the two failures, and safe retry.

**Treating a timeout and no-responders as the same failure.** They are not the same. A blind "retry on any error" backs off the same way for both, which is wrong in both directions: it wastes a fast-retry opportunity on a slow responder and it floods a subject that has no responder at all with repeated requests. Branch on the error (fast-retry a timeout, exponential-backoff a no-responders) so the client matches its behavior to what actually went wrong.

**A timeout shorter than the responder's real latency.** If you set the timeout below what the `inventory` responder needs at its p99, every busy moment looks like a failure and the client retries answers that were already on their way back. Measure the responder's latency and set the timeout to two or three times its p99, so a slow-but-healthy answer isn't mistaken for a fault.

**An unbounded retry loop.** Retrying forever against a responder that never returns is a busy loop that pins a CPU and never reports the problem. Always cap the attempts, add jitter, and stop with a clear signal (log the failure and let the caller decide) rather than retrying silently.

**A non-idempotent retry that double-acts.** If the first attempt reached the `inventory` responder and only the reply was lost, a naive retry reserves stock twice. Key every request by `order_id` and have the responder de-dupe on it, so replaying a request is always safe.

Here's the safe pattern: branch on the failure, bound the retries, and key the request by `order_id` so a duplicate is a no-op on the responder side:

#### CLI

```
#!/bin/bash

# The safe retry pattern: branch on the failure, bound the retries, and

# key the request by order_id so a duplicate is a no-op on the responder.

#

# The CLI does not expose a per-failure backoff strategy the way the

# client libraries do (fast-retry-on-timeout vs

# exponential-backoff-on-no-responders). Here we show the same shape with

# a bounded loop and growing waits, and we keep the payload -- including

# its order_id -- byte-identical on every attempt so the inventory

# responder can de-dupe a re-sent request.



PAYLOAD='{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

MAX_ATTEMPTS=5



attempt=1

while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do

  # The CLI exits 0 even when no reply arrives (it logs "No responders are

  # available" or silently gives up on timeout), so test for a reply body

  # instead of the exit code. Same order_id on every attempt -> the responder

  # treats a retry as the same question and returns the cached answer.

  reply=$(nats request orders.inventory.check "$PAYLOAD" --timeout 2s --raw 2>/dev/null)

  if [ -n "$reply" ]; then

    echo "inventory check answered on attempt $attempt: $reply"

    exit 0

  fi



  # Grow the wait, with a little jitter, so a fleet of requesters does not

  # retry in lockstep and overwhelm the responder the instant it returns.

  wait=$(( attempt * attempt ))

  jitter=$(( RANDOM % 2 ))

  echo "attempt $attempt failed; backing off ${wait}s before retry" >&2

  sleep "$(( wait + jitter ))"

  attempt=$(( attempt + 1 ))

done



echo "inventory check failed after $MAX_ATTEMPTS attempts; giving up" >&2

exit 1
```

#### C

```
// The safe retry: branch on the failure, bound the attempts, and keep

// the payload -- including its order_id -- identical on every attempt

// so the inventory responder can de-dupe a re-sent request.

const char *order       = "{\"order_id\":\"ord_8w2k\",\"customer\":\"acme-co\","

                          "\"total_cents\":4200,\"ts\":\"2026-05-22T10:14:22Z\"}";

int        maxAttempts  = 5;

int        attempt;



for (attempt = 1; attempt <= maxAttempts; attempt++)

{

    natsMsg *reply = NULL;



    s = natsConnection_RequestString(&reply, conn,

                                     "orders.inventory.check",

                                     order, 2000);

    if (s == NATS_OK)

    {

        printf("inventory answered on attempt %d: %.*s\n", attempt,

               natsMsg_GetDataLength(reply), natsMsg_GetData(reply));

        natsMsg_Destroy(reply);

        break;

    }

    else if (s == NATS_TIMEOUT)

    {

        // The responder is up but slow: a fast retry is reasonable.

        fprintf(stderr, "attempt %d timed out, retrying shortly\n",

                attempt);

        nats_Sleep(200);

    }

    else if (s == NATS_NO_RESPONDERS)

    {

        // Nothing is listening yet: back off exponentially, with

        // jitter so a fleet of requesters does not retry in lockstep.

        int64_t wait = (1000 << (attempt - 1)) + (rand() % 250);



        fprintf(stderr, "attempt %d found no responder, backing off "

                "%dms\n", attempt, (int) wait);

        nats_Sleep(wait);

    }

    else

        break; // an unexpected error; do not keep retrying

}

if (s != NATS_OK)

    fprintf(stderr, "inventory check failed after %d attempts: %s\n",

            maxAttempts, natsStatus_GetText(s));
```

## Where you are

`order-svc`'s inventory check now distinguishes "responder absent" from "responder slow" and retries each correctly. You have:

* A request call that tells its three outcomes apart: a reply, a timeout, or an immediate no-responders signal.
* A retry that fast-retries a timeout, backs off on no-responders, and is bounded with jitter so it never busy-loops or overwhelms the responder.
* Idempotent requests keyed by `order_id`, so a retry after a lost reply or a reconnect never double-acts.

The connection now survives faults in every direction it sends and receives traffic. But it still does everything in the clear: the bytes on the wire are readable, and the server takes whatever name the client offers.

## What's next

The last mechanism in this chapter is **TLS and auth**: pointing the client at the `order-svc` credentials file so it authenticates, and at the cluster CA so it validates the server over an encrypted link.

Continue to [TLS & Auth](/learn/resilient-clients/tls-and-auth.md).

## See also

* [Core NATS → Request-Reply](/learn/core-nats/request-reply.md) — the `_INBOX` mechanism this page assumes.
* [Services](/learn/services/.md) — the framework that builds discovery, endpoints, and metrics on top of raw request-reply.
* [Reference](/reference/.md) — the wire protocol and server configuration; the request and timeout option names and defaults live in your client's API reference.
