#!/usr/bin/env bash
# Installer UI: a rounded panel in the middle of the screen (the main menu, the login screen's,
# the packages), the install steps, the finish screen.
shopt -s extglob

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

# the panel's colours (plainer without 24-bit colour)
if [ "$TRUECOLOR" = true ]; then
    T_BORDER=$'\e[38;2;118;98;160m'
    T_ACC=$'\e[38;2;255;150;225m'
    T_ACC2=$'\e[38;2;150;200;255m'
    T_SEL=$'\e[48;2;62;44;84m'
    T_ON=$'\e[38;2;140;230;160m'
    T_HEAD=$'\e[38;2;175;150;220m'
    T_BTN=$'\e[48;2;44;38;60m'
else
    T_BORDER=$DIM; T_ACC=$C_CYAN; T_ACC2=$C_CYAN; T_SEL=$'\e[7m'; T_ON=$C_GREEN; T_HEAD=$C_CYAN; T_BTN=""
fi

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

# --- the screen ------------------------------------------------------------------------------
# The menus draw on the terminal's other screen, so what was there before is back afterwards
TUI_ON=false
tui_begin() {
    [ "$TUI_ON" = true ] && return 0
    PANEL_KEY=""
    printf '\e[?1049h\e[?25l\e[?7l'
    stty -echo 2>/dev/null || true
    TUI_ON=true
}
tui_end() {
    [ "$TUI_ON" = true ] || return 0
    printf '\e[2J\e[H\e[?1049l'
    TUI_ON=false
}
cleanup_terminal() {
    # (the install stopped halfway, an error or Ctrl+C: its last lines, and where the rest is)
    local stopped=$PROG_ON
    progress_end
    tui_end
    printf "\e[?25h\e[?7h" 2>/dev/null || true
    stty echo icanon 2>/dev/null || true
    if [ "$stopped" = true ]; then
        printf '\n%s%sThe install stopped.%s The last of what it did:\n\n' "$BOLD" "$C_RED" "$RESET"
        log_tail 20 | sed 's/^/  /'
        printf '\n%sEverything it printed: %s%s\n' "$DIM" "$PROG_LOG" "$RESET"
    fi
}
trap cleanup_terminal EXIT
trap 'cleanup_terminal; exit 130' INT TERM

