#!/usr/bin/env bash
# Monolith as the shell on Hyprland, only when asked (the installer asks, default no; undo with
# `monolith hyprland off`). It never uninstalls or edits another shell's own files: in
# ~/.config/hypr it backs everything up, turns off (comments out) only the lines that start
# Serpantinum or call it, and adds Monolith's start line and keys in a file of its own
# (monolith.lua, or monolith.conf for a classic hyprland.conf), included at the end of the main
# config. Hyprland reads hyprland.lua when there is one (Serpantinum's setup), else hyprland.conf.

HYPR_DIR="$HOME/.config/hypr"
HYPR_BACKUP="$HOME/.config/hypr.before-monolith"
HYPR_MARK="monolith-off: "

hypr_present() {
    command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1 || [ -d "$HYPR_DIR" ]
}

hypr_kind() {
    if [ -f "$HYPR_DIR/hyprland.lua" ]; then echo lua
    elif [ -f "$HYPR_DIR/hyprland.conf" ]; then echo conf
    else echo none; fi
}

# already set up (by an earlier install)
hypr_switched() {
    [ -f "$HYPR_DIR/monolith.lua" ] || [ -f "$HYPR_DIR/monolith.conf" ]
}

# the keys: Serpantinum's (so they keep doing the same thing), as Monolith's commands.
# "key|command" (key in Hyprland's words: mods then key)
_hypr_binds() {
    local m="$HOME/.local/bin/monolith"
    cat <<EOF
SUPER|D|$m msg toggle launcher
SUPER|C|$m msg toggle clipboard
SUPER|B|$m msg toggle system
SUPER|M|$m msg toggle music
SUPER|W|$m msg toggle wallpaper
SUPER|S|$m msg toggle calendar
SUPER|N|$m msg toggle network
SUPER|V|$m msg toggle volume
SUPER|H|$m msg toggle cheatsheet
SUPER|A|$m msg toggle notifications
SUPER|R|$m restart
SUPER|L|$m lock
|Print|$m screenshot
SUPER SHIFT|S|$m screenshot
|XF86AudioRaiseVolume|wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
|XF86AudioLowerVolume|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
|XF86AudioMute|wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
|XF86AudioMicMute|wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
|XF86MonBrightnessUp|brightnessctl set 5%+
|XF86MonBrightnessDown|brightnessctl set 5%-
EOF
}

_hypr_write_lua() {
    local f="$HYPR_DIR/monolith.lua" mods key cmd combo opts
    {
        echo "-- Monolith as the shell (written by Monolith's installer; \`monolith hyprland off\` undoes it)"
        echo "-- Qt apps (and the shell) take their icons and colours from qt6ct"
        echo "hl.env(\"QT_QPA_PLATFORMTHEME\", \"qt6ct\")"
        echo "hl.on(\"hyprland.start\", function()"
        echo "  hl.exec_cmd(\"$HOME/.local/bin/monolith start --login\")"
        echo "end)"
        while IFS='|' read -r mods key cmd; do
            combo="$key"; [ -n "$mods" ] && combo="${mods// / + } + $key"
            # (volume and brightness keys also work on the lock screen; menus don't)
            case "$key" in XF86*) opts=", { locked = true }" ;; *) opts="" ;; esac
            echo "hl.bind(\"$combo\", hl.dsp.exec_cmd(\"$cmd\")$opts)"
        done < <(_hypr_binds)
        # workspaces 1-10 (Serpantinum switched them through its own shell)
        echo "for i = 1, 10 do"
        echo "  local key = i % 10"
        echo "  hl.bind(\"SUPER + \" .. key, hl.dsp.focus({ workspace = i }))"
        echo "  hl.bind(\"SUPER + SHIFT + \" .. key, hl.dsp.window.move({ workspace = i }))"
        echo "end"
    } > "$f"
    grep -q '^require("monolith")' "$HYPR_DIR/hyprland.lua" || printf '\nrequire("monolith")\n' >> "$HYPR_DIR/hyprland.lua"
}

