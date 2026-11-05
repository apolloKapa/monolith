#!/usr/bin/env python3
"""Startup apps and AppImages for Settings -> Software.

    startup.py apps              JSON list: every app (name, id, icon) and whether it starts at login
    startup.py set ID on|off     start that app at login, or not (~/.config/autostart/ID)
    startup.py run               start the ones that are on (once, at login; not under systemd,
                                 which starts ~/.config/autostart itself)
    startup.py appimages DIR     JSON list of the AppImages in DIR, and which have an app entry
    startup.py appimage add|remove FILE    give an AppImage an app entry (so Search and the dock
                                 know it), or take it away
"""
import configparser
import glob
import json
import os
import shlex
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or HOME + "/.config"
DATA = os.environ.get("XDG_DATA_HOME") or HOME + "/.local/share"
AUTO = CONF + "/autostart"
APPS_DIRS = [DATA + "/applications"] + [d + "/applications" for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")]
TAG = "X-Monolith-Next"


def entry(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        return dict(cp["Desktop Entry"])
    except Exception:
        return {}


def installed():
    apps = {}
    for d in reversed(APPS_DIRS):  # the user's own entries win
        for f in glob.glob(d + "/*.desktop"):
            e = entry(f)
            if e.get("Type") == "Application" and e.get("NoDisplay") != "true" and e.get("Hidden") != "true":
                apps[os.path.basename(f)] = {"id": os.path.basename(f), "name": e.get("Name", ""), "icon": e.get("Icon", ""), "path": f}
            else:
                apps.pop(os.path.basename(f), None)
    return apps


def is_on(e):
    return e and e.get("Hidden") != "true" and e.get("X-GNOME-Autostart-enabled", "true") != "false"


def cmd_apps():
    apps = installed()
    out = []
    for i, a in apps.items():
        a = dict(a, on=is_on(entry(AUTO + "/" + i)) if os.path.exists(AUTO + "/" + i) else False)
        out.append(a)
    # autostart entries with no installed app (written by hand or by the app)
    for f in glob.glob(AUTO + "/*.desktop"):
        i = os.path.basename(f)
        if i not in apps:
            e = entry(f)
            out.append({"id": i, "name": e.get("Name", i), "icon": e.get("Icon", ""), "path": f, "on": is_on(e)})
    out.sort(key=lambda a: (not a["on"], a["name"].lower()))
    print(json.dumps(out))


def cmd_set(i, on):
    os.makedirs(AUTO, exist_ok=True)
    dst = AUTO + "/" + i
    if on:
        if os.path.exists(dst):
            lines = [l for l in open(dst, encoding="utf-8").read().split("\n") if not l.startswith(("Hidden=", "X-GNOME-Autostart-enabled="))]
            open(dst, "w", encoding="utf-8").write("\n".join(lines))
        else:
            src = installed().get(i)
            if not src:
                sys.exit("no such app " + i)
            lines = open(src["path"], encoding="utf-8").read().rstrip("\n").split("\n")
            at = lines.index("[Desktop Entry]") + 1 if "[Desktop Entry]" in lines else 0
            lines.insert(at, TAG + "=true")   # made here: removed again when switched off
            open(dst, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    elif os.path.exists(dst):
        # a copy made here is just removed; the app's own entry is switched off, so it stays known
        if TAG + "=true" in open(dst, encoding="utf-8").read():
            os.remove(dst)
        else:
            text = open(dst, encoding="utf-8").read().rstrip("\n").split("\n")
            text = [l for l in text if not l.startswith("Hidden=")]
            text.insert(1, "Hidden=true")
            open(dst, "w", encoding="utf-8").write("\n".join(text) + "\n")


def cmd_run():
    if os.path.isdir("/run/systemd/system"):
        return
    for f in sorted(glob.glob(AUTO + "/*.desktop")):
        e = entry(f)
        if not is_on(e) or not e.get("Exec"):
            continue
        if e.get("OnlyShowIn") or e.get("TryExec") and not any(os.access(os.path.join(p, e["TryExec"]), os.X_OK) for p in os.environ.get("PATH", "").split(":")):
            continue
        args = [a for a in shlex.split(e["Exec"]) if not (len(a) == 2 and a[0] == "%")]
        try:
            subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            pass


def appimage_entry(f):
    return DATA + "/applications/appimage-" + os.path.splitext(os.path.basename(f))[0].replace(" ", "_") + ".desktop"


def cmd_appimages(d):
    files = sorted(glob.glob(os.path.join(os.path.expanduser(d), "*.AppImage")) + glob.glob(os.path.join(os.path.expanduser(d), "*.appimage")))
    print(json.dumps([{"file": f, "name": os.path.splitext(os.path.basename(f))[0], "added": os.path.exists(appimage_entry(f)),
                       "size": os.path.getsize(f)} for f in files]))


def cmd_appimage(action, f):
    dst = appimage_entry(f)
    if action == "add":
        os.chmod(f, os.stat(f).st_mode | 0o111)
        name = os.path.splitext(os.path.basename(f))[0].replace("-", " ").replace("_", " ")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w", encoding="utf-8").write(
            "[Desktop Entry]\nType=Application\nName=%s\nExec=%s %%U\nIcon=application-x-executable\nCategories=Utility;\n%s=appimage\n"
            % (name, shlex.quote(f), TAG))
    elif os.path.exists(dst):
        os.remove(dst)


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "apps":
        cmd_apps()
    elif a[0] == "set":
        cmd_set(a[1], a[2] == "on")
    elif a[0] == "run":
        cmd_run()
    elif a[0] == "appimages":
        cmd_appimages(a[1])
    elif a[0] == "appimage":
        cmd_appimage(a[1], a[2])


if __name__ == "__main__":
    main()
