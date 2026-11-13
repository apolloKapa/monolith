#!/usr/bin/env bash
# Monolith as the shell on Hyprland, only when chosen (the installer's Desktop line, or
# `monolith hyprland on`; `monolith hyprland off` undoes it). It never uninstalls or edits another
# shell's own files. In ~/.config/hypr it backs everything up first, turns off (comments out)
# another shell's start-up lines and keys, and keeps everything of its own in one labelled folder,
# ~/.config/hypr/monolith/ (start, keybinds, workspaces, borders, cursor, and my-keys: yours,
# never changed), loaded by monolith/init with one line at the end of your main config
# (shell/scripts/hypr_files.py). Hyprland reads hyprland.lua when there is one, else hyprland.conf.

HYPR_DIR="$HOME/.config/hypr"
HYPR_BACKUP="$HOME/.config/hypr.before-monolith"
HYPR_MARK="monolith-off: "
HYPR_MODULES="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Which keys Hyprland gets: "monolith" (Monolith's own layout, the same as on niri, made from its
# niri keymap by hypr_keys.py; every other key in the config is turned off) or "mine" (your
# config's keys stay; another shell's become Monolith's, merge_keys.py). Kept in the keybinds
# file, so an update keeps the choice. Set by the installer's menu.
HYPR_KEYS="${HYPR_KEYS:-}"
# Monolith's folder helper: the installed shell's copy, or the repo's
hypr_files() {
    local f
    for f in "$HOME/.local/share/monolith/shell/scripts/hypr_files.py" "$HYPR_MODULES/../../monolith/shell/scripts/hypr_files.py"; do
        [ -f "$f" ] && { python3 "$f" "$@"; return; }
    done
    return 1
}
hypr_keys_saved() {
    sed -n 's/^[#-]* keys: \([a-z]*\)$/\1/p' "$HYPR_DIR/monolith/keybinds.lua" "$HYPR_DIR/monolith/keybinds.conf" \
        "$HYPR_DIR/monolith.lua" "$HYPR_DIR/monolith.conf" 2>/dev/null | head -1
}
# Monolith's niri keymap: the installed copy, or the repo's
hypr_keys_source() {
    local f
    for f in "$HYPR_MODULES/../niri-keybinds.kdl" "$HYPR_MODULES/../../config/niri/config/keybinds.kdl"; do
        [ -f "$f" ] && { echo "$f"; return; }
    done
}
_hypr_keys_choice() {
    local k="${HYPR_KEYS:-$(hypr_keys_saved)}"
    [ "$k" = monolith ] && [ -n "$(hypr_keys_source)" ] && echo monolith || echo mine
}

hypr_present() {
    command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1 || [ -d "$HYPR_DIR" ]
}

hypr_kind() {
    if [ -f "$HYPR_DIR/hyprland.lua" ]; then echo lua
    elif [ -f "$HYPR_DIR/hyprland.conf" ]; then echo conf
    else echo none; fi
}

# already set up (by an earlier install: the folder, or an older version's monolith.lua)
hypr_switched() {
    [ -f "$HYPR_DIR/monolith/init.lua" ] || [ -f "$HYPR_DIR/monolith/init.conf" ] \
        || [ -f "$HYPR_DIR/monolith.lua" ] || [ -f "$HYPR_DIR/monolith.conf" ]
}

# start (Monolith at login, its environment) and keybinds (in sections), in Monolith's folder
_hypr_write() {
    local kind="$1" c m="$HOME/.local/bin/monolith" src
    [ "$kind" = lua ] && c="--" || c="#"
    src="$(hypr_keys_source)"
    if [ "$kind" = lua ]; then
        hypr_files write start <<EOF
-- Monolith starting at login, and its environment. Rewritten on every update.
-- Qt apps (and the shell) take their icons and colours from qt6ct
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.on("hyprland.start", function()
  hl.exec_cmd("$m start --login")
end)
EOF
    else
        hypr_files write start <<EOF
# Monolith starting at login, and its environment. Rewritten on every update.
env = QT_QPA_PLATFORMTHEME,qt6ct
exec-once = $m start --login
EOF
    fi
    {
        echo "$c Monolith's keys, in sections. Rewritten on every update: keys of your own go in my-keys"
        echo "$c (a key you set there wins, and Monolith leaves it out of this file)."
        echo "$c keys: $(_hypr_keys_choice)"
        echo ""
        if [ -z "$src" ]; then
            echo "$c (Monolith's keymap wasn't found: no keys)"
        elif [ "$(_hypr_keys_choice)" = monolith ]; then
            echo "$c Monolith's key layout, the same as on niri"
            echo ""
            python3 "$HYPR_MODULES/merge_keys.py" layout "$HYPR_DIR" "$src" "$m" "$kind"
        else
            echo "$c Your config's keys stay as they are; another shell's are Monolith's now"
            echo ""
            python3 "$HYPR_MODULES/merge_keys.py" hypr "$HYPR_DIR" "$src" "$m" "$kind" 2>/dev/null
        fi
    } | _hypr_my_changes | hypr_files write keybinds
}
# the keys you changed in Settings, put back on the freshly made keybinds (shell/scripts/keys.py)
_hypr_my_changes() {
    local k="$HOME/.local/share/monolith/shell/scripts/keys.py"
    [ -f "$k" ] || k="$HYPR_MODULES/../../monolith/shell/scripts/keys.py"
    if [ -f "$k" ] && [ -f "$HOME/.config/monolith/keys-hyprland.json" ]; then python3 "$k" hypr-apply --hyprland; else cat; fi
}

