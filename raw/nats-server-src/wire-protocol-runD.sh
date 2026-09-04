#!/bin/bash
# runD.sh — the wrong-port errors, and whether an "unrecoverable" -ERR really closes the socket.
# nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
rm -rf /tmp/wp-store /tmp/wp-store2
nats-server -c full.conf >d-1.log 2>&1 & S1=$!
nats-server -c peer.conf >d-2.log 2>&1 & S2=$!
sleep 2.0

echo "### D1 · a client CONNECT on the route port 16222"
python3 wire-raw.py --port 16222 --wait 1.0 --send 'CONNECT {"lang":"python","version":"0","verbose":false}' --send 'PING' --label ""
echo; echo "### D2 · a client CONNECT on the leafnode port 17422"
python3 wire-raw.py --port 17422 --wait 1.0 --send 'CONNECT {"lang":"python","version":"0","verbose":false}' --send 'PING' --label ""
echo; echo "### D3 · a client CONNECT on the gateway port 17222"
python3 wire-raw.py --port 17222 --wait 1.0 --send 'CONNECT {"lang":"python","version":"0","verbose":false}' --send 'PING' --label ""
echo; echo "### D4 · a CONNECT with no lang on the route port (what a real route sends)"
python3 wire-raw.py --port 16222 --wait 1.0 --send 'CONNECT {"name":"fake","cluster":"WRONGNAME","verbose":false}' --send 'PING' --label ""
echo; echo "### D5 · a CONNECT claiming to be a gateway, on the route port"
python3 wire-raw.py --port 16222 --wait 1.0 --send 'CONNECT {"name":"fake","cluster":"WPC","gateway":"OTHER","verbose":false}' --send 'PING' --label ""
kill $S1 $S2 2>/dev/null; wait 2>/dev/null

echo; echo "### D6 · max_control_line: is the connection actually dead? a PING 1.5 s later"
nats-server -c mcl.conf >d-mcl.log 2>&1 & S3=$!; sleep 0.7
python3 - <<'PY'
import socket, time
t0=time.time()
def ts(): return f"[{(time.time()-t0)*1000:8.1f} ms]"
s=socket.create_connection(("127.0.0.1",14222),timeout=5); f=s.makefile("rb")
print(ts(),"<< INFO (elided)"); f.readline()
s.sendall(b'CONNECT {"verbose":false}\r\n'); print(ts(),">> CONNECT")
s.sendall(b"SUB " + b"x"*2000 + b"\r\n"); print(ts(),">> SUB <2000 bytes>")
s.settimeout(2.0)
try: print(ts(),"<<",f.readline().decode().strip())
except Exception as e: print(ts(),"-- read:",e)
time.sleep(1.5)
try:
    s.sendall(b"PING\r\n"); print(ts(),">> PING")
except Exception as e: print(ts(),"-- send failed:",e.__class__.__name__)
try:
    r=f.readline()
    print(ts(),"<<", r.decode().strip() if r else "(EOF — socket closed)")
except Exception as e: print(ts(),"-- read:",e.__class__.__name__)
PY
curl -s "http://127.0.0.1:0/" >/dev/null 2>&1
kill $S3 2>/dev/null; wait $S3 2>/dev/null
echo "--- server log ---"; grep -iv "starting\|version\|git\|name:\|id:\|listening\|ready\|configuration" d-mcl.log | tail -5