# the terminal's size, in $TR rows and $TC columns
term_size() {
    local s
    s=$(stty size 2>/dev/null </dev/tty)
    TR=${s%% *}; TC=${s##* }
    [[ "$TR" =~ ^[0-9]+$ ]] || TR=24
    [[ "$TC" =~ ^[0-9]+$ ]] || TC=80
}
# how wide a text is on screen ($VL), its colours not counted
vlen() { local s="${1//$'\e['*([0-9;])m/}"; VL=${#s}; }
# a text made exactly `w` wide ($FT): padded with spaces, or cut with … when it's longer
fit() {
    local text=$1 w=$2
    vlen "$text"
    if (( VL <= w )); then
        printf -v FT '%s%*s' "$text" $(( w - VL )) ''
    else
        local plain="${text//$'\e['*([0-9;])m/}"
        FT="${plain:0:$(( w - 1 ))}…"
    fi
}
# a text in lines at most `w` wide (plain text), in the array WRAP
wrap() {
    local text=$1 w=$2 line="" word
    WRAP=()
    for word in $text; do
        if [ -z "$line" ]; then line=$word
        elif (( ${#line} + 1 + ${#word} <= w )); then line+=" $word"
        else WRAP+=("$line"); line=$word; fi
    done
    [ -n "$line" ] && WRAP+=("$line")
}
rule_of() { local n=$1 ch=${2:-─} out="" i; for (( i = 0; i < n; i++ )); do out+=$ch; done; printf '%s' "$out"; }

MONO_LOGO=(
" ███╗   ███╗ ██████╗ ███╗   ██╗ ██████╗ ██╗     ██╗████████╗██╗  ██╗"
" ████╗ ████║██╔═══██╗████╗  ██║██╔═══██╗██║     ██║╚══██╔══╝██║  ██║"
" ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║██║     ██║   ██║   ███████║"
" ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║██║     ██║   ██║   ██╔══██║"
" ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║╚██████╔╝███████╗██║   ██║   ██║  ██║"
" ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚═╝  ╚═╝"
)

# The panel: the lines in PL inside a rounded box, `title` in its top edge and `hint` in its
# bottom one, `w` wide, in the middle of the screen; the logo above it when there's room.
panel_draw() {
    local title=$1 hint=$2 w=$3 i
    term_size
    (( w > TC - 2 )) && w=$(( TC - 2 ))
    (( w < 40 )) && w=40
    local inner=$(( w - 4 )) h=$(( ${#PL[@]} + 2 ))
    local logo=false lw=${#MONO_LOGO[0]}
    (( TR >= h + 9 && TC >= lw + 2 )) && logo=true
    local total=$h; [ "$logo" = true ] && total=$(( h + 8 ))
    local top=$(( (TR - total) / 2 + 1 )); (( top < 1 )) && top=1
    local left=$(( (TC - w) / 2 + 1 )); (( left < 1 )) && left=1
    # the screen cleared only when the panel's size or place changed: redrawn over itself
    # otherwise (the install's panel is drawn several times a second), in one synchronised update
    local buf=$'\e[?2026h' key="$TR $TC $w $h $title"
    [ "$key" != "$PANEL_KEY" ] && buf+=$'\e[2J'
    PANEL_KEY=$key
    if [ "$logo" = true ]; then
        local ll=$(( (TC - lw) / 2 + 1 )) r=$top l
        for l in "${MONO_LOGO[@]}"; do
            grad_build "$l"; buf+=$'\e['"${r};${ll}H${BOLD}${GL}"; r=$(( r + 1 ))
        done
        local tag="really good desktop :3"
        buf+=$'\e['"$(( r + 1 ));$(( (TC - ${#tag}) / 2 + 1 ))H${DIM}${tag}${RESET}"
        top=$(( top + 8 ))
    fi
    # the top edge, with its title
    vlen "$title"
    local tl=$VL
    buf+=$'\e['"${top};${left}H${T_BORDER}╭─${RESET} ${BOLD}${T_ACC}${title}${RESET} ${T_BORDER}$(rule_of $(( w - tl - 5 )))╮${RESET}"
    for (( i = 0; i < ${#PL[@]}; i++ )); do
        fit "${PL[$i]}" "$inner"
        buf+=$'\e['"$(( top + 1 + i ));${left}H${T_BORDER}│${RESET} ${FT}${RESET} ${T_BORDER}│${RESET}"
    done
    # the bottom edge, with what the keys do
    vlen "$hint"
    local hl=$VL
    (( hl > w - 6 )) && { hint=""; hl=0; }
    buf+=$'\e['"$(( top + h - 1 ));${left}H${T_BORDER}╰$(rule_of $(( w - hl - 5 ))) ${RESET}${DIM}${hint}${RESET} ${T_BORDER}─╯${RESET}"
    printf '%s\e[?2026l' "$buf"
}

# --- a menu ----------------------------------------------------------------------------------
# Its rows, set by the screen that shows it:
#   MK  kind: head (a heading), item (a choice, its value on the right), btn (a button along the
#       bottom), text (a line of information), gap (an empty line)
#   ML  label   MV  value (items)   MD  what it does (shown under the menu for the one you're on)
#   MA  its action (what the menu returns in $MENU_PICK)
# menu_show TITLE WIDTH: draws it with MENU_CUR on, reads one key; the pick in MENU_PICK ("" if
# none yet), "exit" for q / Esc
menu_reset() { MK=(); ML=(); MV=(); MD=(); MA=(); }
menu_add() { MK+=("$1"); ML+=("$2"); MV+=("${3:-}"); MD+=("${4:-}"); MA+=("${5:-}"); }
MENU_CUR=0
menu_selectable() { MSEL=(); local i; for i in "${!MK[@]}"; do [[ "${MK[$i]}" == item || "${MK[$i]}" == btn ]] && MSEL+=("$i"); done; }
menu_show() {
    local title=$1 w=$2 i
    menu_selectable
    local n=${#MSEL[@]}
    (( MENU_CUR >= n )) && MENU_CUR=$(( n - 1 ))
    (( MENU_CUR < 0 )) && MENU_CUR=0
    local on=${MSEL[$MENU_CUR]}
    term_size
    (( w > TC - 2 )) && w=$(( TC - 2 ))
    local inner=$(( w - 4 ))
    PL=()
    local btns="" btnw=0
    for i in "${!MK[@]}"; do
        case "${MK[$i]}" in
            gap) PL+=("") ;;
            text) PL+=("${DIM}${ML[$i]}${RESET}") ;;
            line) PL+=("${ML[$i]}") ;;
            head) PL+=("${BOLD}${T_HEAD}${ML[$i]}${RESET}") ;;
            item)
                local left="  ${ML[$i]}" right="${MV[$i]}"
                [ "$i" = "$on" ] && left=" ${T_ACC}▌${RESET}${T_SEL}${BOLD}${ML[$i]}"
                vlen "$left"; local a=$VL; vlen "$right"; local b=$VL
                local gapw=$(( inner - a - b - 2 )); (( gapw < 1 )) && gapw=1
                local line
                printf -v line '%s%*s%s  ' "$left" "$gapw" '' "$right"
                if [ "$i" = "$on" ]; then
                    # (the highlight under the whole row: every colour reset in it puts it back)
                    line="${line//$RESET/$RESET$T_SEL}"
                    fit "$line" "$inner"
                    PL+=("${T_SEL}${FT}${RESET}")
                else
                    PL+=("$line")
                fi ;;
            btn)
                local b
                if [ "$i" = "$on" ]; then b="${T_SEL}${BOLD}${T_ACC} ${ML[$i]} ${RESET}"
                else b="${T_BTN} ${ML[$i]} ${RESET}"; fi
                btns+="$b   "; btnw=$(( btnw + ${#ML[$i]} + 5 )) ;;
        esac
    done
    if [ -n "$btns" ]; then
        PL+=("")
        local pad=$(( (inner - btnw + 3) / 2 )); (( pad < 0 )) && pad=0
        PL+=("$(printf '%*s' "$pad" '')${btns}")
    fi
    # what the one you're on does
    PL+=("" "${T_BORDER}$(rule_of "$inner")${RESET}")
    wrap "${MD[$on]}" "$inner"
    local k
    for k in 0 1 2; do PL+=("${T_ACC2}${WRAP[$k]:-}${RESET}"); done
    panel_draw "$title" "↑↓ move   ⏎ choose   q quit" "$w"

    MENU_PICK=""
    local key
    key=$(read_key)
    case "$key" in
        UP|[kK]) MENU_CUR=$(( (MENU_CUR - 1 + n) % n )) ;;
        DOWN|[jJ]) MENU_CUR=$(( (MENU_CUR + 1) % n )) ;;
        LEFT|[hH]) [ "${MK[$on]}" = btn ] && MENU_CUR=$(( (MENU_CUR - 1 + n) % n )) ;;
        RIGHT|[lL]) [ "${MK[$on]}" = btn ] && MENU_CUR=$(( (MENU_CUR + 1) % n )) ;;
        [1-9]) (( key <= n )) && { MENU_CUR=$(( key - 1 )); MENU_PICK="${MA[${MSEL[$MENU_CUR]}]}"; } ;;
        ENTER|SPACE) MENU_PICK="${MA[$on]}" ;;
        ESC|[qQ]) MENU_PICK="exit" ;;
    esac
}
# how a choice's value looks: on (green), off (dim), or a word in the accent
v_on() { [ "$1" = true ] && printf '%s● On%s' "$T_ON" "$RESET" || printf '%s○ Off%s' "$DIM" "$RESET"; }
v_word() { printf '%s%s%s' "$T_ACC2" "$1" "$RESET"; }

read_key() {
    local key=""
    local rest=""
    # (waiting half a second at a time: a terminal made bigger or smaller meanwhile gives RESIZE,
    # and the menu is drawn again in its middle; it stayed where it was until a key was pressed)
    local size0 size1 rc
    size0=$(stty size 2>/dev/null </dev/tty)
    while true; do
        IFS= read -rsn1 -t 0.5 key 2>/dev/null; rc=$?
        [ "$rc" -eq 0 ] && break
        # no more input (closed stdin): behave like Esc so menus exit instead of spinning
        [ "$rc" -le 128 ] && { echo "ESC"; return; }
        size1=$(stty size 2>/dev/null </dev/tty)
        [ "$size1" != "$size0" ] && { echo "RESIZE"; return; }
    done
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

# the login screen: Monolith's SDDM theme, the display manager that's there now, Wayland or X11
manage_sddm_menu() {
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

    local keep_cur=$MENU_CUR
    MENU_CUR=0
    while true; do
        menu_reset
        if [ -n "$current_dm" ]; then menu_add text "You log in with $current_dm now."
        else menu_add text "No login screen (display manager) is set up now."; fi
        menu_add gap
        menu_add item "Monolith's login screen" "$(v_on "$OPT_SDDM")" \
            "SDDM with Monolith's theme: your wallpaper and colours, a clock, your picture. The login screen you see when the PC starts." sddm
        if [ -n "$current_dm" ] && [ "$current_dm" != "sddm" ]; then
            menu_add item "Turn off $current_dm" "$([ "$REPLACE_DM" = true ] && v_word Yes || printf '%sNo%s' "$DIM" "$RESET")" \
                "Only one login screen can run: $current_dm is switched off so Monolith's can start instead." rdm
        fi
        menu_add item "Login screen runs on" "$([ "$SDDM_WAYLAND" = true ] && v_word Wayland || v_word X11)" \
            "Wayland is newer and smoother; X11 works on more graphics drivers. If the login screen stays black, pick X11." way
        menu_add btn "Done" "" "Back to the main menu." done
        menu_show "Login screen" 76
        case "$MENU_PICK" in
            sddm)
                OPT_SDDM=$([ "$OPT_SDDM" = true ] && echo false || echo true)
                if [ "$OPT_SDDM" = true ] && [ -n "$current_dm" ] && [ "$current_dm" != "sddm" ]; then
                    REPLACE_DM=true
                fi ;;
            rdm) REPLACE_DM=$([ "$REPLACE_DM" = true ] && echo false || echo true) ;;
            way) SDDM_WAYLAND=$([ "$SDDM_WAYLAND" = true ] && echo false || echo true) ;;
            done|exit) break ;;
        esac
    done
    MENU_CUR=$keep_cur
}

draw_banner() { :; }   # (the logo is drawn above the panel now)

# The packages Monolith wants, and how each is installed: a ▶ on the one you're on (↑/↓), ←/→
# to change it. Gentoo: Compile, Binary (Gentoo's prebuilt package when its version and USE
# match, else compiled) or Off; elsewhere Install or Off (the packages there come prebuilt).
# Off: Monolith doesn't install it (one it needs can't be turned off). c / b / x set the one
# you're on, C / B / X all of them. Kept in ~/.config/monolith/package-picks (deps.sh).
show_package_overview() {
    local names=()
    mapfile -t names < <(all_target_packages "$PROJECT_ROOT" | awk '!seen[$0]++')
    local missing_raw
    missing_raw=$(pm_missing_pkgs "${names[@]}")
    declare -A is_missing
    while IFS= read -r p; do
        [[ -n "$p" ]] && is_missing["$p"]=1
    done <<< "$missing_raw"
    # still to install first, then the rest
    local list=() p
    for p in "${names[@]}"; do [[ -n "${is_missing[$p]}" ]] && list+=("$p"); done
    for p in "${names[@]}"; do [[ -z "${is_missing[$p]}" ]] && list+=("$p"); done

    # Gentoo: which of them it prebuilds at all (its binhost index); the rest can only compile (°)
    declare -A has_bin=()
    local bin_known=false
    if [ "$PM_NAME" = portage ] && declare -f pm_binary_pkgs >/dev/null; then
        PL=("" "${DIM}Checking which packages Gentoo prebuilds…${RESET}" "")
        panel_draw "Packages" "" 64
        local got=()
        mapfile -t got < <(pm_binary_pkgs "${list[@]}")
        if [ ${#got[@]} -gt 0 ]; then
            bin_known=true
            for p in "${got[@]}"; do has_bin["$p"]=1; done
        fi
    fi
    no_bin() { $bin_known && [ -z "${has_bin[$1]}" ]; }

    local modes labels
    if [ "$PM_NAME" = portage ]; then modes=(c b x); labels=(Compile Binary Off)
    else modes=(c x); labels=(Install Off); fi
    local mcolor=("$T_ON" "$T_ACC2" "$C_RED")
    [ "$PM_NAME" = portage ] || mcolor=("$T_ON" "$C_RED")

    local total=${#list[@]} cur=0 top=0 msg="" i j k
    set_pick() {   # set_pick name mode
        if pkg_needed "$1"; then
            msg="$1 is important: the shell needs it to start, so it's always installed$([ "$PM_NAME" = portage ] && echo ", as a binary")"
            return
        fi
        if [ "$2" = b ] && no_bin "$1"; then msg="Gentoo doesn't prebuild $1: it's compiled"; PKG_PICK["$1"]=c; return; fi
        PKG_PICK["$1"]="$2"
    }
    while true; do
        term_size
        local page=$(( TR - 12 )); (( page < 3 )) && page=3
        (( cur < 0 )) && cur=0; (( cur >= total )) && cur=$(( total - 1 ))
        (( cur < top )) && top=$cur
        (( cur >= top + page )) && top=$(( cur - page + 1 ))
        # the counts
        local nc=0 nb=0 nx=0 n_missing=0 m
        for p in "${list[@]}"; do
            pick_of_r "$p"; m=$REPLY; [ "$m" = b ] && no_bin "$p" && m=c
            case $m in c) ((++nc)) ;; b) ((++nb)) ;; x) ((++nx)) ;; esac
            [[ -n "${is_missing[$p]}" ]] && ((++n_missing))
        done
        PL=()
        local counts
        if [ "$PM_NAME" = portage ]; then
            counts="${T_ON}${nc} compile${RESET} · ${T_ACC2}${nb} binary${RESET} · ${C_RED}${nx} off${RESET}"
            PL+=("${BOLD}${total} packages${RESET}: ${C_YELLOW}${n_missing} to install${RESET}, $(( total - n_missing )) installed     ${counts}")
            PL+=("${DIM}Binary: Gentoo's prebuilt package when version and USE match, else compiled. ° not prebuilt.${RESET}")
        else
            counts="${T_ON}${nc} install${RESET} · ${C_RED}${nx} off${RESET}"
            PL+=("${BOLD}${total} packages${RESET}: ${C_YELLOW}${n_missing} to install${RESET}, $(( total - n_missing )) installed     ${counts}")
            PL+=("${DIM}Off: Monolith doesn't install it (what it needs can't be off).${RESET}")
        fi
        PL+=("")
        for (( i = top; i < top + page && i < total; i++ )); do
            p=${list[$i]}
            pick_of_r "$p"; m=$REPLY
            local mark="  " st name opts=""
            [ "$i" -eq "$cur" ] && mark="${BOLD}${T_ACC}▶${RESET} "
            if [[ -n "${is_missing[$p]}" ]]; then st="${C_YELLOW}to install${RESET}"; else st="${DIM}installed ${RESET}"; fi
            name="$p"; no_bin "$p" && name="$name°"
            # (one Gentoo doesn't prebuild, saved as Binary before: it's compiled)
            no_bin "$p" && [ "$m" = b ] && m=c
            if pkg_needed "$p"; then
                # important: fixed (binary on Gentoo; one Gentoo doesn't prebuild compiles on binaries)
                if [ "$PM_NAME" = portage ]; then
                    no_bin "$p" && opts=" ${BOLD}${T_ON}[Compile]${RESET} ${DIM}on binaries${RESET}" || opts=" ${BOLD}${T_ACC2}[Binary]${RESET}"
                else
                    opts=" ${BOLD}${T_ON}[Install]${RESET}"
                fi
                opts+="  ${C_YELLOW}important${RESET}"
            fi
            pkg_needed "$p" || for k in "${!modes[@]}"; do
                if [ "${modes[$k]}" = b ] && no_bin "$p"; then
                    opts+=" ${DIM} ------ ${RESET}"
                elif [ "${modes[$k]}" = "$m" ]; then
                    opts+=" ${BOLD}${mcolor[$k]}[${labels[$k]}]${RESET}"
                else
                    opts+=" ${DIM} ${labels[$k]} ${RESET}"
                fi
            done
            local nm; fit "$name" 28; nm=$FT
            if [ "$i" -eq "$cur" ]; then
                PL+=("${mark}${st}  ${BOLD}${nm}${RESET}${opts}")
            else
                PL+=("${mark}${st}  ${nm}${opts}")
            fi
        done
        PL+=("")
        if [ -n "$msg" ]; then PL+=("${C_YELLOW}${msg}${RESET}")
        else PL+=("${DIM}$(( cur + 1 ))/${total}   ←/→ how it's installed   $([ "$PM_NAME" = portage ] && echo "c/b/x" || echo "c/x") this one, $([ "$PM_NAME" = portage ] && echo "C/B/X" || echo "C/X") all${RESET}"); fi
        msg=""
        panel_draw "Packages" "↑↓ package   ←→ change   ⏎ back" 104
        local key; key=$(read_key)
        p=${list[$cur]}
        pick_of_r "$p"; m=$REPLY
        local idx=0
        for k in "${!modes[@]}"; do [ "${modes[$k]}" = "$m" ] && idx=$k; done
        case "$key" in
            UP|[kK]) cur=$(( cur - 1 )) ;;
            DOWN|[jJ]) cur=$(( cur + 1 )) ;;
            SPACE) cur=$(( cur + page )) ;;
            RIGHT|[lL]|LEFT|[hH])
                local step=1; [[ "$key" == LEFT || "$key" == [hH] ]] && step=$(( ${#modes[@]} - 1 ))
                local nxt=$(( (idx + step) % ${#modes[@]} ))
                # (no Binary on what Gentoo doesn't prebuild: straight past it)
                [ "${modes[$nxt]}" = b ] && no_bin "$p" && nxt=$(( (nxt + step) % ${#modes[@]} ))
                set_pick "$p" "${modes[$nxt]}" ;;
            c) set_pick "$p" c ;;
            b) [ "$PM_NAME" = portage ] && set_pick "$p" b ;;
            x) set_pick "$p" x ;;
            C|B|X)
                local want=${key,,}
                [ "$want" = b ] && [ "$PM_NAME" != portage ] && continue
                local skipped=0
                for p in "${list[@]}"; do
                    pkg_needed "$p" && continue
                    if [ "$want" = b ] && no_bin "$p"; then PKG_PICK["$p"]=c; skipped=$((skipped + 1)); continue; fi
                    PKG_PICK["$p"]="$want"
                done
                [ "$want" = x ] && msg="all off but what Monolith needs"
                [ "$want" = b ] && [ "$skipped" -gt 0 ] && msg="$skipped Gentoo doesn't prebuild (°) stay Compile; the binaries' dependencies come prebuilt too" ;;
            g) cur=0 ;;
            G) cur=$(( total - 1 )) ;;
            ESC|[qQ]|ENTER) break ;;
        esac
    done
    picks_save
}

on_off() { [ "$1" = true ] && printf "%s[ON]%s" "$C_GREEN" "$RESET" || printf "%s[OFF]%s" "$DIM" "$RESET"; }

# The main menu: what Monolith sets up, in groups, each choice's value on the right and what it
# does under the menu; Install (or Update / Reinstall) and Exit along the bottom
run_installer_ui() {
    tui_begin
    MENU_CUR=0
    local cpu=${CPU_INFO// Processor/} gpu=${GPU_INFO#Advanced Micro Devices, Inc. }
    while true; do
        menu_reset
        local ver="Monolith $TARGET_VERSION ($TARGET_COMMIT)"
        [ -n "$OLD_VERSION" ] && ver+="   installed: $OLD_VERSION"
        menu_add text "$ver"
        menu_add text "$USER_NAME · $OS_NAME · $cpu"
        menu_add gap

        menu_add head "Setup"
        menu_add item "Desktop" "$([ "$DESKTOP" = hyprland ] && v_word Hyprland || v_word niri)" \
            "$([ "$DESKTOP" = hyprland ] && echo "Monolith runs as Hyprland's shell (your Hyprland config is backed up first). Enter switches to niri." || echo "Monolith on niri: a scrolling desktop with Monolith's own keybinds and layout. Enter switches to Hyprland.")" desktop
        if [ "$DESKTOP" = hyprland ]; then
            menu_add item "Keybinds" "$([ "$HYPR_KEYS" = monolith ] && v_word "Monolith's" || v_word "Keep mine")" \
                "$([ "$HYPR_KEYS" = monolith ] && echo "Monolith's keys, the same as on niri (your other Hyprland keys are turned off)." || echo "Your own Hyprland keybinds stay as they are.")" hyprkeys
        else
            menu_add item "niri config" "$([ "$NIRI_MODE" = replace ] && v_word "Monolith's" || v_word "Keep mine")" \
                "$([ "$NIRI_MODE" = replace ] && echo "Monolith's keybinds, screens and workspaces for niri. Your config is backed up first." || echo "Your niri config stays; Monolith only adds what it needs.")" niri
        fi
        menu_add item "Packages" "$(v_word "Choose…")" \
            "What Monolith installs, and how: $([ "$PM_NAME" = portage ] && echo "compiled, as Gentoo's binary, or not at all" || echo "installed or not"), one by one." packages

        menu_add gap
        menu_add head "Extras"
        menu_add item "Apps for the keybinds" "$(v_on "$OPT_KEYBIND_APPS")" \
            "kitty, LibreWolf, Thunar and Mission Center: the terminal, browser, files and task manager the keybinds open." keybind_apps
        menu_add item "Login screen" "$(v_on "$OPT_SDDM")" \
            "Monolith's login screen (SDDM), with your wallpaper and colours. Enter for its options." sddm
        local wp
        case "$WALLPAPERS" in full) wp="Full pack" ;; random) wp="3 + 1 live" ;; *) wp="None" ;; esac
        menu_add item "Wallpapers" "$(v_word "$wp")" \
            "3 random wallpapers and a live one, the full pack (about 1.1 GB with the live ones), or none. Enter goes through them." wallpapers
        if [ -n "${OTHER_SHELLS_FOUND:-}" ]; then
            menu_add item "Other shells ($OTHER_SHELLS_FOUND)" "$([ "$OPT_REPLACE_SHELLS" = true ] && v_word Remove || v_word Keep)" \
                "$([ "$OPT_REPLACE_SHELLS" = true ] && echo "Uninstalled, their files backed up, their keybinds become Monolith's." || echo "They stay installed, kept out of Monolith's sessions.")" replace
        fi

        menu_add gap
        menu_add head "Rebuilds (take a while)"
        menu_add item "HDMI scaling for TVs" "$(v_on "$OPT_HDMI")" \
            "For a TV that cuts off the edges of the picture: rebuilds $(hdmi_target) with Monolith's patch, then Settings → Displays can shrink the picture to fit." hdmi
        if [ "$DESKTOP" != hyprland ]; then
            menu_add item "niri extras" "$(v_on "$OPT_NIRI_EXTRAS")" \
                "Minimise buttons, windows tiled when dragged to a screen's edge, and drawn on both screens while dragged across: rebuilds niri with Monolith's patches." niriextras
        fi

        if [ "$INSTALL_STATE" = current ]; then
            menu_add btn "Update" "" "Bring Monolith up to date, keeping your settings." install
            menu_add btn "Reinstall" "" "Install again from scratch, with fresh settings (yours are backed up)." reinstall
        else
            menu_add btn "Install" "" "Install Monolith with these choices." install
        fi
        menu_add btn "Exit" "" "Leave without changing anything." exit

        menu_show "Monolith installer" 84
        case "$MENU_PICK" in
            "") ;;
            desktop) DESKTOP=$([ "$DESKTOP" = hyprland ] && echo niri || echo hyprland) ;;
            hyprkeys) HYPR_KEYS=$([ "$HYPR_KEYS" = monolith ] && echo mine || echo monolith) ;;
            hdmi) OPT_HDMI=$([ "$OPT_HDMI" = true ] && echo false || echo true) ;;
            niriextras) OPT_NIRI_EXTRAS=$([ "$OPT_NIRI_EXTRAS" = true ] && echo false || echo true) ;;
            replace) OPT_REPLACE_SHELLS=$([ "$OPT_REPLACE_SHELLS" = true ] && echo false || echo true) ;;
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

