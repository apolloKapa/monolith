#!/usr/bin/env python3
"""Keyboard shortcuts (Settings -> Devices -> Keyboard shortcuts): list them, change a key, remove
one, add one, on niri and on Hyprland.

    keys.py list                       JSON: {"compositor", "items": [{key, label, section, title, action}]}
    keys.py change OLD NEW [--replace] OLD/NEW like "Super+Shift+S". A NEW that another shortcut has is
                                       refused; with --replace that one loses it, in the same step
    keys.py remove KEY
    keys.py add KEY ACTION_JSON [--replace]
                                       {"type": "app", "cmd": "firefox"} | {"type": "monolith", "sub": "msg toggle launcher"}
                                       | {"type": "window", "name": "close"} | {"type": "workspace", "n": 3}
    keys.py hypr-apply                 stdin -> stdout: Hyprland's freshly made keybinds with your changes
                                       put back on (the installer runs it after an update)
Every answer is JSON: {"ok": true} or {"ok": false, "error": "..."}.

niri: ~/.config/niri/config/keybinds.kdl is edited in place (it's your config); niri checks it,
and a change it doesn't accept is undone.
Hyprland: Monolith's ~/.config/hypr/monolith/keybinds file is edited, and the change is kept in
~/.config/monolith/keys-hyprland.json, so an update (which writes that file again) keeps it. If
Hyprland reports a new config error after a change, the change is undone.
"""
import glob
import json
import os
import re
import shlex
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
NIRI_KEYS = os.path.join(CONF, "niri", "config", "keybinds.kdl")
NIRI_MAIN = os.path.join(CONF, "niri", "config.kdl")
OVERRIDES = os.path.join(CONF, "monolith", "keys-hyprland.json")
MONOLITH = os.path.join(HOME, ".local", "bin", "monolith")
HYPR = bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) or "--hyprland" in sys.argv

MODS = ["Super", "Ctrl", "Alt", "Shift"]
MODIN = {"MOD": "Super", "SUPER": "Super", "WIN": "Super", "LOGO": "Super", "META": "Super", "MOD4": "Super",
         "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt", "MOD1": "Alt", "SHIFT": "Shift"}
# niri's key names -> Hyprland's
HYPR_KEY = {"Slash": "slash", "Comma": "comma", "Period": "period", "Minus": "minus", "Equal": "equal",
            "BracketLeft": "bracketleft", "BracketRight": "bracketright", "Page_Down": "Next", "Page_Up": "Prior",
            "Space": "SPACE", "Tab": "TAB", "WheelScrollDown": "mouse_down", "WheelScrollUp": "mouse_up",
            "WheelScrollLeft": "mouse_left", "WheelScrollRight": "mouse_right", "Semicolon": "semicolon",
            "Apostrophe": "apostrophe", "Grave": "grave", "Backslash": "backslash"}
NIRI_KEY = {v.lower(): k for k, v in HYPR_KEY.items()}


def out(obj):
    print(json.dumps(obj))
    sys.exit(0)


# ── keys, however they're written ──
def parse_key(text):
    """"Super+Shift+S", "Mod+Shift+S", "SUPER + SHIFT + S" -> (mods in order, key in niri's words)."""
    parts = [p.strip() for p in re.split(r"\s*\+\s*", text.strip()) if p.strip()]
    if not parts:
        return None
    mods = sorted({MODIN[p.upper()] for p in parts[:-1] if p.upper() in MODIN}, key=MODS.index)
    k = parts[-1]
    k = NIRI_KEY.get(k.lower(), k)
    if len(k) == 1:
        k = k.upper()
    return mods, k


def same(a, b):
    pa, pb = parse_key(a), parse_key(b)
    return bool(pa and pb) and pa[0] == pb[0] and pa[1].lower() == pb[1].lower()


def label(mods, k):
    return " + ".join(mods + [k.replace("_", " ")])


def niri_key(mods, k):
    return "+".join(["Mod" if m == "Super" else m for m in mods] + [k])


def hypr_key(mods, k):
    return " + ".join([m.upper() for m in mods] + [HYPR_KEY.get(k, k)])


