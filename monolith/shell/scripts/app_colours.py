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
gtk:   GTK 3 (Thunar, …): a theme of our own, adw-gtk3 in the shell's colours, in
       ~/.local/share/themes/Monolith-a and Monolith-b. Each change goes into the one not in use and
       the GTK theme is switched to it: GTK 3 apps re-read their theme when its name changes (they
       never re-read gtk.css), so open windows, and Thunar's daemon, recolour at once. (Plain
       Adwaita ignores most colour names: that's why Thunar stayed grey.)
       GTK 4 / libadwaita: a marked block in ~/.config/gtk-4.0/gtk.css (colour names and the CSS
       variables libadwaita 1.6+ reads); the rest of that file is yours. Apps read it as they start.
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


def gtk_colours(c):
    """libadwaita's (and adw-gtk3's) colour names, and GTK 3's own, in the shell's colours"""
    dark = luminance(c["surface"]) < 0.2
    shade = "rgba(0,0,0,0.36)" if dark else "rgba(0,0,0,0.07)"
    border = c.get("outline_variant", c["surface_container_highest"])
    return {
        "accent_color": c["primary"], "accent_bg_color": c["primary"], "accent_fg_color": c["on_primary"],
        "window_bg_color": c["surface"], "window_fg_color": c["on_surface"],
        "view_bg_color": c["surface_container_low"], "view_fg_color": c["on_surface"],
        "headerbar_bg_color": c["surface_container"], "headerbar_fg_color": c["on_surface"],
        "headerbar_border_color": border, "headerbar_backdrop_color": c["surface"],
        "headerbar_shade_color": shade, "headerbar_darker_shade_color": shade,
        "sidebar_bg_color": c["surface_container_low"], "sidebar_fg_color": c["on_surface"],
        "sidebar_backdrop_color": c["surface_container_lowest"], "sidebar_border_color": border, "sidebar_shade_color": shade,
        "secondary_sidebar_bg_color": c["surface_container"], "secondary_sidebar_fg_color": c["on_surface"],
        "card_bg_color": c["surface_container"], "card_fg_color": c["on_surface"], "card_shade_color": shade,
        "popover_bg_color": c["surface_container_high"], "popover_fg_color": c["on_surface"], "popover_shade_color": shade,
        "dialog_bg_color": c["surface_container_high"], "dialog_fg_color": c["on_surface"],
        "thumbnail_bg_color": c["surface_container_high"], "thumbnail_fg_color": c["on_surface"],
        "panel_bg_color": c["surface_container"], "panel_fg_color": c["on_surface"],
        "destructive_color": c["error"], "destructive_bg_color": c["error"], "destructive_fg_color": c["on_error"],
        "error_color": c["error"], "error_bg_color": c["error"], "error_fg_color": c["on_error"],
        "shade_color": shade, "scrollbar_outline_color": c["surface_container_lowest"],
        # GTK 3's own names (adw-gtk3 and Adwaita read these too)
        "theme_bg_color": c["surface"], "theme_fg_color": c["on_surface"], "theme_base_color": c["surface_container_low"],
        "theme_text_color": c["on_surface"], "theme_selected_bg_color": c["primary"], "theme_selected_fg_color": c["on_primary"],
        "theme_unfocused_bg_color": c["surface"], "theme_unfocused_fg_color": c["on_surface"],
        "theme_unfocused_base_color": c["surface_container_low"], "theme_unfocused_text_color": c["on_surface"],
        "theme_unfocused_selected_bg_color": c["primary"], "theme_unfocused_selected_fg_color": c["on_primary"],
        "insensitive_bg_color": c["surface_container"], "insensitive_fg_color": c.get("on_surface_variant", c["on_surface"]),
        "insensitive_base_color": c["surface_container_low"], "borders": border, "unfocused_borders": border,
        "content_view_bg": c["surface_container_low"], "text_view_bg": c["surface_container_low"],
    }


def gtk_block(c):
    pairs = gtk_colours(c)
    lines = ["@define-color %s %s;" % kv for kv in pairs.items()]
    # (libadwaita 1.6+ styles from CSS variables, made from the names above inside its own sheet:
    # set them too, so it doesn't matter which one an app's libadwaita reads)
    lines.append(":root { " + " ".join("--%s: %s;" % (k.replace("_", "-"), v) for k, v in pairs.items()
                                      if not k.startswith(("theme_", "insensitive_", "borders", "unfocused_", "content_", "text_view"))) + " }")
    return START + "\n" + "\n".join(lines) + "\n" + END


THEMES = HOME + "/.local/share/themes"
SLOTS = ("Monolith-a", "Monolith-b")


def theme_dir(name):
    for d in (HOME + "/.local/share/themes", HOME + "/.themes", "/usr/local/share/themes", "/usr/share/themes"):
        if os.path.isdir(d + "/" + name):
            return d + "/" + name
    return None


