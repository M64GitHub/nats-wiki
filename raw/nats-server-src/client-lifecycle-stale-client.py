#!/usr/bin/env python3
# stale-client.py — a raw NATS client that connects and then never answers PING, for run D of
# raw/nats-server-src/client-lifecycle-observed-v2.14.6.md (nats-server v2.14.6, 2026-09-04).
# Prints every line the server sends with the seconds since CONNECT, so the ping interval, the
# outstanding-ping budget and the moment the server gives up are all readable off one transcript.
# --answer makes it answer PONG, for the control run.
import argparse, json, socket, time

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=14222)
ap.add_argument("--wait", type=float, default=40.0)
ap.add_argument("--answer", action="store_true", help="answer PING with PONG (the control)")
a = ap.parse_args()

s = socket.create_connection(("127.0.0.1", a.port), timeout=a.wait)
f = s.makefile("rb")
info = f.readline().decode().strip()
print("t=0.000 << " + info[:200])
t0 = time.time()
opts = {"name": "stale-probe", "lang": "python", "version": "0", "protocol": 1,
        "verbose": False, "pedantic": False, "headers": True}
s.sendall(("CONNECT " + json.dumps(opts) + "\r\nPING\r\n").encode())
print("t=%.3f >> CONNECT + PING" % (time.time() - t0))
s.settimeout(a.wait)
deadline = time.time() + a.wait
while time.time() < deadline:
    try:
        line = f.readline()
    except socket.timeout:
        print("t=%.3f -- read timed out" % (time.time() - t0)); break
    if not line:
        print("t=%.3f -- server closed the socket" % (time.time() - t0)); break
    txt = line.decode(errors="replace").rstrip("\r\n")
    print("t=%.3f << %s" % (time.time() - t0, txt))
    if txt == "PING" and a.answer:
        s.sendall(b"PONG\r\n")
        print("t=%.3f >> PONG" % (time.time() - t0))
