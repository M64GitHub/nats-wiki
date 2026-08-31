<!-- source: https://docs.nats.io/learn/jetstream/priority-groups.md · fetched 2026-08-31 · section: priority-groups -->
# Priority groups

The [worker pool](/learn/jetstream/worker-pool.md) shared work evenly. Every worker on the `shipping` consumer pulled, and the server delivered messages to whichever worker asked.

Some workloads need a different split. You might want one client to handle all the work until it fails, or a far-away client to stay idle unless the near ones fall behind. Even work sharing can't do either of those.

**Priority groups** let a pull consumer ask for those behaviors. They're designed in [ADR-42](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-42.md). This page covers all three policies the server offers.

## What a priority group is

A priority group is a name on a pull consumer, plus a policy that decides how the server hands out messages for that name.

You set two fields when you create the consumer:

* **`PriorityGroups`**: the list of group names the consumer supports. Today a consumer uses exactly one group; naming more than one is accepted but only the first takes effect (see Pitfalls).
* **`PriorityPolicy`**: the rule the server applies, one of `overflow`, `pinned_client`, or `prioritized`.

Two of the three policies, overflow and pinned\_client, need the consumer to acknowledge its messages, so those examples use `--ack explicit`. They decide what to do from counts the server keeps per client: overflow looks at how many messages are waiting and unacknowledged, pinned\_client at which client is still pulling, and the server only keeps those counts when the consumer acks. Prioritized just sorts pulls by a number and needs no acks.

Once a consumer has a policy, every pull must name its group. A pull that leaves the group out is rejected with `Bad Request - Priority Group missing`. The group on the pull and the group on the consumer must match.

So a priority group is a name on the consumer, a policy that governs it, and pulls that join the group by name. The rest of this page covers the three policies and the problem each one solves.

## The overflow policy

Two regions can both process orders. `us-east` is close to the stream and cheap to serve. `us-west` works too, but every message it pulls crosses the country, costs more, and arrives slower. You want `us-west` to stay idle unless `us-east` falls behind.

The **overflow** policy does this. Workers in `us-east` pull with no threshold, so they always get messages. Workers in `us-west` pull with a `min_pending` threshold: the server answers their pull only when the consumer has at least that many messages waiting. Below the threshold their pull gets nothing, the same as if the stream were empty.

**Message flow — Overflow priority policy (animated):** Overflow priority policy. A near worker (us-east) pulls with no threshold and always drains the ORDERS backlog; a far worker (us-west) pulls with a min\_pending threshold and is served only while the backlog sits above it. A burst pushes the backlog over the line so us-west takes the overflow, and once the backlog falls back under, us-west goes idle again.

Create an overflow consumer on the `ORDERS` stream from a config file:

```
nats consumer add ORDERS dispatch --config overflow-consumer.json
```

where `overflow-consumer.json` sets the policy and its single group:

```
{

  "durable_name": "dispatch",

  "ack_policy": "explicit",

  "priority_policy": "overflow",

  "priority_groups": ["regions"]

}
```

The intended shorthand is `nats consumer add ORDERS dispatch --overflow-groups regions --ack explicit --pull`, but through natscli v0.4.x that flag sets the policy without attaching the group, so the server rejects the create with error `10159`. Use `--config` until the fix ships. The pinned and prioritized creates later on this page use their flags normally.

Confirm the consumer:

```
nats consumer info ORDERS dispatch
```

The configuration now carries the two priority fields:

```
Configuration:



              Pull Mode: true

             Ack Policy: Explicit

        Priority Policy: Overflow

        Priority Groups: regions
```

The threshold goes on the pull request, not on the consumer. A near-region worker pulls with no threshold. A far-region worker adds `min_pending`: deliver only when the consumer has backed up past that many waiting messages. `min_ack_pending` is a related threshold, counted against unacknowledged messages instead; meeting either one triggers delivery.

The `nats consumer next` command issues a plain pull and has no flag for these thresholds, so the overflow pull below comes from a client library:

#### CLI

```
#!/bin/bash



# Overflow policy: a standby region pulls only when the consumer has

# backed up past a min_pending threshold.



# Create an overflow pull consumer on ORDERS. --overflow-groups sets the

# policy to overflow and names the single group "regions". Overflow

# requires explicit acks.

nats consumer add ORDERS dispatch \

  --overflow-groups regions \

  --pull \

  --ack explicit \

  --defaults



# Inspect it — the configuration now shows Priority Policy: overflow and

# Priority Groups: [regions].

nats consumer info ORDERS dispatch



# The min_pending threshold lives on the pull request, which natscli's

# `nats consumer next` does not expose a flag for. A near-region worker

# pulls plainly and always gets messages:

nats consumer next ORDERS dispatch --count 5
```