# ── what a key does, in words ──
MENU = {"launcher": "Open the launcher", "system": "Control center", "settings": "Settings", "network": "Network",
        "volume": "Sound", "autohide": "Hide or show the bar", "clipboard": "Clipboard", "cheatsheet": "All the keys",
        "music": "Music", "wallpaper": "Wallpapers", "emoji": "Emoji", "switcher": "Window switcher",
        "notifications": "Notifications", "calendar": "Calendar"}
ACTIONS = {"close-window": "Close the window", "fullscreen-window": "Fullscreen", "maximize-column": "Maximise",
           "toggle-window-floating": "Float or tile the window", "toggle-overview": "Overview", "quit": "Log out",
           "power-off-monitors": "Turn the screens off", "show-hotkey-overlay": "Show the keys",
           "consume-or-expel-window-left": "Pull a window into the column (left)",
           "consume-or-expel-window-right": "Pull a window into the column (right)",
           "consume-window-into-column": "Pull a window into the column", "expand-column-to-available-width": "Fill the free width",
           "center-visible-columns": "Centre the columns", "toggle-column-tabbed-display": "Tabbed column",
           "switch-focus-between-floating-and-tiling": "Between floating and tiled windows",
           "reset-window-height": "Reset the height", "switch-preset-column-width-back": "Previous width",
           "switch-preset-window-height": "Next height", "set-dynamic-cast-window": "Cast the window (OBS)",
           "clear-dynamic-cast-target": "Stop casting (OBS)"}


def describe_cmd(cmd):
    m = re.search(r"monolith\S*\s+(.*)$", cmd)
    if m:
        sub = m.group(1).strip()
        t = re.match(r"(?:msg\s+toggle|hub)\s+(\S+)", sub)
        if t:
            return MENU.get(t.group(1), t.group(1).capitalize())
        first = sub.split()[0] if sub else ""
        return {"lock": "Lock the screen", "restart": "Restart the shell", "appimages": "AppImages",
                "screenshot": "Screenshot" + (" of the whole screen" if "--full" in sub else " of an area") + (", edit it" if "--edit" in sub else ""),
                "zoom": "Zoom " + (sub.split()[1] if len(sub.split()) > 1 else "")}.get(first, "Monolith: " + sub)
    if re.search(r"wpctl.*SOURCE.*mute", cmd):
        return "Microphone on or off"
    if re.search(r"wpctl.*mute", cmd):
        return "Sound on or off"
    if re.search(r"wpctl.*%\+", cmd):
        return "Volume up"
    if re.search(r"wpctl.*%-", cmd):
        return "Volume down"
    if "brightnessctl" in cmd:
        return "Brightness " + ("up" if "+" in cmd else "down")
    if "playerctl" in cmd:
        return {"play-pause": "Play or pause", "next": "Next track", "previous": "Previous track", "stop": "Stop"}.get(cmd.split()[-1], "Media")
    if "niri msg" in cmd:
        return "Maximise (floating windows too)"
    return "Run " + cmd.split()[0].rsplit("/", 1)[-1]


def describe_niri(words):
    name, args = words[0], words[1:]
    if name in ("spawn", "spawn-sh"):
        return describe_cmd(args[0] if name == "spawn-sh" else " ".join(args))
    m = re.match(r"^(focus|move)-(column|window)-(left|right|up|down|first|last)$", name)
    if m:
        return ("Focus " if m.group(1) == "focus" else "Move the window ") + m.group(3)
    m = re.match(r"^(focus-monitor|move-column-to-monitor|move-window-to-monitor)-(left|right|up|down)$", name)
    if m:
        return ("Focus the screen " if m.group(1) == "focus-monitor" else "Move the window to the screen ") + m.group(2)
    if name == "focus-workspace":
        return "Workspace " + args[0]
    if name in ("move-column-to-workspace", "move-window-to-workspace"):
        return "Move the window to workspace " + args[0]
    if name in ("focus-workspace-down", "focus-workspace-up"):
        return ("Next" if name.endswith("down") else "Previous") + " workspace"
    if name.startswith("move-column-to-workspace-") or name.startswith("move-window-to-workspace-"):
        return "Move the window to the " + ("next" if name.endswith("down") else "previous") + " workspace"
    if name in ("set-column-width", "set-window-height"):
        return ("Wider" if "+" in (args[0] if args else "") else "Narrower") if name == "set-column-width" else \
            ("Taller" if "+" in (args[0] if args else "") else "Shorter")
    if name in ("move-column-to-first", "move-column-to-last"):
        return "Move the window to the " + name.rsplit("-", 1)[-1]
    return ACTIONS.get(name, name.replace("-", " ").capitalize())


