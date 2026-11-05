#!/bin/sh
# Package cleanup (Settings -> Software): what can go, and cleaning it in a terminal that asks.
#   cleanup.sh status        one line per check that applies here: id<TAB>title<TAB>what it found
#   cleanup.sh run ID        the cleaning itself (run inside a terminal; every step asks first)
# Checks: depclean, distfiles, world (Portage); orphans, pkgcache, aurcache (pacman); flatunused,
# flatdata (Flatpak).
size() { du -sh "$1" 2>/dev/null | cut -f1; }

status() {
    if command -v emerge >/dev/null; then
        printf 'world\tYour packages (Portage world set)\t%s packages you installed\n' "$(grep -c . /var/lib/portage/world 2>/dev/null)"
        printf 'depclean\tUnneeded dependencies\temerge --depclean lists them and asks\n'
        [ -d /var/cache/distfiles ] && printf 'distfiles\tSource downloads\t%s in /var/cache/distfiles\n' "$(size /var/cache/distfiles)"
    fi
    if command -v pacman >/dev/null; then
        printf 'orphans\tUnneeded dependencies\t%s packages nothing needs\n' "$(pacman -Qdtq 2>/dev/null | grep -c .)"
        printf 'pkgcache\tDownloaded packages\t%s in /var/cache/pacman/pkg\n' "$(size /var/cache/pacman/pkg)"
        for h in yay paru; do
            [ -d "$HOME/.cache/$h" ] && printf 'aurcache\tAUR build folders\t%s in ~/.cache/%s\n' "$(size "$HOME/.cache/$h")" "$h"
        done
    fi
    if command -v flatpak >/dev/null; then
        printf 'flatunused\tUnused Flatpak runtimes\t%s runtimes installed\n' "$(flatpak list --runtime --columns=application 2>/dev/null | grep -c .)"
        n=0; s=0
        if [ -d "$HOME/.var/app" ]; then
            apps=$(flatpak list --app --columns=application 2>/dev/null)
            for d in "$HOME"/.var/app/*/; do
                [ -d "$d" ] || continue
                id=$(basename "$d")
                printf '%s\n' "$apps" | grep -qx "$id" || n=$((n + 1))
            done
        fi
        printf 'flatdata\tLeftover Flatpak data\t%s folders of apps that are gone\n' "$n"
    fi
}

ask() { printf '\n%s [y/N] ' "$1"; read -r a; [ "$a" = y ] || [ "$a" = Y ]; }

run() {
    case "$1" in
        world) echo "Your world set (packages you asked for). Remove one with: sudo emerge --ask --deselect <name> && sudo emerge --ask --depclean"; echo; cat /var/lib/portage/world ;;
        depclean) sudo emerge --ask --depclean ;;
        distfiles) command -v eclean-dist >/dev/null && sudo eclean-dist --deep || { ask "eclean-dist (gentoolkit) isn't installed. Delete everything in /var/cache/distfiles?" && sudo rm -rf /var/cache/distfiles/*; } ;;
        orphans) o=$(pacman -Qdtq); [ -n "$o" ] && sudo pacman -Rns $o || echo "Nothing to remove." ;;
        pkgcache) command -v paccache >/dev/null && sudo paccache -rk2 || sudo pacman -Sc ;;
        aurcache) for h in yay paru; do [ -d "$HOME/.cache/$h" ] && ask "Delete ~/.cache/$h ($(size "$HOME/.cache/$h"))?" && rm -rf "$HOME/.cache/$h"; done ;;
        flatunused) flatpak uninstall --unused ;;
        flatdata)
            apps=$(flatpak list --app --columns=application)
            for d in "$HOME"/.var/app/*/; do
                id=$(basename "$d")
                printf '%s\n' "$apps" | grep -qx "$id" && continue
                ask "Delete the data of $id ($(size "$d"))?" && rm -rf "$d"
            done ;;
    esac
    printf '\nDone. Press Enter to close.'; read -r _
}

case "$1" in
    status) status ;;
    run) run "$2" ;;
    *) sed -n '2,6p' "$0" ;;
esac
