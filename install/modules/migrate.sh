#!/usr/bin/env bash
# Replacing an existing Serpantinum install: back it up, point every compositor config at
# Monolith, remove its system-wide pieces. Nothing is deleted outright: user files are moved into
# ~/serpantinum-backup-<date>/ so they can be restored.

OLD_SHELL="serpantinum"

# config files that could still launch (or call) the old shell. Only places that start
# programs are searched: compositor configs, XDG autostart, systemd user units, session/env
# files and shell login scripts. Our own backups are skipped.
old_shell_launchers() {
    local c="$HOME/.config" places=()
    local d
    for d in hypr sway mango river labwc wayfire niri autostart systemd/user uwsm environment.d fish; do
        [ -e "$c/$d" ] && places+=("$c/$d")
    done
    for d in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.xprofile"; do
        [ -f "$d" ] && places+=("$d")
    done
    [ ${#places[@]} -gt 0 ] || return 0
    grep -rIlZ --exclude-dir="*_backup" --exclude-dir="*.bak" --exclude-dir="niri.$OLD_SHELL" \
        -e "${OLD_SHELL}d" -e "$OLD_SHELL msg" -e "share/$OLD_SHELL" "${places[@]}" 2>/dev/null
}

old_shell_installed() {
    [ -d "$HOME/.local/share/$OLD_SHELL" ] || [ -d "$HOME/.config/$OLD_SHELL" ] \
        || command -v "${OLD_SHELL}d" &>/dev/null || [ -e "/usr/local/bin/${OLD_SHELL}d" ] \
        || pacman -Qq "$OLD_SHELL" "$OLD_SHELL-git" &>/dev/null \
        || [ -n "$(old_shell_launchers | tr -d '\0')" ]
}

migrate_from_old_shell() {
    old_shell_installed || return 0
    local backup="$HOME/${OLD_SHELL}-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup"
    echo -e "  ${C_CYAN}old shell:${RESET} found Serpantinum, replacing it (backup: $backup)"

    # 1) stop it
    "${OLD_SHELL}d" stop &>/dev/null || true
    pkill -f "$HOME/.local/share/$OLD_SHELL/" &>/dev/null || true

    # 2) every config that launches or calls it (compositor configs, autostart entries, systemd
    #    user units, session scripts, ...): back up the file, then point it at Monolith
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#$HOME/}"
        mkdir -p "$backup/home/$(dirname "$rel")"
        cp -a "$f" "$backup/home/$rel"
        sed -i "s/${OLD_SHELL}d/monolithd/g; s/${OLD_SHELL}/monolith/g; s/Serpantinum/Monolith/g" "$f"
        echo -e "  ${C_CYAN}old shell:${RESET} ~/$rel now uses Monolith (original in the backup)"
    done < <(old_shell_launchers)
    systemctl --user daemon-reload &>/dev/null || true

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

    # 4) system-wide pieces (sudo), including the pacman/AUR package if it came that way
    local pkg
    for pkg in "$OLD_SHELL" "$OLD_SHELL-git"; do
        if pacman -Qq "$pkg" &>/dev/null; then
            sudo pacman -Rns --noconfirm "$pkg" && echo -e "  ${C_CYAN}old shell:${RESET} removed the $pkg package"
        fi
    done
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
