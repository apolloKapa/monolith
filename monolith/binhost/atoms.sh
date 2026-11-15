#!/usr/bin/env bash
# Every Gentoo package (atom) a Monolith install can ask for — niri and its helpers (on Hyprland
# Monolith uses the Hyprland you have),
# the keybind apps, the login screen — from the installer's own lists and Portage map, one a line.
# What the binhost builder (build.sh) builds binaries of. Run from the repo root.
set -e
cd "$(dirname "$0")/../.."
PORTAGE_MAP_FILE=install/modules/pm/portage-map.txt
eval "$(sed -n '/^declare -gA PORTAGE_MAP=()/,/^unset _name _rest/p;/^portage_atoms() {/,/^}/p' install/modules/pm/portage.sh)"
eval "$(sed -n '/^REQUIRED_PKGS=(/,/^)/p;/^KEYBIND_PKGS=(/,/^)/p' install/modules/deps.sh)"
{
    for p in "${REQUIRED_PKGS[@]}" "${KEYBIND_PKGS[@]}" sddm gentoolkit xorg-server; do
        p="${p%%|*}"
        a="$(portage_atoms "$p")"
        case "$a" in "" | src:* | unknown:*) continue ;; esac
        printf '%s\n' $a
    done
    # and gentoo-install's packages that Gentoo doesn't prebuild (it sets up the systems this is for)
    grep -v '^#' "monolith/binhost/extra-atoms.txt"
} | sort -u
