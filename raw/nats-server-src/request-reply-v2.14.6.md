<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 — server/client.go, server/route.go, server/gateway.go from the release tarball tools/check-defaults.py keeps in .cache/nats-server-2.14.6/ (identical to raw.githubusercontent.com at the tag), read 2026-09-03 -->
# nats-server v2.14.6 — request/reply and queue groups: the no-responders 503, `processMsgResults`, the routed queue weight, the gateway exclusion list

Verbatim line ranges from the tagged source, one block per file, in the form of `constants-v2.14.6.md`; the line numbers are the real ones at the tag, so each can be checked at `https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<n>`. The companion `request-reply-observed-v2.14.6.md` runs what these ranges say. The `CONNECT` check that refuses `no_responders` without `headers` (`client.go:2454–2470`) and the `HPUB` parser are in `core-delivery-v2.14.6.md` and are not repeated here.

## server/client.go — the flags `processMsgResults` takes

```go
  230	// Some flags passed to processMsgResults
  231	const pmrNoFlag int = 0
  232	const (
  233		pmrCollectQueueNames int = 1 << iota
  234		pmrIgnoreEmptyQueueFilter
  235		pmrAllowSendFromRouteToRoute
  236		pmrMsgImportedFromService
  237	)
```

## server/client.go — after the local delivery: queue names for the gateways, then the 503

The tail of `processInboundClientMsg`. `didDeliver` is what the whole page turns on: the no-responders reply is sent only when nothing — no plain subscriber, no queue member, no route, no leaf, no gateway — took the message, the publish carried a reply subject, the connection asked for `no_responders` in its `CONNECT`, and the connection itself holds a plain subscription matching that reply subject (`subForReply`). The header block is `NATS/1.0 503` plus `Nats-Subject: <the published subject>`; `hdrLen` is 32 bytes plus the subject, and the message has no body (header length equals total length).

```go
 4474		// Indication if we attempted to deliver the message to anyone.
 4475		var didDeliver bool
 4476		var qnames [][]byte
 4477	
 4478		// Check for no interest, short circuit if so.
 4479		// This is the fanout scale.
 4480		if len(r.psubs)+len(r.qsubs) > 0 {
 4481			flag := pmrNoFlag
 4482			// If there are matching queue subs and we are in gateway mode,
 4483			// we need to keep track of the queue names the messages are
 4484			// delivered to. When sending to the GWs, the RMSG will include
 4485			// those names so that the remote clusters do not deliver messages
 4486			// to their queue subs of the same names.
 4487			if len(r.qsubs) > 0 && c.srv.gateway.enabled &&
 4488				atomic.LoadInt64(&c.srv.gateway.totalQSubs) > 0 {
 4489				flag |= pmrCollectQueueNames
 4490			}
 4491			didDeliver, qnames = c.processMsgResults(acc, r, msg, c.pa.deliver, c.pa.subject, c.pa.reply, flag)
 4492		}
 4493	
 4494		// Now deal with gateways
 4495		if c.srv.gateway.enabled {
 4496			reply := c.pa.reply
 4497			if len(c.pa.deliver) > 0 && c.kind == JETSTREAM && len(reply) > 0 && !replyHasJSAckSuffix(reply) {
 4498				reply = append(slices.Clip(reply), '@')
 4499				reply = append(reply, c.pa.deliver...)
 4500			}
 4501			didDeliver = c.sendMsgToGateways(acc, msg, c.pa.subject, reply, qnames, false) || didDeliver
 4502		}
 4503	
 4504		// Check to see if we did not deliver to anyone and the client has a reply subject set
 4505		// and wants notification of no_responders.
 4506		if !didDeliver && len(c.pa.reply) > 0 {
 4507			c.mu.Lock()
 4508			if c.opts.NoResponders {
 4509				if sub := c.subForReply(c.pa.reply); sub != nil {
 4510					hdrLen := 32 /* header without the subject */ + len(c.pa.subject)
 4511					proto := fmt.Sprintf("HMSG %s %s %d %d\r\nNATS/1.0 503\r\nNats-Subject: %s\r\n\r\n\r\n", c.pa.reply, sub.sid, hdrLen, hdrLen, c.pa.subject)
 4512					c.queueOutbound([]byte(proto))
 4513					c.addToPCD(c)
 4514				}
 4515			}
 4516			c.mu.Unlock()
```

