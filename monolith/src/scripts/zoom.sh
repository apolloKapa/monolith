#!/usr/bin/env bash
# Screen zoom on Meta+Ctrl+scroll (niri keybinds), like KDE's zoom shortcut.
#   zoom.sh in     zoom in (starts wooz, following the mouse)
#   zoom.sh out    zoom out; back at the start it closes wooz
#   zoom.sh off    close it
#   zoom.sh setup  at shell start: use niri's own live zoom when it has one (see below)
#
# A niri with the magnifier (niri-wm/niri PR #4572, e.g. the niri-zoom package) zooms live, like
# KDE: setup writes config/zoom.kdl (zoom-modifier "mod-ctrl") and includes it, and niri then takes
# Meta+Ctrl+scroll itself before these binds see it. Stock niri would reject that config, so there
# setup takes the include out again and the binds below drive wooz.
#
# Stock niri has no live zoom, so this drives wooz (a zoomable snapshot of the screen). While Meta+Ctrl
# is held niri takes the scroll for the keybind, so it never reaches wooz: each step presses
# wooz's own =/- key instead (zoom_keys.py, a virtual keyboard: see there why not wtype), and
# the steps are counted so zooming all the way out closes it.
DIR="$(dirname "$(readlink -f "$0")")"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
STEP=12        # wooz key presses per scroll notch (each is ~0.7% of the view)
START=20       # how far the first notch zooms in, in %
STATE="$RUN/monolith-zoom-level"
FIFO="$RUN/monolith-zoom.fifo"
running() { pgrep -x wooz >/dev/null; }
level() { running && cat "$STATE" 2>/dev/null || echo 0; }
send() {
    # the key helper reads the FIFO; never block if it isn't there
    [ -p "$FIFO" ] && pgrep -f "zoom_keys.py" >/dev/null && timeout 1 sh -c 'echo "$1" > "$2"' _ "$1" "$FIFO"
}

native_zoom() { niri msg action toggle-magnifier --help >/dev/null 2>&1; }

case "${1:-in}" in
    setup)
        conf="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
        main="$conf/config.kdl"
        [ -f "$main" ] || exit 0
        line='include "config/zoom.kdl"'
        if native_zoom; then
            mkdir -p "$conf/config"
            [ -f "$conf/config/zoom.kdl" ] || printf '%s\n' \
                "// Added by Monolith: live zoom on Meta+Ctrl+scroll, like KDE (this niri has the magnifier)" \
                "magnifier {" \
                "    zoom-modifier \"mod-ctrl\"" \
                "    // each scroll notch zooms 20% in or out; back at 1x it switches off" \
                "    zoom-speed 0.2" \
                "    max-zoom 10.0" \
                "}" > "$conf/config/zoom.kdl"
            grep -qxF "$line" "$main" || printf '%s\n' "$line" >> "$main"
        elif grep -qxF "$line" "$main"; then
            grep -vxF "$line" "$main" > "$main.tmp" && cat "$main.tmp" > "$main" && rm -f "$main.tmp"
        fi
        ;;
    in)
        # niri zooms live itself (setup); a bind that still gets here has nothing to do
        native_zoom && grep -qxF 'include "config/zoom.kdl"' "${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl" 2>/dev/null && exit 0
        if running; then
            send "in $STEP" && echo $(( $(level) + 1 )) > "$STATE"
        else
            echo 1 > "$STATE"
            [ -p "$FIFO" ] || { rm -f "$FIFO"; mkfifo "$FIFO"; }
            # --invert-scroll: scrolling inside wooz (without Meta+Ctrl) goes the same way, up = in
            setsid -f wooz --mouse-track --invert-scroll --zoom-in "$START%" >/dev/null 2>&1
            # the key helper waits for wooz to be up, and quits with it
            setsid -f sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x wooz >/dev/null && break; sleep 0.1; done; exec python3 "$1" "$2"' _ "$DIR/zoom_keys.py" "$FIFO" >/dev/null 2>&1
        fi
        ;;
    out)
        running || exit 0
        n=$(( $(level) - 1 ))
        if [ "$n" -le 0 ]; then
            pkill -x wooz
            rm -f "$STATE"
        else
            send "out $STEP" && echo "$n" > "$STATE"
        fi
        ;;
    off)
        pkill -x wooz
        rm -f "$STATE"
        ;;
esac
