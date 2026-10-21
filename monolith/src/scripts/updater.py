import json
import os
import re
import sys
import time
import shutil
import subprocess
import urllib.request

# where updates come from: written by the installer next to this install
REPO = "kasc0b3r/dotfiles"
BRANCH = "main"
_source_env = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))), "install", "source.env")
try:
    for _line in open(_source_env):
        _k, _, _v = _line.strip().partition("=")
        _v = _v.strip().strip('"')
        if _k == "REPO_SLUG" and _v:
            REPO = _v
        elif _k == "MONOLITH_BRANCH" and _v:
            BRANCH = _v
except OSError:
    pass
DEFAULT_VER = "1.0.0"

state_dir = os.path.expanduser("~/.local/state/monolith")
if "--state-dir" in sys.argv:
    try:
        idx = sys.argv.index("--state-dir")
        if idx + 1 < len(sys.argv):
            state_dir = sys.argv[idx + 1]
    except Exception:
        pass

package_managed = os.path.isfile(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
    "package-managed",
))

state_file = os.path.join(state_dir, "version")
last_check_file = os.path.join(state_dir, "last_check")
notified_file = os.path.join(state_dir, "last_notified")

if "--save-notified" in sys.argv:
    try:
        idx = sys.argv.index("--save-notified")
        if idx + 1 < len(sys.argv):
            ver_to_save = sys.argv[idx + 1]
            os.makedirs(state_dir, exist_ok=True)
            with open(notified_file, "w") as f:
                f.write(ver_to_save)
    except Exception:
        pass
    sys.exit(0)

if "--delay" in sys.argv:
    if os.path.isfile(last_check_file):
        try:
            with open(last_check_file, "r") as f:
                last_ts = float(f.read().strip())
            elapsed = time.time() - last_ts
            remaining = int(max(0, 3600 - elapsed) * 1000)
            print(remaining)
            sys.exit(0)
        except Exception:
            pass
    print(0)
    sys.exit(0)

def get_local_ver():
    if os.path.isfile(state_file):
        try:
            with open(state_file, "r") as f:
                for line in f:
                    if line.startswith("MONOLITH_VERSION="):
                        v = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if v:
                            return v
        except Exception:
            pass
    return DEFAULT_VER

def get_last_notified():
    if os.path.isfile(notified_file):
        try:
            with open(notified_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return ""

def parse_v(v):
    nums = re.findall(r"\d+", v)
    return [int(x) for x in nums] if nums else [0]

try:
    os.makedirs(state_dir, exist_ok=True)
    with open(last_check_file, "w") as f:
        f.write(str(time.time()))
except Exception:
    pass

local_ver = get_local_ver()
remote_ver = local_ver

def fetch_remote_ver():
    """monolith/version.txt on the install's repo + branch: a plain download when the repo is
    public, otherwise through the GitHub CLI's login (private repo)"""
    path = "monolith/version.txt"
    try:
        req = urllib.request.Request(
            f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/{path}",
            headers={"User-Agent": "monolith-updater"}
        )
        return urllib.request.urlopen(req, timeout=5).read().decode("utf-8").strip()
    except Exception:
        pass
    if shutil.which("gh"):
        try:
            out = subprocess.run(
                ["gh", "api", f"repos/{REPO}/contents/{path}?ref={BRANCH}", "-H", "Accept: application/vnd.github.raw"],
                capture_output=True, text=True, timeout=10)
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except Exception:
            pass
    return None

if not package_managed:
    remote_ver = fetch_remote_ver() or local_ver

has_update = parse_v(remote_ver) > parse_v(local_ver)

print(json.dumps({
    "local": local_ver,
    "remote": remote_ver,
    "has_update": has_update,
    "last_notified": get_last_notified()
}))
