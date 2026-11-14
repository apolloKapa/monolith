#!/usr/bin/env python3
"""Monolith's own files in Hyprland's config: one folder, ~/.config/hypr/monolith/, each part in
a file named for what it holds, all loaded by monolith/init.lua (init.conf for a classic
hyprland.conf), which your main config includes with one line.

    start       Monolith starting at login, and its environment     (rewritten on updates)
    keybinds    the keys, in sections                                (rewritten on updates)
    workspaces  Settings -> Windows -> Workspaces per screen         (rewritten by Settings)
    borders     Settings -> Windows -> window borders                (rewritten by Settings)
    cursor      Settings -> Appearance -> Cursor                     (rewritten by Settings)
    animations  Settings -> Animations -> Workspace switching        (rewritten by Settings)
    my-keys     YOUR keys: never changed by Monolith; a key you set here wins (Monolith leaves
                that key out of its own)

    hypr_files.py write NAME     the part NAME from stdin (then init and the include are made sure of)
    hypr_files.py path NAME      where NAME is
    hypr_files.py migrate        older setups (monolith.lua, monolith-*.lua beside your config) moved in
    hypr_files.py remove         Monolith's folder and its include line taken out again
    hypr_files.py kind           lua or conf
"""
import os
import re
import sys

CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
HYPR = os.path.join(CONF, "hypr")
FOLDER = os.path.join(HYPR, "monolith")
ORDER = ["start", "monitors", "keybinds", "workspaces", "borders", "cursor", "animations", "my-keys"]
HEADERS = {
    "start": "Monolith starting at login, and its environment. Rewritten on every update.",
    "keybinds": "Monolith's keys, in sections. Rewritten on every update: put keys of your own in my-keys.",
    "workspaces": "Workspaces per screen (Settings -> Windows). Rewritten by Settings.",
    "borders": "Window borders (Settings -> Windows). Rewritten by Settings.",
    "cursor": "The cursor (Settings -> Appearance). Rewritten by Settings.",
    "animations": "Switching workspaces (Settings -> Appearance). Rewritten by Settings.",
    "monitors": "Screens (Settings -> Displays). Rewritten by Settings.",
}


def kind():
    return "lua" if os.path.exists(os.path.join(HYPR, "hyprland.lua")) or not os.path.exists(os.path.join(HYPR, "hyprland.conf")) else "conf"


def ext():
    return "." + kind()


def path(name):
    return os.path.join(FOLDER, name + ext())


def comment():
    return "--" if kind() == "lua" else "#"


def main_config():
    return os.path.join(HYPR, "hyprland" + ext())


def include_line():
    return 'require("monolith/init")' if kind() == "lua" else "source = " + os.path.join(FOLDER, "init.conf")


def atomic(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".part"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, p)


MY_KEYS_LUA = """-- Your own keys: Monolith never changes this file, and a key you set here wins: Monolith
-- leaves that key out of its own (monolith/keybinds.lua). Hyprland applies changes when you save.
--
-- A key is one line:   hl.bind("KEYS", WHAT IT DOES)
--   KEYS: SUPER, SHIFT, CTRL, ALT, then the key, joined with " + "     e.g. "SUPER + SHIFT + Return"
--   WHAT IT DOES:
--     run a program       hl.dsp.exec_cmd("firefox")
--     close the window    hl.dsp.window.close()
--     fullscreen          hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })
--     a workspace         hl.dsp.focus({ workspace = 3 })
--
-- Examples (take the -- away to use one):
-- hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
-- hl.bind("SUPER + C", hl.dsp.window.close())
-- hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("firefox --private-window"))
"""

MY_KEYS_CONF = """# Your own keys: Monolith never changes this file, and a key you set here wins: Monolith
# leaves that key out of its own (monolith/keybinds.conf). Hyprland applies changes when you save.
#
# A key is one line:   bind = MODIFIERS, KEY, WHAT, ARGUMENTS
#   MODIFIERS: SUPER, SHIFT, CTRL, ALT (with spaces between)
#   run a program       bind = SUPER, Q, exec, kitty
#   close the window    bind = SUPER, C, killactive,
#   fullscreen          bind = SUPER, F, fullscreen, 0
#   a workspace         bind = SUPER, 3, workspace, 3
#
# Examples (take the # away to use one):
# bind = SUPER, Q, exec, kitty
# bind = SUPER, C, killactive,
"""


