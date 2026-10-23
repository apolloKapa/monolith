#!/usr/bin/env bash
# Monolith installer. Run it from a clone of the repo, through install/get.sh, or with
# `monolith installer` once Monolith is installed.

setterm -blank 0 -powerdown 0 2>/dev/null || true

# Finish even if the terminal goes away: an update stops the shell, and older versions opened
# the update terminal inside the shell's process group, so stopping the shell closed the
# terminal mid-update (leaving no shell and dead keybinds).
trap '' HUP

# --update: no menu, just bring an existing install up to date (used by Settings -> About -> Update).
# Keeps your niri config, login screen, wallpapers and settings; installs new dependencies.
UPDATE_ONLY=false
for arg in "$@"; do
    [ "$arg" = "--update" ] && UPDATE_ONLY=true
done

INSTALL_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
[ -f "$INSTALL_DIR/source.env" ] && source "$INSTALL_DIR/source.env"
REPO_SLUG="$(printf '%s' "${REPO_SLUG:-apolloKapa/monolith}" | tr -cd 'a-zA-Z0-9_./-')"
# older installs remember the repo under its earlier names
case "$REPO_SLUG" in kasc0b3r/monolith|kasc0b3r/dotfiles) REPO_SLUG="apolloKapa/monolith" ;; esac
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
    # run the installer that came with the download, so an update uses the new installer's
    # steps (and questions), not the copy installed with the old version
    if [ -z "${MONOLITH_INSTALLER_REEXEC:-}" ] && [ -f "$CACHE_REPO/install/install.sh" ]; then
        export MONOLITH_INSTALLER_REEXEC=1
        exec bash "$CACHE_REPO/install/install.sh" "$@"
    fi
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
source "$MODULES_DIR/migrate.sh"
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


if [ "$UPDATE_ONLY" = true ]; then
    NIRI_MODE=keep
    OPT_SDDM=false
    WALLPAPERS=none
    IS_REINSTALL=false
    printf "\n%sUpdating Monolith%s %s -> %s (%s)\n" "$BOLD" "$RESET" "${OLD_VERSION:-?}" "$TARGET_VERSION" "$TARGET_COMMIT"
else
    run_installer_ui
fi

# --- install ------------------------------------------------------------------------------------
step "Packages"
install_dependencies "$PROJECT_ROOT" "$INSTALL_STATE"

if old_shell_installed; then
    step "Replacing Serpantinum"
    migrate_from_old_shell
fi

step "Monolith shell"
SHELL_WAS_RUNNING=false
monolithd status >/dev/null 2>&1 && SHELL_WAS_RUNNING=true
monolithd stop >/dev/null 2>&1 || true
deploy_shell "$PROJECT_ROOT"
install_desktop_entry "$PROJECT_ROOT"
deploy_dotfiles_extras "$PROJECT_ROOT"
setup_pam_service

step "niri"
setup_niri_config "$PROJECT_ROOT" "$NIRI_MODE"
[ "$UPDATE_ONLY" != true ] && [ "$NIRI_MODE" = replace ] && prefer_niri_session
# screenshot binds -> Monolith's screenshot tool, and let its keys (e.g. Meta+C copy) through niri
upgrade_screenshot_binds "$NIRI_DIR/config/keybinds.kdl" >/dev/null
bash "$SHELL_HOME/src/scripts/niri_screenshot_keys.sh" >/dev/null 2>&1 || true

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

# switch over right away when we're inside a desktop session (no reboot needed). niri only runs
# spawn-at-startup at login, so a fresh install has to start the shell itself.
if [ -n "$WAYLAND_DISPLAY" ] && { [ "$UPDATE_ONLY" != true ] || [ "$SHELL_WAS_RUNNING" = true ]; }; then
    setsid "$BIN_DIR/monolithd" start >/dev/null 2>&1 < /dev/null &
    MONOLITH_STARTED=true
fi

if [ "$UPDATE_ONLY" = true ]; then
    printf "\n%s%sMonolith is up to date (%s).%s\n" "$BOLD" "$C_GREEN" "$TARGET_VERSION" "$RESET"
    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        printf "%sThese packages failed to install: %s%s\n" "$C_RED" "${FAILED_PKGS[*]}" "$RESET"
    fi
    printf "A restart makes sure everything (keybinds, login screen, services) uses the new version.\n"
    answer=""
    if { : < /dev/tty; } 2>/dev/null; then
        printf "\n%s%sRestart your computer now?%s\n" "$BOLD" "$C_CYAN" "$RESET"
        read -r -p "  [y] restart now   [n] later: " answer < /dev/tty || true
    elif command -v notify-send >/dev/null 2>&1; then
        # no terminal to ask in: ask with a notification instead
        answer=$(notify-send -a "Monolith" -u critical -A "y=Restart now" -A "n=Later" --wait \
            "Monolith updated to $TARGET_VERSION" "Restart now so everything uses the new version?" 2>/dev/null)
    fi
    if [[ "$answer" =~ ^[Yy] ]]; then
        systemctl reboot
    else
        printf "OK, the new version is active; restart whenever you like.\n"
        command -v notify-send >/dev/null 2>&1 && notify-send -a "Monolith" "Monolith updated to $TARGET_VERSION" "Restart later so keybinds, login screen and services pick it up." 2>/dev/null || true
    fi
else
    draw_completion_screen
fi
