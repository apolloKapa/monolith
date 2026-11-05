#!/usr/bin/env python3
"""Apps that start when you log in (Settings -> Software -> Autostart).

Uses the standard XDG autostart folder, ~/.config/autostart, so the choice also works in other
desktops and is understood by other tools:
  list         every installed app as JSON, with "on" for the ones that start at login (plus
               any autostart entry that has no installed app, e.g. one written by hand)
  on  ID       start this app (its .desktop file id, e.g. "discord.desktop") at login
  off ID       stop starting it at login
  minimized ID on|off   start it in the tray (the app's own option, e.g. Steam's -silent)
  run          start every app that's on; called by monolithd once per login

Only the user's own folder is run, not /etc/xdg/autostart: those are system helpers (keyring,
PipeWire launcher, ...) that the session already starts its own way. Under a systemd session
that runs autostart entries itself, "run" does nothing, so nothing starts twice.
"""
import json
import os
import shlex
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
AUTOSTART = os.path.join(CONFIG, "autostart")
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
DATA_DIRS = [DATA_HOME] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
MARK = "X-Monolith-Autostart"


def read_entry(path):
    """The [Desktop Entry] keys of a .desktop file (unlocalised), or None."""
    keys, inside = {}, False
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    inside = line == "[Desktop Entry]"
                    continue
                if inside and "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    keys.setdefault(k.strip(), v.strip())
    except OSError:
        return None
    return keys


def is_true(v):
    return str(v).strip().lower() == "true"


def installed_apps():
    """id -> (path, keys) for every app a launcher would show; the user's copy wins."""
    apps = {}
    for base in DATA_DIRS:
        root = os.path.join(base, "applications")
        if not os.path.isdir(root):
            continue
        for dirpath, _, files in os.walk(root):
            for name in files:
                if not name.endswith(".desktop"):
                    continue
                path = os.path.join(dirpath, name)
                # the spec's desktop id: subfolders joined with "-"
                app_id = os.path.relpath(path, root).replace(os.sep, "-")
                if app_id in apps:
                    continue
                keys = read_entry(path)
                apps[app_id] = (path, keys)
    return {i: v for i, v in apps.items()
            if v[1] and v[1].get("Type", "Application") == "Application"
            and not is_true(v[1].get("NoDisplay")) and not is_true(v[1].get("Hidden"))}


def exec_key(value):
    """What an Exec line runs, so an autostart entry matches its app even with other options
    (OpenRGB's own entry adds --startminimized): the program's name, or for Flatpaks the app id."""
    try:
        parts = [p for p in shlex.split(value) if not p.startswith("%")]
    except ValueError:
        return value
    while parts and (parts[0] == "env" or ("=" in parts[0] and not parts[0].startswith("/"))):
        parts = parts[1:]
    if not parts:
        return value
    prog = os.path.basename(parts[0])
    if prog == "flatpak":
        ids = [p for p in parts[1:] if not p.startswith("-") and p != "run" and "." in p]
        return "flatpak:" + (ids[0] if ids else value)
    return prog


# Settings -> Software -> Autostart -> Minimized: niri has no minimized windows, so this is each
# app's own start-in-the-tray option, added to its autostart entry. Only apps with one get the switch
MINIMIZE_FLAGS = {
    "steam": "-silent",
    "discord": "--start-minimized", "discord-canary": "--start-minimized", "discord-ptb": "--start-minimized",
    "flatpak:com.discordapp.Discord": "--start-minimized",
    "vesktop": "--start-minimized", "flatpak:dev.vencord.Vesktop": "--start-minimized",
    "legcord": "--start-minimized", "flatpak:app.legcord.Legcord": "--start-minimized",
    "openrgb": "--startminimized", "flatpak:org.openrgb.OpenRGB": "--startminimized",
    "telegram-desktop": "-startintray", "flatpak:org.telegram.desktop": "-startintray",
}


def exec_tokens(value):
    try:
        return shlex.split(value.replace("\\$", "$").replace("\\`", "`"))
    except ValueError:
        return None


def exec_join(tokens):
    """Tokens back into an Exec line, quoted the way the desktop-entry spec wants (double quotes)."""
    out = []
    for t in tokens:
        if t and not any(c in t for c in ' \t\n"\'\\><~|&;$*?#()`'):
            out.append(t)
        else:
            out.append('"' + "".join("\\" + c if c in '"`$\\' else c for c in t) + '"')
    return " ".join(out)


