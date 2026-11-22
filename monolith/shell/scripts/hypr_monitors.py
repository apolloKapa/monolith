#!/usr/bin/env python3
"""Screens on Hyprland (Settings -> Displays): read them in niri's shape, and keep changes.

    hypr_monitors.py read                  JSON like `niri msg -j outputs` (name -> output)
    hypr_monitors.py set NAME KEY VALUE    KEY: mode ("WxH@R"), position ("X Y"), scale, off ("1"/"0"),
                                           mirror (another screen's name: show the same; "" its own),
                                           underscan (HDMI scaling: how much smaller, in %; 0 off)

HDMI scaling needs aquamarine (Hyprland's display library) with Monolith's underscan patch
(monolith/patches): the borders go to ~/.config/aquamarine/underscan, which it reads when a
screen's mode is set, so the screen is turned off and on again to apply a change.

Changes go to Monolith's folder, ~/.config/hypr/monolith/monitors.lua (or .conf), loaded by its
init after your own config, so they win; each screen keeps what it has for the rest (its
rotation too). The settings are kept as JSON on its first line. Hyprland reloads it by itself.
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_files as hf  # noqa: E402


UNDERSCAN_MAX = 128   # pixels of border per axis amdgpu takes at most


def underscan_file():
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "aquamarine", "underscan")


def us_driver(name):
    """the graphics driver of the card a connector is on (only amdgpu, radeon and nouveau have
    underscan)"""
    import glob
    for c in glob.glob("/sys/class/drm/card*-" + name):
        card = os.path.basename(c).split("-", 1)[0]
        d = os.path.realpath("/sys/class/drm/%s/device/driver" % card)
        if os.path.isdir(d):
            return os.path.basename(d)
    return ""


def underscan_running():
    """Does the Hyprland that's running use the patched aquamarine? Installed isn't enough: a
    running Hyprland keeps the library it started with until you log out and in (the slider moved
    and nothing happened). "yes", "restart" (patched on disk, not loaded yet) or "no"."""
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    pid = None
    try:
        # (the running Hyprland: the one whose lock names this instance)
        pid = int(open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid()), "hypr", sig, "hyprland.lock")).readline().strip())
    except (OSError, ValueError):
        pass
    loaded = None
    if pid:
        try:
            for line in open("/proc/%d/maps" % pid):
                if "libaquamarine" in line:
                    loaded = line.split(None, 5)[5].strip()
                    break
        except OSError:
            pass
    if loaded and not loaded.endswith("(deleted)"):
        try:
            return "yes" if b"aquamarine/underscan" in open(loaded, "rb").read() else ("restart" if underscan_patched() else "no")
        except OSError:
            pass
    return "restart" if underscan_patched() else "no"


def underscan_patched():
    """Is the aquamarine Hyprland uses one with the underscan patch? (its library names the file)"""
    import glob
    for lib in glob.glob("/usr/lib*/libaquamarine.so*") + glob.glob("/usr/local/lib*/libaquamarine.so*"):
        try:
            if os.path.isfile(lib) and not os.path.islink(lib) and b"aquamarine/underscan" in open(lib, "rb").read():
                return True
        except OSError:
            pass
    return False


def monitors():
    r = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True, timeout=5)
    return json.loads(r.stdout or "[]")


def niri_shape(m, saved_state=None, patched=False):
    modes = []
    for s in m.get("availableModes", []):
        g = re.match(r"(\d+)x(\d+)@([\d.]+)", s)
        if g:
            modes.append({"width": int(g.group(1)), "height": int(g.group(2)), "refresh_rate": int(round(float(g.group(3)) * 1000))})
    off = bool(m.get("disabled"))
    cur = None
    if not off and modes:
        w, h, r = m["width"], m["height"], m.get("refreshRate", 0) * 1000
        best = [i for i, x in enumerate(modes) if x["width"] == w and x["height"] == h]
        if best:
            cur = min(best, key=lambda i: abs(modes[i]["refresh_rate"] - r))
    sc = m.get("scale", 1) or 1
    rot = m.get("transform", 0) % 2 == 1
    lw, lh = round(m["width"] / sc), round(m["height"] / sc)
    if rot:
        lw, lh = lh, lw
    mirror = m.get("mirrorOf") or ""
    s = (saved_state or {}).get(m["name"], {})
    # (the most it can shrink: 128 px of border on the shorter way round)
    w, h = m.get("width") or 0, m.get("height") or 0
    umax = round(min(UNDERSCAN_MAX / w, UNDERSCAN_MAX / h) * 100, 1) if w and h else 0
    return {"name": m["name"], "make": m.get("make", ""), "model": m.get("model", ""), "modes": modes,
            "current_mode": cur, "mirror_of": "" if mirror in ("none", "") else mirror,
            "underscan": float(s.get("underscan", 0) or 0), "underscan_max": umax, "underscan_ok": patched,
            "underscan_driver": us_driver(m["name"]),
            "logical": None if off else {"x": m.get("x", 0), "y": m.get("y", 0), "width": lw, "height": lh, "scale": sc,
                                         "transform": m.get("transform", 0)}}


def saved():
    try:
        first = open(hf.path("monitors"), encoding="utf-8").readline()
        return json.loads(first.split(" monolith ", 1)[1])
    except (OSError, IndexError, ValueError):
        return {}


def fix(s):
    """A screen that has been off since login shows as 0x0 at -1,-1: it comes on at its best
    mode, beside the others, instead."""
    if not re.match(r"[1-9]\d*x[1-9]\d*@", s.get("mode", "")):
        s["mode"] = "preferred"
    if s.get("position") in (None, "", "-1 -1"):
        s["position"] = "auto"


def write(state):
    lua = hf.kind() == "lua"
    c = "--" if lua else "#"
    for s in state.values():
        if not s.get("off"):
            fix(s)
    out = [c + " monolith " + json.dumps(state, separators=(",", ":")),
           c + " Written by Monolith (Settings -> Displays). Changes here are replaced."]
    for name, s in sorted(state.items()):
        if s.get("off"):
            out.append('hl.monitor({ output = "%s", disabled = true })' % name if lua else "monitor = %s, disable" % name)
            continue
        pos = s["position"].replace(" ", "x")
        if s.get("mirror"):
            # (showing another screen: it has no place of its own)
            if lua:
                out.append('hl.monitor({ output = "%s", mode = "%s", position = "auto", scale = %s, mirror = "%s", disabled = false })'
                           % (name, s["mode"], s["scale"], s["mirror"]))
            else:
                out.append("monitor = %s, %s, auto, %s, mirror, %s" % (name, s["mode"], s["scale"], s["mirror"]))
            continue
        if lua:
            # (disabled = false said outright: hl.monitor merges the rules for a screen, so one
            # your config turns off would stay off)
            out.append('hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = %s, transform = %d, disabled = false })'
                       % (name, s["mode"], pos, s["scale"], s.get("transform", 0)))
        else:
            out.append("monitor = %s, %s, %s, %s, transform, %d" % (name, s["mode"], pos, s["scale"], s.get("transform", 0)))
    write_underscan(state)
    hf.migrate()
    new = not os.path.exists(hf.path("monitors"))
    hf.write("monitors", "\n".join(out) + "\n")
    if new:
        # (Hyprland watches the files it loaded: a new one is only read on a reload)
        subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=5)


def write_underscan(state):
    """The borders for aquamarine, in pixels for each screen's mode (worked out again when the
    mode changes). Only lines of "NAME H V": it reads nothing else."""
    live = None
    lines = []
    for name, s in sorted(state.items()):
        pct = float(s.get("underscan", 0) or 0)
        if pct <= 0 or s.get("off"):
            continue
        g = re.match(r"(\d+)x(\d+)@", s.get("mode", ""))
        if g:
            w, h = int(g.group(1)), int(g.group(2))
        else:
            live = live if live is not None else {m["name"]: m for m in monitors()}
            m = live.get(name) or {}
            w, h = m.get("width") or 0, m.get("height") or 0
        if not w or not h:
            continue
        hb = min(UNDERSCAN_MAX, round(w * pct / 100))
        vb = min(UNDERSCAN_MAX, round(h * pct / 100))
        lines.append("%s %d %d" % (name, hb, vb))
    path = underscan_file()
    if not lines and not os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w", encoding="utf-8") as f:
        f.write("".join(l + "\n" for l in lines))
    os.replace(path + ".tmp", path)


def reapply(name):
    """aquamarine reads the borders when a screen's mode is set: off and on again"""
    for action in ("disable", "enable"):
        subprocess.run(["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "%s", monitor = "%s" })' % (action, name)],
                       capture_output=True, timeout=5)
        if action == "disable":
            import time
            time.sleep(0.6)


def main():
    a = sys.argv[1:]
    if not a or a[0] == "read":
        st, run = saved(), underscan_running()
        ok = run == "yes"
        out = {m["name"]: niri_shape(m, st, ok) for m in monitors()}
        for o in out.values():
            o["underscan_restart"] = run == "restart"
        print(json.dumps(out))
        return
    if a[0] == "set" and len(a) >= 4:
        name, key, value = a[1], a[2], a[3]
        state = saved()
        live = {m["name"]: m for m in monitors()}
        m = live.get(name)
        s = state.get(name)
        if not s:
            if not m:
                print(json.dumps({"ok": False, "error": "No screen " + name}))
                return
            s = {"mode": "%dx%d@%.3f" % (m["width"], m["height"], m.get("refreshRate", 60)),
                 "position": "%d %d" % (m.get("x", 0), m.get("y", 0)), "scale": round(m.get("scale", 1), 2),
                 "transform": m.get("transform", 0), "off": bool(m.get("disabled"))}
            if m.get("disabled") and not m.get("width"):
                s["mode"], s["position"] = "preferred", "auto"
        if key == "off":
            s["off"] = value in ("1", "true")
        elif key == "mode":
            s["mode"] = value.strip('"').replace("@", "@")
        elif key == "position":
            g = re.findall(r"-?\d+", value)
            if len(g) >= 2:
                s["position"] = "%s %s" % (g[0], g[1])
        elif key == "scale":
            s["scale"] = round(float(value), 2)
        elif key == "mirror":
            if value and value != name and value in live:
                s["mirror"] = value
                s["off"] = False
                # (a screen can't show one that is itself showing another)
                for other, o in state.items():
                    if other == value and o.get("mirror"):
                        o.pop("mirror", None)
            else:
                s.pop("mirror", None)
        elif key == "underscan":
            try:
                pct = max(0.0, min(15.0, round(float(value), 1)))
            except ValueError:
                pct = 0.0
            if pct > 0:
                s["underscan"] = pct
            else:
                s.pop("underscan", None)
        state[name] = s
        write(state)
        if key == "underscan" and not s.get("off"):
            reapply(name)
        print(json.dumps({"ok": True}))


if __name__ == "__main__":
    main()