```go
 4522	// Return the subscription for this reply subject. Only look at normal subs for this client.
 4523	func (c *client) subForReply(reply []byte) *subscription {
 4524		r := c.acc.sl.Match(string(reply))
 4525		for _, sub := range r.psubs {
 4526			if sub.client == c {
 4527				return sub
 4528			}
 4529		}
 4530		return nil
 4531	}
```

## server/client.go — `processMsgResults`: how one queue member is chosen

Signature, then the queue-subscription part. Plain subscriptions (`r.psubs`) are delivered first and are not shown. For each queue group that matched (`r.qsubs[i]` is the group's member list, local clients and one entry per route or leaf that carries members), the server picks a **random start index** and walks the list from there; the first entry that can take the message gets it. What "can take" means depends on where the message came from (`c.kind`, the `src`) and where the candidate lives (`sub.client.kind`, the `dst`):

- from a **client** (`src == CLIENT`): a local client member is delivered to at once; a **route** entry (a member on another server of the cluster, or one that server holds for a leaf) is picked and the walk ends — `rsub = sub; break` — unless it is held on behalf of a leaf (`sub.origin`), which only becomes the fallback; a **leaf** entry is remembered as the fallback and skipped. So a message from a local publisher is spread over local members and the peers' members alike — the sublist expands a peer's entry to its member count (below) — with no preference for the local ones (run E measures it), and a leaf is chosen only when nothing else can take the message;
- from a **route** (`src == ROUTER`): only local clients and leaves are candidates — a routed message is never routed again — and among the fallbacks a leaf is favoured over a route (a coin flip between two leaves, #6040);
- a **spoke leaf** never forwards to a route (`isSpokeLeafNode`).

```go
 5220	func (c *client) processMsgResults(acc *Account, r *SublistResult, msg, deliver, subject, reply []byte, flags int) (bool, [][]byte) {
 5221		// For sending messages across routes and leafnodes.
 5222		// Reset if we have one since we reuse this data structure.
```

```go
 5426		// Set these up to optionally filter based on the queue lists.
 5427		// This is for messages received from routes which will have directed
 5428		// guidance on which queue groups we should deliver to.
 5429		qf := c.pa.queues
 5430	
 5431		// Declared here because of goto.
 5432		var queues [][]byte
 5433	
 5434		var leafOrigin string
 5435		switch c.kind {
 5436		case ROUTER:
 5437			if len(c.pa.origin) > 0 {
 5438				// Picture a message sent from a leafnode to a server that then routes
 5439				// this message: CluserA -leaf-> HUB1 -route-> HUB2
 5440				// Here we are in HUB2, so c.kind is a ROUTER, but the message will
 5441				// contain a c.pa.origin set to "ClusterA" to indicate that this message
 5442				// originated from that leafnode cluster.
 5443				leafOrigin = bytesToString(c.pa.origin)
 5444			}
 5445		case LEAF:
 5446			leafOrigin = c.remoteCluster()
 5447		}
 5448	
 5449		// For all routes/leaf/gateway connections, we may still want to send messages to
 5450		// leaf nodes or routes even if there are no queue filters since we collect
 5451		// them above and do not process inline like normal clients.
 5452		// However, do select queue subs if asked to ignore empty queue filter.
 5453		if (c.kind == LEAF || c.kind == ROUTER || c.kind == GATEWAY) && len(qf) == 0 && flags&pmrIgnoreEmptyQueueFilter == 0 {
 5454			goto sendToRoutesOrLeafs
 5455		}
 5456	
```

```go
 5457		// Process queue subs
 5458		for i := 0; i < len(r.qsubs); i++ {
 5459			qsubs := r.qsubs[i]
 5460			// If we have a filter check that here. We could make this a map or someting more
 5461			// complex but linear search since we expect queues to be small. Should be faster
 5462			// and more cache friendly.
 5463			if qf != nil && len(qsubs) > 0 {
 5464				tqn := qsubs[0].queue
 5465				for _, qn := range qf {
 5466					if bytes.Equal(qn, tqn) {
 5467						goto selectQSub
 5468					}
 5469				}
 5470				continue
 5471			}
 5472	
 5473		selectQSub:
 5474			// We will hold onto remote or lead qsubs when we are coming from
 5475			// a route or a leaf node just in case we can no longer do local delivery.
 5476			var rsub, sub *subscription
 5477			var _ql [32]*subscription
 5478	
 5479			src := c.kind
 5480			// If we just came from a route we want to prefer local subs.
 5481			// So only select from local subs but remember the first rsub
 5482			// in case all else fails.
 5483			if src == ROUTER {
 5484				ql := _ql[:0]
 5485				for i := 0; i < len(qsubs); i++ {
 5486					sub = qsubs[i]
 5487					if dst := sub.client.kind; dst == LEAF || dst == ROUTER {
 5488						// If the destination is a LEAF, we first need to make sure
 5489						// that we would not pick one that was the origin of this
 5490						// message.
 5491						if dst == LEAF && leafOrigin != _EMPTY_ && leafOrigin == sub.client.remoteCluster() {
 5492							continue
 5493						}
 5494						// If we have assigned a ROUTER rsub already, replace if
 5495						// the destination is a LEAF since we want to favor that.
 5496						if rsub == nil || (rsub.client.kind == ROUTER && dst == LEAF) {
 5497							rsub = sub
 5498						} else if dst == LEAF {
 5499							// We already have a LEAF and this is another one.
 5500							// Flip a coin to see if we swap it or not.
 5501							// See https://github.com/nats-io/nats-server/issues/6040
 5502							if fastrand.Uint32()%2 == 1 {
 5503								rsub = sub
 5504							}
 5505						}
 5506					} else {
 5507						ql = append(ql, sub)
 5508					}
 5509				}
 5510				qsubs = ql
 5511			}
 5512	
 5513			sindex := 0
 5514			lqs := len(qsubs)
 5515			if lqs > 1 {
 5516				sindex = int(fastrand.Uint32() % uint32(lqs))
 5517			}
 5518	
 5519			// Find a subscription that is able to deliver this message starting at a random index.
 5520			// Note that if the message came from a ROUTER, we will only have CLIENT or LEAF
 5521			// queue subs here, otherwise we can have all types.
 5522			for i := 0; i < lqs; i++ {
 5523				if sindex+i < lqs {
 5524					sub = qsubs[sindex+i]
 5525				} else {
 5526					sub = qsubs[(sindex+i)%lqs]
 5527				}
 5528				if sub == nil {
 5529					continue
 5530				}
 5531	
 5532				// If we are a spoke leaf node make sure to not forward across routes.
 5533				// This mimics same behavior for normal subs above.
 5534				if c.kind == LEAF && c.isSpokeLeafNode() && sub.client.kind == ROUTER {
 5535					continue
 5536				}
 5537	
 5538				// We have taken care of preferring local subs for a message from a route above.
 5539				// Here we just care about a client or leaf and skipping a leaf and preferring locals.
 5540				if dst := sub.client.kind; dst == ROUTER || dst == LEAF {
 5541					if (src == LEAF || src == CLIENT) && dst == LEAF {
 5542						// If we come from a LEAF and are about to pick a LEAF connection,
 5543						// make sure this is not the same leaf cluster.
 5544						if src == LEAF && leafOrigin != _EMPTY_ && leafOrigin == sub.client.remoteCluster() {
 5545							continue
 5546						}
 5547						// Remember that leaf in case we don't find any other candidate.
 5548						// We already start randomly in lqs slice, so we don't need
 5549						// to do a random swap if we already have an rsub like we do
 5550						// when src == ROUTER above.
 5551						if rsub == nil {
 5552							rsub = sub
 5553						}
 5554						continue
 5555					} else {
 5556						// We want to favor qsubs in our own cluster. If the routed
 5557						// qsub has an origin, it means that is on behalf of a leaf.
 5558						// We need to treat it differently.
 5559						if len(sub.origin) > 0 {
 5560							// If we already have an rsub, nothing to do. Also, do
 5561							// not pick a routed qsub for a LEAF origin cluster
 5562							// that is the same than where the message comes from.
 5563							if rsub == nil && (leafOrigin == _EMPTY_ || leafOrigin != bytesToString(sub.origin)) {
 5564								rsub = sub
 5565							}
 5566							continue
 5567						}
 5568						// This is a qsub that is local on the remote server (or
 5569						// we are connected to an older server and we don't know).
 5570						// Pick this one and be done.
 5571						rsub = sub
 5572						break
 5573					}
 5574				}
 5575	
 5576				// Assume delivery subject is normal subject to this point.
 5577				dsubj = subj
```

The delivery, the queue-name collection for the gateways, and the fallback: when a member on this server took the message the loop breaks and `rsub` is cleared; otherwise the remembered route or leaf entry is added to the route targets and the message leaves the server.

```go
 5625					}
 5626				}
 5627	
 5628				var delivered bool
 5629				if !skipDelivery {
 5630					mh := c.msgHeader(dsubj, creply, sub)
 5631					delivered = c.deliverMsg(prodIsMQTT, sub, acc, subject, creply, mh, msg, rplyHasGWPrefix)
 5632					if restorePaTrace {
 5633						c.pa.trace = mt
 5634					}
 5635				}
 5636				if skipDelivery || delivered {
 5637					// Update only if not skipped.
 5638					if !skipDelivery && sub.icb == nil {
 5639						dlvMsgs++
 5640						switch sub.client.kind {
 5641						case ROUTER:
 5642							dlvRouteMsgs++
 5643						case LEAF:
 5644							dlvLeafMsgs++
 5645						case CLIENT:
 5646							dlvClientMsgs++
 5647						}
 5648					}
 5649					// Do the rest even when message delivery was skipped.
 5650					didDeliver = true
 5651					// Clear rsub
 5652					rsub = nil
 5653					if flags&pmrCollectQueueNames != 0 {
 5654						queues = append(queues, sub.queue)
 5655					}
 5656					break
 5657				}
 5658			}
 5659	
 5660			if rsub != nil {
 5661				// We are here if we have selected a leaf or route as the destination,
 5662				// or if we tried to deliver to a local qsub but failed.
 5663				c.addSubToRouteTargets(rsub)
```

## server/sublist.go — a remote queue entry is expanded to its weight before the pick

The sublist's match result "shadows" a routed or leaf queue subscription once per member behind it (`qw`), so the random pick in `processMsgResults` is over members, not over connections: one local member and a peer holding three yields four entries and a quarter each (run E2). The expansion is what makes the selection uniform across a cluster — and what places every copy of a leaf's entry side by side in the list, which run H5 shows the walk skipping over onto the *next* local member.

```go
  728		// Queue subscriptions
  729		for qname, qr := range n.qsubs {
  730			if len(qr) == 0 {
  731				continue
  732			}
  733			// Need to find matching list in results
  734			var i int
  735			if i = findQSlot([]byte(qname), results.qsubs); i < 0 {
  736				i = len(results.qsubs)
  737				nqsub := make([]*subscription, 0, len(qr))
  738				results.qsubs = append(results.qsubs, nqsub)
  739			}
  740			for sub := range qr {
  741				if isRemoteQSub(sub) {
  742					ns := atomic.LoadInt32(&sub.qw)
  743					// Shadow these subscriptions
  744					for n := 0; n < int(ns); n++ {
  745						results.qsubs[i] = append(results.qsubs[i], sub)
  746					}
  747				} else {
  748					results.qsubs[i] = append(results.qsubs[i], sub)
  749				}
  750			}
  751		}
```

## server/route.go — a remote queue group is one entry with a weight

A server learns of queue members on a peer through `RS+ <account> <subject> <queue> <weight>`; the weight is the number of members behind that route, kept in `sub.qw` and updated as members join and leave, and expanded by the sublist as above.

```go
 1486	func (c *client) processRemoteSub(argo []byte, hasOrigin bool) (err error) {
 1487		// Indicate activity.
 1488		c.in.subs++
 1489	
 1490		srv := c.srv
 1491		if srv == nil {
 1492			return nil
 1493		}
 1494	
 1495		// We copy `argo` to not reference the read buffer. However, we will
 1496		// prefix with a code that says if the remote sub is for a leaf
 1497		// (hasOrigin == true) or not to prevent key collisions. Imagine:
 1498		// "RS+ foo bar baz 1\r\n" => "foo bar baz" (a routed queue sub)
 1499		// "LS+ foo bar baz\r\n"   => "foo bar baz" (a route leaf sub on "baz",
```

```go
 1570			sub.queue = nil
 1571		case subjIdx + 3:
 1572			sub.queue = args[subjIdx+1]
 1573			sub.qw = int32(parseSize(args[subjIdx+2]))
 1574			// TODO: (ik) We should have a non empty queue name and a queue
 1575			// weight >= 1. For 2.11, we may want to return an error if that
 1576			// is not the case, but for now just overwrite `delta` if queue
 1577			// weight is greater than 1 (it is possible after a reconnect/
 1578			// server restart to receive a queue weight > 1 for a new sub).
 1579			if sub.qw > 1 {
 1580				delta = sub.qw
 1581			}
 1582		default:
```

## server/gateway.go — the queue names already served are excluded from the remote clusters

`sendMsgToGateways` receives the queue names the local delivery served (`qgroups`, collected under `pmrCollectQueueNames` above); a remote cluster's queue interest under one of those names is dropped from the message's queue list, and the gateway is skipped entirely when no plain interest and no other queue remains. The whole of geo-affinity is these lines (the wiki's `gateway` page quotes 2652–2653 from `topology-v2.14.6.md`).

```go
 2539	func (c *client) sendMsgToGateways(acc *Account, msg, subject, reply []byte, qgroups [][]byte, checkLeafQF bool) bool {
```

```go
 2611			} else {
 2612				// Plain sub interest and queue sub results for this account/subject
 2613				psi, qr := gwc.gatewayInterest(accName, subject)
 2614				if !psi && qr == nil {
 2615					continue
 2616				}
 2617				queues = queuesa[:0]
 2618				if qr != nil {
 2619					for i := 0; i < len(qr.qsubs); i++ {
 2620						qsubs := qr.qsubs[i]
 2621						if len(qsubs) > 0 {
 2622							queue := qsubs[0].queue
 2623							if checkLeafQF {
 2624								// Skip any queue that is not in the leaf's queue filter.
 2625								skip := true
 2626								for _, qn := range c.pa.queues {
 2627									if bytes.Equal(queue, qn) {
 2628										skip = false
 2629										break
 2630									}
 2631								}
 2632								if skip {
 2633									continue
 2634								}
 2635								// Now we still need to check that it was not delivered
 2636								// locally by checking the given `qgroups`.
 2637							}
 2638							add := true
 2639							for _, qn := range qgroups {
 2640								if bytes.Equal(queue, qn) {
 2641									add = false
 2642									break
 2643								}
 2644							}
 2645							if add {
 2646								qgroups = append(qgroups, queue)
 2647								queues = append(queues, queue...)
 2648								queues = append(queues, ' ')
 2649							}
 2650						}
 2651					}
 2652				}
 2653				if !psi && len(queues) == 0 {
 2654					continue
```
