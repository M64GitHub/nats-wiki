<!-- source: https://docs.nats.io/learn/jetstream/message-ttl.md · fetched 2026-08-31 · section: message-ttl -->
# Per-message TTL

The [Shaping the stream](/learn/jetstream/shaping-the-stream.md) page capped `ORDERS` at a 7-day `MaxAge`, so every message in the stream lives the same seven days, then is removed. That's one lifespan for the whole stream. Sometimes one message needs a different lifespan.

## When one message should expire sooner

Consider an `orders.canceled` message that only matters for an hour. A service that reads from the stream has 60 minutes to react to a cancellation. After that the message is no longer useful, and you don't want it in the stream for the full seven days.

`MaxAge` applies one deadline to every message in the stream, so it can't expire this one ahead of the rest.

A **per-message TTL** handles this case. TTL is short for time-to-live. It's a lifespan attached to one message, telling the server to delete that message after a stated time even when the stream's `MaxAge` would keep it longer.

You set it with a header named `Nats-TTL` when you publish. The value is a length of time: `1h`, `5s`, `30m`. The server deletes the message that long after it was stored in the stream.

## The stream must opt in

Per-message TTL is off by default. A stream rejects a `Nats-TTL` header until you turn the feature on.

The switch is a stream setting named `AllowMsgTTL`. Turn it on for `ORDERS` now:

```
nats stream edit ORDERS --allow-msg-ttl
```

Confirm it landed:

```
nats stream info ORDERS
```

The `Allows Per-Message TTL` line in the settings block flips from `false` to `true`:

```
Allows Per-Message TTL: true
```

This switch comes with two catches.

It can't be reversed. You can turn `AllowMsgTTL` on for an existing stream, but you can't turn it off again. The server refuses to take it back off.

It needs server 2.11 or newer. On older servers the setting doesn't exist and the edit has no effect. The rest of this page assumes 2.11+.

## Publish a short-lived message

With the feature on, publish an `orders.canceled` message that expires in 60 seconds. The TTL travels along as the `Nats-TTL` header:

#### CLI

```
#!/bin/bash

# Publish an orders.canceled message that expires 60 seconds after it

# is stored. The per-message TTL rides along as the Nats-TTL header.

# The stream must already have AllowMsgTTL enabled (nats stream edit

# ORDERS --allow-msg-ttl) or this publish is rejected.

# -J makes it a JetStream publish, so the server returns a PubAck

# (Stored in Stream ... Sequence ...) instead of a fire-and-forget send.

nats pub orders.canceled -J \

  --header "Nats-TTL:60s" \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'
```

#### JavaScript/TypeScript

```
// Publish one order with a per-message TTL. The `ttl` option sets the

// `Nats-TTL` header ("60s"), so the server deletes this message 60 seconds

// after it is stored, even if the stream would otherwise keep it forever.

const pa = await js.publish("orders.cancelled", "order ord_8w2k cancelled", {

  ttl: "60s",

});

console.log(`Stored in ${pa.stream} at sequence ${pa.seq}`);

console.log("This message is deleted 60s after it was stored");
```

#### Go

```
// Publish with a 60-second TTL. WithMsgTTL sets the Nats-TTL header, so the

// server deletes this single message 60s after it is stored, ahead of the

// stream's MaxAge.

ack, err := js.Publish(ctx, "orders.canceled", []byte("order 42 canceled"),

	jetstream.WithMsgTTL(60*time.Second))

if err != nil {

	panic(err)

}



fmt.Printf("Stored in %s at sequence %d\n", ack.Stream, ack.Sequence)
```

#### Python

```
# Publish with a Nats-TTL header so the server deletes this message 60

# seconds after it's stored, no matter what the stream would otherwise keep.

ack = await js.publish(

    "orders.canceled",

    b'{"id": "A-1001", "reason": "customer"}',

    headers={"Nats-TTL": "60s"},

)



print(f"stored in {ack.stream} at sequence {ack.seq}")
```

#### Java

```
// Attach a per-message TTL with the Nats-TTL header. The server keeps

// this message for 60 seconds after it is stored, then deletes it.

Headers headers = new Headers();

headers.add("Nats-TTL", "60s");



PublishAck ack = js.publish("orders.canceled", headers,

        "order 4242 canceled".getBytes(StandardCharsets.UTF_8));



System.out.println("Stored in stream: " + ack.getStream());

System.out.println("At sequence: " + ack.getSeqno());
```

