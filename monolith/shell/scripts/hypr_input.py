#!/usr/bin/env python3
"""Keyboard and mouse on Hyprland (Settings -> Devices -> Keyboard & mouse).

    hypr_input.py read                        JSON: {"scroll_factor": N, "kb_layout": "us,gr", "kb_variant": "",
                                              "kb_options": "grp:alt_shift_toggle"} (what Hyprland uses now)
    hypr_input.py set KEY VALUE [KEY VALUE…]  scroll_factor (the mouse's scroll speed, 1 = normal), kb_layout (the
                                              keyboard's languages, "us,gr"), kb_variant, kb_options; several
                                              in one go are written together

Kept in Monolith's folder, ~/.config/hypr/monolith/input.lua (or .conf), loaded after your own
config, so it wins. The settings are kept as JSON on its first line. Hyprland reloads it by itself
(a new file once by `hyprctl reload`: it only watches files it has read).
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_files as hf  # noqa: E402

KEYS = {"scroll_factor": (0.1, 5.0)}
# text settings, and what each may hold (they go into the config as written)
TEXT = {"kb_layout": r"[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*", "kb_variant": r"[A-Za-z0-9_,-]*", "kb_options": r"[A-Za-z0-9_:,+-]*"}


def saved():
    try:
        first = open(hf.path("input"), encoding="utf-8").readline()
        return json.loads(first.split(" monolith ", 1)[1])
    except (OSError, IndexError, ValueError):
        return {}


def live(key):
    try:
        r = subprocess.run(["hyprctl", "getoption", "input:" + key, "-j"], capture_output=True, text=True, timeout=5)
        if key in TEXT:
            v = str(json.loads(r.stdout).get("str") or "")
            return "" if v == "[[EMPTY]]" else v
        return float(json.loads(r.stdout).get("float"))
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return None


def write(state):
    lua = hf.kind() == "lua"
    c = "--" if lua else "#"
    out = [c + " monolith " + json.dumps(state, separators=(",", ":")),
           c + " Written by Monolith (Settings -> Devices). Changes here are replaced."]
    if lua:
        out += ["hl.config({ input = {"] + ["  %s = %s," % (k, json.dumps(v) if k in TEXT else v) for k, v in sorted(state.items())] + ["} })"]
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
        for k in list(KEYS) + list(TEXT):
            v = saved().get(k)
            out[k] = v if v is not None else live(k)
        print(json.dumps(out))
        return
    pairs = list(zip(a[1::2], a[2::2]))
    if a[0] == "set" and pairs and len(a) % 2 == 1 and all(k in KEYS or k in TEXT for k, _ in pairs):
        state = saved()
        for k, text in pairs:
            if k in TEXT:
                if not re.fullmatch(TEXT[k], text):
                    print(json.dumps({"ok": False, "error": "Not a %s: %s" % (k, text)}))
                    return
                state[k] = text
                continue
            lo, hi = KEYS[k]
            try:
                state[k] = round(min(hi, max(lo, float(text))), 2)
            except ValueError:
                print(json.dumps({"ok": False, "error": "Not a number: " + text}))
                return
        write(state)
        print(json.dumps({"ok": True}))
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main()
