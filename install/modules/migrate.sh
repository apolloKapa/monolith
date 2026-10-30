#!/usr/bin/env bash
# Other shells on the same PC. Monolith is its own shell with its own files (~/.local/share/monolith,
# ~/.config/monolith, ~/.local/state/monolith, monolith/monolithd): it never stops, moves or edits
# another shell, its files, or the configs of other compositors. When Serpantinum is installed it
# keeps running in its own sessions (e.g. Hyprland) and Monolith runs in niri next to it.

OTHER_SHELL="serpantinum"

other_shell_installed() {
    [ -d "$HOME/.local/share/$OTHER_SHELL" ] || [ -d "$HOME/.config/$OTHER_SHELL" ] \
        || command -v "${OTHER_SHELL}d" &>/dev/null || [ -e "/usr/local/bin/${OTHER_SHELL}d" ] \
        || pacman -Qq "$OTHER_SHELL" "$OTHER_SHELL-git" &>/dev/null
}

# Serpantinum themes kitty and cava too (fastfetch is always Monolith's): on a new Monolith settings file, leave those to
# it (Settings -> Theme -> Apps can switch them back on)
share_with_other_shell() {
    other_shell_installed || return 0
    local f="$HOME/.config/monolith/settings.json"
    echo -e "  ${C_CYAN}other shell:${RESET} Serpantinum is installed; it's left as it is"
    [ -f "$f" ] || return 0
    jq -e '.theme.terminalColors != null' "$f" &>/dev/null && return 0
    local tmp
    tmp="$(mktemp)" && jq '.theme = ((.theme // {}) + {terminalColors: false})' "$f" > "$tmp" && mv "$tmp" "$f"
    echo -e "  ${C_CYAN}other shell:${RESET} kitty and cava keep Serpantinum's colours"
}
