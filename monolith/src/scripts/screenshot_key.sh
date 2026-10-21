#!/usr/bin/env bash
# usage: screenshot_key.sh <niri key, e.g. Mod+C>
# A niri keybind that the screenshot tool also uses (Settings -> Screenshots) runs this instead
# of its normal action: if the screenshot tool is open and has an action on that key, it gets
# it; otherwise the bind's original action (saved by niri_screenshot_keys.sh) runs as usual.

key="$1"
[ -n "$key" ] || exit 1
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

if [ -n "$MAIN_QML" ]; then
    res="$(quickshell -p "$MAIN_QML" ipc call screenshotOverlay key "$key" 2>/dev/null)"
    [ "$res" = "handled" ] && exit 0
fi

fallbacks="$HOME/.config/monolith/niri-key-fallbacks.json"
body="$(jq -r --arg k "$key" '.[$k] // empty' "$fallbacks" 2>/dev/null)"
[ -n "$body" ] || exit 0

# the original bind body, e.g.  spawn "kitty";   spawn-sh "a | b";   close-window;
python3 - "$body" <<'EOF'
import os, shlex, subprocess, sys
body = sys.argv[1].strip().rstrip(";").strip()
parts = shlex.split(body)
if not parts:
    sys.exit(0)
action, args = parts[0], parts[1:]
if action == "spawn":
    subprocess.Popen(args, start_new_session=True)
elif action == "spawn-sh":
    subprocess.Popen(["sh", "-c", " ".join(args)], start_new_session=True)
else:
    subprocess.run(["niri", "msg", "action", action, *args])
EOF
