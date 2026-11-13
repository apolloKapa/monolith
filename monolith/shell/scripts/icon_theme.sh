#!/bin/sh
# Switch the icon pack everywhere: GTK apps (gsettings and settings.ini), Qt apps (qt6ct and
# qt5ct, which the shell uses too) and KDE apps (kdeglobals). Only gsettings was set before,
# so the shell and Qt apps kept the old icons. Qt reads its icon theme once when it starts,
# so the shell then restarts and opens Settings → Appearance again.
#   icon_theme.sh <name> [--no-restart]
name="$1"
[ -n "$name" ] || { echo "usage: icon_theme.sh <name> [--no-restart]" >&2; exit 2; }
here=$(cd "$(dirname "$0")/../.." && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

gsettings set org.gnome.desktop.interface icon-theme "$name" 2>/dev/null

# key=value in [section] of an ini file: replaced, added under the section, or a new section
ini_set() {
    file="$1" section="$2" key="$3" value="$4"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || : > "$file"
    awk -v s="[$section]" -v k="$key" -v v="$value" '
        BEGIN { in_s = 0; done = 0 }
        /^\[.*\]$/ { if (in_s && !done) { print k "=" v; done = 1 } in_s = ($0 == s) }
        in_s && index($0, k "=") == 1 { if (!done) { print k "=" v; done = 1 } next }
        { print }
        END { if (!done) { if (!in_s) { if (NR > 0) print ""; print s } print k "=" v } }
    ' "$file" > "$file.tmp.$$" && mv "$file.tmp.$$" "$file"
}

for q in qt6ct qt5ct; do ini_set "$cfg/$q/$q.conf" Appearance icon_theme "$name"; done
for g in gtk-3.0 gtk-4.0; do ini_set "$cfg/$g/settings.ini" Settings gtk-icon-theme-name "$name"; done
ini_set "$cfg/kdeglobals" Icons Theme "$name"

[ "$2" = "--no-restart" ] && exit 0
"$here/bin/monolith" restart
# reopen where you were, once the new shell answers
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 0.5
    quickshell ipc -p "$here/shell/shell.qml" call settings open appearance >/dev/null 2>&1 && break
done
