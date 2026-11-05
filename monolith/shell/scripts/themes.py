#!/usr/bin/env python3
"""Previews for Settings -> Appearance: icon packs and cursor themes.

    themes.py icons     JSON: each icon pack with a few of its icons (files) to show
    themes.py cursors   JSON: each cursor theme with a few of its pointers, drawn to PNG files

Cursor themes are Xcursor files; their pictures are unpacked here (no extra libraries) into
~/.cache/monolith/cursor-previews. The lists are cached until a theme folder changes.
"""
import json
import os
import struct
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


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "icons":
        print(json.dumps(cached("icon", build_icons)))
    elif what == "cursors":
        print(json.dumps(cached("cursor", build_cursors)))
    else:
        sys.exit(__doc__)