def describe_hypr(dispatch):
    m = re.search(r'exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', dispatch) or re.match(r"^exec,\s*(.*)$", dispatch)
    if m:
        return describe_cmd(m.group(1))
    # Monolith's own Lua for the keys niri has built in (install/modules/hypr_keys.py)
    if "zoom_factor" in dispatch:
        return "Zoom in" if "z *" in dispatch else "Zoom out" if "z /" in dispatch else "Zoom toggle"
    m = re.search(r"monolith_ws_step\(\s*(-?\d+)\s*(,\s*true)?", dispatch)
    if m:
        way = "next" if int(m.group(1)) > 0 else "previous"
        return "Move the window to the %s workspace" % way if m.group(2) else way.capitalize() + " workspace"
    m = re.search(r'\blayout\("([^"]+)"\)', dispatch)
    if m:
        return {"consume_or_expel prev": ACTIONS["consume-or-expel-window-left"], "consume_or_expel next": ACTIONS["consume-or-expel-window-right"],
                "consume": ACTIONS["consume-window-into-column"], "expel": "Push the window out of the column",
                "center": ACTIONS["center-visible-columns"], "colresize +conf": "Next width",
                "colresize -conf": ACTIONS["switch-preset-column-width-back"]}.get(m.group(1), "Layout: " + m.group(1))
    m = re.search(r'global\("quickshell:monolith-alttab(-back)?"\)', dispatch)
    if m:
        return "Switch windows (backwards)" if m.group(1) else "Switch windows"
    if re.search(r"window\.drag\(\)", dispatch):
        return "Drag the window with the mouse"
    if re.search(r"window\.resize\(\)", dispatch):
        return "Resize the window with the mouse"
    for rx, t in ((r"window\.close|killactive", "Close the window"), (r'mode = "fullscreen"|fullscreen,\s*0', "Fullscreen"),
                  (r'mode = "maximized"|fullscreen,\s*1', "Maximise"), (r"window\.float|togglefloating", "Float or tile the window"),
                  (r"group\.toggle|togglegroup", "Tabbed group"), (r"\bexit\b", "Log out"), (r"dpms", "Turn the screens off")):
        if re.search(rx, dispatch):
            return t
    m = re.search(r'window\.move\(\{\s*workspace = "?([^"\s}]+)|movetoworkspace,\s*(\S+)', dispatch)
    if m:
        w = m.group(1) or m.group(2)
        return {"m+1": "Move the window to the next workspace", "m-1": "Move the window to the previous workspace"}.get(w, "Move the window to workspace " + w)
    m = re.search(r'focus\(\{\s*workspace = "?([^"\s}]+)|workspace,\s*(\S+)', dispatch)
    if m:
        w = m.group(1) or m.group(2)
        return {"m+1": "Next workspace", "m-1": "Previous workspace"}.get(w, "Workspace " + w)
    m = re.search(r'focus\(\{\s*monitor = "(\w)"|focusmonitor,\s*(\w)', dispatch)
    if m:
        return "Focus the screen " + {"l": "left", "r": "right", "u": "up", "d": "down"}[m.group(1) or m.group(2)]
    m = re.search(r'window\.move\(\{\s*monitor = "(\w)"', dispatch)
    if m:
        return "Move the window to the screen " + {"l": "left", "r": "right", "u": "up", "d": "down"}[m.group(1)]
    m = re.search(r'focus\(\{\s*direction = "(\w+)"|movefocus,\s*(\w)', dispatch)
    if m:
        d = m.group(1) or m.group(2)
        return "Focus " + {"l": "left", "r": "right", "u": "up", "d": "down"}.get(d, d)
    m = re.search(r'window\.move\(\{\s*direction = "(\w)"|movewindow,\s*(\w)', dispatch)
    if m:
        return "Move the window " + {"l": "left", "r": "right", "u": "up", "d": "down"}[m.group(1) or m.group(2)]
    m = re.search(r"resize\(\{\s*x = (-?\d+), y = (-?\d+)|resizeactive,\s*(-?\d+)\s+(-?\d+)", dispatch)
    if m:
        x, y = int(m.group(1) or m.group(3)), int(m.group(2) or m.group(4))
        return ("Wider" if x > 0 else "Narrower") if x else ("Taller" if y > 0 else "Shorter")
    return dispatch


