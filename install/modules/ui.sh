#!/usr/bin/env bash
# Installer UI: banner, main menu, SDDM submenu, completion screen.

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
C_CYAN=$'\e[36m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'

# --- effects ---------------------------------------------------------------------------------
# Animations only in a real terminal (not piped, not the --update notification run);
# MONOLITH_NO_ANIM=1 turns them off. Gradients use 24-bit colour when the terminal has it.
ANIM=false
[ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${MONOLITH_NO_ANIM:-}" ] && ANIM=true
TRUECOLOR=false
case "${COLORTERM:-}" in truecolor|24bit) TRUECOLOR=true ;; esac
case "${TERM:-}" in *kitty*|*alacritty*|*foot*|*wezterm*|*ghostty*) TRUECOLOR=true ;; esac
# the gradient: pink -> violet -> cyan
GRAD=(255 140 220  190 140 255  110 200 255)
BANNER_SHOWN=false

nap() { [ "$ANIM" = true ] && sleep "$1"; return 0; }
# the gradient's colour at position i of n, as an escape in $GA (cyan without 24-bit colour);
# grad_at prints it. No subshells in the loops: the logo sweep draws thousands of these.
grad_set() {
    local i=$1 n=$2
    [ "$TRUECOLOR" = true ] || { GA=$C_CYAN; return; }
    [ "$n" -le 1 ] && n=2
    local t=$(( i * 2000 / (n - 1) ))        # 0..2000 over the two halves
    local k=0; [ "$t" -gt 1000 ] && { k=3; t=$(( t - 1000 )); }
    GA=$'\e'"[38;2;$(( GRAD[k] + (GRAD[k+3] - GRAD[k]) * t / 1000 ));$(( GRAD[k+1] + (GRAD[k+4] - GRAD[k+1]) * t / 1000 ));$(( GRAD[k+2] + (GRAD[k+5] - GRAD[k+2]) * t / 1000 ))m"
}
grad_at() { grad_set "$1" "$2"; printf '%s' "$GA"; }
# a line of text in the gradient, in $GL (only the first `upto` characters); grad_line prints it
grad_build() {
    local text=$1 upto=${2:-999999} i n=${#1}
    GL=""
    for (( i = 0; i < n && i < upto; i++ )); do
        grad_set "$i" "$n"; GL+="$GA${text:i:1}"
    done
    GL+=$RESET
}
grad_line() { grad_build "$@"; printf '%s' "$GL"; }
# a full-width rule in the gradient
grad_rule() {
    local w=${1:-80} ch=${2:-─} line="" i
    for (( i = 0; i < w; i++ )); do line+="$ch"; done
    grad_line "$line"
}
# the highlighted menu row: an accent bar and a soft background
row_on() {
    if [ "$TRUECOLOR" = true ]; then
        printf '\r\e[K\e[48;2;58;40;78m%s\e[38;2;255;140;220m ▌%s\e[48;2;58;40;78m %s \e[K%s\n' "$BOLD" "$RESET" "$1" "$RESET"
    else
        printf '\r\e[K%s%s ▸ %s%s\n' "$BOLD" "$C_CYAN" "$RESET" "$1"
    fi
}
row_off() { printf '\r\e[K   %s\n' "$1"; }

IS_REINSTALL=false
NIRI_MODE=replace
WALLPAPERS=random

OPT_SDDM=true
# another login screen theme is set up already (e.g. Serpantinum's): leave it unless asked
_sddm_theme="$(grep -hs '^Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null | tail -1 | cut -d= -f2)"
[ -n "$_sddm_theme" ] && [ "$_sddm_theme" != monolith ] && OPT_SDDM=false
unset _sddm_theme
REPLACE_DM=false
SDDM_WAYLAND="$PM_SDDM_WAYLAND_DEFAULT"

USER_NAME="${USER:-$(whoami)}"
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d "\"'")
[[ -z "$OS_NAME" ]] && OS_NAME="Linux"
CPU_INFO=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || true)
[[ -z "$CPU_INFO" ]] && CPU_INFO="unknown"
GPU_INFO=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//g; s/\[[0-9a-f:]+\]//g' | xargs)
[[ -z "$GPU_INFO" ]] && GPU_INFO="unknown"

cleanup_terminal() {
    printf "\e[?25h\e[?7h" 2>/dev/null || true
    stty echo icanon 2>/dev/null || true
}
trap cleanup_terminal EXIT INT TERM

