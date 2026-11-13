#!/usr/bin/env python3
"""AppImages: drop one on the AppImages window and it's set up like an installed app.

  appimages.py list FOLDER                JSON: every AppImage in FOLDER and every one an app
                                          entry runs, with its name, icon and whether it has one
  appimages.py add FOLDER FILE [--keep]   set one up: moved into FOLDER (--keep: left where it
                                          is), made runnable, and given an app entry with the
                                          name, description and icon from inside it
  appimages.py remove FILE [--delete]     take its app entry (and icon) away; --delete: the file too.
                                          Without --delete the file is remembered as removed, so
                                          sync doesn't set it up again
  appimages.py sync FOLDER                set up every AppImage in FOLDER that has no entry (and
                                          wasn't removed), and drop entries made here whose file
                                          has gone

Entries are ~/.local/share/applications/appimage-<name>.desktop marked X-Monolith-AppImage=<file>
(the same as the classic Monolith made, so those carry on). The name and icon come from the
AppImage's own .desktop file and icon, unpacked by its runtime with --appimage-extract into a
temporary folder: that unpacks, it doesn't start the app.
"""
import configparser
import glob
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
APPS = os.path.join(DATA, "applications")
ICONS = os.path.join(DATA, "icons", "hicolor")
MARK = "X-Monolith-AppImage"
# AppImages taken out of the apps with Remove (the file kept): sync leaves these alone
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "monolith")
REMOVED = os.path.join(STATE, "appimages-removed.json")


def removed_files():
    try:
        with open(REMOVED, encoding="utf-8") as fh:
            v = json.load(fh)
        return set(v) if isinstance(v, list) else set()
    except (OSError, ValueError):
        return set()


def set_removed(path, on):
    files = removed_files()
    if on == (path in files):
        return
    files = (files | {path}) if on else (files - {path})
    # forget files that are gone
    files = {f for f in files if os.path.exists(f)}
    os.makedirs(STATE, exist_ok=True)
    tmp = REMOVED + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(sorted(files), fh, indent=1)
    os.replace(tmp, REMOVED)
# what's carried over from the AppImage's own entry
CARRY = ("Name", "GenericName", "Comment", "Categories", "Keywords", "MimeType", "StartupWMClass",
         "Terminal", "StartupNotify", "SingleMainWindow", "PrefersNonDefaultGPU")


def is_appimage(path):
    """an ELF file with the AppImage magic (AI and type 1 or 2 at byte 8), or named like one"""
    try:
        with open(path, "rb") as fh:
            head = fh.read(11)
    except OSError:
        return False
    if head[:4] != b"\x7fELF":
        return False
    return head[8:10] == b"AI" or path.lower().endswith(".appimage")


def slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s or "app"


def plain_name(path):
    """Daniel-x86_64.AppImage -> Daniel, r2modman-3.2.21.AppImage -> r2modman"""
    n = re.sub(r"\.appimage$", "", os.path.basename(path), flags=re.I)
    n = re.sub(r"[-_.](x86[-_]64|amd64|aarch64|arm64|i[3-6]86|linux\d*)\b.*$", "", n, flags=re.I)
    n = re.sub(r"[-_]v?\d+(\.\d+)+.*$", "", n)
    return n.replace("_", " ").strip() or "App"


