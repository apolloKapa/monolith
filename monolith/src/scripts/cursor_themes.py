#!/usr/bin/env python3
"""Cursor themes (Settings -> Theme -> Cursors): the mouse pointer niri and apps draw.

  cursor_themes.py list               JSON: the current theme and size, and every installed
                                      cursor theme with a few preview images (PNGs made from
                                      its Xcursor files, cached in ~/.cache/monolith/cursors)
  cursor_themes.py set <id> [size]    use that theme (and size): niri's cursor { } section,
                                      GNOME's setting (gsettings), GTK 3 and 4 (settings.ini) and
                                      ~/.icons/default (what X11 apps fall back to)
  cursor_themes.py add <path>         install a cursor theme from an archive (.tar.gz, .tar.xz,
                                      .zip...) or a folder, or make one from a single image
                                      (.png, .svg, .jpg...: it becomes the arrow; the theme in use
                                      fills in the other shapes). Prints the new theme's id.
  cursor_themes.py remove <id>        delete a theme installed into your home (not system ones)

Themes are looked up like the icon packs: ~/.icons, ~/.local/share/icons, then XDG_DATA_DIRS.
Only the cursor lines are changed in those files; everything else in them stays.
"""
import configparser
import glob
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import zipfile
import zlib

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "monolith", "cursors")
USER_ICONS = os.path.join(DATA, "icons")
HOME_DIRS = [os.path.join(HOME, ".icons"), USER_ICONS]
SEARCH = HOME_DIRS + [
    os.path.join(d, "icons") for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d
]
NIRI_DIR = os.path.join(CONF, "niri")
DEFAULT_SIZE = 24

