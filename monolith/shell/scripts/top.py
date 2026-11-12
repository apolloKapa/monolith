#!/usr/bin/env python3
"""The system monitor's process list: the busiest processes right now. CPU is measured over
half a second (ps's %CPU is a lifetime average), memory is resident size, and video memory
comes from the GPU driver's fdinfo (drm-memory-vram, per DRM client, so a client open on
several fds counts once). Prints JSON: [{pid, name, cpu (% of one core), mem (bytes),
vram (bytes), mine}], the top N by the chosen key.

usage: top.py [cpu|mem|vram] [N]"""
import json, os, sys, time

key = sys.argv[1] if len(sys.argv) > 1 else "cpu"
count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
hz = os.sysconf("SC_CLK_TCK")
page = os.sysconf("SC_PAGE_SIZE")
me = os.getuid()

def times():
    out = {}
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            with open(f"/proc/{p}/stat") as f:
                s = f.read()
            rest = s[s.rindex(")") + 2:].split()
            out[int(p)] = int(rest[11]) + int(rest[12])
        except (OSError, ValueError, IndexError):
            pass
    return out

def vram(pid):
    seen, total = set(), 0
    d = f"/proc/{pid}/fdinfo"
    try:
        fds = os.listdir(d)
    except OSError:
        return 0
    for fd in fds:
        try:
            with open(f"{d}/{fd}") as f:
                txt = f.read()
        except OSError:
            continue
        if "drm-memory-vram" not in txt and "drm-resident-vram" not in txt:
            continue
        client, amount = None, 0
        for line in txt.splitlines():
            if line.startswith("drm-client-id:"):
                client = line.split()[1]
            elif line.startswith(("drm-memory-vram:", "drm-resident-vram:")):
                parts = line.split()
                n = int(parts[1])
                unit = parts[2] if len(parts) > 2 else ""
                amount = max(amount, n * {"KiB": 1024, "MiB": 1 << 20, "GiB": 1 << 30}.get(unit, 1))
        if client is None or client not in seen:
            seen.add(client)
            total += amount
    return total

a = times()
t0 = time.monotonic()
time.sleep(0.5)
b = times()
dt = time.monotonic() - t0

rows = []
self_pid = os.getpid()
for pid, t in b.items():
    if pid == self_pid:
        continue
    try:
        with open(f"/proc/{pid}/comm") as f:
            name = f.read().strip()
        with open(f"/proc/{pid}/statm") as f:
            rss = int(f.read().split()[1]) * page
        uid = os.stat(f"/proc/{pid}").st_uid
    except (OSError, ValueError, IndexError):
        continue
    if rss == 0:
        continue      # kernel threads
    cpu = (t - a.get(pid, t)) / hz / dt * 100
    rows.append({"pid": pid, "name": name, "cpu": round(cpu, 1), "mem": rss, "vram": 0, "mine": uid == me})

if key == "vram":
    for r in rows:
        r["vram"] = vram(r["pid"]) if r["mine"] else 0
    rows.sort(key=lambda r: -r["vram"])
    rows = [r for r in rows if r["vram"] > 0] or rows
else:
    rows.sort(key=lambda r: -(r["mem"] if key == "mem" else r["cpu"]))
    top = rows[:count]
    for r in top:
        r["vram"] = vram(r["pid"]) if r["mine"] else 0
    rows = top
print(json.dumps(rows[:count]))
