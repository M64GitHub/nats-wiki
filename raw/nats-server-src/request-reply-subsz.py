#!/usr/bin/env python3
# subsz.py — print the non-$SYS entries of /subsz?subs=1&acc=$G on one monitoring port (request-reply-run2.sh).
import json, sys, urllib.request
port = sys.argv[1] if len(sys.argv) > 1 else "18222"
d = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/subsz?subs=1&acc=$G"))
subs = [s for s in d.get("subscriptions_list", []) if not s["subject"].startswith("$SYS")]
print(f"  num_subscriptions {d['num_subscriptions']}; non-$SYS entries {len(subs)}:")
for s in sorted(subs, key=lambda s: (s["cid"], int(s["sid"]))):
    print(f"  cid {s['cid']:>3}  sid {s['sid']:>3}  msgs {s['msgs']:>4}  qgroup {s.get('qgroup','-'):<14} {s['subject']}")
