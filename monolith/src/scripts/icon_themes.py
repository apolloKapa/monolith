#!/usr/bin/env python3
"""Icon packs (Settings -> Theme -> Icons): the icons apps and Monolith draw, like KDE's Icons page.

  icon_themes.py list        JSON: the current pack and every installed one, with a few sample
                             icons from each for the preview
  icon_themes.py set <id>    use that pack: Qt apps (qt6ct / qt5ct), GTK 3 and 4 (settings.ini)
                             and apps that read GNOME's setting (gsettings)

One app's own icon (like KDE's "Edit Application -> Icon"):
  icon_themes.py search <text>              JSON: icons whose name has <text>, from every pack
                                            (the current one first)
  icon_themes.py app-icon <app> <icon>      give an app another icon: an icon name, or an image
                                            file (copied into Monolith's data, so moving the
                                            original doesn't break it)
  icon_themes.py app-icon-reset <app>       the app's own icon again
  icon_themes.py app-overrides              JSON: {app id: icon} for the apps given one here

<app> is its desktop file id (firefox, org.kde.dolphin...). The new icon goes in a copy of the
app's .desktop file in ~/.local/share/applications, which launchers, docks and menus everywhere
read first. If that copy was already yours, only its Icon line changes (the old one is kept
in the file and put back on reset).

Only the icon theme line is changed in those files; everything else in them stays.
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
SEARCH = [os.path.join(HOME, ".icons"), os.path.join(DATA, "icons")] + [
    os.path.join(d, "icons") for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d
]

# what the preview shows, with the usual alternative names for each
SAMPLES = [
    ("folder", ["folder", "inode-directory"]),
    ("terminal", ["utilities-terminal", "org.gnome.Terminal", "terminal", "kitty"]),
    ("browser", ["web-browser", "firefox", "internet-web-browser", "org.mozilla.firefox"]),
    ("files", ["system-file-manager", "org.gnome.Nautilus", "file-manager", "org.kde.dolphin"]),
    ("settings", ["preferences-system", "systemsettings", "org.gnome.Settings", "preferences-desktop"]),
    ("editor", ["accessories-text-editor", "text-editor", "org.gnome.TextEditor", "kate"]),
    ("music", ["multimedia-audio-player", "audio-x-generic", "rhythmbox", "elisa"]),
    ("home", ["user-home", "folder-home", "go-home"]),
]


def theme_dirs():
    """id -> list of directories holding that theme (home first, like icon lookup does)"""
    found = {}
    for base in SEARCH:
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for name in names:
            path = os.path.join(base, name)
            if os.path.isfile(os.path.join(path, "index.theme")):
                found.setdefault(name, []).append(path)
    return found


def read_index(paths):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(os.path.join(paths[0], "index.theme"), encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        return None
    return cp


def is_icon_pack(name, cp):
    if name in ("hicolor", "default") or cp is None or not cp.has_section("Icon Theme"):
        return False
    sec = cp["Icon Theme"]
    # hidden themes are fallbacks (AdwaitaLegacy...), except GNOME's own default, which hides
    # itself from pickers but is a normal choice
    if sec.get("Hidden", "false").lower() == "true" and name != "Adwaita":
        return False
    # cursor themes have an index.theme too, but no icon directories
    return bool(sec.get("Directories", "").strip())


def dir_order(cp):
    """the theme's icon directories, most useful for a ~48px preview first"""
    sec = cp["Icon Theme"]
    dirs = [d.strip() for d in (sec.get("Directories", "") + "," + sec.get("ScaledDirectories", "")).split(",") if d.strip()]
    def score(d):
        info = cp[d] if cp.has_section(d) else {}
        if info.get("Type", "") == "Scalable" or "scalable" in d:
            return 0
        try:
            return 1 + abs(int(info.get("Size", "48")) - 48)
        except ValueError:
            return 500
    return sorted(dict.fromkeys(dirs), key=score)


