# Scout — core NATS or JetStream, per flow: row 133 (2026-09-04)

**Why this topic.** Step 7 of `inbox/plan-the-client-side-2026-09-03.md` (phase F), which writes
`wiki/operations/core-or-jetstream.md` and closes megaplan group **G7**. Section 5(b) of
`inbox/scout-backlog.md` — a scout per pattern page before it is written.

| row | question | asked at | state before this scout |
|---:|---|---|---|
| **133** | Core NATS or JetStream for a given flow — how do I decide per subject, and what does a mixed design (core for request/reply, JetStream for events) look like? | `own` | open, `design`; [[core-or-jetstream]] is the wiki's only registered wanted page, linked from [[core-nats-delivery]] and [[services-on-core-nats]], both of which stop at the durability boundary and hand the decision on |

**The 5(a) sweep already searched for row 133's public form and did not find it**
(`inbox/scout-posed-rows-public-form-2026-09-03.md`, row 133: *"nobody asks how to decide core versus
JetStream per flow"*). This scout does not overturn that. It searched the same comment cache with
different terms and confirms the shape: **the question is asked in halves, never whole.** The halves
that *are* public are candidates 4, 5 and 6 below.

**What was searched, on 2026-09-04**, over `local/scratch/gh-index/threads-2026-09-03.md` (484
threads with every comment and reply): `core (nats )?(vs|or) jetstream`, `jetstream (vs|or) core`,
`when (to|should i) use jetstream`, `do i need jetstream`, `why (use )?jetstream`, `instead of
jetstream`, `without jetstream`, and every thread whose comments contain the string *core NATS* (22
threads, listed by title). Plus the Stack Exchange API for `74129868`, `natsbyexample.com`'s index,
and the docs tree for `supersede`.

**Not found, and why the nearest miss is a miss:**

- **gh#7738** (*Hot scaling core NATS (no JetStream) for bursty traffic*) — already bank row **11**; it
  assumes core is chosen and asks how to scale it. Phase H.
- **gh#6437** (*Client Design & partitioning*) — the partitioning answer, already phase G1's material.
- **gh#5220**, **gh#3654** — work distribution, one mechanism each.
- **natsbyexample.com** — skimmed today: 11 categories, no example compares the two or says when to
  choose. *Messaging* and *JetStream* are separate sections with no bridge page.
- **so#74129868** — candidate 6: the right question on one axis, an answer this wiki cannot lean on.

**Conclusion for the bank.** Row 133 **stays `own`**. Candidate 4 (gh#2961) becomes a new asked row of
its own — it answers "must I deploy two clusters?", which is one leg of the mixed design but not the
choice — and candidate 6 likewise. The page is written from the docs' own two statements of the rule,
the boundary ADR, and the runs.

---

## The candidates

| # | candidate | what it gives | rows | pages it would touch | flags |
|---|---|---|---:|---|---|
| 1 | `raw/nats-docs/concepts/jetstream.md` (591 lines, fetched 2026-08-31) — **unread**, no summary owns it | The docs' own one-paragraph statement of the boundary: *"Core NATS delivers messages only to subscribers connected at the moment of publication - at most once, never replayed. JetStream adds a persistence layer on top, giving you at-least-once delivery"*, and the framing this page needs — *"Core NATS already decouples publisher and subscriber from each other … JetStream extends that decoupling to time - the two no longer need to be online at the same moment."* Then the three pieces (stream, consumer, client), independent cursors, the seven-language *Putting it together*, and *Beyond streams and consumers* (KV, object store). | 133 | [[core-or-jetstream]], [[core-nats-delivery]], [[stream]], [[consumer]], [[key-value]], [[object-store]] | **★** docs, the boundary |
| 2 | `raw/nats-docs/learn/core-nats.md` (the chapter index, fetched 2026-08-31) — cited once, no summary owns it | **The single best sentence in the docs for row 133**, with worked examples on both sides. §*Core NATS is ephemeral*: at-most-once is *"intentional. It keeps core NATS small and fast, and it's exactly right when each message is superseded by the next one, such as a live price, a current temperature, or a cache invalidation. When you need messages to wait for a subscriber, survive a restart, or be replayed later, you add a stream."* Also the chapter's whole-scenario framing (the Acme ORDERS world *"before it adds any persistence"*), which is the same running example the JetStream chapter picks up — the docs' own mixed design. | 133 | [[core-or-jetstream]], [[core-nats-delivery]], [[stream]], [[subjects-and-wildcards]] | **★** docs, the decision rule |
| 3 | `raw/nats-docs/learn/jetstream/where-next.md` (265 lines) — **unread**, no summary owns it | The rule from the JetStream side, in the chapter's gathered production checklist (line 53): *"Stay on plain pub-sub when the next message supersedes the last; reach for a stream only when a missed message has consequences."* Plus the three-idea model (stream · consumer · ack), *"A stored message has not yet been processed"*, and the whole JetStream production checklist. **Carries a docs defect**: that bullet is attributed to `your-first-stream.md#pitfalls`, and that page's Pitfalls section states only two things, neither of them this — the decision rule the chapter turns on exists in exactly one place in the tree, and it is a gathered checklist item pointing at a page that does not state it. | 133 | [[core-or-jetstream]], [[stream]], [[consumer]], [[ack-and-redelivery]], [[publishing]] | **★** docs, the reciprocal rule + a docs issue |
| 4 | [gh#2961](https://github.com/nats-io/nats-server/discussions/2961) — *JS and Core Can Use a cluster together* · General · opened 2022-03-25 by @ltDamon · no chosen answer · 3 comments · 1 upvote · fetched into `raw/gh-discussions/gh-2961.md` today | The **only public maintainer statement on the mixed deployment**, and it is two lines. @wallyqs: *"You can use both at the same time with the same cluster."* @ripienaar, asked whether enabling JetStream costs core NATS anything: *"Enabling jetstream will increase memory use on the server - and using it again also will increase memory use. But core nats performance will remain the same essentially"*. The asker is reading a docs sentence about a cluster *"where none of the nats-server instances are configured to enable JetStream"* and concluding he needs two clusters — which is exactly the confusion the page has to remove. | new row; 133 | [[core-or-jetstream]], [[jetstream-sizing]], [[core-nats-delivery]], [[build-a-3-node-cluster]] | **★** public, maintainer |
| 5 | `raw/adr/ADR-22.md` — *JetStream Publish Retries on No Responders* (wallyqs, 2022-03-18, **Partially Implemented**) — `inbox/adr-toc.md` row 22, no decision recorded | **The boundary ADR**: it is the one that says out loud that a JetStream publish *is* a core request/reply. *"A synchronous `Publish` request when using the JetStream context internally uses a `Request` to produce a message and if the JetStream service was not ready at the moment of publishing, the server will send to the requestor a 503 status message right away."* Leadership blips during election produce `no responders available`; the client's answer is backoff and retry — Go's defaults `retryWait = 250ms`, `maxAttempts = 2` (three sends in total), the options `RetryWait` / `RetryAttempts` (`-1` = until the context deadline), and the terminal errors: a timeout if the deadline expired, else `nats: no response from stream`. This is the cost line of the whole decision: a core publish is one frame, a JetStream publish is a round trip that can 503. | 133; adr-toc row 22 | [[core-or-jetstream]], [[publishing]], [[nats-timeout]], [[meta-layer]], [[nats-go]], [[core-nats-delivery]] | **★** ADR, the cost of the boundary |
| 6 | [so#74129868](https://stackoverflow.com/questions/74129868/is-nats-jetstream-suitable-for-persiting-messages-forever) — *Is NATs Jetstream suitable for persiting messages forever?* · score 3 · 717 views · 1 answer (score **0**, not accepted, not a maintainer) · asked 2022-10-19 | The public form of one axis: *"Can Jetstream persist messages forever? So it will be the only source of truth like Kafka is often used? … we can rewind to the beginning anytime and consume all messages that went through some stream?"* The answer only points at the docs and suggests KV for single values. **Weak** — worth a bank row for the question, not a source for the page. | new row | [[core-or-jetstream]], [[stream]], [[retention-policies]], [[key-value]] | public, weak answer |
| 7 | [gh#3507](https://github.com/nats-io/nats-server/discussions/3507) — *Will Jetstream support external DB like postgres for persistence* · chosen answer @derekcollison 2022-09-28 | Already bank row **143**, answered by [[stream]]: *"No, we will support memory and file based for the store level."* Bounds the choice — there is no third storage option to weigh. **Cite, do not re-ingest.** | 143 | [[core-or-jetstream]] (pointer) | in-bank |
| 8 | [gh#7138](https://github.com/nats-io/nats-server/discussions/7138) — *Postgres as Persistent storage for hight critical events* · answered @ripienaar / @neilalexander 2025-08-04 | The 2025 restatement of the same boundary from the other end, and the sharper half of it: @neilalexander, *"You can publish into JetStream and wait for a puback for confirmation that JetStream received your message, and after that you can replay it up to as many times as you want"* — then the asker discovers a stream is not an audit log (*"once the msg are process in jetstream they are vanished"*). The *what a stream is not* row of the decision table. | new row candidate; 133 | [[core-or-jetstream]], [[retention-policies]], [[stream]] | public |
| 9 | `raw/gh-discussions/gh-4984.md` — *Nats micro with Jetstream* (8 upvotes) | Already in the tree and summarised as [[s-gh-4984-micro-with-jetstream]] (step 6, bank row 193). The public statement of where the services pattern stops: an acking handler is *"Still not on the immediate roadmap"*, and a third commenter describes the bridge — publish into a stream, carry the caller's reply subject in a header. **Cite, do not re-ingest.** | 193, 134 | [[core-or-jetstream]] (the mixed design), [[services-on-core-nats]] | in-tree |
| 10 | `raw/synadia-blog/jetstream-design-patterns-for-scale.txt` | Already summarised as [[s-synadia-jetstream-anti-patterns]]. The *Design Patterns for Scaling NATS* series is about scaling JetStream, not about choosing it; nothing in it weighs core against a stream. **Cite for the cost side only, do not re-ingest.** | — | [[core-or-jetstream]] (pointer) | in-tree, off-topic |

**Skimmed and not picked**: `raw/nats-docs/learn/core-nats/where-next.md` (the core chapter's closing —
its §*What core NATS does not store* repeats candidate 2's rule in weaker form, and its production
checklist is the chapter's pitfalls gathered, all of which landed on [[core-nats-delivery]],
[[subjects-and-wildcards]], [[request-reply]] and [[queue-groups]] in steps 1–2);
`raw/nats-docs/learn/jetstream/your-first-stream.md` (*Why a stream* is candidate 2's rule again; its
two pitfalls — unlimited defaults, a permanent stream name — are already on [[stream]]).

## Status

Ingested 2026-09-04 for step 7 of `inbox/plan-the-client-side-2026-09-03.md`:

| candidate | summary |
|---|---|
| 1 · `concepts/jetstream.md` | [[s-docs-concepts-jetstream]] |
| 2 · `learn/core-nats.md` | [[s-docs-core-nats-chapter]] |
| 3 · `learn/jetstream/where-next.md` | [[s-docs-jetstream-where-next]] |
| 4 · gh#2961 | [[s-gh-2961-js-and-core-one-cluster]] |
| 5 · ADR-22 | [[s-adr-22-publish-retries]] |
| 7 · gh#3507 | [[s-gh-3507-no-external-store]] — **ingested after all**: the scout said "cite, do not re-ingest", but bank row 143 was marked answered by [[stream]] and [[nats-streaming]] and **neither page stated the fact**, so citing it would have been citing nothing. Fetched whole, summarised, and landed on both pages |
| 6, 8 | bank rows only (**197**, and 8's material folded into the page's *Trade-offs*), cited through candidates 1–5 and the runs |
| 9, 10 | already in the tree; cited, not re-ingested |

**Seven summaries, not four.** The step planned "≤ 4 summaries" on the assumption the scout would find
one thread that asks row 133; it found none, so the page rests on the docs' own two statements of the
rule (candidates 1–3), the boundary ADR (5), the one public maintainer statement on the mixed
deployment (4), eight passes of runs on 2.14.6, and candidate 7 above — which was a repair, not an
expansion.