# what the preview shows, with the usual alternative file names for each
SAMPLES = [
    ("arrow", ["left_ptr", "default", "arrow", "top_left_arrow"]),
    ("hand", ["pointer", "hand2", "hand1", "pointing_hand"]),
    ("text", ["text", "xterm", "ibeam"]),
    ("busy", ["wait", "watch"]),
    ("working", ["progress", "left_ptr_watch", "half-busy"]),
    ("move", ["move", "fleur", "all-scroll", "size_all"]),
    ("cross", ["crosshair", "cross", "tcross"]),
    ("no", ["not-allowed", "crossed_circle", "forbidden", "no-drop"]),
]
# the names an image made into a cursor stands in for (the arrow); the rest come from the
# theme it inherits
ARROW_NAMES = ["left_ptr", "default", "arrow", "top_left_arrow", "left_arrow"]
IMAGE_EXTS = (".png", ".svg", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")
IMAGE_SIZES = (24, 32, 48, 64, 96)


# ---- finding themes ---------------------------------------------------------------------------

def themes():
    """id -> directory of each cursor theme (the first found wins, like cursor lookup)"""
    found = {}
    for base in SEARCH:
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for name in names:
            path = os.path.join(base, name)
            if name != "default" and name not in found and os.path.isdir(os.path.join(path, "cursors")):
                found[name] = path
    return found


def theme_name(path, fallback):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    for f in ("index.theme", "cursor.theme"):
        try:
            cp.read(os.path.join(path, f), encoding="utf-8")
        except (configparser.Error, UnicodeDecodeError):
            continue
        if cp.has_section("Icon Theme"):
            name = cp["Icon Theme"].get("Name", "").strip()
            if name:
                return name
    return fallback


def in_home(path):
    return any(os.path.realpath(path).startswith(os.path.realpath(d) + os.sep) for d in HOME_DIRS)


# ---- Xcursor -> PNG previews -------------------------------------------------------------------

XCUR_IMAGE = 0xFFFD0002


def read_xcursor(path, want=48):
    """(width, height, RGBA bytes) of the image in an Xcursor file closest to `want` px"""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        raise ValueError("not an Xcursor file")
    _, _, ntoc = struct.unpack_from("<III", data, 4)
    best = None
    for i in range(ntoc):
        typ, size, pos = struct.unpack_from("<III", data, 16 + i * 12)
        if typ == XCUR_IMAGE and (best is None or abs(size - want) < abs(best[0] - want)):
            best = (size, pos)
    if best is None:
        raise ValueError("no images")
    pos = best[1]
    _, _, _, _, w, h, _, _, _ = struct.unpack_from("<IIIIIIIII", data, pos)
    pixels = memoryview(data)[pos + 36: pos + 36 + w * h * 4]
    out = bytearray(w * h * 4)
    for i in range(w * h):
        b, g, r, a = pixels[i * 4: i * 4 + 4]   # little-endian premultiplied ARGB
        if a:
            r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
        out[i * 4: i * 4 + 4] = bytes((r, g, b, a))
    return w, h, bytes(out)


def write_png(path, w, h, rgba):
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(png)
    os.replace(tmp, path)


def preview(theme_id, theme_dir, names):
    """a PNG of the first of `names` the theme has (cached by the file's path and time)"""
    for n in names:
        src = os.path.join(theme_dir, "cursors", n)
        if not os.path.exists(src):
            continue
        real = os.path.realpath(src)
        try:
            stamp = int(os.path.getmtime(real))
        except OSError:
            continue
        key = re.sub(r"[^A-Za-z0-9_.-]", "_", f"{theme_id}-{os.path.basename(real)}-{stamp}")
        out = os.path.join(CACHE, key + ".png")
        if os.path.exists(out):
            return out
        try:
            w, h, rgba = read_xcursor(real)
        except (OSError, ValueError, struct.error):
            continue
        os.makedirs(CACHE, exist_ok=True)
        write_png(out, w, h, rgba)
        return out
    return ""


# ---- the current choice ------------------------------------------------------------------------

def niri_files():
    return sorted(glob.glob(os.path.join(NIRI_DIR, "**", "*.kdl"), recursive=True))


CURSOR_BLOCK = re.compile(r"(?ms)^(\s*)cursor\s*\{(.*?)^\1\}")


def niri_cursor():
    for f in niri_files():
        try:
            text = open(f, encoding="utf-8").read()
        except OSError:
            continue
        m = CURSOR_BLOCK.search(text)
        if m:
            t = re.search(r'(?m)^\s*xcursor-theme\s+"([^"]*)"', m.group(2))
            s = re.search(r"(?m)^\s*xcursor-size\s+(\d+)", m.group(2))
            return f, (t.group(1) if t else ""), (int(s.group(1)) if s else 0)
    return None, "", 0


def gsetting(key):
    if not shutil.which("gsettings"):
        return ""
    try:
        return subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key],
                              capture_output=True, text=True, timeout=3).stdout.strip().strip("'")
    except (OSError, subprocess.SubprocessError):
        return ""


def current():
    _, theme, size = niri_cursor()
    theme = theme or gsetting("cursor-theme") or "default"
    if not size:
        try:
            size = int(gsetting("cursor-size") or DEFAULT_SIZE)
        except ValueError:
            size = DEFAULT_SIZE
    return theme, size


# ---- applying ---------------------------------------------------------------------------------

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
    with open(path, "r+" if os.path.exists(path) else "w", encoding="utf-8") as f:
        f.write(text)
        f.truncate()


