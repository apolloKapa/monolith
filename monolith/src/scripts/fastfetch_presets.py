#!/usr/bin/env python3
"""Fastfetch presets for Settings -> Theme -> Fastfetchlings.

Presets are fastfetch configs in ~/.config/monolith/fastfetch/<name>.jsonc that may use theme colour
placeholders. The active one is rendered with the current theme colours into
~/.config/fastfetch/config.jsonc, again whenever the theme changes (Matugen.qml runs `render`).

Placeholders, filled from ~/.local/state/monolith/qs_colors.json:
  {{primary}} {{mauve}} ...           "#rrggbb" (a Material role or any Monolith colour)
  {{primary.rgb}}                      "r;g;b", for "\\u001b[38;2;{{primary.rgb}}m"
  {{colors.primary.default.hex}}       matugen's form, also .hex_stripped .red .green .blue

Commands (all print JSON or nothing; errors go to stderr with exit code 1):
  list                 presets, the active one, and a coloured HTML preview of each
  apply NAME           make NAME active and write fastfetch's config
  render               write the active preset again (after a theme change)
  new                  make "New preset", "New preset 2"... from the basic config; prints its name
  duplicate NAME       copy NAME; prints the copy's name
  rename OLD NEW
  delete NAME
  edit NAME            open NAME in a terminal editor; when the editor closes, re-render if it's
                       active and show the result until Enter
  show NAME            (inside that terminal) run fastfetch with NAME and wait for Enter
  set-image NAME FILE [WIDTH]  show a picture instead of the logo (copied in as PNG, WIDTH in
                       terminal columns, default 30); kitty draws it with its image protocol
  image-size NAME WIDTH
  clear-image NAME     back to the preset's own logo
"""
import hashlib, html, json, os, re, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local", "state"), "monolith")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "monolith", "fastfetch")
PRESETS = os.path.join(CONF, "monolith", "fastfetch")
ACTIVE = os.path.join(PRESETS, ".active")
SEEDED = os.path.join(PRESETS, ".seeded")
TARGET = os.path.join(CONF, "fastfetch", "config.jsonc")
IMAGES = os.path.join(PRESETS, "images")
IMAGE_MAP = os.path.join(PRESETS, ".images.json")
IMAGE_WIDTH = 30
COLORS = os.path.join(STATE, "qs_colors.json")
ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "fastfetch")
SHIPPED = os.path.join(ASSETS, "presets")
MARK = "// Monolith fastfetch"
DEFAULT = "Monolith"
OLD_NAME = "Before Monolith"

# the Material roles matugen uses, from Monolith's palette (same mapping as Matugen.qml toMd3)
ROLES = {
    "surface_container_lowest": "base", "surface_container_low": "mantle", "surface": "crust",
    "surface_container": "surface0", "surface_container_high": "surface1",
    "surface_container_highest": "surface2", "surface_variant": "surface1", "on_surface": "text",
    "on_surface_variant": "subtext0", "outline": "subtext1", "outline_variant": "surface2",
    "inverse_surface": "overlay0", "surface_dim": "crust", "surface_bright": "surface1",
    "primary": "blue", "primary_container": "sapphire", "secondary": "green",
    "secondary_container": "yellow", "tertiary": "peach", "tertiary_container": "pink",
    "error": "red", "error_container": "maroon", "primary_fixed": "sapphire",
    "secondary_fixed": "yellow", "tertiary_fixed": "pink", "inverse_primary": "mauve",
}
FALLBACK = {"base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b", "text": "#cdd6f4",
            "subtext0": "#a6adc8", "subtext1": "#bac2de", "surface0": "#313244", "surface1": "#45475a",
            "surface2": "#585b70", "overlay0": "#6c7086", "overlay1": "#7f849c", "overlay2": "#9399b2",
            "blue": "#89b4fa", "sapphire": "#74c7ec", "peach": "#fab387", "green": "#a6e3a1",
            "red": "#f38ba8", "mauve": "#cba6f7", "pink": "#f5c2e7", "yellow": "#f9e2af",
            "maroon": "#eba0ac", "teal": "#94e2d5"}