def gtk_theme_now():
    try:
        return subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                              capture_output=True, text=True).stdout.strip().strip("'")
    except OSError:
        return ""


def set_gtk_theme(name):
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", name], stderr=subprocess.DEVNULL)
    for v in ("gtk-3.0", "gtk-4.0"):
        ini_set(CONF + "/" + v + "/settings.ini", "Settings", "gtk-theme-name", name)


def gtk3_theme(c, mode):
    """adw-gtk3 in the shell's colours, as a theme of our own; switched to (see the top)"""
    dark = mode != "light"
    base = theme_dir("adw-gtk3-dark" if dark else "adw-gtk3")
    defs = "\n".join("@define-color %s %s;" % kv for kv in gtk_colours(c).items())
    files = {}
    for v in ("gtk-3.0", "gtk-4.0"):
        if base and os.path.exists(base + "/" + v + "/gtk.css"):
            imp = '@import url("file://%s/%s/gtk.css");' % (base, v)
        elif v == "gtk-3.0":
            # (no adw-gtk3: GTK's built-in Adwaita, which takes fewer of the colours)
            imp = '@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained%s.css");' % ("-dark" if dark else "")
        else:
            continue
        files[v] = "/* Monolith: adw-gtk3 in the shell's colours (Settings -> App colours). Rewritten on every change. */\n" + imp + "\n" + defs + "\n"
    now = gtk_theme_now()
    # same colours as the theme in use: nothing to do (switching would only make apps redraw)
    if now in SLOTS:
        try:
            if all(open("%s/%s/%s/gtk.css" % (THEMES, now, v)).read() == t for v, t in files.items()):
                return
        except OSError:
            pass
    slot = SLOTS[1] if now == SLOTS[0] else SLOTS[0]
    d = THEMES + "/" + slot
    for v, text in files.items():
        os.makedirs(d + "/" + v, exist_ok=True)
        # (adw-gtk3's pictures: checkboxes, radio buttons… found next to the theme's gtk.css)
        if base and os.path.isdir(base + "/" + v + "/assets") and not os.path.exists(d + "/" + v + "/assets"):
            os.symlink(base + "/" + v + "/assets", d + "/" + v + "/assets")
        open(d + "/" + v + "/gtk.css", "w").write(text)
    open(d + "/index.theme", "w").write("[Desktop Entry]\nType=X-GNOME-Metatheme\nName=%s\nComment=Monolith: the shell's colours\n"
                                        "Encoding=UTF-8\n\n[X-GNOME-Metatheme]\nGtkTheme=%s\n" % (slot, slot))
    set_gtk_theme(slot)


def set_block(path, block):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = open(path).read() if os.path.exists(path) else ""
    text = re.sub(re.escape(START) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    # the block the earlier shell wrote, replaced the same way
    text = re.sub(r"/\* >>> Monolith colours.*?/\* <<< Monolith colours <<< \*/\n?", "", text, flags=re.S)
    if block:
        text = block + "\n" + text
    open(path, "w").write(text)


def gtk(c, mode, on=True):
    # GTK 3: the theme (the block that used to go in its gtk.css comes out: user CSS outranks the
    # theme, so it held the old colours over every new theme)
    set_block(CONF + "/gtk-3.0/gtk.css", "")
    set_block(CONF + "/gtk-4.0/gtk.css", gtk_block(c) if on else "")
    if on:
        gtk3_theme(c, mode)
    elif gtk_theme_now() in SLOTS:
        # back to plain adw-gtk3 (or Adwaita) in the mode
        base = "adw-gtk3" if theme_dir("adw-gtk3") else "Adwaita"
        set_gtk_theme(base + ("-dark" if mode != "light" else ""))


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
    cur = gtk_theme_now()
    # (our own theme, Monolith-a/-b: App colours rewrites it in the new mode itself. Plain Adwaita
    # becomes adw-gtk3 when that's there: the same look, and it takes the colours)
    base = {"adw-gtk3": "adw-gtk3", "adw-gtk3-dark": "adw-gtk3", "Adwaita": "adw-gtk3", "Adwaita-dark": "adw-gtk3", "": "adw-gtk3"}.get(cur)
    if base:
        if base == "adw-gtk3" and not any(os.path.isdir(d + "/adw-gtk3") for d in ("/usr/share/themes", HOME + "/.themes", HOME + "/.local/share/themes")):
            base = "Adwaita"
        set_gtk_theme(base + ("-dark" if dark else ""))
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
            {"kitty": lambda: kitty(c, mode), "gtk": lambda: gtk(c, mode), "qt": lambda: qt(c)}.get(t, lambda: None)()
    elif cmd == "off":
        for t in targets:
            if t == "gtk":
                gtk(c, mode, False)
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
