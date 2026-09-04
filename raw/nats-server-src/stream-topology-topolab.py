#!/usr/bin/env python3
"""topolab.py — stdlib-only NATS client for the stream-topology runs (nats-server v2.14.6, 2026-09-04).

The JetStream API is spoken directly over the wire ($JS.API.*) so that thousands of streams or
consumers can be created without paying the `nats` CLI's per-invocation connection cost, and so that
every create is timed individually.

  mkstreams  <port> <n> <prefix> <replicas> [storage]   create n streams <prefix>NNNNN on <prefix>.NNNNN.>
  rmstreams  <port> <n> <prefix>                        delete them again
  mkcons     <port> <stream> <n> <filterfmt> [prefix]   create n pull consumers, filter = filterfmt % i
  fill       <port> <subjfmt> <count> <size> <nsubj>    publish count msgs round-robin over nsubj subjects
  fillmany   <port> <subjfmt> <count> <size> <nstream>  same, but subjfmt %  (i % nstream) -> one per stream
  pubrate    <port> <subject> <count> <size>            publish count msgs to one subject, print rate
  firstfetch <port> <stream> <filter> [name]            ephemeral filtered consumer: create, fetch 1, time both
  streaminfo <port> <stream> [subjects_filter]          time $JS.API.STREAM.INFO, print sizes
  apitime    <port> <subject> [body]                    time one request/response on a $JS.API subject
  multifetch <port> <stream> <nfilters> <filterfmt>     one consumer with n disjoint filters: create + fetch 1
  conslist   <port> <stream>                            time $JS.API.CONSUMER.NAMES and .LIST
  subjdetails <port> <stream> [filter] [offset]         time STREAM.INFO with subjects_filter, show paging
  lagwait    <port> <stream> <target> [timeout]         poll STREAM.INFO until the stream holds target msgs

Every timing is wall clock on the client, printed in milliseconds, and every one is one laptop.
"""
import socket, json, time, threading, queue, itertools, sys, os

class Nats:
    def __init__(self, port, name="topolab"):
        self.s = socket.create_connection(("127.0.0.1", port))
        self.s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.f = self.s.makefile("rb", buffering=1 << 20)
        self.info = json.loads(self.f.readline().decode()[5:])
        opts = {"verbose": False, "pedantic": False, "tls_required": False,
                "name": name, "lang": "python-topolab", "version": "0.1", "protocol": 1,
                "headers": True, "no_responders": True}
        if os.environ.get("NLAB_USER"):
            opts["user"] = os.environ["NLAB_USER"]; opts["pass"] = os.environ.get("NLAB_PASS", "")
        self.s.sendall(("CONNECT " + json.dumps(opts) + "\r\nPING\r\n").encode())
        assert self.f.readline().strip() == b"PONG"
        self.sid = itertools.count(1)
        self.q = queue.Queue()
        self.pongs = queue.Queue()
        self.stop = False
        self.t = threading.Thread(target=self._reader, daemon=True); self.t.start()

    def _reader(self):
        f = self.f
        while not self.stop:
            try:
                line = f.readline()
            except Exception:
                return
            if not line:
                return
            if line.startswith(b"MSG ") or line.startswith(b"HMSG "):
                p = line.split()
                hm = p[0] == b"HMSG"
                subj = p[1].decode()
                if hm:
                    reply = p[3].decode() if len(p) == 6 else ""
                    hlen = int(p[-2]); tot = int(p[-1])
                else:
                    reply = p[3].decode() if len(p) == 5 else ""
                    hlen = 0; tot = int(p[-1])
                data = f.read(tot + 2)[:tot]
                hdr = data[:hlen] if hm else b""
                self.q.put((subj, reply, hdr, data[hlen:], time.monotonic()))
            elif line.startswith(b"PING"):
                self.s.sendall(b"PONG\r\n")
            elif line.startswith(b"PONG"):
                self.pongs.put(1)
            elif line.startswith(b"-ERR"):
                print("SERVER", line.decode().strip(), file=sys.stderr)

    def flush(self, timeout=120):
        self.s.sendall(b"PING\r\n"); self.pongs.get(timeout=timeout)

    def sub(self, subj):
        sid = next(self.sid); self.s.sendall(f"SUB {subj} {sid}\r\n".encode()); return sid

    def pub(self, subj, data=b"", reply=""):
        self.s.sendall(f"PUB {subj} {reply} {len(data)}\r\n".encode() + data + b"\r\n")

    def request(self, subj, data=b"", timeout=30):
        inbox = "_INBOX.req." + os.urandom(6).hex()
        sid = self.sub(inbox)
        self.pub(subj, data, inbox)
        while True:
            m = self.q.get(timeout=timeout)
            if m[0] == inbox:
                self.s.sendall(f"UNSUB {sid}\r\n".encode())
                return m

    def close(self):
        self.stop = True
        try: self.s.close()
        except Exception: pass