# ── niri ──
NIRI_BIND = re.compile(r"^(\s*)([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:\"[^\"]*\"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*$")
SECTION = re.compile(r"^\s*//\s*──\s*(.+?)\s*─*\s*$")


def niri_items():
    items, sec = [], ""
    for line in open(NIRI_KEYS, encoding="utf-8"):
        h = SECTION.match(line)
        if h:
            sec = h.group(1)
            continue
        if line.strip().startswith("//"):
            continue
        m = NIRI_BIND.match(line.rstrip("\n"))
        if not m:
            continue
        try:
            words = shlex.split(m.group(4))
        except ValueError:
            continue
        pk = parse_key(m.group(2))
        if not pk or not words:
            continue
        t = re.search(r'hotkey-overlay-title="([^"]*)"', m.group(3))
        items.append({"key": "+".join(pk[0] + [pk[1]]), "label": label(*pk), "section": sec or "Other",
                      "title": t.group(1) if t else describe_niri(words), "action": " ".join(words)})
    return items


def niri_valid():
    try:
        return subprocess.run(["niri", "validate", "-c", NIRI_MAIN], capture_output=True, timeout=15).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return True


def niri_edit(fn):
    """Change keybinds.kdl with fn(lines) -> lines or an error; niri checks it, undone if not accepted."""
    old = open(NIRI_KEYS, encoding="utf-8").read()
    res = fn(old.split("\n"))
    if isinstance(res, str):
        out({"ok": False, "error": res})
    open(NIRI_KEYS, "w", encoding="utf-8").write("\n".join(res))
    if not niri_valid():
        open(NIRI_KEYS, "w", encoding="utf-8").write(old)
        out({"ok": False, "error": "niri didn't accept that, so nothing changed"})
    out({"ok": True})


def niri_find(lines, key):
    for i, line in enumerate(lines):
        if line.strip().startswith("//"):
            continue
        m = NIRI_BIND.match(line)
        if m and same(m.group(2), key):
            return i, m
    return None, None


def niri_action(action):
    t = action.get("type")
    if t == "app":
        return 'spawn-sh "%s"' % action["cmd"].replace("\\", "\\\\").replace('"', '\\"')
    if t == "monolith":
        return "spawn " + " ".join('"%s"' % w for w in [MONOLITH] + action["sub"].split())
    if t == "workspace":
        return "focus-workspace %d" % int(action["n"])
    return {"close": "close-window", "fullscreen": "fullscreen-window", "maximize": "maximize-column",
            "float": "toggle-window-floating", "overview": "toggle-overview"}.get(action.get("name"), None)


# ── Hyprland ──
def hypr_paths():
    import hypr_files as hf
    return hf.path("keybinds"), hf.path("my-keys"), hf.kind() == "lua"


HYPR_LUA = re.compile(r'^(\s*)hl\.bind\("([^"]+)",\s*(.*)\)\s*$')
HYPR_CONF = re.compile(r"^(\s*)(bind[a-z]*)\s*=\s*([^,]*),\s*([^,]+),\s*(.*)$")


def hypr_line_key(line, lua):
    if lua:
        m = HYPR_LUA.match(line)
        return (m.group(2), m.group(3)) if m else None
    m = HYPR_CONF.match(line)
    return ((m.group(3).strip() + " + " + m.group(4).strip()).strip(" +"), m.group(5)) if m else None


