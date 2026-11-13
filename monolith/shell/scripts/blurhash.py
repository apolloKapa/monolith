#!/usr/bin/env python3
"""BlurHash placeholders for pictures (and videos: their first frame).

    blurhash.py PATH...

For each path, prints "PATH<TAB>HASH" (a BlurHash with 4x3 components, see blurha.sh), working
out the ones it doesn't already have in ~/.cache/monolith/blurhash.json (kept there by path,
size and modification time, so a changed file gets a new one). ffmpeg does the decoding and
shrinks each picture to 32x32 pixels; the hash is computed from those, in plain Python.
A path that can't be read prints nothing."""

import json
import math
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "monolith", "blurhash.json")
NX, NY = 4, 3
SIDE = 32
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"


def b83(value, length):
    return "".join(CHARS[(value // 83 ** (length - 1 - i)) % 83] for i in range(length))


def to_linear(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def to_srgb(v):
    v = max(0.0, min(1.0, v))
    return int(round((v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055) * 255))


def sign_pow(v, e):
    return math.copysign(abs(v) ** e, v)


def encode(rgb):
    lin = [to_linear(b) for b in rgb]
    comps = []
    for j in range(NY):
        for i in range(NX):
            norm = 1 if i == 0 and j == 0 else 2
            r = g = b = 0.0
            for y in range(SIDE):
                cy = math.cos(math.pi * j * y / SIDE)
                for x in range(SIDE):
                    basis = norm * math.cos(math.pi * i * x / SIDE) * cy
                    k = (y * SIDE + x) * 3
                    r += basis * lin[k]; g += basis * lin[k + 1]; b += basis * lin[k + 2]
            s = 1.0 / (SIDE * SIDE)
            comps.append((r * s, g * s, b * s))
    dc, ac = comps[0], comps[1:]
    out = b83((NX - 1) + (NY - 1) * 9, 1)
    max_ac = max((abs(c) for t in ac for c in t), default=0.0)
    qmax = int(max(0, min(82, math.floor(max_ac * 166 - 0.5)))) if ac else 0
    maxv = (qmax + 1) / 166
    out += b83(qmax, 1)
    out += b83((to_srgb(dc[0]) << 16) + (to_srgb(dc[1]) << 8) + to_srgb(dc[2]), 4)
    for t in ac:
        q = [int(max(0, min(18, math.floor(sign_pow(c / maxv, 0.5) * 9 + 9.5)))) for c in t]
        out += b83(q[0] * 19 * 19 + q[1] * 19 + q[2], 2)
    return out


def pixels(path):
    try:
        raw = subprocess.run(
            ["ffmpeg", "-v", "quiet", "-nostdin", "-i", path, "-frames:v", "1",
             "-vf", f"scale={SIDE}:{SIDE}:flags=area,format=rgb24", "-f", "rawvideo", "-"],
            capture_output=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return raw if len(raw) == SIDE * SIDE * 3 else None


def stamp(path):
    try:
        st = os.stat(path)
    except OSError:
        return None
    return f"{st.st_size}:{int(st.st_mtime)}"


def main():
    paths = [p[7:] if p.startswith("file://") else p for p in sys.argv[1:]]
    try:
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}
    todo = []
    for p in dict.fromkeys(paths):
        st = stamp(p)
        if st is None:
            continue
        hit = cache.get(p)
        if hit and hit.get("s") == st:
            print(f"{p}\t{hit['h']}", flush=True)
        else:
            todo.append((p, st))

    def work(item):
        p, st = item
        px = pixels(p)
        return (p, st, encode(px) if px else None)

    changed = False
    with ThreadPoolExecutor(max_workers=4) as pool:
        for p, st, h in pool.map(work, todo):
            if h:
                cache[p] = {"s": st, "h": h}
                changed = True
                print(f"{p}\t{h}", flush=True)
    if changed:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE), prefix=".blurhash.")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(cache, f)
        os.replace(tmp, CACHE)


if __name__ == "__main__":
    main()
