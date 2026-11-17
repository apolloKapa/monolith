#!/usr/bin/env bash

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig base-devel)

# Nothing Monolith installs needs an extra repository, so pacman.conf is left alone (it used to
# switch multilib on for Steam, which isn't part of the install any more).
pm_prepare_repos() {
    return 0
}

# The package lists are refreshed and the system brought up to date once per run, before anything
# is installed: installing from stale lists asked the mirrors for versions they no longer had
# ("failed retrieving file ... error: 404", seen on CachyOS's mirrors), and refreshing the lists
# without upgrading (-Sy then -S) is the partial upgrade Arch warns can break the system.
PM_SYNCED=false
pm_sync() {
    [ "$PM_SYNCED" = true ] && return 0
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    sudo pacman -Syu --noconfirm && PM_SYNCED=true
}

# a repo package; a download failing (a mirror behind or ahead of the lists) gets the lists
# fetched again from scratch and one more try, upgrading in the same step
pm_pacman_install() {
    pm_sync || true
    sudo pacman -S --noconfirm --needed "$@" && return 0
    echo -e "\e[33m[ WARN ]\e[0m pacman couldn't get everything: fetching the package lists again and retrying"
    sudo pacman -Syyu --noconfirm --needed "$@"
}

pm_bootstrap_install() {
    sudo pacman -Syu --noconfirm --needed "$@" && PM_SYNCED=true && return 0
    sudo pacman -Syyu --noconfirm --needed "$@" && PM_SYNCED=true
}

pm_bootstrap_helper() {
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        local cache_build="${XDG_CACHE_HOME:-"$HOME/.cache"}/monolith-yay-bin"
        rm -rf "$cache_build"
        mkdir -p "$cache_build"
        git clone https://aur.archlinux.org/yay-bin.git "$cache_build"
        (cd "$cache_build" && makepkg -si --noconfirm)
        rm -rf "$cache_build"
    fi
}

pm_full_upgrade() {
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    sudo pacman -Syyu --noconfirm && PM_SYNCED=true
}

pm_missing_pkgs() {
    pacman -T "$@" 2>/dev/null || true
}

# is the package in the repos (not the AUR)?
pm_has_pkg() {
    pacman -Si "$1" &>/dev/null
}

pm_is_installed() {
    pacman -Q "$1" &>/dev/null
}

pm_install_pkg() {
    local pkg="$1"
    local safe_jobs="$2"

    # (the lists up to date first: an AUR package's dependencies come from the repos too)
    pm_sync || true
    if pacman -Si "$pkg" &>/dev/null; then
        pm_pacman_install "$pkg"
    elif command -v yay &>/dev/null; then
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" yay -S --noconfirm --needed "$pkg"
    elif command -v paru &>/dev/null; then
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" paru -S --noconfirm --needed "$pkg"
    else
        pm_pacman_install "$pkg"
    fi
}

pm_upgrade_quickshell() {
    if sudo pacman -Syu --noconfirm --needed --ask=4 quickshell && PM_SYNCED=true && quickshell_is_current; then
        return 0
    fi

    local helper
    for helper in yay paru; do
        command -v "$helper" &>/dev/null || continue
        "$helper" -S --noconfirm --needed --ask=4 quickshell-git && quickshell_is_current && return 0
        break
    done
    return 0
}

pm_remove_pkg() {
    sudo pacman -Rns --noconfirm "$1" >/dev/null 2>&1 || true
}

pm_remove_conflicting_pkg() {
    local pkg="$1"
    if pm_is_installed "$pkg"; then
        yay -R --noconfirm "$pkg" 2>/dev/null || sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
    fi
}