def hypr_items():
    path, mine, lua = hypr_paths()
    items, sec = [], ""
    c = "--" if lua else "#"
    for src, tag in ((path, None), (mine, "Your own (my-keys)")):
        try:
            lines = open(src, encoding="utf-8").read().split("\n")
        except OSError:
            continue
        for line in lines:
            h = re.match(r"^\s*" + re.escape(c) + r"\s*──\s*(.+?)\s*─*\s*$", line)
            if h:
                sec = h.group(1)
                continue
            if line.strip().startswith(c):
                continue
            got = hypr_line_key(line, lua)
            if not got:
                continue
            # (letting go of Alt ends Alt+Tab: the switcher's own wiring, not a shortcut to change)
            if "monolith-alttab-done" in got[1]:
                continue
            pk = parse_key(got[0])
            if not pk:
                continue
            items.append({"key": "+".join(pk[0] + [pk[1]]), "label": label(*pk), "section": tag or sec or "Other",
                          "title": describe_hypr(got[1]), "action": got[1], "mine": bool(tag)})
    return items


HEAD = " ── Added in Settings " + "─" * 41


def load_over():
    try:
        o = json.load(open(OVERRIDES, encoding="utf-8"))
        return o if isinstance(o.get("ops"), list) else {"ops": []}
    except (OSError, ValueError, AttributeError):
        return {"ops": []}


def save_over(o):
    os.makedirs(os.path.dirname(OVERRIDES), exist_ok=True)
    json.dump(o, open(OVERRIDES, "w", encoding="utf-8"), indent=1)


def apply_ops(text, lua, ops):
    """Your changes, in the order you made them, on a keybinds file."""
    lines = text.split("\n")
    c = "--" if lua else "#"
    for op in ops:
        if op.get("op") == "add":
            # (after the last line, not after the empty one a file ends with: every added key
            # used to get a blank line above it)
            while lines and not lines[-1].strip():
                lines.pop()
            if c + HEAD not in lines:
                lines += ["", c + HEAD]
            lines.append(op["lua"] if lua else op["conf"])
            continue
        for i, line in enumerate(lines):
            got = hypr_line_key(line, lua) if not line.strip().startswith(c) else None
            if not got or not same(got[0], op.get("key", "")):
                continue
            if op["op"] == "remove":
                del lines[i]
            elif op["op"] == "move":
                pk = parse_key(op["to"])
                if lua:
                    lines[i] = line.replace('"%s"' % got[0], '"%s"' % hypr_key(*pk), 1)
                else:
                    m = HYPR_CONF.match(line)
                    lines[i] = "%s%s = %s, %s, %s" % (m.group(1), m.group(2), " ".join(x.upper() for x in pk[0]), HYPR_KEY.get(pk[1], pk[1]), m.group(5))
            break
    return "\n".join(lines)


def hypr_errors():
    try:
        r = subprocess.run(["hyprctl", "configerrors"], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""
    return "" if r.lower() in ("", "no errors") else r


def hypr_change(ops):
    """Apply a change (or a few that belong together: the other shortcut loses a key, this one
    takes it) to the keybinds file and remember it (updates replay it); all undone if Hyprland
    then reports a new error."""
    path, mine, lua = hypr_paths()
    old_text = open(path, encoding="utf-8").read()
    c = "--" if lua else "#"
    for op in ops:
        if op["op"] != "add" and not any((g := hypr_line_key(l, lua)) and same(g[0], op["key"]) for l in old_text.split("\n") if not l.strip().startswith(c)):
            out({"ok": False, "error": "%s is in your own config, not Monolith's keybinds file: change it there" % label(*parse_key(op["key"]))})
    o = load_over()
    old_o = json.loads(json.dumps(o))
    o["ops"] += ops
    before = hypr_errors()
    new_text = apply_ops(old_text, lua, ops)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text if new_text.endswith("\n") else new_text + "\n")
    save_over(o)
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        subprocess.run(["hyprctl", "reload"], capture_output=True)
        time.sleep(1.0)
        after = hypr_errors()
        if after and after != before:
            open(path, "w", encoding="utf-8").write(old_text)
            save_over(old_o)
            subprocess.run(["hyprctl", "reload"], capture_output=True)
            out({"ok": False, "error": "Hyprland didn't accept that, so nothing changed: " + after.splitlines()[0]})
    out({"ok": True})