NAME_OK = re.compile(r"^[^/\\\x00.][^/\\\x00]{0,59}$")


def fail(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def path_of(name):
    return os.path.join(PRESETS, name + ".jsonc")


def check_name(name):
    name = (name or "").strip()
    if not NAME_OK.match(name):
        fail("Use a name of up to 60 characters, without / or a leading dot")
    return name


def exists(name):
    return os.path.isfile(path_of(name))


def names():
    try:
        files = [f[:-6] for f in os.listdir(PRESETS) if f.endswith(".jsonc") and not f.startswith(".")]
    except FileNotFoundError:
        files = []
    first = [n for n in (DEFAULT,) if n in files]
    return first + sorted((n for n in files if n not in first), key=str.lower)


def read(p, default=""):
    try:
        with open(p, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return default


def write(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p), prefix=".tmp-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, p)


def get_active():
    a = read(ACTIVE).strip()
    return a if a and exists(a) else (DEFAULT if exists(DEFAULT) else (names() or [""])[0])


def seed():
    """Copy shipped presets in once each (one you delete doesn't come back), and keep the
    fastfetch config you had before Monolith as a preset of its own."""
    os.makedirs(PRESETS, exist_ok=True)
    seeded = set(read(SEEDED).split("\n")) - {""}
    changed = False
    if os.path.isdir(SHIPPED):
        for f in sorted(os.listdir(SHIPPED)):
            if not f.endswith(".jsonc") or f in seeded:
                continue
            if not os.path.exists(os.path.join(PRESETS, f)):
                shutil.copyfile(os.path.join(SHIPPED, f), os.path.join(PRESETS, f))
            seeded.add(f)
            changed = True
    if "import:pre-monolith" not in seeded:
        old = TARGET + ".pre-monolith"
        current = read(TARGET)
        src = old if os.path.isfile(old) else (TARGET if current and MARK not in current else "")
        # an older Monolith/Serpantinum-written config is just the Monolith preset again
        if src and not exists(OLD_NAME) and "monolith" not in read(src).lower():
            shutil.copyfile(src, path_of(OLD_NAME))
        seeded.add("import:pre-monolith")
        changed = True
    if changed:
        write(SEEDED, "\n".join(sorted(seeded)) + "\n")


def palette():
    try:
        with open(COLORS, encoding="utf-8") as f:
            c = json.load(f)
    except (OSError, ValueError):
        c = {}
    pal = dict(FALLBACK)
    pal.update({k: v for k, v in c.items() if isinstance(v, str) and re.match(r"^#[0-9a-fA-F]{6}", v)})
    for role, key in ROLES.items():
        pal[role] = pal.get(key, "#ffffff")
    for k in ("primary", "secondary", "tertiary", "error"):
        for suffix in ("", "_container"):
            hx = pal[k + suffix]
            lum = sum(w * int(hx[i:i + 2], 16) / 255 for w, i in ((0.2126, 1), (0.7152, 3), (0.0722, 5)))
            pal["on_" + k + suffix] = pal["crust"] if lum > 0.5 else pal["text"]
    return {k: v[:7].lower() for k, v in pal.items()}


def fill(text, pal):
    def comp(hx, what):
        r, g, b = (int(hx[i:i + 2], 16) for i in (1, 3, 5))
        return {"hex": hx, "hex_stripped": hx[1:], "red": str(r), "green": str(g), "blue": str(b),
                "rgb": f"{r};{g};{b}"}.get(what)

    def matugen(m):
        v = pal.get(m.group(1))
        out = comp(v, m.group(2)) if v else None
        return out if out is not None else m.group(0)

    def short(m):
        v = pal.get(m.group(1))
        out = comp(v, m.group(2) or "hex") if v else None
        return out if out is not None else m.group(0)

    text = re.sub(r"\{\{\s*colors\.([a-z0-9_]+)\.(?:default|dark|light)\.([a-z_]+)\s*\}\}", matugen, text)
    return re.sub(r"\{\{\s*([a-z0-9_]+)(?:\.(rgb|hex|hex_stripped|red|green|blue))?\s*\}\}", short, text)


# --- pictures instead of the logo: {preset: {"file": "images/x.png", "width": 30}} -------------
def images():
    try:
        with open(IMAGE_MAP, encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def save_images(d):
    write(IMAGE_MAP, json.dumps(d, indent=2, sort_keys=True) + "\n")


def image_of(name):
    e = images().get(name)
    if not isinstance(e, dict) or not e.get("file"):
        return None
    p = os.path.join(PRESETS, e["file"])
    if not os.path.isfile(p):
        return None
    try:
        w = max(8, min(120, int(e.get("width", IMAGE_WIDTH))))
    except (TypeError, ValueError):
        w = IMAGE_WIDTH
    return {"path": p, "width": w}


def drop_unused_images():
    used = {e.get("file") for e in images().values() if isinstance(e, dict)}
    if os.path.isdir(IMAGES):
        for f in os.listdir(IMAGES):
            if "images/" + f not in used:
                try: os.unlink(os.path.join(IMAGES, f))
                except OSError: pass


def import_image(name, src):
    """Copies the picture in as a PNG (kitty reads PNG files directly), at most 1024 px."""
    if not os.path.isfile(src):
        fail(f"Couldn't find {src}")
    os.makedirs(IMAGES, exist_ok=True)
    with open(src, "rb") as f:
        digest = hashlib.sha1(f.read()).hexdigest()[:10]
    out = os.path.join(IMAGES, digest + ".png")
    if not os.path.isfile(out):
        try:
            from PIL import Image
            with Image.open(src) as im:
                im.seek(0)
                im = im.convert("RGBA")
                im.thumbnail((1024, 1024))
                im.save(out, "PNG")
        except ImportError:
            if subprocess.run(["magick", src + "[0]", "-resize", "1024x1024>", out], capture_output=True).returncode != 0:
                fail("Couldn't read that picture (install python-pillow or imagemagick)")
        except Exception:
            fail("Couldn't read that picture; pick a PNG, JPEG, WebP or GIF")
    return "images/" + os.path.basename(out)


def jsonc_load(text):
    """fastfetch configs are JSON with comments and trailing commas."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    clean = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
    try:
        d = json.loads(clean)
        return d if isinstance(d, dict) else None
    except ValueError:
        return None


def with_image(body, img, preview):
    """The preset with the picture as its logo (or no logo, for a preview: the tile draws the
    picture itself, since the preview is text)."""
    d = jsonc_load(body)
    if d is None:
        return body
    old = d.get("logo") if isinstance(d.get("logo"), dict) else {}
    pad = old.get("padding") if isinstance(old.get("padding"), dict) else {"top": 1, "right": 3}
    d["logo"] = {"type": "none"} if preview else {
        "type": "kitty-direct", "source": img["path"], "width": img["width"],
        "preserveAspectRatio": True, "padding": pad}
    return json.dumps(d, indent=2, ensure_ascii=False) + "\n"


def rendered(name, pal=None, preview=False):
    body = fill(read(path_of(name)), pal or palette())
    img = image_of(name)
    if img:
        body = with_image(body, img, preview)
    return (f"{MARK}: the \"{name}\" preset in your theme colours, rewritten when the theme changes.\n"
            f"// Edit it in Settings -> Theme -> Fastfetchlings ({path_of(name)}), not here.\n" + body)


def render(name=None):
    name = name or get_active()
    if not name or not exists(name):
        return
    current = read(TARGET)
    if current and MARK not in current and not os.path.exists(TARGET + ".pre-monolith"):
        shutil.copyfile(TARGET, TARGET + ".pre-monolith")
    write(TARGET, rendered(name))


# --- preview: run fastfetch on the rendered preset and turn its colour codes into HTML ---------
SGR = re.compile(r"\x1b\[([0-9;]*)m")
BASIC = ["#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de"]
BRIGHT = ["#585b70", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8"]


def to_html(ansi, pal):
    basic = [pal.get(k, d) for k, d in zip(["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1"], BASIC)]
    bright = [pal.get(k, d) for k, d in zip(["surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"], BRIGHT)]
    ansi = re.sub(r"\x1b\[[0-9;?]*[A-LN-Za-ln-z]", "", ansi)      # cursor moves etc: not needed
    ansi = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)", "", ansi)    # OSC (links, titles)
    lines = []
    fg = bg = None
    bold = False
    for raw in ansi.replace("\r", "").split("\n"):
        out = []
        pos = 0
        for m in list(SGR.finditer(raw)) + [None]:
            chunk = raw[pos:m.start() if m else len(raw)]
            if chunk:
                style = []
                if fg: style.append("color:" + fg)
                if bg: style.append("background-color:" + bg)
                t = html.escape(chunk).replace(" ", "&nbsp;")
                if bold: t = "<b>" + t + "</b>"
                out.append(f'<span style="{";".join(style)}">{t}</span>' if style else t)
            if not m:
                break
            pos = m.end()
            codes = [int(x) if x.isdigit() else 0 for x in m.group(1).split(";")] if m.group(1) else [0]
            i = 0
            while i < len(codes):
                c = codes[i]
                if c == 0: fg = bg = None; bold = False
                elif c == 1: bold = True
                elif c == 22: bold = False
                elif 30 <= c <= 37: fg = basic[c - 30]
                elif 90 <= c <= 97: fg = bright[c - 90]
                elif 40 <= c <= 47: bg = basic[c - 40]
                elif 100 <= c <= 107: bg = bright[c - 100]
                elif c == 39: fg = None
                elif c == 49: bg = None
                elif c in (38, 48) and i + 1 < len(codes):
                    if codes[i + 1] == 2 and i + 4 < len(codes):
                        col = "#%02x%02x%02x" % tuple(max(0, min(255, v)) for v in codes[i + 2:i + 5])
                        i += 4
                    elif codes[i + 1] == 5 and i + 2 < len(codes):
                        n = codes[i + 2]
                        col = (basic + bright)[n] if n < 16 else None
                        i += 2
                    else:
                        col = None
                    if c == 38: fg = col
                    else: bg = col
                i += 1
        lines.append("".join(out))
    while lines and not re.sub(r"<[^>]+>|&nbsp;", "", lines[-1]).strip():
        lines.pop()
    while lines and not re.sub(r"<[^>]+>|&nbsp;", "", lines[0]).strip():
        lines.pop(0)
    return "<br>".join(lines)


TERMINALS = ("kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "xterm")


def preview_cmd():
    """fastfetch names the shell and terminal after the processes above it, which here would be
    this script and the Settings app. So it runs inside your login shell, under a stand-in named
    after your terminal (a `timeout` symlink, which stays around as the parent)."""
    try:
        import pwd
        shell = pwd.getpwuid(os.getuid()).pw_shell or "/bin/sh"
    except (ImportError, KeyError):
        shell = os.environ.get("SHELL", "/bin/sh")
    if not shutil.which(shell):
        shell = "/bin/sh"
    term = next((t for t in TERMINALS if shutil.which(t)), "")
    run = [shell] + (["--no-config"] if os.path.basename(shell) == "fish" else []) + ["-c", 'fastfetch --pipe false -c "$FF_PRESET"']
    timeout = shutil.which("timeout")
    if not term or not timeout:
        return run
    stand_in = os.path.join(CACHE, "bin", term)
    try:
        os.makedirs(os.path.dirname(stand_in), exist_ok=True)
        if os.path.realpath(stand_in) != os.path.realpath(timeout):
            if os.path.lexists(stand_in): os.unlink(stand_in)
            os.symlink(timeout, stand_in)
    except OSError:
        return run
    return [stand_in, "15"] + run


def preview(name, pal, key):
    os.makedirs(CACHE, exist_ok=True)
    cached = os.path.join(CACHE, hashlib.sha1((name + key).encode()).hexdigest() + ".html")
    if os.path.isfile(cached):
        return read(cached)
    if not shutil.which("fastfetch"):
        return ""
    fd, tmp = tempfile.mkstemp(suffix=".jsonc")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(rendered(name, pal, preview=True))
        r = subprocess.run(preview_cmd(), capture_output=True, text=True, timeout=20,
                           env=dict(os.environ, COLUMNS="200", FF_PRESET=tmp), cwd=HOME)
        out = to_html(r.stdout, pal) if r.returncode == 0 else ""
        err = "" if r.returncode == 0 else (r.stderr.strip().splitlines() or ["fastfetch couldn't read this preset"])[-1]
    except (OSError, subprocess.TimeoutExpired) as e:
        out, err = "", str(e)
    finally:
        os.unlink(tmp)
    if err:
        return '<span style="color:' + pal.get("red", "#f38ba8") + '">' + html.escape(err) + "</span>"
    write(cached, out)
    return out


def cmd_list():
    pal = palette()
    ns = names()
    colours = "v2:" + json.dumps(pal, sort_keys=True)   # bump v2 when previews are made differently

    def key(n):
        st = os.stat(path_of(n))
        return f"{st.st_mtime_ns}:{st.st_size}:{json.dumps(image_of(n))}:{colours}"

    def one(n):
        return preview(n, pal, key(n))

    with ThreadPoolExecutor(max_workers=4) as ex:
        previews = list(ex.map(one, ns))
    # drop previews that no preset uses any more
    keep = {hashlib.sha1((n + key(n)).encode()).hexdigest() + ".html" for n in ns}
    for f in os.listdir(CACHE) if os.path.isdir(CACHE) else []:
        if f not in keep and f.endswith(".html"):
            try: os.unlink(os.path.join(CACHE, f))
            except OSError: pass
    print(json.dumps({"active": get_active(), "dir": PRESETS, "fastfetch": bool(shutil.which("fastfetch")),
                      "presets": [dict({"name": n, "path": path_of(n), "preview": p, "image": "", "imageWidth": IMAGE_WIDTH},
                                       **({"image": im["path"], "imageWidth": im["width"]} if (im := image_of(n)) else {}))
                                  for n, p in zip(ns, previews)]}))


def free_name(base):
    if not exists(base):
        return base
    i = 2
    while exists(f"{base} {i}"):
        i += 1
    return f"{base} {i}"


def terminal_cmd(title, argv):
    for term, pre in (("kitty", ["kitty", "--class", "monolith-fastfetch", "--title", title, "--"]),
                      ("foot", ["foot", "--app-id", "monolith-fastfetch", "--title", title]),
                      ("alacritty", ["alacritty", "--class", "monolith-fastfetch", "--title", title, "-e"]),
                      ("ghostty", ["ghostty", "--title=" + title, "-e"]),
                      ("wezterm", ["wezterm", "start", "--class", "monolith-fastfetch", "--"]),
                      ("konsole", ["konsole", "-e"]),
                      ("xterm", ["xterm", "-T", title, "-e"])):
        if shutil.which(term):
            return pre + argv
    fail("No terminal found (kitty, foot, alacritty, ghostty, wezterm, konsole or xterm)")


def editor():
    for e in (os.environ.get("VISUAL"), os.environ.get("EDITOR"), "nano", "micro", "nvim", "vim", "vi"):
        if e and shutil.which(e.split()[0]):
            return e
    fail("No text editor found: install nano, or set $EDITOR")


def cmd_edit(name):
    if not exists(name):
        fail(f'There is no preset called "{name}"')
    me = os.path.abspath(__file__)
    script = ('$MONOLITH_EDITOR "$1"; python3 "$2" show "$3"')
    argv = ["sh", "-c", script, "_", path_of(name), me, name]
    env = dict(os.environ, MONOLITH_EDITOR=editor())
    # waits for the terminal, so Settings refreshes the tiles when you close it
    sys.exit(subprocess.run(terminal_cmd(f"Fastfetchlings: {name}", argv), env=env).returncode)


def cmd_show(name):
    if get_active() == name:
        render(name)
    fd, tmp = tempfile.mkstemp(suffix=".jsonc")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(rendered(name))
    print("\x1b[2J\x1b[H", end="", flush=True)
    r = subprocess.run(["fastfetch", "-c", tmp])
    os.unlink(tmp)
    if r.returncode != 0:
        print("\nfastfetch couldn't read this preset; fix it and save again.")
    try:
        input(f"\n\x1b[2m\"{name}\" saved. Press Enter to close\x1b[0m")
    except (EOFError, KeyboardInterrupt):
        pass


def main():
    a = sys.argv[1:]
    if not a:
        fail(__doc__)
    cmd = a[0]
    seed()
    if cmd == "list":
        cmd_list()
    elif cmd == "render":
        render()
    elif cmd == "apply" and len(a) > 1:
        n = check_name(a[1])
        if not exists(n): fail(f'There is no preset called "{n}"')
        write(ACTIVE, n + "\n")
        render(n)
    elif cmd == "new":
        n = free_name("New preset")
        shutil.copyfile(os.path.join(ASSETS, "new.jsonc"), path_of(n))
        print(n)
    elif cmd == "duplicate" and len(a) > 1:
        src = check_name(a[1])
        if not exists(src): fail(f'There is no preset called "{src}"')
        n = free_name(src + " copy")
        shutil.copyfile(path_of(src), path_of(n))
        im = images()
        if src in im:
            im[n] = dict(im[src])
            save_images(im)
        print(n)
    elif cmd == "rename" and len(a) > 2:
        old, new = check_name(a[1]), check_name(a[2])
        if not exists(old): fail(f'There is no preset called "{old}"')
        if old == new: return
        if exists(new) and old.lower() != new.lower(): fail(f'There is already a preset called "{new}"')
        was_active = get_active() == old
        os.replace(path_of(old), path_of(new))
        im = images()
        if old in im:
            im[new] = im.pop(old)
            save_images(im)
        if was_active:
            write(ACTIVE, new + "\n")
            render(new)
    elif cmd == "delete" and len(a) > 1:
        n = check_name(a[1])
        if len(names()) <= 1: fail("Keep at least one preset")
        was_active = get_active() == n
        try: os.unlink(path_of(n))
        except FileNotFoundError: pass
        im = images()
        if im.pop(n, None) is not None:
            save_images(im)
            drop_unused_images()
        if was_active:
            write(ACTIVE, get_active() + "\n")
            render()
    elif cmd == "set-image" and len(a) > 2:
        n = check_name(a[1])
        if not exists(n): fail(f'There is no preset called "{n}"')
        im = images()
        old = im.get(n) if isinstance(im.get(n), dict) else {}
        width = int(a[3]) if len(a) > 3 and a[3].isdigit() else int(old.get("width", IMAGE_WIDTH))
        im[n] = {"file": import_image(n, a[2]), "width": max(8, min(120, width))}
        save_images(im)
        drop_unused_images()
        if get_active() == n: render(n)
    elif cmd == "image-size" and len(a) > 2 and a[2].isdigit():
        n = check_name(a[1])
        im = images()
        if isinstance(im.get(n), dict):
            im[n]["width"] = max(8, min(120, int(a[2])))
            save_images(im)
            if get_active() == n: render(n)
    elif cmd == "clear-image" and len(a) > 1:
        n = check_name(a[1])
        im = images()
        if im.pop(n, None) is not None:
            save_images(im)
            drop_unused_images()
            if get_active() == n: render(n)
    elif cmd == "edit" and len(a) > 1:
        cmd_edit(check_name(a[1]))
    elif cmd == "show" and len(a) > 1:
        cmd_show(a[1])
    else:
        fail(__doc__)


if __name__ == "__main__":
    main()
