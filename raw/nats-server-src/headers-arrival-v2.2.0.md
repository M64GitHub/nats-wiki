<!-- source: https://github.com/nats-io/nats-server — server/server.go, server/client.go and server/const.go at tags v2.1.9 and v2.2.0, fetched from raw.githubusercontent.com on 2026-09-03 (cached in local/scratch/src/v2.1.9/ and v2.2.0/) -->
# When headers, `HPUB`/`HMSG` and `no_responders` reached the server: v2.2.0, not before

The v2.2.0 release body (`raw/release-notes/v2.2.0.md`, published 2021-03-15) lists JetStream, WebSocket, MQTT and thirty other additions and never names message headers or the no-responders reply. The source at the two tags does: **nothing** in `server.go` or `client.go` at v2.1.9 (2020-11-02, the release before) matches `headers`, `Headers`, `HPUB`, `HMSG` or `503`; at v2.2.0 the `INFO` struct advertises `headers`, the `CONNECT` options carry `headers` and `no_responders`, a `CONNECT` asking for the second without the first is refused, and a request nobody could receive is answered with `HMSG … NATS/1.0 503` — **without** a `Nats-Subject` header, which the v2.12.0 release body adds ("No responders errors from the server now include the original subject in the `Nats-Subject` header (#5250)").

## The counts at each tag

| tag | published | `grep -c 'headers\|Headers' server/server.go` | `… server/client.go` | `grep -n 'HMSG\|HPUB\|503' server/client.go` |
|---|---|---|---|---|
| v2.1.9 | 2020-11-02 | 0 | 0 | no match |
| v2.2.0 | 2021-03-15 | 5 (one of them `Info.Headers`) | 22 | `hdrLine`, `emptyHdrLine`, the 503 below |

(`raw/release-notes/_tags-and-dates.md` has the dates.)

## server/server.go at v2.2.0 — `INFO` advertises `headers`

```go
   59	type Info struct {
   60		ID                string   `json:"server_id"`
   61		Name              string   `json:"server_name"`
   62		Version           string   `json:"version"`
   63		Proto             int      `json:"proto"`
   64		GitCommit         string   `json:"git_commit,omitempty"`
   65		GoVersion         string   `json:"go"`
   66		Host              string   `json:"host"`
   67		Port              int      `json:"port"`
   68		Headers           bool     `json:"headers"`
   69		AuthRequired      bool     `json:"auth_required,omitempty"`
   70		TLSRequired       bool     `json:"tls_required,omitempty"`
   71		TLSVerify         bool     `json:"tls_verify,omitempty"`
   72		TLSAvailable      bool     `json:"tls_available,omitempty"`
   73		MaxPayload        int32    `json:"max_payload"`
   74		JetStream         bool     `json:"jetstream,omitempty"`
   75		IP                string   `json:"ip,omitempty"`
   76		CID               uint64   `json:"client_id,omitempty"`
```

The same struct at v2.1.9 (`server.go:61–…`) goes from `Port` straight to `AuthRequired`; there is no `Headers` field.

## server/client.go at v2.2.0 — the header version line, the two `CONNECT` fields, the refusal, the 503

```go
  120	const (
  121		hdrLine      = "NATS/1.0\r\n"
  122		emptyHdrLine = "NATS/1.0\r\n\r\n"
  123	)
```

```go
  508	type clientOpts struct {
  509		Echo         bool   `json:"echo"`
  510		Verbose      bool   `json:"verbose"`
  511		Pedantic     bool   `json:"pedantic"`
  512		TLSRequired  bool   `json:"tls_required"`
  513		Nkey         string `json:"nkey,omitempty"`
  514		JWT          string `json:"jwt,omitempty"`
  515		Sig          string `json:"sig,omitempty"`
  516		Token        string `json:"auth_token,omitempty"`
  517		Username     string `json:"user,omitempty"`
  518		Password     string `json:"pass,omitempty"`
  519		Name         string `json:"name"`
  520		Lang         string `json:"lang"`
  521		Version      string `json:"version"`
  522		Protocol     int    `json:"protocol"`
  523		Account      string `json:"account,omitempty"`
  524		AccountNew   bool   `json:"new_account,omitempty"`
  525		Headers      bool   `json:"headers,omitempty"`
  526		NoResponders bool   `json:"no_responders,omitempty"`
  527	
  528		// Routes and Leafnodes only
  529		Import *SubjectPermission `json:"import,omitempty"`
  530		Export *SubjectPermission `json:"export,omitempty"`
```

```go
 1761			// Check to see that if no_responders is requested
 1762			// they have header support on as well.
 1763			c.mu.Lock()
 1764			misMatch := c.opts.NoResponders && !c.headers
 1765			c.mu.Unlock()
 1766			if misMatch {
 1767				c.sendErr(ErrNoRespondersRequiresHeaders.Error())
 1768				c.closeConnection(NoRespondersRequiresHeaders)
 1769				return ErrNoRespondersRequiresHeaders
 1770			}
```

```go
 3492		// Check to see if we did not deliver to anyone and the client has a reply subject set
 3493		// and wants notification of no_responders.
 3494		if !didDeliver && len(c.pa.reply) > 0 {
 3495			c.mu.Lock()
 3496			if c.opts.NoResponders {
 3497				if sub := c.subForReply(c.pa.reply); sub != nil {
 3498					proto := fmt.Sprintf("HMSG %s %s 16 16\r\nNATS/1.0 503\r\n\r\n\r\n", c.pa.reply, sub.sid)
 3499					c.queueOutbound([]byte(proto))
 3500					c.addToPCD(c)
 3501				}
 3502			}
 3503			c.mu.Unlock()
 3504		}
 3505	
 3506		return didDeliver, false
 3507	}
 3508	
 3509	// Return the subscription for this reply subject. Only look at normal subs for this client.
 3510	func (c *client) subForReply(reply []byte) *subscription {
 3511		r := c.acc.sl.Match(string(reply))
 3512		for _, sub := range r.psubs {
 3513			if sub.client == c {
 3514				return sub
 3515			}
 3516		}
```

At v2.14.6 the same send reads `HMSG %s %s %d %d\r\nNATS/1.0 503\r\nNats-Subject: %s\r\n\r\n\r\n` with `hdrLen := 32 + len(c.pa.subject)` (`client.go:4508–4511`, in `request-reply-v2.14.6.md`).