def find_icon(theme, names, all_themes, seen=None):
    """path of the first of names in theme or what it inherits (not hicolor: the preview
    should show what the pack itself draws)"""
    seen = seen or set()
    if theme in seen or theme not in all_themes or theme == "hicolor":
        return ""
    seen.add(theme)
    paths = all_themes[theme]
    cp = read_index(paths)
    if cp is None or not cp.has_section("Icon Theme"):
        return ""
    order = dir_order(cp)
    for name in names:
        for d in order:
            for root in paths:
                for ext in (".svg", ".png"):
                    p = os.path.join(root, d, name + ext)
                    if os.path.isfile(p):
                        return p
    for parent in cp["Icon Theme"].get("Inherits", "").split(","):
        p = find_icon(parent.strip(), names, all_themes, seen)
        if p:
            return p
    return ""


def ini_get(path, section, key):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return ""
    m = re.search(rf"(?ms)^\[{re.escape(section)}\]\s*$(.*?)(?=^\[|\Z)", text)
    if not m:
        return ""
    v = re.search(rf"(?m)^{re.escape(key)}\s*=\s*(.*)$", m.group(1))
    return v.group(1).strip() if v else ""


def ini_set(path, section, key, value):
    """set one key in one section, leaving the rest of the file as it was"""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        text = ""
    line = f"{key}={value}"
    m = re.search(rf"(?ms)^\[{re.escape(section)}\]\s*$(.*?)(?=^\[|\Z)", text)
    if m:
        body = m.group(1)
        if re.search(rf"(?m)^{re.escape(key)}\s*=", body):
            body = re.sub(rf"(?m)^{re.escape(key)}\s*=.*$", lambda _: line, body, count=1)
        else:
            body = "\n" + line + body
        text = text[:m.start(1)] + body + text[m.end(1):]
    else:
        text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + f"[{section}]\n{line}\n"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # rewrite the same file (not a new one): anything watching it keeps watching
    with open(path, "r+" if os.path.exists(path) else "w", encoding="utf-8") as f:
        f.write(text)
        f.truncate()


def current():
    for v in ("qt6ct", "qt5ct"):
        t = ini_get(os.path.join(CONF, v, v + ".conf"), "Appearance", "icon_theme")
        if t:
            return t
    if shutil.which("gsettings"):
        try:
            out = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
                                 capture_output=True, text=True, timeout=3).stdout.strip().strip("'")
            if out:
                return out
        except (OSError, subprocess.SubprocessError):
            pass
    return ini_get(os.path.join(CONF, "gtk-3.0", "settings.ini"), "Settings", "gtk-icon-theme-name")


def cmd_list():
    all_themes = theme_dirs()
    out = []
    for name, paths in all_themes.items():
        cp = read_index(paths)
        if not is_icon_pack(name, cp):
            continue
        sec = cp["Icon Theme"]
        samples = []
        for _, names in SAMPLES:
            p = find_icon(name, names, all_themes)
            if p:
                samples.append(p)
        out.append({
            "id": name,
            "name": sec.get("Name", name),
            "comment": sec.get("Comment", ""),
            "samples": samples,
        })
    out.sort(key=lambda t: t["name"].lower())
    print(json.dumps({"current": current(), "themes": out}))


def cmd_set(theme):
    if theme not in theme_dirs():
        sys.exit(f"no icon pack called {theme}")
    for v in ("qt6ct", "qt5ct"):
        if os.path.isdir(os.path.join(CONF, v)) or shutil.which(v):
            ini_set(os.path.join(CONF, v, v + ".conf"), "Appearance", "icon_theme", theme)
    for v in ("gtk-3.0", "gtk-4.0"):
        ini_set(os.path.join(CONF, v, "settings.ini"), "Settings", "gtk-icon-theme-name", theme)
    if shutil.which("gsettings"):
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", theme],
                       capture_output=True, timeout=5)
    print(json.dumps({"current": theme}))


