#!/usr/bin/env python3
"""App theming (Settings -> Theme -> Apps): makes apps follow Monolith's colours.

matugen writes colour files for each app into ~/.local/state/monolith/apps/ on every theme
change; this hooks them into the apps you switch on, and unhooks them when you switch off.
Your config files keep everything you wrote: Monolith only adds a marked block (or, for btop
and Qt, changes one setting and remembers the old value to put back).

GTK also keeps the system's light/dark setting (what portals and Flatpak apps go by) in step
with the theme. Qt also writes a KDE colour scheme (Monolith.colors) for KDE / Kirigami apps
(WiVRn, Dolphin...), which ignore qt6ct's colours. Flatpak lets sandboxed apps read those colour
files and drops per-app theme overrides that pin them to another theme (a light one, often).

  app_theming.py status            JSON: each app, whether it's installed and switched on
  app_theming.py enable <app>
  app_theming.py disable <app>
  app_theming.py sync              after a theme change: refresh what was copied (GTK, Qt)
"""
import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
DATA = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
APPS = os.path.join(os.environ.get("QS_STATE_DIR", os.path.join(HOME, ".local/state/monolith")), "apps")
ENABLED = os.path.join(APPS, "enabled.json")

TARGETS = ["gtk", "qt", "flatpak", "foot", "alacritty", "btop", "rofi"]


def have(cmd):
    return shutil.which(cmd) is not None


def available(t):
    return {
        "gtk": True,
        "qt": have("qt6ct") or have("qt5ct") or os.path.isdir(os.path.join(CONF, "qt6ct")) or os.path.isdir(os.path.join(CONF, "qt5ct")),
        "flatpak": have("flatpak"),
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


# ---- colours, light/dark ----

def gtk_colors():
    """the @define-color values matugen wrote for GTK: the richest colour file"""
    return dict(re.findall(r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", read(os.path.join(APPS, "gtk.css"))))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(rgb(a), rgb(b)))


def is_dark():
    c = gtk_colors().get("window_bg_color")
    if not c:
        return True
    r, g, b = rgb(c)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5


def gsettings(key, value=None):
    if not have("gsettings"):
        return None
    if value is None:
        r = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key], capture_output=True, text=True)
        return r.stdout.strip().strip("'") if r.returncode == 0 else None
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], capture_output=True)


def gtk_theme_dir(name):
    return any(os.path.isdir(os.path.join(d, name)) for d in
               (os.path.join(DATA, "themes"), os.path.join(HOME, ".themes"), "/usr/share/themes", "/usr/local/share/themes"))


def follow_light_dark(st):
    """the system light/dark setting (portals, libadwaita, Flatpak apps) and, with adw-gtk3
    installed, the GTK 3 theme, matching the Monolith theme"""
    if "gsettings_prev" not in st:
        st["gsettings_prev"] = {k: gsettings(k) for k in ("color-scheme", "gtk-theme")}
    dark = is_dark()
    gsettings("color-scheme", "prefer-dark" if dark else "default")
    theme = gsettings("gtk-theme") or ""
    if theme.startswith("adw-gtk3") or not theme or theme.startswith("Adwaita"):
        want = "adw-gtk3-dark" if dark else "adw-gtk3"
        if gtk_theme_dir(want):
            gsettings("gtk-theme", want)


def restore_light_dark(st):
    for k, v in (st.pop("gsettings_prev", None) or {}).items():
        if v:
            gsettings(k, f"'{v}'" if k == "gtk-theme" else v)


# ---- KDE colour scheme (KDE / Kirigami apps) ----

KDE_SCHEME = os.path.join(DATA, "color-schemes", "Monolith.colors")
KDE_GLOBALS = os.path.join(CONF, "kdeglobals")


