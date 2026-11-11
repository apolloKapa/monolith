#!/usr/bin/env python3
"""Fastfetch presets (Settings -> Fastfetch). Presets are fastfetch configs in
~/.config/monolith/fastfetch/NAME.jsonc; {{colors.ROLE.VARIANT.hex}} (.red, .green, .blue too) or {{ROLE}} in them becomes the
shell's colour (as the shell shows it: the wallpaper's or a colour theme's). The one in use is written to fastfetch's own config.

    fastfetch.py list              JSON: each preset, whether it's in use, and a preview (HTML)
    fastfetch.py apply NAME        use NAME
    fastfetch.py render            write the one in use again (after the colours change)
    fastfetch.py new               a new preset (from fastfetch's defaults); prints its name
    fastfetch.py duplicate NAME    a copy; prints its name
    fastfetch.py delete NAME
    fastfetch.py picture NAME FILE [small|medium|large]   a picture as NAME's logo (kitty)
    fastfetch.py picsize NAME small|medium|large          the picture's size
    fastfetch.py text NAME         back to the text logo NAME had before its picture
    fastfetch.py support           "yes" if this fastfetch can show pictures at all
"""
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or HOME + "/.config"
DIR = CONF + "/monolith/fastfetch"
TARGET = CONF + "/fastfetch/config.jsonc"
STATE_DIR = (os.environ.get("XDG_STATE_HOME") or HOME + "/.local/state") + "/monolith"
# the shell's colours as it shows them (the wallpaper's, or a colour theme's); the wallpaper
# palette only until the shell has written that
PALETTE = STATE_DIR + "/shell-palette.json" if os.path.exists(STATE_DIR + "/shell-palette.json") else STATE_DIR + "/next-palette.json"
HEADER = '// Monolith: the "%s" preset with the shell\'s colours, rewritten when they change.\n// Change it in Settings -> Fastfetch (%s), not here.\n'


def presets():
    os.makedirs(DIR, exist_ok=True)
    return sorted(f[:-6] for f in os.listdir(DIR) if f.endswith(".jsonc"))


def active():
    try:
        m = re.search(r'the "(.+?)" preset', open(TARGET).readline())
        return m.group(1) if m else ""
    except OSError:
        return ""


def coloured(text):
    try:
        roles = json.load(open(PALETTE)).get("colors", {})
    except (OSError, ValueError):
        roles = {}

    def colour(role, variant="default"):
        v = roles.get(role, {})
        pick = v.get(variant) or v.get("default") or v.get("dark") or {}
        return pick.get("color", "#888888") if isinstance(pick, dict) else "#888888"
    def field(role, variant, what):
        c = colour(role, variant)
        r, g, b = int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
        return {"hex": c, "hex_stripped": c[1:], "red": str(r), "green": str(g), "blue": str(b),
                "rgb": "rgb(%d, %d, %d)" % (r, g, b)}.get(what, c)
    # {{colors.ROLE.VARIANT.hex}} (or .red / .green / .blue / .hex_stripped / .rgb)
    text = re.sub(r"\{\{\s*colors\.(\w+)\.(\w+)\.(\w+)\s*\}\}", lambda m: field(m.group(1), m.group(2), m.group(3)), text)
    # the short form: {{primary}}
    return re.sub(r"\{\{\s*(\w+)\s*\}\}", lambda m: colour(m.group(1)), text)


def path(name):
    return os.path.join(DIR, name + ".jsonc")


# ── pictures as logos ──
# A preset's picture is copied (as a PNG, fitted) to DIR/images/NAME.png and shown with
# kitty's graphics protocol ("kitty-direct": kitty reads the file itself; it takes PNG only).
# The text logo it replaced is kept next to it (NAME.logo.json) for "Back to text".
IMAGES = DIR + "/images"
SIZES = {"small": 22, "medium": 32, "large": 44}     # width in terminal cells