def read_desktop(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return dict(cp["Desktop Entry"]) if cp.has_section("Desktop Entry") else {}
    except (configparser.Error, OSError, UnicodeDecodeError):
        return {}


def exec_target(e):
    """the file an entry runs (its X-Monolith-AppImage, else the first word of Exec)"""
    if e.get(MARK):
        return e[MARK]
    try:
        words = shlex.split(e.get("Exec", ""))
    except ValueError:
        return ""
    return words[0] if words else ""


def entries():
    """file -> (entry path, entry) for every app entry that runs an AppImage"""
    out = {}
    for d in sorted(glob.glob(os.path.join(APPS, "*.desktop"))):
        e = read_desktop(d)
        t = exec_target(e)
        if t and (MARK in e or t.lower().endswith(".appimage")):
            out[os.path.realpath(os.path.expanduser(t))] = (d, e)
    return out


def unpack(appimage, tmp, what):
    try:
        subprocess.run([appimage, "--appimage-extract", what], cwd=tmp, timeout=90,
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired):
        pass


def inside(appimage):
    """The AppImage's own entry and icon file (in a temporary folder the caller removes)."""
    tmp = tempfile.mkdtemp(prefix="monolith-appimage-")
    root = os.path.join(tmp, "squashfs-root")
    unpack(appimage, tmp, "*.desktop")
    own = {}
    for d in glob.glob(os.path.join(root, "*.desktop")):
        own = read_desktop(d)
        if own:
            break
    # the icon: .DirIcon (often a link to the real file), else <Icon>.png/.svg at the top
    icon = None
    unpack(appimage, tmp, ".DirIcon")
    link = os.path.join(root, ".DirIcon")
    for _ in range(3):
        if os.path.islink(link):
            unpack(appimage, tmp, os.path.relpath(os.path.join(os.path.dirname(link), os.readlink(link)), root))
            link = os.path.join(os.path.dirname(link), os.readlink(link))
    if os.path.isfile(link):
        icon = link
    elif own.get("Icon"):
        for ext in (".png", ".svg", ".xpm"):
            unpack(appimage, tmp, own["Icon"] + ext)
            p = os.path.join(root, own["Icon"] + ext)
            if os.path.isfile(p):
                icon = os.path.realpath(p)
                break
    return tmp, own, icon


def install_icon(src, name):
    """into the user's icon theme: SVGs in scalable/, the rest in 256x256/; returns the icon name"""
    with open(src, "rb") as fh:
        svg = fh.read(512).lstrip().startswith((b"<?xml", b"<svg"))
    folder = os.path.join(ICONS, "scalable" if svg else "256x256", "apps")
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(src, os.path.join(folder, name + (".svg" if svg else ".png")))
    return name


def free_path(folder, base):
    p = os.path.join(folder, base)
    n = 2
    while os.path.exists(p):
        stem, ext = os.path.splitext(base)
        p = os.path.join(folder, "%s-%d%s" % (stem, n, ext))
        n += 1
    return p


def add(folder, path, keep=False):
    path = os.path.realpath(os.path.expanduser(path))
    # adding it by hand undoes an earlier Remove
    set_removed(path, False)
    if not os.path.isfile(path):
        return {"ok": False, "file": path, "error": "There's no file there"}
    if not is_appimage(path):
        return {"ok": False, "file": path, "error": "That isn't an AppImage"}
    folder = os.path.expanduser(folder)
    os.makedirs(folder, exist_ok=True)
    if not keep and os.path.dirname(path) != os.path.realpath(folder):
        dest = os.path.join(folder, os.path.basename(path))
        # dropping a newer copy of one that's already set up replaces it
        if os.path.exists(dest) and os.path.realpath(dest) != path:
            os.remove(dest)
        shutil.move(path, dest)
        path = os.path.realpath(dest)
    os.chmod(path, os.stat(path).st_mode | 0o755)

    tmp, own, icon_file = inside(path)
    try:
        name = own.get("Name") or plain_name(path)
        sl = slug(name)
        old = entries().get(path)
        entry = old[0] if old else os.path.join(APPS, "appimage-" + sl + ".desktop")
        if not old and os.path.exists(entry) and read_desktop(entry).get(MARK) not in (None, path):
            entry = free_path(APPS, "appimage-" + sl + ".desktop")
        icon = install_icon(icon_file, "appimage-" + sl) if icon_file else "application-x-executable"
        lines = ["[Desktop Entry]", "Type=Application"]
        for k in CARRY:
            if k == "Name":
                lines.append("Name=" + name)
            elif own.get(k):
                lines.append(k + "=" + own[k])
        if not own.get("Categories"):
            lines.append("Categories=Utility;")
        lines += ['Exec="%s" %%U' % path.replace('"', '\\"'), "TryExec=" + path, "Icon=" + icon, MARK + "=" + path]
        os.makedirs(APPS, exist_ok=True)
        with open(entry, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        refresh()
        set_removed(path, False)
        return {"ok": True, "file": path, "name": name, "entry": entry, "icon": icon}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def remove(path, delete=False):
    path = os.path.realpath(os.path.expanduser(path))
    found = entries().get(path)
    if found:
        d, e = found
        os.remove(d)
        icon = e.get("Icon", "")
        if icon.startswith("appimage-"):
            for f in glob.glob(os.path.join(ICONS, "*", "apps", icon + ".*")):
                os.remove(f)
    if delete and os.path.isfile(path):
        os.remove(path)
    if os.path.isfile(path):
        set_removed(path, True)
    refresh()
    return {"ok": True, "file": path}


def refresh():
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", "-q", APPS], stderr=subprocess.DEVNULL)


def listing(folder):
    folder = os.path.realpath(os.path.expanduser(folder))
    ents = entries()
    files = set()
    if os.path.isdir(folder):
        for f in os.listdir(folder):
            p = os.path.join(folder, f)
            if os.path.isfile(p) and f.lower().endswith(".appimage"):
                files.add(os.path.realpath(p))
    files |= set(f for f in ents if os.path.isfile(f))
    out = []
    for f in sorted(files, key=lambda x: os.path.basename(x).lower()):
        d, e = ents.get(f, (None, {}))
        out.append({"file": f, "name": e.get("Name") or plain_name(f), "comment": e.get("Comment", ""),
                    "icon": e.get("Icon", ""), "added": bool(d), "entry": d or "",
                    "inFolder": os.path.dirname(f) == folder, "size": os.path.getsize(f)})
    # entries made here whose file has gone
    gone = [{"file": f, "name": e.get("Name", ""), "entry": d} for f, (d, e) in ents.items() if MARK in e and not os.path.exists(f)]
    return {"folder": folder, "items": out, "gone": gone}


def sync(folder):
    done = []
    skip = removed_files()
    for it in listing(folder)["items"]:
        if not it["added"] and it["inFolder"] and it["file"] not in skip:
            done.append(add(folder, it["file"], keep=True))
    for g in listing(folder)["gone"]:
        os.remove(g["entry"])
        done.append({"ok": True, "file": g["file"], "removed": True})
    if done:
        refresh()
    return done


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 1
    if a[0] == "list" and len(a) > 1:
        print(json.dumps(listing(a[1])))
    elif a[0] == "add" and len(a) > 2:
        print(json.dumps(add(a[1], a[2], keep="--keep" in a)))
    elif a[0] == "remove" and len(a) > 1:
        print(json.dumps(remove(a[1], delete="--delete" in a)))
    elif a[0] == "sync" and len(a) > 1:
        print(json.dumps(sync(a[1])))
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