#### C

```
// Bind to the existing overflow consumer. Every pull on a

// priority-group consumer must name its group.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream = "ORDERS";

so.Consumer = "dispatch";



s = js_PullSubscribe(&sub, js, NULL, "dispatch", NULL, &so, &jerr);



// A near-region worker pulls with no threshold, so it always gets

// messages.

if (s == NATS_OK)

{

    jsFetchRequest  req;

    natsMsgList     list = {NULL, 0};



    jsFetchRequest_Init(&req);

    req.Batch = 5;

    req.Expires = 2 * 1000000000LL; // 2 seconds, in nanoseconds

    req.Group = "regions";



    s = natsSubscription_FetchRequest(&list, sub, &req);

    if (s == NATS_OK)

    {

        printf("near region got %d messages\n", list.Count);

        for (i = 0; i < list.Count; i++)

            natsMsg_Ack(list.Msgs[i], NULL);

        natsMsgList_Destroy(&list);

    }

    else if (s == NATS_TIMEOUT)

        s = NATS_OK; // nothing waiting right now

}



// A far-region worker adds MinPending: the server answers its pull

// only when the consumer has backed up past that many waiting

// messages. Below the threshold it gets nothing, the same as if the

// stream were empty.

if (s == NATS_OK)

{

    jsFetchRequest  req;

    natsMsgList     list = {NULL, 0};



    jsFetchRequest_Init(&req);

    req.Batch = 5;

    req.Expires = 2 * 1000000000LL;

    req.Group = "regions";

    req.MinPending = 100;



    s = natsSubscription_FetchRequest(&list, sub, &req);

    if (s == NATS_OK)

    {

        printf("far region got %d overflow messages\n", list.Count);

        for (i = 0; i < list.Count; i++)

            natsMsg_Ack(list.Msgs[i], NULL);

        natsMsgList_Destroy(&list);

    }

    else if (s == NATS_TIMEOUT)

    {

        // Backlog below 100: the far region stays idle.

        printf("far region got nothing\n");

        s = NATS_OK;

    }

}
```

The near-region worker, pulling without a threshold, empties the backlog as fast as it processes. The far-region worker gets messages only when the backlog crosses its `min_pending` threshold, takes the overflow, and goes idle again once the near worker catches up.

## The pinned\_client policy

The overflow policy spreads work under load. The **pinned\_client** policy sends all work to one client and keeps a standby ready to take over.

Consider an order pipeline that must process messages strictly in arrival order. Two clients run so that one can take over if the other fails, but only one may work at a time, or the ordering breaks. You want one active client and one standby.

The server picks one waiting pull and **pins** it. That client becomes the one that receives messages. Every other client's pull waits as a standby. If the pinned client stops pulling, because it crashed or went quiet longer than the pin timeout allows, the server pins a standby instead.

**Message flow — Pinned-client priority policy (animated):** Pinned\_client priority policy. The server pins one worker and sends it every message while the others stand by. The pinned worker goes quiet; once PinnedTTL elapses the server pins a standby instead and stamps its messages with a new Nats-Pin-Id, and the old worker's next pull carrying the stale id comes back 423 — it clears the id and rejoins the standby pool.

Create a pinned consumer:

```
nats consumer add ORDERS sequencer --pinned-groups ordered --pinned-ttl 90s --ack explicit --pull --defaults
```

Two flags do the work. `--pinned-groups ordered` sets the policy to `pinned_client` and names the group `ordered`. `--pinned-ttl 90s` sets how long the server waits for a pull from the pinned client before it gives up and pins someone else.

The pin timeout must sit comfortably above the pull's `expires` value. The pinned client needs time to pull, get its batch or time out, process, then pull again, all before the timeout fires and costs it the pin. The server's default timeout is two minutes; keep `expires` under a minute and the whole cycle fits.

The pinned client earns and keeps the pin like this:

#### CLI

