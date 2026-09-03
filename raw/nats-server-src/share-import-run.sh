#!/bin/bash
# share-import-run.sh — nats-server v2.14.6, nats CLI 0.4.0, macOS, 2026-09-03.
# What the Nats-Request-Info header carries across a service import: without and with `share: true`
# (scene A), on a two-hop chain of imports (scene B), and against max_payload (scene C); plus whether
# config mode accepts `share` on a stream import (scene D). Port 14222; every scene starts its own server.
set -u
cd "$(dirname "$0")"
PORT=14222
SVC="nats://svc:svc@127.0.0.1:$PORT"; APP="nats://app:app@127.0.0.1:$PORT"
start() { nats-server -c "$1" -P server.pid > "$2" 2>&1 & sleep 0.7; }
stop()  { kill "$(cat server.pid)" 2>/dev/null; sleep 0.3; }
ask()   { # $1 = log for the responder side, $2.. = nats request args
  local log=$1; shift
  nats sub svc.remote --server $SVC > "$log" 2>&1 & local sp=$!; sleep 0.5
  nats request "$@" --server $APP --timeout=500ms --connection-name=tenant-agent-1 > /dev/null 2>&1
  sleep 0.3; kill $sp 2>/dev/null; sleep 0.2
  grep -E 'Nats-Request-Info|Received' "$log"
}
echo "### versions"; nats-server --version; nats --version

echo; echo "### scene A — two accounts, the import without share, then share: true by reload"
cat > a.conf <<'CONF'
port: 14222
server_name: sharelab
accounts {
  SVC: {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.remote", accounts: [APP] } ]
  }
  APP: {
    users: [ { user: app, password: app } ]
    imports: [ { service: { account: SVC, subject: "svc.remote" }, to: "svc.local" } ]
  }
}
CONF
start a.conf a.log
echo "--- A1: no share key"; ask a1-sub.log svc.local hello
sed -i '' 's/to: "svc.local" }/to: "svc.local", share: true }/' a.conf
nats-server --signal reload=$(cat server.pid); sleep 0.5; grep -c 'Reloaded server configuration' a.log
echo "--- A2: share: true"; ask a2-sub.log svc.local hello
stop

echo; echo "### scene B — a chain APP -> MID -> SVC: which hop's share decides"
chain() { # $1 = APP import share, $2 = MID import share
cat > b.conf <<CONF
port: 14222
server_name: sharelab
accounts {
  SVC: {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.remote", accounts: [MID] } ]
  }
  MID: {
    users: [ { user: mid, password: mid } ]
    imports: [ { service: { account: SVC, subject: "svc.remote" }, to: "svc.mid", share: $2 } ]
    exports: [ { service: "svc.mid", accounts: [APP] } ]
  }
  APP: {
    users: [ { user: app, password: app } ]
    imports: [ { service: { account: MID, subject: "svc.mid" }, to: "svc.local", share: $1 } ]
  }
}
CONF
}
chain false true; start b.conf b1.log
echo "--- B1: APP import share: false, MID import share: true"; ask b1-sub.log svc.local hello
stop
chain true false; start b.conf b2.log
echo "--- B2: APP import share: true, MID import share: false"; ask b2-sub.log svc.local hello
stop

echo; echo "### scene C — max_payload: 256 and a shared import; a raw subscriber prints the HMSG line"
cat > c.conf <<'CONF'
port: 14222
server_name: sharelab
max_payload: 256
accounts {
  SVC: {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.remote", accounts: [APP] } ]
  }
  APP: {
    users: [ { user: app, password: app } ]
    imports: [ { service: { account: SVC, subject: "svc.remote" }, to: "svc.local", share: true } ]
  }
}
CONF
cat > rawsub.py <<'PY'
import socket, json, sys
user, pw, subj = sys.argv[1], sys.argv[2], sys.argv[3]
s = socket.create_connection(("127.0.0.1", 14222), timeout=10); f = s.makefile("rb")
f.readline()  # INFO
s.sendall(("CONNECT " + json.dumps({"user": user, "pass": pw, "name": "rawsub", "lang": "python", "version": "0",
           "protocol": 1, "headers": True, "verbose": False}) + "\r\nSUB " + subj + " 1\r\nPING\r\n").encode())
while True:
    line = f.readline()
    if not line: break
    t = line.decode().strip()
    if t == "PING": s.sendall(b"PONG\r\n"); continue
    if t.startswith("HMSG"):
        p = t.split(); hdr_len, total = int(p[-2]), int(p[-1]); body = f.read(total + 2)
        print(t); print("header bytes:", hdr_len, "total bytes:", total, "body bytes:", total - hdr_len)
        print(body[:hdr_len].decode(errors="replace").replace("\r\n", "\\r\\n")); break
    if t.startswith("MSG"):
        p = t.split(); total = int(p[-1]); f.read(total + 2); print(t); print("total bytes:", total); break
    if t.startswith("-ERR"): print(t); break
s.close()
PY
start c.conf c.log
python3 rawsub.py svc svc svc.remote > c-rawsub.log 2>&1 & RS=$!; sleep 0.5
echo "--- C1: a 250-byte request (under max_payload 256) from APP"
nats request svc.local "$(python3 -c "print('A'*250, end='')")" --server $APP --timeout=500ms 2>&1 | tail -1
sleep 0.5; kill $RS 2>/dev/null; cat c-rawsub.log
echo "--- C2: a 260-byte request (over max_payload) from APP — the control"
nats request svc.local "$(python3 -c "print('A'*260, end='')")" --server $APP --timeout=500ms 2>&1 | tail -1
grep -i 'maximum payload\|max_payload' c.log | tail -2
stop

echo; echo "### scene D — share: true on a stream import, config mode: does the config load?"
cat > d.conf <<'CONF'
port: 14222
accounts {
  SVC: { exports: [ { stream: "ev.>" } ] }
  APP: { imports: [ { stream: { account: SVC, subject: "ev.>" }, share: true } ] }
}
CONF
nats-server -t -c d.conf 2>&1; echo "exit: $?"
rm -f server.pid
