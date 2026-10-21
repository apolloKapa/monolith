#!/usr/bin/env bash
# Installer UI: banner, main menu, SDDM submenu, completion screen.

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
C_CYAN=$'\e[36m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_RED=$'\e[31m'

IS_REINSTALL=false
NIRI_MODE=replace
WALLPAPERS=random

OPT_SDDM=true
REPLACE_DM=false
SDDM_WAYLAND="$PM_SDDM_WAYLAND_DEFAULT"

USER_NAME="${USER:-$(whoami)}"
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
[[ -z "$OS_NAME" ]] && OS_NAME="Linux"
CPU_INFO=$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || true)
[[ -z "$CPU_INFO" ]] && CPU_INFO="unknown"
GPU_INFO=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//g; s/\[[0-9a-f:]+\]//g' | xargs)
[[ -z "$GPU_INFO" ]] && GPU_INFO="unknown"

cleanup_terminal() {
    printf "\e[?25h" 2>/dev/null || true
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
    printf "\e[?25l"
    printf "%s%s$(t "installer.ui.sddm_title")%s\n\n" "$BOLD" "$C_CYAN" "$RESET"

    local current_dm=""
    local dms=("gdm" "gdm3" "lightdm" "sddm" "lxdm" "lxdm-gtk3" "ly")
    for dm in "${dms[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
            current_dm="$dm"
            break
        fi
    done

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
                printf "\r\033[K%s%s ▸ %s%s\n" "$BOLD" "$C_CYAN" "$RESET" "${items[$i]}"
            else
                printf "\r\033[K    %s\n" "${items[$i]}"
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
    printf "%s" "$BOLD"
    cat << "EOF"
 ███╗   ███╗ ██████╗ ███╗   ██╗ ██████╗ ██╗     ██╗████████╗██╗  ██╗
 ████╗ ████║██╔═══██╗████╗  ██║██╔═══██╗██║     ██║╚══██╔══╝██║  ██║
 ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║██║     ██║   ██║   ███████║
 ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║██║     ██║   ██║   ██╔══██║
 ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║╚██████╔╝███████╗██║   ██║   ██║  ██║
 ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚═╝  ╚═╝
EOF
    printf "%s" "$RESET"
    printf " %sreally good desktop :3%s\n" "$BOLD" "$RESET"
    printf "%s%s%s\n" "$DIM" "--------------------------------------------------------------------------------" "$RESET"
    printf " %sUser:%s %-25s | %sOS:%s  %s\n" "$BOLD" "$RESET" "$USER_NAME" "$BOLD" "$RESET" "$OS_NAME"
    printf " %sCPU:%s  %-25.25s | %sGPU:%s %.40s\n" "$BOLD" "$RESET" "$CPU_INFO" "$BOLD" "$RESET" "$GPU_INFO"
    printf " %sRepo:%s %-25s | %sMode:%s %s\n" "$BOLD" "$RESET" "$REPO_SLUG@$MONOLITH_BRANCH" "$BOLD" "$RESET" "$INSTALL_STATE"
    printf " %sVersion:%s %s (%s)" "$BOLD" "$RESET" "$TARGET_VERSION" "$TARGET_COMMIT"
    [ -n "$OLD_VERSION" ] && printf "  %sinstalled: %s%s" "$DIM" "$OLD_VERSION" "$RESET"
    printf "\n%s%s%s\n\n" "$DIM" "================================================================================" "$RESET"
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
    printf "\e[?25l"
}

on_off() { [ "$1" = true ] && printf "%s[ON]%s" "$C_GREEN" "$RESET" || printf "%s[OFF]%s" "$DIM" "$RESET"; }

run_installer_ui() {
    local cursor=0
    while true; do
        draw_banner
        stty -echo 2>/dev/null || true
        printf "\e[?25l"

        local niri_label wp_label
        [ "$NIRI_MODE" = replace ] \
            && niri_label="${C_GREEN}[Monolith config, old one backed up]${RESET}" \
            || niri_label="${DIM}[keep mine]${RESET}"
        case "$WALLPAPERS" in
            full)   wp_label="${C_GREEN}[full pack]${RESET}" ;;
            random) wp_label="${C_GREEN}[3 random]${RESET}" ;;
            *)      wp_label="${DIM}[none]${RESET}" ;;
        esac

        local labels=(
            "Packages overview"
            "Apps for the keybinds (librewolf, thunar, rofi, steam...) $(on_off "$OPT_KEYBIND_APPS")"
            "All my apps (packages.txt + packages-aur.txt) $(on_off "$OPT_ALL_MY_APPS")"
            "niri config (keybinds, displays, workspaces) $niri_label"
            "Login screen (SDDM theme) $(on_off "$OPT_SDDM")"
            "Wallpapers $wp_label"
        )
        local actions=(packages keybind_apps all_apps niri sddm wallpapers)
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
                    printf "\r\033[K%s ▸ %s%d. %s\n" "$BOLD" "$RESET" $((i + 1)) "${labels[$i]}"
                else
                    printf "\r\033[K   %d. %s\n" $((i + 1)) "${labels[$i]}"
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
            all_apps) OPT_ALL_MY_APPS=$([ "$OPT_ALL_MY_APPS" = true ] && echo false || echo true) ;;
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

step() { printf "\n%s%s==>%s %s%s%s\n" "$BOLD" "$C_CYAN" "$RESET" "$BOLD" "$1" "$RESET"; }

draw_completion_screen() {
    cleanup_terminal
    printf "\n%s%s" "$BOLD" "$C_GREEN"
    printf "  Monolith %s (%s) is installed.%s\n\n" "$TARGET_VERSION" "$TARGET_COMMIT" "$RESET"
    printf "  %sreally good desktop :3%s\n\n" "$BOLD" "$RESET"
    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        printf "%s%s  These packages failed to install:%s\n" "$BOLD" "$C_RED" "$RESET"
        for fp in "${FAILED_PKGS[@]}"; do printf "    - %s%s%s\n" "$C_YELLOW" "$fp" "$RESET"; done
        printf "\n"
    fi
    if [ "$MONOLITH_STARTED" = true ]; then
        printf "  Monolith is running now. Next time you log in, pick %sniri%s for the Monolith keybinds and layout.\n" "$BOLD" "$RESET"
    else
        printf "  Log in to %sniri%s and Monolith starts by itself (or run %smonolithd start%s inside niri).\n" "$BOLD" "$RESET" "$BOLD" "$RESET"
    fi
    printf "  Run %smonolith installer%s any time to update or change these choices.\n\n" "$BOLD" "$RESET"

    local choice=""
    if [ -t 0 ]; then
        read -r -p "  Restart your computer now? [y/N] " choice
    elif [ -e /dev/tty ]; then
        read -r -p "  Restart your computer now? [y/N] " choice < /dev/tty
    fi
    [[ "$choice" =~ ^[Yy]$ ]] && systemctl reboot
    return 0
}
