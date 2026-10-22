#!/usr/bin/env bash
# Copies the shell, the dotfiles extras and the settings into place.

SHELL_HOME="$HOME/.local/share/monolith"
STATE_DIR="$HOME/.local/state/monolith"
VERSION_FILE="$STATE_DIR/version"
SETTINGS_FILE="$HOME/.config/monolith/settings.json"
BIN_DIR="$HOME/.local/bin"

detect_install_state() {
    [ -f "$VERSION_FILE" ] && echo "current" || echo "fresh"
}

installed_version() {
    awk -F= '/^MONOLITH_VERSION=/{gsub(/"/, "", $2); print $2}' "$VERSION_FILE" 2>/dev/null
}

repo_version() {
    cat "$1/monolith/version.txt" 2>/dev/null | xargs
}

repo_commit() {
    git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "local"
}

# the shell: ~/.local/share/monolith/{bin,src,install}, commands linked into ~/.local/bin
deploy_shell() {
    local project_root="$1"
    rm -rf "$SHELL_HOME"
    mkdir -p "$SHELL_HOME" "$BIN_DIR"
    cp -r "$project_root/monolith/bin" "$project_root/monolith/src" "$project_root/monolith/version.txt" "$SHELL_HOME/"
    # a copy of the installer, so `monolith installer` works without the repo around
    cp -r "$project_root/install" "$SHELL_HOME/install"
    printf 'REPO_SLUG="%s"\nMONOLITH_BRANCH="%s"\n' "$REPO_SLUG" "$MONOLITH_BRANCH" > "$SHELL_HOME/install/source.env"
    chmod +x "$SHELL_HOME"/bin/* "$SHELL_HOME"/install/*.sh
    find "$SHELL_HOME/src/scripts" -type f -name "*.sh" -exec chmod +x {} +
    ln -sf "$SHELL_HOME/bin/monolith" "$BIN_DIR/monolith"
    ln -sf "$SHELL_HOME/bin/monolithd" "$BIN_DIR/monolithd"
    echo -e "  ${C_GREEN}shell:${RESET} installed to $SHELL_HOME"
}

# helper scripts the keybinds use (focuswin, snap, swapwin, setwall, ...) and the rofi config
deploy_dotfiles_extras() {
    local project_root="$1"
    mkdir -p "$BIN_DIR" "$HOME/.config"
    cp -a "$project_root/bin/." "$BIN_DIR/"
    if [ -d "$project_root/config/rofi" ]; then
        mkdir -p "$HOME/.config/rofi"
        cp "$project_root/config/rofi/config.rasi" "$HOME/.config/rofi/"
        # your favourites are yours: only a starting list when you have none
        [ -f "$HOME/.config/rofi/favorites" ] || cp "$project_root/config/rofi/favorites" "$HOME/.config/rofi/"
    fi
    [ -f "$HOME/.config/wallpaper" ] || cp "$project_root/config/wallpaper" "$HOME/.config/wallpaper" 2>/dev/null || true
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo -e "  ${C_YELLOW}path:${RESET} add $BIN_DIR to your PATH (fish: fish_add_path ~/.local/bin)" ;;
    esac
    echo -e "  ${C_GREEN}scripts:${RESET} helper scripts copied to $BIN_DIR"
}

# settings.json: kept if you have one, otherwise the repo's defaults with this machine's paths
init_settings() {
    local project_root="$1"
    local wallpaper_dir="$2"
    # an existing file is kept, unless it's just the empty `{}` the shell's scripts create on first use
    if [ -s "$SETTINGS_FILE" ] && jq -e 'length > 0' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "  ${C_CYAN}settings:${RESET} keeping $SETTINGS_FILE"
        return 0
    fi
    mkdir -p "$(dirname "$SETTINGS_FILE")"

    local src="$project_root/config/monolith/settings.json" from="defaults"

    # the defaults carry my /home/<user>/ paths: point them at this home first, then set this
    # machine's wallpaper folder and avatar (so those don't get rewritten twice)
    sed -e "s|/home/[^/\"]*/|$HOME/|g" "$src" \
        | jq --arg user "$USER" --arg wp "$wallpaper_dir" '
            # nothing that identifies you by network: IP, ISP, postcode
            (if .general.location then .general.location |= (del(.ip, .asn, .org, .postal, .currency, .languages, .utc_offset)
                | .latitude |= ((. * 100 | round) / 100) | .longitude |= ((. * 100 | round) / 100) | .source = "manual") else . end)
            | .wallpaperDir = $wp
            | (if .general.avatarPath then .general.avatarPath = "/var/lib/AccountsService/icons/\($user)" else . end)
        ' > "$SETTINGS_FILE"
    echo -e "  ${C_GREEN}settings:${RESET} created from $from"
}

write_version_state() {
    local project_root="$1"
    mkdir -p "$STATE_DIR"
    cat > "$VERSION_FILE" <<EOF
MONOLITH_VERSION="$(repo_version "$project_root")"
MONOLITH_COMMIT="$(repo_commit "$project_root")"
SELECTED_COMPOSITORS="niri"
EOF
}

# "Monolith Settings" in the app launcher: opens the settings window on its own
install_desktop_entry() {
    local project_root="$1"
    local src_dir="$project_root/monolith/packaging/desktop"
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local apps_dir="$data_home/applications"
    local icons_dir="$data_home/icons/hicolor/scalable/apps"
    [ -f "$src_dir/monolith-settings.desktop" ] || return 0
    mkdir -p "$apps_dir" "$icons_dir"
    sed "s|^Exec=.*|Exec=\"$BIN_DIR/monolith\" settings|" "$src_dir/monolith-settings.desktop" > "$apps_dir/monolith-settings.desktop"
    [ -f "$src_dir/monolith-settings.svg" ] && cp "$src_dir/monolith-settings.svg" "$icons_dir/monolith-settings.svg"
    command -v update-desktop-database >/dev/null && update-desktop-database "$apps_dir" >/dev/null 2>&1
    return 0
}
