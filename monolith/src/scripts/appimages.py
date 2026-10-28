#!/usr/bin/env python3
"""AppImages (Settings -> AppImages): drop an AppImage and it shows up like an installed app.

  appimages.py list                     JSON: the AppImages that have an app entry (the ones added
                                        here and ones you made yourself), and the folder
  appimages.py add <file> [--keep]      add one: made executable, moved into the AppImages folder
                                        (--keep: left where it is), and given an app entry
                                        (~/.local/share/applications) with its own name and icon,
                                        so launchers, the dock and menus show it like any app
  appimages.py remove <id> [--delete]   take its app entry away again (--delete: the file too)
  appimages.py sync [folder]            add every AppImage in the folder that has no entry yet and
                                        drop entries made here whose file is gone (the folder
                                        watcher runs this)

The name, icon and the rest of the entry come from the AppImage itself: its .desktop file and
icon are unpacked with its own --appimage-extract into a temporary folder (only the runtime's
unpacker runs, not the app). Entries made here carry X-Monolith-AppImage=<file>.
"""
import configparser
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
APPS = os.path.join(DATA, "applications")
ICONS = os.path.join(DATA, "monolith", "appimage-icons")
SETTINGS = os.path.join(CONF, "monolith", "settings.json")
MARK = "X-Monolith-AppImage"
# keys copied over from the AppImage's own entry
KEEP = ("Name", "GenericName", "Comment", "Categories", "Keywords", "MimeType", "StartupWMClass",
        "Terminal", "StartupNotify", "SingleMainWindow", "PrefersNonDefaultGPU")


def folder():
    try:
        f = json.load(open(SETTINGS, encoding="utf-8")).get("appimages", {}).get("folder", "")
    except (OSError, ValueError):
        f = ""
    return os.path.expanduser(f) if f else os.path.join(HOME, "Appimages")


def is_appimage(path):
    """an ELF file with the AppImage type 2 magic (AI\\x02 at byte 8)"""
    try:
        with open(path, "rb") as f:
            head = f.read(12)
    except OSError:
        return False
    return head[:4] == b"\x7fELF" and head[8:11] == b"AI\x02"


