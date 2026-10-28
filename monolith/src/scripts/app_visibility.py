#!/usr/bin/env python3
"""Show or hide apps (Settings -> Launcher -> Apps): what the launcher, dock and app menus list.

  app_visibility.py list          JSON: every installed app, with whether it's hidden
  app_visibility.py hide <id>     hide it everywhere
  app_visibility.py show <id>     show it again

<id> is the desktop file id (firefox, org.kde.dolphin...). Hiding is the standard NoDisplay=true:
for an app installed elsewhere, a copy of its .desktop file in ~/.local/share/applications (which
menus read first) with that line added; for an entry that's already yours, the line goes into it.
Showing undoes exactly that: the copy is deleted, or the line comes out again. Apps hidden by
their own package (helpers that were never meant to be listed) aren't listed.
"""
import configparser
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
APPS_HOME = os.path.join(DATA, "applications")
MARK = "X-Monolith-Hidden"   # "copy": a copy made to hide it; "line": NoDisplay added to your own file


def app_dirs():
    dirs = [os.path.join(d, "applications") for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
    for extra in (os.path.join(DATA, "flatpak/exports/share/applications"), "/var/lib/flatpak/exports/share/applications"):
        if extra not in dirs:
            dirs.append(extra)
    return [APPS_HOME] + dirs


def desktop_files():
    """id -> [paths, the one menus use first]"""
    found = {}
    for base in app_dirs():
        for root, _, files in os.walk(base):
            for f in files:
                if f.endswith(".desktop"):
                    path = os.path.join(root, f)
                    did = os.path.relpath(path, base)[:-len(".desktop")].replace(os.sep, "-")
                    found.setdefault(did, []).append(path)
    return found


def read(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        return {}
    return dict(cp["Desktop Entry"]) if cp.has_section("Desktop Entry") else {}


def is_true(v):
    return str(v).strip().lower() == "true"


def section_bounds(text):
    m = re.search(r"(?ms)^\[Desktop Entry\]\s*$(.*?)(?=^\[|\Z)", text)
    return (m.start(1), m.end(1)) if m else None


def set_key(text, key, value):
    """set (or with value None, remove) one key in [Desktop Entry]"""
    b = section_bounds(text)
    if b is None:
        return text
    body = text[b[0]:b[1]]
    rx = re.compile(rf"(?m)^{re.escape(key)}\s*=.*\n?")
    if value is None:
        body = rx.sub("", body)
    elif rx.search(body):
        body = rx.sub(lambda _: f"{key}={value}\n", body, count=1)
    else:
        body = body.rstrip("\n") + f"\n{key}={value}\n" + ("\n" if body.endswith("\n\n") else "")
    return text[:b[0]] + body + text[b[1]:]


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def refresh_db():
    try:
        subprocess.run(["update-desktop-database", APPS_HOME], capture_output=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        pass


def state(did, paths):
    """None for entries that aren't apps to list, else (entry, hidden, how it's hidden)"""
    top = read(paths[0])
    if not top or top.get("Type", "Application") != "Application" or is_true(top.get("Hidden", "")):
        return None
    mine = paths[0].startswith(APPS_HOME + os.sep)
    if not is_true(top.get("NoDisplay", "")):
        return top, False, ""
    how = top.get(MARK, "")
    if how:
        return top, True, how
    # hidden by a copy of yours over an entry that is shown (made by hand, like the Java tools)
    if mine and len(paths) > 1 and not is_true(read(paths[1]).get("NoDisplay", "")):
        return top, True, "copy"
    return None   # hidden by its own package: a helper, not an app to list


def cmd_list():
    out = []
    for did, paths in desktop_files().items():
        s = state(did, paths)
        if s is None:
            continue
        e, hidden, how = s
        out.append({"id": did, "name": e.get("Name", did), "icon": e.get("Icon", ""),
                    "comment": e.get("Comment", "") or e.get("GenericName", ""), "hidden": hidden,
                    "flatpak": "flatpak" in paths[0] or "flatpak run" in e.get("Exec", "")})
    out.sort(key=lambda a: a["name"].lower())
    print(json.dumps(out))


def cmd_hide(did):
    paths = desktop_files().get(did)
    if not paths:
        sys.exit(f"no app called {did}")
    src = paths[0]
    text = open(src, encoding="utf-8").read()
    target = os.path.join(APPS_HOME, did + ".desktop")
    if os.path.abspath(src) == os.path.abspath(target):
        how = read(src).get(MARK) or "line"
    else:
        how = "copy"
    text = set_key(text, "NoDisplay", "true")
    text = set_key(text, MARK, how)
    write(target, text)
    refresh_db()
    print(json.dumps({"hidden": did}))


def cmd_show(did):
    paths = desktop_files().get(did)
    if not paths:
        sys.exit(f"no app called {did}")
    target = os.path.join(APPS_HOME, did + ".desktop")
    top = read(paths[0])
    how = top.get(MARK, "")
    if os.path.abspath(paths[0]) == os.path.abspath(target) and how == "copy":
        os.remove(target)      # the copy only existed to hide it
    # anything else (your own entry, or one hidden by hand): only the line comes out
    else:
        text = open(paths[0], encoding="utf-8").read()
        text = set_key(text, "NoDisplay", None)
        text = set_key(text, MARK, None)
        write(target, text)
    refresh_db()
    print(json.dumps({"shown": did}))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        cmd_list()
    elif a[:1] == ["hide"] and len(a) >= 2:
        cmd_hide(a[1])
    elif a[:1] == ["show"] and len(a) >= 2:
        cmd_show(a[1])
    else:
        sys.exit(__doc__)
