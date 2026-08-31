<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6 · files server/leafnode.go, server/jetstream_api.go · fetched 2026-08-31 -->
# nats-server v2.14.6 — JetStream over a leafnode: the domain and system-account rules

Only the ranges this wiki quotes are stored, with their real line numbers, so each value links to
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/<file>#L<line>`. Apache-2.0.

Read for question-bank Q42 (*why aren't my streams visible on both ends of a leafnode connection*),
against `raw/gh-discussions/gh-7834.md`. `Server.addLeafNodeConnection` (line 1951) is where the
server decides whether a leafnode connection **extends** JetStream, gets the client JetStream API
**denied**, or only carries a cross-domain **mapping**.

### `server/leafnode.go` lines 1951–1962

```go
  1951	func (s *Server) addLeafNodeConnection(c *client, srvName, clusterName string, checkForDup bool) bool {
  1952		var accName string
  1953		c.mu.Lock()
  1954		cid := c.cid
  1955		acc := c.acc
  1956		if acc != nil {
  1957			accName = acc.Name
  1958		}
  1959		myRemoteDomain := c.leaf.remoteDomain
  1960		mySrvName := c.leaf.remoteServer
  1961		remoteAccName := c.leaf.remoteAccName
  1962		myClustName := c.leaf.remoteCluster
```

### `server/leafnode.go` lines 2033–2135

```go
  2033		blockMappingOutgoing := false
  2034		// Deny (non domain) JetStream API traffic unless system account is shared
  2035		// and domain names are identical and extending is not disabled
  2036	
  2037		// Check if backwards compatibility has been enabled and needs to be acted on
  2038		forceSysAccDeny := false
  2039		if len(opts.JsAccDefaultDomain) > 0 {
  2040			if acc == sysAcc {
  2041				for _, d := range opts.JsAccDefaultDomain {
  2042					if d == _EMPTY_ {
  2043						// Extending JetStream via leaf node is mutually exclusive with a domain mapping to the empty/default domain.
  2044						// As soon as one mapping to "" is found, disable the ability to extend JS via a leaf node.
  2045						c.Noticef("Not extending remote JetStream domain %q due to presence of empty default domain", myRemoteDomain)
  2046						forceSysAccDeny = true
  2047						break
  2048					}
  2049				}
  2050			} else if domain, ok := opts.JsAccDefaultDomain[accName]; ok && domain == _EMPTY_ {
  2051				// for backwards compatibility with old setups that do not have a domain name set
  2052				c.Debugf("Skipping deny %q for account %q due to default domain", jsAllAPI, accName)
  2053				return true
  2054			}
  2055		}
  2056	
  2057		// If the server has JS disabled, it may still be part of a JetStream that could be extended.
  2058		// This is either signaled by js being disabled and a domain set,
  2059		// or in cases where no domain name exists, an extension hint is set.
  2060		// However, this is only relevant in mixed setups.
  2061		//
  2062		// If the system account connects but default domains are present, JetStream can't be extended.
  2063		if opts.JetStreamDomain != myRemoteDomain || (!opts.JetStream && (opts.JetStreamDomain == _EMPTY_ && opts.JetStreamExtHint != jsWillExtend)) ||
  2064			sysAcc == nil || acc == nil || forceSysAccDeny {
  2065			// If domain names mismatch always deny. This applies to system accounts as well as non system accounts.
  2066			// Not having a system account, account or JetStream disabled is considered a mismatch as well.
  2067			if acc != nil && acc == sysAcc {
  2068				c.Noticef("System account connected from %s", srvDecorated())
  2069				c.Noticef("JetStream not extended, domains differ")
  2070				c.mergeDenyPermissionsLocked(both, denyAllJs)
  2071				// When a remote with a system account is present in a server, unless otherwise disabled, the server will be
  2072				// started in observer mode. Now that it is clear that this not used, turn the observer mode off.
  2073				if solicited && meta != nil && meta.IsObserver() {
  2074					meta.setObserver(false, extNotExtended)
  2075					c.Debugf("Turning JetStream metadata controller Observer Mode off")
  2076					// Take note that the domain was not extended to avoid this state from startup.
  2077					writePeerState(c.srv.diskIOSemaphore(), js.config.StoreDir, meta.currentPeerState())
  2078					// Meta controller can't be leader yet.
  2079					// Yet it is possible that due to observer mode every server already stopped campaigning.
  2080					// Therefore this server needs to be kicked into campaigning gear explicitly.
  2081					meta.Campaign()
  2082				}
  2083			} else {
  2084				c.Noticef("JetStream using domains: local %q, remote %q", opts.JetStreamDomain, myRemoteDomain)
  2085				c.mergeDenyPermissionsLocked(both, denyAllClientJs)
  2086			}
  2087			blockMappingOutgoing = true
  2088		} else if acc == sysAcc {
  2089			// system account and same domain
  2090			s.sys.client.Noticef("Extending JetStream domain %q as System Account connected from server %s",
  2091				myRemoteDomain, srvDecorated())
  2092			// In an extension use case, pin leadership to server remotes connect to.
  2093			// Therefore, server with a remote that are not already in observer mode, need to be put into it.
  2094			if solicited && meta != nil && !meta.IsObserver() {
  2095				c.Debugf("Turning JetStream metadata controller Observer Mode on - System Account Connected")
  2096				// Discard any local metagroup state accumulated before the SYS-account
  2097				// leaf came up (e.g. the wrong-hint case where this server bootstrapped
  2098				// its own metagroup). The parent's view is now authoritative; without
  2099				// this reset the two raft logs stay forked because the standalone log's
  2100				// commit prefix short-circuits the follower's AE handling.
  2101				meta.setObserver(true, extExtended)
  2102				meta.Reset()
  2103			}
  2104		} else {
  2105			// This deny is needed in all cases (system account shared or not)
  2106			// If the system account is shared, jsAllAPI traffic will go through the system account.
  2107			// So in order to prevent duplicate delivery (from system and actual account) suppress it on the account.
  2108			// If the system account is NOT shared, jsAllAPI traffic has no business
  2109			c.Debugf("Adding deny %+v for account %q", denyAllClientJs, accName)
  2110			c.mergeDenyPermissionsLocked(both, denyAllClientJs)
  2111		}
  2112		// If we have a specified JetStream domain we will want to add a mapping to
  2113		// allow access cross domain for each non-system account.
  2114		if opts.JetStreamDomain != _EMPTY_ && opts.JetStream && acc != nil && acc != sysAcc {
  2115			for src, dest := range generateJSMappingTable(opts.JetStreamDomain) {
  2116				if err := acc.AddMapping(src, dest); err != nil {
  2117					c.Debugf("Error adding JetStream domain mapping: %s", err.Error())
  2118				} else {
  2119					c.Debugf("Adding JetStream Domain Mapping %q -> %s to account %q", src, dest, accName)
  2120				}
  2121			}
  2122			if blockMappingOutgoing {
  2123				src := fmt.Sprintf(jsDomainAPI, opts.JetStreamDomain)
  2124				// make sure that messages intended for this domain, do not leave the cluster via this leaf node connection
  2125				// This is a guard against a miss-config with two identical domain names and will only cover some forms
  2126				// of this issue, not all of them.
  2127				// This guards against a hub and a spoke having the same domain name.
  2128				// But not two spokes having the same one and the request coming from the hub.
  2129				c.mergeDenyPermissionsLocked(pub, []string{src})
  2130				c.Debugf("Adding deny %q for outgoing messages to account %q", src, accName)
  2131			}
  2132		}
  2133		return true
  2134	}
  2135	
```

### `server/jetstream_api.go` lines 38–43

```go
    38		// All API endpoints.
    39		jsAllAPI = "$JS.API.>"
    40	
    41		// For constructing JetStream domain prefixes.
    42		jsDomainAPI = "$JS.%s.API.>"
    43	
```

### `server/jetstream_api.go` lines 323–352

```go
   323	var denyAllClientJs = []string{jsAllAPI, "$KV.>", "$OBJ.>"}
   324	var denyAllJs = []string{jscAllSubj, raftAllSubj, jsAllAPI, "$KV.>", "$OBJ.>"}
   325	
   326	func generateJSMappingTable(domain string) map[string]string {
   327		mappings := map[string]string{}
   328		// This set of mappings is very very very ugly.
   329		// It is a consequence of what we defined the domain prefix to be "$JS.domain.API" and it's mapping to "$JS.API"
   330		// For optics $KV and $OBJ where made to be independent subject spaces.
   331		// As materialized views of JS, they did not simply extend that subject space to say "$JS.API.KV" "$JS.API.OBJ"
   332		// This is very unfortunate!!!
   333		// Furthermore, it seemed bad to require different domain prefixes for JS/KV/OBJ.
   334		// Especially since the actual API for say KV, does use stream create from JS.
   335		// To avoid overlaps KV and OBJ views append the prefix to their API.
   336		// (Replacing $KV with the prefix allows users to create collisions with say the bucket name)
   337		// This mapping therefore needs to have extra token so that the mapping can properly discern between $JS, $KV, $OBJ
   338		for srcMappingSuffix, to := range map[string]string{
   339			"INFO":       JSApiAccountInfo,
   340			"STREAM.>":   "$JS.API.STREAM.>",
   341			"CONSUMER.>": "$JS.API.CONSUMER.>",
   342			"DIRECT.>":   "$JS.API.DIRECT.>",
   343			"META.>":     "$JS.API.META.>",
   344			"SERVER.>":   "$JS.API.SERVER.>",
   345			"ACCOUNT.>":  "$JS.API.ACCOUNT.>",
   346			"$KV.>":      "$KV.>",
   347			"$OBJ.>":     "$OBJ.>",
   348		} {
   349			mappings[fmt.Sprintf("$JS.%s.API.%s", domain, srcMappingSuffix)] = to
   350		}
   351		return mappings
   352	}
```

### `server/leafnode.go` lines 1690–1700

```go
  1690			// the content of the field `Name` in the leafnode CONNECT protocol.
  1691			if info.Name == _EMPTY_ {
  1692				c.leaf.remoteServer = info.ID
  1693			} else {
  1694				c.leaf.remoteServer = info.Name
  1695			}
  1696			c.leaf.remoteDomain = info.Domain
  1697			c.leaf.remoteCluster = info.Cluster
  1698			// We send the protocol version in the INFO protocol.
  1699			// Keep track of it, so we know if this connection supports message
  1700			// tracing for instance.
```