def strip_jsonc(text):
    """JSON with comments (// and /* */) and trailing commas -> plain JSON; strings untouched."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == "\\":
                out.append(text[i + 1:i + 2])
                i += 2
                continue
            if ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
            out.append(ch)
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            out.append(ch)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def read_preset(name):
    raw = open(path(name), encoding="utf-8").read()
    head = "".join(l for l in raw.splitlines(True)[:5] if l.lstrip().startswith("//") and not l.lstrip().startswith("// Picture:"))
    return head, json.loads(strip_jsonc(raw))


def write_preset(name, head, data, note=""):
    with open(path(name), "w", encoding="utf-8") as f:
        f.write(head + (note and "// Picture: " + note + "\n") + json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def picture_of(data):
    logo = data.get("logo")
    if isinstance(logo, dict) and logo.get("type") in ("kitty", "kitty-direct", "sixel", "iterm", "chafa", "kitty-icat"):
        return logo
    return None


def fit_picture(src, dest, cells):
    """The picture as a PNG at most 2x what it shows at; returns its height in cells."""
    from PIL import Image, ImageOps
    im = ImageOps.exif_transpose(Image.open(src))
    im.seek(0)
    im = im.convert("RGBA")
    w, h = im.size
    px = cells * 20
    if w > px:
        im = im.resize((px, max(1, round(h * px / w))), Image.LANCZOS)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".tmp.png"
    im.save(tmp, "PNG")
    os.replace(tmp, dest)
    # terminal cells are about twice as tall as wide
    return max(1, round(cells * (h / w) / 2.1))


def set_picture(name, src, size="medium"):
    head, data = read_preset(name)
    keep = IMAGES + "/" + name + ".logo.json"
    if not picture_of(data) and not os.path.exists(keep):
        os.makedirs(IMAGES, exist_ok=True)
        json.dump(data.get("logo", {}), open(keep, "w"))
    dest = IMAGES + "/" + name + ".png"
    cells = SIZES.get(size, SIZES["medium"])
    rows = fit_picture(src, dest, cells)
    data["logo"] = {"type": "kitty-direct", "source": dest, "width": cells, "height": rows,
                    "position": "left", "padding": {"top": 1, "left": 2, "right": 3}}
    write_preset(name, head, data, os.path.basename(src))
    if name == active():
        write_target(name)


def set_size(name, size):
    head, data = read_preset(name)
    logo = picture_of(data)
    if not logo or not os.path.exists(logo.get("source", "")):
        return
    from PIL import Image
    w, h = Image.open(logo["source"]).size
    cells = SIZES.get(size, SIZES["medium"])
    logo["width"], logo["height"] = cells, max(1, round(cells * (h / w) / 2.1))
    write_preset(name, head, data)
    if name == active():
        write_target(name)


def image_support():
    """Distributions can build fastfetch without picture logos (Gentoo: USE=-imagemagick);
    then any picture preset only prints an error."""
    with tempfile.NamedTemporaryFile("w", suffix=".jsonc", delete=False) as f:
        f.write('{"logo": {"type": "kitty-direct", "source": "/nonexistent.png"}, "modules": []}')
        tmp = f.name
    try:
        r = subprocess.run(["fastfetch", "-c", tmp, "--pipe", "true"], capture_output=True, text=True, timeout=6,
                           stdin=subprocess.DEVNULL)
        return "without image logo support" not in (r.stdout + r.stderr)
    except (OSError, subprocess.TimeoutExpired):
        return False
    finally:
        os.unlink(tmp)


def back_to_text(name):
    head, data = read_preset(name)
    keep = IMAGES + "/" + name + ".logo.json"
    try:
        data["logo"] = json.load(open(keep))
    except (OSError, ValueError):
        data.pop("logo", None)
    for f in (keep, IMAGES + "/" + name + ".png"):
        if os.path.exists(f):
            os.remove(f)
    if not data.get("logo"):
        data.pop("logo", None)
    write_preset(name, head, data)
    if name == active():
        write_target(name)


def write_target(name):
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    body = coloured(open(path(name)).read())
    open(TARGET, "w").write(HEADER % (name, path(name)) + body)


# ── preview: run fastfetch and replay its output on a small character grid ──
PALETTE16 = ["#1e1e1e", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#dcdfe4",
             "#5c6370", "#ef8891", "#b5e890", "#f0d197", "#86c5ff", "#dd9bf0", "#7ad3de", "#ffffff"]


def xterm256(n):
    if n < 16:
        return PALETTE16[n]
    if n < 232:
        n -= 16
        lv = [0, 95, 135, 175, 215, 255]
        return "#%02x%02x%02x" % (lv[n // 36], lv[n // 6 % 6], lv[n % 6])
    g = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (g, g, g)


def to_html(out):
    rows, r, c = [[]], 0, 0
    style = {"fg": None, "bold": False}

    def put(ch):
        nonlocal c
        while len(rows) <= r:
            rows.append([])
        row = rows[r]
        while len(row) < c:
            row.append((" ", None, False))
        cell = (ch, style["fg"], style["bold"])
        if c < len(row):
            row[c] = cell
        else:
            row.append(cell)
        c += 1

    i = 0
    while i < len(out):
        ch = out[i]
        if ch == "\x1b" and i + 1 < len(out) and out[i + 1] == "[":
            m = re.match(r"\x1b\[([0-9;?]*)([A-Za-z])", out[i:])
            if not m:
                i += 1
                continue
            args = [int(x) if x.isdigit() else 0 for x in m.group(1).replace("?", "").split(";")] if m.group(1) else []
            cmd, n = m.group(2), (args[0] if args and args[0] else 1)
            if cmd == "m":
                k = 0
                args = args or [0]
                while k < len(args):
                    a = args[k]
                    if a == 0:
                        style = {"fg": None, "bold": False}
                    elif a == 1:
                        style["bold"] = True
                    elif a == 22:
                        style["bold"] = False
                    elif 30 <= a <= 37:
                        style["fg"] = PALETTE16[a - 30]
                    elif 90 <= a <= 97:
                        style["fg"] = PALETTE16[a - 90 + 8]
                    elif a == 39:
                        style["fg"] = None
                    elif a == 38 and k + 1 < len(args):
                        if args[k + 1] == 2 and k + 4 < len(args):
                            style["fg"] = "#%02x%02x%02x" % tuple(args[k + 2:k + 5])
                            k += 4
                        elif args[k + 1] == 5 and k + 2 < len(args):
                            style["fg"] = xterm256(args[k + 2])
                            k += 2
                    k += 1
            elif cmd == "A":
                r = max(0, r - n)
            elif cmd == "B":
                r += n
            elif cmd == "C":
                c += n
            elif cmd == "D":
                c = max(0, c - n)
            elif cmd == "G":
                c = n - 1
            elif cmd == "H":
                r, c = (args[0] - 1 if args else 0), (args[1] - 1 if len(args) > 1 else 0)
            i += len(m.group(0))
            continue
        if ch == "\x1b":           # other escapes (images, titles): skip to their end
            j = out.find("\x1b\\", i)
            k = out.find("\x07", i)
            ends = [x for x in (j + 2 if j >= 0 else -1, k + 1 if k >= 0 else -1) if x > 0]
            i = min(ends) if ends else i + 2
            continue
        if ch == "\n":
            r += 1
            c = 0
        elif ch == "\r":
            c = 0
        elif ch == "\t":
            c = (c // 8 + 1) * 8
        elif ch >= " ":
            put(ch)
        i += 1

    lines = []
    for row in rows[:40]:
        parts, cur, buf = [], None, ""
        for ch, fg, bold in row[:110]:
            key = (fg, bold)
            if key != cur:
                if buf:
                    parts.append(span(cur, buf))
                cur, buf = key, ""
            buf += ch
        if buf:
            parts.append(span(cur, buf))
        lines.append("".join(parts))
    while lines and not lines[-1].strip():
        lines.pop()
    return "<pre style=\"font-family: '%s'\">" % terminal_font() + "\n".join(lines) + "</pre>"


def span(key, text):
    fg, bold = key if key else (None, False)
    t = html.escape(text)
    if bold:
        t = "<b>" + t + "</b>"
    return '<span style="color:%s">%s</span>' % (fg, t) if fg else t


def terminal_font():
    """kitty's font, so a preview looks like the terminal it greets (fixed width lines up)."""
    try:
        for line in open(CONF + "/kitty/kitty.conf", encoding="utf-8"):
            m = re.match(r"\s*font_family\s+(.+)", line)
            if m:
                return m.group(1).strip()
    except OSError:
        pass
    return "monospace"