def slug(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s or "appimage"


def base_name(path):
    """MyApp-1.2.3-x86_64.AppImage -> MyApp"""
    n = re.sub(r"\.appimage$", "", os.path.basename(path), flags=re.I)
    n = re.sub(r"[-_.]?(x86[-_]64|amd64|aarch64|arm64|i[3-6]86|linux)(?=$|[-_.])", "", n, flags=re.I)
    n = re.sub(r"[-_ ]v?\d+(\.\d+)+.*$", "", n)
    return n.replace("_", " ").strip(" -.") or "AppImage"


def extract(appimage, tmp, pattern):
    try:
        subprocess.run([appimage, "--appimage-extract", pattern], cwd=tmp, capture_output=True, timeout=60,
                       env={**os.environ, "APPIMAGE_EXTRACT_AND_RUN": "0"})
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.join(tmp, "squashfs-root")


def read_entry(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        return {}
    return dict(cp["Desktop Entry"]) if cp.has_section("Desktop Entry") else {}


def unpack(appimage, tmp, rel):
    """unpack one file of the AppImage, following symlinks inside it (its .desktop and .DirIcon
    are often links into usr/share): the real file's path, or None"""
    root = os.path.join(tmp, "squashfs-root")
    rel = rel.lstrip("/")
    for _ in range(8):
        p = os.path.join(root, rel)
        if not os.path.lexists(p):
            extract(appimage, tmp, rel)
        if os.path.islink(p):
            target = os.readlink(p)
            rel = os.path.normpath(os.path.join(os.path.dirname(rel), target)) if not target.startswith("/") else target.lstrip("/")
            if rel.startswith(".."):
                return None
            continue
        real = os.path.realpath(p)
        return real if real.startswith(os.path.realpath(root) + os.sep) and os.path.isfile(real) else None
    return None


def find_icon(appimage, tmp, root, icon_name):
    """the AppImage's icon file: the icon its entry names (an SVG, or the largest PNG), or .DirIcon"""
    if icon_name:
        for rel in (icon_name + ".svg", icon_name + ".png"):
            real = unpack(appimage, tmp, rel)
            if real:
                return real
        extract(appimage, tmp, f"usr/share/icons/hicolor/*/apps/{icon_name}.*")
        hi = glob.glob(os.path.join(root, "usr/share/icons/hicolor/*/apps", icon_name + ".*"))
        def size(p):
            m = re.search(r"/(\d+)x\d+/", p)
            return 10000 if "/scalable/" in p else (int(m.group(1)) if m else 0)
        for p in sorted(hi, key=size, reverse=True):
            real = unpack(appimage, tmp, os.path.relpath(p, root))
            if real:
                return real
    return unpack(appimage, tmp, ".DirIcon")


def icon_ext(path):
    with open(path, "rb") as f:
        head = f.read(512)
    if head.startswith(b"\x89PNG"):
        return ".png"
    if b"<svg" in head or head.lstrip().startswith(b"<?xml"):
        return ".svg"
    return ".png"


def escape_exec(path):
    return '"' + path.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$") + '"'


def entries():
    """desktop file -> (entry, AppImage path, made here) for every entry that runs an AppImage"""
    out = {}
    for f in sorted(glob.glob(os.path.join(APPS, "*.desktop"))):
        e = read_entry(f)
        if not e:
            continue
        target = e.get(MARK, "")
        mine = bool(target)
        if not target:
            m = re.search(r'"?([^"\s]+\.AppImage)"?', e.get("Exec", ""), re.I)
            target = os.path.expanduser(m.group(1)) if m else ""
        if target:
            out[f] = (e, target, mine)
    return out


def add(path, keep=False):
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.isfile(path):
        sys.exit(f"{path} doesn't exist")
    if not is_appimage(path):
        sys.exit(f"{os.path.basename(path)} isn't an AppImage (type 2)")
    # already has an entry: nothing to do
    for f, (_, target, _) in entries().items():
        if os.path.realpath(target) == os.path.realpath(path):
            return os.path.basename(f)[:-len(".desktop")]
    dest_dir = folder()
    if not keep and os.path.realpath(os.path.dirname(path)) != os.path.realpath(dest_dir):
        os.makedirs(dest_dir, exist_ok=True)
        dest = os.path.join(dest_dir, os.path.basename(path))
        if os.path.exists(dest):
            sys.exit(f"there's already a {os.path.basename(path)} in {dest_dir}")
        shutil.move(path, dest)
        path = dest
    os.chmod(path, os.stat(path).st_mode | 0o111)

    with tempfile.TemporaryDirectory(prefix="monolith-appimage-") as tmp:
        root = extract(path, tmp, "*.desktop")
        own = {}
        for d in sorted(glob.glob(os.path.join(root, "*.desktop"))):
            real = unpack(path, tmp, os.path.relpath(d, root))
            own = read_entry(real) if real else {}
            if own:
                break
        name = own.get("Name") or base_name(path)
        app_id = "appimage-" + slug(name)
        icon_src = find_icon(path, tmp, root, own.get("Icon", ""))
        icon = ""
        if icon_src:
            os.makedirs(ICONS, exist_ok=True)
            icon = os.path.join(ICONS, app_id + icon_ext(icon_src))
            shutil.copyfile(icon_src, icon)

    args = ""
    m = re.search(r"(%[fFuU])", own.get("Exec", ""))
    if m:
        args = " " + m.group(1)
    lines = ["[Desktop Entry]", "Type=Application"]
    for k in KEEP:
        if own.get(k) and k != "Name":
            lines.append(f"{k}={own[k]}")
    lines.insert(2, f"Name={name}")
    lines += [f"Exec={escape_exec(path)}{args}", f"TryExec={path}", f"Icon={icon or 'application-x-executable'}",
              f"{MARK}={path}"]
    os.makedirs(APPS, exist_ok=True)
    desktop = os.path.join(APPS, app_id + ".desktop")
    n = 2
    while os.path.exists(desktop):
        desktop = os.path.join(APPS, f"{app_id}-{n}.desktop")
        n += 1
    with open(desktop, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", APPS], capture_output=True, timeout=20)
    return os.path.basename(desktop)[:-len(".desktop")]


def remove(app_id, delete=False):
    desktop = os.path.join(APPS, app_id + ".desktop")
    e = read_entry(desktop)
    if not e:
        sys.exit(f"no app entry called {app_id}")
    target = e.get(MARK) or ""
    if not target:
        m = re.search(r'"?([^"\s]+\.AppImage)"?', e.get("Exec", ""), re.I)
        target = os.path.expanduser(m.group(1)) if m else ""
    icon = e.get("Icon", "")
    os.remove(desktop)
    if icon.startswith(ICONS + os.sep) and os.path.exists(icon):
        os.remove(icon)
    if delete and target and os.path.isfile(target) and is_appimage(target):
        os.remove(target)


def sync(dirpath=None):
    d = os.path.expanduser(dirpath) if dirpath else folder()
    added, removed = [], []
    have = {os.path.realpath(t) for _, t, _ in entries().values()}
    for f in sorted(glob.glob(os.path.join(d, "*"))):
        if os.path.isfile(f) and os.path.realpath(f) not in have and is_appimage(f):
            try:
                added.append(add(f, keep=True))
            except SystemExit:
                continue
    for f, (_, target, mine) in entries().items():
        if mine and not os.path.exists(target):
            remove(os.path.basename(f)[:-len(".desktop")])
            removed.append(os.path.basename(f)[:-len(".desktop")])
    return added, removed


def cmd_list():
    out = []
    for f, (e, target, mine) in entries().items():
        out.append({"id": os.path.basename(f)[:-len(".desktop")], "name": e.get("Name", ""), "icon": e.get("Icon", ""),
                    "path": target, "exists": os.path.exists(target), "managed": mine})
    out.sort(key=lambda a: a["name"].lower())
    print(json.dumps({"folder": folder(), "apps": out}))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        cmd_list()
    elif a[:1] == ["add"] and len(a) >= 2:
        print(json.dumps({"added": add(a[1], keep="--keep" in a)}))
    elif a[:1] == ["remove"] and len(a) >= 2:
        remove(a[1], delete="--delete" in a)
        print(json.dumps({"removed": a[1]}))
    elif a[:1] == ["sync"]:
        added, removed = sync(a[1] if len(a) >= 2 else None)
        print(json.dumps({"added": added, "removed": removed}))
    else:
        sys.exit(__doc__)