APPS_HOME = os.path.join(DATA, "applications")
ICON_COPIES = os.path.join(DATA, "monolith", "app-icons")
MADE_BY_US = "X-Monolith-Icon-Override"
OLD_ICON = "X-Monolith-Original-Icon"


def app_dirs():
    dirs = [os.path.join(d, "applications") for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
    return [APPS_HOME] + dirs


def desktop_files():
    """desktop file id -> path, earlier directories winning (how menus resolve them)"""
    found = {}
    for base in app_dirs():
        for root, _, files in os.walk(base):
            for f in files:
                if not f.endswith(".desktop"):
                    continue
                path = os.path.join(root, f)
                did = os.path.relpath(path, base)[:-len(".desktop")].replace(os.sep, "-")
                found.setdefault(did, path)
    return found


def entry_section(text):
    """span (start, end) of the [Desktop Entry] section's body"""
    m = re.search(r"(?ms)^\[Desktop Entry\]\s*$(.*?)(?=^\[|\Z)", text)
    if not m:
        sys.exit("not a desktop file (no [Desktop Entry])")
    return m.start(1), m.end(1)


def entry_get(text, key):
    a, b = entry_section(text)
    m = re.search(rf"(?m)^{re.escape(key)}\s*=\s*(.*)$", text[a:b])
    return m.group(1).strip() if m else None


def entry_set(text, key, value):
    """set (or with value None remove) one key of [Desktop Entry], nothing else"""
    a, b = entry_section(text)
    body = text[a:b]
    pat = rf"(?m)^{re.escape(key)}\s*=.*\n?"
    if value is None:
        body = re.sub(pat, "", body)
    elif re.search(pat, body):
        body = re.sub(rf"(?m)^{re.escape(key)}\s*=.*$", lambda _: f"{key}={value}", body, count=1)
    else:
        body = body.rstrip("\n") + f"\n{key}={value}\n" + ("\n" if body.endswith("\n\n") else "")
    return text[:a] + body + text[b:]


def app_id(arg):
    return arg[:-len(".desktop")] if arg.endswith(".desktop") else arg


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "r+" if os.path.exists(path) else "w", encoding="utf-8") as f:
        f.write(text)
        f.truncate()


CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "monolith", "icon_index.json")


def icon_index():
    """{pack: {name: path}} for every pack (and hicolor, where apps put their own icons).
    Walking every pack takes a second or two, so it's kept in a cache, rebuilt whenever a
    pack's folder changes (installed, removed, updated)."""
    all_themes = theme_dirs()
    packs = [t for t in all_themes if t == "hicolor" or is_icon_pack(t, read_index(all_themes[t]))]
    stamp = {t: [os.path.getmtime(p) for p in all_themes[t]] for t in packs}
    try:
        cached = json.load(open(CACHE, encoding="utf-8"))
        if cached.get("stamp") == stamp:
            return cached["icons"]
    except (OSError, ValueError, KeyError):
        pass
    icons = {}
    for t in packs:
        names = {}
        for root_dir in all_themes[t]:
            for root, _, files in os.walk(root_dir):
                for f in files:
                    name, ext = os.path.splitext(f)
                    # symbolic ones are tiny monochrome glyphs, not app icons
                    if ext in (".svg", ".png") and not name.endswith("-symbolic"):
                        names.setdefault(name, os.path.join(root, f))
        icons[t] = names
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump({"stamp": stamp, "icons": icons}, f)
    except OSError:
        pass
    return icons


def cmd_search(query, limit=240):
    q = query.strip().lower()
    icons = icon_index()
    cur = current()
    # the pack in use first, hicolor (apps' own icons) last
    order = ([cur] if cur in icons else []) + sorted(t for t in icons if t not in (cur, "hicolor")) + (["hicolor"] if "hicolor" in icons else [])
    seen, out = set(), []
    for t in order:
        for name, path in icons[t].items():
            if name in seen or (q and q not in name.lower()):
                continue
            seen.add(name)
            out.append({"name": name, "path": path, "pack": t})
    out.sort(key=lambda i: (not i["name"].lower().startswith(q), len(i["name"]), i["name"]))
    print(json.dumps(out[:limit]))