# --- the install, in the panel ---------------------------------------------------------------
# While it installs: a bar, the steps (✓ done and how long it took, a spinner on the one it's
# on, ○ still to come) and the last lines of what it's doing, drawn by a little loop of its own
# (progress_loop) several times a second. Everything the install prints goes to $PROG_LOG; if it
# stops halfway, cleanup_terminal shows that log's last lines. Plain output instead (step's own
# bars) with no terminal, MONOLITH_PLAIN=1, or a sudo that asks every time (a password asked for
# behind the panel couldn't be seen).
PROG_ON=false
PROG_LOG="${PROG_LOG:-$HOME/.cache/monolith/install.log}"
STEP_PLAN=()        # the steps it will take (install.sh), for the list
STEP_DONE=()        # the ones it's been through, in order (the last is the one it's on)
STEP_TIMES=()       # when each started
STEP_N=0
STEP_TOTAL=${STEP_TOTAL:-0}

tui_ok() { [ -t 0 ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${MONOLITH_PLAIN:-}" ]; }
now_s() { printf -v NOW '%(%s)T' -1; }
mmss() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }

# the log's last lines, readable: progress bars' carriage returns as new lines, colours and other
# terminal codes taken out, empty lines left out
log_tail() {
    tail -c 24000 "$PROG_LOG" 2>/dev/null | tr '\r\t' '\n ' \
        | LC_ALL=C sed -e 's/\x1b\[[0-9;?<=>]*[ -\/]*[@-~]//g' -e 's/\x1b.//g' -e 's/[[:cntrl:]]//g' \
        | grep -v '^[[:space:]]*$' | tail -n "$1"
}

# the steps, for the loop that draws them: "d name seconds", "c name started", "p name"
steps_write() {
    local i n=${#STEP_DONE[@]} out="" p seen
    for (( i = 0; i < n; i++ )); do
        if (( i < n - 1 )); then out+="d ${STEP_TIMES[$((i + 1))]} $(( STEP_TIMES[i + 1] - STEP_TIMES[i] )) ${STEP_DONE[$i]}"$'\n'
        else out+="c ${STEP_TIMES[$i]} 0 ${STEP_DONE[$i]}"$'\n'; fi
    done
    for p in "${STEP_PLAN[@]}"; do
        seen=false
        for (( i = 0; i < n; i++ )); do [ "${STEP_DONE[$i]}" = "$p" ] && seen=true; done
        [ "$seen" = false ] && out+="p 0 0 $p"$'\n'
    done
    printf '%s' "$out" > "$PROG_DIR/steps.new" && mv -f "$PROG_DIR/steps.new" "$PROG_DIR/steps"
}

progress_begin() {   # progress_begin TITLE
    tui_ok || return 0
    if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && ! sudo -n true 2>/dev/null; then return 0; fi
    mkdir -p "${PROG_LOG%/*}" && : > "$PROG_LOG" || return 0
    PROG_DIR=$(mktemp -d 2>/dev/null) || return 0
    PROG_TITLE=$1
    now_s; PROG_T0=$NOW
    : > "$PROG_DIR/steps"
    tui_begin
    exec 3>&1 4>&2 >>"$PROG_LOG" 2>&1
    PROG_ON=true
    ( trap - EXIT INT TERM; progress_loop ) >&3 2>/dev/null &
    PROG_PID=$!
}
progress_end() {
    [ "$PROG_ON" = true ] || return 0
    PROG_ON=false
    kill "$PROG_PID" 2>/dev/null; wait "$PROG_PID" 2>/dev/null
    exec 1>&3 2>&4 3>&- 4>&-
    rm -rf "$PROG_DIR"
}

progress_loop() {
    local f=0 spin=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    while true; do
        progress_frame "${spin[$(( f % 10 ))]}"
        f=$(( f + 1 ))
        sleep 0.12
    done
}
progress_frame() {
    local sp=$1 rows=() r st t0 dur name i d=0 cur=0 n
    mapfile -t rows < "$PROG_DIR/steps" 2>/dev/null
    n=${#rows[@]}; (( n < 1 )) && n=1
    for r in "${rows[@]}"; do case ${r:0:1} in d) d=$(( d + 1 )) ;; c) cur=1 ;; esac; done
    now_s
    term_size
    local w=84; (( w > TC - 2 )) && w=$(( TC - 2 ))
    local inner=$(( w - 4 ))
    # the bar: half a step for the one it's on
    local right; right="  $d of $n   $(mmss $(( NOW - PROG_T0 )))"
    local bw=$(( inner - ${#right} )) fill line="" k
    (( bw < 10 )) && bw=10
    fill=$(( (2 * d + cur) * bw / (2 * n) ))
    for (( k = 0; k < bw; k++ )); do
        if (( k < fill )); then grad_set "$k" "$bw"; line+="$GA━"; else line+="${RESET}${DIM}─"; fi
    done
    PL=("${line}${RESET}${DIM}${right}${RESET}" "")
    for r in "${rows[@]}"; do
        read -r st t0 dur name <<<"$r"
        local left rt=""
        case $st in
            d) left="  ${T_ON}✓${RESET} ${name}"; rt="${DIM}$(mmss "$dur")${RESET}" ;;
            c) left="  ${BOLD}${T_ACC}${sp}${RESET} ${BOLD}${name}${RESET}"; rt="${T_ACC2}$(mmss $(( NOW - t0 )))${RESET}" ;;
            *) left="  ${DIM}○ ${name}${RESET}" ;;
        esac
        vlen "$left"; local a=$VL; vlen "$rt"
        printf -v line '%s%*s%s' "$left" $(( inner - a - VL - 1 )) '' "$rt"
        PL+=("$line")
    done
    # what it's doing: as many of the log's last lines as fit (room left for the logo when it can)
    local base=$(( ${#PL[@]} + 4 )) nl
    nl=$(( TR - base - 10 )); (( nl < 5 )) && nl=$(( TR - base - 1 ))
    (( nl > 12 )) && nl=12; (( nl < 2 )) && nl=2
    PL+=("" "${T_BORDER}$(rule_of "$inner")${RESET}")
    local logs=()
    mapfile -t logs < <(log_tail "$nl")
    for (( i = 0; i < nl; i++ )); do PL+=("${DIM}${logs[$i]:-}${RESET}"); done
    panel_draw "$PROG_TITLE" "log: ${PROG_LOG/#$HOME/\~}" "$w"
}

# each install step: in the panel, the list moves on; plain, "3/7", a bar that fills up to it
# (animated from the last one) and its name
step() {
    STEP_N=$(( STEP_N + 1 ))
    local total=$STEP_TOTAL; [ "$total" -lt "$STEP_N" ] && total=$STEP_N
    if [ "$PROG_ON" = true ]; then
        now_s
        STEP_DONE+=("$1"); STEP_TIMES+=("$NOW")
        steps_write
        printf '\n==> %s\n' "$1"
        return 0
    fi
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

# a panel printed where the text is (the plain finish screen), in the middle across: the lines in PL
panel_inline() {
    local title=$1 w=$2 i
    term_size
    (( w > TC - 2 )) && w=$(( TC - 2 ))
    local inner=$(( w - 4 )) margin=$(( (TC - w) / 2 )); (( margin < 0 )) && margin=0
    local m; printf -v m '%*s' "$margin" ''
    vlen "$title"
    printf '%s%s╭─%s %s%s%s%s %s%s╮%s\n' "$m" "$T_BORDER" "$RESET" "$BOLD" "$T_ACC" "$title" "$RESET" "$T_BORDER" "$(rule_of $(( w - VL - 5 )))" "$RESET"
    for (( i = 0; i < ${#PL[@]}; i++ )); do
        fit "${PL[$i]}" "$inner"
        printf '%s%s│%s %s%s %s│%s\n' "$m" "$T_BORDER" "$RESET" "$FT" "$RESET" "$T_BORDER" "$RESET"
    done
    printf '%s%s╰%s╯%s\n' "$m" "$T_BORDER" "$(rule_of $(( w - 2 )))" "$RESET"
    INLINE_MARGIN=$m
}

# what the finish screen says, in DONE_LINES (formatted lines; the messages wrapped to `inner`)
completion_lines() {
    local inner=$1 line k
    DONE_LINES=("")
    if [ "$UPDATE_ONLY" = true ]; then grad_build "Monolith is up to date: $TARGET_VERSION ($TARGET_COMMIT)."
    else grad_build "Monolith $TARGET_VERSION ($TARGET_COMMIT) is installed."; fi
    DONE_LINES+=("${BOLD}${GL}" "${DIM}really good desktop :3${RESET}" "")
    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        DONE_LINES+=("${BOLD}${C_RED}These packages failed to install:${RESET}")
        for k in "${FAILED_PKGS[@]}"; do DONE_LINES+=("  ${C_YELLOW}• ${k}${RESET}"); done
        DONE_LINES+=("")
    fi
    local msgs=()
    if [ "$UPDATE_ONLY" = true ]; then
        msgs+=("A restart makes sure everything (keybinds, login screen, services) uses the new version.")
    elif [ "$DESKTOP" = hyprland ] && [ "$MONOLITH_STARTED" = true ]; then
        msgs+=("Monolith is running again on Hyprland, updated."
               "Your keys are in the welcome tour (monolith welcome). \`monolith hyprland off\` puts your old config back.")
    elif [ "$DESKTOP" = hyprland ]; then
        msgs+=("Log out of Hyprland and back in: Monolith starts there instead of your old shell."
               "Your keys are in the welcome tour (monolith welcome). \`monolith hyprland off\` undoes the switch.")
    elif [ "$MONOLITH_STARTED" = true ]; then
        msgs+=("Monolith is running now. Next time you log in, pick niri for Monolith's keybinds and layout."
               "Super+Space opens the hub: search, settings and everything else.")
    else
        msgs+=("Log in to niri and Monolith starts by itself."
               "Super+Space opens the hub: search, settings and everything else.")
    fi
    # niri chosen, Hyprland here too
    if [ "$UPDATE_ONLY" != true ] && [ "$DESKTOP" != hyprland ] && hypr_present && ! hypr_switched; then
        msgs+=("To use Monolith on Hyprland too: \`monolith hyprland on\` (backs up ~/.config/hypr first).")
    fi
    [ "$UPDATE_ONLY" = true ] || msgs+=("Run \`monolith installer\` any time to update or change these choices.")
    for line in "${msgs[@]}"; do
        wrap "$line" "$inner"
        for k in "${WRAP[@]}"; do DONE_LINES+=("$k"); done
        DONE_LINES+=("")
    done
}

do_reboot() { systemctl reboot 2>/dev/null || loginctl reboot 2>/dev/null || sudo reboot; }

# The finish screen: in the panel (Later / Restart now) after the install ran in it, else printed
draw_completion_screen() {
    local w=84
    if [ "$TUI_ON" = true ]; then
        term_size
        (( w > TC - 2 )) && w=$(( TC - 2 ))
        completion_lines $(( w - 4 ))
        # (keys pressed while it installed thrown away: a stray Enter mustn't restart the PC)
        while read -rsn1 -t 0.05 _ 2>/dev/null; do :; done
        MENU_CUR=0
        local pick="" l
        while true; do
            menu_reset
            for l in "${DONE_LINES[@]}"; do menu_add line "$l"; done
            menu_add btn "Later" "" "Close the installer and keep going; restart whenever you like." later
            menu_add btn "Restart now" "" "Restart the computer now, so everything starts with the new version." reboot
            menu_show "$([ "$UPDATE_ONLY" = true ] && echo Updated || echo Done)" "$w"
            case "$MENU_PICK" in later|exit|reboot) pick=$MENU_PICK; break ;; esac
        done
        cleanup_terminal
        if [ "$UPDATE_ONLY" = true ]; then
            printf '%s%sMonolith is up to date (%s).%s\n' "$BOLD" "$C_GREEN" "$TARGET_VERSION" "$RESET"
        else
            printf '%s%sMonolith %s is installed.%s\n' "$BOLD" "$C_GREEN" "$TARGET_VERSION" "$RESET"
        fi
        [ ${#FAILED_PKGS[@]} -gt 0 ] && printf '%sThese packages failed to install: %s%s\n' "$C_RED" "${FAILED_PKGS[*]}" "$RESET"
        printf '%sWhat the install printed: %s%s\n' "$DIM" "$PROG_LOG" "$RESET"
        if [ "$pick" = reboot ]; then do_reboot
        elif [ "$UPDATE_ONLY" = true ] && command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Monolith" "Monolith updated to $TARGET_VERSION" "Restart later so keybinds, login screen and services pick it up." 2>/dev/null || true
        fi
        return 0
    fi

    cleanup_terminal
    printf "\n"
    term_size
    (( w > TC - 2 )) && w=$(( TC - 2 ))
    completion_lines $(( w - 4 ))
    PL=("${DONE_LINES[@]}")
    panel_inline "Done" "$w"
    printf "\n"
    local choice=""
    if [ -t 0 ]; then
        read -r -p "${INLINE_MARGIN}  Restart your computer now? [y/N] " choice
    elif [ -e /dev/tty ]; then
        { read -r -p "${INLINE_MARGIN}  Restart your computer now? [y/N] " choice; } 2>/dev/null < /dev/tty
    fi
    [[ "$choice" =~ ^[Yy]$ ]] && do_reboot
    return 0
}
