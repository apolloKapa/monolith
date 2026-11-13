#!/usr/bin/env python3
"""Monolith's niri keybinds as Hyprland binds, so Hyprland gets the same key layout.

    hypr_keys.py <niri keybinds.kdl> lua|conf <monolith command path>

Prints the binds (hl.bind lines for hyprland.lua, bind lines for hyprland.conf). Each niri
action becomes Hyprland's nearest one (columns are windows, a column's workspace is the window's);
actions with no Hyprland counterpart (niri's column presets, tabbed columns, screen casts) are
left out. Lua dispatchers follow Hyprland 0.55's hl.dsp names.
"""
import re
import shlex
import sys


DIRS = {"left": "l", "right": "r", "up": "u", "down": "d"}
WORDS = {"left": "left", "right": "right", "up": "up", "down": "down"}
KEYS = {"Slash": "slash", "Comma": "comma", "Period": "period", "Minus": "minus", "Equal": "equal",
        "BracketLeft": "bracketleft", "BracketRight": "bracketright", "Page_Down": "Next", "Page_Up": "Prior",
        "Escape": "Escape", "Space": "SPACE", "Tab": "TAB", "Delete": "Delete",
        "WheelScrollDown": "mouse_down", "WheelScrollUp": "mouse_up",
        "WheelScrollLeft": "mouse_left", "WheelScrollRight": "mouse_right"}
MODS = {"Mod": "SUPER", "Super": "SUPER", "Ctrl": "CTRL", "Control": "CTRL", "Shift": "SHIFT", "Alt": "ALT"}


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def keyspec(k):
    parts = k.split("+")
    mods = [MODS[p] for p in parts[:-1] if p in MODS]
    key = KEYS.get(parts[-1], parts[-1])
    return mods, key


def action(name, args):
    """(lua dispatcher, conf dispatcher + args) for a niri action, or None."""
    m = re.match(r"^(focus|move)-(column|window)-(left|right|up|down)$", name)
    if m:
        d = m.group(3)
        if m.group(1) == "focus":
            return ("hl.dsp.focus({ direction = %s })" % lua_str(WORDS[d]), "movefocus, " + DIRS[d])
        return ("hl.dsp.window.move({ direction = %s })" % lua_str(DIRS[d]), "movewindow, " + DIRS[d])
    m = re.match(r"^focus-monitor-(left|right|up|down)$", name)
    if m:
        return ("hl.dsp.focus({ monitor = %s })" % lua_str(DIRS[m.group(1)]), "focusmonitor, " + DIRS[m.group(1)])
    m = re.match(r"^move-(column|window)-to-monitor-(left|right|up|down)$", name)
    if m:
        d = DIRS[m.group(2)]
        return ("hl.dsp.window.move({ monitor = %s })" % lua_str(d), "movewindow, mon:" + d)
    if name == "focus-workspace" and args:
        return ("hl.dsp.focus({ workspace = %s })" % args[0], "workspace, " + args[0])
    if name in ("move-column-to-workspace", "move-window-to-workspace") and args:
        return ("hl.dsp.window.move({ workspace = %s })" % args[0], "movetoworkspace, " + args[0])
    if name in ("focus-workspace-down", "focus-workspace-up"):
        w = "m+1" if name.endswith("down") else "m-1"
        return ("hl.dsp.focus({ workspace = %s })" % lua_str(w), "workspace, " + w)
    if name in ("move-column-to-workspace-down", "move-column-to-workspace-up", "move-window-to-workspace-down", "move-window-to-workspace-up"):
        w = "m+1" if name.endswith("down") else "m-1"
        return ("hl.dsp.window.move({ workspace = %s })" % lua_str(w), "movetoworkspace, " + w)
    if name == "close-window":
        return ("hl.dsp.window.close()", "killactive,")
    if name == "toggle-window-floating":
        return ('hl.dsp.window.float({ action = "toggle" })', "togglefloating,")
    if name == "fullscreen-window":
        return ('hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })', "fullscreen, 0")
    if name in ("maximize-column", "expand-column-to-available-width"):
        return ('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })', "fullscreen, 1")
    if name == "toggle-column-tabbed-display":
        return ("hl.dsp.group.toggle()", "togglegroup,")
    if name in ("set-column-width", "set-window-height") and args:
        v = args[0].strip('"')
        m = re.match(r"^([+-])(\d+)%$", v)
        if not m:
            return None
        px = (1 if m.group(1) == "+" else -1) * int(m.group(2)) * 10
        x, y = (px, 0) if name == "set-column-width" else (0, px)
        return ("hl.dsp.window.resize({ x = %d, y = %d, relative = true })" % (x, y), "resizeactive, %d %d" % (x, y))
    if name == "quit":
        return ("hl.dsp.exit()", "exit,")
    if name == "power-off-monitors":
        return ('hl.dsp.dpms({ action = "disable" })', "dpms, off")
    # niri's own windows that Monolith has too
    if name == "show-hotkey-overlay":
        return exec_of(MONOLITH + " msg toggle cheatsheet")
    if name == "toggle-overview":
        return exec_of(MONOLITH + " msg toggle switcher")
    return None


def exec_of(cmd):
    return ("hl.dsp.exec_cmd(%s)" % lua_str(cmd), "exec, " + cmd)


MONOLITH = "monolith"
bind_re = re.compile(r"^\s*([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:\"[^\"]*\"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*$")


def niri_binds(path):
    """Every bind in a niri keybinds file: (key, props, action words, the line)."""
    out = []
    for line in open(path, encoding="utf-8"):
        if line.strip().startswith("//"):
            continue
        m = bind_re.match(line.rstrip("\n"))
        if not m:
            continue
        try:
            words = shlex.split(m.group(3).strip())
        except ValueError:
            continue
        if words:
            out.append((m.group(1), m.group(2), words, line.rstrip("\n")))
    return out


def command_of(words, monolith):
    """A spawn's command line (monolith pointed at its full path), or None."""
    name, args = words[0], words[1:]
    if name not in ("spawn", "spawn-sh") or not args:
        return None
    cmd = args[0] if name == "spawn-sh" else " ".join(shlex.quote(a) if re.search(r"\s", a) else a for a in args)
    return re.sub(r"^(\S*/)?monolith(?=\s|$)", monolith, cmd)


def translate(path, monolith):
    """Monolith's niri keymap as Hyprland binds: [(mods, key, locked, lua line, conf line)]."""
    global MONOLITH
    MONOLITH = monolith
    out, seen = [], set()
    for key, props, words, _ in niri_binds(path):
        name, args = words[0], words[1:]
        if name in ("spawn", "spawn-sh"):
            cmd = command_of(words, monolith)
            # (niri's own commands mean nothing on Hyprland)
            if not cmd or "niri msg" in cmd:
                continue
            got = exec_of(cmd)
        else:
            got = action(name, args)
        if not got:
            continue
        mods, k = keyspec(key)
        sig = (frozenset(mods), k.lower())
        if sig in seen:
            continue
        seen.add(sig)
        locked = "allow-when-locked=true" in props
        lua = "hl.bind(%s, %s%s)" % (lua_str(" + ".join(mods + [k])), got[0], ", { locked = true }" if locked else "")
        conf = "%s = %s, %s, %s" % ("bindl" if locked else "bind", " ".join(mods), k, got[1])
        out.append((mods, k, locked, lua, conf, got))
    return out


if __name__ == "__main__":
    src, fmt, monolith = sys.argv[1], sys.argv[2], sys.argv[3]
    print("\n".join(b[3] if fmt == "lua" else b[4] for b in translate(src, monolith)))