def program_index(tokens):
    """Where the program (or a Flatpak's app id) is in the Exec tokens: options go right after it."""
    i = 0
    while i < len(tokens) and (tokens[i] == "env" or ("=" in tokens[i] and not tokens[i].startswith("/"))):
        i += 1
    if i < len(tokens) and os.path.basename(tokens[i]) == "flatpak":
        for j in range(i + 1, len(tokens)):
            t = tokens[j]
            if not t.startswith("-") and t != "run" and "." in t:
                return j
    return i if i < len(tokens) else -1


def minimize_info(exec_value, entry_exec):
    """(can it start minimized, does its autostart entry do so)"""
    flag = MINIMIZE_FLAGS.get(exec_key(exec_value or entry_exec or ""))
    if not flag:
        return False, False
    # the app itself, not a shortcut into it: every Steam game's entry runs
    # "steam steam://rungameid/..." and has nothing to start minimized
    base = exec_tokens(exec_value or entry_exec or "") or []
    at = program_index(base)
    extra = [t for t in base[at + 1:] if not t.startswith("-") and not t.startswith("%") and not t.startswith("@@")] if at >= 0 else []
    if extra:
        return False, False
    toks = exec_tokens(entry_exec or "") or []
    return True, flag in toks


def enabled(keys):
    return bool(keys) and not is_true(keys.get("Hidden")) \
        and keys.get("X-GNOME-Autostart-enabled", "true").lower() != "false"


def autostart_entries():
    out = {}
    if os.path.isdir(AUTOSTART):
        for name in sorted(os.listdir(AUTOSTART)):
            if name.endswith(".desktop"):
                out[name] = read_entry(os.path.join(AUTOSTART, name))
    return out


def unique_keys(apps):
    """Programs only one installed app runs. Only those can match an autostart entry by program:
    every Steam game's shortcut runs "steam" too, and took Steam's own entry."""
    count = {}
    for _, keys in apps.values():
        if keys.get("Exec"):
            k = exec_key(keys["Exec"])
            count[k] = count.get(k, 0) + 1
    return {k for k, n in count.items() if n == 1}


def cmd_list():
    apps = installed_apps()
    auto = autostart_entries()
    unique = unique_keys(apps)
    # an autostart entry made from another app's file under a different name still counts
    by_exec = {}
    for name, keys in auto.items():
        if keys and keys.get("Exec"):
            by_exec.setdefault(exec_key(keys["Exec"]), name)
    rows, used = [], set(i for i in apps if i in auto)    # entries named after their app
    for app_id, (_, keys) in apps.items():
        entry = None
        if app_id in auto:
            entry = app_id
        elif keys.get("Exec") and exec_key(keys["Exec"]) in unique:
            entry = by_exec.get(exec_key(keys["Exec"]))
            if entry in used:
                entry = None    # one entry belongs to one app
        if entry:
            used.add(entry)
        can_min, is_min = minimize_info(keys.get("Exec", ""), (auto[entry] or {}).get("Exec", "") if entry else "")
        rows.append({"id": app_id, "name": keys.get("Name", app_id), "icon": keys.get("Icon", ""),
                     "comment": keys.get("Comment", ""), "on": bool(entry) and enabled(auto[entry]),
                     "entry": entry or "", "canMinimize": can_min, "minimized": is_min})
    for name, keys in auto.items():
        if name in used or not keys:
            continue
        can_min, is_min = minimize_info(keys.get("Exec", ""), keys.get("Exec", ""))
        rows.append({"id": name, "name": keys.get("Name", name), "icon": keys.get("Icon", ""),
                     "comment": keys.get("Comment", "") or keys.get("Exec", ""),
                     "on": enabled(keys), "entry": name, "canMinimize": can_min, "minimized": is_min})
    rows.sort(key=lambda r: str(r["name"]).lower())
    print(json.dumps(rows))


def set_key(path, key, value):
    """Set (or with value None, remove) a key in the [Desktop Entry] section."""
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    out, inside, done = [], False, False
    for line in lines:
        s = line.strip()
        if s.startswith("["):
            if inside and not done and value is not None:
                out.append(f"{key}={value}")
                done = True
            inside = s == "[Desktop Entry]"
        elif inside and s.split("=", 1)[0].strip() == key:
            if value is not None and not done:
                out.append(f"{key}={value}")
                done = True
            continue
        out.append(line)
    if inside and not done and value is not None:
        out.append(f"{key}={value}")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    os.replace(tmp, path)


def find_entry(app_id):
    """The autostart file for this app: its own name, or one with the same Exec."""
    path = os.path.join(AUTOSTART, app_id)
    if os.path.isfile(path):
        return path
    apps = installed_apps()
    app = apps.get(app_id)
    if app and app[1].get("Exec") and exec_key(app[1]["Exec"]) in unique_keys(apps):
        key = exec_key(app[1]["Exec"])
        for name, keys in autostart_entries().items():
            if name in apps and name != app_id:
                continue    # another app's own entry
            if keys and keys.get("Exec") and exec_key(keys["Exec"]) == key:
                return os.path.join(AUTOSTART, name)
    return None


