<!-- source: https://docs.nats.io/tutorials/work-queue.md · fetched 2026-08-31 · section: work-queue -->
# 3. Share work across workers

In this tutorial you'll run two workers that share one subject and watch the server split the work between them. You'll publish six messages to `tasks`, and each one goes to exactly one worker — never both. That's a **queue group**: a pool of subscribers that share a name and divide the load.

**Message flow — Queue group (animated):** Animated queue group: a publisher emits messages; NATS load-balances each message to exactly one worker in the queue group.

* Publisher → Worker 1
* Publisher → Worker 2
* Publisher → Worker 3

## What you'll need

* `nats-server` and the `nats` CLI installed. If you haven't installed them yet, do the [Hello NATS](/tutorials/hello-nats.md) tutorial first.
* Four terminal windows: one for the server, two for the workers, and one to publish.

## Step 1: Start the server

In the first terminal, start `nats-server`:

```
nats-server
```

You should see startup logs ending with a ready line:

```
[INF] Server is ready
```

Leave it running.

## Step 2: Start the first worker

In the second terminal, subscribe to the `tasks` subject as a member of the `workers` queue group. The `--queue` flag is what makes this a queue group member instead of a plain subscriber:

#### CLI

```
#!/bin/bash

# Subscribe to the "tasks" subject as a member of the "workers" queue group.

# The --queue flag names the group. Every subscriber that names the same

# group on the same subject shares the load: each message is delivered to

# exactly one member. Run this in two terminals to watch work split between

# them. Press Ctrl-C to stop.

nats sub tasks --queue workers
```

#### C

```
// The callback runs once for each task the server hands this worker.

static void

onTask(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("received on \"%s\": %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe to the "tasks" subject as a member of the "workers" queue

    // group. Every subscriber that names the same group on the same subject

    // shares the load: each message is delivered to exactly one member.

    // Run this program twice to watch work split between the two copies.

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&sub, conn, "tasks", "workers",

                                          onTask, NULL);
```

You should see the worker waiting for messages:

```
17:42:10 Subscribing on tasks
```

Leave it running.

## Step 3: Start the second worker

In the third terminal, run the exact same command. Because it names the same queue group `workers` on the same subject `tasks`, it joins the same group:

#### CLI

```
#!/bin/bash

# Subscribe to the "tasks" subject as a member of the "workers" queue group.

# The --queue flag names the group. Every subscriber that names the same

# group on the same subject shares the load: each message is delivered to

# exactly one member. Run this in two terminals to watch work split between

# them. Press Ctrl-C to stop.

nats sub tasks --queue workers
```

#### C

```
// The callback runs once for each task the server hands this worker.

static void

onTask(natsConnection *nc, natsSubscription *sub, natsMsg *msg, void *closure)

{

    printf("received on \"%s\": %.*s\n",

           natsMsg_GetSubject(msg),

           natsMsg_GetDataLength(msg), natsMsg_GetData(msg));

    natsMsg_Destroy(msg);

}

    // Subscribe to the "tasks" subject as a member of the "workers" queue

    // group. Every subscriber that names the same group on the same subject

    // shares the load: each message is delivered to exactly one member.

    // Run this program twice to watch work split between the two copies.

    if (s == NATS_OK)

        s = natsConnection_QueueSubscribe(&sub, conn, "tasks", "workers",

                                          onTask, NULL);
```

You should see the same waiting line:

```
17:42:18 Subscribing on tasks
```

You now have two workers in one group. Both terminals are idle; neither has received anything yet.

## Step 4: Publish the work

In the fourth terminal, publish six messages to `tasks`. The `--count` flag repeats the publish six times, and the CLI replaces `{{ Count }}` with the message number:

#### CLI

```
#!/bin/bash

# Publish six messages to the "tasks" subject. The --count flag sends the

# publish that many times, and {{ Count }} is replaced with the message

# number (1, 2, 3, ...). With two workers in the "workers" queue group,

# the server hands each message to exactly one of them.

nats pub tasks "task {{ Count }}" --count 6
```

#### C

```
// Publish six messages to the "tasks" subject. With two workers in

// the "workers" queue group, the server hands each message to

// exactly one of them.

char task[32];

int  i;



for (i = 1; (s == NATS_OK) && (i <= 6); i++)

{

    snprintf(task, sizeof(task), "task %d", i);

    s = natsConnection_PublishString(conn, "tasks", task);

    if (s == NATS_OK)

        printf("published \"%s\" to \"tasks\"\n", task);

}
```

You should see the publisher confirm one line per message:

```
17:42:30 Published 6 bytes to "tasks"

17:42:30 Published 6 bytes to "tasks"

17:42:30 Published 6 bytes to "tasks"

17:42:30 Published 6 bytes to "tasks"

17:42:30 Published 6 bytes to "tasks"

17:42:30 Published 6 bytes to "tasks"
```

## Step 5: Watch the split

Look at your two worker terminals. The six messages are split between them: each worker receives some, and no message appears in both. One terminal might show:

```
[#1] Received on "tasks"

task 1



[#2] Received on "tasks"

task 3



[#3] Received on "tasks"

task 5
```

and the other:

```
[#1] Received on "tasks"

task 2



[#2] Received on "tasks"

task 4



[#3] Received on "tasks"

task 6
```

The server picks one member per message, so the exact split varies. What never varies: every message goes to exactly one worker.

Publish again to see it balance once more:

#### CLI

```
#!/bin/bash

# Publish six messages to the "tasks" subject. The --count flag sends the

# publish that many times, and {{ Count }} is replaced with the message

# number (1, 2, 3, ...). With two workers in the "workers" queue group,

# the server hands each message to exactly one of them.

nats pub tasks "task {{ Count }}" --count 6
```

#### C

```
// Publish six messages to the "tasks" subject. With two workers in

// the "workers" queue group, the server hands each message to

// exactly one of them.

char task[32];

int  i;



for (i = 1; (s == NATS_OK) && (i <= 6); i++)

{

    snprintf(task, sizeof(task), "task %d", i);

    s = natsConnection_PublishString(conn, "tasks", task);

    if (s == NATS_OK)

        printf("published \"%s\" to \"tasks\"\n", task);

}
```

The new batch spreads across the two workers the same way. Press Ctrl-C in each terminal to stop.

## What you built

Two workers shared the `tasks` subject through the `workers` queue group, and the server delivered each message to exactly one of them. Add a third worker with the same command and the group resizes itself. The work spreads across all three with no extra setup.

## Next

* Build a stream that keeps messages so a worker can replay them later: [First stream](/tutorials/first-stream.md).
* Understand how the server picks a member, how groups resize live, and when to reach for a durable work queue instead: [Queue groups deep dive](/learn/core-nats/queue-groups.md).
