#!/usr/bin/env python3
"""Screens on Hyprland (Settings -> Displays): read them in niri's shape, and keep changes.

    hypr_monitors.py read                  JSON like `niri msg -j outputs` (name -> output)
    hypr_monitors.py set NAME KEY VALUE    KEY: mode ("WxH@R"), position ("X Y"), scale, off ("1"/"0")

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


def monitors():
    r = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True, timeout=5)
    return json.loads(r.stdout or "[]")


def niri_shape(m):
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
    return {"name": m["name"], "make": m.get("make", ""), "model": m.get("model", ""), "modes": modes,
            "current_mode": cur,
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
        if lua:
            # (disabled = false said outright: hl.monitor merges the rules for a screen, so one
            # your config turns off would stay off)
            out.append('hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = %s, transform = %d, disabled = false })'
                       % (name, s["mode"], pos, s["scale"], s.get("transform", 0)))
        else:
            out.append("monitor = %s, %s, %s, %s, transform, %d" % (name, s["mode"], pos, s["scale"], s.get("transform", 0)))
    hf.migrate()
    new = not os.path.exists(hf.path("monitors"))
    hf.write("monitors", "\n".join(out) + "\n")
    if new:
        # (Hyprland watches the files it loaded: a new one is only read on a reload)
        subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=5)


def main():
    a = sys.argv[1:]
    if not a or a[0] == "read":
        print(json.dumps({m["name"]: niri_shape(m) for m in monitors()}))
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
        state[name] = s
        write(state)
        print(json.dumps({"ok": True}))


if __name__ == "__main__":
    main()
