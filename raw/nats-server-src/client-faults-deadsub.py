#!/usr/bin/env python3
"""A raw NATS subscriber that connects, subscribes, and then never reads
another byte off the socket -- the shape the server calls a slow consumer.

It prints what it eventually finds in the socket buffer once the server has
given up on it, so the client's side of a server-side slow consumer is on the
record next to the server's log line.
"""
import socket, time, sys

s = socket.create_connection(("127.0.0.1", 4222))
s.settimeout(5)
info = s.recv(65536)
print("INFO:", info.decode(errors="replace").strip()[:200])
s.sendall(b'CONNECT {"verbose":false,"pedantic":false,"protocol":1,"name":"deadsub","headers":true,"no_responders":true}\r\n')
s.sendall(b'SUB orders.> 1\r\nPING\r\n')
print("PONG:", s.recv(4096).decode(errors="replace").strip())
print("subscribed; now sleeping without reading for 20 s", flush=True)
t0 = time.time()
time.sleep(20)
print("woke after %.1f s; draining what the kernel buffered" % (time.time()-t0), flush=True)
s.settimeout(2)
total = 0
tail = b""
try:
    while True:
        b = s.recv(1 << 20)
        if not b:
            print("socket EOF after %d bytes" % total); break
        total += len(b); tail = b[-400:]
except socket.timeout:
    print("read timed out after %d bytes" % total)
except OSError as e:
    print("read error after %d bytes: %r" % (total, e))
print("last bytes:", tail.decode(errors="replace")[-300:])