```
#!/bin/bash



# Pinned_client policy: one active client gets all the work, with a

# standby ready to take over.



# Create a pinned consumer. --pinned-groups sets the policy to

# pinned_client and names the group "ordered". --pinned-ttl is how long

# the server waits for a pull from the pinned client before pinning a

# standby instead. Pinned consumers require explicit acks.

nats consumer add ORDERS sequencer \

  --pinned-groups ordered \

  --pinned-ttl 90s \

  --pull \

  --ack explicit \

  --defaults



# Inspect it — the configuration shows Priority Policy: pinned_client,

# Priority Groups: [ordered], and Pinned TTL: 1m30s. The State block

# shows which client (if any) currently holds the pin.

nats consumer info ORDERS sequencer



# The Nats-Pin-Id handshake happens on the pull request, which natscli's

# `nats consumer next` does not drive. Pull a message to see delivery:

nats consumer next ORDERS sequencer --count 1



# Force the server to pick a new pinned client:

nats consumer unpin ORDERS sequencer ordered
```

#### C

```
// Pull from the pinned consumer with the async helper. The library

// runs the pin handshake for you: it stores the Nats-Pin-Id header

// from the first delivered message, sends it back on every later pull,

// and clears it to rejoin the standby pool if the server unpins this

// client.

jsOptions       jsOpts;

jsSubOptions    so;



jsOptions_Init(&jsOpts);

jsOpts.PullSubscribeAsync.Group = "ordered"; // the consumer's priority group

jsOpts.PullSubscribeAsync.Timeout = 30000;   // stop after 30 seconds



jsSubOptions_Init(&so);

so.Stream = "ORDERS";

so.Consumer = "sequencer";

so.ManualAck = true; // pinned_client requires explicit acks



s = js_PullSubscribeAsync(&sub, js, NULL, "sequencer",

                          onMsg, NULL, &jsOpts, &so, &jerr);



// If the server pins this client, every message flows here; if a

// standby client runs the same code, its pulls wait until the pin

// moves to it.

while ((s == NATS_OK) && natsSubscription_IsValid(sub))

    nats_Sleep(100);
```

The client and server agree on the pin through a header. When the server pins a client, the first message it delivers carries a `Nats-Pin-Id` header. The client reads that ID and sends it back on every later pull. The server keeps serving the client that presents the matching ID and parks the others.

The client gives up the pin in one of two ways. If it falls silent past the timeout, the server pins a standby, and the old client's next pull, still carrying the now-stale ID, comes back with a `423` status. The client clears its stored ID and pulls without it, joining the standby pool again. The `423` rules and the pinned and unpinned advisories are in the [Consumer API reference](/reference/jetstream/api/consumer/info.md).

The other way is an operator forcing a switch. `nats consumer unpin` clears the current pin and makes the server choose again:

```
nats consumer unpin ORDERS sequencer ordered -f
```

The command takes the stream, the consumer, and the group name; `-f` skips the confirmation prompt. It reports the client it dropped:

```
Unpinned client <client-id> from Priority Group ORDERS > sequencer > ordered
```

To check who's pinned without forcing a change, read the consumer's state. `nats consumer info ORDERS sequencer` shows the live pin in its `State` block:

```
State:



          Priority Groups: ordered: pinned <client-id> at 2026-06-02 12:14:22
```

A group with no active client reads `No client`. To list every fully pinned consumer at once, run `nats consumer find ORDERS --pinned`.

:::note Client support varies The pinned-client steps (storing `Nats-Pin-Id`, sending it back, handling the `423`) run in the Go, Java, JavaScript/TypeScript, and .NET clients today. Rust and Python let you set the configuration fields but don't yet run the client-side pinning loop. Check your client's reference before relying on it. :::

## The prioritized policy

The overflow policy makes a standby wait for a backlog to build. Sometimes you want the opposite: hand work to the next region the instant the closer one stops asking, with no threshold and no delay.

`us-east` is close and cheap but resource-constrained. Whenever it has capacity it should take the work; when it doesn't, `us-west` should pick up right away, and `eu-west` only when neither US region is pulling. That's a hierarchy, not a threshold.

The **prioritized** policy serves pulls in priority order. Each pull carries a `priority` from `0` to `9`, and the server hands messages to the lowest number present first; pulls at the same priority share round-robin. So `us-east` pulls at priority `0`, `us-west` at `1`, and `eu-west` at `2`: work goes to `us-east` whenever it's asking, falls to `us-west` the moment `us-east` isn't, and reaches `eu-west` only when neither is pulling.

