#!/usr/bin/env bash
# Package manager backend: Arch and Arch-based distros (pacman + yay/paru), or Gentoo and
# Gentoo-based distros (Portage, everything built from source; see pm/portage.sh).

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"
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
