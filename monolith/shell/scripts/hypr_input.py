#!/usr/bin/env python3
"""Mouse and touchpad on Hyprland (Settings -> Devices -> Keyboard & mouse).

    hypr_input.py read              JSON: {"scroll_factor": N} (what Hyprland uses now)
    hypr_input.py set KEY VALUE     KEY: scroll_factor (the mouse's scroll speed, 1 = normal)

Kept in Monolith's folder, ~/.config/hypr/monolith/input.lua (or .conf), loaded after your own
config, so it wins. The settings are kept as JSON on its first line. Hyprland reloads it by itself
(a new file once by `hyprctl reload`: it only watches files it has read).
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_files as hf  # noqa: E402

KEYS = {"scroll_factor": (0.1, 5.0)}


def saved():
    try:
        first = open(hf.path("input"), encoding="utf-8").readline()
        return json.loads(first.split(" monolith ", 1)[1])
    except (OSError, IndexError, ValueError):
        return {}


def live(key):
    try:
        r = subprocess.run(["hyprctl", "getoption", "input:" + key, "-j"], capture_output=True, text=True, timeout=5)
        return float(json.loads(r.stdout).get("float"))
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return None


def write(state):
    lua = hf.kind() == "lua"
    c = "--" if lua else "#"
    out = [c + " monolith " + json.dumps(state, separators=(",", ":")),
           c + " Written by Monolith (Settings -> Devices). Changes here are replaced."]
    if lua:
        out += ["hl.config({ input = {"] + ["  %s = %s," % (k, v) for k, v in sorted(state.items())] + ["} })"]
    else:
        out += ["input {"] + ["    %s = %s" % (k, v) for k, v in sorted(state.items())] + ["}"]
    hf.migrate()
    new = not os.path.exists(hf.path("input"))
    hf.write("input", "\n".join(out) + "\n")
    if new:
        subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=5)


def main():
    a = sys.argv[1:]
    if not a or a[0] == "read":
        out = {}
        for k in KEYS:
            v = saved().get(k)
            out[k] = v if v is not None else live(k)
        print(json.dumps(out))
        return
    if a[0] == "set" and len(a) >= 3 and a[1] in KEYS:
        lo, hi = KEYS[a[1]]
        try:
            v = round(min(hi, max(lo, float(a[2]))), 2)
        except ValueError:
            print(json.dumps({"ok": False, "error": "Not a number: " + a[2]}))
            return
        state = saved()
        state[a[1]] = v
        write(state)
        print(json.dumps({"ok": True}))
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
