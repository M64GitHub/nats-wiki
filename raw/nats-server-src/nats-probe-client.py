#!/usr/bin/env python3
"""natsprobe.py — a minimal, stdlib-only NATS client written to run acknowledgment
experiments the `nats` CLI cannot express (it has no delayed-nak flag at v0.4.0).

Speaks enough of the NATS client protocol to: connect, subscribe, publish, issue a
JetStream pull request, and answer a delivered message with +ACK / -NAK / -NAK {"delay":n}.
Every delivered message is returned with a monotonic receive timestamp so a redelivery
interval can be measured.
"""
import socket, json, time, threading, queue, itertools, sys

class Nats:
    def __init__(self, host="127.0.0.1", port=4222, name="probe"):
        self.s = socket.create_connection((host, port))
        self.f = self.s.makefile("rb")
        self.info = json.loads(self.f.readline().decode()[5:])
        self.s.sendall(("CONNECT " + json.dumps({
            "verbose": False, "pedantic": False, "tls_required": False,
            "name": name, "lang": "python-probe", "version": "0.1",
            "protocol": 1, "headers": True, "no_responders": True}) + "\r\nPING\r\n").encode())
        assert self.f.readline().strip() == b"PONG", "no PONG from server"
        self.sid = itertools.count(1)
        self.q = queue.Queue()
        self.t0 = time.monotonic()
        self.stop = False
        threading.Thread(target=self._reader, daemon=True).start()

    def _reader(self):
        while not self.stop:
            try:
                line = self.f.readline()
            except OSError:
                return
            except Exception as e:
                print("READER ERR", e, file=sys.stderr); return
            if not line:
                return
            p = line.decode(errors="replace").strip().split()
            if not p:
                continue
            op = p[0].upper()
            if op == "PING":
                self.s.sendall(b"PONG\r\n")
            elif op == "-ERR":
                print("SERVER -ERR:", line.decode().strip(), file=sys.stderr)
            elif op in ("MSG", "HMSG"):
                # MSG  <subj> <sid> [reply] <len>
                # HMSG <subj> <sid> [reply] <hdrlen> <totlen>
                n = 2 if op == "HMSG" else 1
                subj, sid = p[1], p[2]
                reply = p[3] if len(p) == 4 + n else None
                total = int(p[-1])
                hdrlen = int(p[-2]) if op == "HMSG" else 0
                try:
                    body = self.f.read(total + 2)[:total]
                except Exception as e:
                    print("READ BODY ERR", e, file=sys.stderr); return
                self.q.put({"t": time.monotonic() - self.t0, "subject": subj, "sid": sid,
                            "reply": reply,
                            "headers": body[:hdrlen].decode(errors="replace"),
                            "payload": body[hdrlen:].decode(errors="replace")})

    def pub(self, subject, payload=b"", reply=""):
        if isinstance(payload, str):
            payload = payload.encode()
        head = f"PUB {subject}{(' ' + reply) if reply else ''} {len(payload)}\r\n".encode()
        self.s.sendall(head + payload + b"\r\n")

    def sub(self, subject):
        sid = str(next(self.sid))
        self.s.sendall(f"SUB {subject} {sid}\r\n".encode())
        return sid

    def get(self, timeout):
        try:
            return self.q.get(timeout=timeout)
        except queue.Empty:
            return None

    def flush(self):
        self.s.sendall(b"PING\r\n"); time.sleep(0.05)

    def close(self):
        self.stop = True
        try: self.s.close()
        except OSError: pass

def now():
    return time.monotonic()
