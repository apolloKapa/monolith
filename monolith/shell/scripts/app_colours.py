#!/usr/bin/env python3
"""App colours (Settings -> App colours): apps take the shell's colours (as the shell shows them).

    app_colours.py apply TARGET...   write the colours for these targets: kitty gtk qt
    app_colours.py off TARGET        take them away again (your own settings stay)
    app_colours.py mode dark|light [--palette-qt]
                                     dark or light for every app (Appearance → Apps follow dark or
                                     light), even with the colours above off: GTK 3 apps get
                                     adw-gtk3(-dark) and the prefer-dark flag, GTK 4 the colour
                                     scheme, Qt apps a plain dark or light qt6ct/qt5ct palette (with
                                     the accent for selections). --palette-qt: Qt has the shell's
                                     colours already (the qt target), so it's left alone.

kitty: ~/.config/kitty/colors.conf (kitty.conf includes it), reloaded in open windows.
gtk:   a marked block in ~/.config/gtk-3.0/gtk.css and gtk-4.0/gtk.css (GTK 3 and libadwaita
       colour names), the rest of those files is yours.
qt:    a qt6ct/qt5ct colour scheme, picked in their config (apps need QT_QPA_PLATFORMTHEME=qt6ct).
The palette is the shell's own (~/.local/state/monolith/shell-palette.json: the wallpaper's or a
colour theme's), else the wallpaper's (next-palette.json); the mode the shell's.
"""
import configparser
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or HOME + "/.config"
STATE = (os.environ.get("XDG_STATE_HOME") or HOME + "/.local/state") + "/monolith"
START, END = "/* monolith colours: start (Settings -> App colours writes this block) */", "/* monolith colours: end */"


def palette():
    try:
        mode = json.load(open(CONF + "/monolith/next.json")).get("theme", {}).get("mode", "dark")
    except (OSError, ValueError):
        mode = "dark"
    src = STATE + "/shell-palette.json"
    data = json.load(open(src if os.path.exists(src) else STATE + "/next-palette.json"))
    roles = data.get("colors", {})
    # a colour theme's palette says itself whether it's dark or light (Twilight: light apps)
    if data.get("mode") in ("dark", "light"):
        mode = data["mode"]
    out = {}
    for k, v in roles.items():
        pick = v.get(mode) or v.get("default") or {}
        if isinstance(pick, dict) and pick.get("color"):
            out[k] = pick["color"]
    return out, mode


def mix(a, b, t):
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(pa, pb))


def luminance(h):
    v = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    v = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]


def readable(col, bg, ratio=4.5):
    """col darkened just enough to be read on a light background (WCAG contrast ratio)."""
    lb = luminance(bg)
    for i in range(21):
        out = mix(col, "#000000", i * 0.05)
        if (lb + 0.05) / (luminance(out) + 0.05) >= ratio:
            return out
    return out


