#!/usr/bin/env python3
"""HDMI scaling on niri (Settings -> Displays): the borders niri with Monolith's underscan patch
(monolith/patches/niri-underscan.patch) gives a screen, kept in ~/.config/aquamarine/underscan
(lines of "NAME H V" in pixels; the same file the aquamarine patch reads on Hyprland).

    underscan.py read              JSON: {"patched", "restart", "outputs": {name: {"pct", "max", "driver"}}}
    underscan.py set NAME PERCENT  the borders for that much smaller, then the screen off and on
                                   (niri reads them as it turns a screen on)
    underscan.py status            what HDMI scaling needs and has on this PC, in words (Hyprland
                                   or niri), to see why it doesn't work

Only some graphics drivers can draw the picture smaller: amdgpu and radeon (AMD) and nouveau
(NVIDIA's open driver). Intel's and NVIDIA's own don't have it, whatever the compositor does.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

MAX = 128   # pixels of border per axis amdgpu takes at most
DRIVERS = ("amdgpu", "radeon", "nouveau")   # the ones with "underscan"


def driver(name):
    """the graphics driver of the card a connector is on ("" when it's not found)"""
    for c in glob.glob("/sys/class/drm/card*-" + name):
        card = os.path.basename(c).split("-", 1)[0]
        d = os.path.realpath("/sys/class/drm/%s/device/driver" % card)
        if os.path.isdir(d):
            return os.path.basename(d)
    return ""


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
    """niri with the patch names the file it reads. "yes" when the niri that's running has it,
    "restart" when only the installed one does (a running niri keeps the program it started with
    until you log out and in), else no"""
    def has(path):
        try:
            return b"aquamarine/underscan" in open(path, "rb").read()
        except OSError:
            return False
    exe = shutil.which("niri")
    on_disk = bool(exe) and has(exe)
    try:
        pid = int(subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "niri"], capture_output=True, text=True).stdout.split()[0])
        running = os.readlink("/proc/%d/exe" % pid)
    except (IndexError, ValueError, OSError):
        return "yes" if on_disk else "no"
    if not running.endswith("(deleted)") and has("/proc/%d/exe" % pid):
        return "yes"
    return "restart" if on_disk else "no"


def main():
    a = sys.argv[1:]
    if not a or a[0] == "read":
        have = lines()
        res = {}
        for name, o in outputs().items():
            w, h = size(o)
            hb, vb = have.get(name, (0, 0))
            res[name] = {"pct": round(hb * 100 / w, 1) if w and hb else 0,
                         "max": round(min(MAX / w, MAX / h) * 100, 1) if w and h else 0,
                         "driver": driver(name)}
        state = patched()
        print(json.dumps({"patched": state == "yes", "restart": state == "restart", "outputs": res}))
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


def status():
    hypr = bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))
    print("Compositor:", "Hyprland" if hypr else ("niri" if shutil.which("niri") else "unknown"))
    hdmi = sorted(os.path.basename(c).split("-", 1)[1] for c in glob.glob("/sys/class/drm/card*-HDMI-*"))
    for n in hdmi:
        try:
            st = open(glob.glob("/sys/class/drm/card*-" + n)[0] + "/status").read().strip()
        except (OSError, IndexError):
            st = "?"
        d = driver(n)
        print("  %s: %s, driver %s: %s" % (n, st, d or "?", "can do HDMI scaling" if d in DRIVERS else "has no HDMI scaling (only amdgpu, radeon and nouveau do)"))
    if not hdmi:
        print("  no HDMI ports found (a TV on a DisplayPort adapter shows as DP: not supported here)")
    if hypr:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import hypr_monitors as hm
        state = hm.underscan_running()
        what = "aquamarine (Hyprland's display library)"
    else:
        state = patched()
        what = "niri"
    print("Patch:", {"yes": what + " with Monolith's patch is running",
                     "restart": what + " is patched but the running one started before: log out and in",
                     "no": what + " isn't patched: run `monolith installer`, turn on \"HDMI scaling for TVs\" in its menu, then log out and in"}[state])
    have = lines()
    print("Borders (%s):" % path(), ", ".join("%s %dx%d px" % (n, h, v) for n, (h, v) in sorted(have.items())) or "none set")
    try:
        print("Chosen in the installer:", open(os.path.expanduser("~/.local/state/monolith/hdmi-scaling")).read().strip() or "no")
    except OSError:
        print("Chosen in the installer: no")


if __name__ == "__main__":
    if sys.argv[1:2] == ["status"]:
        status()
    else:
        main()
