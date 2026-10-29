#!/usr/bin/env python3
"""Peripherals (Settings -> Peripherals -> Mouse / Keyboard): niri's input { } section.

  peripherals.py list                     JSON: the mouse, touchpad and keyboard settings, the
                                          connected devices and every keyboard layout xkb knows
  peripherals.py set <section> <key> <v>  change one setting and print the new list
      mouse     speed <-1..1> | flat on|off | natural on|off | lefthanded on|off |
                middle on|off | scroll <factor>
      touchpad  speed <-1..1> | tap on|off | natural on|off | dwt on|off
      keyboard  delay <ms> | rate <per second> | numlock on|off |
                shortcut <grp option, e.g. alt_shift_toggle, or none> | layouts <us,gr,...>

niri reloads its config by itself, so a change works straight away. Only the lines being
changed are touched; comments and everything else in the file stay. A config niri can't read
is put back the way it was.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
NIRI_DIR = os.path.join(CONF, "niri")
MAIN = os.path.join(NIRI_DIR, "config.kdl")
XKB_RULES = "/usr/share/X11/xkb/rules/evdev.lst"

# the layout-switch shortcuts offered (xkb grp: options), in menu order
SHORTCUTS = [
    ("alt_shift_toggle", "Alt+Shift"),
    ("win_space_toggle", "Super+Space"),
    ("ctrl_shift_toggle", "Ctrl+Shift"),
    ("caps_toggle", "Caps Lock"),
    ("lalt_toggle", "Left Alt"),
    ("none", "None"),
]

# libinput's own defaults, what niri uses when a line is missing
DEFAULTS = {"speed": 0.0, "scroll": 1.0, "delay": 600, "rate": 25}


# ---- finding blocks in niri's config ------------------------------------------------------------

def niri_files():
    files = sorted(glob.glob(os.path.join(NIRI_DIR, "**", "*.kdl"), recursive=True))
    # the main config first, then its includes (config/input.kdl...)
    return sorted(files, key=lambda f: f != MAIN)


def braces(text):
    """(position, "{" or "}") for every brace outside strings and comments"""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        elif c in "{}":
            out.append((i, c))
        i += 1
    return out


def child_blocks(text, start, end):
    """{name: (open brace, close brace)} for the blocks directly inside text[start:end]"""
    found = {}
    depth = 0
    for pos, c in braces(text):
        if pos < start or pos >= end:
            continue
        if c == "{":
            if depth == 0:
                line_start = text.rfind("\n", 0, pos) + 1
                m = re.match(r"\s*([A-Za-z][\w-]*)\b[^\n{]*$", text[line_start:pos])
                open_at, name = pos, (m.group(1) if m else None)
            depth += 1
        else:
            depth -= 1
            if depth == 0 and name and name not in found:
                found[name] = (open_at, pos)
    return found


def find_block(text, path):
    """(open brace, close brace) of e.g. input > mouse, or None"""
    start, end = 0, len(text)
    span = None
    for name in path:
        span = child_blocks(text, start, end).get(name)
        if span is None:
            return None
        start, end = span[0] + 1, span[1]
    return span


def input_file():
    """the file holding niri's input { } section (config/input.kdl in Monolith's setup)"""
    for f in niri_files():
        try:
            text = open(f, encoding="utf-8").read()
        except OSError:
            continue
        if find_block(text, ["input"]):
            return f
    return MAIN if os.path.exists(MAIN) else None


def block_lines(text, span):
    """the plain settings lines directly in a block: [(start, end, key, value)]"""
    out = []
    if span is None:
        return out
    body_start, body_end = span[0] + 1, span[1]
    nested = [(a, b) for a, b in child_blocks(text, body_start, body_end).values()]
    pos = body_start
    for line in text[body_start:body_end].split("\n"):
        line_end = pos + len(line)
        inside = any(a < pos <= b for a, b in nested)
        bare = line.split("//")[0].strip() if '"' not in line else line.strip()
        m = re.match(r"([A-Za-z][\w-]*)(?:\s+(.*?))?\s*(?://.*)?$", bare)
        if m and not inside and "{" not in bare and "}" not in bare:
            out.append((pos, line_end, m.group(1), (m.group(2) or "").strip()))
        pos = line_end + 1
    return out


def read_block(text, path):
    span = find_block(text, path)
    return {k: v for _, _, k, v in block_lines(text, span)}


def unquote(v):
    v = v.strip()
    return v[1:-1] if len(v) >= 2 and v[0] == v[-1] == '"' else v


def indent_of(text, pos):
    line_start = text.rfind("\n", 0, pos) + 1
    return re.match(r"[ \t]*", text[line_start:]).group(0)


def ensure_block(text, path):
    """make sure the block exists (adding the missing ones at the end of their parent)"""
    for depth in range(1, len(path) + 1):
        if find_block(text, path[:depth]):
            continue
        parent = find_block(text, path[:depth - 1]) if depth > 1 else None
        name = path[depth - 1]
        if parent is None:
            text = text.rstrip("\n") + f"\n\n{name} {{\n}}\n"
        else:
            ind = indent_of(text, parent[0]) + "    "
            close = parent[1]
            line_start = text.rfind("\n", 0, close) + 1
            text = text[:line_start] + f"{ind}{name} {{\n{ind}}}\n" + text[line_start:]
    return text


def set_line(text, path, key, value):
    """value None removes the line, "" writes the bare flag, anything else `key value`"""
    text = ensure_block(text, path) if value is not None else text
    span = find_block(text, path)
    if span is None:
        return text
    lines = [l for l in block_lines(text, span) if l[2] == key]
    if value is None:
        for start, end, _, _ in reversed(lines):
            text = text[:start] + text[end + 1:]
        return text
    new = key if value == "" else f"{key} {value}"
    if lines:
        start, end, _, _ = lines[0]
        return text[:start] + indent_of(text, start) + new + text[end:]
    # a new line, right after the block's opening brace
    ind = indent_of(text, span[0]) + "    "
    nl = text.find("\n", span[0])
    if nl < 0 or nl > span[1]:
        # `mouse { }` on one line: open it up
        close_ind = indent_of(text, span[0])
        return text[:span[0] + 1] + f"\n{ind}{new}\n{close_ind}" + text[span[1]:]
    return text[:nl + 1] + f"{ind}{new}\n" + text[nl + 1:]


def write_checked(f, old, new):
    if new == old:
        return
    with open(f, "r+", encoding="utf-8") as fh:
        fh.write(new)
        fh.truncate()
    if shutil.which("niri") and os.path.exists(MAIN):
        r = subprocess.run(["niri", "validate", "-c", MAIN], capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            with open(f, "r+", encoding="utf-8") as fh:
                fh.write(old)
                fh.truncate()
            sys.exit("niri didn't accept that: " + (r.stderr.strip().splitlines() or ["?"])[-1])


# ---- connected devices --------------------------------------------------------------------------

def tidy_name(name):
    # "Wooting Wooting 80HE" -> "Wooting 80HE"
    words = name.split()
    if len(words) >= 2 and words[0].lower() == words[1].lower():
        words = words[1:]
    return " ".join(words)


def devices():
    kinds = {"mice": [], "keyboards": [], "touchpads": [], "controllers": []}
    if not shutil.which("udevadm"):
        return kinds
    found = []
    for ev in sorted(glob.glob("/sys/class/input/event*")):
        try:
            name = open(os.path.join(ev, "device", "name"), encoding="utf-8").read().strip()
            props = subprocess.run(["udevadm", "info", "-q", "property", "-p", ev],
                                   capture_output=True, text=True, timeout=3).stdout
        except (OSError, subprocess.SubprocessError):
            continue
        p = dict(l.split("=", 1) for l in props.splitlines() if "=" in l)
        if p.get("ID_INPUT_TOUCHPAD") == "1":
            kind = "touchpads"
        elif p.get("ID_INPUT_JOYSTICK") == "1":
            kind = "controllers"
        elif p.get("ID_INPUT_MOUSE") == "1":
            kind = "mice"
        elif p.get("ID_INPUT_KEYBOARD") == "1":
            kind = "keyboards"
        else:
            continue
        found.append((kind, tidy_name(name)))
    names = {n for _, n in found}
    for kind, name in found:
        # a keyboard's extra "Mouse" / "Consumer Control" parts aren't devices of their own
        base = re.sub(r"\s+(Mouse|Keyboard|Consumer Control|System Control|Keypad)$", "", name)
        if base != name and base in names:
            continue
        if name not in kinds[kind]:
            kinds[kind].append(name)
    return kinds


def all_layouts():
    out = []
    try:
        lines = open(XKB_RULES, encoding="utf-8").read().splitlines()
    except OSError:
        return out
    inside = False
    for l in lines:
        if l.startswith("!"):
            inside = l.strip() == "! layout"
            continue
        if inside and l.strip():
            parts = l.split(None, 1)
            out.append({"id": parts[0], "name": parts[1].strip() if len(parts) > 1 else parts[0]})
    return sorted(out, key=lambda x: x["name"].lower())


# ---- reading and changing -----------------------------------------------------------------------

def num(v, default):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def state():
    f = input_file()
    text = open(f, encoding="utf-8").read() if f else ""
    mouse = read_block(text, ["input", "mouse"])
    pad = read_block(text, ["input", "touchpad"])
    kb = read_block(text, ["input", "keyboard"])
    xkb = read_block(text, ["input", "keyboard", "xkb"])
    options = [o for o in unquote(xkb.get("options", "")).split(",") if o]
    grp = next((o[4:] for o in options if o.startswith("grp:")), "none")
    layouts = [l for l in unquote(xkb.get("layout", "")).split(",") if l]
    devs = devices()
    return {
        "file": f or "",
        "devices": devs,
        "mouse": {
            "speed": num(mouse.get("accel-speed"), DEFAULTS["speed"]),
            "flat": unquote(mouse.get("accel-profile", "")) == "flat",
            "natural": "natural-scroll" in mouse,
            "lefthanded": "left-handed" in mouse,
            "middle": "middle-emulation" in mouse,
            "scroll": num(mouse.get("scroll-factor"), DEFAULTS["scroll"]),
        },
        "touchpad": {
            "speed": num(pad.get("accel-speed"), DEFAULTS["speed"]),
            "tap": "tap" in pad,
            "natural": "natural-scroll" in pad,
            "dwt": "dwt" in pad,
        },
        "keyboard": {
            "layouts": layouts or ["us"],
            "shortcut": grp,
            "delay": int(num(kb.get("repeat-delay"), DEFAULTS["delay"])),
            "rate": int(num(kb.get("repeat-rate"), DEFAULTS["rate"])),
            "numlock": "numlock" in kb,
        },
        "shortcuts": [{"id": i, "name": n} for i, n in SHORTCUTS],
        "allLayouts": all_layouts(),
    }


def on(v):
    if v not in ("on", "off"):
        sys.exit("expected on or off")
    return v == "on"


def clamp(v, lo, hi, as_int=False):
    try:
        x = float(v)
    except ValueError:
        sys.exit(f"not a number: {v}")
    x = max(lo, min(hi, x))
    # niri wants a decimal point on the fractional ones (accel-speed 0.0, not 0)
    return str(int(round(x))) if as_int else f"{x:.2f}"


def cmd_set(section, key, value):
    f = input_file()
    if f is None:
        sys.exit("couldn't find niri's config")
    old = open(f, encoding="utf-8").read()
    text = old
    flag = lambda v: "" if on(v) else None
    if section == "mouse" or section == "touchpad":
        path = ["input", section]
        if key == "speed":
            text = set_line(text, path, "accel-speed", clamp(value, -1, 1))
        elif section == "mouse" and key == "flat":
            text = set_line(text, path, "accel-profile", '"flat"' if on(value) else None)
        elif key == "natural":
            text = set_line(text, path, "natural-scroll", flag(value))
        elif section == "mouse" and key == "lefthanded":
            text = set_line(text, path, "left-handed", flag(value))
        elif section == "mouse" and key == "middle":
            text = set_line(text, path, "middle-emulation", flag(value))
        elif section == "mouse" and key == "scroll":
            text = set_line(text, path, "scroll-factor", clamp(value, 0.1, 5))
        elif section == "touchpad" and key in ("tap", "dwt"):
            text = set_line(text, path, key, flag(value))
        else:
            sys.exit(f"unknown {section} setting: {key}")
    elif section == "keyboard":
        path = ["input", "keyboard"]
        if key == "delay":
            text = set_line(text, path, "repeat-delay", clamp(value, 100, 2000, True))
        elif key == "rate":
            text = set_line(text, path, "repeat-rate", clamp(value, 1, 100, True))
        elif key == "numlock":
            text = set_line(text, path, "numlock", flag(value))
        elif key == "shortcut":
            ids = [i for i, _ in SHORTCUTS]
            if value not in ids:
                sys.exit(f"unknown shortcut: {value}")
            xkb = read_block(text, path + ["xkb"])
            # keep any other xkb options (caps:escape...), swap only the grp: one
            opts = [o for o in unquote(xkb.get("options", "")).split(",") if o and not o.startswith("grp:")]
            if value != "none":
                opts.insert(0, "grp:" + value)
            text = set_line(text, path + ["xkb"], "options", f'"{",".join(opts)}"' if opts else None)
        elif key == "layouts":
            known = {l["id"] for l in all_layouts()}
            new = [l for l in value.split(",") if l]
            if not new:
                sys.exit("keep at least one layout")
            bad = [l for l in new if known and l not in known]
            if bad:
                sys.exit("unknown layout: " + ", ".join(bad))
            xkb = read_block(text, path + ["xkb"])
            old_layouts = [l for l in unquote(xkb.get("layout", "")).split(",") if l]
            # variants line up with layouts by position: carry each one along with its layout
            variants = unquote(xkb.get("variant", "")).split(",") if "variant" in xkb else None
            text = set_line(text, path + ["xkb"], "layout", f'"{",".join(new)}"')
            if variants is not None:
                by_layout = {l: (variants[i] if i < len(variants) else "") for i, l in enumerate(old_layouts)}
                vs = [by_layout.get(l, "") for l in new]
                text = set_line(text, path + ["xkb"], "variant", f'"{",".join(vs)}"' if any(vs) else None)
        else:
            sys.exit(f"unknown keyboard setting: {key}")
    else:
        sys.exit(f"unknown section: {section}")
    write_checked(f, old, text)
    print(json.dumps(state()))


def main():
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        print(json.dumps(state()))
    elif a[:1] == ["set"] and len(a) == 4:
        cmd_set(a[1], a[2], a[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
