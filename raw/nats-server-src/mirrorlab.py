#!/usr/bin/env python3
"""mirrorlab.py — stdlib-only NATS client for the mirror runs (nats-server v2.14.6, 2026-09-02).

  fill    <port> <bucket> <keys> <hot> <overwrites> <size>   publish keys once, then overwrite a hot subset
  consume <port> <stream> <consumer> <expected>              pull-consume until <expected> msgs, print rate
  scan    <port> <stream> <seconds> [filter]                 loop: ephemeral DeliverAll/AckNone consumer, pull to
                                                             pending==0, delete, repeat, for <seconds>
  lagwait <port> <stream> [interval]                         poll $JS.API.STREAM.INFO until mirror lag==0, print t
"""
import socket, json, time, threading, queue, itertools, sys, random, os

class Nats:
    def __init__(self, port, name="mirrorlab"):
        self.s = socket.create_connection(("127.0.0.1", port))
        self.s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.f = self.s.makefile("rb", buffering=1 << 20)
        self.info = json.loads(self.f.readline().decode()[5:])
        opts = {"verbose": False, "pedantic": False, "tls_required": False,
            "name": name, "lang": "python-mirrorlab", "version": "0.1", "protocol": 1, "headers": True,
            "no_responders": True}
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
            line = f.readline()
            if not line: return
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
    def flush(self, timeout=60):
        self.s.sendall(b"PING\r\n"); self.pongs.get(timeout=timeout)
    def sub(self, subj):
        sid = next(self.sid); self.s.sendall(f"SUB {subj} {sid}\r\n".encode()); return sid
    def pub(self, subj, data=b"", reply=""):
        self.s.sendall(f"PUB {subj} {reply} {len(data)}\r\n".encode() + data + b"\r\n")
    def request(self, subj, data=b"", timeout=10):
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

def status_of(hdr):
    if hdr.startswith(b"NATS/1.0"):
        first = hdr.split(b"\r\n", 1)[0].decode()
        parts = first.split(" ", 2)
        return parts[1] if len(parts) > 1 else ""
    return ""

def cmd_fill(port, bucket, keys, hot, overwrites, size, window=4000):
    """Publish with a reply inbox and keep at most <window> publishes un-acked, so the stream's inbound
    queue never overflows (an un-acked flood is dropped with 'Dropping messages due to excessive stream
    ingest rate'). Every PubAck is counted; an error PubAck is printed."""
    n = Nats(port, "fill")
    payload = ("v" * size).encode()
    pre = f"$KV.{bucket}."
    inbox = "_INBOX.fill." + os.urandom(6).hex()
    n.sub(inbox)
    acked = [0]; errs = [0]
    def drain(block):
        try:
            while True:
                m = n.q.get(block=block, timeout=60)
                if m[0] != inbox: continue
                if b'"error"' in m[3]:
                    errs[0] += 1
                    if errs[0] <= 3: print("puback error:", m[3][:200])
                acked[0] += 1
                block = False
        except queue.Empty:
            if block: raise
    sent = 0
    def send(subj):
        nonlocal sent
        n.s.sendall(f"PUB {subj} {inbox} {len(payload)}\r\n".encode() + payload + b"\r\n")
        sent += 1
        if sent - acked[0] >= window:
            while sent - acked[0] >= window // 2:
                drain(True)
        else:
            drain(False)
    t0 = time.monotonic()
    for i in range(keys):
        send(f"{pre}k{i:07d}")
    while acked[0] < sent: drain(True)
    t1 = time.monotonic()
    print(f"fill: {keys} keys written once in {t1-t0:.2f}s ({keys/(t1-t0):.0f} msg/s, every PubAck received, {errs[0]} errors)")
    rnd = random.Random(1)
    lo = keys - hot
    for i in range(overwrites):
        send(f"{pre}k{lo + rnd.randrange(hot):07d}")
    while acked[0] < sent: drain(True)
    t2 = time.monotonic()
    print(f"fill: {overwrites} overwrites on the hot {hot} keys in {t2-t1:.2f}s ({overwrites/(t2-t1):.0f} msg/s, every PubAck received, {errs[0]} errors)")
    n.close()

def pull(n, stream, consumer, inbox, batch, expires_ns, no_wait=False):
    body = {"batch": batch, "expires": expires_ns}
    if no_wait: body["no_wait"] = True
    n.pub(f"$JS.API.CONSUMER.MSG.NEXT.{stream}.{consumer}", json.dumps(body).encode(), inbox)