def hypr_action(action, lua):
    t = action.get("type")
    if t == "app":
        cmd = action["cmd"]
        return ('hl.dsp.exec_cmd("%s")' % cmd.replace("\\", "\\\\").replace('"', '\\"')) if lua else "exec, " + cmd
    if t == "monolith":
        cmd = MONOLITH + " " + action["sub"]
        return ('hl.dsp.exec_cmd("%s")' % cmd) if lua else "exec, " + cmd
    if t == "workspace":
        n = int(action["n"])
        return ("hl.dsp.focus({ workspace = %d })" % n) if lua else "workspace, %d" % n
    lua_map = {"close": "hl.dsp.window.close()", "fullscreen": 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })',
               "maximize": 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })', "float": 'hl.dsp.window.float({ action = "toggle" })'}
    conf_map = {"close": "killactive,", "fullscreen": "fullscreen, 0", "maximize": "fullscreen, 1", "float": "togglefloating,"}
    return (lua_map if lua else conf_map).get(action.get("name"))


# ── Hyprland: the keys in your own config (not Monolith's files), and what Hyprland has live ──
# Someone running Hyprland with their own config (or another shell's) has their keys there, not
# in Monolith's keybinds file: they're listed too, as yours (change them in that file).
def hypr_config_files():
    """Hyprland's main config and every file it pulls in (require/dofile in Lua, source = in a
    classic config), Monolith's own folder left out (it's read on its own)."""
    import hypr_files as hf
    lua = hf.kind() == "lua"
    main = hf.running_config() or hf.main_config()
    found, seen = [], set()

    def visit(p, depth):
        p = os.path.realpath(os.path.expanduser(p))
        if p in seen or depth > 6 or len(found) >= 80 or not os.path.isfile(p):
            return
        seen.add(p)
        if p.startswith(os.path.realpath(hf.FOLDER) + os.sep):
            return
        try:
            text = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            return
        found.append((p, text))
        base = os.path.dirname(p)
        if lua:
            for m in re.finditer(r"""\brequire\s*\(?\s*["']([^"']+)["']""", text):
                mod = m.group(1).replace(".", "/")
                for cand in (os.path.join(hf.HYPR, mod + ".lua"), os.path.join(hf.HYPR, mod, "init.lua")):
                    visit(cand, depth + 1)
            for m in re.finditer(r"""\bdofile\s*\(?\s*["']([^"']+)["']""", text):
                visit(os.path.join(base, os.path.expanduser(m.group(1))), depth + 1)
        else:
            for m in re.finditer(r"^\s*source\s*=\s*(.+?)\s*$", text, re.M):
                pat = os.path.join(base, os.path.expanduser(m.group(1)))
                for f in sorted(glob.glob(pat)) or [pat]:
                    visit(f, depth + 1)
    visit(main, 0)
    return found, lua


def lua_calls(text, name):
    """Each name("first", rest…) call in Lua source, however it's spread over lines: (first, rest)."""
    out, i = [], 0
    rx = re.compile(re.escape(name) + r'\s*\(\s*"((?:[^"\\]|\\.)*)"\s*,')
    while True:
        m = rx.search(text, i)
        if not m:
            return out
        j, depth, q = m.end(), 1, None
        while j < len(text) and depth:
            c = text[j]
            if q:
                if c == "\\":
                    j += 1
                elif c == q:
                    q = None
            elif c in "\"'":
                q = c
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            j += 1
        out.append((m.group(1), text[m.end():j - 1].strip()))
        i = j


def conf_key(mods, key, variables):
    mods = re.sub(r"\$(\w+)", lambda v: variables.get(v.group(1), v.group(0)), mods)
    words = [w for w in re.split(r"[\s_+]+", mods.strip()) if w]
    return " + ".join(words + [key.strip()])