def set_niri(theme, size):
    """niri's cursor { } section (niri reloads its config by itself and switches right away)"""
    f, _, _ = niri_cursor()
    if f is None:
        # no cursor section anywhere: add one to the main config
        f = os.path.join(NIRI_DIR, "config.kdl")
        if not os.path.exists(f):
            return
        text = open(f, encoding="utf-8").read()
        new = text.rstrip("\n") + f'\n\ncursor {{\n    xcursor-theme "{theme}"\n    xcursor-size {size}\n}}\n'
    else:
        text = open(f, encoding="utf-8").read()
        m = CURSOR_BLOCK.search(text)
        body = m.group(2)
        indent = m.group(1) + "    "
        for key, val in (("xcursor-theme", f'"{theme}"'), ("xcursor-size", str(size))):
            if re.search(rf"(?m)^\s*{key}\s", body):
                body = re.sub(rf"(?m)^(\s*){key}\s.*$", lambda mm: f"{mm.group(1)}{key} {val}", body, count=1)
            else:
                body = f"\n{indent}{key} {val}" + body
        new = text[:m.start(2)] + body + text[m.end(2):]
    if new == text:
        return
    old = text
    with open(f, "r+", encoding="utf-8") as fh:
        fh.write(new)
        fh.truncate()
    # a config niri can't read would leave it on the old one: put the file back then
    if shutil.which("niri"):
        main = os.path.join(NIRI_DIR, "config.kdl")
        r = subprocess.run(["niri", "validate", "-c", main], capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            with open(f, "r+", encoding="utf-8") as fh:
                fh.write(old)
                fh.truncate()
            sys.exit("niri didn't accept the cursor setting: " + (r.stderr.strip().splitlines() or ["?"])[-1])


def cmd_set(theme, size=None):
    all_themes = themes()
    if theme not in all_themes:
        sys.exit(f"no cursor theme called {theme}")
    size = int(size) if size else current()[1]
    size = max(12, min(256, size))
    set_niri(theme, size)
    if shutil.which("gsettings"):
        for key, val in (("cursor-theme", theme), ("cursor-size", str(size))):
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, val],
                           capture_output=True, timeout=5)
    for v in ("gtk-3.0", "gtk-4.0"):
        ini_set(os.path.join(CONF, v, "settings.ini"), "Settings", "gtk-cursor-theme-name", theme)
        ini_set(os.path.join(CONF, v, "settings.ini"), "Settings", "gtk-cursor-theme-size", str(size))
    # what X11 apps (XWayland) use when nothing else tells them
    ini_set(os.path.join(HOME, ".icons", "default", "index.theme"), "Icon Theme", "Inherits", theme)
    print(json.dumps({"current": theme, "size": size}))


# ---- adding your own ---------------------------------------------------------------------------

def safe_extract(archive, dest):
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                target = os.path.realpath(os.path.join(dest, info.filename))
                if not target.startswith(os.path.realpath(dest) + os.sep):
                    sys.exit("the archive has files outside its own folder")
            z.extractall(dest)
        return
    try:
        with tarfile.open(archive) as t:
            t.extractall(dest, filter="data")   # no paths outside dest, no devices
    except tarfile.TarError as e:
        sys.exit(f"couldn't open the archive: {e}")


def theme_roots(folder):
    """the cursor themes inside an unpacked download (folders with a cursors/ subfolder)"""
    roots = []
    for dirpath, dirnames, _ in os.walk(folder):
        if "cursors" in dirnames and os.path.isdir(os.path.join(dirpath, "cursors")):
            roots.append(dirpath)
            dirnames[:] = []    # a theme's own subfolders aren't themes
        elif dirpath[len(folder):].count(os.sep) >= 4:
            dirnames[:] = []
    return roots


def install_root(root, fallback_name):
    name = os.path.basename(os.path.normpath(root))
    if name in ("", ".", "tmp") or name.startswith("monolith-cursor-"):
        name = fallback_name
    name = re.sub(r"[^A-Za-z0-9_.+-]", "_", name)
    dest = os.path.join(USER_ICONS, name)
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(USER_ICONS, exist_ok=True)
    shutil.copytree(root, dest, symlinks=True)
    if not os.path.exists(os.path.join(dest, "index.theme")):
        with open(os.path.join(dest, "index.theme"), "w", encoding="utf-8") as f:
            f.write(f"[Icon Theme]\nName={name}\n")
    return name


