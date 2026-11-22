#!/usr/bin/env python3
"""Default apps (Settings -> Startup & apps -> Default apps): which app opens links, folders,
text, videos, music, pictures, PDFs, mail and archives.

    default_apps.py list               JSON: [{id, title, current, apps: [{id, name, icon}]}]
    default_apps.py set ROLE APP_ID    APP_ID (a .desktop file's id) opens all of ROLE's types

Kept where every app and xdg-open look: ~/.config/mimeapps.list ([Default Applications], and
[Added Associations] so the app is listed for those types too). A desktop's own list
(~/.config/<desktop>-mimeapps.list) wins over it, so a type set there is changed there too.
Only the lines for the role's types change; the rest of the file stays as it is.
"""
import json
import os
import subprocess
import sys

# id, title, its types (the first is the one asked to tell which app it is now), what an app
# offering it lists (a category, or a type: "video/" for any video type), and whether a web
# browser counts (it lists half of these types and isn't what anyone wants for them)
ROLES = [
    ("browser", "Web browser", ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml",
                                "x-scheme-handler/about", "x-scheme-handler/unknown"], ["WebBrowser", "x-scheme-handler/http"], True),
    ("files", "File manager", ["inode/directory"], ["FileManager", "inode/directory"], False),
    ("editor", "Text editor", ["text/plain", "text/markdown", "text/x-log", "application/x-shellscript", "application/json",
                               "text/x-python", "application/xml"], ["TextEditor", "text/plain"], False),
    ("video", "Video player", ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo",
                               "video/mpeg", "video/ogg", "video/x-flv", "video/3gpp"], ["video/"], False),
    ("music", "Music player", ["audio/mpeg", "audio/flac", "audio/x-flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/opus",
                               "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/x-m4a"], ["audio/"], False),
    ("images", "Image viewer", ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff",
                                "image/avif", "image/heic", "image/svg+xml"], ["image/"], False),
    ("pdf", "PDF viewer", ["application/pdf"], ["application/pdf"], True),
    ("mail", "Email", ["x-scheme-handler/mailto"], ["Email", "x-scheme-handler/mailto"], False),
    ("archives", "Archive manager", ["application/zip", "application/x-7z-compressed", "application/vnd.rar", "application/x-rar",
                                     "application/x-tar", "application/x-compressed-tar", "application/x-xz-compressed-tar",
                                     "application/gzip"], ["Archiving", "application/zip"], False),
]

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
DATA_DIRS = [DATA_HOME] + [d for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]


def entries():
    """Every app's .desktop file: id -> {name, icon, types, categories, hidden}. The first one found
    for an id wins (your own over the system's), as for the launcher."""
    found = {}
    for d in DATA_DIRS:
        root = os.path.join(d, "applications")
        for base, _, files in os.walk(root):
            for f in files:
                if not f.endswith(".desktop"):
                    continue
                path = os.path.join(base, f)
                did = os.path.relpath(path, root).replace("/", "-")
                if did in found:
                    continue
                e = {"Type": "", "Name": "", "Icon": "", "MimeType": "", "Categories": "", "NoDisplay": "", "Hidden": ""}
                try:
                    section = None
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        for line in fh:
                            line = line.strip()
                            if line.startswith("["):
                                section = line
                                continue
                            if section != "[Desktop Entry]" or "=" not in line:
                                continue
                            k, v = line.split("=", 1)
                            if k in e and not e[k]:
                                e[k] = v.strip()
                except OSError:
                    continue
                found[did] = {
                    "name": e["Name"] or did[:-8],
                    "icon": e["Icon"],
                    "types": [t for t in e["MimeType"].split(";") if t],
                    "categories": [c for c in e["Categories"].split(";") if c],
                    "app": e["Type"] == "Application",
                    "hidden": e["Hidden"].lower() == "true",
                    "nodisplay": e["NoDisplay"].lower() == "true",
                }
    return found


