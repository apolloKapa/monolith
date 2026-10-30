#!/usr/bin/env python3
"""Lists niri's keybinds as JSON for the keybind cheatsheet (monolith msg toggle cheatsheet).

Reads ~/.config/niri/config.kdl and everything it includes, finds the binds { } blocks and
prints [{"keys": [...], "desc": "...", "group": "...", "action": "..."}]. A bind's
hotkey-overlay-title, when it has one, is used as its description.
"""
import json
import os
import re
import shlex
import sys

CONF_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "niri")


def read_config(path, seen):
    path = os.path.realpath(path)
    if path in seen or not os.path.isfile(path):
        return ""
    seen.add(path)
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r'\s*include\s+"([^"]+)"', line)
        if m:
            out.append(read_config(os.path.join(os.path.dirname(path), m.group(1)), seen))
        else:
            out.append(line)
    return "".join(out)


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?m)//.*$", "", text)


def bind_blocks(text):
    for m in re.finditer(r"(?m)^\s*binds\s*\{", text):
        depth, i = 1, m.end()
        while depth and i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        yield text[m.end():i - 1]


KEY_NAMES = {
    "Mod": "Super", "Slash": "/", "Comma": ",", "Period": ".", "Minus": "-", "Equal": "=",
    "BracketLeft": "[", "BracketRight": "]", "Semicolon": ";", "Apostrophe": "'", "Grave": "`",
    "Backslash": "\\", "Return": "Enter", "Escape": "Esc", "Print": "PrtSc", "Page_Up": "PgUp",
    "Page_Down": "PgDn", "WheelScrollDown": "Scroll ↓", "WheelScrollUp": "Scroll ↑",
    "WheelScrollLeft": "Scroll ←", "WheelScrollRight": "Scroll →", "Left": "←", "Right": "→",
    "Up": "↑", "Down": "↓", "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
    "XF86AudioStop": "Stop", "XF86AudioPrev": "Prev track", "XF86AudioNext": "Next track",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic mute", "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −",
}


MEDIA_KEYS = {
    "XF86AudioPlay": "Play / pause", "XF86AudioPause": "Pause", "XF86AudioStop": "Stop",
    "XF86AudioPrev": "Previous track", "XF86AudioNext": "Next track", "XF86AudioMute": "Mute",
    "XF86AudioRaiseVolume": "Volume up", "XF86AudioLowerVolume": "Volume down",
    "XF86AudioMicMute": "Microphone mute", "XF86MonBrightnessUp": "Brightness up",
    "XF86MonBrightnessDown": "Brightness down",
}


def pretty_keys(combo):
    return [KEY_NAMES.get(k, k) for k in combo.split("+")]


def humanize(action):
    return action.replace("-", " ").capitalize()


PANELS = {
    "launcher": "App launcher", "system": "System panel", "settings": "Settings", "guide": "Settings",
    "clipboard": "Clipboard history", "wallpaper": "Wallpaper picker", "network": "Network",
    "volume": "Volume mixer", "music": "Media player", "calendar": "Calendar", "notifications": "Notifications",
    "session": "Session menu", "overview": "Workspace overview", "dashboard": "Dashboard",
    "cheatsheet": "Keybind cheatsheet", "switcher": "Window switcher", "autohide": "Bar auto-hide",
}


def monolith_command(words):
    cmd = words[0] if words else ""
    flags = set(words[1:])
    if cmd == "screenshot":
        what = "whole screen" if "--full" in flags else "region"
        return "group:Screenshots", "Screenshot " + what + (", then edit" if "--edit" in flags else "")
    if cmd == "lock":
        return "group:System", "Lock screen"
    if cmd in ("volume", "brightness"):
        how = {"raise": "up", "lower": "down", "mute-toggle": "mute", "mic-toggle": "mic mute"}.get(words[1] if len(words) > 1 else "", " ".join(words[1:]))
        return "group:Media", cmd.capitalize() + " " + how
    if cmd in ("toggle", "open", "close") and len(words) > 1:
        return "group:Monolith", PANELS.get(words[1], words[1].capitalize())
    return "group:Monolith", "Monolith: " + " ".join(words)


def describe(action, args):
    if action == "spawn-sh" and args:
        line = args[0]
        acts = re.findall(r"niri msg action ([a-z-]+)", line)
        if acts:
            return "group:" + group_for(acts[-1]), humanize(acts[-1])
        if "cliphist" in line:
            return "group:Apps", "Clipboard history (rofi)"
        # "pgrep -x app || app ...": it's about the app
        progs = [w for w in re.split(r"[|;&]+", line) if w.strip()]
        words = shlex.split(progs[-1]) if progs else []
        if words and os.path.basename(words[0]) in ("pgrep", "sh", "bash", "test", "["):
            words = words[1:]
        return describe("spawn", words)
    if action == "spawn":
        words = args
        if words and os.path.basename(words[0]) == "monolith":
            return monolith_command([w for w in words[1:] if w != "msg"])
        prog = os.path.basename(words[0]) if words else "command"
        if prog in ("playerctl", "wpctl", "pamixer", "brightnessctl"):
            return "group:Media", " ".join(words[:3])
        if prog in ("grim", "slurp", "swappy"):
            return "group:Screenshots", "Screenshot (" + prog + ")"
        return "group:Apps", "Open " + prog
    return None, humanize(action)


def group_for(action):
    a = action
    if "workspace" in a:
        return "Workspaces"
    if "monitor" in a:
        return "Monitors"
    if a.startswith("screenshot"):
        return "Screenshots"
    if any(x in a for x in ("column", "window", "fullscreen", "floating", "maximize", "width", "height", "consume", "expel", "tab")):
        return "Windows"
    if a in ("quit", "power-off-monitors", "suspend", "toggle-keyboard-shortcuts-inhibit"):
        return "System"
    return "Niri"


def parse(block):
    binds = []
    for m in re.finditer(r'(?m)^\s*([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:"[^"]*"|\S+))*)\s*\{([^{}]*)\}', block):
        combo, props, body = m.group(1), m.group(2), m.group(3).strip().rstrip(";").strip()
        title = re.search(r'hotkey-overlay-title="([^"]*)"', props)
        try:
            parts = shlex.split(body)
        except ValueError:
            parts = body.split()
        if not parts:
            continue
        action, args = parts[0], parts[1:]
        group, desc = describe(action, args)
        group = group[len("group:"):] if group else group_for(action)
        if combo.startswith("XF86"):
            group = "Media"
            desc = MEDIA_KEYS.get(combo, desc)
        if action == "quit":
            desc = "Log out (quit niri)"
        if title and title.group(1):
            desc = title.group(1)
        binds.append({"keys": pretty_keys(combo), "desc": desc, "group": group, "action": body})
    return binds


def main():
    conf = os.path.join(CONF_DIR, "config.kdl")
    text = strip_comments(read_config(conf, set()))
    binds = [b for block in bind_blocks(text) for b in parse(block)]
    order = ["Apps", "Monolith", "Windows", "Workspaces", "Monitors", "Screenshots", "Media", "System", "Niri"]
    binds.sort(key=lambda b: (order.index(b["group"]) if b["group"] in order else 99))
    json.dump(binds, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
