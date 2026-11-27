#!/usr/bin/env bash
# niri, rebuilt with Monolith's patches (monolith/patches), every one wanted in one build (a
# rebuild with only some lost the others):
#   niri extras (asked for in the menu):
#     niri-minimize.patch              minimise buttons: niri says it can minimise and passes a
#                                      window's request to the shell (Desktop mode minimises it)
#     niri-move-across-monitors.patch  a window being dragged is drawn on every screen it reaches
#     niri-drag-edges.patch            a floating window dragged to a screen's edge or corner: niri
#                                      says which (WindowDragEdge), Desktop mode tiles it there
#     niri-move-shrink.patch           a floating window shrinks a little while dragged and grows
#                                      back as it's let go (KDE's feel; after move-across-monitors)
#   HDMI scaling (modules/hdmi.sh), on niri:
#     niri-underscan.patch
#   Gentoo: the patches go in Portage's user patches for the installed version and niri is emerged
#           again (it stays patched across rebuilds of that version)
#   Arch:   Arch's own PKGBUILD for the installed version with the patches added, built with
#           makepkg and installed over it (hdmi.sh: _arch_patched_build)
# Remembered ($NIRI_EXTRAS_STATE_FILE), and an update patches niri again when an upgrade replaced
# it. Patches that don't fit a new version are left out (niri stays as it is).

NIRI_EXTRAS_STATE_FILE="$HOME/.local/state/monolith/niri-extras"
NIRI_EXTRA_PATCHES=(niri-minimize.patch niri-move-across-monitors.patch niri-drag-edges.patch niri-move-shrink.patch)
# and xwayland-satellite (X11 apps on niri), with the extras: an X11 app's own maximise and minimise
# buttons (Steam's) did nothing, satellite passing on only fullscreen
SATELLITE_PATCHES=(xwayland-satellite-wm-buttons.patch)
satellite_patched() {
    local f
    f="$(command -v xwayland-satellite 2>/dev/null)"
    [ -z "$f" ] || grep -aq "WM_CHANGE_STATE" "$f" 2>/dev/null
}

niri_extras_wanted() { [ "$(cat "$NIRI_EXTRAS_STATE_FILE" 2>/dev/null)" = on ]; }
# the installed niri has them all (their events' names are in it: one built with only the older
# extras is patched again)
niri_extras_patched() {
    local f
    f="$(command -v niri 2>/dev/null)"
    [ -n "$f" ] && grep -q "WindowMinimizeRequested" "$f" 2>/dev/null && grep -q "WindowDragEdge" "$f" 2>/dev/null \
        && grep -q "monolith drag shrink v2" "$f" 2>/dev/null
}
# HDMI scaling is one of niri's patches here (on Hyprland it's aquamarine's: hdmi.sh)
niri_hdmi_wanted() { [ "${OPT_HDMI:-false}" = true ] && [ "$(hdmi_target)" = niri ]; }
niri_patches_wanted() { [ "${OPT_NIRI_EXTRAS:-false}" = true ] || niri_hdmi_wanted; }
niri_all_patched() {
    { [ "${OPT_NIRI_EXTRAS:-false}" != true ] || { niri_extras_patched && satellite_patched; }; } && { ! niri_hdmi_wanted || hdmi_patched; }
}