def rebuild():
    """init (loading the parts there are, in order), my-keys made once, the include made sure of."""
    os.makedirs(FOLDER, exist_ok=True)
    if not os.path.exists(path("my-keys")):
        atomic(path("my-keys"), MY_KEYS_LUA if kind() == "lua" else MY_KEYS_CONF)
    c = comment()
    lines = [c + " Monolith's files, loaded in this order (written by Monolith: changes here are replaced).",
             c + " Your own keys go in my-keys, which Monolith never changes."]
    for n in ORDER:
        if os.path.exists(path(n)):
            lines.append('require("monolith/%s")' % n if kind() == "lua" else "source = " + path(n))
    atomic(os.path.join(FOLDER, "init" + ext()), "\n".join(lines) + "\n")
    main = main_config()
    try:
        text = open(main, encoding="utf-8").read()
    except OSError:
        return
    if include_line() not in text.splitlines():
        atomic(main, text + ("" if text.endswith("\n") else "\n") + "\n" + include_line() + "\n")


def write(name, body):
    head = HEADERS.get(name)
    text = body if not head or body.startswith(comment() + " monolith ") or body.startswith(comment() + " " + head[:20]) \
        else comment() + " " + head + "\n" + body
    atomic(path(name), text if text.endswith("\n") else text + "\n")
    rebuild()


def migrate():
    """An older setup's files beside your config (monolith.lua and monolith-workspaces/borders/
    cursor) moved into the folder, and their include lines swapped for the folder's one."""
    e = ext()
    moved = False
    for old, new in (("monolith-workspaces", "workspaces"), ("monolith-borders", "borders"), ("monolith-cursor", "cursor")):
        p = os.path.join(HYPR, old + e)
        if os.path.exists(p):
            os.makedirs(FOLDER, exist_ok=True)
            os.replace(p, path(new))
            moved = True
    oldmain = os.path.join(HYPR, "monolith" + e)
    if os.path.exists(oldmain):
        # (start and keys are written again by the installer; the old keys choice is kept in the
        # new keybinds file so the update keeps it)
        m = re.search(r"^[#-]+ keys: (\w+)$", open(oldmain, encoding="utf-8").read(), re.M)
        if m and not os.path.exists(path("keybinds")):
            atomic(path("keybinds"), comment() + " keys: " + m.group(1) + "\n")
        os.remove(oldmain)
        moved = True
    main = main_config()
    if os.path.exists(main):
        text = open(main, encoding="utf-8").read()
        olds = ['require("monolith")', 'require("monolith-workspaces")', 'require("monolith-borders")', 'require("monolith-cursor")'] \
            if kind() == "lua" else ["source = " + os.path.join(HYPR, n + ".conf") for n in ("monolith", "monolith-workspaces", "monolith-borders", "monolith-cursor")]
        new = "\n".join(l for l in text.split("\n") if l.strip() not in olds)
        if new != text:
            atomic(main, new)
            moved = True
    if moved or os.path.isdir(FOLDER):
        rebuild()
    return moved


def remove():
    import shutil
    main = main_config()
    if os.path.exists(main):
        text = open(main, encoding="utf-8").read()
        atomic(main, "\n".join(l for l in text.split("\n") if l.strip() != include_line()))
    shutil.rmtree(FOLDER, ignore_errors=True)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "write":
        write(sys.argv[2], sys.stdin.read())
    elif cmd == "path":
        print(path(sys.argv[2]))
    elif cmd == "migrate":
        migrate()
    elif cmd == "remove":
        remove()
    elif cmd == "kind":
        print(kind())
    else:
        sys.exit(__doc__)
