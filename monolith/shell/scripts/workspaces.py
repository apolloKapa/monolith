#!/usr/bin/env python3
"""How many workspaces each screen has (Settings -> Windows -> Workspaces).

    workspaces.py apply '<json>'     json: {"screens": [["DP-1", 5], ["HDMI-A-1", 3], ...]}
    workspaces.py read               prints {"DP-1": 5, ...} from the current config

The screens come in order: the first is the main one. A count of 0 leaves that screen's
workspaces to the compositor (they come and go as you use them).

niri: ~/.config/niri/config/workspaces.kdl gets named workspaces pinned to their screen with
open-on-output, so they always exist and move back when a screen is turned off and on: the
main screen's are "1".."N", the others' "d2-1".., "d3-1".. (the installer's names). niri reloads
it by itself. The file is backed up once, to workspaces.kdl.before-monolith.

Hyprland: ~/.config/hypr/monolith-workspaces.lua (for hyprland.lua) or .conf, included once at
the end of the main config: persistent workspaces bound to their screen, numbered one after
another (main 1..N, the next N+1..). Hyprland reloads its config by itself.
"""

import json
import os
import shutil
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
NIRI_FILE = os.path.join(CONF, "niri", "config", "workspaces.kdl")
HYPR = os.path.join(CONF, "hypr")


def on_hyprland():
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))


def hypr_lua():
    return os.path.exists(os.path.join(HYPR, "hyprland.lua"))


def kdl_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".part"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def apply_niri(screens):
    if os.path.exists(NIRI_FILE) and not os.path.exists(NIRI_FILE + ".before-monolith"):
        shutil.copy2(NIRI_FILE, NIRI_FILE + ".before-monolith")
    out = ["// Written by Monolith (Settings -> Windows -> Workspaces): how many workspaces each",
           "// screen keeps. Each is pinned to its screen, so it always exists and moves back when",
           "// the screen is turned off and on. Changes here are replaced."]
    for i, (name, n) in enumerate(screens):
        n = max(0, min(20, int(n)))
        out.append("")
        if n == 0:
            out.append(f"// {name}: as many as you use")
            continue
        prefix = "" if i == 0 else f"d{i + 1}-"
        out.append(f"// {name}: {n}")
        for k in range(1, n + 1):
            out.append(f"workspace {kdl_str(prefix + str(k))} {{ open-on-output {kdl_str(name)}; }}")
    write(NIRI_FILE, "\n".join(out) + "\n")


def apply_hypr(screens):
    lua = hypr_lua()
    path = os.path.join(HYPR, "monolith-workspaces." + ("lua" if lua else "conf"))
    c = "--" if lua else "#"
    out = [f"{c} Written by Monolith (Settings -> Windows -> Workspaces): how many workspaces each",
           f"{c} screen keeps, numbered one after another. Changes here are replaced."]
    first = 1
    for name, n in screens:
        n = max(0, min(20, int(n)))
        out.append(f"{c} {name}: " + (f"{n} ({first}-{first + n - 1})" if n else "as many as you use"))
        for k in range(first, first + n):
            if lua:
                out.append(f"hl.workspace_rule({{ workspace = {lua_str(str(k))}, monitor = {lua_str(name)}, "
                           f"persistent = true{', default = true' if k == first else ''} }})")
            else:
                out.append(f"workspace = {k}, monitor:{name}, persistent:true" + (", default:true" if k == first else ""))
        first += n
    write(path, "\n".join(out) + "\n")
    # included once, at the end of the main config
    main = os.path.join(HYPR, "hyprland.lua" if lua else "hyprland.conf")
    line = 'require("monolith-workspaces")' if lua else f"source = {path}"
    try:
        text = open(main, encoding="utf-8").read()
    except OSError:
        return
    if line not in text:
        with open(main, "a", encoding="utf-8") as f:
            f.write(("" if text.endswith("\n") else "\n") + "\n" + line + "\n")


def read_niri():
    counts = {}
    try:
        for l in open(NIRI_FILE, encoding="utf-8"):
            l = l.strip()
            if l.startswith("workspace") and "open-on-output" in l:
                out = l.split("open-on-output", 1)[1].strip().split('"')[1]
                counts[out] = counts.get(out, 0) + 1
    except (OSError, IndexError):
        pass
    return counts


def read_hypr():
    counts = {}
    path = os.path.join(HYPR, "monolith-workspaces." + ("lua" if hypr_lua() else "conf"))
    try:
        for l in open(path, encoding="utf-8"):
            l = l.strip()
            if l.startswith("hl.workspace_rule") and "monitor =" in l:
                out = l.split("monitor =", 1)[1].split('"')[1]
            elif l.startswith("workspace =") and "monitor:" in l:
                out = l.split("monitor:", 1)[1].split(",")[0].strip()
            else:
                continue
            counts[out] = counts.get(out, 0) + 1
    except (OSError, IndexError):
        pass
    return counts


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "read"
    if cmd == "read":
        print(json.dumps(read_hypr() if on_hyprland() else read_niri()))
    elif cmd == "apply":
        screens = json.loads(sys.argv[2])["screens"]
        (apply_hypr if on_hyprland() else apply_niri)(screens)
        print("ok")


if __name__ == "__main__":
    main()