def hypr_config_items():
    files, lua = hypr_config_files()
    items = []
    for path, text in files:
        tag = "Your Hyprland config (" + os.path.basename(path) + ")"
        if lua:
            body = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
            body = "\n".join(l for l in body.split("\n") if not l.strip().startswith("--"))
            for key, rest in lua_calls(body, "hl.bind"):
                pk = parse_key(key)
                if pk:
                    items.append({"key": "+".join(pk[0] + [pk[1]]), "label": label(*pk), "section": tag,
                                  "title": describe_hypr(rest), "action": rest, "mine": True})
        else:
            variables = {}
            for line in text.split("\n"):
                line = line.split("#", 1)[0].rstrip()
                v = re.match(r"^\s*\$(\w+)\s*=\s*(.*)$", line)
                if v:
                    variables[v.group(1)] = v.group(2).strip()
                    continue
                m = re.match(r"^\s*bind([a-z]*)\s*=\s*(.*)$", line)
                if not m:
                    continue
                parts = [x.strip() for x in m.group(2).split(",")]
                if len(parts) < 3:
                    continue
                desc = None
                if "d" in m.group(1) and len(parts) >= 4:
                    desc = parts.pop(2)
                dispatch = parts[2] + ", " + ", ".join(parts[3:]) if len(parts) > 3 else parts[2] + ","
                pk = parse_key(conf_key(parts[0], parts[1], variables))
                if pk:
                    items.append({"key": "+".join(pk[0] + [pk[1]]), "label": label(*pk), "section": tag,
                                  "title": desc or describe_hypr(dispatch), "action": dispatch, "mine": True})
    return items


