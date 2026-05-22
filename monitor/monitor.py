#!/usr/bin/env python3
# monitor.py — Human-readable VLESS connection monitor

import re, time
from datetime import datetime

LOG = "/var/log/xray-access.log"
IDLE_TIMEOUT = 15

state = {}

def label_dest(ip, port):
    labels = {
        "17.": "Apple",
        "31.13.": "Facebook",
        "157.240.": "Facebook",
        "179.60.": "Facebook",
        "140.82.": "GitHub",
        "185.199.": "GitHub",
        "151.101.": "Fastly CDN",
        "34.160.": "Google",
        "172.217.": "Google",
        "142.250.": "Google",
        "1.1.1.": "Cloudflare DNS",
        "8.8.8.": "Google DNS",
    }
    for prefix, name in labels.items():
        if ip.startswith(prefix):
            return f"{name} ({ip}:{port})"
    return f"{ip}:{port}"

def now():
    return datetime.utcnow().strftime("%H:%M:%S")

def check_idle():
    t = time.time()
    for email, s in state.items():
        if s["connected"] and (t - s["last_seen"]) > IDLE_TIMEOUT:
            s["connected"] = False
            dur = int(t - s["connected_at"])
            print(f"  {now()}  ✗ DISCONNECTED   [{email}]  duration: {dur}s", flush=True)
            print(f"  {'─'*8}  {'─'*50}", flush=True)

print(f"  {'TIME':8}  {'EVENT'}", flush=True)
print(f"  {'─'*8}  {'─'*50}", flush=True)

with open(LOG) as f:
    f.seek(0, 2)
    while True:
        line = f.readline()
        if not line:
            check_idle()
            time.sleep(1)
            continue

        if "api -> api" in line:
            continue

        # handles both "from IP:PORT" and "from tcp:IP:PORT" / "from udp:IP:PORT"
        m = re.search(r'from (?:tcp:|udp:)?([\d\.]+):(\d+) accepted \w+:([\d\.]+):(\d+) \[([^\]]+)\](?:\s+email:\s+(\S+))?', line)
        if not m:
            continue

        src_ip, src_port, dst_ip, dst_port, tag, email = m.groups()
        email = email or "unknown"
        t = time.time()

        s = state.get(email)
        if s is None:
            state[email] = {"ip": src_ip, "last_seen": t, "connected": True, "connected_at": t}
            print(f"  {now()}  ✓ CONNECTED      [{email}]  from {src_ip}", flush=True)
            print(f"  {now()}    → {label_dest(dst_ip, dst_port)}", flush=True)
        else:
            if not s["connected"]:
                s.update({"ip": src_ip, "last_seen": t, "connected": True, "connected_at": t})
                print(f"  {now()}  ↻ RECONNECTED    [{email}]  from {src_ip}", flush=True)
                print(f"  {now()}    → {label_dest(dst_ip, dst_port)}", flush=True)
            else:
                s["last_seen"] = t
                print(f"  {now()}    → {label_dest(dst_ip, dst_port)}", flush=True)
