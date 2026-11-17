#!/usr/bin/env bash
# Other shells on the same PC. Monolith is its own shell with its own files (~/.local/share/monolith,
# ~/.config/monolith, ~/.local/state/monolith, the monolith command): it never stops, moves or edits
# another shell, its files, or the configs of other compositors. When Serpantinum is installed it
# keeps running in its own sessions (e.g. Hyprland) and Monolith runs in niri next to it.

OTHER_SHELL="serpantinum"

other_shell_installed() {
    [ -d "$HOME/.local/share/$OTHER_SHELL" ] || [ -d "$HOME/.config/$OTHER_SHELL" ] \
        || command -v "${OTHER_SHELL}d" &>/dev/null || [ -e "/usr/local/bin/${OTHER_SHELL}d" ] \
        || { command -v pacman &>/dev/null && pacman -Qq "$OTHER_SHELL" "$OTHER_SHELL-git" &>/dev/null; }
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

# Another shell or bar started by systemd (a user service) or by XDG autostart: Monolith's niri and
# Hyprland configs don't start it, but those do, and it ran next to Monolith (two bars, two
# notification daemons). It's kept out of niri and Hyprland sessions only: a systemd drop-in
# (ConditionEnvironment) or NotShowIn= on the autostart entry. Other desktops still start it, and
# deleting the one file put there undoes it. Running now in a niri or Hyprland session: stopped.
OTHER_SHELLS_RX='noctalia|caelestia|illogical|end-4|dms|dankmaterial|inir|serpantinum|hyprpanel|waybar|ags|astal|eww|nwg-panel|nwg-dock|ironbar|yambar|swaync|mako|dunst|fnott|hyprpaper|swww|awww|swaybg|mpvpaper|wpaperd'
OTHER_SHELL_PROC_RX='(^|/)(qs|quickshell) (-c|--config) *(noctalia|caelestia|ii|dms|illogical)|noctalia-shell|caelestia|(^|/)waybar( |$)|(^|/)ags( |$)|(^|/)hyprpanel|(^|/)dms run'

other_shell_cmd() {   # is this command line another shell's (and not Monolith's)?
    local c="$1"
    [[ "$c" == *monolith* ]] && return 1
    grep -Eqi "(^|[^a-z0-9])($OTHER_SHELLS_RX)([^a-z0-9]|$)|(qs|quickshell) +(-c|--config)" <<<"$c"
}

in_monolith_session() {
    case "${XDG_CURRENT_DESKTOP:-}" in *[Nn]iri*|*Hyprland*) return 0 ;; esac
    [ -n "${NIRI_SOCKET:-}" ] || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]
}

quiet_other_shells() {
    local quieted=()
    # systemd user services
    if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
        local unit exec dir
        while read -r unit _; do
            [ -n "$unit" ] || continue
            exec="$(systemctl --user show -p ExecStart --value "$unit" 2>/dev/null)"
            other_shell_cmd "$unit $exec" || continue
            dir="$HOME/.config/systemd/user/$unit.d"
            mkdir -p "$dir"
            cat > "$dir/monolith-off.conf" <<'UNIT'
# Monolith's installer: not started in niri or Hyprland sessions, where Monolith is the shell (other
# desktops still start it). Delete this file and run `systemctl --user daemon-reload` to undo.
[Unit]
ConditionEnvironment=!XDG_CURRENT_DESKTOP=niri
ConditionEnvironment=!XDG_CURRENT_DESKTOP=Niri
ConditionEnvironment=!XDG_CURRENT_DESKTOP=Hyprland
UNIT
            quieted+=("$unit (systemd)")
            in_monolith_session && systemctl --user stop "$unit" 2>/dev/null
        done < <(systemctl --user list-unit-files --type=service --state=enabled --no-legend 2>/dev/null)
        [ ${#quieted[@]} -gt 0 ] && systemctl --user daemon-reload 2>/dev/null
    fi
    # XDG autostart entries (yours, and the system's: a copy of those in yours)
    local f name exec dst
    for f in /etc/xdg/autostart/*.desktop "$HOME/.config/autostart/"*.desktop; do
        [ -f "$f" ] || continue
        exec="$(sed -n 's/^Exec=//p' "$f" | head -n 1)"
        other_shell_cmd "$exec" || continue
        name="$(basename "$f")"
        dst="$HOME/.config/autostart/$name"
        [ "$f" != "$dst" ] && { [ -f "$dst" ] || { mkdir -p "$HOME/.config/autostart"; cp "$f" "$dst"; }; }
        grep -q 'niri;' "$dst" 2>/dev/null && continue
        if grep -q '^NotShowIn=' "$dst"; then
            sed -i 's/^NotShowIn=\(.*\)$/NotShowIn=\1;niri;Niri;Hyprland;/; s/;;/;/g' "$dst"
        else
            sed -i '/^\[Desktop Entry\]/a NotShowIn=niri;Niri;Hyprland;' "$dst"
        fi
        quieted+=("$name (autostart)")
    done
    # running now in this niri / Hyprland session (started some other way): stopped
    if in_monolith_session; then
        # (never a shell interpreter, whose command line can merely mention one, never anything of
        # Monolith's, never this installer or what started it)
        local pid comm cmd ancestors=" $$ " p=$$ stopped=()
        while [ "$p" -gt 1 ] 2>/dev/null; do p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"; [ -n "$p" ] || break; ancestors+="$p "; done
        for pid in $(pgrep -f -u "$(id -u)" -- "$OTHER_SHELL_PROC_RX" 2>/dev/null); do
            [[ "$ancestors" == *" $pid "* ]] && continue
            comm="$(ps -o comm= -p "$pid" 2>/dev/null)"
            case "$comm" in bash|sh|dash|zsh|fish|python*|perl|sudo|"") continue ;; esac
            cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
            [[ "$cmd" == *monolith* ]] && continue
            kill "$pid" 2>/dev/null && stopped+=("$comm")
        done
        [ ${#stopped[@]} -gt 0 ] && quieted+=("running: ${stopped[*]}")
    fi
    [ ${#quieted[@]} -eq 0 ] && return 0
    echo -e "  ${C_CYAN}other shells:${RESET} kept out of niri and Hyprland sessions: ${quieted[*]}"
}