#### Rust

```
// Publish a cancellation that carries its own time-to-live. The `Nats-TTL`

// header tells the server to delete this one message 60 seconds after it is

// stored, even if the rest of the stream never expires. "60s" is a duration

// string; the server also accepts an integer number of seconds (minimum 1s).

// (A typed shortcut also exists: `PublishMessage::build().ttl(Duration)`.)

let mut headers = async_nats::HeaderMap::new();

headers.insert("Nats-TTL", "60s");



let ack = js

    .publish_with_headers("orders.canceled", headers, "order 4242 canceled".into())

    .await?

    .await?;



println!(

    "Stored on stream {} at sequence {}",

    ack.stream, ack.sequence

);

// The message is live now and is removed 60 seconds after it was stored.
```

#### C#/.NET

```
// Give one message its own lifetime with the `Nats-TTL` header. The

// server deletes this message 60 seconds after it's stored, while the

// rest of the stream keeps its normal retention.

var headers = new NatsHeaders { ["Nats-TTL"] = "60s" };



var ack = await js.PublishAsync<OrderCancellation>(

    subject: "orders.canceled",

    data: new OrderCancellation(OrderId: "ord_8w2k", Reason: "customer_request"),

    headers: headers);



output.WriteLine($"Stored in {ack.Stream} at sequence {ack.Seq}");
```

#### C

```
// Publish with a 60-second TTL. MsgTTL sets the Nats-TTL header, so the

// server deletes this single message 60s after it is stored, ahead of

// the stream's MaxAge.

if (s == NATS_OK)

{

    jsPubOptions_Init(&po);

    po.MsgTTL = 60000; // in milliseconds



    s = js_Publish(&ack, js, "orders.cancelled", payload, (int) strlen(payload), &po, &jerr);

}



if (s == NATS_OK)

    printf("Stored in %s at sequence %" PRIu64 "\n", ack->Stream, ack->Sequence);
```

The publish returns a normal `PubAck`. The message is stored in the stream like any other, with a sequence number. The one difference is that the server now holds a deletion time for it: stored time plus 60 seconds.

Right after publishing, `nats stream info ORDERS` counts the message. Wait past the minute, ask again, and the count drops back. The message expired on its own deadline, while every other message in `ORDERS` keeps its full 7-day life.

## How TTL and MaxAge interact

A message lives until the *first* deadline that arrives. The per-message TTL and the stream `MaxAge` are both deadlines, and the earlier one applies.

**Message flow — Per-message TTL versus MaxAge (animated):** Three stored messages with different lifespans on one timeline, with a 'now' marker sweeping left to right. orders.cancelled carries a 1-hour per-message TTL and expires first, well before the stream's 7-day MaxAge. orders.created has no TTL, so it lives until MaxAge. orders.schema carries Nats-TTL: never and outlives even MaxAge. The earlier deadline always wins — except never, which has no deadline at all.

For the cancellation above, the 60-second TTL arrives long before the 7-day `MaxAge`. The TTL applies, and the message expires early.

A per-message TTL only ever makes a message expire *sooner* than `MaxAge` would, never later, with one exception covered next.

## How to make a message permanent

Sometimes a single message has to outlive everything around it: a schema definition the rest of the stream depends on, or a baseline snapshot you replay new consumers against. You want that one message held past the stream's `MaxAge`, not just held a little longer.

The exact value `never` does this. A message published with `Nats-TTL: never` never expires, not even at the stream's `MaxAge`. It stays until something deletes it on purpose.

## Storage versus delivery

A per-message TTL decides how long a message stays *stored in the stream*. It says nothing about whether a consumer has read the message.

This is the same split between storage and delivery from the publishing page, seen from the other end. A short TTL puts a deadline on the stored copy. If no consumer reads and acks the message before that deadline, the message expires unread. The server deletes it on schedule either way.

If a consumer needs to learn that a message expired rather than just find it gone, the stream's `SubjectDeleteMarkerTTL` setting can leave a delete marker in its place, but only when the expired message was the last one on its subject. On an active subject with newer messages, no marker is placed. The setting also has its own conditions; the [reference](/reference/jetstream/api/stream/create.md) covers them.

Size the TTL to the work. A 60-second TTL on a cancellation only makes sense if the consumer that cares about cancellations reads within that minute. Set the TTL shorter than the time in which the message still matters, but long enough for a healthy consumer to keep up.