def cmd_consume(port, stream, consumer, expected):
    n = Nats(port, "consume")
    inbox = "_INBOX.pull." + os.urandom(6).hex()
    n.sub(inbox)
    batch = 1000
    got = 0; nbytes = 0
    t0 = time.monotonic(); last = t0; lastgot = 0
    inflight = 0
    pull(n, stream, consumer, inbox, batch, 5_000_000_000); inflight = batch
    while got < expected:
        try:
            subj, reply, hdr, data, ts = n.q.get(timeout=30)
        except queue.Empty:
            print(f"consume: timeout after {got} msgs"); break
        st = status_of(hdr)
        if st:
            # 404/408/409 — the batch ended; re-pull
            if st in ("404", "408", "409"):
                inflight = 0
                if st == "404" and got > 0:
                    print(f"consume: 404 No Messages after {got}"); break
                pull(n, stream, consumer, inbox, batch, 5_000_000_000); inflight = batch
            continue
        got += 1; nbytes += len(data); inflight -= 1
        if inflight <= batch // 2:
            pull(n, stream, consumer, inbox, batch, 5_000_000_000); inflight += batch
        now = time.monotonic()
        if now - last >= 2.0:
            print(f"[{now-t0:7.1f}s] total={got:>9}  cur={(got-lastgot)/(now-last):>9.0f} msg/s")
            last = now; lastgot = got
    t1 = time.monotonic()
    print(f"consume: {got} msgs, {nbytes} payload bytes in {t1-t0:.2f}s = {got/(t1-t0):.0f} msg/s")
    n.close()

def cmd_scan(port, stream, seconds, filt=""):
    n = Nats(port, "scan")
    inbox = "_INBOX.scan." + os.urandom(6).hex()
    n.sub(inbox)
    t0 = time.monotonic(); rounds = 0; total = 0
    while time.monotonic() - t0 < seconds:
        cfg = {"deliver_policy": "all", "ack_policy": "none", "inactive_threshold": 30_000_000_000, "mem_storage": True}
        if filt: cfg["filter_subject"] = filt
        m = n.request(f"$JS.API.CONSUMER.CREATE.{stream}", json.dumps({"stream_name": stream, "config": cfg}).encode())
        r = json.loads(m[3])
        if "error" in r:
            time.sleep(0.05); continue
        cname = r["name"]
        got = 0; pending = None; rt0 = time.monotonic()
        batch = 1000
        pull(n, stream, cname, inbox, batch, 5_000_000_000); inflight = batch
        while time.monotonic() - t0 < seconds:
            try:
                subj, reply, hdr, data, ts = n.q.get(timeout=10)
            except queue.Empty:
                break
            if subj != inbox: continue
            st = status_of(hdr)
            if st:
                inflight = 0
                if st == "404": break
                pull(n, stream, cname, inbox, batch, 5_000_000_000); inflight = batch
                continue
            got += 1; inflight -= 1
            pending = int(reply.rsplit(".", 1)[1])
            if got % 200000 == 0: print(f"scan: round {rounds+1} at {got} msgs, {time.monotonic()-t0:.2f}s since start, pending {pending}", flush=True)
            if pending == 0: break
            if inflight <= batch // 2:
                pull(n, stream, cname, inbox, batch, 5_000_000_000); inflight += batch
        rounds += 1; total += got
        print(f"scan: round {rounds} read {got} msgs in {time.monotonic()-rt0:.2f}s (pending at end: {pending})", flush=True)
        try: n.request(f"$JS.API.CONSUMER.DELETE.{stream}.{cname}", b"", timeout=5)
        except Exception: pass
    print(f"scan: {rounds} rounds, {total} msgs in {time.monotonic()-t0:.1f}s")
    n.close()

def cmd_lagwait(port, stream, interval=0.25):
    n = Nats(port, "lagwait")
    t0 = time.monotonic(); lastp = None
    while True:
        try:
            m = n.request(f"$JS.API.STREAM.INFO.{stream}", b"", timeout=10)
        except queue.Empty:
            time.sleep(interval); continue
        r = json.loads(m[3])
        if "error" in r:
            time.sleep(interval); continue
        mi = r.get("mirror") or {}
        st = r.get("state", {})
        lag = mi.get("lag"); msgs = st.get("messages"); lseq = st.get("last_seq")
        now = time.monotonic()
        if lastp is None or now - lastp >= 1.0:
            print(f"[{now-t0:7.2f}s] msgs={msgs} last_seq={lseq} lag={lag} active={mi.get('active')}", flush=True)
            lastp = now
        if lag == 0 and msgs and lseq:
            print(f"lagwait: lag 0 at {now-t0:.2f}s (msgs={msgs} last_seq={lseq})"); break
        time.sleep(interval)
    n.close()

if __name__ == "__main__":
    c = sys.argv[1]; a = sys.argv[2:]
    if c == "fill": cmd_fill(int(a[0]), a[1], int(a[2]), int(a[3]), int(a[4]), int(a[5]))
    elif c == "consume": cmd_consume(int(a[0]), a[1], a[2], int(a[3]))
    elif c == "scan": cmd_scan(int(a[0]), a[1], float(a[2]), a[3] if len(a) > 3 else "")
    elif c == "lagwait": cmd_lagwait(int(a[0]), a[1], float(a[2]) if len(a) > 2 else 0.25)
    else: print(__doc__)