def cmd_app_icon(arg, icon):
    did = app_id(arg)
    files = desktop_files()
    if did not in files:
        sys.exit(f"no app called {did}")
    if icon.startswith("file://"):
        icon = icon[len("file://"):]
    if icon.startswith("/"):
        if not os.path.isfile(icon):
            sys.exit(f"{icon} isn't a file")
        ext = os.path.splitext(icon)[1].lower()
        if ext not in (".png", ".svg", ".svgz", ".xpm", ".jpg", ".jpeg", ".webp", ".ico"):
            sys.exit("pick a PNG, SVG or other image")
        os.makedirs(ICON_COPIES, exist_ok=True)
        dest = os.path.join(ICON_COPIES, did + ext)
        for old in os.listdir(ICON_COPIES):        # one copy per app
            if os.path.splitext(old)[0] == did and old != os.path.basename(dest):
                os.remove(os.path.join(ICON_COPIES, old))
        if os.path.abspath(icon) != dest:
            shutil.copyfile(icon, dest)
        icon = dest
    elif not re.fullmatch(r"[A-Za-z0-9._+-]+", icon):
        sys.exit(f"not an icon name: {icon}")

    target = os.path.join(APPS_HOME, did.replace("/", "-") + ".desktop")
    src = files[did]
    text = open(src, encoding="utf-8").read()
    if os.path.abspath(src) == os.path.abspath(target):
        # already a copy of the user's: change the Icon line, remember the old one once
        if entry_get(text, MADE_BY_US) != "true" and entry_get(text, OLD_ICON) is None:
            text = entry_set(text, OLD_ICON, entry_get(text, "Icon") or "")
    else:
        text = entry_set(text, MADE_BY_US, "true")
    text = entry_set(text, "Icon", icon)
    write_text(target, text)
    print(json.dumps({"app": did, "icon": icon}))


def cmd_app_reset(arg):
    did = app_id(arg)
    target = os.path.join(APPS_HOME, did + ".desktop")
    if not os.path.isfile(target):
        print(json.dumps({"app": did, "icon": ""}))
        return
    text = open(target, encoding="utf-8").read()
    if entry_get(text, MADE_BY_US) == "true":
        os.remove(target)
    elif entry_get(text, OLD_ICON) is not None:
        old = entry_get(text, OLD_ICON)
        text = entry_set(text, "Icon", old if old else None)
        write_text(target, entry_set(text, OLD_ICON, None))
    for old in os.listdir(ICON_COPIES) if os.path.isdir(ICON_COPIES) else []:
        if os.path.splitext(old)[0] == did:
            os.remove(os.path.join(ICON_COPIES, old))
    print(json.dumps({"app": did, "icon": ""}))


def cmd_app_overrides():
    out = {}
    if os.path.isdir(APPS_HOME):
        for f in os.listdir(APPS_HOME):
            if not f.endswith(".desktop"):
                continue
            try:
                text = open(os.path.join(APPS_HOME, f), encoding="utf-8").read()
                if entry_get(text, MADE_BY_US) == "true" or entry_get(text, OLD_ICON) is not None:
                    out[f[:-len(".desktop")]] = entry_get(text, "Icon") or ""
            except (OSError, UnicodeDecodeError, SystemExit):
                continue
    print(json.dumps(out))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) >= 3 and sys.argv[1] == "set":
        cmd_set(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "search":
        cmd_search(sys.argv[2] if len(sys.argv) >= 3 else "")
    elif len(sys.argv) >= 4 and sys.argv[1] == "app-icon":
        cmd_app_icon(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 3 and sys.argv[1] == "app-icon-reset":
        cmd_app_reset(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "app-overrides":
        cmd_app_overrides()
    else:
        sys.exit(__doc__)