## Two ways a TTL publish can fail

The TTL has to be at least one second. The server rejects a sub-second or zero `Nats-TTL` with an *invalid-TTL* error (`err_code` 10165) and stores nothing. The message never lands.

A valid `Nats-TTL` on a stream that hasn't opted in fails differently. The server rejects it with a *TTL-disabled* error (`err_code` 10166). The result is the same: no message stored. But the cause differs, so the two error codes are worth telling apart when you read a failed `PubAck`.

In both cases the server never quietly drops the header. On a stream like `ORDERS`, which has no `SubjectDeleteMarkerTTL` set, a TTL publish either honors the TTL or returns an error.

## Pitfalls

A few ways per-message TTL goes wrong in practice.

**A TTL header on a stream that never opted in fails the publish. It does not store the message without a TTL instead.** The server rejects the `Nats-TTL` header with a `per-message TTL is disabled` error (`err_code` 10166), and nothing is stored. The danger is assuming the message landed with its TTL when it never landed at all. Do check the `Allows Per-Message TTL` line in `nats stream info ORDERS` before you rely on the header. Don't publish a TTL message and walk away on a stream you haven't confirmed opted in.

#### CLI

```
#!/bin/bash

# A Nats-TTL header on a stream that hasn't opted in is rejected. The

# JetStream publish fails loudly (err_code 10166) and stores nothing —

# the message is not quietly kept forever without a TTL.



# A stream that never enabled AllowMsgTTL. Its config has no

# "Allows Per-Message TTL" line (the line only appears once it's on).

nats stream add ORDERS_NO_TTL --subjects "no-ttl.>" --defaults



# A JetStream publish (-J) with a TTL header is rejected: nats pub exits

# non-zero and prints the error, and nothing is stored. A plain core

# publish would hide this — it returns no PubAck, so you'd never see the

# rejection.

nats pub no-ttl.msg -J \

  --header "Nats-TTL:60s" \

  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

# -> nats: error: per-message TTL is disabled (10166)



# The fix is to opt the stream in once (a one-way switch), then republish.

nats stream edit ORDERS_NO_TTL --allow-msg-ttl
```

#### JavaScript/TypeScript

```
// Publish with a TTL to a stream that has per-message TTLs disabled. The server

// rejects the message with err 10166 ("per-message TTL is disabled") and stores

// nothing. Enabling `allow_msg_ttl` on the stream is the fix.

try {

  await js.publish("no-ttl.msg", "order ord_8w2k cancelled", { ttl: "60s" });

} catch (err) {

  if (err instanceof JetStreamApiError) {

    console.log(`Rejected (err ${err.code}): ${err.message}`);

    console.log("Nothing was stored");

  } else {

    throw err;

  }

}
```

#### Go

```
// Publishing with a TTL to a stream that hasn't enabled AllowMsgTTL fails.

// The server returns "per-message TTL is disabled" (err_code 10166) and

// stores nothing. The fix is to opt the stream in with AllowMsgTTL: true.

_, err = js.Publish(ctx, "no-ttl.msg", []byte("order 42 canceled"),

	jetstream.WithMsgTTL(60*time.Second))

if err != nil {

	fmt.Printf("Publish rejected, message not stored: %s\n", err)

	return

}
```

#### Python

```
# Publishing with a Nats-TTL header fails when the stream doesn't allow

# per-message TTLs. The server rejects it with err_code 10166 and stores

# nothing.

try:

    await js.publish(

        "no-ttl.msg",

        b'{"id": "A-1002"}',

        headers={"Nats-TTL": "60s"},

    )

except APIError as e:

    # "per-message TTL is disabled" — the fix is to create or update the

    # stream with allow_msg_ttl=True.

    print(f"publish rejected: {e.description} (err_code {e.err_code})")
```

#### Java

```
// Publishing a Nats-TTL header to a stream without AllowMsgTTL is

// rejected by the server, and nothing is stored.

Headers headers = new Headers();

headers.add("Nats-TTL", "60s");



try {

    js.publish("no-ttl.canceled", headers,

            "order 4242 canceled".getBytes(StandardCharsets.UTF_8));

}

catch (JetStreamApiException e) {

    // Error 10166: "per-message TTL is disabled". Enabling

    // AllowMsgTTL on the stream is the fix.

    System.out.println("Publish rejected [" + e.getApiErrorCode() + "]: "

            + e.getErrorDescription());

}
```