# Another shell's lines in the config: its start-up lines and every key that calls it (its
# menus, lock, screenshots, volume, workspaces). Monolith's file binds the same keys again
_hypr_turn_off() {
    local kind="$1" c ext f
    if [ "$kind" = lua ]; then c="-- "; ext="lua"; else c="# "; ext="conf"; fi
    # another shell's keys and start-up lines (its bar, notifications, wallpaper) go first, whatever
    # shell it is (the keys come back as Monolith's in Monolith's file)
    [ -n "$(hypr_keys_source)" ] && python3 "$HYPR_MODULES/merge_keys.py" hypr "$HYPR_DIR" "$(hypr_keys_source)" "$HOME/.local/bin/monolith" "$kind" >/dev/null 2>&1
    # Monolith's own key layout: every other key goes too (it would fire alongside), except mouse
    # drags and gestures; whole statements, never half of one (that would break the config)
    if [ "$(_hypr_keys_choice)" = monolith ]; then
        python3 "$HYPR_MODULES/merge_keys.py" hypr-off-all "$HYPR_DIR" "$kind" >/dev/null 2>&1
    fi
    # (no keymap to merge with: Serpantinum's lines, the old way)
    if [ -z "$(hypr_keys_source)" ]; then
        while IFS= read -r -d '' f; do
            case "$f" in "$HYPR_DIR/monolith/"*) continue ;; esac
            case "$(basename "$f")" in monolith*) continue ;; esac
            sed -i -E "/^[[:space:]]*(--|#)/! { /serpantinumd?([^a-zA-Z_-]|$)/ s/^([[:space:]]*)/\1${c}${HYPR_MARK}/ }" "$f"
        done < <(find "$HYPR_DIR" -name "*.$ext" -type f -print0)
    fi
}

hypr_switch() {
    local kind
    kind="$(hypr_kind)"
    if [ "$kind" = none ]; then
        echo -e "  ${C_YELLOW}Hyprland:${RESET} no hyprland.lua or hyprland.conf in $HYPR_DIR, nothing changed"
        return 1
    fi
    if hypr_switched; then
        # (an older version's files move into the folder; Monolith's are written again, so an
        # update brings its fixes, and a changed key choice applies too)
        local choice; choice="$(_hypr_keys_choice)"
        hypr_files migrate
        HYPR_KEYS="$choice" _hypr_turn_off "$kind"
        HYPR_KEYS="$choice" _hypr_write "$kind"
        echo -e "  ${C_CYAN}Hyprland:${RESET} Monolith's files are up to date (${HYPR_DIR/#$HOME/\~}/monolith/)"
        return 0
    fi
    # the whole folder, once (a later reinstall keeps the first, untouched copy)
    if [ ! -e "$HYPR_BACKUP" ]; then
        cp -a "$HYPR_DIR" "$HYPR_BACKUP" || { echo -e "  ${C_RED}Hyprland:${RESET} couldn't back up $HYPR_DIR, nothing changed"; return 1; }
    fi
    _hypr_turn_off "$kind"
    _hypr_write "$kind"
    echo -e "  ${C_GREEN}Hyprland:${RESET} Monolith starts there from your next login. Its files: ${HYPR_DIR/#$HOME/\~}/monolith/"
    echo -e "  (your own keys go in monolith/my-keys). Backup: ${HYPR_BACKUP/#$HOME/\~}. Undo: monolith hyprland off"
}

# hypr_switch, with a safety net: inside a Hyprland session, if Hyprland reports config errors
# afterwards that it didn't have before, the config goes back to how it was a moment ago.
hypr_safe_switch() {
    local snap before after rc
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] || ! command -v hyprctl >/dev/null 2>&1; then
        hypr_switch; return
    fi
    snap="$(mktemp -d)" && cp -a "$HYPR_DIR" "$snap/hypr" || { hypr_switch; return; }
    before="$(hyprctl configerrors 2>/dev/null)"
    hypr_switch; rc=$?
    hyprctl reload >/dev/null 2>&1
    sleep 1.5
    after="$(hyprctl configerrors 2>/dev/null)"
    if [ "$after" != "$before" ] && [ -n "$(printf '%s' "$after" | tr -d '[:space:]')" ] && ! printf '%s' "$after" | grep -qix "no errors"; then
        rm -rf "$HYPR_DIR" && cp -a "$snap/hypr" "$HYPR_DIR"
        hyprctl reload >/dev/null 2>&1
        echo -e "  ${C_RED}Hyprland:${RESET} the new config had errors, so it was put back as it was:"
        printf '%s\n' "$after" | head -5 | sed 's/^/    /'
        rc=1
    fi
    rm -rf "$snap"
    return $rc
}

# put Hyprland's config back as it was before Monolith took over
hypr_undo() {
    if [ ! -d "$HYPR_BACKUP" ]; then
        # no backup (made by hand?): just remove Monolith's part and turn the lines it turned off back on
        hypr_switched || { echo "Monolith isn't set up as the Hyprland shell."; return 0; }
        rm -f "$HYPR_DIR/monolith.lua" "$HYPR_DIR/monolith.conf"
        hypr_files remove
        sed -i '/^require("monolith")$/d' "$HYPR_DIR/hyprland.lua" 2>/dev/null
        sed -i "\|^source = $HYPR_DIR/monolith.conf$|d" "$HYPR_DIR/hyprland.conf" 2>/dev/null
        find "$HYPR_DIR" \( -name "*.lua" -o -name "*.conf" \) -type f -exec sed -i -E "s/^([[:space:]]*)(-- |# )${HYPR_MARK}/\1/" {} +
    else
        local keep="$HOME/.config/hypr.with-monolith"
        rm -rf "$keep"
        mv "$HYPR_DIR" "$keep" && mv "$HYPR_BACKUP" "$HYPR_DIR"
        echo "(the config as Monolith left it is in ${keep/#$HOME/\~})"
    fi
    echo "Hyprland's config is back as it was: your old shell starts there again from your next login."
}
