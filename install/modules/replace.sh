#!/usr/bin/env bash
# Other shells: Monolith takes their place when asked (the installer's "Other shells" option, on
# whenever one is found; turn it off to keep one installed next to Monolith, as migrate.sh did
# before). For each shell found:
#   - it's stopped, and its packages are uninstalled with a plain `pacman -R` (never `-Rns`: what
#     it pulled in stays, Quickshell among it, which Monolith runs on). On Gentoo it's deselected.
#   - its own folders (its config, state, cache) are moved into a backup, not deleted:
#     ~/.local/share/monolith/replaced/<shell>-<date>/
#   - its autostart entries and systemd user services are taken away (into the same backup)
#   - its keys become Monolith's: merge_keys.py, run on the niri / Hyprland config afterwards
# Quickshell itself is never touched.

# name | packages (pacman; "illogical-impulse-*": every package with that start) | folders in $HOME | its command
SHELL_TABLE=(
    "Noctalia|noctalia-shell noctalia-shell-git noctalia-qs|.config/quickshell/noctalia-shell .config/quickshell/noctalia .config/noctalia .local/share/noctalia .local/state/noctalia .cache/noctalia|noctalia-shell"
    "Caelestia|caelestia-shell caelestia-shell-git caelestia-meta caelestia-cli caelestia-cli-git|.config/quickshell/caelestia .config/caelestia .local/state/caelestia .cache/caelestia|caelestia"
    "DankMaterialShell|dms-shell dms-shell-bin dms-shell-git dankmaterialshell dankmaterialshell-git|.config/quickshell/dms .config/DankMaterialShell .local/state/DankMaterialShell .cache/DankMaterialShell|dms"
    "illogical impulse|illogical-impulse-*|.config/quickshell/ii .config/illogical-impulse .local/state/quickshell/user .cache/illogical-impulse|"
    "HyprPanel|ags-hyprpanel-git hyprpanel hyprpanel-git|.config/hyprpanel|hyprpanel"
    "Waybar|waybar waybar-git|.config/waybar|waybar"
    "Serpantinum|serpantinum serpantinum-git|.local/share/serpantinum .config/serpantinum|serpantinumd"
)

_shell_pkgs() {   # the installed packages of a table row's package list
    local list="$1" p
    command -v pacman &>/dev/null || return 0
    for p in $list; do
        if [[ "$p" == *'*' ]]; then pacman -Qq 2>/dev/null | grep -E "^${p%\*}" || true
        else pacman -Q "$p" &>/dev/null && echo "$p"; fi
    done
}

# the other shells on this PC (their names, one a line)
found_shells() {
    local row name pkgs dirs cmd d
    for row in "${SHELL_TABLE[@]}"; do
        IFS='|' read -r name pkgs dirs cmd <<<"$row"
        if [ -n "$(_shell_pkgs "$pkgs")" ]; then echo "$name"; continue; fi
        for d in $dirs; do [ -e "$HOME/$d" ] && { echo "$name"; continue 2; }; done
        if [ -n "$cmd" ] && command -v "$cmd" &>/dev/null && [[ "$(command -v "$cmd")" != *monolith* ]]; then echo "$name"; fi
    done
}

remove_other_shells() {
    local row name pkgs dirs cmd d pkg backup any=0 when
    when="$(date +%Y%m%d-%H%M%S)"
    for row in "${SHELL_TABLE[@]}"; do
        IFS='|' read -r name pkgs dirs cmd <<<"$row"
        local installed have_dir=0
        installed="$(_shell_pkgs "$pkgs" | tr '\n' ' ')"
        for d in $dirs; do [ -e "$HOME/$d" ] && have_dir=1; done
        [ -n "$installed" ] || [ "$have_dir" = 1 ] || { [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; } || continue
        any=1
        backup="$HOME/.local/share/monolith/replaced/$(echo "$name" | tr ' A-Z' '-a-z')-$when"
        mkdir -p "$backup"

        # stopped (never a shell interpreter, never this installer, never anything of Monolith's)
        if [ -n "$cmd" ]; then
            local pid comm
            for pid in $(pgrep -u "$(id -u)" -f -- "(^|/)$cmd( |$)|quickshell.*$cmd|qs .*-c *$cmd" 2>/dev/null); do
                [ "$pid" = "$$" ] && continue
                comm="$(ps -o comm= -p "$pid" 2>/dev/null)"
                case "$comm" in bash|sh|dash|zsh|fish|python*|sudo|"") continue ;; esac
                tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q monolith && continue
                kill "$pid" 2>/dev/null
            done
        fi

        # its systemd user services and autostart entries: into the backup
        if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
            local unit exec
            while read -r unit _; do
                [ -n "$unit" ] || continue
                exec="$(systemctl --user show -p ExecStart --value "$unit" 2>/dev/null)"
                { [ -n "$cmd" ] && grep -qi -- "$cmd" <<<"$unit $exec"; } || grep -qi -- "$(echo "$name" | cut -d' ' -f1)" <<<"$unit" || continue
                systemctl --user disable --now "$unit" &>/dev/null
                [ -f "$HOME/.config/systemd/user/$unit" ] && mv "$HOME/.config/systemd/user/$unit" "$backup/" 2>/dev/null
            done < <(systemctl --user list-unit-files --type=service --no-legend 2>/dev/null)
            systemctl --user daemon-reload &>/dev/null
        fi
        local f
        for f in "$HOME/.config/autostart/"*.desktop; do
            [ -f "$f" ] && [ -n "$cmd" ] || continue
            grep -q "^Exec=.*$cmd" "$f" && mv "$f" "$backup/" 2>/dev/null
        done

        # its packages (plain -R, one at a time: one another package needs is left, not the rest)
        if [ -n "$installed" ]; then
            if command -v pacman &>/dev/null; then
                for pkg in $installed; do sudo pacman -R --noconfirm "$pkg" &>/dev/null || true; done
            elif declare -F pm_remove_pkg &>/dev/null; then
                for pkg in $installed; do pm_remove_pkg "$pkg"; done
            fi
        fi
        # its folders: into the backup
        for d in $dirs; do
            [ -e "$HOME/$d" ] || continue
            mkdir -p "$backup/$(dirname "$d")"
            mv "$HOME/$d" "$backup/$d" 2>/dev/null
        done
        local left
        left="$(_shell_pkgs "$pkgs" | tr '\n' ' ')"
        echo -e "  ${C_GREEN}other shell:${RESET} $name removed${left:+ ${C_YELLOW}(still installed, needed by something else: $left)${RESET}}"
        echo -e "        (its files: ${backup/#$HOME/\~})"
    done
    [ "$any" = 1 ] || echo -e "  ${C_CYAN}other shells:${RESET} none found"
}