def kde_scheme():
    """Monolith's colours as a KDE colour scheme: {section: {key: "r,g,b"}}"""
    c = gtk_colors()
    if "window_bg_color" not in c:
        raise SystemExit(os.path.join(APPS, "gtk.css") + " doesn't exist yet: change the theme or wallpaper once so Monolith writes it")
    win, fg = c["window_bg_color"], c["window_fg_color"]
    view, vfg = c.get("view_bg_color", win), c.get("view_fg_color", fg)
    head, hfg = c.get("headerbar_bg_color", win), c.get("headerbar_fg_color", fg)
    card, pop, pfg = c.get("card_bg_color", view), c.get("popover_bg_color", view), c.get("popover_fg_color", fg)
    acc, afg = c.get("accent_bg_color", fg), c.get("accent_fg_color", win)

    def group(bg, text, alt=0.05):
        return {"BackgroundNormal": bg, "BackgroundAlternate": mix(bg, text, alt), "ForegroundNormal": text,
                "ForegroundInactive": mix(text, bg, 0.4), "ForegroundActive": acc, "ForegroundLink": acc,
                "ForegroundVisited": mix(acc, text, 0.35), "ForegroundNegative": "#e06c75",
                "ForegroundNeutral": "#e5a050", "ForegroundPositive": "#7fc28a", "DecorationFocus": acc,
                "DecorationHover": mix(acc, bg, 0.3)}

    sel = group(acc, afg, 0.15)
    sel["ForegroundActive"] = sel["ForegroundLink"] = afg
    out = {"Colors:Window": group(win, fg), "Colors:View": group(view, vfg, 0.04), "Colors:Button": group(card, fg),
           "Colors:Selection": sel, "Colors:Tooltip": group(pop, pfg), "Colors:Complementary": group(head, hfg),
           "Colors:Header": group(head, hfg), "Colors:Header][Inactive": group(win, fg)}
    out = {k: {kk: ",".join(map(str, rgb(vv))) for kk, vv in v.items()} for k, v in out.items()}
    out["WM"] = {"activeBackground": ",".join(map(str, rgb(head))), "activeForeground": ",".join(map(str, rgb(hfg))),
                 "inactiveBackground": ",".join(map(str, rgb(win))), "inactiveForeground": ",".join(map(str, rgb(mix(fg, win, 0.4))))}
    return out


def ini_sections(text):
    """kdeglobals-style ini as [(header, [lines])]; header None for lines before the first section"""
    out = [[None, []]]
    for line in text.splitlines():
        m = re.match(r"^\[(.*)\]\s*$", line)
        if m:
            out.append([m.group(1), []])
        else:
            out[-1][1].append(line)
    return out


def ini_text(sections):
    parts = []
    for head, lines in sections:
        while lines and not lines[-1].strip():
            lines = lines[:-1]
        if head is None:
            if lines:
                parts.append("\n".join(lines))
            continue
        parts.append("\n".join([f"[{head}]"] + lines))
    return "\n\n".join(parts) + "\n"


def ini_set(sections, head, key, value):
    """sets key in [head] (value None removes it): the old value or None"""
    sec = next((s for s in sections if s[0] == head), None)
    if sec is None:
        if value is not None:
            sections.append([head, [f"{key}={value}"]])
        return None
    for i, line in enumerate(sec[1]):
        if line.split("=", 1)[0].strip() == key:
            old = line.split("=", 1)[1] if "=" in line else ""
            if value is None:
                del sec[1][i]
            else:
                sec[1][i] = f"{key}={value}"
            return old
    if value is not None:
        sec[1].append(f"{key}={value}")
    return None


def apply_kde(st):
    scheme = kde_scheme()
    body = ["[General]", "ColorScheme=Monolith", "Name=Monolith", "", "[KDE]", "contrast=4"]
    for head, keys in scheme.items():
        body += ["", f"[{head}]"] + [f"{k}={v}" for k, v in keys.items()]
    write(KDE_SCHEME, "\n".join(body) + "\n")
    # kdeglobals: KDE apps outside Plasma pick the scheme named in [UiSettings]; apps on KDE's own
    # platform theme (and KDE Flatpaks) read the colour groups straight from kdeglobals
    remember(KDE_GLOBALS, st)
    secs = ini_sections(read(KDE_GLOBALS))
    first = "kde_prev" not in st
    prev = st.setdefault("kde_prev", {"groups": {}, "ui": None, "general": None})
    for head, keys in scheme.items():
        sec = next((s for s in secs if s[0] == head), None)
        if first:
            prev["groups"][head] = sec[1] if sec else None
        if sec is None:
            secs.append([head, []])
            sec = secs[-1]
        sec[1] = [f"{k}={v}" for k, v in keys.items()]
    ui = ini_set(secs, "UiSettings", "ColorScheme", "Monolith")
    gen = ini_set(secs, "General", "ColorScheme", "Monolith")
    if first:
        prev["ui"], prev["general"] = ui, gen
    write(KDE_GLOBALS, ini_text(secs))


def unapply_kde(st):
    prev = st.pop("kde_prev", None)
    if prev and os.path.isfile(KDE_GLOBALS):
        secs = ini_sections(read(KDE_GLOBALS))
        for head, lines in prev["groups"].items():
            sec = next((s for s in secs if s[0] == head), None)
            if lines is None:
                secs = [s for s in secs if s[0] != head]
            elif sec:
                sec[1] = lines
            else:
                secs.append([head, lines])
        ini_set(secs, "UiSettings", "ColorScheme", prev["ui"])
        ini_set(secs, "General", "ColorScheme", prev["general"])
        secs = [s for s in secs if s[0] is None or any(l.strip() for l in s[1])]
        write(KDE_GLOBALS, ini_text(secs))
    restore_file(KDE_GLOBALS, st)
    if os.path.isfile(KDE_SCHEME):
        os.remove(KDE_SCHEME)


