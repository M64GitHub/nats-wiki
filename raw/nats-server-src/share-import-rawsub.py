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