**Message flow — Prioritized priority policy (animated):** Prioritized priority policy. Three regions pull at priority 0, 1 and 2. The server serves the lowest priority that is currently pulling, with no delay: us-east (0) gets everything while it pulls; the moment it goes quiet the work falls to us-west (1), then eu-west (2); when us-east returns the work snaps straight back to priority 0.

Create a prioritized consumer:

```
nats consumer add ORDERS dispatch --prioritized-groups regions --pull --defaults
```

`--prioritized-groups regions` sets the policy to `prioritized` and names the single group `regions`. Unlike the other two policies, prioritized keeps no per-client counts, so it doesn't require explicit acks.

This reuses the `dispatch` name from the overflow example on purpose: overflow and prioritized are two ways to run the same regional-dispatch consumer, so you pick one. The server does let you switch a live consumer's policy, though `nats consumer edit` has no flag for it; you'd pass a full config with `--config`.

The priority rides on the pull request, the same place overflow's thresholds go, so `nats consumer next` can't set it and the pull comes from a client library:

#### CLI

```
#!/bin/bash



# Prioritized policy: each pull carries a 0-9 priority and the server serves

# the lowest number first, so nearer workers get first refusal and farther

# ones pick up the instant the nearer ones go quiet.



# Create a prioritized pull consumer on ORDERS. --prioritized-groups sets the

# policy to prioritized and names the single group "regions". Prioritized

# sorts pulls by number and tracks no per-client counts, so unlike overflow

# and pinned_client it needs no explicit acks.

nats consumer add ORDERS dispatch \

  --prioritized-groups regions \

  --pull \

  --defaults



# Inspect it — the configuration shows Priority Policy: prioritized and

# Priority Groups: [regions].

nats consumer info ORDERS dispatch



# The priority rides on the pull request, which natscli's `nats consumer next`

# does not expose a flag for. A worker pulls plainly (priority 0) and is

# served ahead of any higher-numbered pull:

nats consumer next ORDERS dispatch --count 5
```

#### C

```
// Bind to the existing prioritized consumer. Every pull names the

// group and carries a priority from 0 to 9; the server serves the

// lowest number present first.

jsSubOptions so;



jsSubOptions_Init(&so);

so.Stream = "ORDERS";

so.Consumer = "dispatch";



s = js_PullSubscribe(&sub, js, NULL, "dispatch", NULL, &so, &jerr);



// us-east pulls at priority 0, so it's served ahead of any

// higher-numbered pull.

if (s == NATS_OK)

{

    jsFetchRequest  req;

    natsMsgList     list = {NULL, 0};



    jsFetchRequest_Init(&req);

    req.Batch = 5;

    req.Expires = 2 * 1000000000LL; // 2 seconds, in nanoseconds

    req.Group = "regions";

    req.Priority = 0;



    s = natsSubscription_FetchRequest(&list, sub, &req);

    if (s == NATS_OK)

    {

        printf("us-east got %d messages\n", list.Count);

        for (i = 0; i < list.Count; i++)

            natsMsg_Ack(list.Msgs[i], NULL);

        natsMsgList_Destroy(&list);

    }

    else if (s == NATS_TIMEOUT)

        s = NATS_OK; // nothing waiting right now

}



// us-west pulls the same way at priority 1: it's served the moment no

// priority-0 pull is waiting, with no threshold and no delay.

if (s == NATS_OK)

{

    jsFetchRequest  req;

    natsMsgList     list = {NULL, 0};



    jsFetchRequest_Init(&req);

    req.Batch = 5;

    req.Expires = 2 * 1000000000LL;

    req.Group = "regions";

    req.Priority = 1;



    s = natsSubscription_FetchRequest(&list, sub, &req);

    if (s == NATS_OK)

    {

        printf("us-west got %d messages\n", list.Count);

        for (i = 0; i < list.Count; i++)

            natsMsg_Ack(list.Msgs[i], NULL);

        natsMsgList_Destroy(&list);

    }

    else if (s == NATS_TIMEOUT)

        s = NATS_OK;

}
```

This is the immediate counterpart to overflow. Overflow waits for the backlog to cross a threshold before a standby gets anything, which avoids churn but makes far regions wait. Prioritized shifts work the moment a higher-priority puller goes quiet, with no delay, at the cost of some flip-flop as work moves between regions.

The full set of priority-group options, the `423` protocol, the `PriorityGroupState` fields, and the advisories live in [Reference → Consumer API](/reference/jetstream/api/consumer/info.md) and in [ADR-42](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-42.md).