read_key() {
    local key=""
    local rest=""
    # no more input (closed stdin): behave like Esc so menus exit instead of spinning
    IFS= read -rsn1 key 2>/dev/null || { echo "ESC"; return; }
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.05 rest 2>/dev/null
        if [[ "$rest" == "[A" || "$rest" == "OA" ]]; then
            echo "UP"
            return
        elif [[ "$rest" == "[B" || "$rest" == "OB" ]]; then
            echo "DOWN"
            return
        elif [[ "$rest" == "[C" || "$rest" == "OC" ]]; then
            echo "RIGHT"
            return
        elif [[ "$rest" == "[D" || "$rest" == "OD" ]]; then
            echo "LEFT"
            return
        elif [[ "$rest" == *"["* ]]; then
            local trailing=""
            while read -rsn1 -t 0.05 trailing 2>/dev/null; do
                [[ -z "$trailing" ]] && break
            done
            echo "ESC"
            return
        elif [[ -z "$rest" ]]; then
            echo "ESC"
            return
        fi
        echo "ESC"
        return
    elif [[ -z "$key" || "$key" == $'\n' || "$key" == $'\r' ]]; then
        echo "ENTER"
        return
    elif [[ "$key" == " " ]]; then
        echo "SPACE"
        return
    fi
    echo "$key"
}

