#!/usr/bin/env bash
# Screen zoom on Meta+Ctrl+scroll (niri keybinds), like KDE's zoom shortcut.
#   zoom.sh in     zoom in (starts wooz, following the mouse)
#   zoom.sh out    zoom out; back at the start it closes wooz
#   zoom.sh off    close it
# niri has no live zoom, so this drives wooz (a zoomable snapshot of the screen). While Meta+Ctrl
# is held niri takes the scroll for the keybind, so it never reaches wooz: each step presses
# wooz's own =/- key instead (zoom_keys.py, a virtual keyboard: see there why not wtype), and
# the steps are counted so zooming all the way out closes it.
DIR="$(dirname "$(readlink -f "$0")")"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RUN/monolith-zoom-level"
FIFO="$RUN/monolith-zoom.fifo"
running() { pgrep -x wooz >/dev/null; }
level() { running && cat "$STATE" 2>/dev/null || echo 0; }
send() {
    # the key helper reads the FIFO; never block if it isn't there
    [ -p "$FIFO" ] && pgrep -f "zoom_keys.py" >/dev/null && timeout 1 sh -c 'echo "$1" > "$2"' _ "$1" "$FIFO"
}

case "${1:-in}" in
    in)
        if running; then
            send in && echo $(( $(level) + 1 )) > "$STATE"
        else
            echo 1 > "$STATE"
            [ -p "$FIFO" ] || { rm -f "$FIFO"; mkfifo "$FIFO"; }
            setsid -f wooz --mouse-track --zoom-in 25% >/dev/null 2>&1
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
            send out && echo "$n" > "$STATE"
        fi
        ;;
    off)
        pkill -x wooz
        rm -f "$STATE"
        ;;
esac
