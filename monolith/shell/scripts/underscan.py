#!/usr/bin/env python3
"""HDMI scaling on niri (Settings -> Displays): the borders niri with Monolith's underscan patch
(monolith/patches/niri-underscan.patch) gives a screen, kept in ~/.config/aquamarine/underscan
(lines of "NAME H V" in pixels; the same file the aquamarine patch reads on Hyprland).

    underscan.py read              JSON: {"patched": bool, "outputs": {name: {"pct", "max"}}}
    underscan.py set NAME PERCENT  the borders for that much smaller, then the screen off and on
                                   (niri reads them as it turns a screen on)
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

MAX = 128   # pixels of border per axis amdgpu takes at most


def path():
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "aquamarine", "underscan")


def lines():
    out = {}
    try:
        for l in open(path(), encoding="utf-8"):
            p = l.split()
            if len(p) >= 3 and p[1].isdigit() and p[2].isdigit():
                out[p[0]] = (int(p[1]), int(p[2]))
    except OSError:
        pass
    return out


def outputs():
    r = subprocess.run(["niri", "msg", "-j", "outputs"], capture_output=True, text=True, timeout=5)
    try:
        return json.loads(r.stdout or "{}")
    except ValueError:
        return {}


def size(o):
    """the screen's current mode (else its first): width, height in pixels"""
    modes = o.get("modes") or []
    i = o.get("current_mode")
    m = modes[i] if i is not None and i < len(modes) else (modes[0] if modes else None)
    return (m["width"], m["height"]) if m else (0, 0)


def patched():
    """niri with the patch names the file it reads"""
    exe = shutil.which("niri")
    try:
        return bool(exe) and b"aquamarine/underscan" in open(exe, "rb").read()
    except OSError:
        return False


def main():
    a = sys.argv[1:]
    if not a or a[0] == "read":
        have = lines()
        res = {}
        for name, o in outputs().items():
            w, h = size(o)
            hb, vb = have.get(name, (0, 0))
            res[name] = {"pct": round(hb * 100 / w, 1) if w and hb else 0,
                         "max": round(min(MAX / w, MAX / h) * 100, 1) if w and h else 0}
        print(json.dumps({"patched": patched(), "outputs": res}))
        return
    if a[0] == "set" and len(a) >= 3:
        name = a[1]
        if not re.match(r"^[A-Za-z0-9._-]+$", name):
            sys.exit(1)
        try:
            pct = max(0.0, min(15.0, float(a[2])))
        except ValueError:
            pct = 0.0
        o = outputs().get(name)
        if not o:
            print(json.dumps({"ok": False, "error": "No screen " + name}))
            return
        w, h = size(o)
        have = lines()
        if pct > 0 and w and h:
            have[name] = (min(MAX, round(w * pct / 100)), min(MAX, round(h * pct / 100)))
        else:
            have.pop(name, None)
        p = path()
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p + ".tmp", "w", encoding="utf-8") as f:
            f.write("".join("%s %d %d\n" % (n, hb, vb) for n, (hb, vb) in sorted(have.items())))
        os.replace(p + ".tmp", p)
        # (niri sets them as a screen comes on: off and on again, if it's on)
        if o.get("current_mode") is not None:
            subprocess.run(["niri", "msg", "output", name, "off"], capture_output=True, timeout=5)
            time.sleep(0.8)
            subprocess.run(["niri", "msg", "output", name, "on"], capture_output=True, timeout=5)
        print(json.dumps({"ok": True}))


if __name__ == "__main__":
    main()
