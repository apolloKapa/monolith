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
    # niri's columns: Hyprland's scrolling layout (general.layout = "scrolling") has them as layout
    # messages (other layouts ignore them)
    msg = {"consume-or-expel-window-left": "consume_or_expel prev", "consume-or-expel-window-right": "consume_or_expel next",
           "consume-window-into-column": "consume", "expel-window-from-column": "expel",
           "center-column": "center", "center-visible-columns": "center",
           "switch-preset-column-width": "colresize +conf", "switch-preset-column-width-back": "colresize -conf"}.get(name)
    if msg:
        return ("hl.dsp.layout(%s)" % lua_str(msg), "layoutmsg, " + msg)
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


# `monolith zoom ...` as Lua run by Hyprland itself: the live zoom (cursor.zoom_factor) around the
# mouse, 1.1x a notch (small steps, and no wait between notches: smooth however fast you
# scroll) up to 10x (Hyprland's most), off at 1x; toggle: 2x or off
_Z = "function() local z = hl.get_config(\"cursor.zoom_factor\") or 1; hl.config({ cursor = { zoom_factor = %s } }) end"
ZOOM_LUA = {
    "in": _Z % "math.min(z * 1.1, 10)",
    "out": _Z % "(z / 1.1 < 1.02) and 1 or z / 1.1",
    "toggle": _Z % "(z > 1) and 1 or 2",
    "off": _Z % "1",
}


def exec_of(cmd):
    return ("hl.dsp.exec_cmd(%s)" % lua_str(cmd), "exec, " + cmd)


MONOLITH = "monolith"
bind_re = re.compile(r"^\s*([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:\"[^\"]*\"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*$")


SECTION = re.compile(r"^\s*//\s*──\s*(.+?)\s*─*\s*$")


def niri_binds(path, sections=None):
    """Every bind in a niri keybinds file: (key, props, action words, the line). With `sections`
    (a dict), each bind's line maps to the section heading above it ("// ── Apps ──")."""
    out, cur = [], ""
    for line in open(path, encoding="utf-8"):
        h = SECTION.match(line)
        if h:
            cur = h.group(1)
            continue
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
            if sections is not None:
                sections[line.rstrip("\n")] = cur
    return out


def command_of(words, monolith):
    """A spawn's command line (monolith pointed at its full path), or None."""
    name, args = words[0], words[1:]
    if name not in ("spawn", "spawn-sh") or not args:
        return None
    cmd = args[0] if name == "spawn-sh" else " ".join(shlex.quote(a) if re.search(r"\s", a) else a for a in args)
    return re.sub(r"^(\S*/)?monolith(?=\s|$)", monolith, cmd)


def translate(path, monolith):
    """Monolith's niri keymap as Hyprland binds: [(mods, key, locked, lua line, conf line,
    dispatcher, section)]."""
    global MONOLITH
    MONOLITH = monolith
    out, seen, secs = [], set(), {}
    for key, props, words, raw in niri_binds(path, secs):
        name, args = words[0], words[1:]
        if name in ("spawn", "spawn-sh"):
            cmd = command_of(words, monolith)
            if not cmd:
                continue
            # niri's own commands mean nothing on Hyprland: a script around niri actions (Mod+T:
            # take the window out of floating, then maximize its column) becomes its last action
            z = re.match(r"^\S*monolith zoom (in|out|toggle|off)$", cmd)
            if "niri msg" in cmd:
                acts = re.findall(r"niri msg action ([a-z-]+)", cmd)
                got = action(acts[-1], []) if acts else None
            elif z:
                # zoom runs inside Hyprland (Lua): a program per scroll notch queued up, so fast
                # scrolling zoomed slowly, a notch at a time
                got = (ZOOM_LUA[z.group(1)], "exec, " + cmd)
            else:
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
        what = got[0]
        # (a scroll key's own cooldown: Lua configs have no shared wait between scroll keys, see
        # scroll_delay; zoom has none)
        cd = re.search(r"cooldown-ms=(\d+)", props)
        if cd and "Wheel" in key and what.startswith("hl.dsp."):
            what = "monolith_cooldown(%s, %s)" % (cd.group(1), what)
        lua = "hl.bind(%s, %s%s)" % (lua_str(" + ".join(mods + [k])), what, ", { locked = true }" if locked else "")
        conf = "%s = %s, %s, %s" % ("bindl" if locked else "bind", " ".join(mods), k, got[1])
        out.append((mods, k, locked, lua, conf, got, secs.get(raw, "")))
    return out


def scroll_delay(path, lua):
    """Hyprland waits 300 ms between scroll-wheel keys (one wait for them all: fast scrolling
    zoomed a notch at a time); niri's keymap gives each its own cooldown-ms. The shortest one
    (zoom's), as a config line; none when no scroll key has one."""
    ms = [int(m.group(1)) for k, props, _, _ in niri_binds(path) if "Wheel" in k
          for m in [re.search(r"cooldown-ms=(\d+)", props)] if m]
    if not ms:
        return []
    if not lua:
        return ["# the wait between scroll-wheel keys (niri's shortest cooldown)", "binds:scroll_event_delay = %d" % min(ms), ""]
    # Lua: no shared wait (zoom glides in small steps however fast you scroll); a scroll key with
    # a cooldown in niri (switching workspaces) waits on its own instead
    return ["-- scroll-wheel keys: no shared wait; each one with a cooldown (as in niri) waits on its own",
            "hl.config({ binds = { scroll_event_delay = 0 } })"] + COOLDOWN_LUA + [""]


# a key that waits `ms` before it works again (niri's cooldown-ms), for binds made with it
COOLDOWN_LUA = [
    "local function monolith_cooldown(ms, what)",
    "  local busy = false",
    "  return function()",
    "    if busy then return end",
    "    busy = true",
    "    hl.dispatch(what)",
    "    hl.timer(function() busy = false end, { timeout = ms, type = \"oneshot\" })",
    "  end",
    "end"]


def render(binds, lua, skip=()):
    """Binds as lines, with a heading where a section starts; `skip`: keys (frozenset of mods,
    lowercase key) to leave out."""
    c = "--" if lua else "#"
    lines, last = [], None
    for b in binds:
        if (frozenset(b[0]), b[1].lower()) in skip:
            continue
        if b[6] != last and b[6]:
            if lines:
                lines.append("")
            lines.append("%s ── %s %s" % (c, b[6], "─" * max(3, 60 - len(b[6]))))
            last = b[6]
        lines.append(b[3] if lua else b[4])
    return lines


if __name__ == "__main__":
    src, fmt, monolith = sys.argv[1], sys.argv[2], sys.argv[3]
    print("\n".join(render(translate(src, monolith), fmt == "lua")))
