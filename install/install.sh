#!/usr/bin/env bash
# Monolith installer. Run it from a clone of the repo, through install/get.sh, or with
# `monolith installer` once Monolith is installed. Inspired by Serpantinum's installer.

setterm -blank 0 -powerdown 0 2>/dev/null || true

INSTALL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
[ -f "$INSTALL_DIR/source.env" ] && source "$INSTALL_DIR/source.env"
REPO_SLUG="$(printf '%s' "${REPO_SLUG:-kasc0b3r/dotfiles}" | tr -cd 'a-zA-Z0-9_./-')"
MONOLITH_BRANCH="$(printf '%s' "${MONOLITH_BRANCH:-main}" | tr -cd 'a-zA-Z0-9_./-')"
CACHE_REPO="${XDG_CACHE_HOME:-$HOME/.cache}/monolith-installer"
export REPO_SLUG MONOLITH_BRANCH

die() { printf '\e[31m[ ERROR ]\e[0m %s\n' "$1" >&2; exit 1; }

[ "$EUID" -eq 0 ] && die "Run the installer as your normal user, not root (it asks for sudo when needed)."
command -v pacman &>/dev/null || die "Monolith's installer supports Arch Linux and Arch-based distros (pacman) only."

# --- find the repo: the one this script is in, or a cached clone of GitHub -------------------
PROJECT_ROOT="$(dirname "$INSTALL_DIR")"
# git that never stops to ask for a password; uses the GitHub CLI login when there is one
# (needed while the repo is private)
gitx() {
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
    else
        GIT_TERMINAL_PROMPT=0 git "$@"
    fi
}

if [ ! -d "$PROJECT_ROOT/monolith/src" ]; then
    command -v git &>/dev/null || sudo pacman -Sy --noconfirm --needed git
    if [ -d "$CACHE_REPO/.git" ]; then
        echo "Updating $REPO_SLUG ($MONOLITH_BRANCH)..."
        gitx -C "$CACHE_REPO" fetch --depth 1 origin "$MONOLITH_BRANCH" 2>/dev/null \
            && git -C "$CACHE_REPO" reset --hard FETCH_HEAD >/dev/null \
            || echo "Couldn't update, using the copy from last time."
    else
        echo "Downloading $REPO_SLUG ($MONOLITH_BRANCH)..."
        rm -rf "$CACHE_REPO"
        gitx clone --depth 1 -b "$MONOLITH_BRANCH" "https://github.com/$REPO_SLUG.git" "$CACHE_REPO" 2>/dev/null \
            || die "Couldn't download $REPO_SLUG. If the repo is private, run 'gh auth login' first."
    fi
    PROJECT_ROOT="$CACHE_REPO"
    INSTALL_DIR="$CACHE_REPO/install"
fi
MODULES_DIR="$INSTALL_DIR/modules"

# --- modules ------------------------------------------------------------------------------------
source "$MODULES_DIR/pm.sh"
source "$MODULES_DIR/deps.sh"
source "$MODULES_DIR/service.sh"
source "$MODULES_DIR/deploy.sh"
source "$MODULES_DIR/niri.sh"
source "$MODULES_DIR/pam.sh"
source "$MODULES_DIR/sddm.sh"
source "$MODULES_DIR/wallpapers.sh"
source "$MODULES_DIR/ui.sh"

# read the install state before i18n.sh: sourcing it creates Monolith's state dir + version stamp
INSTALL_STATE="$(detect_install_state)"
OLD_VERSION="$(installed_version)"
TARGET_VERSION="$(repo_version "$PROJECT_ROOT")"
TARGET_COMMIT="$(repo_commit "$PROJECT_ROOT")"

bootstrap_installer_deps
export MONOLITH_DIR="$PROJECT_ROOT/monolith/src"
export I18N_DIR="$MONOLITH_DIR/assets/languages"
source "$MONOLITH_DIR/scripts/i18n.sh"


run_installer_ui

# --- install ------------------------------------------------------------------------------------
step "Packages"
install_dependencies "$PROJECT_ROOT" "$INSTALL_STATE"

step "Monolith shell"
SHELL_WAS_RUNNING=false
monolithd status >/dev/null 2>&1 && SHELL_WAS_RUNNING=true
monolithd stop >/dev/null 2>&1 || true
deploy_shell "$PROJECT_ROOT"
deploy_dotfiles_extras "$PROJECT_ROOT"
setup_pam_service

step "niri"
setup_niri_config "$PROJECT_ROOT" "$NIRI_MODE"

if [ "$OPT_SDDM" = true ]; then
    step "Login screen"
    setup_sddm "$PROJECT_ROOT" "$INSTALL_STATE" "$IS_REINSTALL"
fi

if [ "$WALLPAPERS" != none ]; then
    step "Wallpapers"
    install_wallpapers "$([ "$WALLPAPERS" = full ] && echo true || echo false)"
fi

step "Settings"
[ "$IS_REINSTALL" = true ] && rm -f "$SETTINGS_FILE"
init_settings "$PROJECT_ROOT" "$(get_wallpaper_dir)"

step "Services"
setup_services
write_version_state "$PROJECT_ROOT"
# fresh installs get the intro
[[ "$INSTALL_STATE" == fresh || "$IS_REINSTALL" == true ]] && rm -f "$STATE_DIR/first_launch.done"

if [ "$SHELL_WAS_RUNNING" = true ] && [ -n "$WAYLAND_DISPLAY" ]; then
    setsid monolithd start >/dev/null 2>&1 < /dev/null &
fi

draw_completion_screen
