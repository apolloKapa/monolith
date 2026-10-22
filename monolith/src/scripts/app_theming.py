#!/usr/bin/env python3
"""App theming (Settings -> Theme -> Apps): makes apps follow Monolith's colours.

matugen writes colour files for each app into ~/.local/state/monolith/apps/ on every theme
change; this hooks them into the apps you switch on, and unhooks them when you switch off.
Your config files keep everything you wrote: Monolith only adds a marked block (or, for btop
and Qt, changes one setting and remembers the old value to put back).

  app_theming.py status            JSON: each app, whether it's installed and switched on
  app_theming.py enable <app>
  app_theming.py disable <app>
  app_theming.py sync              after a theme change: refresh what was copied (GTK, Qt)
"""
import json
import os
import re
import shutil
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
APPS = os.path.join(os.environ.get("QS_STATE_DIR", os.path.join(HOME, ".local/state/monolith")), "apps")
ENABLED = os.path.join(APPS, "enabled.json")

TARGETS = ["gtk", "qt", "foot", "alacritty", "btop", "rofi"]


def have(cmd):
    return shutil.which(cmd) is not None


def available(t):
    return {
        "gtk": True,
        "qt": have("qt6ct") or have("qt5ct") or os.path.isdir(os.path.join(CONF, "qt6ct")) or os.path.isdir(os.path.join(CONF, "qt5ct")),
        "foot": have("foot"),
        "alacritty": have("alacritty"),
        "btop": have("btop"),
        "rofi": have("rofi"),
    }[t]


def load_state():
    try:
        return json.load(open(ENABLED))
    except (OSError, ValueError):
        return {}


def save_state(st):
    os.makedirs(APPS, exist_ok=True)
    json.dump(st, open(ENABLED, "w"), indent=2)


def read(p):
    try:
        return open(p, encoding="utf-8").read()
    except OSError:
        return ""


def write(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w", encoding="utf-8").write(text)


def remember(path, st):
    """Notes how a file looked before Monolith first touched it, so switching off can put it back."""
    files = st.setdefault("files", {})
    if path not in files:
        files[path] = {"existed": os.path.lexists(path), "dir_existed": os.path.isdir(os.path.dirname(path)),
                       "link": os.readlink(path) if os.path.islink(path) else None}


def set_block(path, body, start, end, st, at_top=False):
    """Puts `body` between the start/end marker lines in `path` (replacing an old block).
    A file that is a symlink (e.g. GTK 4's gtk.css pointing at a system theme) becomes a small
    file that imports what the link pointed to."""
    remember(path, st)
    if os.path.islink(path):
        target = os.path.realpath(path)
        os.remove(path)
        write(path, f'@import url("file://{target}");\n')
    text = strip_block(read(path), start, end)
    block = f"{start}\n{body.rstrip()}\n{end}\n"
    if at_top:
        text = block + text
    else:
        if text and not text.endswith("\n"):
            text += "\n"
        text += block
    write(path, text)


def strip_block(text, start, end):
    return re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.S)


def restore_file(path, st):
    """After a block was removed: a file Monolith created goes away again once it's empty,
    a replaced symlink comes back."""
    info = st.get("files", {}).pop(path, None)
    if not info:
        return
    if info["link"]:
        if os.path.lexists(path):
            os.remove(path)
        os.symlink(info["link"], path)
    elif not info["existed"] and os.path.isfile(path) and not read(path).strip():
        os.remove(path)
        d = os.path.dirname(path)
        if not info.get("dir_existed", True) and os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)


def unset_block(path, start, end, st):
    if os.path.isfile(path) and not os.path.islink(path):
        write(path, strip_block(read(path), start, end))
    restore_file(path, st)


def set_key(path, key, value, prev_store, st):
    """key=value in an ini-style file; remembers the old value once."""
    text = read(path)
    m = re.search(rf"(?m)^{re.escape(key)}\s*=\s*(.*)$", text)
    if prev_store not in st:
        st[prev_store] = m.group(1) if m else None
    if m:
        text = text[:m.start()] + f"{key}={value}" + text[m.end():]
    else:
        text = text.rstrip() + f"\n{key}={value}\n"
    write(path, text)


def restore_key(path, key, prev):
    text = read(path)
    if not text:
        return
    if prev is None:
        text = re.sub(rf"(?m)^{re.escape(key)}\s*=.*\n?", "", text)
    else:
        text = re.sub(rf"(?m)^{re.escape(key)}\s*=.*$", f"{key}={prev}", text)
    write(path, text)


GTK_START, GTK_END = "/* >>> Monolith colours (Settings -> Theme -> Apps) >>> */", "/* <<< Monolith colours <<< */"
HASH_START, HASH_END = "# >>> Monolith colours (Settings -> Theme -> Apps) >>>", "# <<< Monolith colours <<<"