manage_sddm_menu() {
    draw_banner
    stty -echo 2>/dev/null || true
    printf "\e[?25l\e[?7l"
    printf "%s%s$(t "installer.ui.sddm_title")%s\n\n" "$BOLD" "$C_CYAN" "$RESET"

    local current_dm=""
    local dms=("gdm" "gdm3" "lightdm" "sddm" "lxdm" "lxdm-gtk3" "ly")
    for dm in "${dms[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
            current_dm="$dm"
            break
        fi
    done
    # OpenRC: Gentoo runs every display manager through one "display-manager" service and names it
    # in /etc/conf.d/display-manager; other distros have a service per display manager
    if [ -z "$current_dm" ] && [ -d /run/openrc ]; then
        local conf_dm=""
        [ -f /etc/conf.d/display-manager ] && conf_dm="$(sed -n 's/^DISPLAYMANAGER="\{0,1\}\([^"]*\)"\{0,1\}/\1/p' /etc/conf.d/display-manager | tail -1)"
        if [ -n "$conf_dm" ] && rc-update show default 2>/dev/null | grep -qw display-manager; then
            current_dm="$conf_dm"
        else
            for dm in "${dms[@]}"; do
                if rc-update show default 2>/dev/null | grep -qw "$dm"; then current_dm="$dm"; break; fi
            done
        fi
    fi

    if [ -n "$current_dm" ]; then
        printf "$(t "installer.ui.sddm_detected_active" "dm=${BOLD}${C_YELLOW}%s${RESET}")\n\n" "$current_dm"
    else
        printf "%s\n\n" "$(t "installer.ui.sddm_detected_none")"
    fi

    local cursor=0
    local rendered_lines=0

    while true; do
        local S_SDDM="${DIM}[Disabled]${RESET}"
        local S_RDM="${DIM}[No]${RESET}"
        local S_WAY="${DIM}[X11/Default]${RESET}"

        [ "$OPT_SDDM" = true ] && S_SDDM="${C_GREEN}[Enabled]${RESET}"
        [ "$REPLACE_DM" = true ] && S_RDM="${C_GREEN}[Yes]${RESET}"
        [ "$SDDM_WAYLAND" = true ] && S_WAY="${C_GREEN}[Wayland]${RESET}"

        local items=()
        items+=("1. $(t "installer.ui.sddm_opt_install") $S_SDDM")
        if [ -n "$current_dm" ] && [ "$current_dm" != "sddm" ]; then
            items+=("2. $(t "installer.ui.sddm_opt_disable" "dm=$current_dm") $S_RDM")
        fi
        items+=("3. $(t "installer.ui.sddm_opt_wayland") $S_WAY")
        items+=("4. ${BOLD}${C_GREEN}$(t "installer.ui.done")${RESET}")

        if [ "$rendered_lines" -gt 0 ]; then
            printf "\033[%dA" "$rendered_lines"
        fi

        for i in "${!items[@]}"; do
            if [ "$i" -eq "$cursor" ]; then
                row_on "${items[$i]}"
            else
                row_off "${items[$i]}"
            fi
        done
        rendered_lines=${#items[@]}

        local key
        key=$(read_key)

        case "$key" in
            UP|[kK])
                if [ "$cursor" -gt 0 ]; then
                    cursor=$(( cursor - 1 ))
                else
                    cursor=$(( ${#items[@]} - 1 ))
                fi
                ;;
            DOWN|[jJ])
                if [ "$cursor" -lt $(( ${#items[@]} - 1 )) ]; then
                    cursor=$(( cursor + 1 ))
                else
                    cursor=0
                fi
                ;;
            ENTER|SPACE)
                local selected_str="${items[$cursor]}"
                case "$selected_str" in
                    *"1."*)
                        OPT_SDDM=$([ "$OPT_SDDM" = true ] && echo false || echo true)
                        if [ "$OPT_SDDM" = true ] && [ -n "$current_dm" ] && [ "$current_dm" != "sddm" ]; then
                            REPLACE_DM=true
                        fi
                        ;;
                    *"2."*)
                        REPLACE_DM=$([ "$REPLACE_DM" = true ] && echo false || echo true)
                        ;;
                    *"3."*)
                        SDDM_WAYLAND=$([ "$SDDM_WAYLAND" = true ] && echo false || echo true)
                        ;;
                    *"4."*)
                        break
                        ;;
                esac
                ;;
            ESC|[qQ])
                break
                ;;
        esac
    done
}

draw_banner() {
    clear
    local logo=(
" ███╗   ███╗ ██████╗ ███╗   ██╗ ██████╗ ██╗     ██╗████████╗██╗  ██╗"
" ████╗ ████║██╔═══██╗████╗  ██║██╔═══██╗██║     ██║╚══██╔══╝██║  ██║"
" ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║██║     ██║   ██║   ███████║"
" ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║██║     ██║   ██║   ██╔══██║"
" ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║╚██████╔╝███████╗██║   ██║   ██║  ██║"
" ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚═╝  ╚═╝"
    )
    local w=${#logo[0]} l c
    printf '\e[?25l'
    if [ "$ANIM" = true ] && [ "$BANNER_SHOWN" = false ]; then
        # the first time: the logo sweeps in from the left, in the gradient
        for (( c = 4; c <= w + 4; c += 4 )); do
            printf '\e[H'
            for l in "${logo[@]}"; do grad_build "$l" "$c"; printf '%s%s\e[K\n' "$BOLD" "$GL"; done
            sleep 0.012
        done
    else
        for l in "${logo[@]}"; do grad_build "$l"; printf '%s%s\n' "$BOLD" "$GL"; done
    fi
    BANNER_SHOWN=true
    printf " %s%sreally good desktop :3%s\n" "$BOLD" "$(grad_at 0 2)" "$RESET"
    printf "%s\n" "$(grad_rule 80)"
    local k="$BOLD$(grad_at 1 2)"
    printf " %sUser:%s %-25s %s│%s %sOS:%s  %s\n" "$k" "$RESET" "$USER_NAME" "$DIM" "$RESET" "$k" "$RESET" "$OS_NAME"
    printf " %sCPU:%s  %-25.25s %s│%s %sGPU:%s %.40s\n" "$k" "$RESET" "$CPU_INFO" "$DIM" "$RESET" "$k" "$RESET" "$GPU_INFO"
    printf " %sRepo:%s %-25s %s│%s %sMode:%s %s\n" "$k" "$RESET" "$REPO_SLUG@$MONOLITH_BRANCH" "$DIM" "$RESET" "$k" "$RESET" "$INSTALL_STATE"
    printf " %sVersion:%s %s (%s)" "$k" "$RESET" "$TARGET_VERSION" "$TARGET_COMMIT"
    [ -n "$OLD_VERSION" ] && printf "  %sinstalled: %s%s" "$DIM" "$OLD_VERSION" "$RESET"
    printf "\n%s\n\n" "$(grad_rule 80 ━)"
}

show_package_overview() {
    local target_list=()
    mapfile -t target_list < <(target_packages "$PROJECT_ROOT" | awk '!seen[$0]++')
    local missing_raw
    missing_raw=$(pm_missing_pkgs "${target_list[@]}")
    declare -A is_missing
    while IFS= read -r p; do
        [[ -n "$p" ]] && is_missing["$p"]=1
    done <<< "$missing_raw"

    local lines=()
    for pkg in "${target_list[@]}"; do
        if [[ -n "${is_missing[$pkg]}" ]]; then
            lines+=("${C_YELLOW}[ to install ]${RESET} $pkg")
        else
            lines+=("${C_GREEN}[ installed  ]${RESET} $pkg")
        fi
    done

    cleanup_terminal
    printf "%s\n" "${lines[@]}" | fzf --ansi --layout=reverse --border=rounded --margin=1,2 --height=25 \
        --prompt="packages > " --header="${#target_list[@]} packages (Esc to go back)" > /dev/null || true
    stty -echo icanon 2>/dev/null || true
    printf "\e[?25l\e[?7l"
}

on_off() { [ "$1" = true ] && printf "%s[ON]%s" "$C_GREEN" "$RESET" || printf "%s[OFF]%s" "$DIM" "$RESET"; }

run_installer_ui() {
    local cursor=0
    while true; do
        draw_banner
        stty -echo 2>/dev/null || true
        printf "\e[?25l\e[?7l"

        local niri_label wp_label
        [ "$NIRI_MODE" = replace ] \
            && niri_label="${C_GREEN}[replace, backup kept]${RESET}" \
            || niri_label="${DIM}[keep mine]${RESET}"
        case "$WALLPAPERS" in
            full)   wp_label="${C_GREEN}[full pack, ~1.1 GB with live]${RESET}" ;;
            random) wp_label="${C_GREEN}[3 random + 1 live]${RESET}" ;;
            *)      wp_label="${DIM}[none]${RESET}" ;;
        esac

        local labels=(
            "Packages overview"
            "Apps for the keybinds (kitty, librewolf, thunar, mission center) $(on_off "$OPT_KEYBIND_APPS")"
            "niri config (keybinds, displays, workspaces) $niri_label"
            "Login screen (SDDM theme) $(on_off "$OPT_SDDM")"
            "Wallpapers $wp_label"
        )
        local actions=(packages keybind_apps niri sddm wallpapers)
        if [ "$INSTALL_STATE" = current ]; then
            labels+=("${BOLD}${C_GREEN}Update${RESET}" "${BOLD}${C_YELLOW}Reinstall (fresh settings)${RESET}" "${DIM}Exit${RESET}")
            actions+=(install reinstall exit)
        else
            labels+=("${BOLD}${C_GREEN}Install${RESET}" "${DIM}Exit${RESET}")
            actions+=(install exit)
        fi

        local rendered=0 chosen=""
        while [ -z "$chosen" ]; do
            [ "$rendered" -gt 0 ] && printf "\033[%dA" "$rendered"
            for i in "${!labels[@]}"; do
                if [ "$i" -eq "$cursor" ]; then
                    row_on "$((i + 1)). ${labels[$i]}"
                else
                    row_off "$((i + 1)). ${labels[$i]}"
                fi
            done
            rendered=${#labels[@]}
            printf "\r\033[K%s   ↑/↓ or j/k to move, Enter to pick, q to quit%s" "$DIM" "$RESET"
            printf "\r"

            local key
            key=$(read_key)
            case "$key" in
                UP|[kK]) cursor=$(( (cursor - 1 + ${#labels[@]}) % ${#labels[@]} )) ;;
                DOWN|[jJ]) cursor=$(( (cursor + 1) % ${#labels[@]} )) ;;
                [1-9]) [ "$key" -le "${#labels[@]}" ] && { cursor=$((key - 1)); chosen="${actions[$cursor]}"; } ;;
                ENTER|SPACE) chosen="${actions[$cursor]}" ;;
                ESC|[qQ]) chosen="exit" ;;
            esac
        done

        case "$chosen" in
            packages) show_package_overview ;;
            keybind_apps) OPT_KEYBIND_APPS=$([ "$OPT_KEYBIND_APPS" = true ] && echo false || echo true) ;;
            niri) NIRI_MODE=$([ "$NIRI_MODE" = replace ] && echo keep || echo replace) ;;
            sddm) manage_sddm_menu ;;
            wallpapers)
                case "$WALLPAPERS" in random) WALLPAPERS=full ;; full) WALLPAPERS=none ;; *) WALLPAPERS=random ;; esac ;;
            install) IS_REINSTALL=false; cleanup_terminal; clear; return 0 ;;
            reinstall) IS_REINSTALL=true; cleanup_terminal; clear; return 0 ;;
            exit) cleanup_terminal; clear; exit 0 ;;
        esac
    done
}

