#!/usr/bin/env python3
"""Previews for Settings -> Appearance: icon packs and cursor themes.

    themes.py icons     JSON: each icon pack with a few of its icons (files) to show
    themes.py cursors   JSON: each cursor theme with a few of its pointers, drawn to PNG files
    themes.py add icons|cursors FOLDER
                        a theme from anywhere (a download, unpacked) made one of the choices: the
                        folder, or the themes inside it, copied into ~/.local/share/icons (an
                        icon pack without an index.theme gets one). JSON: {"added": [names]} or
                        {"error": "why not"}

Cursor themes are Xcursor files; their pictures are unpacked here (no extra libraries) into
~/.cache/monolith/cursor-previews. The lists are cached until a theme folder changes.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zlib

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME") or HOME + "/.local/share"
ROOTS = ["/usr/share/icons", "/usr/local/share/icons", DATA + "/icons", HOME + "/.icons"]
CACHE = (os.environ.get("XDG_CACHE_HOME") or HOME + "/.cache") + "/monolith"

# what an icon pack is shown with: the first name a pack has, per sample
ICON_SAMPLES = [
    ["folder", "inode-directory"],
    ["user-home", "folder-home"],
    ["utilities-terminal", "kitty", "terminal"],
    ["web-browser", "firefox", "librewolf", "internet-web-browser"],
    ["preferences-system", "systemsettings", "org.gnome.Settings"],
    ["accessories-text-editor", "text-editor", "org.gnome.TextEditor"],
    ["multimedia-audio-player", "audio-player", "rhythmbox"],
    ["image-viewer", "eog", "org.gnome.Loupe"],
    ["user-trash", "user-trash-full"],
]
CURSOR_SAMPLES = [["left_ptr", "default", "arrow"], ["hand2", "pointer", "hand1"], ["xterm", "text", "ibeam"],
                  ["watch", "wait"], ["fleur", "move", "all-scroll"], ["crosshair", "cross"]]


def themes():
    seen, out = set(), []
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            d = os.path.join(root, name)
            if name in seen or not os.path.isdir(d):
                continue
            seen.add(name)
            out.append((name, d))
    return out


def title_of(d, name):
    try:
        for line in open(os.path.join(d, "index.theme"), encoding="utf-8", errors="replace"):
            if line.startswith("Name="):
                return line.strip()[5:] or name
    except OSError:
        pass
    return name


def stamp(d):
    try:
        return os.stat(d).st_mtime
    except OSError:
        return 0


def cached(kind, build):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, kind + "-previews.json")
    key = [[n, d, stamp(d)] for n, d in themes()]
    try:
        c = json.load(open(path))
        if c.get("key") == key:
            return c["list"]
    except (OSError, ValueError):
        pass
    lst = build()
    json.dump({"key": key, "list": lst}, open(path, "w"))
    return lst


def icon_files(d):
    """name -> best file in the pack: SVG first, else the biggest PNG."""
    best = {}
    for root, _dirs, files in os.walk(d):
        if "/cursors" in root:
            continue
        size = 0
        for part in root.split("/"):
            num = part.split("x")[0].split("@")[0]
            if num.isdigit():
                size = int(num)
        if "scalable" in root:
            size = 10000
        for f in files:
            base, ext = os.path.splitext(f)
            if ext not in (".svg", ".png"):
                continue
            score = size + (1 if ext == ".svg" else 0)
            if base not in best or score > best[base][0]:
                best[base] = (score, os.path.join(root, f))
    return best


def build_icons():
    out = []
    for name, d in themes():
        if name in ("hicolor", "default") or not os.path.isfile(os.path.join(d, "index.theme")):
            continue
        if not any(os.path.isdir(os.path.join(d, x)) for x in os.listdir(d) if x != "cursors"):
            continue
        files = icon_files(d)
        samples = []
        for names in ICON_SAMPLES:
            for n in names:
                if n in files:
                    samples.append(files[n][1])
                    break
        if samples:
            out.append({"name": name, "title": title_of(d, name), "samples": samples[:8]})
    return out


# ── Xcursor → PNG ──
def xcursor_image(path, want=32):
    """The picture closest to `want` px in an Xcursor file, as (w, h, rgba bytes)."""
    data = open(path, "rb").read()
    if data[:4] != b"Xcur":
        return None
    hsize, _ver, ntoc = struct.unpack_from("<III", data, 4)
    entries = []
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, hsize + i * 12)
        if typ == 0xFFFD0002:
            entries.append((abs(sub - want), pos))
    if not entries:
        return None
    pos = sorted(entries)[0][1]
    _h, _t, _s, _v, w, h = struct.unpack_from("<IIIIII", data, pos)
    px = data[pos + 36: pos + 36 + w * h * 4]
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        b, g, r, a = px[i * 4], px[i * 4 + 1], px[i * 4 + 2], px[i * 4 + 3]
        if 0 < a < 255:  # stored premultiplied
            r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
        rgba[i * 4:i * 4 + 4] = bytes((r, g, b, a))
    return w, h, bytes(rgba)


def write_png(path, w, h, rgba):
    raw = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def build_cursors():
    out = []
    for name, d in themes():
        cdir = os.path.join(d, "cursors")
        if not os.path.isdir(cdir):
            continue
        dest = os.path.join(CACHE, "cursor-previews", name)
        os.makedirs(dest, exist_ok=True)
        samples = []
        for names in CURSOR_SAMPLES:
            for n in names:
                src = os.path.join(cdir, n)
                if not os.path.exists(src):
                    continue
                png = os.path.join(dest, names[0] + ".png")
                try:
                    img = xcursor_image(os.path.realpath(src))
                    if img:
                        write_png(png, *img)
                        samples.append(png)
                except (OSError, struct.error):
                    pass
                break
        if samples:
            out.append({"name": name, "title": title_of(d, name), "samples": samples})
    return out


# ── adding a theme from a folder ──


def is_cursor_theme(d):
    return os.path.isdir(os.path.join(d, "cursors"))


def icon_dirs(d):
    """the folders of an icon pack that hold icons (relative), for an index.theme"""
    out = []
    for root, _dirs, files in os.walk(d):
        rel = os.path.relpath(root, d)
        if rel == "." or rel.split("/")[0] == "cursors":
            continue
        if any(f.endswith((".svg", ".png", ".xpm")) for f in files):
            out.append(rel)
    return sorted(out)


KINDS = {"apps", "places", "devices", "mimetypes", "mimes", "actions", "status", "categories", "emblems",
         "emotes", "panel", "animations", "intl", "stock", "legacy", "preferences"}


def is_icon_theme(d):
    if os.path.isfile(os.path.join(d, "index.theme")):
        try:
            text = open(os.path.join(d, "index.theme"), encoding="utf-8", errors="replace").read()
        except OSError:
            return False
        # (a cursor theme's index.theme only says Inherits=: that isn't an icon pack)
        return "Directories=" in text
    # (no index.theme: icons in size folders straight inside it, 48x48/…, scalable/…, or kind
    # folders with sizes, apps/48/…; not just any folder that has pictures somewhere below)
    for rel in icon_dirs(d):
        parts = rel.split("/")
        if re.match(r"(\d+(x\d+)?(@\d+x?)?|scalable|symbolic)$", parts[0], re.I):
            return True
        if len(parts) > 1 and parts[0].lower() in KINDS and re.match(r"(\d+(x\d+)?(@\d+x?)?|scalable|symbolic)$", parts[1], re.I):
            return True
    return False


def find(d, test, depth=3):
    """d itself if it's a theme, else the themes inside it (an unpacked download often has the
    theme one or two folders down, or several variants side by side)"""
    d = os.path.realpath(d)
    if os.path.basename(d) == "cursors" and test is is_cursor_theme:
        d = os.path.dirname(d)
    if test(d):
        return [d]
    if depth == 0:
        return []
    out = []
    try:
        kids = sorted(os.listdir(d))
    except OSError:
        return []
    for k in kids:
        p = os.path.join(d, k)
        if os.path.isdir(p) and not os.path.islink(p) and not k.startswith("."):
            out += find(p, test, depth - 1)
    return out


def size_of(rel):
    first = rel.split("/")[0]
    m = re.match(r"(\d+)(?:x\d+)?(?:@(\d+)x?)?$", first)
    if m:
        return int(m.group(1)), int(m.group(2) or 1), "Fixed"
    if first.lower() == "scalable" or "symbolic" in first.lower():
        return 128, 1, "Scalable"
    # (packs laid out by kind first: apps/48 …)
    for part in rel.split("/"):
        if part.isdigit():
            return int(part), 1, "Fixed"
    return 48, 1, "Threshold"


def write_index(d, name, kind):
    path = os.path.join(d, "index.theme")
    if kind == "cursors":
        if not os.path.exists(path):
            open(path, "w").write("[Icon Theme]\nName=%s\nComment=Added in Monolith\n" % name)
        return
    if os.path.exists(path):
        return
    dirs = icon_dirs(d)
    lines = ["[Icon Theme]", "Name=" + name, "Comment=Added in Monolith", "Inherits=hicolor", "Directories=" + ",".join(dirs), ""]
    for rel in dirs:
        size, scale, typ = size_of(rel)
        ctx = rel.split("/")[-1].capitalize()
        lines += ["[%s]" % rel, "Size=%d" % size, "Scale=%d" % scale, "Type=" + typ, "Context=" + ctx]
        if typ == "Scalable":
            lines += ["MinSize=8", "MaxSize=512"]
        lines.append("")
    open(path, "w").write("\n".join(lines))


def files_of(d):
    out = set()
    for root, dirs, files in os.walk(d):
        for f in files + [x for x in dirs if os.path.islink(os.path.join(root, x))]:
            out.add(os.path.relpath(os.path.join(root, f), d))
    return out


def add(kind, folder):
    if not os.path.isdir(folder):
        return {"error": "That isn't a folder"}
    test = is_cursor_theme if kind == "cursors" else is_icon_theme
    found = find(folder, test)
    if not found:
        what = "cursor theme (a folder with a \"cursors\" folder in it)" if kind == "cursors" else "icon pack (folders of icons by size, or an index.theme)"
        return {"error": "There's no %s in that folder" % what}
    if len(found) > 24:
        return {"error": "That folder has %d themes in it: pick one of them, or a smaller folder" % len(found)}
    dest_root = DATA + "/icons"
    os.makedirs(dest_root, exist_ok=True)
    taken = {n for n, _d in themes()}
    added = []
    for src in found:
        name = re.sub(r"[^A-Za-z0-9._ +-]", "_", os.path.basename(src)).strip() or "Theme"
        dest = os.path.join(dest_root, name)
        # (one that's a choice already, where themes live: nothing to copy)
        if os.path.dirname(os.path.realpath(src)) in {os.path.realpath(r) for r in ROOTS} and os.path.realpath(src) != os.path.realpath(dest):
            added.append(os.path.basename(src))
            continue
        if os.path.realpath(src) == os.path.realpath(dest):
            # (picked straight from ~/.local/share/icons: it's there already, just made usable)
            write_index(dest, name, kind)
            added.append(name)
            continue
        # added before (the same files under the same name): nothing to do
        if os.path.isdir(dest) and files_of(dest) - {"index.theme", "icon-theme.cache"} == files_of(src) - {"index.theme", "icon-theme.cache"}:
            added.append(name)
            continue
        # a theme of that name already: this one gets its own (both stay choices)
        base, n = name, 2
        while name in taken or os.path.exists(dest):
            name = "%s %d" % (base, n)
            dest = os.path.join(dest_root, name)
            n += 1
        try:
            # (symlinks kept as they are: cursor themes are mostly links between their pointers)
            shutil.copytree(src, dest, symlinks=True)
        except (OSError, shutil.Error) as e:
            shutil.rmtree(dest, ignore_errors=True)
            return {"error": "Couldn't copy %s: %s" % (os.path.basename(src), e), "added": added}
        write_index(dest, name, kind)
        if name != base:
            # (the menu shows the index.theme's name: say which one this is)
            idx = os.path.join(dest, "index.theme")
            try:
                text = open(idx, encoding="utf-8", errors="replace").read()
                text = re.sub(r"^Name=(.*)$", lambda m: "Name=%s (%s)" % (m.group(1), name), text, count=1, flags=re.M)
                open(idx, "w").write(text)
            except OSError:
                pass
        taken.add(name)
        added.append(name)
    # (GTK's icon cache for the pack, when the tool's there: apps find icons faster)
    if kind == "icons" and shutil.which("gtk-update-icon-cache"):
        for name in added:
            subprocess.run(["gtk-update-icon-cache", "-q", "-f", "-t", os.path.join(dest_root, name)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"added": added}


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "icons":
        print(json.dumps(cached("icon", build_icons)))
    elif what == "cursors":
        print(json.dumps(cached("cursor", build_cursors)))
    elif what == "add" and len(sys.argv) == 4 and sys.argv[2] in ("icons", "cursors"):
        print(json.dumps(add(sys.argv[2], sys.argv[3])))
    else:
        sys.exit(__doc__)
