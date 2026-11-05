#!/bin/sh
# Run the new shell inside a nested niri (a window on the current desktop), so it can be
# tried and screenshotted without touching the real session. Stop with: dev/nested.sh stop
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
rt=/run/user/$(id -u)/mnext
if [ "$1" = "stop" ]; then
    # niri, and everything started inside the test session (its D-Bus, portals, apps)
    for p in $(pgrep -u "$(id -u)"); do
        { tr '\0' '\n' < /proc/$p/environ; } 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=$rt" && kill "$p" 2>/dev/null
    done
    fusermount3 -u "$rt/doc" 2>/dev/null || true
    exit 0
fi
mkdir -p "$rt"; chmod 700 "$rt"
host_wl="/run/user/$(id -u)/${WAYLAND_DISPLAY:-wayland-1}"
cat > "$rt/niri.kdl" <<KDL
input {
    keyboard {
        xkb {
            layout "us,gr"
        }
    }
}
spawn-at-startup "quickshell" "-p" "${SHELL_QML:-$here/shell/shell.qml}"
spawn-at-startup "kitty"
prefer-no-csd
hotkey-overlay {
    skip-at-startup
}
binds {
    Mod+Space { spawn "quickshell" "ipc" "-p" "$here/shell/shell.qml" "call" "hub" "toggle" "search"; }
    Mod+Q { close-window; }
}
KDL
env -u NIRI_SOCKET PIPEWIRE_RUNTIME_DIR="/run/user/$(id -u)" XDG_RUNTIME_DIR="$rt" WAYLAND_DISPLAY="$host_wl" setsid -f dbus-run-session -- niri -c "$rt/niri.kdl" >"$rt/niri.log" 2>&1
echo "nested niri started (runtime $rt)"
