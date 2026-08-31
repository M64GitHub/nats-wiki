---
title: "nats-server v2.14.6 — route.go, cluster formation"
type: summary
area: [topology, deploy]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/route.go
source-path: raw/nats-server-src/route-v2.14.6.md
author: nats-io/nats-server maintainers
article: "server/route.go at tag v2.14.6 — the cluster-name check and the route listener's log lines"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [routes, cluster-name, dynamic-cluster-name, ClusterNameConflict, DuplicateRoute, log-lines]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — `route.go`, cluster formation

Read to check what [[s-docs-forming-a-cluster]] and [[s-docs-your-first-cluster]] say about a
cluster-name mismatch. The rejection they describe is real and their log line is exact — **but it
only happens when both servers have a name configured.** A server with no `cluster { name: … }`
silently adopts its peer's name instead.

## Key claims

**The rejection log line, verbatim** (`server/route.go:3073`, in `processRouteConnect` — the side
*accepting* a route):

```go
errTxt := fmt.Sprintf("Rejecting connection, cluster name %q does not match %q", proto.Cluster, clusterName)
c.Errorf(errTxt)
c.sendErr(errTxt)
c.closeConnection(ClusterNameConflict)
return ErrClusterNameRemoteConflict
```

The **remote's** name is printed first, this server's second — so the phrasing in
[[s-docs-forming-a-cluster]] ("its log reads `… cluster name "east" does not match "eest"`", read on
the odd server) is the right way round. The error is also *sent to the peer* (`c.sendErr`), so the
line can appear on both ends.

**The exception the docs do not state: a dynamic cluster name is overwritten, not rejected.** Both
check sites take a different branch when this server's name was generated rather than configured
(`route.go:3056` accepting, `route.go:576` on an async INFO):

```go
if srv.isClusterNameDynamic() {
    if !proto.Dynamic || strings.Compare(clusterName, proto.Cluster) < 0 {
        // We will take on their name since theirs is configured or higher then ours.
        srv.setClusterName(proto.Cluster)
        …
        srv.removeAllRoutesExcept(remoteID)
        shouldReject = false
    }
}
```

So: **if you leave `cluster { name }` unset, the server takes the peer's name** when the peer's name
is configured, or when both are dynamic and the peer's sorts higher — and drops every other route it
holds while doing it. It joins; it does not split.

**The two log lines the route listener writes at startup** (`route.go:2718–2720`):

```go
s.Noticef("Cluster name is %s", clusterName)
if s.isClusterNameDynamic() {
    s.Warnf("Cluster name was dynamically generated, consider setting one")
}
```

`Cluster name is <name>` is the cheapest possible confirmation of what a server actually thinks it
belongs to — it needs no system account, unlike `nats server list`. The warning is the only signal
that a name was never configured.

**A route to self closes as `DuplicateRoute`** (`route.go:563–567`): the server compares the INFO's
server ID against its own, "Detect route to self", and closes. The same reason is used for a
redundant second route to a peer (`route.go:890`, and `handleDuplicateRoute`), which is the close
[[s-docs-your-first-cluster]] mentions when you write the full mesh by hand.

## Practical takeaways

- **"Every server must set the same `cluster.name`" is advice, not an invariant.** The invariant is:
  *two servers with different **configured** names cannot join*. Leave the name out and you get a
  cluster whose name nobody chose — and, on a joiner, every existing route dropped at the moment it
  adopts a new one.
- **Grep the log for `Cluster name is` before trusting a new node.** It is written by every server at
  route-listener startup, on the node itself, with no credentials involved.
- **`Cluster name was dynamically generated, consider setting one` is a warning worth treating as an
  error** in any deployment with more than one server.

## Relevance to the wiki

The verification and pitfall sections of [[build-a-3-node-cluster]], and the reason that runbook
states the log line to grep rather than only the CLI check.

## Questions it answers

Q47 (why a cluster does not form, or forms with the wrong membership) together with
[[s-docs-forming-a-cluster]].

## Pages touched

[[build-a-3-node-cluster]] · [[install-nats-server]] · [[config-keys]]