# each install step: "step 3/7", a bar that fills up to it (animated from the last one), its name
STEP_N=0
STEP_TOTAL=${STEP_TOTAL:-0}
step() {
    STEP_N=$(( STEP_N + 1 ))
    local total=$STEP_TOTAL; [ "$total" -lt "$STEP_N" ] && total=$STEP_N
    local w=30 from=$(( (STEP_N - 1) * 30 / total )) to=$(( STEP_N * 30 / total )) f i bar
    printf "\n"
    for (( f = from; f <= to; f++ )); do
        bar=""
        for (( i = 0; i < w; i++ )); do
            if [ "$i" -lt "$f" ]; then grad_set "$i" "$w"; bar+="$GA━"; else bar+="$DIM─$RESET"; fi
        done
        printf "\r\e[K %s%s%d/%d%s  %s%s  %s%s%s" "$BOLD" "$(grad_at "$STEP_N" "$((total + 1))")" "$STEP_N" "$total" "$RESET" "$bar" "$RESET" "$BOLD" "$1" "$RESET"
        nap 0.02
    done
    printf "\n"
}

draw_completion_screen() {
    cleanup_terminal
    printf "\n"
    # a little sparkle runs across, then settles into the gradient line
    if [ "$ANIM" = true ]; then
        local sparks=("✦" "✧" "·" "⋆") w=60 p i line
        printf '\e[?25l'
        for (( p = 0; p <= w + 6; p += 2 )); do
            line=""
            for (( i = 0; i < w; i++ )); do
                if [ "$i" -le "$p" ] && [ "$i" -gt $(( p - 6 )) ]; then grad_set "$i" "$w"; line+="$GA${sparks[$(( (i + p) % 4 ))]}"
                elif [ "$i" -le "$p" ]; then grad_set "$i" "$w"; line+="$GA─"
                else line+=" "; fi
            done
            printf '\r  %s%s' "$line" "$RESET"
            sleep 0.015
        done
        printf '\e[?25h\n\n'
    else
        printf "  %s\n\n" "$(grad_rule 60)"
    fi
    printf "  %s%s\n" "$BOLD" "$(grad_line "Monolith $TARGET_VERSION ($TARGET_COMMIT) is installed.")"
    printf "  %s%sreally good desktop :3%s\n\n" "$BOLD" "$(grad_at 1 2)" "$RESET"
    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        printf "%s%s  These packages failed to install:%s\n" "$BOLD" "$C_RED" "$RESET"
        for fp in "${FAILED_PKGS[@]}"; do printf "    - %s%s%s\n" "$C_YELLOW" "$fp" "$RESET"; done
        printf "\n"
    fi
    if [ "$MONOLITH_STARTED" = true ]; then
        printf "  Monolith is running now. Next time you log in, pick %sniri%s for the Monolith keybinds and layout.\n" "$BOLD" "$RESET"
    else
        printf "  Log in to %sniri%s and Monolith starts by itself.\n" "$BOLD" "$RESET"
    fi
    printf "  Super+Space opens the hub: search, settings and everything else.\n"
    # Hyprland is here too
    if [ "$HYPR_SWITCHED" = true ]; then
        printf "  On %sHyprland%s Monolith starts from your next login there too (%smonolith hyprland off%s undoes it).\n" "$BOLD" "$RESET" "$BOLD" "$RESET"
    elif hypr_present && ! hypr_switched; then
        printf "  To use Monolith on Hyprland too: %smonolith hyprland on%s (backs up ~/.config/hypr first).\n" "$BOLD" "$RESET"
    fi
    printf "  Run %smonolith installer%s any time to update or change these choices.\n\n" "$BOLD" "$RESET"

    local choice=""
    if [ -t 0 ]; then
        read -r -p "  Restart your computer now? [y/N] " choice
    elif [ -e /dev/tty ]; then
        read -r -p "  Restart your computer now? [y/N] " choice < /dev/tty
    fi
    [[ "$choice" =~ ^[Yy]$ ]] && { systemctl reboot 2>/dev/null || loginctl reboot 2>/dev/null || sudo reboot; }
    return 0
}
