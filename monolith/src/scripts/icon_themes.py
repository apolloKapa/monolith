#!/usr/bin/env python3
"""Icon packs (Settings -> Theme -> Icons): the icons apps and Monolith draw, like KDE's Icons page.

  icon_themes.py list        JSON: the current pack and every installed one, with a few sample
                             icons from each for the preview
  icon_themes.py set <id>    use that pack: Qt apps (qt6ct / qt5ct), GTK 3 and 4 (settings.ini)
                             and apps that read GNOME's setting (gsettings)

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


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) >= 3 and sys.argv[1] == "set":
        cmd_set(sys.argv[2])
    else:
        sys.exit(__doc__)