def apply(t, st):
    src = os.path.join(APPS, {"gtk": "gtk.css", "qt": "qt.conf", "foot": "foot.ini", "alacritty": "alacritty.toml", "btop": "btop.theme", "rofi": "rofi.rasi"}[t])
    if not os.path.isfile(src):
        raise SystemExit(f"{src} doesn't exist yet: change the theme or wallpaper once so Monolith writes it")
    if t == "gtk":
        for v in ("gtk-3.0", "gtk-4.0"):
            set_block(os.path.join(CONF, v, "gtk.css"), read(src), GTK_START, GTK_END, st)
    elif t == "qt":
        for v in ("qt6ct", "qt5ct"):
            d = os.path.join(CONF, v)
            if not os.path.isdir(d) and not have(v):
                continue
            scheme = os.path.join(d, "colors", "monolith.conf")
            write(scheme, read(src))
            conf = os.path.join(d, v + ".conf")
            remember(conf, st)
            if not read(conf):
                write(conf, "[Appearance]\n")
            set_key(conf, "color_scheme_path", scheme, v + "_scheme_prev", st)
            set_key(conf, "custom_palette", "true", v + "_palette_prev", st)
    elif t == "foot":
        set_block(os.path.join(CONF, "foot", "foot.ini"), f"include={src}", HASH_START, HASH_END, st, at_top=True)
    elif t == "alacritty":
        path = os.path.join(CONF, "alacritty", "alacritty.toml")
        rest = strip_block(read(path), HASH_START, HASH_END)
        if re.search(r"(?m)^\s*\[general\]", rest):
            raise SystemExit("alacritty.toml already has a [general] section: add  import = [\"" + src + "\"]  to it yourself")
        set_block(path, f'[general]\nimport = ["{src}"]', HASH_START, HASH_END, st, at_top=True)
    elif t == "btop":
        os.makedirs(os.path.join(CONF, "btop", "themes"), exist_ok=True)
        link = os.path.join(CONF, "btop", "themes", "monolith.theme")
        if os.path.islink(link) or os.path.exists(link):
            os.remove(link)
        os.symlink(src, link)
        conf = os.path.join(CONF, "btop", "btop.conf")
        remember(conf, st)
        text = read(conf)
        m = re.search(r'(?m)^color_theme\s*=\s*(.*)$', text)
        if "btop_prev" not in st:
            st["btop_prev"] = m.group(1) if m else None
        line = 'color_theme = "monolith"'
        text = text[:m.start()] + line + text[m.end():] if m else text.rstrip() + ("\n" if text else "") + line + "\n"
        write(conf, text)
    elif t == "rofi":
        set_block(os.path.join(CONF, "rofi", "config.rasi"), f'@import "{src}"', GTK_START, GTK_END, st)


def unapply(t, st):
    if t == "gtk":
        for v in ("gtk-3.0", "gtk-4.0"):
            unset_block(os.path.join(CONF, v, "gtk.css"), GTK_START, GTK_END, st)
    elif t == "qt":
        for v in ("qt6ct", "qt5ct"):
            conf = os.path.join(CONF, v, v + ".conf")
            if v + "_scheme_prev" in st:
                restore_key(conf, "color_scheme_path", st.pop(v + "_scheme_prev"))
                restore_key(conf, "custom_palette", st.pop(v + "_palette_prev", None))
            scheme = os.path.join(CONF, v, "colors", "monolith.conf")
            if os.path.isfile(scheme):
                os.remove(scheme)
            restore_file(conf, st)
    elif t == "foot":
        unset_block(os.path.join(CONF, "foot", "foot.ini"), HASH_START, HASH_END, st)
    elif t == "alacritty":
        unset_block(os.path.join(CONF, "alacritty", "alacritty.toml"), HASH_START, HASH_END, st)
    elif t == "btop":
        conf = os.path.join(CONF, "btop", "btop.conf")
        prev = st.pop("btop_prev", None)
        text = read(conf)
        if text:
            if prev:
                text = re.sub(r'(?m)^color_theme\s*=.*$', f"color_theme = {prev}", text)
            else:
                text = re.sub(r'(?m)^color_theme\s*=.*\n?', "", text)
            write(conf, text)
        restore_file(conf, st)
        link = os.path.join(CONF, "btop", "themes", "monolith.theme")
        if os.path.islink(link):
            os.remove(link)
    elif t == "rofi":
        unset_block(os.path.join(CONF, "rofi", "config.rasi"), GTK_START, GTK_END, st)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    st = load_state()
    on = st.setdefault("enabled", [])
    if cmd == "status":
        print(json.dumps({t: {"available": available(t), "enabled": t in on} for t in TARGETS}))
    elif cmd in ("enable", "disable") and len(sys.argv) > 2 and sys.argv[2] in TARGETS:
        t = sys.argv[2]
        if cmd == "enable":
            apply(t, st)
            if t not in on:
                on.append(t)
        else:
            unapply(t, st)
            if t in on:
                on.remove(t)
        save_state(st)
    elif cmd == "sync":
        for t in list(on):
            try:
                apply(t, st)
            except SystemExit:
                pass
        save_state(st)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
