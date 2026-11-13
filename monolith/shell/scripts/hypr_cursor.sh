#!/bin/sh
# The cursor theme and size on Hyprland (Settings → Appearance → Cursor): set now with
# `hyprctl setcursor`, for GTK apps through gsettings, and kept for the next login in
# Monolith's own file, monolith-cursor.lua (for hyprland.lua) or monolith-cursor.conf,
# included once at the end of the main config.
#   hypr_cursor.sh <theme> <size>     hypr_cursor.sh read   (prints "theme size")
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
if [ -f "$cfg/hyprland.lua" ]; then kind=lua; main="$cfg/hyprland.lua"; else kind=conf; main="$cfg/hyprland.conf"; fi
file="$cfg/monolith-cursor.$kind"

if [ "$1" = read ]; then
    # (Monolith's file, else what the session has)
    t=$(sed -n 's/.*XCURSOR_THEME[",[:space:]]*\([^",)]*\).*/\1/p' "$file" 2>/dev/null | head -1)
    s=$(sed -n 's/.*XCURSOR_SIZE[",[:space:]]*\([0-9]*\).*/\1/p' "$file" 2>/dev/null | head -1)
    echo "${t:-${XCURSOR_THEME:-}} ${s:-${XCURSOR_SIZE:-24}}"
    exit 0
fi

theme="$1"; size="${2:-24}"
[ -n "$theme" ] || { echo "usage: hypr_cursor.sh <theme> <size> | read" >&2; exit 2; }

hyprctl setcursor "$theme" "$size" >/dev/null 2>&1
gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null

mkdir -p "$cfg"
if [ "$kind" = lua ]; then
    cat > "$file" <<EOF
-- Written by Monolith (Settings → Appearance → Cursor). Changes here are replaced.
hl.env("XCURSOR_THEME", "$theme")
hl.env("XCURSOR_SIZE", "$size")
hl.env("HYPRCURSOR_SIZE", "$size")
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprctl setcursor '$theme' $size")
end)
EOF
    line='require("monolith-cursor")'
else
    cat > "$file" <<EOF
# Written by Monolith (Settings → Appearance → Cursor). Changes here are replaced.
env = XCURSOR_THEME,$theme
env = XCURSOR_SIZE,$size
env = HYPRCURSOR_SIZE,$size
exec-once = hyprctl setcursor '$theme' $size
EOF
    line="source = $file"
fi
[ -f "$main" ] && ! grep -qxF "$line" "$main" && printf '\n%s\n' "$line" >> "$main"
exit 0
