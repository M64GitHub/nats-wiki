#!/usr/bin/env python3
# core-delivery-raw.py — a raw NATS protocol writer for core-delivery-run.sh (nats-server v2.14.6 runs, 2026-09-03).
# Connects, prints the INFO line, sends CONNECT with the given extra fields, then every --send line verbatim
# (CRLF appended), and prints everything the server sends back until --wait seconds pass or the server
# closes the socket. PING from the server is answered. Two generators for big frames:
#   PUBBIG <subject> <n>          -> "PUB <subject> <n>\r\n" + n bytes of 'x' + "\r\n"
#   HPUBBIG <subject> <hdr> <body> -> "HPUB <subject> <hdr> <hdr+body>\r\n" + an exact <hdr>-byte header block + body
import argparse, json, socket, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=14222)
ap.add_argument("--connect", default="{}", help="extra CONNECT fields as JSON, e.g. '{\"pedantic\":true}'")
ap.add_argument("--send", action="append", default=[])
ap.add_argument("--wait", type=float, default=1.0)
a = ap.parse_args()

s = socket.create_connection(("127.0.0.1", a.port), timeout=a.wait)
f = s.makefile("rb")
info = f.readline().decode().strip()
print("<<", info)
opts = {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": False, "pedantic": False, "headers": True}
opts.update(json.loads(a.connect))
line = "CONNECT " + json.dumps(opts)
print(">>", line)
buf = (line + "\r\n").encode()
for l in a.send:
    if l.startswith("PUBBIG "):
        _, subj, n = l.split(); n = int(n)
        buf += f"PUB {subj} {n}\r\n".encode() + b"x" * n + b"\r\n"
        print(f">> PUB {subj} {n}  (+{n} payload bytes)")
    elif l.startswith("HPUBBIG "):
        _, subj, h, b = l.split(); h = int(h); b = int(b)
        head = b"NATS/1.0\r\nX-Pad: "
        hdr = head + b"p" * (h - len(head) - 4) + b"\r\n\r\n"
        assert len(hdr) == h
        buf += f"HPUB {subj} {h} {h + b}\r\n".encode() + hdr + b"y" * b + b"\r\n"
        print(f">> HPUB {subj} {h} {h + b}  (+{h + b} bytes: {h} header, {b} body)")
    else:
        buf += (l + "\r\n").encode()
        print(">>", l if l else "(empty line)")
try:
    s.sendall(buf)
except (BrokenPipeError, ConnectionResetError) as e:
    print(f"-- send interrupted: {e.__class__.__name__} (the server closed the socket before the frame was fully written)")

deadline = time.time() + a.wait
closed = False
while time.time() < deadline:
    try:
        raw = f.readline()
    except (socket.timeout, ConnectionResetError):
        break
    if not raw:
        closed = True
        break
    t = raw.decode(errors="replace").rstrip("\r\n")
    if t == "PING":
        s.sendall(b"PONG\r\n"); print("<< PING  (answered)"); continue
    if t.startswith("MSG ") or t.startswith("HMSG "):
        p = t.split(); total = int(p[-1]); body = f.read(total + 2)
        shown = body[:120].decode(errors="replace").replace("\r\n", "\\r\\n")
        print("<<", t, "| payload:", shown + ("…" if total > 120 else ""))
        continue
    print("<<", t)
print("-- socket closed by the server" if closed else f"-- socket still open after {a.wait}s")