def pct(xs):
    xs = sorted(xs)
    n = len(xs)
    def p(q):
        return xs[min(n - 1, int(q * n))]
    return (f"min {xs[0]*1000:.1f}ms  P50 {p(.50)*1000:.1f}ms  P90 {p(.90)*1000:.1f}ms  "
            f"P99 {p(.99)*1000:.1f}ms  max {xs[-1]*1000:.1f}ms")


def cmd_mkstreams(port, n, prefix, replicas, storage="file"):
    c = Nats(port, "mkstreams")
    times = []
    errs = 0
    t0 = time.monotonic()
    for i in range(1, n + 1):
        name = f"{prefix}{i:05d}"
        cfg = {"name": name, "subjects": [f"{prefix.lower()}.{i:05d}.>"], "storage": storage,
               "retention": "limits", "num_replicas": int(replicas), "discard": "old"}
        a = time.monotonic()
        m = c.request("$JS.API.STREAM.CREATE." + name, json.dumps(cfg).encode(), timeout=60)
        times.append(time.monotonic() - a)
        if b'"error"' in m[3]:
            errs += 1
            if errs <= 3: print("create error:", m[3][:300].decode())
    t1 = time.monotonic()
    print(f"mkstreams: {n} streams R{replicas} {storage} in {t1-t0:.2f}s "
          f"({n/(t1-t0):.1f} streams/s, {errs} errors)")
    print("  per create:", pct(times))
    c.close()


def cmd_rmstreams(port, n, prefix):
    c = Nats(port, "rmstreams")
    t0 = time.monotonic()
    for i in range(1, n + 1):
        name = f"{prefix}{i:05d}"
        c.request("$JS.API.STREAM.DELETE." + name, b"", timeout=60)
    print(f"rmstreams: {n} deleted in {time.monotonic()-t0:.2f}s")
    c.close()


def cmd_mkcons(port, stream, n, filterfmt, prefix="C"):
    c = Nats(port, "mkcons")
    times = []; errs = 0
    t0 = time.monotonic()
    for i in range(1, n + 1):
        name = f"{prefix}{i:04d}"
        cfg = {"stream_name": stream,
               "config": {"durable_name": name, "ack_policy": "explicit",
                          "deliver_policy": "all", "filter_subject": filterfmt % i,
                          "max_ack_pending": 1000}}
        a = time.monotonic()
        m = c.request(f"$JS.API.CONSUMER.DURABLE.CREATE.{stream}.{name}",
                      json.dumps(cfg).encode(), timeout=60)
        times.append(time.monotonic() - a)
        if b'"error"' in m[3]:
            errs += 1
            if errs <= 3: print("consumer error:", m[3][:300].decode())
    t1 = time.monotonic()
    print(f"mkcons: {n} consumers on {stream} in {t1-t0:.2f}s ({n/(t1-t0):.1f}/s, {errs} errors)")
    print("  per create:", pct(times))
    c.close()


