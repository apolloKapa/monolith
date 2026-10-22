#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd -P)"
else
    SCRIPT_DIR="$(pwd -P)"
fi

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true

ACTION="open"
case "$1" in
    open|toggle|close|prewarm) ACTION="$1"; shift ;;
esac
TAB="$1"
SUBTAB="$2"

SETTINGS_QML="$QS_DIR/SettingsApp.qml"
APP_ID="monolith-settings"
GUIDE_MODE_FILE="${QS_CACHE_GUIDE:-$QS_CACHE_DIR/guide}/last_tab.txt"

if [[ ! -f "$SETTINGS_QML" ]]; then
    echo "settings: $SETTINGS_QML not found" >&2
    exit 1
fi

settings_ipc() {
    quickshell -p "$SETTINGS_QML" ipc call settings "$@" >/dev/null 2>&1
}

is_running() {
    settings_ipc ping
}

focus_window() {
    settings_ipc focus
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch focuswindow "class:^(${APP_ID})$" >/dev/null 2>&1 \
            || hyprctl dispatch 'hl.dsp.focus({ window = "class:^('"$APP_ID"')$" })' >/dev/null 2>&1
    elif [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
        local id
        id="$(niri msg -j windows 2>/dev/null | jq -r --arg a "$APP_ID" '[.[] | select(.app_id == $a)][0].id // empty')"
        [[ -n "$id" ]] && niri msg action focus-window --id "$id" >/dev/null 2>&1
    elif [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
        swaymsg "[app_id=\"$APP_ID\"] focus" >/dev/null 2>&1
    elif [[ -n "${MANGO_INSTANCE_SIGNATURE:-}" ]] && command -v mmsg >/dev/null 2>&1; then
        local id
        id="$(mmsg get all-clients 2>/dev/null | jq -r --arg a "$APP_ID" '[.. | objects | select(.appid? == $a)][0].id // empty' 2>/dev/null)"
        [[ -n "$id" ]] && mmsg dispatch focusid "client,$id" >/dev/null 2>&1
    fi
}

write_tab() {
    [[ -n "$TAB" ]] || return 0
    mkdir -p "$(dirname "$GUIDE_MODE_FILE")"
    if [[ -n "$SUBTAB" ]]; then
        echo "$TAB:$SUBTAB" > "$GUIDE_MODE_FILE"
    else
        echo "$TAB" > "$GUIDE_MODE_FILE"
    fi
}

if [[ "$ACTION" == "close" ]]; then
    settings_ipc close
    exit 0
fi

# the settings app keeps running hidden after it's closed (and is started hidden at login),
# so opening it just shows the window again
if is_running; then
    [[ "$ACTION" == "prewarm" ]] && exit 0
    if [[ "$ACTION" == "toggle" ]] && [[ "$(quickshell -p "$SETTINGS_QML" ipc call settings isOpen 2>/dev/null)" == "true" ]]; then
        settings_ipc close
        exit 0
    fi
    write_tab
    [[ -n "$TAB" ]] && settings_ipc goto "$TAB" "$SUBTAB"
    settings_ipc open
    focus_window
    exit 0
fi

if [[ "$ACTION" == "prewarm" ]]; then
    MONOLITH_SETTINGS_HIDDEN=1 exec setsid quickshell -n -p "$SETTINGS_QML" >/dev/null 2>&1 < /dev/null
fi
write_tab
exec setsid quickshell -n -p "$SETTINGS_QML"
