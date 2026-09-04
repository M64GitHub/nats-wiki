#!/usr/bin/env python3
# raw-watch.py — a raw NATS client that connects, answers PING, and prints every protocol line the
# server sends with the seconds since CONNECT. For run B3 of
# raw/nats-server-src/client-lifecycle-observed-v2.14.6.md: the asynchronous INFO a server sends its
# clients when it enters lame duck, with `ldm` and the rewritten `connect_urls`.
# Reads with recv() and its own line buffer — socket.makefile() cannot be read from a socket that
# has a timeout set.
import argparse, json, socket, time

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=4291)
ap.add_argument("--wait", type=float, default=30.0)
ap.add_argument("--sub", default="")
ap.add_argument("--user", default="")
ap.add_argument("--pass", dest="pw", default="")
ap.add_argument("--no-ping", action="store_true", help="send CONNECT without the first PING")
a = ap.parse_args()

s = socket.create_connection(("127.0.0.1", a.port), timeout=5.0)
t0 = time.time()
buf = b""

def lines(timeout):
    global buf
    s.settimeout(timeout)
    try:
        data = s.recv(65536)
    except socket.timeout:
        return None
    except OSError:
        return None
    if not data:
        return []
    buf += data
    out = []
    while b"\r\n" in buf:
        line, buf = buf.split(b"\r\n", 1)
        out.append(line.decode(errors="replace"))
    return out

got = lines(5.0) or []
for l in got:
    print("t=%.3f << %s" % (time.time() - t0, l))
opts = {"name": "raw-watch", "lang": "python", "version": "0", "protocol": 1,
        "verbose": False, "pedantic": False, "headers": True}
if a.user:
    opts["user"] = a.user; opts["pass"] = a.pw
# CONNECT *and* a PING: the server only sends asynchronous INFO updates to clients that have
# completed the first PING/PONG (`firstPongSent`, route.go:1028), so a client that never pings
# never learns its server is entering lame duck.
s.sendall(("CONNECT " + json.dumps(opts) + ("\r\n" if a.no_ping else "\r\nPING\r\n")).encode())
print("t=%.3f >> CONNECT%s" % (time.time() - t0, "" if a.no_ping else " + PING"))
if a.sub:
    s.sendall(("SUB " + a.sub + " 1\r\n").encode())
    print("t=%.3f >> SUB %s 1" % (time.time() - t0, a.sub))
deadline = time.time() + a.wait
while time.time() < deadline:
    got = lines(1.0)
    if got is None:
        continue
    if got == []:
        print("t=%.3f -- server closed the socket" % (time.time() - t0)); break
    for l in got:
        print("t=%.3f << %s" % (time.time() - t0, l))
        if l == "PING":
            s.sendall(b"PONG\r\n")
            print("t=%.3f >> PONG" % (time.time() - t0))
