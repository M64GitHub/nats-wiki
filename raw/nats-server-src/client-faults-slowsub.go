// slowsub — the client-side slow consumer, on nats.go v1.53.1.
//
// Subscribes asynchronously to orders.> with a handler that sleeps, bounds the
// subscription's pending buffer, and reports what the client does when the
// buffer overflows: the stderr line the default async-error handler writes,
// how many times an explicit callback fires against how many messages are
// dropped, whether the subscription and the connection survive, and what
// Pending/PendingLimits/Dropped read afterwards.
//
//	go run ./slowsub.go -mode=default   # no AsyncErrorCB set  -> defaultErrHandler
//	go run ./slowsub.go -mode=callback  # our own AsyncErrorCB -> count the fires
//	go run ./slowsub.go -mode=zero      # SetPendingLimits(0, -1)
//	go run ./slowsub.go -mode=sync      # SyncSubscription: NextMsg after overflow
package main

import (
	"flag"
	"fmt"
	"os"
	"sync/atomic"
	"time"

	"github.com/nats-io/nats.go"
)

func main() {
	url := flag.String("url", nats.DefaultURL, "server URL")
	mode := flag.String("mode", "default", "default|callback|zero|sync")
	msgs := flag.Int("msgs", 100, "pending message limit")
	sleep := flag.Duration("sleep", 20*time.Millisecond, "handler latency")
	wait := flag.Duration("wait", 6*time.Second, "how long to run")
	flag.Parse()

	var cbFires int64
	opts := []nats.Option{nats.Name("warehouse")}
	if *mode == "callback" {
		opts = append(opts, nats.ErrorHandler(func(nc *nats.Conn, s *nats.Subscription, err error) {
			n := atomic.AddInt64(&cbFires, 1)
			subj := "<nil>"
			if s != nil {
				subj = s.Subject
			}
			fmt.Printf("[cb %d] err=%q sub=%s status=%v\n", n, err, subj, nc.Status())
		}))
	}
	nc, err := nats.Connect(*url, opts...)
	if err != nil {
		fmt.Println("connect:", err)
		os.Exit(1)
	}
	defer nc.Close()
	fmt.Printf("connected: nats.go %s, server %s, cid %d, status %v\n",
		nats.Version, nc.ConnectedServerVersion(), func() uint64 { id, _ := nc.GetClientID(); return id }(), nc.Status())

	var got int64
	handler := func(m *nats.Msg) { atomic.AddInt64(&got, 1); time.Sleep(*sleep) }

	var sub *nats.Subscription
	if *mode == "sync" {
		sub, err = nc.SubscribeSync("orders.>")
	} else {
		sub, err = nc.Subscribe("orders.>", handler)
	}
	if err != nil {
		fmt.Println("subscribe:", err)
		os.Exit(1)
	}
	pm, pb, _ := sub.PendingLimits()
	fmt.Printf("pending limits at subscribe time (the defaults): msgs=%d bytes=%d\n", pm, pb)

	if *mode == "zero" {
		fmt.Printf("SetPendingLimits(0, -1) -> %v\n", sub.SetPendingLimits(0, -1))
		fmt.Printf("SetPendingLimits(-1, 0) -> %v\n", sub.SetPendingLimits(-1, 0))
		fmt.Printf("SetPendingLimits(100, -1) -> %v\n", sub.SetPendingLimits(100, -1))
		pm, pb, _ = sub.PendingLimits()
		fmt.Printf("PendingLimits() now: msgs=%d bytes=%d  (negative = unlimited)\n", pm, pb)
		return
	}

	if err := sub.SetPendingLimits(*msgs, -1); err != nil {
		fmt.Println("SetPendingLimits:", err)
		os.Exit(1)
	}
	pm, pb, _ = sub.PendingLimits()
	fmt.Printf("pending limits set: msgs=%d bytes=%d\n", pm, pb)
	nc.Flush()
	fmt.Println("--- subscribed; flood it now ---")

	deadline := time.Now().Add(*wait)
	if *mode == "sync" {
		// Read one message a beat, so the buffer overflows, then report what
		// NextMsg returns after the overflow.
		seen, slow := 0, 0
		for time.Now().Before(deadline) {
			m, err := sub.NextMsg(500 * time.Millisecond)
			if err == nats.ErrSlowConsumer {
				slow++
				d, _ := sub.Dropped()
				fmt.Printf("NextMsg -> ErrSlowConsumer (#%d), dropped so far %d\n", slow, d)
				continue
			}
			if err == nats.ErrTimeout {
				continue
			}
			if err != nil {
				fmt.Println("NextMsg:", err)
				break
			}
			_ = m
			seen++
			time.Sleep(*sleep)
		}
		fmt.Printf("sync: delivered %d, ErrSlowConsumer returned %d times\n", seen, slow)
	} else {
		for time.Now().Before(deadline) {
			time.Sleep(500 * time.Millisecond)
			m, b, _ := sub.Pending()
			d, _ := sub.Dropped()
			del, _ := sub.Delivered()
			fmt.Printf("t+%4.1fs pending=%d/%dB dropped=%d delivered=%d valid=%v status=%v conn=%v\n",
				time.Since(deadline.Add(-*wait)).Seconds(), m, b, d, del, sub.IsValid(), func() string {
					if s := subStatus(sub); s != "" {
						return s
					}
					return "?"
				}(), nc.Status())
		}
	}

	d, _ := sub.Dropped()
	del, _ := sub.Delivered()
	mp, bp, _ := sub.MaxPending()
	fmt.Printf("--- final: handler ran %d, Delivered()=%d, Dropped()=%d, MaxPending=%d/%dB, sub valid=%v, conn=%v, LastError=%v\n",
		atomic.LoadInt64(&got), del, d, mp, bp, sub.IsValid(), nc.Status(), nc.LastError())
	if *mode == "callback" {
		fmt.Printf("--- async error callback fired %d time(s) for %d dropped message(s)\n",
			atomic.LoadInt64(&cbFires), d)
	}
}

func subStatus(s *nats.Subscription) string { return fmt.Sprintf("%v", s.Type()) }