## Pitfalls

Priority groups have a small surface, but a few details are easy to miss.

**One group per consumer.** A consumer uses exactly one priority group today. The `--overflow-groups` and `--pinned-groups` flags take a comma list, so passing two looks legal, and the server accepts it, but it uses only the first group and ignores the rest. Multiple groups per consumer is planned for a future server release. To split work by region or tier now, run separate consumers on the same stream, each with its own group.

#### CLI

```
#!/bin/bash



# A consumer acts on exactly one priority group. The --overflow-groups

# and --pinned-groups flags accept a comma list, so it is easy to pass

# two by accident.



# NOT THIS: two group names. The server accepts the create without error,

# but it uses only the first group (regions) and silently ignores the

# rest. Multiple groups per consumer is reserved for a future release.

nats consumer add ORDERS dispatch \

  --overflow-groups regions,backup \

  --pull \

  --ack explicit \

  --defaults



# DO THIS: name a single group. To split work by region or tier, run

# separate consumers, each with its own group, on the same stream.

nats consumer add ORDERS dispatch \

  --overflow-groups regions \

  --pull \

  --ack explicit \

  --defaults
```

#### C

```
// A consumer acts on exactly one priority group, but PriorityGroups is

// a list, so it's easy to pass two by accident.

jsConsumerConfig    cc;

const char          *twoGroups[] = {"regions", "backup"};

const char          *oneGroup[]  = {"regions"};



// NOT THIS: two group names. The server accepts the create without

// error, but it uses only the first group (regions) and silently

// ignores the rest. Multiple groups per consumer is reserved for a

// future release.

jsConsumerConfig_Init(&cc);

cc.Durable = "dispatch";

cc.AckPolicy = js_AckExplicit;

cc.PriorityPolicy = "overflow";

cc.PriorityGroups = twoGroups;

cc.PriorityGroupsLen = 2;



s = js_AddConsumer(&ci, js, "ORDERS", &cc, NULL, &jerr);

if (s == NATS_OK)

{

    jsConsumerInfo_Destroy(ci);

    ci = NULL;

    // The policy and groups are fixed at creation, so delete the

    // consumer before recreating it correctly.

    s = js_DeleteConsumer(js, "ORDERS", "dispatch", NULL, &jerr);

}



// DO THIS: name a single group. To split work by region or tier, run

// separate consumers, each with its own group, on the same stream.

if (s == NATS_OK)

{

    cc.PriorityGroups = oneGroup;

    cc.PriorityGroupsLen = 1;

    s = js_AddConsumer(&ci, js, "ORDERS", &cc, NULL, &jerr);

}

if (s == NATS_OK)

    printf("dispatch uses group %s\n", ci->Config->PriorityGroups[0]);
```

**The pin does not give one client sole ownership.** The server can switch the pinned client while that client still believes it holds the pin, so a long-running handler can finish work the server already gave to someone else. A pull that carries a now-stale `Nats-Pin-Id` comes back with a `423`; clear the stored ID and pull without it to join the standby pool again. If the same message must never be processed twice, use explicit acks and handlers that are safe to run more than once, not the pin alone.

**A quiet pinned client keeps the pin.** The pin only resets when the pinned client pulls again within `--pinned-ttl`. A client that holds the pin but stops pulling, for example because it's stuck on a slow handler, keeps every other client parked until the timeout fires. Keep each pull's `expires` comfortably under the pin timeout so the client always pulls again in time to renew. Which node in a cluster serves these pulls is covered in [clustering](/learn/clustering/.md).

## Where you are

A priority group is always one group plus a policy that decides how the server hands out pulls: reach for `overflow` to spill work to a standby only under load, `pinned_client` for one active worker with a standby ready to take over, and `prioritized` for an immediate, lowest-first hierarchy across regions.

## What's next

A consumer doesn't have to be running at all. The next page pauses a consumer, stopping it from delivering for a set window, and shows when that's the right tool.

## See also

* [Reference → Consumer API](/reference/jetstream/api/consumer/info.md) — the priority-group config fields, `PriorityGroupState`, the `423` protocol, and the pinned/unpinned advisories.
* [ADR-42](https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-42.md) — the design of pull consumer priority groups.
* [A pool of workers](/learn/jetstream/worker-pool.md) — the even work-sharing this page steers away from.
