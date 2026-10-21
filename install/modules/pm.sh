#!/usr/bin/env bash
# Package manager backend. Monolith targets Arch and Arch-based distros (pacman + yay/paru).

PM_MODULES_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/pm"
PM_NAME="pacman"

PM_EXTRA_PKGS=()
PM_SDDM_EXTRA_PKGS=()
PM_SDDM_WAYLAND_DEFAULT=false
PM_SDDM_CURSOR_FIX=false

source "$PM_MODULES_DIR/$PM_NAME.sh"
