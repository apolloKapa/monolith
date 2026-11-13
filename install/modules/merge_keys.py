#!/usr/bin/env python3
"""Keep your own keybinds, with Monolith in place of another shell (the installer's "keep mine",
on niri and on Hyprland).

    merge_keys.py niri <niri config dir> <Monolith's niri keymap> <monolith command>
    merge_keys.py hypr <hypr config dir> <Monolith's niri keymap> <monolith command> lua|conf

Your binds are sorted into:
  kept      apps, window management (focus, move, maximise, fullscreen, close...), workspaces,
            media keys: everything that isn't a shell's
  switched  a key that runs another shell or its tools (its launcher, lock, screenshots, clipboard,
            wallpapers, panels, notifications, logout menu, bar...): the same key now does
            Monolith's version of it
  off       a shell's key with no Monolith counterpart: commented out ("monolith-off:")
Then Monolith's own keys go on every key that's still free.

niri: done in place in the config's .kdl files (switched binds rewritten, Monolith's added at the
end of the binds block, marked). Hyprland: shell binds are commented out in your files and the
switched and added ones are printed for Monolith's own monolith.lua / monolith.conf.
Prints a summary on stderr.
"""
import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hypr_keys as hk  # noqa: E402

MARK = "monolith-off: "

# anything belonging to a desktop shell, a bar or a shell's helper tools
SHELL = re.compile(r"""(?ix)
    \b(quickshell|qs\s+(ipc|-c|-p|msg)|inir|serpantinumd?|noctalia|caelestia|illogical|end-4|dms\b|dankmaterial|
       ags\b|astal|eww\b|waybar|hyprpanel|nwg-(panel|drawer|dock|bar)|ironbar|yambar|
       rofi|wofi|fuzzel|anyrun|walker|tofi|bemenu|dmenu|vicinae|ulauncher|kickoff|
       wlogout|nwg-bar|swaync(-client)?|mako(ctl)?|dunst(ctl)?|fnott|
       hyprlock|swaylock|gtklock|waylock|loginctl\s+lock-session|
       hyprpaper|swww|awww|waypaper|swaybg|mpvpaper|wpaperd|
       cliphist|clipse|copyq|
       hyprshot|grimblast|grim|flameshot|satty|swappy|slurp|wf-recorder|gpu-screen-recorder|
       hyprpicker|hyprsunset|wlsunset|gammastep)\b""")