class Filler:
    """Ack-windowed publisher: at most <window> publishes outstanding, so the stream's inbound queue
    never overflows (an un-acked flood is dropped: 'Dropping messages due to excessive stream ingest
    rate')."""
    def __init__(self, c, window=4000):
        self.c = c; self.window = window
        self.inbox = "_INBOX.fill." + os.urandom(6).hex()
        c.sub(self.inbox)
        self.acked = 0; self.errs = 0; self.sent = 0
        self.firsterr = None

    def drain(self, block):
        try:
            while True:
                m = self.c.q.get(block=block, timeout=120)
                if m[0] != self.inbox: continue
                if b'"error"' in m[3]:
                    self.errs += 1
                    if self.firsterr is None: self.firsterr = m[3][:300].decode()
                self.acked += 1
                block = False
        except queue.Empty:
            if block: raise

    def send(self, subj, payload):
        self.c.s.sendall(f"PUB {subj} {self.inbox} {len(payload)}\r\n".encode() + payload + b"\r\n")
        self.sent += 1
        if self.sent - self.acked >= self.window:
            while self.sent - self.acked >= self.window // 2:
                self.drain(True)
        else:
            self.drain(False)

    def finish(self):
        while self.acked < self.sent:
            self.drain(True)


def _fill(port, subjfmt, count, size, mod, label):
    c = Nats(port, "fill")
    f = Filler(c)
    payload = (b"v" * size)
    t0 = time.monotonic()
    for i in range(count):
        f.send(subjfmt % (i % mod + 1), payload)
    f.finish()
    t1 = time.monotonic()
    print(f"{label}: {count} x {size}B over {mod} subject(s) in {t1-t0:.2f}s "
          f"({count/(t1-t0):.0f} msg/s, {f.errs} errors)")
    if f.firsterr: print("  first error:", f.firsterr)
    c.close()


def cmd_fill(port, subjfmt, count, size, nsubj):
    _fill(port, subjfmt, count, size, nsubj, "fill")


def cmd_pubrate(port, subject, count, size):
    c = Nats(port, "pubrate")
    f = Filler(c)
    payload = (b"v" * size)
    t0 = time.monotonic()
    for _ in range(count):
        f.send(subject, payload)
    f.finish()
    t1 = time.monotonic()
    print(f"pubrate {subject}: {count} x {size}B in {t1-t0:.3f}s "
          f"({count/(t1-t0):.0f} msg/s, {f.errs} errors)")
    if f.firsterr: print("  first error:", f.firsterr)
    c.close()


def cmd_firstfetch(port, stream, filt, name=""):
    """Create an ephemeral filtered consumer on <stream> and pull one message. Prints the time the
    CONSUMER.CREATE took and the time from the pull request to the first message."""
    c = Nats(port, "firstfetch")
    inbox = "_INBOX.ff." + os.urandom(6).hex()
    c.sub(inbox)
    cfg = {"stream_name": stream,
           "config": {"ack_policy": "none", "deliver_policy": "all", "filter_subject": filt,
                      "inactive_threshold": 60_000_000_000}}
    a = time.monotonic()
    m = c.request(f"$JS.API.CONSUMER.CREATE.{stream}", json.dumps(cfg).encode(), timeout=120)
    tcreate = time.monotonic() - a
    d = json.loads(m[3])
    if "error" in d:
        print("create error:", m[3][:300].decode()); c.close(); return
    cname = d["name"]
    pending = d.get("num_pending")
    b = time.monotonic()
    c.pub(f"$JS.API.CONSUMER.MSG.NEXT.{stream}.{cname}",
          json.dumps({"batch": 1, "expires": 30_000_000_000}).encode(), inbox)
    got = None
    # A pull delivery arrives on the message's own subject, not on the pull inbox; a status
    # (404/408) arrives on the inbox with a NATS/1.0 header. Take whatever comes back first.
    while True:
        mm = c.q.get(timeout=120)
        if mm[2].startswith(b"NATS/1.0"):
            got = ("status", mm[2].split(b"\r\n")[0].decode()); break
        got = ("msg", mm[0]); break
    tfetch = time.monotonic() - b
    print(f"firstfetch {name or filt}: CONSUMER.CREATE {tcreate*1000:.1f}ms (num_pending {pending}), "
          f"first message {tfetch*1000:.1f}ms -> {got[1]}")
    c.close()


