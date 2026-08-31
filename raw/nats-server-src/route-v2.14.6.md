<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/route.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — `server/route.go`, the cluster-formation ranges

The line ranges this wiki quotes for **how a route joins a cluster**: the cluster-name check on both
the solicited and the accepted side, the dynamic-name adoption path, and the two log lines a server
writes when its route listener starts. Line numbers are the real ones in `server/route.go` at
v2.14.6, so each claim links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/route.go#L<line>`.

Read while ingesting `learn/clustering/forming-a-cluster.md` and `learn/topologies/your-first-cluster.md`,
which describe a cluster-name mismatch as always splitting the cluster. The `isClusterNameDynamic()`
branches below are the exception those pages do not state.

## Route to self, and the cluster-name check on an async INFO (`processRouteInfo`)

```go
   560		s := c.srv
   561	
   562		// Detect route to self.
   563		if info.ID == s.info.ID {
   564			// Need to set this so that the close does the right thing
   565			c.route.remoteID = info.ID
   566			c.mu.Unlock()
   567			c.closeConnection(DuplicateRoute)
   568			return
   569		}
   570	
   571		// Detect if we have a mismatch of cluster names.
   572		if info.Cluster != "" && info.Cluster != clusterName {
   573			c.mu.Unlock()
   574			// If we are dynamic we may update our cluster name.
   575			// Use other if remote is non dynamic or their name is "bigger"
   576			if s.isClusterNameDynamic() && (!info.Dynamic || (strings.Compare(clusterName, info.Cluster) < 0)) {
   577				s.setClusterName(info.Cluster)
   578				s.removeAllRoutesExcept(info.ID)
   579				c.mu.Lock()
   580			} else {
   581				c.closeConnection(ClusterNameConflict)
   582				return
   583			}
   584		}
   585	
```

## The route listener's two startup log lines (`startRouteAcceptLoop`)

```go
  2712		}
  2713	
  2714		// This requires lock, so do this outside of may block.
  2715		clusterName := s.ClusterName()
  2716	
  2717		s.mu.Lock()
  2718		s.Noticef("Cluster name is %s", clusterName)
  2719		if s.isClusterNameDynamic() {
  2720			s.Warnf("Cluster name was dynamically generated, consider setting one")
  2721		}
  2722	
  2723		hp := net.JoinHostPort(opts.Cluster.Host, strconv.Itoa(port))
  2724		l, e := natsListen("tcp", hp)
```

## The cluster-name check when accepting a route (`processRouteConnect`)

```go
  3049		perms := srv.getOpts().Cluster.Permissions
  3050		clusterName := srv.ClusterName()
  3051	
  3052		// If we have a cluster name set, make sure it matches ours.
  3053		if proto.Cluster != clusterName {
  3054			shouldReject := true
  3055			// If we have a dynamic name we will do additional checks.
  3056			if srv.isClusterNameDynamic() {
  3057				if !proto.Dynamic || strings.Compare(clusterName, proto.Cluster) < 0 {
  3058					// We will take on their name since theirs is configured or higher then ours.
  3059					srv.setClusterName(proto.Cluster)
  3060					if !proto.Dynamic {
  3061						srv.optsMu.Lock()
  3062						srv.opts.Cluster.Name = proto.Cluster
  3063						srv.optsMu.Unlock()
  3064					}
  3065					c.mu.Lock()
  3066					remoteID := c.opts.Name
  3067					c.mu.Unlock()
  3068					srv.removeAllRoutesExcept(remoteID)
  3069					shouldReject = false
  3070				}
  3071			}
  3072			if shouldReject {
  3073				errTxt := fmt.Sprintf("Rejecting connection, cluster name %q does not match %q", proto.Cluster, clusterName)
  3074				c.Errorf(errTxt)
  3075				c.sendErr(errTxt)
  3076				c.closeConnection(ClusterNameConflict)
  3077				return ErrClusterNameRemoteConflict
  3078			}
  3079		}
  3080	
```