def xcursor_bytes(images, hot):
    """an Xcursor file from [(size, width, height, rgba)] with the hotspot at `hot` (0..1 of the size)"""
    ntoc = len(images)
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc)
    pos = 16 + ntoc * 12
    toc, body = b"", b""
    for size, w, h, rgba in images:
        px = bytearray(w * h * 4)
        for i in range(w * h):
            r, g, b, a = rgba[i * 4: i * 4 + 4]
            px[i * 4: i * 4 + 4] = bytes((b * a // 255, g * a // 255, r * a // 255, a))   # premultiplied BGRA
        chunk = struct.pack("<IIIIIIIII", 36, XCUR_IMAGE, size, 1, w, h,
                            min(w - 1, int(hot[0] * w)), min(h - 1, int(hot[1] * h)), 0) + bytes(px)
        toc += struct.pack("<III", XCUR_IMAGE, size, pos + len(body))
        body += chunk
    return header + toc + body


def make_from_image(path):
    """an image -> a small cursor theme: it's the arrow, everything else comes from the theme in use"""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        sys.exit("ImageMagick is needed to turn an image into a cursor")
    images = []
    for size in IMAGE_SIZES:
        r = subprocess.run([magick, path + "[0]", "-background", "none", "-resize", f"{size}x{size}",
                            "-gravity", "northwest", "-extent", f"{size}x{size}", "-depth", "8", "rgba:-"],
                           capture_output=True, timeout=30)
        if r.returncode != 0 or len(r.stdout) != size * size * 4:
            sys.exit("couldn't read that image")
        images.append((size, size, size, r.stdout))
    stem = re.sub(r"[^A-Za-z0-9_.+-]", "_", os.path.splitext(os.path.basename(path))[0]) or "image"
    name = f"monolith-custom-{stem}"
    base = current()[0]
    dest = os.path.join(USER_ICONS, name)
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(os.path.join(dest, "cursors"))
    with open(os.path.join(dest, "cursors", ARROW_NAMES[0]), "wb") as f:
        f.write(xcursor_bytes(images, (0.0, 0.0)))    # an arrow points with its top-left corner
    for n in ARROW_NAMES[1:]:
        os.symlink(ARROW_NAMES[0], os.path.join(dest, "cursors", n))
    inherits = base if base not in ("", "default", name) else "Adwaita"
    with open(os.path.join(dest, "index.theme"), "w", encoding="utf-8") as f:
        f.write(f"[Icon Theme]\nName={os.path.splitext(os.path.basename(path))[0]} (custom)\n"
                f"Comment=Made from {os.path.basename(path)}\nInherits={inherits}\n")
    return name


def cmd_add(path):
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.exists(path):
        sys.exit(f"{path} doesn't exist")
    if os.path.isfile(path) and path.lower().endswith(IMAGE_EXTS):
        print(json.dumps({"added": [make_from_image(path)]}))
        return
    fallback = re.sub(r"(\.tar)?\.[A-Za-z0-9]+$", "", os.path.basename(path)) or "custom"
    with tempfile.TemporaryDirectory(prefix="monolith-cursor-") as tmp:
        if os.path.isdir(path):
            folder = path
        else:
            safe_extract(path, tmp)
            folder = tmp
        roots = theme_roots(folder)
        if not roots:
            sys.exit("no cursor theme in there (a cursor theme is a folder with a cursors/ folder in it)")
        added = [install_root(r, fallback) for r in roots]
    print(json.dumps({"added": added}))


def cmd_remove(theme):
    path = themes().get(theme)
    if not path:
        sys.exit(f"no cursor theme called {theme}")
    if not in_home(path):
        sys.exit("that theme came with the system; it can only be removed with the package manager")
    shutil.rmtree(path)
    print(json.dumps({"removed": theme}))


def cmd_list():
    cur, size = current()
    out = []
    for tid, path in themes().items():
        samples = [p for p in (preview(tid, path, names) for _, names in SAMPLES) if p]
        if not samples:
            continue
        out.append({"id": tid, "name": theme_name(path, tid), "samples": samples, "removable": in_home(path)})
    out.sort(key=lambda t: t["name"].lower())
    print(json.dumps({"current": cur, "size": size, "themes": out}))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        cmd_list()
    elif a[:1] == ["set"] and len(a) >= 2:
        cmd_set(a[1], a[2] if len(a) >= 3 else None)
    elif a[:1] == ["add"] and len(a) >= 2:
        cmd_add(a[1])
    elif a[:1] == ["remove"] and len(a) >= 2:
        cmd_remove(a[1])
    else:
        sys.exit(__doc__)
