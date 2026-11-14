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
    (r"vol\w*.*(raise|up|increase|increment|inc\b|\+)|(raise|increase|increment).*vol", "!wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    (r"vol\w*.*(lower|down|decrease|decrement|dec\b|-\s*$|\d%-)|(lower|decrease|decrement).*vol", "!wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    (r"vol\w*.*(mute|toggle)|(mute).*(vol|sink|audio)", "!wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    (r"bright\w*.*(raise|up|increase|increment|inc\b|\+)", "!brightnessctl set 5%+"),
    (r"bright\w*.*(lower|down|decrease|decrement|dec\b|-)", "!brightnessctl set 5%-"),
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
# notifications, the wallpaper, idle locking): turned off, or there'd be two of each (Monolith locks
# and sleeps on idle itself: Settings -> Lock & idle). Helpers (the clipboard
# watcher Monolith's clipboard reads, idle, polkit...) stay.
AUTOSTART_OFF = re.compile(r"""(?ix)
    \b(quickshell|qs\b|inir|serpantinumd?|noctalia|caelestia|dms\s+run|ags\b|astal|eww\b|waybar|hyprpanel|
       nwg-(panel|dock|drawer)|ironbar|yambar|swaync|mako|dunst|fnott|
       hyprpaper|swww(-daemon)?|awww(-daemon)?|swaybg|mpvpaper|wpaperd|waypaper|
       hypridle|swayidle)\b""")


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


# a key that is only a modifier (Super, Alt or Ctrl tapped on its own): another shell's launcher on
# a tap of Super, say. It can't be carried over: on its own it fires on every press of Super, also
# when Super is held for Super+1, Super+Q..., and the menu kept popping up. It's turned off, and
# Monolith's key for the same thing (the launcher: Super+Space) goes on instead.
LONE = re.compile(r"^(super|alt|ctrl|control|shift|meta|hyper)(_[lr])?$", re.I)


def lone_modifier(key):
    return bool(key) and bool(LONE.match(key[1]))


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
            if lone_modifier((None, m.group(1).split("+")[-1])) and cmd and shellish(cmd):
                lines[i] = re.match(r"\s*", line).group(0) + "// " + MARK + line.strip()
                counts["off"] += 1
                changed = True
                continue
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
CONF_BIND = re.compile(r"^(\s*)(bind([a-z]*))\s*=\s*(.*)$")
MODWORDS = re.compile(r"SUPER|SHIFT|CTRL|CONTROL|ALT|MOD[1-5]|META|WIN|LOGO")


def norm_mods(text):
    """Modifiers however they're written: "SUPER SHIFT", "SUPERSHIFT", "SUPER_SHIFT", "Super + Shift"."""
    return MODWORDS.findall(text.upper())


def paren_depth(text):
    """How many ( are still open at the end of `text` (strings and comments skipped)."""
    d, q, i = 0, None, 0
    while i < len(text):
        ch = text[i]
        if q:
            if ch == "\\":
                i += 2
                continue
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch
        elif text.startswith("--", i):
            break
        elif ch == "(":
            d += 1
        elif ch == ")":
            d -= 1
        i += 1
    return d


def statements(lines, lua, c):
    """Each statement: (first line, last line, its text, was it turned off already). A Lua call
    written over several lines is one statement (turned off whole, never half: that would break
    the config)."""
    out, i, n = [], 0, len(lines)
    pre = c + MARK
    while i < n:
        raw = lines[i]
        st = raw.strip()
        again = st.startswith(pre)
        body = st[len(pre):] if again else st
        if not again and st.startswith(("--", "#")) or not body:
            i += 1
            continue
        j, text = i, body
        if lua and re.match(r"hl\.(bind|exec_cmd)\(", body):
            while paren_depth(text) > 0 and j + 1 < n:
                j += 1
                nxt = lines[j].strip()
                text += " " + (nxt[len(pre):] if again and nxt.startswith(pre) else nxt)
        out.append((i, j, text, again))
        i = j + 1
    return out


def lua_key(expr, variables):
    """A bind's key from its Lua expression (strings joined with .., variables like mainMod).
    A key made in a loop ("SUPER + " .. i): ("loop", its modifiers)."""
    parts = [p.strip() for p in expr.split("..")]
    out = ""
    for k, p in enumerate(parts):
        if p.startswith('"') and p.endswith('"'):
            out += p[1:-1]
        elif p in variables:
            out += variables[p]
        elif k == len(parts) - 1 and re.match(r"^[\w.\[\]]+$", p):
            return ("loop", norm_mods(out))
        else:
            return None
    toks = [t.strip() for t in out.split("+") if t.strip()]
    if not toks:
        return None
    return (norm_mods(" ".join(toks[:-1])), toks[-1])


def split_lua_bind(text):
    """hl.bind(KEY, DISPATCH[, OPTS]) -> (key expression, dispatch text, options text or "")."""
    m = re.match(r"^hl\.bind\((.*)\)\s*;?\s*$", text)
    if not m:
        return None
    args, parts, d, q, cur = m.group(1), [], 0, None, ""
    i = 0
    while i < len(args):
        ch = args[i]
        if q:
            cur += ch
            if ch == "\\" and i + 1 < len(args):
                cur += args[i + 1]; i += 2; continue
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch; cur += ch
        elif ch in "({[":
            d += 1; cur += ch
        elif ch in ")}]":
            d -= 1; cur += ch
        elif ch == "," and d == 0:
            parts.append(cur.strip()); cur = ""
        else:
            cur += ch
        i += 1
    if cur.strip():
        parts.append(cur.strip())
    if len(parts) < 2:
        return None
    return parts[0], parts[1], (parts[2] if len(parts) > 2 else "")


FOLDER = "monolith"          # Monolith's own folder in ~/.config/hypr (its files: start, keybinds...)


def user_files(cfg_dir, ext):
    """Your config's files: everything but Monolith's own (its folder, and the monolith*.lua/.conf
    files of older versions)."""
    out = []
    for r, ds, fs in os.walk(cfg_dir):
        if os.path.abspath(r) == os.path.abspath(cfg_dir):
            ds[:] = [d for d in ds if d != FOLDER]
        out += [os.path.join(r, f) for f in fs if f.endswith(ext) and not f.startswith("monolith")]
    return out


def my_keys(cfg_dir, lua, variables):
    """The keys in your own my-keys file (in Monolith's folder; never changed by Monolith):
    Monolith leaves those keys to you."""
    path = os.path.join(cfg_dir, FOLDER, "my-keys" + (".lua" if lua else ".conf"))
    taken = set()
    try:
        lines = open(path, encoding="utf-8").read().split("\n")
    except OSError:
        return taken
    c = "-- " if lua else "# "
    for a, b, text, again in statements(lines, lua, c):
        if again:
            continue
        if lua:
            parts = split_lua_bind(text)
            key = lua_key(parts[0], dict(variables)) if parts else None
        else:
            m = CONF_BIND.match(text)
            f = [x.strip() for x in m.group(4).split(",")] if m else []
            key = None
            if len(f) >= 2:
                mods = f[0]
                for v in sorted(variables, key=len, reverse=True):
                    mods = mods.replace(v, variables[v])
                key = (norm_mods(mods), f[1])
        if key and key[0] == "loop":
            for dgt in "1234567890":
                taken.add(sig(key[1], dgt))
        elif key:
            taken.add(sig(*key))
    return taken


def layout_hypr(cfg_dir, keymap, monolith, fmt):
    """Monolith's own key layout, in sections, without the keys you set in my-keys."""
    lua = fmt == "lua"
    taken = my_keys(cfg_dir, lua, {"mainMod": "SUPER"} if lua else {})
    binds = hk.translate(keymap, monolith)
    keys = hk.render(binds, lua, skip=taken)
    print("\n".join(hk.scroll_delay(keymap, lua) + (hk.helpers(keys) if lua else []) + keys))


def merge_hypr(cfg_dir, keymap, monolith, fmt):
    lua = fmt == "lua"
    ext = ".lua" if lua else ".conf"
    files = user_files(cfg_dir, ext)
    # (Lua: names like mainMod; a classic config: $names. A Lua config's mainMod is SUPER unless set)
    variables = {"mainMod": "SUPER"} if lua else {}
    for path in files:
        for line in open(path, encoding="utf-8"):
            m = re.match(r'^\s*(?:local\s+)?(?:_G\.)?(\w+)\s*=\s*(?:_G\.\w+\s+or\s+)?"([^"]*)"', line) if lua else re.match(r"^\s*\$(\w+)\s*=\s*(\S+)", line)
            if m:
                variables[m.group(1) if lua else "$" + m.group(1)] = m.group(2)
    used, have, out = set(), set(), []
    # (the keys in your my-keys file are yours too)
    used |= my_keys(cfg_dir, lua, variables)
    counts = {"kept": 0, "switched": 0, "off": 0, "added": 0}
    c = "-- " if lua else "# "

    def turn_off(lines, a, b):
        for k in range(a, b + 1):
            if lines[k].strip() and not lines[k].strip().startswith(c + MARK):
                lines[k] = re.match(r"\s*", lines[k]).group(0) + c + MARK + lines[k].strip()

    for path in files:
        lines = open(path, encoding="utf-8").read().split("\n")
        changed = False
        for a, b, text, again in statements(lines, lua, c):
            # start-up lines of another shell's
            if lua:
                am = re.match(r'^hl\.exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', text)
            else:
                am = re.match(r"^exec(?:-once)?\s*=\s*(.*)$", text)
            if am:
                if not again and autostart_off(am.group(1)):
                    turn_off(lines, a, b); changed = True
                    counts["autostart off"] = counts.get("autostart off", 0) + 1
                continue
            flags, opts = "", ""
            if lua:
                parts = split_lua_bind(text)
                if not parts:
                    continue
                key = lua_key(parts[0], variables)
                em = re.search(r'exec_cmd\(\s*"((?:[^"\\]|\\.)*)"', parts[1])
                cmd = em.group(1) if em else None
                opts = parts[2]
            else:
                m = CONF_BIND.match(text)
                if not m:
                    continue
                flags = m.group(3)
                f = [x.strip() for x in m.group(4).split(",")]
                if "d" in flags and len(f) >= 4:          # bindd: a description before the dispatcher
                    f = f[:2] + f[3:]
                if len(f) < 3:
                    continue
                mods = f[0]
                for v in sorted(variables, key=len, reverse=True):
                    mods = mods.replace(v, variables[v])
                key = (norm_mods(mods), f[1])
                cmd = ", ".join(f[3:]) if f[2] == "exec" else None
            # a loop's keys (SUPER + 1..0, say): taken, whatever they do; unless it's another
            # shell's (its workspace keys): then it's turned off and Monolith's go there
            if key and key[0] == "loop" and cmd and shellish(cmd):
                if not again:
                    turn_off(lines, a, b); changed = True
                    counts["off"] += 1
                continue
            if key and key[0] == "loop":
                for dgt in "1234567890":
                    used.add(sig(key[1], dgt))
                counts["kept"] += 1
                continue
            if again and not (cmd and shellish(cmd)):
                continue
            if key and lone_modifier(key) and cmd and (shellish(cmd) or "monolith" in cmd):
                if not again:
                    turn_off(lines, a, b); changed = True
                    counts["off"] += 1
                continue
            if cmd and shellish(cmd):
                sub = intent(cmd)
                if not again:
                    turn_off(lines, a, b); changed = True
                if sub and key:
                    full = command_for(sub, monolith)
                    combo = " + ".join(key[0] + [key[1]])
                    if lua:
                        # (its options stay: repeating, locked...; media keys on the lock screen too)
                        o = opts
                        if not o and key[1].startswith("XF86") and is_direct(sub):
                            o = "{ locked = true }"
                        out.append("hl.bind(%s, hl.dsp.exec_cmd(%s)%s)" % (hk.lua_str(combo), hk.lua_str(full), (", " + o) if o else ""))
                    else:
                        fl = flags.replace("d", "")
                        if not fl and key[1].startswith("XF86") and is_direct(sub):
                            fl = "l"
                        out.append("bind%s = %s, %s, exec, %s" % (fl, " ".join(key[0]), key[1], full))
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
    # Monolith's keys on the free ones, in their sections
    add = []
    for b in hk.translate(keymap, monolith):
        mods, k, got = b[0], b[1], b[5]
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
        add.append(b)
        counts["added"] += 1
    cm = "--" if lua else "#"
    lines = []
    if out:
        lines += [cm + " ── Your keys that ran another shell: now Monolith's ────────────", *out, ""]
    lines += [cm + " (Monolith's keys below are on keys your config left free)", ""]
    keys = hk.render(add, lua)
    # (a scroll key with its own cooldown needs the helper; Hyprland's own wait stays as it is)
    if lua:
        lines += hk.helpers(keys)
    lines += keys
    print("\n".join(lines))
    return counts


def off_all_hypr(cfg_dir, fmt):
    """Monolith's own key layout: every key in your config turned off (whole statements, never
    half of one), except mouse drags and gestures."""
    lua = fmt == "lua"
    c = "-- " if lua else "# "
    n = 0
    for path in user_files(cfg_dir, ".lua" if lua else ".conf"):
        lines = open(path, encoding="utf-8").read().split("\n")
        changed = False
        for a, b, text, again in statements(lines, lua, c):
            if again:
                continue
            if lua:
                if not text.startswith("hl.bind(") or re.search(r"mouse:27[23]|mouse\s*=\s*true", text):
                    continue
            else:
                m = CONF_BIND.match(text)
                if not m or "m" in m.group(3):
                    continue
            for k in range(a, b + 1):
                if lines[k].strip():
                    lines[k] = re.match(r"\s*", lines[k]).group(0) + c + MARK + lines[k].strip()
            changed = True
            n += 1
        if changed:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
    return n


if __name__ == "__main__":
    kind = sys.argv[1]
    if kind == "layout":
        layout_hypr(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
        sys.exit(0)
    if kind == "hypr-off-all":
        sys.stderr.write("your keys turned off: %d\n" % off_all_hypr(sys.argv[2], sys.argv[3]))
        sys.exit(0)
    if kind == "niri":
        r = merge_niri(sys.argv[2], sys.argv[3], sys.argv[4], "--no-add" not in sys.argv)
        if "--no-add" in sys.argv:
            r["added"] = 0
    else:
        r = merge_hypr(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    r.setdefault("autostart off", 0)
    sys.stderr.write("keys: kept %(kept)d, switched to Monolith %(switched)d, turned off %(off)d, Monolith's added %(added)d; "
                     "another shell's start-up lines turned off: %(autostart off)d\n" % r)