def terminal_name():
    """Your terminal (Settings → Launcher's terminal, else Monolith's), for the preview's
    "Terminal" line: run from the shell, fastfetch would see the shell there instead."""
    for path, keys in ((CONF + "/monolith/next.json", ("search", "terminal")), (CONF + "/monolith/settings.json", ("launcher", "terminalCommand"))):
        try:
            d = json.load(open(path))
            v = d.get(keys[0], {}).get(keys[1], "")
            if v:
                return os.path.basename(v.split()[0])
        except (OSError, ValueError, AttributeError):
            pass
    return "kitty"


def preview(name):
    text = coloured(open(path(name)).read())
    try:
        data = json.loads(strip_jsonc(text))
        if picture_of(data):
            # outside a terminal fastfetch draws no picture (and then nothing else either):
            # the preview runs without it, and Settings puts the picture next to the text
            data["logo"] = {"type": "none"}
            text = json.dumps(data)
    except ValueError:
        pass
    with tempfile.NamedTemporaryFile("w", suffix=".jsonc", delete=False) as f:
        f.write(text)
        tmp = f.name
    try:
        # not a terminal: no input, and no hint of a terminal it could query (kitty answers
        # image queries; asked without one, fastfetch waits)
        env = {k: v for k, v in os.environ.items() if not k.startswith(("KITTY", "TERM", "WEZTERM", "GHOSTTY", "KONSOLE", "VTE"))}
        env.update(TERM="xterm-256color", COLORTERM="truecolor", COLUMNS="110", LINES="40")
        # through your login shell, so the "Shell" line names it
        shell = "/bin/sh"
        try:
            import pwd
            shell = pwd.getpwuid(os.getuid()).pw_shell or shell
        except (ImportError, KeyError):
            pass
        env["FF_PREVIEW_CONF"] = tmp
        out = subprocess.run([shell, "-c", 'fastfetch -c "$FF_PREVIEW_CONF" --pipe false'], capture_output=True, text=True, timeout=6,
                             stdin=subprocess.DEVNULL, env=env).stdout
        # (colour codes sit right against the name, so no word boundary before it)
        out = re.sub(r"(quickshell|python3(?:\.\d+)?)(?=[\s\x1b]|$)", terminal_name(), out)
        return to_html(out)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    finally:
        os.unlink(tmp)


