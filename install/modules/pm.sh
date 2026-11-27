#!/usr/bin/env bash
# Package manager backend: Arch and Arch-based distros (pacman + yay/paru), or Gentoo and
# Gentoo-based distros (Portage, everything built from source; see pm/portage.sh).

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"
# which distro: /etc/os-release, else /usr/lib/os-release (where the standard says to look next;
# Artix's filesystem package ships only that one)
OS_RELEASE=/etc/os-release
[ -f "$OS_RELEASE" ] || OS_RELEASE=/usr/lib/os-release
if command -v pacman &>/dev/null; then
    PM_NAME="pacman"
elif command -v emerge &>/dev/null; then
    PM_NAME="portage"
else
    PM_NAME="pacman"
fi

PM_EXTRA_PKGS=()
PM_SDDM_EXTRA_PKGS=()
PM_SDDM_WAYLAND_DEFAULT=false

source "$PM_MODULES_DIR/$PM_NAME.sh"
