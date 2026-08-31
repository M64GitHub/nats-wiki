"""Minimal MQTT 3.1.1 client, stdlib only. Written to verify docs claims, not for reuse."""
import socket, struct, sys, time

CONNECT,CONNACK,PUBLISH,PUBACK,PUBREC,PUBREL,PUBCOMP,SUBSCRIBE,SUBACK,UNSUB,UNSUBACK,PINGREQ,PINGRESP,DISCONNECT = range(1,15)

def _str(s):
    b = s.encode() if isinstance(s,str) else s
    return struct.pack("!H", len(b)) + b

def _rlen(n):
    out=b""
    while True:
        d = n % 128; n //= 128
        if n: d |= 0x80
        out += bytes([d])
        if not n: return out

def _pkt(t, flags, body):
    return bytes([(t<<4)|flags]) + _rlen(len(body)) + body

class MQTT:
    def __init__(self, host="127.0.0.1", port=1883, timeout=5):
        self.s = socket.create_connection((host,port), timeout=timeout)
        self.s.settimeout(timeout)
        self.buf=b""; self.pid=0
    def _next_pid(self):
        self.pid += 1; return self.pid
    def connect(self, client_id="probe", clean=True, user=None, pw=None,
                will_topic=None, will_payload=b"", will_qos=0, will_retain=False, level=4):
        flags = 0
        if clean: flags |= 0x02
        if will_topic is not None:
            flags |= 0x04 | ((will_qos & 3) << 3)
            if will_retain: flags |= 0x20
        if user is not None: flags |= 0x80
        if pw is not None: flags |= 0x40
        vh = _str("MQTT") + bytes([level, flags]) + struct.pack("!H", 60)
        pl = _str(client_id)
        if will_topic is not None: pl += _str(will_topic) + _str(will_payload)
        if user is not None: pl += _str(user)
        if pw is not None: pl += _str(pw)
        self.s.sendall(_pkt(CONNECT, 0, vh+pl))
        t, flags, body = self.read()
        assert t == CONNACK, f"expected CONNACK, got {t}"
        return {"session_present": body[0], "return_code": body[1]}
    def publish(self, topic, payload=b"", qos=0, retain=False):
        if isinstance(payload,str): payload = payload.encode()
        f = (qos<<1) | (1 if retain else 0)
        body = _str(topic)
        pid = None
        if qos: pid = self._next_pid(); body += struct.pack("!H", pid)
        body += payload
        self.s.sendall(_pkt(PUBLISH, f, body))
        return pid
    def subscribe(self, filters):
        if isinstance(filters,str): filters=[(filters,0)]
        pid = self._next_pid()
        body = struct.pack("!H", pid)
        for f,q in filters: body += _str(f) + bytes([q])
        self.s.sendall(_pkt(SUBSCRIBE, 2, body))
        while True:
            t, fl, b = self.read()
            if t == SUBACK: return list(b[2:])
    def read(self, timeout=None):
        if timeout is not None: self.s.settimeout(timeout)
        hdr = self._recv(1); t = hdr[0]>>4; flags = hdr[0]&0xF
        mult=1; n=0
        while True:
            d = self._recv(1)[0]; n += (d & 127)*mult
            if not (d & 0x80): break
            mult *= 128
        return t, flags, self._recv(n)
    def _recv(self, n):
        while len(self.buf) < n:
            d = self.s.recv(65536)
            if not d: raise EOFError("connection closed by server")
            self.buf += d
        out, self.buf = self.buf[:n], self.buf[n:]
        return out
    def read_publish(self, timeout=3):
        try:
            t, flags, b = self.read(timeout)
        except (socket.timeout, TimeoutError):
            return None
        if t != PUBLISH: return ("other", t, flags, b)
        tl = struct.unpack("!H", b[:2])[0]
        topic = b[2:2+tl].decode(errors="replace"); rest = b[2+tl:]
        qos = (flags>>1)&3
        if qos: rest = rest[2:]
        return {"topic":topic, "payload":rest.decode(errors="replace"),
                "qos":qos, "retain":bool(flags&1), "dup":bool(flags&8)}
    def disconnect(self):
        try: self.s.sendall(_pkt(DISCONNECT,0,b"")); self.s.close()
        except Exception: pass
    def kill(self):
        """close the socket without DISCONNECT -- an abnormal disconnect"""
        self.s.close()

    def publish_qos2(self, topic, payload=b"", retain=False, timeout=5):
        """full four-packet QoS 2 handshake: PUBLISH -> PUBREC -> PUBREL -> PUBCOMP"""
        pid = self.publish(topic, payload, qos=2, retain=retain)
        steps=[]
        while True:
            t, fl, b = self.read(timeout)
            if t == PUBREC:
                steps.append("PUBREC")
                self.s.sendall(_pkt(PUBREL, 2, struct.pack("!H", pid)))
                steps.append("PUBREL")
            elif t == PUBCOMP:
                steps.append("PUBCOMP"); return steps
    def ack(self, pid):
        self.s.sendall(_pkt(PUBACK, 0, struct.pack("!H", pid)))