#### Rust

```
// Try to publish a message carrying a `Nats-TTL` header to a stream that does

// not allow per-message TTLs. The server refuses the write with error 10166,

// "per-message TTL is disabled", so nothing is ever stored.

let mut headers = async_nats::HeaderMap::new();

headers.insert("Nats-TTL", "60s");



match js

    .publish_with_headers("no-ttl.event", headers, "should be rejected".into())

    .await?

    .await

{

    Ok(ack) => println!("Unexpected: message stored at sequence {}", ack.sequence),

    Err(err) => {

        println!("Publish rejected, nothing stored: {err}");

        // The fix is to enable TTLs on the stream: create (or update) it with

        // `allow_message_ttl: true`, as in the publish-with-TTL example.

    }

}
```

#### C#/.NET

```
// The `Nats-TTL` header only works on a stream created with

// AllowMsgTTL = true. Publishing it to a stream that hasn't enabled the

// feature is rejected instead of silently storing the message forever.

var headers = new NatsHeaders { ["Nats-TTL"] = "60s" };



try

{

    var ack = await js.PublishAsync<OrderCancellation>(

        subject: "no-ttl.canceled",

        data: new OrderCancellation(OrderId: "ord_8w2k", Reason: "customer_request"),

        headers: headers);



    // PublishAsync returns the server's answer; EnsureSuccess turns a

    // rejection into an exception instead of leaving it unchecked.

    ack.EnsureSuccess();

}

catch (NatsJSApiException ex)

{

    // 10166: per-message TTL is disabled. The fix is to recreate the

    // stream with AllowMsgTTL = true so it accepts the `Nats-TTL` header.

    rejection = ex;

    output.WriteLine($"Rejected ({ex.Error.Code}): {ex.Error.Description}");

}
```

#### C

```
// Publishing with a TTL to a stream that hasn't enabled AllowMsgTTL

// fails. The server returns "per-message TTL is disabled" (err_code

// 10166) and stores nothing. The fix is to opt the stream in with

// AllowMsgTTL: true.

if (s == NATS_OK)

{

    jsPubOptions_Init(&po);

    po.MsgTTL = 60000; // in milliseconds



    s = js_Publish(NULL, js, "no-ttl.msg", payload, (int) strlen(payload), &po, &jerr);

    if ((s != NATS_OK) && (jerr == JSMessageTTLDisabledErr))

    {

        printf("Publish rejected, message not stored: %s (err_code %d)\n",

               nats_GetLastError(NULL), (int) jerr);

        s = NATS_OK;

    }

}
```

**A short TTL deletes the message whether or not a consumer read it.** The TTL is a deadline on the *stored copy*, not a guarantee about delivery. It counts down regardless of what any consumer is doing. If the TTL runs out while the consumer that handles cancellations is down, backed up, or reading slowly mid-batch, the server deletes the message and nobody processes the cancellation. A consumer that already holds a message doesn't pause that message's TTL. Do size the TTL to outlast the lag of your slowest healthy consumer. Don't set a TTL shorter than the time in which the message still has to be acted on.

**Turning `AllowMsgTTL` on can't be undone.** You can turn the feature on with `nats stream edit ORDERS --allow-msg-ttl`, but the server refuses to turn it back off. Do turn it on on purpose, knowing the stream keeps the feature for life. Don't flip it on to test something and expect to undo it.

## Where you are

`ORDERS` now has `AllowMsgTTL` turned on, a switch you can't turn back off. You published an `orders.canceled` message with a 60-second `Nats-TTL` and saw it expire while the rest of the stream remained. The earlier of TTL and `MaxAge` always applies.

The stream still holds its earlier messages under the 7-day `MaxAge` set on the [Shaping the stream](/learn/jetstream/shaping-the-stream.md) page. Nothing else changed.

## What's next

That's the last of the stream and consumer mechanics. Before the chapter closes, [Stream and consumer policies](/learn/jetstream/policies.md) lines up every policy you've met, and the few you haven't, in one place.

## See also

* [Reference → Per-Message TTL](/reference/jetstream/api/headers.md) — the `Nats-TTL` header and the delete-marker headers in full.
* [Reference → Stream Configuration](/reference/jetstream/api/stream/create.md) — `AllowMsgTTL` and `SubjectDeleteMarkerTTL` alongside every other stream field.
