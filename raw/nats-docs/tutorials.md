<!-- source: https://docs.nats.io/tutorials.md · fetched 2026-08-31 · section: tutorials -->
# Tutorials

Tutorials take you by the hand and get you a small, complete, working result. Each one is a short happy path: run the commands, see the output you're told to expect, and you're done. No detours, no edge cases, no "it depends" — just steps that work.

That's the difference from the rest of the docs:

* **Tutorials** (you are here) show you *that* it works. Follow the steps and you'll be done in 10–20 minutes.
* **[Learn](/learn/.md)** deep dives explain *why* it works: the mechanisms, the trade-offs, and the judgment to use NATS well.
* **[Concepts](/concepts/intro.md)** give the big-picture overview of what NATS is.

Each tutorial is self-contained. Start anywhere, but if you're brand new, the order below builds up naturally.

## Start here

Work through these in order, or jump to whatever you need:

1. **[Hello NATS](/tutorials/hello-nats.md)**: install a server, publish your first message, and watch a subscriber receive it.
2. **[Request/reply](/tutorials/request-reply.md)**: stand up a responder and call it to get an answer back.
3. **[Work queue](/tutorials/work-queue.md)**: split a stream of jobs across two workers so each job goes to exactly one of them.
4. **[Your first stream](/tutorials/first-stream.md)**: turn on JetStream and create a stream that keeps your messages so you can replay them.
5. **[Stream consumer](/tutorials/stream-consumer.md)**: read a stream with a durable consumer that acknowledges messages and resumes where it left off.
6. **[Key-value](/tutorials/key-value.md)**: use a tiny state store. Put a value, get it back, and watch it change live.
7. **[Build an app](/tutorials/build-an-app.md)**: combine pub/sub, request/reply, and a stream into one small running program.

## Already comfortable?

Want the *why* behind any of this? Jump straight to the [Learn deep dives](/learn/.md) for the mechanisms, the design choices, and how to use NATS well.