def kitty(c, mode):
    bg, fg = c["surface"], c["on_surface"]
    # the 16 terminal colours: tinted towards the palette, readable on its background
    base = ["#000000", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#dcdfe4"]
    norm = [mix(b, c["primary"], 0.25) for b in base]
    norm[0], norm[7] = c.get("surface_container_highest", bg), c.get("on_surface_variant", fg)
    bright = [mix(x, "#ffffff" if mode == "dark" else "#000000", 0.2) for x in norm]
    bright[0] = c.get("outline", bright[0])
    # white and bright white: near the text colour, and the text colour itself (a muted role made
    # them grey, so anything printed in white, like fastfetch in its own colours, came out grey).
    # (a light theme keeps them grey: white text wouldn't show on its background)
    if mode == "dark":
        norm[7] = mix(c.get("on_surface_variant", fg), fg, 0.65)
        bright[7] = fg
    else:
        # (the colours are made for dark terminals: on a light one they came out pale, a green
        # prompt at 2.3:1; each is darkened just until it reads)
        for i in range(1, 7):
            norm[i], bright[i] = readable(norm[i], bg), readable(bright[i], bg)
    lines = ["# Monolith: the shell's colours (Settings -> App colours). Rewritten on every change.",
             "background " + bg, "foreground " + fg, "cursor " + c["primary"], "cursor_text_color " + bg,
             "selection_background " + c["primary_container"], "selection_foreground " + c["on_primary_container"],
             "url_color " + c["tertiary"], "active_border_color " + c["primary"], "inactive_border_color " + c["outline_variant"],
             "active_tab_background " + c["primary"], "active_tab_foreground " + c["on_primary"],
             "inactive_tab_background " + c["surface_container"], "inactive_tab_foreground " + c["on_surface_variant"]]
    lines += ["color%d %s" % (i, v) for i, v in enumerate(norm + bright)]
    os.makedirs(CONF + "/kitty", exist_ok=True)
    open(CONF + "/kitty/colors.conf", "w").write("\n".join(lines) + "\n")
    conf = CONF + "/kitty/kitty.conf"
    if os.path.exists(conf) and not re.search(r"^\s*include\s+(\./|~/\.config/kitty/)?colors\.conf", open(conf).read(), re.M):
        open(conf, "a").write("\n# Monolith's colours (Settings -> App colours)\ninclude colors.conf\n")
    subprocess.run(["pkill", "-USR1", "-x", "kitty"], stderr=subprocess.DEVNULL)


def gtk_block(c):
    pairs = {
        "accent_color": c["primary"], "accent_bg_color": c["primary"], "accent_fg_color": c["on_primary"],
        "window_bg_color": c["surface"], "window_fg_color": c["on_surface"],
        "view_bg_color": c["surface_container_low"], "view_fg_color": c["on_surface"],
        "headerbar_bg_color": c["surface_container"], "headerbar_fg_color": c["on_surface"],
        "sidebar_bg_color": c["surface_container_low"], "sidebar_fg_color": c["on_surface"],
        "card_bg_color": c["surface_container"], "card_fg_color": c["on_surface"],
        "popover_bg_color": c["surface_container_high"], "popover_fg_color": c["on_surface"],
        "dialog_bg_color": c["surface_container_high"], "dialog_fg_color": c["on_surface"],
        "destructive_color": c["error"], "destructive_bg_color": c["error"], "destructive_fg_color": c["on_error"],
        # GTK 3 themes (Adwaita) read these
        "theme_bg_color": c["surface"], "theme_fg_color": c["on_surface"], "theme_base_color": c["surface_container_low"],
        "theme_text_color": c["on_surface"], "theme_selected_bg_color": c["primary"], "theme_selected_fg_color": c["on_primary"],
    }
    return START + "\n" + "\n".join("@define-color %s %s;" % kv for kv in pairs.items()) + "\n" + END


def set_block(path, block):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = open(path).read() if os.path.exists(path) else ""
    text = re.sub(re.escape(START) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    # the block the earlier shell wrote, replaced the same way
    text = re.sub(r"/\* >>> Monolith colours.*?/\* <<< Monolith colours <<< \*/\n?", "", text, flags=re.S)
    if block:
        text = block + "\n" + text
    open(path, "w").write(text)


def gtk(c, on=True):
    for v in ("gtk-3.0", "gtk-4.0"):
        set_block(CONF + "/" + v + "/gtk.css", gtk_block(c) if on else "")


def qt(c, on=True):
    # QPalette roles, in the order qt6ct/qt5ct expect
    roles = [c["on_surface"], c["surface_container_high"], c["surface_container_highest"], c["surface_container_high"],
             c["surface_container_lowest"], c["surface_container"], c["on_surface"], "#ffffff", c["on_surface"],
             c["surface_container_low"], c["surface"], "#000000", c["primary"], c["on_primary"], c["primary"],
             c["tertiary"], c["surface_container"], "#000000", c["surface_container_highest"], c["on_surface"], c["outline"]]
    disabled = [mix(x, c["surface"], 0.5) for x in roles]
    for app in ("qt6ct", "qt5ct"):
        d = CONF + "/" + app
        scheme = d + "/colors/Monolith.conf"
        cfg_path = d + "/" + app + ".conf"
        if not on:
            if os.path.exists(scheme):
                os.remove(scheme)
            continue
        os.makedirs(d + "/colors", exist_ok=True)
        open(scheme, "w").write("[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n"
                                % (", ".join(roles), ", ".join(disabled), ", ".join(roles)))
        cp = configparser.RawConfigParser()
        cp.optionxform = str
        if os.path.exists(cfg_path):
            cp.read(cfg_path)
        if not cp.has_section("Appearance"):
            cp.add_section("Appearance")
        cp.set("Appearance", "color_scheme_path", scheme)
        cp.set("Appearance", "custom_palette", "true")
        with open(cfg_path, "w") as f:
            cp.write(f, space_around_delimiters=False)


# plain greys for Qt in either mode (only the accent comes from the palette)
GREYS = {
    "dark": {"surface": "#1e1f22", "surface_container_lowest": "#141517", "surface_container_low": "#1a1b1e",
             "surface_container": "#232428", "surface_container_high": "#2b2c31", "surface_container_highest": "#36373d",
             "on_surface": "#e6e6e9", "outline": "#80828a"},
    # (light: the bevel's light edge white and its dark edge grey, the other way round from dark)
    "light": {"surface": "#fafafb", "surface_container_lowest": "#c4c4ca", "surface_container_low": "#f4f4f6",
              "surface_container": "#d9d9de", "surface_container_high": "#ececf0", "surface_container_highest": "#ffffff",
              "on_surface": "#1b1b1f", "outline": "#777981"},
}


def ini_set(path, section, key, value):
    cp = configparser.RawConfigParser()
    cp.optionxform = str
    if os.path.exists(path):
        try:
            cp.read(path)
        except configparser.Error:
            return
    if not cp.has_section(section):
        cp.add_section(section)
    cp.set(section, key, value)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        cp.write(f, space_around_delimiters=False)


def follow(mode, palette_qt):
    dark = mode != "light"
    gs = ["gsettings", "set", "org.gnome.desktop.interface"]
    subprocess.run(gs + ["color-scheme", "prefer-dark" if dark else "prefer-light"], stderr=subprocess.DEVNULL)
    # GTK 3 only changes with its theme: adw-gtk3 / Adwaita in the right variant (a theme of
    # your own, anything else, is left as it is)
    try:
        cur = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                             capture_output=True, text=True).stdout.strip().strip("'")
    except OSError:
        cur = ""
    base = {"adw-gtk3": "adw-gtk3", "adw-gtk3-dark": "adw-gtk3", "Adwaita": "Adwaita", "Adwaita-dark": "Adwaita", "": "adw-gtk3"}.get(cur)
    if base:
        if base == "adw-gtk3" and not any(os.path.isdir(d + "/adw-gtk3") for d in ("/usr/share/themes", HOME + "/.themes", HOME + "/.local/share/themes")):
            base = "Adwaita"
        theme = base + ("-dark" if dark else "")
        subprocess.run(gs + ["gtk-theme", theme], stderr=subprocess.DEVNULL)
        for v in ("gtk-3.0", "gtk-4.0"):
            ini_set(CONF + "/" + v + "/settings.ini", "Settings", "gtk-theme-name", theme)
    for v in ("gtk-3.0", "gtk-4.0"):
        ini_set(CONF + "/" + v + "/settings.ini", "Settings", "gtk-application-prefer-dark-theme", "1" if dark else "0")
    # Qt: a plain palette in the mode (unless the shell's own colours are already there)
    if not palette_qt:
        try:
            pal, _ = palette()
        except (OSError, ValueError):
            pal = {}
        c = dict(GREYS["dark" if dark else "light"])
        c["primary"] = pal.get("primary", "#7aa2f7" if dark else "#3b5bdb")
        c["on_primary"] = pal.get("on_primary", "#000000" if dark else "#ffffff")
        c["tertiary"] = pal.get("tertiary", c["primary"])
        qt(c)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, targets = sys.argv[1], sys.argv[2:]
    if cmd == "mode":
        follow(targets[0], "--palette-qt" in targets)
        return
    c, mode = palette()
    if cmd == "apply":
        for t in targets:
            {"kitty": lambda: kitty(c, mode), "gtk": lambda: gtk(c), "qt": lambda: qt(c)}.get(t, lambda: None)()
    elif cmd == "off":
        for t in targets:
            if t == "gtk":
                gtk(c, False)
            elif t == "qt":
                qt(c, False)
            elif t == "kitty":
                p = CONF + "/kitty/colors.conf"
                if os.path.exists(p) and open(p).read().startswith("# Monolith"):
                    os.remove(p)
                    open(p, "w").write("")
                subprocess.run(["pkill", "-USR1", "-x", "kitty"], stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
