// svc — a nats.go micro service with several endpoints, used to observe the
// services framework at nats.go v1.53.1 against nats-server v2.14.6.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/micro"
)

func stamp() string { return time.Now().Format("15:04:05.000") }

func main() {
	url := flag.String("url", nats.DefaultURL, "server url")
	user := flag.String("user", "", "user")
	pass := flag.String("pass", "", "password")
	label := flag.String("label", "A", "label printed with every log line")
	name := flag.String("name", "Inventory", "service name")
	version := flag.String("version", "1.2.3", "service version")
	slowFor := flag.Duration("slow", 3*time.Second, "how long the slow endpoint blocks")
	stopAfter := flag.Duration("stop-after", 0, "call Stop() after this long (0 = never)")
	holdAfterStop := flag.Duration("hold-after-stop", 5*time.Second, "stay alive this long after Stop()")
	flag.Parse()

	opts := []nats.Option{nats.Name("svc-" + *label)}
	if *user != "" {
		opts = append(opts, nats.UserInfo(*user, *pass))
	}
	nc, err := nats.Connect(*url, opts...)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer nc.Close()

	cfg := micro.Config{
		Name:        *name,
		Version:     *version,
		Description: "order inventory, observed",
		Metadata:    map[string]string{"zone": "eu-1", "label": *label},
		StatsHandler: func(e *micro.Endpoint) any {
			return map[string]any{"label": *label}
		},
	}
	srv, err := micro.AddService(nc, cfg)
	if err != nil {
		log.Fatalf("AddService: %v", err)
	}
	fmt.Printf("[%s %s] service %s %s id=%s\n", stamp(), *label, *name, *version, srv.Info().ID)

	grp := srv.AddGroup("orders.inventory")

	must := func(err error) {
		if err != nil {
			log.Fatalf("AddEndpoint: %v", err)
		}
	}
	// fast: default queue group "q"
	must(grp.AddEndpoint("check", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] check   <- %q on %s\n", stamp(), *label, r.Data(), r.Subject())
		r.Respond([]byte("ok from " + *label))
	})))
	// slow: blocks, same default queue group
	must(grp.AddEndpoint("slow", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] slow    <- %q (blocking %s)\n", stamp(), *label, r.Data(), *slowFor)
		time.Sleep(*slowFor)
		fmt.Printf("[%s %s] slow    -> replying\n", stamp(), *label)
		r.Respond([]byte("slow from " + *label))
	})))
	// bad: always a service error
	must(grp.AddEndpoint("bad", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] bad     <- %q\n", stamp(), *label, r.Data())
		r.Error("400", "order total must be positive", []byte(`{"field":"total"}`))
	})))
	// vip: its own queue group
	must(grp.AddEndpoint("vip", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] vip     <- %q\n", stamp(), *label, r.Data())
		r.Respond([]byte("vip from " + *label))
	}), micro.WithEndpointQueueGroup("q-vip")))
	// bcast: queue group disabled -> a plain subscription
	must(grp.AddEndpoint("bcast", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] bcast   <- %q\n", stamp(), *label, r.Data())
		r.Respond([]byte("bcast from " + *label))
	}), micro.WithEndpointQueueGroupDisabled()))
	// top: an endpoint on the service, not the group, with an explicit subject
	must(srv.AddEndpoint("health", micro.HandlerFunc(func(r micro.Request) {
		fmt.Printf("[%s %s] health  <- %q\n", stamp(), *label, r.Data())
		r.Respond([]byte("up"))
	}), micro.WithEndpointSubject("inv.health")))

	var subs []string
	for _, e := range srv.Info().Endpoints {
		subs = append(subs, fmt.Sprintf("%s=%s(q=%q)", e.Name, e.Subject, e.QueueGroup))
	}
	fmt.Printf("[%s %s] endpoints: %s\n", stamp(), *label, strings.Join(subs, " "))

	if *stopAfter > 0 {
		go func() {
			time.Sleep(*stopAfter)
			fmt.Printf("[%s %s] calling Stop()\n", stamp(), *label)
			t0 := time.Now()
			err := srv.Stop()
			fmt.Printf("[%s %s] Stop() returned after %.1f ms err=%v\n", stamp(), *label, float64(time.Since(t0).Microseconds())/1000, err)
			time.Sleep(*holdAfterStop)
			fmt.Printf("[%s %s] exiting\n", stamp(), *label)
			os.Exit(0)
		}()
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
	fmt.Printf("[%s %s] signal; exiting without Stop()\n", stamp(), *label)
}
