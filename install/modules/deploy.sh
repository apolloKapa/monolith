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

# the shell: ~/.local/share/monolith/{bin,shell,install}, `monolith` linked into ~/.local/bin.
# Whatever was there (the classic shell on an older install) is replaced.
deploy_shell() {
    local project_root="$1"
    rm -rf "$SHELL_HOME"
    mkdir -p "$SHELL_HOME" "$BIN_DIR"
    cp -r "$project_root/monolith/bin" "$project_root/monolith/shell" "$project_root/monolith/LICENSE" "$project_root/monolith/version.txt" "$SHELL_HOME/"
    # a copy of the installer, so `monolith installer` works without the repo around
    cp -r "$project_root/install" "$SHELL_HOME/install"
    printf 'REPO_SLUG="%s"\nMONOLITH_BRANCH="%s"\n' "$REPO_SLUG" "$MONOLITH_BRANCH" > "$SHELL_HOME/install/source.env"
    chmod +x "$SHELL_HOME"/bin/* "$SHELL_HOME"/install/*.sh "$SHELL_HOME"/shell/scripts/*
    ln -sf "$SHELL_HOME/bin/monolith" "$BIN_DIR/monolith"
    # the classic shell's daemon and the new shell's trial copy are gone
    rm -f "$BIN_DIR/monolithd" "$BIN_DIR/monolith-next"
    rm -rf "$HOME/.local/share/monolith-next"
    echo -e "  ${C_GREEN}shell:${RESET} installed to $SHELL_HOME"
}

# icon packs that come with Monolith (config/icons/<pack>) go to ~/.local/share/icons, where
# Settings → Theme → Icons finds them. A pack Monolith put there (it carries .monolith-icon-pack)
# is refreshed on every install/update; a folder of the same name you put there yourself is kept.
install_icon_packs() {
    local project_root="$1" pack name dest
    local icons_home="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
    [ -d "$project_root/config/icons" ] || return 0
    mkdir -p "$icons_home"
    for pack in "$project_root"/config/icons/*/; do
        [ -f "$pack/index.theme" ] || continue
        name="$(basename "$pack")"
        dest="$icons_home/$name"
        if [ -e "$dest" ] && [ ! -f "$dest/.monolith-icon-pack" ]; then
            echo -e "  ${C_GREEN}icons:${RESET} $name is already in $icons_home (yours, kept)"
            continue
        fi
        rm -rf "$dest"
        cp -a "$pack" "$dest"
        touch "$dest/.monolith-icon-pack"
        command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -qf "$dest" 2>/dev/null || true
        echo -e "  ${C_GREEN}icons:${RESET} $name installed to $icons_home"
    done
}

# extras next to the shell: the bundled icon packs, ~/.local/bin on the PATH, kitty's fastfetch
deploy_dotfiles_extras() {
    local project_root="$1"
    mkdir -p "$BIN_DIR" "$HOME/.config"
    install_icon_packs "$project_root"
    ensure_bin_on_path
    setup_kitty_config "$project_root"
    setup_kitty_fastfetch
}

# kitty: Monolith's matugen writes ~/.config/kitty/colors.conf, but kitty only reads kitty.conf.
# No kitty.conf: install Monolith's (font, size, colours). One of your own: kept, and only the
# include line for the colours is added when it's missing.
setup_kitty_config() {
    local project_root="$1"
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
    local conf="$dir/kitty.conf" src="$project_root/config/kitty/kitty.conf"
    mkdir -p "$dir"
    if [ ! -e "$conf" ]; then
        [ -f "$src" ] || return 0
        cp "$src" "$conf"
        echo -e "  ${C_GREEN}kitty:${RESET} config installed ($conf)"
    elif ! grep -qsE '^[[:space:]]*include[[:space:]]+(~/\.config/kitty/|\./)?colors\.conf' "$conf"; then
        printf '\n# Added by the Monolith installer: colours from your wallpaper\ninclude colors.conf\n' >> "$conf"
        echo -e "  ${C_GREEN}kitty:${RESET} Monolith's colours added to $conf"
    fi
}

# kitty greets you with Monolith's fastfetch: your login shell runs it when it starts inside kitty.
# fish gets its own conf.d file; bash and zsh a marked block at the end of their rc. Done once:
# if you take it out again, updates leave it out. Skipped when your shell already runs fastfetch.
setup_kitty_fastfetch() {
    local flag="$STATE_DIR/kitty_fastfetch.done"
    [ -e "$flag" ] && return 0
    command -v fastfetch &>/dev/null || return 0
    local login_shell rc
    login_shell="$(basename "$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)")"
    [ -n "$login_shell" ] || login_shell="$(basename "${SHELL:-bash}")"
    case "$login_shell" in
        fish)
            local fish_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
            if ! grep -qs 'fastfetch' "$fish_dir/config.fish" "$fish_dir"/conf.d/*.fish; then
                mkdir -p "$fish_dir/conf.d"
                printf '%s\n' "# Added by the Monolith installer: fastfetch when kitty opens (delete this file to stop it)" \
                    "if status is-interactive; and set -q KITTY_WINDOW_ID" "    fastfetch" "end" \
                    > "$fish_dir/conf.d/monolith-fastfetch.fish"
                echo -e "  ${C_GREEN}kitty:${RESET} fastfetch shows when kitty opens ($fish_dir/conf.d/monolith-fastfetch.fish)"
            fi
            ;;
        bash|zsh)
            rc="$HOME/.${login_shell}rc"
            if ! grep -qs 'fastfetch' "$rc"; then
                printf '\n%s\n' "# >>> monolith fastfetch (added by the Monolith installer: fastfetch when kitty opens) >>>
if [[ \$- == *i* && -n \"\$KITTY_WINDOW_ID\" ]]; then
    fastfetch
fi
# <<< monolith fastfetch <<<" >> "$rc"
                echo -e "  ${C_GREEN}kitty:${RESET} fastfetch shows when kitty opens (end of $rc)"
            fi
            ;;
        *) return 0 ;;
    esac
    mkdir -p "$STATE_DIR" && touch "$flag"
}

# niri (via niri-session) gets its PATH from the systemd user manager, which on a fresh PC has
# no ~/.local/bin: `spawn-at-startup "monolith"` found nothing and the shell never started
# (the plain grey niri screen), and every `spawn "monolith" ...` keybind did nothing.
# environment.d puts it on the PATH of everything the session starts, from the next login.
ensure_bin_on_path() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/60-monolith-path.conf"
    if [ ! -f "$conf" ]; then
        mkdir -p "$(dirname "$conf")"
        printf '# Added by the Monolith installer: its command (monolith) lives here\nPATH=$HOME/.local/bin:${PATH}\n' > "$conf"
        echo -e "  ${C_CYAN}path:${RESET} $BIN_DIR added to the session PATH ($conf)"
    fi
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
            # no location: each person sets their own in Settings -> General
            del(.general.location)
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

# "Monolith Settings" in the app launcher: opens Settings in the hub
install_desktop_entry() {
    local apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$apps_dir"
    rm -f "$apps_dir/monolith-appimages.desktop"
    printf '%s\n' "[Desktop Entry]" "Type=Application" "Name=Monolith Settings" \
        "Comment=Appearance, displays, keyboard and mouse, startup apps and more" \
        "Exec=\"$BIN_DIR/monolith\" settings" "Icon=preferences-system" "Categories=Settings;" \
        > "$apps_dir/monolith-settings.desktop"
    command -v update-desktop-database >/dev/null && update-desktop-database "$apps_dir" >/dev/null 2>&1
    return 0
}
