#!/usr/bin/env python3
"""Window borders on Hyprland (Settings -> Windows): colours (one, or a fade between two at an
angle) for the focused window and the others, and the border's width.

    hypr_borders.py read             prints the saved settings as JSON (or {})
    hypr_borders.py apply '<json>'   {"width": 2, "active": {"a": "#rrggbb[aa]", "b": "" | "#..", "angle": 45},
                                      "inactive": {...}}

Written to Monolith's own ~/.config/hypr/monolith-borders.lua (for hyprland.lua) or .conf,
included once at the end of the main config; Hyprland reloads it by itself. The settings are
kept as JSON in a comment on its first line, so they read back exactly.
"""

import json
import os
import re
import sys

CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
HYPR = os.path.join(CONF, "hypr")
LUA = os.path.exists(os.path.join(HYPR, "hyprland.lua"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_files as hf  # noqa: E402
# (in Monolith's folder, ~/.config/hypr/monolith/, loaded by its init; an older setup had it beside the config)
FILE = hf.path("borders")
OLD_FILE = os.path.join(HYPR, "monolith-borders." + ("lua" if LUA else "conf"))
HEX = re.compile(r"^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$")


def rgba(c):
    m = HEX.match(str(c or "").strip())
    if not m:
        return None
    return "rgba(" + m.group(1).lower() + (m.group(2) or "ff").lower() + ")"


def angle(v):
    try:
        return int(round(float(v))) % 360
    except (TypeError, ValueError):
        return 45


def lua_value(side):
    a, b = rgba(side.get("a")), rgba(side.get("b"))
    if not a:
        return None
    if b:
        return '{ colors = { "%s", "%s" }, angle = %d }' % (a, b, angle(side.get("angle")))
    return '"%s"' % a


def conf_value(side):
    a, b = rgba(side.get("a")), rgba(side.get("b"))
    if not a:
        return None
    return a + (" " + b + " " + str(angle(side.get("angle"))) + "deg" if b else "")


def apply(s):
    width = max(0, min(20, int(s.get("width", 2))))
    act, ina = s.get("active", {}), s.get("inactive", {})
    c = "--" if LUA else "#"
    out = [c + " monolith " + json.dumps(s, separators=(",", ":")),
           c + " Written by Monolith (Settings -> Windows): window borders. Changes here are replaced."]
    if LUA:
        col = []
        for key, side in (("active_border", act), ("inactive_border", ina)):
            v = lua_value(side)
            if v:
                col.append("      %s = %s," % (key, v))
        out += ["hl.config({", "  general = {", "    border_size = %d," % width, "    col = {"] + col + ["    },", "  },", "})"]
    else:
        out += ["general {", "    border_size = %d" % width]
        for key, side in (("col.active_border", act), ("col.inactive_border", ina)):
            v = conf_value(side)
            if v:
                out.append("    %s = %s" % (key, v))
        out.append("}")
    hf.migrate()
    hf.write("borders", "\n".join(out) + "\n")


def read():
    try:
        first = open(FILE if os.path.exists(FILE) else OLD_FILE, encoding="utf-8").readline()
        return json.loads(first.split(" monolith ", 1)[1])
    except (OSError, IndexError, ValueError):
        return {}


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "apply":
        apply(json.loads(sys.argv[2]))
        print("ok")
    else:
        print(json.dumps(read()))