# what a shell key was for -> Monolith's command for it (first match wins)
# ("!" in front: a plain command, not one of Monolith's)
INTENTS = [
    # keys that do something straight away keep doing it (not a panel)
    (r"mic\w*.*(mute|toggle)|(mute|toggle).*mic", "!wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    (r"vol\w*.*(raise|up|increase|\+)|(raise|increase).*vol", "!wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    (r"vol\w*.*(lower|down|decrease|-\s*$|\d%-)|(lower|decrease).*vol", "!wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    (r"vol\w*.*(mute|toggle)|(mute).*(vol|sink|audio)", "!wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    (r"bright\w*.*(raise|up|increase|\+)", "!brightnessctl set 5%+"),
    (r"bright\w*.*(lower|down|decrease|-)", "!brightnessctl set 5%-"),
    (r"(screenshot|hyprshot|grimblast|grim|flameshot|satty|swappy).*(output|screen|full|monitor|-o\b).*(edit|annotate|satty|swappy)|"
     r"(screenshot|hyprshot|grimblast|grim|flameshot).*(edit|annotate|satty|swappy).*(output|screen|full|monitor)", "screenshot --full --edit"),
    (r"(screenshot|hyprshot|grimblast|grim|flameshot|satty|swappy).*(edit|annotate|satty|swappy)|swappy|satty", "screenshot --edit"),
    (r"emoji", "msg toggle emoji"),
    (r"clip(board|hist|se)|copyq", "msg toggle clipboard"),
    (r"wall(paper)?|swww|awww|hyprpaper|waypaper|swaybg|mpvpaper|wpaperd", "msg toggle wallpaper"),
    (r"lock", "lock"),
    (r"(record|wf-recorder|gpu-screen-recorder)", "record-menu"),
    (r"(screenshot|hyprshot|grimblast|grim|flameshot|satty|swappy|slurp).*(output|screen|full|monitor|-o\b)", "screenshot --full"),
    (r"screenshot|hyprshot|grimblast|grim\b|flameshot|satty|swappy", "screenshot"),
    (r"logout|wlogout|power|session|nwg-bar", "msg toggle system"),
    (r"notif|swaync|mako|dunst|fnott", "msg toggle notifications"),
    (r"overview|switcher|expo|window.?list|alt.?tab", "msg toggle switcher"),
    (r"cheat|keybind|hotkey|shortcut", "msg toggle cheatsheet"),
    (r"setting|config\b|prefs|preferences", "msg toggle settings"),
    (r"music|media|player|mpris", "msg toggle music"),
    (r"volume|audio|sound|mixer", "msg toggle volume"),
    (r"wifi|network|bluetooth|nm-", "msg toggle network"),
    (r"calendar|clock|date", "msg toggle calendar"),
    (r"bar.*(hide|toggle)|autohide|toggle.*bar", "msg toggle autohide"),
    (r"dashboard|control|sidebar|quick|panel|center|centre|system", "msg toggle system"),
    (r"reload|restart", "restart"),
    (r"rofi|wofi|fuzzel|anyrun|walker|tofi|bemenu|dmenu|vicinae|ulauncher|kickoff|launch|drun|apps|search|menu", "msg toggle launcher"),
]


# started at login by another shell setup and doing a job Monolith does itself (a shell or bar,
# notifications, the wallpaper): turned off, or there'd be two of each. Helpers (the clipboard
# watcher Monolith's clipboard reads, idle, polkit...) stay.
AUTOSTART_OFF = re.compile(r"""(?ix)
    \b(quickshell|qs\b|inir|serpantinumd?|noctalia|caelestia|dms\s+run|ags\b|astal|eww\b|waybar|hyprpanel|
       nwg-(panel|dock|drawer)|ironbar|yambar|swaync|mako|dunst|fnott|
       hyprpaper|swww(-daemon)?|awww(-daemon)?|swaybg|mpvpaper|wpaperd|waypaper)\b""")


def autostart_off(cmd):
    return bool(cmd) and bool(AUTOSTART_OFF.search(cmd)) and "monolith" not in cmd and "--watch" not in cmd


def intent(cmd):
    for rx, sub in INTENTS:
        if re.search(rx, cmd, re.I):
            return sub
    return None


def command_for(sub, monolith):
    """The command for an intent: Monolith's (with its path), or a plain one ("!")."""
    return sub[1:] if sub.startswith("!") else monolith + " " + sub


def is_direct(sub):
    return sub.startswith("!")


def shellish(cmd):
    return bool(cmd) and bool(SHELL.search(cmd)) and "monolith" not in cmd


# ── keys, compared however they're written ──
MODMAP = {"MOD": "SUPER", "SUPER": "SUPER", "WIN": "SUPER", "LOGO": "SUPER", "MOD4": "SUPER", "META": "SUPER",
          "CTRL": "CTRL", "CONTROL": "CTRL", "SHIFT": "SHIFT", "ALT": "ALT", "MOD1": "ALT"}


def sig(mods, key):
    return (frozenset(MODMAP.get(m.upper(), m.upper()) for m in mods if m), key.lower())


# ── niri ──
def merge_niri(cfg_dir, keymap, monolith, add_keys=True):
    files = [os.path.join(r, f) for r, _, fs in os.walk(cfg_dir) for f in fs if f.endswith(".kdl")]
    used, have, home = set(), set(), None
    counts = {"kept": 0, "switched": 0, "off": 0, "added": 0}
    for path in files:
        lines = open(path, encoding="utf-8").read().split("\n")
        changed = False
        for i, line in enumerate(lines):
            if line.strip().startswith("//"):
                continue
            a = re.match(r"^(\s*)spawn(-sh)?-at-startup\s+(.*)$", line)
            if a:
                try:
                    cmd = " ".join(shlex.split(a.group(3)))
                except ValueError:
                    cmd = a.group(3)
                if autostart_off(cmd):
                    lines[i] = a.group(1) + "// " + MARK + line.strip()
                    counts["autostart off"] = counts.get("autostart off", 0) + 1
                    changed = True
                continue
            m = hk.bind_re.match(line)
            if not m:
                continue
            try:
                words = shlex.split(m.group(3).strip())
            except ValueError:
                continue
            if not words:
                continue
            k = sig(m.group(1).split("+")[:-1], m.group(1).split("+")[-1])
            cmd = hk.command_of(words, monolith)
            if cmd and shellish(cmd):
                sub = intent(cmd)
                ind = re.match(r"\s*", line).group(0)
                if sub:
                    if is_direct(sub):
                        lines[i] = '%s%s%s { spawn-sh "%s"; }' % (ind, m.group(1), m.group(2), sub[1:])
                    else:
                        args = " ".join('"%s"' % a for a in [monolith] + sub.split())
                        lines[i] = "%s%s%s { spawn %s; }" % (ind, m.group(1), m.group(2), args)
                    counts["switched"] += 1
                    used.add(k); have.add(sub)
                else:
                    lines[i] = ind + "// " + MARK + line.strip()
                    counts["off"] += 1
                changed = True
                continue
            used.add(k)
            counts["kept"] += 1
            if cmd and "monolith" in cmd:
                have.add(re.sub(r"^\S*monolith\s+", "", cmd))
            if home is None and re.match(r"^\s*binds\s*\{", "\n".join(lines[:i])) is None:
                pass
        if changed:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
    # Monolith's keys on the free ones, at the end of the binds block
    add = []
    for key, props, words, line in hk.niri_binds(keymap):
        k = sig(key.split("+")[:-1], key.split("+")[-1])
        if k in used:
            continue
        cmd = hk.command_of(words, monolith)
        sub = re.sub(r"^\S*monolith\s+", "", cmd) if cmd and "monolith" in cmd else None
        if sub and sub in have:
            continue
        used.add(k)
        if sub:
            have.add(sub)
        add.append("    " + (line.strip() if not cmd else re.sub(r'spawn "monolith"', 'spawn "%s"' % monolith, line.strip())))
    if add and add_keys:
        target = next((p for p in files if re.search(r"^\s*binds\s*\{", open(p, encoding="utf-8").read(), re.M)), None)
        if target:
            text = open(target, encoding="utf-8").read()
            m = re.search(r"^\s*binds\s*\{", text, re.M)
            depth, j = 0, m.end() - 1
            while j < len(text):
                depth += {"{": 1, "}": -1}.get(text[j], 0)
                if depth == 0:
                    break
                j += 1
            block = "\n    // Monolith's keys (added by its installer, on keys that were free)\n" + "\n".join(add) + "\n"
            text = text[:j] + block + text[j:]
            open(target, "w", encoding="utf-8").write(text)
            counts["added"] = len(add)
    return counts


# ── Hyprland ──
LUA_BIND = re.compile(r"^(\s*)hl\.bind\((.+?),\s*(hl\.dsp\..*)$")
CONF_BIND = re.compile(r"^(\s*)(bind[a-z]*)\s*=\s*([^,]*),\s*([^,]+),\s*([^,]+)(?:,\s*(.*))?$")


def lua_key(expr, variables):
    """A bind's key from its Lua expression (strings joined with .., variables like mainMod)."""
    parts = [p.strip() for p in expr.split("..")]
    out = ""
    for p in parts:
        if p.startswith('"') and p.endswith('"'):
            out += p[1:-1]
        elif p in variables:
            out += variables[p]
        else:
            return None        # computed (a loop's key): not known
    toks = [t.strip() for t in out.split("+") if t.strip()]
    return (toks[:-1], toks[-1]) if toks else None


def merge_hypr(cfg_dir, keymap, monolith, fmt):
    lua = fmt == "lua"
    ext = ".lua" if lua else ".conf"
    files = [os.path.join(r, f) for r, _, fs in os.walk(cfg_dir) for f in fs
             if f.endswith(ext) and not f.startswith("monolith")]
    # (Lua: names like mainMod; a classic config: $names. A Lua config's mainMod is SUPER unless set)
    variables = {"mainMod": "SUPER"} if lua else {}
    for path in files:
        for line in open(path, encoding="utf-8"):
            m = re.match(r'^\s*(?:_G\.)?(\w+)\s*=\s*(?:_G\.\w+\s+or\s+)?"([^"]*)"', line) if lua else re.match(r"^\s*\$(\w+)\s*=\s*(\S+)", line)
            if m:
                variables[m.group(1) if lua else "$" + m.group(1)] = m.group(2)
    used, have, out = set(), set(), []
    counts = {"kept": 0, "switched": 0, "off": 0, "added": 0}
    c = "-- " if lua else "# "
    for path in files:
        lines = open(path, encoding="utf-8").read().split("\n")
        changed = False
        for i, line in enumerate(lines):
            # a key turned off by an earlier run: still switched to Monolith (Monolith's file is
            # written again on every update), left as it is in your file
            again = False
            st = line.strip()
            for pre in ("-- " + MARK, "# " + MARK):
                if st.startswith(pre):
                    line, again = re.match(r"\s*", line).group(0) + st[len(pre):], True
            if not again and st.startswith(("--", "#")):
                continue
            a = (re.match(r'^(\s*)hl\.exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', line) if lua
                 else re.match(r"^(\s*)exec(?:-once)?\s*=\s*(.*)$", line))
            if a:
                if not again and autostart_off(a.group(2)):
                    lines[i] = a.group(1) + c + MARK + line.strip()
                    counts["autostart off"] = counts.get("autostart off", 0) + 1
                    changed = True
                continue
            if lua:
                m = LUA_BIND.match(line)
                if not m:
                    continue
                key = lua_key(m.group(2), variables)
                em = re.search(r'exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', m.group(3))
                cmd = em.group(1) if em else None
            else:
                m = CONF_BIND.match(line)
                if not m:
                    continue
                mods = m.group(3)
                # (longest names first, so $mainMod2 isn't taken for $mainMod)
                for v in sorted(variables, key=len, reverse=True):
                    mods = mods.replace(v, variables[v])
                key = (mods.split(), m.group(4).strip())
                cmd = m.group(6) if m.group(5).strip() == "exec" else None
            if again and not (cmd and shellish(cmd)):
                continue
            if cmd and shellish(cmd):
                sub = intent(cmd)
                if not again:
                    lines[i] = (m.group(1) or "") + c + MARK + line.strip()
                    changed = True
                if sub and key:
                    full = command_for(sub, monolith)
                    # (media keys: also on the lock screen, as they were)
                    locked = key[1].startswith("XF86") and is_direct(sub)
                    if lua:
                        out.append('hl.bind(%s, hl.dsp.exec_cmd(%s)%s)' % (hk.lua_str(" + ".join(key[0] + [key[1]])), hk.lua_str(full), ", { locked = true }" if locked else ""))
                    else:
                        out.append("%s = %s, %s, exec, %s" % ("bindl" if locked else "bind", " ".join(key[0]), key[1], full))
                    used.add(sig(*key)); have.add(sub)
                    counts["switched"] += 1
                elif not again:
                    counts["off"] += 1
                continue
            if key:
                used.add(sig(*key))
            counts["kept"] += 1
            if cmd and "monolith" in cmd:
                have.add(re.sub(r"^\S*monolith\s+", "", cmd))
        if changed:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
    # Monolith's keys on the free ones
    for mods, k, locked, lua_line, conf_line, got in hk.translate(keymap, monolith):
        s = sig(mods, k)
        if s in used:
            continue
        cmd = got[1][6:] if got[1].startswith("exec, ") else None
        sub = re.sub(r"^\S*monolith\s+", "", cmd) if cmd and "monolith" in cmd else None
        if sub and sub in have:
            continue
        used.add(s)
        if sub:
            have.add(sub)
        out.append(lua_line if lua else conf_line)
        counts["added"] += 1
    print("\n".join(out))
    return counts


if __name__ == "__main__":
    kind = sys.argv[1]
    if kind == "niri":
        r = merge_niri(sys.argv[2], sys.argv[3], sys.argv[4], "--no-add" not in sys.argv)
        if "--no-add" in sys.argv:
            r["added"] = 0
    else:
        r = merge_hypr(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    r.setdefault("autostart off", 0)
    sys.stderr.write("keys: kept %(kept)d, switched to Monolith %(switched)d, turned off %(off)d, Monolith's added %(added)d; "
                     "another shell's start-up lines turned off: %(autostart off)d\n" % r)
