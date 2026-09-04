// rawcreds — a raw NATS client that authenticates with a .creds file and then
// prints every protocol line the server sends, verbatim, until the socket ends.
// Written so the exact `-ERR '...'` bytes at credential expiry are on the
// record rather than a client library's rendering of them.
package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	"github.com/nats-io/nkeys"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:4222", "host:port")
	creds := flag.String("creds", "", "path to a .creds file")
	name := flag.String("name", "rawcreds", "connection name")
	dur := flag.Duration("for", 60*time.Second, "how long to stay connected")
	ping := flag.Duration("ping", 5*time.Second, "how often to PING")
	flag.Parse()

	body, err := os.ReadFile(*creds)
	if err != nil {
		fmt.Println("read creds:", err)
		os.Exit(1)
	}
	ujwt, err := nkeys.ParseDecoratedJWT(body)
	if err != nil {
		fmt.Println("parse jwt:", err)
		os.Exit(1)
	}
	kp, err := nkeys.ParseDecoratedNKey(body)
	if err != nil {
		fmt.Println("parse seed:", err)
		os.Exit(1)
	}

	t0 := time.Now()
	stamp := func(f string, a ...any) {
		fmt.Printf("t+%6.2fs  %s\n", time.Since(t0).Seconds(), fmt.Sprintf(f, a...))
	}

	c, err := net.Dial("tcp", *addr)
	if err != nil {
		fmt.Println("dial:", err)
		os.Exit(1)
	}
	defer c.Close()
	r := bufio.NewReader(c)
	line, err := r.ReadString('\n')
	if err != nil {
		fmt.Println("read INFO:", err)
		os.Exit(1)
	}
	stamp("<< %s", strings.TrimRight(line, "\r\n"))
	var info struct {
		Nonce       string `json:"nonce"`
		AuthRequired bool  `json:"auth_required"`
	}
	_ = json.Unmarshal([]byte(strings.TrimPrefix(strings.TrimSpace(line), "INFO ")), &info)

	sigraw, err := kp.Sign([]byte(info.Nonce))
	if err != nil {
		fmt.Println("sign:", err)
		os.Exit(1)
	}
	sig := base64.RawURLEncoding.EncodeToString(sigraw)
	cn, _ := json.Marshal(map[string]any{
		"verbose": false, "pedantic": false, "protocol": 1, "name": *name,
		"lang": "raw", "version": "0", "headers": true, "no_responders": true,
		"jwt": ujwt, "sig": sig,
	})
	stamp(">> CONNECT (jwt+sig, %d bytes)", len(cn))
	fmt.Fprintf(c, "CONNECT %s\r\nPING\r\n", cn)

	go func() {
		for range time.Tick(*ping) {
			fmt.Fprint(c, "PING\r\n")
		}
	}()
	c.SetReadDeadline(time.Now().Add(*dur))
	for {
		line, err := r.ReadString('\n')
		if line != "" {
			stamp("<< %s", strings.TrimRight(line, "\r\n"))
		}
		if err != nil {
			stamp("socket ended: %v", err)
			return
		}
	}
}
