#!/usr/bin/env python3
"""Switching workspaces on Hyprland (Settings -> Animations -> Workspace switching): how the
workspaces move, how it feels and how fast.

    hypr_anims.py read             prints the saved settings as JSON (or {})
    hypr_anims.py apply '<json>'   {"style": "slidevert" | "slide" | "slidefadevert" | "slidefade" | "fade" | "off",
                                    "feel": "smooth" | "bouncy", "speed": "relaxed" | "normal" | "fast" | "fastest"}

Written to Monolith's folder, ~/.config/hypr/monolith/animations.lua (or .conf), loaded by its
init after your own config, so it wins over a workspaces animation set there. Hyprland reloads
it by itself. The settings are kept as JSON on its first line, so they read back exactly.

A spring that starts from rest, like niri's: a curve that starts fast jumped most of the way in
the first frame on a fast screen, which looked like the screen shaking.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_files as hf  # noqa: E402

STYLES = {"slidevert": "slidevert", "slide": "slide", "slidefadevert": "slidefadevert 20%",
          "slidefade": "slidefade 20%", "fade": "fade"}
# how stiff the spring is (higher: faster); the same numbers as niri's stiffness
SPEEDS = {"relaxed": 450, "normal": 900, "fast": 1500, "fastest": 2500}
# damping ratio: 1 settles without going past, lower overshoots and comes back
FEELS = {"smooth": 1.0, "bouncy": 0.6}
DEFAULT = {"style": "slidevert", "feel": "smooth", "speed": "normal"}


def clean(s):
    s = dict(DEFAULT, **(s or {}))
    if s["style"] not in STYLES and s["style"] != "off":
        s["style"] = DEFAULT["style"]
    if s["feel"] not in FEELS:
        s["feel"] = DEFAULT["feel"]
    if s["speed"] not in SPEEDS:
        s["speed"] = DEFAULT["speed"]
    return s


def lines(s, lua):
    c = "--" if lua else "#"
    out = [c + " monolith " + json.dumps(s, separators=(",", ":")),
           c + " Written by Monolith (Settings -> Animations -> Workspace switching). Changes here are replaced."]
    if s["style"] == "off":
        if lua:
            out.append('hl.animation({ leaf = "workspaces", enabled = false })')
        else:
            out.append("animation = workspaces, 0")
        return out
    k = SPEEDS[s["speed"]]
    d = FEELS[s["feel"]] * 2 * math.sqrt(k)
    style = STYLES[s["style"]]
    if lua:
        out += ['hl.curve("monolith_workspaces", { type = "spring", mass = 1, stiffness = %d, damping = %.2f })' % (k, d),
                'hl.animation({ leaf = "workspaces", enabled = true, speed = 1, spring = "monolith_workspaces", style = "%s" })' % style]
    else:
        # (a classic hyprland.conf: a curve that eases in and out, as long as the spring takes)
        secs = 5.0 / math.sqrt(k)
        out += ["bezier = monolith_workspaces, 0.4, 0, 0.2, 1",
                "animation = workspaces, 1, %.1f, monolith_workspaces, %s" % (max(0.5, secs * 10), style)]
    return out


def apply(s):
    s = clean(s)
    hf.migrate()
    hf.write("animations", "\n".join(lines(s, hf.kind() == "lua")) + "\n")
    return s


def read():
    try:
        first = open(hf.path("animations"), encoding="utf-8").readline()
        return clean(json.loads(first.split(" monolith ", 1)[1]))
    except (OSError, IndexError, ValueError):
        return {}


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "apply":
        apply(json.loads(sys.argv[2]))
        print("ok")
    else:
        print(json.dumps(read()))