def cmd_streaminfo(port, stream, subjects_filter=""):
    c = Nats(port, "streaminfo")
    body = {}
    if subjects_filter:
        body["subjects_filter"] = subjects_filter
    a = time.monotonic()
    m = c.request("$JS.API.STREAM.INFO." + stream, json.dumps(body).encode() if body else b"",
                  timeout=120)
    dt = time.monotonic() - a
    d = json.loads(m[3])
    if "error" in d:
        print("info error:", m[3][:300].decode()); c.close(); return
    st = d.get("state", {})
    nsub = len(st.get("subjects", {}) or {})
    print(f"streaminfo {stream}{' filter=' + subjects_filter if subjects_filter else ''}: "
          f"{dt*1000:.1f}ms, reply {len(m[3])} bytes, messages {st.get('messages')}, "
          f"bytes {st.get('bytes')}, num_subjects {st.get('num_subjects')}, subjects returned {nsub}")
    c.close()


def cmd_apitime(port, subject, body=""):
    c = Nats(port, "apitime")
    a = time.monotonic()
    m = c.request(subject, body.encode(), timeout=120)
    dt = time.monotonic() - a
    print(f"apitime {subject}: {dt*1000:.1f}ms, {len(m[3])} bytes")
    print("  ", m[3][:400].decode())
    c.close()


def cmd_multifetch(port, stream, nfilters, filterfmt, label=""):
    """One ephemeral consumer with <nfilters> disjoint filter_subjects (the 2.10 multi-filter form).
    Times the CONSUMER.CREATE and the first message out of it."""
    c = Nats(port, "multifetch")
    inbox = "_INBOX.mf." + os.urandom(6).hex()
    c.sub(inbox)
    filters = [filterfmt % i for i in range(1, int(nfilters) + 1)]
    cfg = {"stream_name": stream,
           "config": {"ack_policy": "none", "deliver_policy": "all", "filter_subjects": filters,
                      "inactive_threshold": 60_000_000_000}}
    a = time.monotonic()
    m = c.request(f"$JS.API.CONSUMER.CREATE.{stream}", json.dumps(cfg).encode(), timeout=300)
    tcreate = time.monotonic() - a
    d = json.loads(m[3])
    if "error" in d:
        print(f"multifetch {nfilters} filters: create error after {tcreate*1000:.1f}ms:",
              m[3][:300].decode()); c.close(); return
    cname = d["name"]; pending = d.get("num_pending")
    b = time.monotonic()
    c.pub(f"$JS.API.CONSUMER.MSG.NEXT.{stream}.{cname}",
          json.dumps({"batch": 1, "expires": 30_000_000_000}).encode(), inbox)
    while True:
        mm = c.q.get(timeout=120)
        got = mm[0] if not mm[2] else mm[2].split(b"\r\n")[0].decode()
        break
    tfetch = time.monotonic() - b
    print(f"multifetch {label or nfilters}: {nfilters} disjoint filters, CONSUMER.CREATE "
          f"{tcreate*1000:.1f}ms (num_pending {pending}), first message {tfetch*1000:.1f}ms")
    c.request(f"$JS.API.CONSUMER.DELETE.{stream}.{cname}", b"", timeout=60)
    c.close()


