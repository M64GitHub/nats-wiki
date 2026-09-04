// authclient — a nats.go v1.53.1 client on a .creds file, printing every
// connection callback it gets, so the library's response to a credential
// expiring on a live connection is on the record: which errors arrive, in
// which order, whether it reconnects, and what finally closes it.
package main

import (
	"flag"
	"fmt"
	"time"

	"github.com/nats-io/nats.go"
)

func main() {
	url := flag.String("url", nats.DefaultURL, "server URL")
	creds := flag.String("creds", "", "path to a .creds file")
	dur := flag.Duration("for", 90*time.Second, "how long to run")
	ignore := flag.Bool("ignore-abort", false, "set IgnoreAuthErrorAbort")
	maxRe := flag.Int("max-reconnects", 60, "MaxReconnects")
	wait := flag.Duration("reconnect-wait", 500*time.Millisecond, "ReconnectWait")
	flag.Parse()

	t0 := time.Now()
	say := func(f string, a ...any) {
		fmt.Printf("t+%6.2fs  %s\n", time.Since(t0).Seconds(), fmt.Sprintf(f, a...))
	}

	opts := []nats.Option{
		nats.Name("order-svc"),
		nats.UserCredentials(*creds),
		nats.MaxReconnects(*maxRe),
		nats.ReconnectWait(*wait),
		nats.ErrorHandler(func(nc *nats.Conn, s *nats.Subscription, err error) {
			say("ErrorHandler: %v   (status %v)", err, nc.Status())
		}),
		nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
			say("Disconnected: err=%v  (status %v)", err, nc.Status())
		}),
		nats.ReconnectHandler(func(nc *nats.Conn) {
			say("Reconnected to %s (status %v, reconnects %d)", nc.ConnectedUrl(), nc.Status(), nc.Reconnects)
		}),
		nats.ClosedHandler(func(nc *nats.Conn) {
			say("CLOSED. LastError=%v", nc.LastError())
		}),
	}
	if *ignore {
		opts = append(opts, nats.IgnoreAuthErrorAbort())
	}
	nc, err := nats.Connect(*url, opts...)
	if err != nil {
		say("connect failed: %v", err)
		return
	}
	say("connected: status=%v cid=%d server=%s", nc.Status(), func() uint64 { id, _ := nc.GetClientID(); return id }(), nc.ConnectedServerId())
	if _, err := nc.Subscribe("orders.>", func(m *nats.Msg) {}); err != nil {
		say("subscribe: %v", err)
	}
	nc.Flush()

	deadline := time.Now().Add(*dur)
	for time.Now().Before(deadline) {
		time.Sleep(2 * time.Second)
		if nc.Status() == nats.CLOSED {
			say("status CLOSED after %d reconnect(s); stopping. LastError=%v", nc.Reconnects, nc.LastError())
			return
		}
	}
	say("still %v after %v; reconnects=%d LastError=%v", nc.Status(), *dur, nc.Reconnects, nc.LastError())
}
