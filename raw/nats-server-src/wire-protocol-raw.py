#!/usr/bin/env python3
# wire-raw.py — a byte-level NATS wire tool for the step-5 wire-protocol runs (nats-server v2.14.6, 2026-09-04).
# Unlike core-delivery-raw.py it sends NOTHING unless told to: it prints the INFO line the server offers,
# then writes exactly the --send lines given (CRLF appended), and prints every line the server sends back
# with a millisecond timestamp relative to connect. PING is answered only with --pong.
#   --send 'CONNECT {}'        send that line verbatim
#   --send-raw '<bytes>'       same, but no CRLF is appended
#   --bigline <op> <n>         "<op> " + n bytes of 'x' + CRLF  (an over-long control line)
#   --pubbig <subject> <n>     "PUB <subject> <n>\r\n" + n bytes + CRLF
#   --tls                      wrap the socket in TLS before reading INFO (handshake-first servers)
import argparse, socket, ssl, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("--host", default="127.0.0.1")
ap.add_argument("--port", type=int, default=14222)
ap.add_argument("--send", action="append", default=[])
ap.add_argument("--wait", type=float, default=2.0)
ap.add_argument("--pong", action="store_true", help="answer server PINGs with PONG")
ap.add_argument("--no-info", action="store_true", help="do not read an INFO line first")
ap.add_argument("--label", default="")
a = ap.parse_args()

t0 = time.time()
def ts(): return f"[{(time.time()-t0)*1000:8.1f} ms]"

if a.label: print(f"### {a.label}")
s = socket.create_connection((a.host, a.port), timeout=a.wait)
f = s.makefile("rb")
if not a.no_info:
    info = f.readline()
    print(ts(), "<<", info.decode(errors="replace").rstrip("\r\n"))

out = b""
for l in a.send:
    if l.startswith("BIGLINE "):
        _, op, n = l.split(); n = int(n)
        out += op.encode() + b" " + b"x" * n + b"\r\n"
        print(ts(), ">>", f"{op} " + "x" * 20 + f"…  ({n} bytes of argument)")
    elif l.startswith("PUBBIG "):
        _, subj, n = l.split(); n = int(n)
        out += f"PUB {subj} {n}\r\n".encode() + b"x" * n + b"\r\n"
        print(ts(), ">>", f"PUB {subj} {n}  (+{n} payload bytes)")
    elif l.startswith("HPUBLINE "):
        # HPUBLINE <subject> <headerline> <payload>  -- builds NATS/1.0 + one header + payload
        _, subj, hdrline, payload = l.split(" ", 3)
        hdr = "NATS/1.0\r\n" + hdrline.replace("~", " ") + "\r\n\r\n"
        out += f"HPUB {subj} {len(hdr)} {len(hdr)+len(payload)}\r\n{hdr}{payload}\r\n".encode()
        print(ts(), ">>", f"HPUB {subj} {len(hdr)} {len(hdr)+len(payload)}  + {hdr!r} {payload!r}")
    elif l.startswith("PUBLINE "):
        _, subj, payload = l.split(" ", 2)
        out += f"PUB {subj} {len(payload)}\r\n{payload}\r\n".encode()
        print(ts(), ">>", f"PUB {subj} {len(payload)}  +  {payload!r}")
    elif l.startswith("RAW "):
        out += l[4:].encode()
        print(ts(), ">>", repr(l[4:]), "(no CRLF appended)")
    else:
        out += (l + "\r\n").encode()
        print(ts(), ">>", l if l else "(empty line)")
try:
    if out: s.sendall(out)
except (BrokenPipeError, ConnectionResetError) as e:
    print(ts(), f"-- send interrupted: {e.__class__.__name__}")

deadline = time.time() + a.wait
closed = False
while time.time() < deadline:
    s.settimeout(max(0.05, deadline - time.time()))
    try:
        raw = f.readline()
    except (socket.timeout, ConnectionResetError, OSError):
        break
    if not raw:
        closed = True
        break
    t = raw.decode(errors="replace").rstrip("\r\n")
    if t == "PING" and a.pong:
        s.sendall(b"PONG\r\n"); print(ts(), "<< PING   >> PONG"); continue
    if t.startswith("MSG ") or t.startswith("HMSG "):
        p = t.split(); total = int(p[-1]); body = f.read(total + 2)
        print(ts(), "<<", t, "| payload:", body[:100].decode(errors="replace").replace("\r\n", "\\r\\n"))
        continue
    print(ts(), "<<", t)
print(ts(), "-- socket closed by the server" if closed else f"-- socket still open after {a.wait}s")
