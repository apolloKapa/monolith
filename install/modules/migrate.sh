#!/usr/bin/env bash
# Replacing an existing Serpantinum install: back it up, point every compositor config at
# Monolith, remove its system-wide pieces. Nothing is deleted outright: user files are moved into
# ~/serpantinum-backup-<date>/ so they can be restored.

OLD_SHELL="serpantinum"

old_shell_installed() {
    [ -d "$HOME/.local/share/$OLD_SHELL" ] || [ -d "$HOME/.config/$OLD_SHELL" ] \
        || command -v "${OLD_SHELL}d" &>/dev/null || [ -e "/usr/local/bin/${OLD_SHELL}d" ]
}

migrate_from_old_shell() {
    old_shell_installed || return 0
    local backup="$HOME/${OLD_SHELL}-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup"
    echo -e "  ${C_CYAN}old shell:${RESET} found Serpantinum, replacing it (backup: $backup)"

    # 1) stop it
    "${OLD_SHELL}d" stop &>/dev/null || true
    pkill -f "$HOME/.local/share/$OLD_SHELL/" &>/dev/null || true

    # 2) other compositors: back up their config, then start/call Monolith instead
    local dir
    for dir in hypr sway mango river labwc; do
        local cfg="$HOME/.config/$dir"
        [ -d "$cfg" ] && grep -rqs "$OLD_SHELL" "$cfg" || continue
        mkdir -p "$backup/config"
        cp -a "$cfg" "$backup/config/$dir"
        grep -rlZ "$OLD_SHELL" "$cfg" | xargs -0 -r sed -i "s/${OLD_SHELL}d/monolithd/g; s/${OLD_SHELL}/monolith/g; s/Serpantinum/Monolith/g"
        echo -e "  ${C_CYAN}old shell:${RESET} ~/.config/$dir now starts Monolith (original in the backup)"
    done

    # 3) its own files
    mkdir -p "$backup/share" "$backup/config" "$backup/state" "$backup/cache" "$backup/bin"
    [ -d "$HOME/.local/share/$OLD_SHELL" ] && mv "$HOME/.local/share/$OLD_SHELL" "$backup/share/"
    [ -d "$HOME/.config/$OLD_SHELL" ] && mv "$HOME/.config/$OLD_SHELL" "$backup/config/"
    [ -d "$HOME/.local/state/$OLD_SHELL" ] && mv "$HOME/.local/state/$OLD_SHELL" "$backup/state/"
    local c
    for c in "$HOME/.cache/$OLD_SHELL" "$HOME/.cache/$OLD_SHELL-installer" "$HOME/.cache/$OLD_SHELL-wallpapers"; do
        [ -e "$c" ] && mv "$c" "$backup/cache/"
    done
    for c in "$HOME/.local/bin/$OLD_SHELL" "$HOME/.local/bin/${OLD_SHELL}d"; do
        [ -e "$c" ] || [ -L "$c" ] && mv "$c" "$backup/bin/"
    done
    rm -rf "${XDG_RUNTIME_DIR:-/tmp}/$OLD_SHELL" 2>/dev/null || true

    # 4) system-wide pieces (sudo)
    sudo rm -f "/usr/local/bin/$OLD_SHELL" "/usr/local/bin/${OLD_SHELL}d" "/etc/pam.d/$OLD_SHELL"
    if [ -f /etc/sddm.conf.d/10-material-you.conf ] || [ -d /usr/share/sddm/themes/material-you ]; then
        sudo rm -f /etc/sddm.conf.d/10-material-you.conf
        sudo rm -rf /usr/share/sddm/themes/material-you /usr/share/sddm/themes/material-you.bak
        echo -e "  ${C_CYAN}old shell:${RESET} removed its login screen theme"
    fi
    echo -e "  ${C_GREEN}old shell:${RESET} Serpantinum removed"
}

# The next login should be niri with Monolith's config, not whatever session SDDM remembers
# (Serpantinum's installer defaults to Hyprland).
prefer_niri_session() {
    local state=/var/lib/sddm/state.conf session=/usr/share/wayland-sessions/niri.desktop
    [ -f "$session" ] && sudo test -f "$state" || return 0
    # state.conf is root-only, so read it through sudo as well
    local current
    current="$(sudo cat "$state" 2>/dev/null)" || return 0
    grep -q "^Session=$session$" <<< "$current" && return 0
    if grep -q "^Session=" <<< "$current"; then
        sudo sed -i "s|^Session=.*|Session=$session|" "$state"
    elif grep -q "^\[Last\]" <<< "$current"; then
        sudo sed -i "/^\[Last\]/a Session=$session" "$state"
    else
        printf '\n[Last]\nSession=%s\n' "$session" | sudo tee -a "$state" >/dev/null
    fi
    echo -e "  ${C_GREEN}login:${RESET} niri is now the default session"
}