def fresh_name(base):
    names = presets()
    if base not in names:
        return base
    i = 2
    while "%s %d" % (base, i) in names:
        i += 1
    return "%s %d" % (base, i)


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "list":
        cur = active()
        items = []
        for n in presets():
            pic = {}
            try:
                logo = picture_of(read_preset(n)[1])
                if logo:
                    size = next((k for k, v in SIZES.items() if v == logo.get("width")), "")
                    pic = {"image": logo.get("source", ""), "cols": logo.get("width", 0), "rows": logo.get("height", 0),
                           "size": size, "padTop": (logo.get("padding") or {}).get("top", 0),
                           "padLeft": (logo.get("padding") or {}).get("left", 0)}
            except (OSError, ValueError):
                pass
            items.append({"name": n, "active": n == cur, "html": preview(n), **pic})
        print(json.dumps(items))
    elif a[0] == "apply":
        write_target(a[1])
    elif a[0] == "render":
        cur = active()
        if cur and os.path.exists(path(cur)):
            write_target(cur)
    elif a[0] == "new":
        name = fresh_name("New preset")
        out = subprocess.run(["fastfetch", "--gen-config", path(name)], capture_output=True)
        if not os.path.exists(path(name)):
            open(path(name), "w").write('{\n  "modules": ["title", "separator", "os", "kernel", "uptime", "packages", "shell", "wm", "cpu", "gpu", "memory", "colors"]\n}\n')
        print(name)
    elif a[0] == "duplicate":
        name = fresh_name(a[1] + " copy")
        shutil.copy(path(a[1]), path(name))
        print(name)
    elif a[0] == "delete":
        if a[1] != active() and os.path.exists(path(a[1])):
            os.remove(path(a[1]))
            for f in (IMAGES + "/" + a[1] + ".png", IMAGES + "/" + a[1] + ".logo.json"):
                if os.path.exists(f):
                    os.remove(f)
    elif a[0] == "picture":
        set_picture(a[1], a[2], a[3] if len(a) > 3 else "medium")
    elif a[0] == "picsize":
        set_size(a[1], a[2])
    elif a[0] == "text":
        back_to_text(a[1])
    elif a[0] == "support":
        print("yes" if image_support() else "no")


if __name__ == "__main__":
    main()