# ---- Flatpak ----

FLATPAK_OVERRIDES = os.path.join(DATA, "flatpak", "overrides")
# what sandboxed apps may read: Monolith's GTK colours, the KDE colour scheme and kdeglobals
FLATPAK_FILES = ["xdg-config/gtk-3.0:ro", "xdg-config/gtk-4.0:ro", "xdg-config/kdeglobals:ro", "xdg-data/color-schemes:ro"]


def flatpak(*args):
    return subprocess.run(["flatpak", *args], capture_output=True, text=True)


def global_override_lines():
    text = read(os.path.join(FLATPAK_OVERRIDES, "global"))
    m = re.search(r"(?m)^filesystems=(.*)$", text)
    return m.group(1).split(";") if m else []


def apply_flatpak(st):
    # files: only the ones that weren't shared already are noted, so switching off leaves the rest
    have_fs = set(global_override_lines())
    added = st.setdefault("flatpak_fs", [])
    for f in FLATPAK_FILES:
        if f not in have_fs and f not in added:
            added.append(f)
    r = flatpak("override", "--user", *[f"--filesystem={f}" for f in added])
    if r.returncode != 0:
        raise SystemExit("flatpak override failed: " + r.stderr.strip())
    # per-app overrides that pin GTK_THEME (PortProton ships with Breeze, a light theme) win over
    # the system theme: drop them, remembering each value
    pinned = st.setdefault("flatpak_gtk_theme", {})
    if os.path.isdir(FLATPAK_OVERRIDES):
        for app in os.listdir(FLATPAK_OVERRIDES):
            if app == "global":
                continue
            m = re.search(r"(?m)^GTK_THEME=(.+)$", read(os.path.join(FLATPAK_OVERRIDES, app)))
            if m and m.group(1).strip():
                pinned.setdefault(app, m.group(1).strip())
                path = os.path.join(FLATPAK_OVERRIDES, app)
                write(path, re.sub(r"(?m)^GTK_THEME=.*\n?", "", read(path)))
    # GTK 3 apps in Flatpak need the system's GTK theme as a Flatpak extension (tried once per
    # theme: a sync runs on every theme change)
    theme = gsettings("gtk-theme")
    tried = st.setdefault("flatpak_theme_tried", [])
    if theme and theme not in tried and flatpak("info", f"org.gtk.Gtk3theme.{theme}").returncode != 0:
        tried.append(theme)
        flatpak("install", "--user", "-y", "--noninteractive", "flathub", f"org.gtk.Gtk3theme.{theme}")


def unapply_flatpak(st):
    added = st.pop("flatpak_fs", [])
    if added:
        flatpak("override", "--user", *[f"--nofilesystem={f}" for f in added])
        # --nofilesystem leaves a "!path" entry; without it the override is just gone
        path = os.path.join(FLATPAK_OVERRIDES, "global")
        text = read(path)
        m = re.search(r"(?m)^filesystems=(.*)$", text)
        if m:
            gone = {f.split(":")[0] for f in added}
            keep = [f for f in m.group(1).split(";") if f and f.lstrip("!").split(":")[0] not in gone]
            end = m.end() + (0 if keep or m.end() >= len(text) else 1)
            text = text[:m.start()] + ("filesystems=" + ";".join(keep) + ";" if keep else "") + text[end:]
            write(path, text)
    st.pop("flatpak_theme_tried", None)
    for app, theme in st.pop("flatpak_gtk_theme", {}).items():
        flatpak("override", "--user", f"--env=GTK_THEME={theme}", app)


GTK_START, GTK_END = "/* >>> Monolith colours (Settings -> Theme -> Apps) >>> */", "/* <<< Monolith colours <<< */"
HASH_START, HASH_END = "# >>> Monolith colours (Settings -> Theme -> Apps) >>>", "# <<< Monolith colours <<<"


def apply(t, st):
    src = os.path.join(APPS, {"gtk": "gtk.css", "qt": "qt.conf", "flatpak": "gtk.css", "foot": "foot.ini", "alacritty": "alacritty.toml", "btop": "btop.theme", "rofi": "rofi.rasi"}[t])
    if not os.path.isfile(src):
        raise SystemExit(f"{src} doesn't exist yet: change the theme or wallpaper once so Monolith writes it")
    if t == "gtk":
        for v in ("gtk-3.0", "gtk-4.0"):
            set_block(os.path.join(CONF, v, "gtk.css"), read(src), GTK_START, GTK_END, st)
        follow_light_dark(st)
    elif t == "flatpak":
        apply_flatpak(st)
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
        apply_kde(st)
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
        restore_light_dark(st)
    elif t == "flatpak":
        unapply_flatpak(st)
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
        unapply_kde(st)
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