def cmd_on(app_id):
    path = find_entry(app_id)
    if path:
        # it was turned off (Hidden / GNOME's switch): turn it back on
        set_key(path, "Hidden", None)
        set_key(path, "X-GNOME-Autostart-enabled", None)
        return
    app = installed_apps().get(app_id)
    if not app:
        sys.exit(f"no installed app {app_id}")
    os.makedirs(AUTOSTART, exist_ok=True)
    dest = os.path.join(AUTOSTART, app_id)
    shutil.copyfile(app[0], dest)
    set_key(dest, MARK, "true")


def cmd_off(app_id):
    path = find_entry(app_id)
    if not path:
        return
    keys = read_entry(path) or {}
    if is_true(keys.get(MARK)):
        os.remove(path)     # made here: nothing else to keep
    else:
        # written by the app or by hand: keep it, switched off the standard way
        set_key(path, "Hidden", "true")


def cmd_minimized(app_id, on):
    """Add or remove the app's start-minimized option in its autostart entry (made if missing)."""
    path = find_entry(app_id)
    if not path:
        cmd_on(app_id)
        path = find_entry(app_id)
    if not path:
        sys.exit(f"no autostart entry for {app_id}")
    keys = read_entry(path) or {}
    flag = MINIMIZE_FLAGS.get(exec_key(keys.get("Exec", "")))
    if not flag:
        sys.exit("this app has no option to start minimized")
    toks = exec_tokens(keys.get("Exec", ""))
    if toks is None:
        sys.exit("can't read the app's Exec line")
    toks = [t for t in toks if t != flag]
    if on:
        at = program_index(toks)
        if at < 0:
            sys.exit("can't find the program in the Exec line")
        toks.insert(at + 1, flag)
    set_key(path, "Exec", exec_join(toks))


def exec_argv(value, keys, path):
    """The Exec line as an argument list, without the spec's %f/%u/... field codes."""
    try:
        # the spec's escapes inside quotes (\$ \` \\); shlex leaves \$ and \` as they are
        parts = shlex.split(value.replace("\\$", "$").replace("\\`", "`"))
    except ValueError:
        return None
    argv = []
    for p in parts:
        # field codes, and the @@ / @@u markers Flatpak puts round them
        if p in ("%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%v", "%m", "%k", "@@", "@@u", "@@f"):
            continue
        if p == "%i":
            if keys.get("Icon"):
                argv += ["--icon", keys["Icon"]]
            continue
        if p == "%c":
            argv.append(keys.get("Name", ""))
            continue
        argv.append(p.replace("%%", "%"))
    return argv or None


def systemd_runs_autostart():
    if not os.path.isdir("/run/systemd/system") or not shutil.which("systemctl"):
        return False
    r = subprocess.run(["systemctl", "--user", "is-active", "xdg-desktop-autostart.target"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def cmd_run():
    if systemd_runs_autostart():
        return
    # once per login: the shell restarts (updates, icon theme changes) shouldn't start apps again
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    marker = os.path.join(runtime, "monolith", "autostart.done")
    if os.path.exists(marker):
        return
    os.makedirs(os.path.dirname(marker), exist_ok=True)
    open(marker, "w").close()

    desktops = [d.lower() for d in (os.environ.get("XDG_CURRENT_DESKTOP") or "niri").split(":") if d]
    for name, keys in autostart_entries().items():
        if not keys or not enabled(keys) or keys.get("Type", "Application") != "Application":
            continue
        only = [d.lower() for d in keys.get("OnlyShowIn", "").split(";") if d]
        if only and not any(d in only for d in desktops):
            continue
        if any(d.lower() in desktops for d in keys.get("NotShowIn", "").split(";") if d):
            continue
        if keys.get("TryExec") and not shutil.which(os.path.expanduser(keys["TryExec"])):
            continue
        argv = exec_argv(keys.get("Exec", ""), keys, os.path.join(AUTOSTART, name))
        if not argv:
            continue
        cwd = keys.get("Path") or HOME
        try:
            subprocess.Popen(argv, cwd=cwd if os.path.isdir(cwd) else HOME, start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as e:
            print(f"autostart: {name}: {e}", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list()
    elif cmd in ("on", "off") and len(sys.argv) == 3:
        (cmd_on if cmd == "on" else cmd_off)(sys.argv[2])
    elif cmd == "minimized" and len(sys.argv) == 4 and sys.argv[3] in ("on", "off"):
        cmd_minimized(sys.argv[2], sys.argv[3] == "on")
    elif cmd == "run":
        cmd_run()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