install_niri_patches() {
    local root="$1" patches=() p missing=0
    mkdir -p "$(dirname "$NIRI_EXTRAS_STATE_FILE")"
    if [ "${OPT_NIRI_EXTRAS:-false}" = true ]; then echo on > "$NIRI_EXTRAS_STATE_FILE"; else echo off > "$NIRI_EXTRAS_STATE_FILE"; fi
    if niri_hdmi_wanted; then echo on > "$HDMI_STATE_FILE"; fi
    if niri_all_patched; then
        echo "  niri: has Monolith's patches already"
        return 0
    fi
    if [ "${OPT_NIRI_EXTRAS:-false}" = true ]; then
        for p in "${NIRI_EXTRA_PATCHES[@]}"; do patches+=("$root/monolith/patches/$p"); done
    fi
    niri_hdmi_wanted && patches+=("$root/monolith/patches/niri-underscan.patch")
    for p in "${patches[@]}"; do
        [ -f "$p" ] || { echo -e "  ${C_YELLOW}niri patches:${RESET} ${p##*/} is missing from this copy of Monolith"; missing=1; }
    done
    [ "$missing" = 0 ] || return 0
    # (niri only when it's missing some: the satellite can be the one left)
    if ! { { [ "${OPT_NIRI_EXTRAS:-false}" != true ] || niri_extras_patched; } && { ! niri_hdmi_wanted || hdmi_patched; }; }; then
        case "$PM_NAME" in
            portage) _niri_patches_gentoo "${patches[@]}" ;;
            pacman) _arch_patched_build niri "Monolith's niri patches" "${patches[@]}" ;;
            *) echo -e "  ${C_YELLOW}niri patches:${RESET} not available on this system yet"; return 0 ;;
        esac
    fi
    if [ "${OPT_NIRI_EXTRAS:-false}" = true ] && command -v xwayland-satellite >/dev/null && ! satellite_patched; then
        local sp=()
        for p in "${SATELLITE_PATCHES[@]}"; do [ -f "$root/monolith/patches/$p" ] && sp+=("$root/monolith/patches/$p"); done
        if [ ${#sp[@]} -gt 0 ]; then
            case "$PM_NAME" in
                portage) _gentoo_user_patch_build gui-apps/xwayland-satellite "xwayland-satellite patch" "${sp[@]}" ;;
                pacman) _arch_patched_build xwayland-satellite "Monolith's xwayland-satellite patch" "${sp[@]}" ;;
            esac
        fi
    fi
    if niri_all_patched; then
        echo "  niri: patched; ready after you log out and in again"
    else
        echo -e "  ${C_YELLOW}niri patches:${RESET} niri still isn't the patched one (a patch may not fit this niri version)"
    fi
    return 0
}

_niri_patches_gentoo() { _gentoo_user_patch_build gui-wm/niri "niri patches" "$@"; }

# Portage's user patches for the installed version of a package, and it emerged again (they stay
# for rebuilds of that version); ones that don't fit are taken out again
_gentoo_user_patch_build() {
    local atom="$1" what="$2"; shift 2
    local cat="${atom%/*}" pn="${atom#*/}" pkg ver dir p added=()
    pkg=$(ls -d /var/db/pkg/$cat/$pn-[0-9]* 2>/dev/null | tail -1)
    [ -n "$pkg" ] || { echo -e "  ${C_YELLOW}$what:${RESET} $pn isn't installed"; return 0; }
    ver="${pkg##*/$pn-}"; ver="${ver%-r[0-9]*}"
    dir="/etc/portage/patches/$cat/$pn-$ver"
    echo -e "\n\e[36m[ INFO ]\e[0m Building $pn $ver with Monolith's patches"
    sudo mkdir -p "$dir" || return 0
    for p in "$@"; do
        # (the same one there already, from by hand or before: left as it is)
        if ! sudo cmp -s "$p" "$dir/${p##*/}" 2>/dev/null; then
            sudo cp "$p" "$dir/${p##*/}" || return 0
            added+=("$dir/${p##*/}")
        fi
    done
    # (~: that version at any revision, the installed one being -r1 say)
    if ! sudo emerge --oneshot --ask=n "~$cat/$pn-$ver"; then
        # (patches that don't fit this version: the ones put there now taken out again)
        for p in "${added[@]}"; do sudo rm -f "$p"; done
        sudo rmdir "$dir" 2>/dev/null || true
        echo -e "  ${C_YELLOW}$what:${RESET} they don't fit $pn $ver; left as it was"
    fi
}
