#!/usr/bin/env python3
"""App colours (Settings -> App colours): apps take the shell's colours (as the shell shows them).

    app_colours.py apply TARGET...   write the colours for these targets: kitty gtk qt
    app_colours.py off TARGET        take them away again (your own settings stay)

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
    roles = json.load(open(src if os.path.exists(src) else STATE + "/next-palette.json")).get("colors", {})
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


def kitty(c, mode):
    bg, fg = c["surface"], c["on_surface"]
    # the 16 terminal colours: tinted towards the palette, readable on its background
    base = ["#000000", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#dcdfe4"]
    norm = [mix(b, c["primary"], 0.25) for b in base]
    norm[0], norm[7] = c.get("surface_container_highest", bg), c.get("on_surface_variant", fg)
    bright = [mix(x, "#ffffff" if mode == "dark" else "#000000", 0.2) for x in norm]
    bright[0] = c.get("outline", bright[0])
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


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, targets = sys.argv[1], sys.argv[2:]
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