def offers(e, match, browser_ok):
    if not e["app"] or e["hidden"]:
        return False
    if not browser_ok and "WebBrowser" in e["categories"]:
        return False
    for m in match:
        if "/" not in m:
            if m in e["categories"]:
                return True
        elif m.endswith("/"):
            if any(t.startswith(m) for t in e["types"]):
                return True
        elif m in e["types"]:
            return True
    return False


def current(mime):
    try:
        r = subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True, timeout=10)
        return r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def lists():
    """mimeapps.list files to write: the desktop's own ones that exist, then the main one."""
    out = []
    for desk in (os.environ.get("XDG_CURRENT_DESKTOP") or "").lower().split(":"):
        p = os.path.join(CONFIG, desk + "-mimeapps.list")
        if desk and os.path.exists(p):
            out.append(p)
    out.append(os.path.join(CONFIG, "mimeapps.list"))
    return out


def rewrite(path, types, app, must):
    """Sets each type to app under [Default Applications], and puts app first under [Added
    Associations]. A desktop's own list only gets the types it already has (must=False)."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        lines = []
    if not must and not lines:
        return

    def section(name):
        """(start, end) of a section's lines (start is its header), or None."""
        start = None
        for i, l in enumerate(lines):
            if l.strip() == name:
                start = i
            elif start is not None and l.strip().startswith("["):
                return start, i
        return (start, len(lines)) if start is not None else None

    def put(name, value_of, only_existing):
        sec = section(name)
        if sec is None:
            if only_existing:
                return
            if lines and lines[-1].strip() != "":
                lines.append("")
            lines.append(name)
            sec = (len(lines) - 1, len(lines))
        start, end = sec
        have = {}
        for i in range(start + 1, end):
            l = lines[i]
            if "=" in l and not l.lstrip().startswith("#"):
                have[l.split("=", 1)[0].strip()] = i
        new = []
        for t in types:
            if t in have:
                lines[have[t]] = t + "=" + value_of(lines[have[t]].split("=", 1)[1])
            elif not only_existing:
                new.append(t + "=" + value_of(""))
        # (after the section's last entry, before the blank line that ends it)
        at = end
        while at > start + 1 and lines[at - 1].strip() == "":
            at -= 1
        lines[at:at] = new

    put("[Default Applications]", lambda old: app, not must)
    put("[Added Associations]", lambda old: ";".join([app] + [a for a in old.split(";") if a and a != app]) + ";", not must)
    if not must and not any("=" in l for l in lines):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".monolith-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip("\n") + "\n")
    os.replace(tmp, path)


def main():
    a = sys.argv[1:]
    if not a or a[0] == "list":
        es = entries()
        out = []
        for rid, title, types, match, browser_ok in ROLES:
            cur = current(types[0])
            apps = [{"id": did, "name": e["name"], "icon": e["icon"]} for did, e in es.items()
                    if offers(e, match, browser_ok) and (not e["nodisplay"] or did == cur)]
            if cur and cur not in [x["id"] for x in apps]:
                e = es.get(cur)
                apps.append({"id": cur, "name": e["name"] if e else cur[:-8] if cur.endswith(".desktop") else cur, "icon": e["icon"] if e else ""})
            apps.sort(key=lambda x: x["name"].lower())
            out.append({"id": rid, "title": title, "current": cur, "apps": apps})
        print(json.dumps(out))
        return
    if a[0] == "set" and len(a) >= 3:
        role = next((r for r in ROLES if r[0] == a[1]), None)
        app = a[2]
        if not role or not app.endswith(".desktop") or "/" in app or "=" in app or ";" in app or "\n" in app:
            print(json.dumps({"ok": False, "error": "bad role or app"}))
            sys.exit(1)
        files = lists()
        for p in files:
            rewrite(p, role[2], app, p == files[-1])
        print(json.dumps({"ok": True}))
        return
    print(__doc__)
    sys.exit(2)


if __name__ == "__main__":
    main()