def cmd_conslist(port, stream):
    c = Nats(port, "conslist")
    a = time.monotonic()
    m = c.request("$JS.API.CONSUMER.NAMES." + stream, b'{"offset":0}', timeout=300)
    t1 = time.monotonic() - a
    d = json.loads(m[3])
    b = time.monotonic()
    m2 = c.request("$JS.API.CONSUMER.LIST." + stream, b'{"offset":0}', timeout=300)
    t2 = time.monotonic() - b
    print(f"conslist {stream}: CONSUMER.NAMES {t1*1000:.1f}ms (total {d.get('total')}), "
          f"CONSUMER.LIST {t2*1000:.1f}ms ({len(m2[3])} bytes)")
    c.close()


def cmd_subjdetails(port, stream, filt=">", offset="0"):
    """$JS.API.STREAM.INFO with subjects_filter (and an offset): time it, and print the paging fields
    the server sets (JSMaxSubjectDetails caps one response at 100,000 subject entries at v2.14.6)."""
    c = Nats(port, "subjdetails")
    body = {"subjects_filter": filt, "offset": int(offset)}
    a = time.monotonic()
    m = c.request("$JS.API.STREAM.INFO." + stream, json.dumps(body).encode(), timeout=600)
    dt = time.monotonic() - a
    d = json.loads(m[3])
    if "error" in d:
        print("subjdetails error:", m[3][:300].decode()); c.close(); return
    st = d.get("state", {})
    subs = st.get("subjects") or {}
    print(f"subjdetails {stream} filter={filt} offset={offset}: {dt*1000:.1f}ms, reply {len(m[3])} bytes, "
          f"total {d.get('total')}, offset {d.get('offset')}, limit {d.get('limit')}, "
          f"num_subjects {st.get('num_subjects')}, subjects returned {len(subs)}")
    c.close()


def cmd_lagwait(port, stream, target, timeout_s="300"):
    """Poll $JS.API.STREAM.INFO until the stream holds <target> messages; print how long it took."""
    c = Nats(port, "lagwait")
    t0 = time.monotonic(); last = -1
    while time.monotonic() - t0 < float(timeout_s):
        m = c.request("$JS.API.STREAM.INFO." + stream, b"", timeout=60)
        d = json.loads(m[3])
        if "error" in d:
            print("lagwait error:", m[3][:200].decode()); c.close(); return
        n = d["state"]["messages"]
        if n != last:
            last = n
        if n >= int(target):
            print(f"lagwait {stream}: reached {n} messages in {time.monotonic()-t0:.3f}s")
            c.close(); return
        time.sleep(0.02)
    print(f"lagwait {stream}: TIMED OUT at {last} of {target} after {timeout_s}s")
    c.close()


if __name__ == "__main__":
    cmd = sys.argv[1]
    a = sys.argv[2:]
    if cmd == "mkstreams":  cmd_mkstreams(int(a[0]), int(a[1]), a[2], a[3], *(a[4:5]))
    elif cmd == "rmstreams": cmd_rmstreams(int(a[0]), int(a[1]), a[2])
    elif cmd == "mkcons":   cmd_mkcons(int(a[0]), a[1], int(a[2]), a[3], *(a[4:5]))
    elif cmd == "fill":     cmd_fill(int(a[0]), a[1], int(a[2]), int(a[3]), int(a[4]))
    elif cmd == "pubrate":  cmd_pubrate(int(a[0]), a[1], int(a[2]), int(a[3]))
    elif cmd == "firstfetch": cmd_firstfetch(int(a[0]), a[1], a[2], *(a[3:4]))
    elif cmd == "streaminfo": cmd_streaminfo(int(a[0]), a[1], *(a[2:3]))
    elif cmd == "apitime":  cmd_apitime(int(a[0]), a[1], *(a[2:3]))
    elif cmd == "multifetch": cmd_multifetch(int(a[0]), a[1], int(a[2]), a[3], *(a[4:5]))
    elif cmd == "conslist": cmd_conslist(int(a[0]), a[1])
    elif cmd == "subjdetails": cmd_subjdetails(int(a[0]), a[1], *(a[2:4]))
    elif cmd == "lagwait": cmd_lagwait(int(a[0]), a[1], a[2], *(a[3:4]))
    else: print(__doc__); sys.exit(2)