_hypr_write_conf() {
    local f="$HYPR_DIR/monolith.conf" mods key cmd
    {
        echo "# Monolith as the shell (written by Monolith's installer; \`monolith hyprland off\` undoes it)"
        echo "env = QT_QPA_PLATFORMTHEME,qt6ct"
        echo "exec-once = $HOME/.local/bin/monolith start --login"
        while IFS='|' read -r mods key cmd; do
            case "$key" in XF86*) echo "bindl = $mods, $key, exec, $cmd" ;; *) echo "bind = $mods, $key, exec, $cmd" ;; esac
        done < <(_hypr_binds)
        for i in 1 2 3 4 5 6 7 8 9 10; do
            echo "bind = SUPER, $((i % 10)), workspace, $i"
            echo "bind = SUPER SHIFT, $((i % 10)), movetoworkspace, $i"
        done
    } > "$f"
    grep -q "^source = $f" "$HYPR_DIR/hyprland.conf" || printf '\nsource = %s\n' "$f" >> "$HYPR_DIR/hyprland.conf"
}

# Serpantinum's lines in the config: its start (serpantinumd) and every key that calls it (its
# menus, lock, screenshots, volume, workspaces). Monolith's file binds the same keys again
_hypr_turn_off() {
    local kind="$1" c ext f
    if [ "$kind" = lua ]; then c="-- "; ext="lua"; else c="# "; ext="conf"; fi
    while IFS= read -r -d '' f; do
        case "$(basename "$f")" in monolith.lua|monolith.conf) continue ;; esac
        # (only lines that aren't already comments)
        sed -i -E "/^[[:space:]]*(--|#)/! { /serpantinumd?([^a-zA-Z_-]|$)/ s/^([[:space:]]*)/\1${c}${HYPR_MARK}/ }" "$f"
    done < <(find "$HYPR_DIR" -name "*.$ext" -type f -print0)
}

hypr_switch() {
    local kind
    kind="$(hypr_kind)"
    if [ "$kind" = none ]; then
        echo -e "  ${C_YELLOW}Hyprland:${RESET} no hyprland.lua or hyprland.conf in $HYPR_DIR, nothing changed"
        return 1
    fi
    if hypr_switched; then
        # (Monolith's own file is written again, so an update brings its fixes)
        if [ "$kind" = lua ]; then _hypr_write_lua; else _hypr_write_conf; fi
        echo -e "  ${C_CYAN}Hyprland:${RESET} Monolith is already the shell there (its keys file is up to date)"
        return 0
    fi
    # the whole folder, once (a later reinstall keeps the first, untouched copy)
    if [ ! -e "$HYPR_BACKUP" ]; then
        cp -a "$HYPR_DIR" "$HYPR_BACKUP" || { echo -e "  ${C_RED}Hyprland:${RESET} couldn't back up $HYPR_DIR, nothing changed"; return 1; }
    fi
    _hypr_turn_off "$kind"
    if [ "$kind" = lua ]; then _hypr_write_lua; else _hypr_write_conf; fi
    echo -e "  ${C_GREEN}Hyprland:${RESET} Monolith starts there from your next login (Serpantinum is still installed;"
    echo -e "  its start line and keys are commented out). Backup: ${HYPR_BACKUP/#$HOME/\~}. Undo: monolith hyprland off"
}

# put Hyprland's config back as it was before Monolith took over
hypr_undo() {
    if [ ! -d "$HYPR_BACKUP" ]; then
        # no backup (made by hand?): just remove Monolith's part and turn Serpantinum's lines back on
        hypr_switched || { echo "Monolith isn't set up as the Hyprland shell."; return 0; }
        rm -f "$HYPR_DIR/monolith.lua" "$HYPR_DIR/monolith.conf"
        sed -i '/^require("monolith")$/d' "$HYPR_DIR/hyprland.lua" 2>/dev/null
        sed -i "\|^source = $HYPR_DIR/monolith.conf$|d" "$HYPR_DIR/hyprland.conf" 2>/dev/null
        find "$HYPR_DIR" \( -name "*.lua" -o -name "*.conf" \) -type f -exec sed -i -E "s/^([[:space:]]*)(-- |# )${HYPR_MARK}/\1/" {} +
    else
        local keep="$HOME/.config/hypr.with-monolith"
        rm -rf "$keep"
        mv "$HYPR_DIR" "$keep" && mv "$HYPR_BACKUP" "$HYPR_DIR"
        echo "(the config as Monolith left it is in ${keep/#$HOME/\~})"
    fi
    echo "Hyprland's config is back as it was: Serpantinum starts there again from your next login."
}
