<!-- source: https://github.com/nats-io/nats-server at tag v2.14.6, server/const.go fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats-server v2.14.6 — `server/const.go`, the lame-duck constants

The range `constants-v2.14.6.md` stops just short of. Read while ingesting
`util/nats-server-hardened.service`, whose `TimeoutStopSec=150` is justified in a comment as
"`lame_duck_duration` + some buffer … By default, `lame_duck_duration` is 2 mins". Line numbers are
the real ones at v2.14.6:
`https://github.com/nats-io/nats-server/blob/v2.14.6/server/const.go#L196`.

```go
   186		MAX_HPUB_ARGS = 4
   187	
   188		// MAX_RSUB_ARGS Maximum possible number of arguments from a RS+/LS+ proto.
   189		MAX_RSUB_ARGS = 6
   190	
   191		// DEFAULT_MAX_CLOSED_CLIENTS is the maximum number of closed connections we hold onto.
   192		DEFAULT_MAX_CLOSED_CLIENTS = 10000
   193	
   194		// DEFAULT_LAME_DUCK_DURATION is the time in which the server spreads
   195		// the closing of clients when signaled to go in lame duck mode.
   196		DEFAULT_LAME_DUCK_DURATION = 2 * time.Minute
   197	
   198		// DEFAULT_LAME_DUCK_GRACE_PERIOD is the duration the server waits, after entering
   199		// lame duck mode, before starting closing client connections.
   200		DEFAULT_LAME_DUCK_GRACE_PERIOD = 10 * time.Second
   201	
   202		// DEFAULT_LEAFNODE_INFO_WAIT Route dial timeout.
   203		DEFAULT_LEAFNODE_INFO_WAIT = 1 * time.Second
   204	
```