HYPR_MODS = ((64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift"))
HYPR_WHAT = {"exec": "Run a program", "exec_cmd": "Run a program", "killactive": "Close the window", "close": "Close the window",
             "movefocus": "Focus", "focus": "Focus", "movewindow": "Move the window", "move": "Move", "workspace": "Workspace",
             "movetoworkspace": "Move the window to a workspace", "fullscreen": "Fullscreen", "togglefloating": "Float or tile the window",
             "float": "Float or tile the window", "resizeactive": "Resize the window", "resize": "Resize the window", "exit": "Log out",
             "global": "A shortcut of an app", "layout": "Layout", "pass": "Passed to an app", "submap": "Key mode", "dpms": "Turn the screens off"}


def hypr_live_items():
    """What the running Hyprland has bound (hyprctl binds): the keys and the kind of action."""
    try:
        r = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5)
        binds = json.loads(r.stdout or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    items = []
    for b in binds if isinstance(binds, list) else []:
        if b.get("mouse") or b.get("submap"):
            continue
        key = str(b.get("key") or "")
        if not key:
            continue
        side = re.match(r"^(ALT|SUPER|CONTROL|SHIFT|META)_([LR])$", key, re.I)
        if side and b.get("release"):
            continue    # (letting go of a modifier: Alt+Tab's own wiring)
        if side:
            key = ("Left " if side.group(2).upper() == "L" else "Right ") + {"control": "Ctrl"}.get(side.group(1).lower(), side.group(1).capitalize())
        mods = [n for bit, n in HYPR_MODS if int(b.get("modmask") or 0) & bit]
        pk = parse_key(" + ".join(mods + [key]))
        if not pk:
            continue
        d = str(b.get("dispatcher") or "")
        name = re.sub(r"^HL\.Dispatcher\((.*)\)$", r"\1", d)
        arg = str(b.get("arg") or "")
        if b.get("has_description") and b.get("description"):
            title = b["description"]
        elif name != d:
            title = HYPR_WHAT.get(name, name.replace("_", " ").capitalize())
        else:
            title = describe_hypr(name + ", " + arg)
        items.append({"key": "+".join(pk[0] + [pk[1]]), "label": label(*pk), "section": "Set in Hyprland",
                      "title": title, "action": d + (" " + arg if name == d and arg else ""), "mine": True})
    return items


def hypr_all_items():
    """Monolith's keys and your my-keys, then your own config's, then anything else Hyprland
    has live; a key listed once (the first place it's found)."""
    try:
        first = hypr_items()
    except OSError:
        first = []
    out, keys = [], set()
    for group in (first, hypr_config_items(), hypr_live_items()):
        for it in group:
            k = it["key"].lower()
            if k in keys:
                continue
            keys.add(k)
            out.append(it)
    return out


# ── commands ──
def items():
    return hypr_all_items() if HYPR else niri_items()


def taken_by(key, skip=None):
    for it in items():
        if same(it["key"], key) and not (skip and same(it["key"], skip)):
            return it
    return None


def main():
    a = [x for x in sys.argv[1:] if x not in ("--hyprland", "--replace")]
    replace = "--replace" in sys.argv

    def holder(key, skip=None):
        """The shortcut that has `key` already: None when it's free. Refused unless it's to be
        replaced, and it can only be replaced when it's one of Monolith's."""
        other = taken_by(key, skip)
        if not other:
            return None
        what = "%s is already used in \u201c%s\u201d" % (label(*parse_key(key)), other["title"])
        if not replace:
            out({"ok": False, "error": what})
        if other.get("mine"):
            out({"ok": False, "error": what + ", which is in your own config: change it there, or pick another key"})
        return other
    cmd = a[0] if a else "list"
    if cmd == "list":
        try:
            out({"ok": True, "compositor": "hyprland" if HYPR else "niri", "items": items()})
        except OSError as e:
            out({"ok": False, "error": "No keybinds file: " + str(e.filename), "items": []})
    if cmd == "hypr-apply":
        text = sys.stdin.read()
        _, _, lua = hypr_paths()
        sys.stdout.write(apply_ops(text, lua, load_over()["ops"]))
        return
    if cmd == "change":
        old, new = a[1], a[2]
        pn = parse_key(new)
        if not pn or not pn[1]:
            out({"ok": False, "error": "That isn't a key"})
        if same(old, new):
            out({"ok": True})
        other = holder(new, skip=old)
        if HYPR:
            hypr_change(([{"op": "remove", "key": other["key"]}] if other else []) + [{"op": "move", "key": old, "to": new}])

        def g(lines):
            if other:
                j, _ = niri_find(lines, other["key"])
                if j is not None:
                    del lines[j]
            i, m = niri_find(lines, old)
            if i is None:
                return "That key isn't in the keybinds file"
            lines[i] = lines[i].replace(m.group(2), niri_key(*pn), 1)
            return lines
        niri_edit(g)
    if cmd == "remove":
        key = a[1]
        if HYPR:
            hypr_change([{"op": "remove", "key": key}])

        def g(lines):
            i, _ = niri_find(lines, key)
            if i is None:
                return "That key isn't in the keybinds file"
            del lines[i]
            return lines
        niri_edit(g)
    if cmd == "add":
        key, action = a[1], json.loads(a[2])
        pk = parse_key(key)
        if not pk or not pk[1]:
            out({"ok": False, "error": "That isn't a key"})
        other = holder(key)
        gone = [{"op": "remove", "key": other["key"]}] if other else []
        if HYPR:
            _, _, lua = hypr_paths()
            d = hypr_action(action, lua)
            if not d:
                out({"ok": False, "error": "Pick what it does"})
            entry = {"op": "add", "key": key, "lua": 'hl.bind("%s", %s)' % (hypr_key(*pk), d),
                     "conf": "bind = %s, %s, %s" % (" ".join(m.upper() for m in pk[0]), HYPR_KEY.get(pk[1], pk[1]), d)}
            hypr_change(gone + [entry])
        d = niri_action(action)
        if not d:
            out({"ok": False, "error": "Pick what it does"})

        def g(lines):
            if other:
                j, _ = niri_find(lines, other["key"])
                if j is not None:
                    del lines[j]
            line = "    %s { %s; }" % (niri_key(*pk), d)
            head = "    // ── Added in Settings " + "─" * 41
            if head in lines:
                j = lines.index(head) + 1
                while j < len(lines) and lines[j].strip() and not lines[j].strip().startswith("}"):
                    j += 1
                lines.insert(j, line)
                return lines
            # the end of the binds block
            depth, end = 0, None
            for i, l in enumerate(lines):
                if re.match(r"^\s*binds\s*\{", l):
                    depth = 1
                    continue
                if depth:
                    depth += l.count("{") - l.count("}")
                    if depth <= 0:
                        end = i
                        break
            if end is None:
                return "No binds block in the keybinds file"
            lines[end:end] = ["", head, line]
            return lines
        niri_edit(g)
    out({"ok": False, "error": "unknown command"})


if __name__ == "__main__":
    main()
