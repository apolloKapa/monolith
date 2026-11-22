#!/usr/bin/env bash
# HDMI scaling (Settings → Displays → HDMI scaling): the GPU's underscan, so a TV that cuts the
# edges off can be given a border, as Windows' HDMI scaling does. Neither compositor sets it, so
# the one in use is rebuilt with Monolith's patch (monolith/patches):
#   Hyprland: its display library, aquamarine (aquamarine-underscan.patch)
#   niri:     niri itself (niri-underscan.patch)
# Both read the borders from ~/.config/aquamarine/underscan, which Settings writes.
#   Gentoo: the patch goes in Portage's user patches for the installed version, and the package
#           is emerged again (it stays patched across rebuilds of that version)
#   Arch:   Arch's own PKGBUILD for the installed version, with the patch added, built with makepkg
#           (its pkgrel gets a ".1", so the repo's same version doesn't replace it; a newer one
#           does, and the next Monolith update builds that one patched again)
# Asked for once in the installer's menu; remembered ($HDMI_STATE_FILE), and an update patches it
# again when an upgrade replaced it. A patch that doesn't fit a new version is left out (the
# package stays as it is) and Settings says HDMI scaling needs it.

HDMI_STATE_FILE="$HOME/.local/state/monolith/hdmi-scaling"

# what gets the patch on this desktop
hdmi_target() { [ "${DESKTOP:-niri}" = hyprland ] && echo aquamarine || echo niri; }

# the installed one is patched (it names the file it reads)
hdmi_patched() {
    local f
    if [ "$(hdmi_target)" = aquamarine ]; then
        for f in /usr/lib*/libaquamarine.so.* /usr/local/lib*/libaquamarine.so.*; do
            [ -f "$f" ] && [ ! -L "$f" ] && grep -q "aquamarine/underscan" "$f" 2>/dev/null && return 0
        done
        return 1
    fi
    f="$(command -v niri 2>/dev/null)"
    [ -n "$f" ] && grep -q "aquamarine/underscan" "$f" 2>/dev/null
}
hdmi_wanted() { [ "$(cat "$HDMI_STATE_FILE" 2>/dev/null)" = on ]; }

install_hdmi_scaling() {
    local root="$1" target
    target="$(hdmi_target)"
    local patch="$root/monolith/patches/$target-underscan.patch"
    mkdir -p "$(dirname "$HDMI_STATE_FILE")"
    echo on > "$HDMI_STATE_FILE"
    if hdmi_patched; then
        echo "  HDMI scaling: $target is patched already"
        return 0
    fi
    [ -f "$patch" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} the patch is missing from this copy of Monolith"; return 0; }
    case "$PM_NAME:$target" in
        portage:aquamarine) _hdmi_gentoo gui-libs aquamarine "$patch" ;;
        portage:niri) _hdmi_gentoo gui-wm niri "$patch" ;;
        pacman:*) _hdmi_arch "$target" "$patch" ;;
        *) echo -e "  ${C_YELLOW}HDMI scaling:${RESET} not available on this system yet" ;;
    esac
    hdmi_patched && echo -e "  HDMI scaling: ready after you log out and in again (Settings → Displays → HDMI scaling, on an HDMI screen)"
    return 0
}

_hdmi_gentoo() {
    local cat="$1" pn="$2" patch="$3" pkg ver dir
    pkg=$(ls -d /var/db/pkg/"$cat"/"$pn"-[0-9]* 2>/dev/null | tail -1)
    [ -n "$pkg" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} $pn isn't installed"; return 0; }
    ver="${pkg##*/$pn-}"
    dir="/etc/portage/patches/$cat/$pn-$ver"
    echo -e "\n\e[36m[ INFO ]\e[0m Building $pn $ver with HDMI scaling"
    sudo mkdir -p "$dir" && sudo cp "$patch" "$dir/${patch##*/}" || return 0
    if ! sudo emerge --oneshot --ask=n "=$cat/$pn-$ver"; then
        # (a patch that doesn't fit this version: taken out again, nothing else changed)
        sudo rm -f "$dir/${patch##*/}"
        sudo rmdir "$dir" 2>/dev/null || true
        echo -e "  ${C_YELLOW}HDMI scaling:${RESET} the patch doesn't fit $pn $ver; left as it was"
    fi
}

_hdmi_arch() {
    local pn="$1" patch="$2" ver build
    ver=$(pacman -Q "$pn" 2>/dev/null | awk '{print $2}')
    [ -n "$ver" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} $pn isn't installed"; return 0; }
    # (our own build of the same version: ".1" on the release; the repo's version, to match)
    ver="${ver%.1}"
    build="${XDG_CACHE_HOME:-"$HOME/.cache"}/monolith-$pn"
    rm -rf "$build"
    echo -e "\n\e[36m[ INFO ]\e[0m Building $pn $ver with HDMI scaling"
    # Arch's PKGBUILD for exactly that version (its tag), else the newest
    gitx clone -q --depth 1 --branch "$ver" "https://gitlab.archlinux.org/archlinux/packaging/packages/$pn.git" "$build" 2>/dev/null \
        || gitx clone -q --depth 1 "https://gitlab.archlinux.org/archlinux/packaging/packages/$pn.git" "$build" 2>/dev/null \
        || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} couldn't download Arch's $pn package"; return 0; }
    cp "$patch" "$build/monolith-underscan.patch"
    # the patch added to its sources and put in before the build (after Arch's own prepare, if it
    # has one); its release one higher, so pacman keeps it over the repo's same version
    sed -i 's/^prepare()/_arch_prepare()/' "$build/PKGBUILD"
    cat >> "$build/PKGBUILD" <<'EOF'

# ── Monolith: HDMI scaling (underscan) ──
source+=("monolith-underscan.patch")
[ "${#sha256sums[@]}" -gt 0 ] && sha256sums+=('SKIP')
[ "${#sha512sums[@]}" -gt 0 ] && sha512sums+=('SKIP')
[ "${#b2sums[@]}" -gt 0 ] && b2sums+=('SKIP')
pkgrel="${pkgrel}.1"
prepare() {
	if declare -f _arch_prepare >/dev/null; then (cd "$srcdir" && _arch_prepare) || return 1; fi
	cd "$srcdir/${_archive:-$pkgname-$pkgver}" && patch -Np1 -i "$srcdir/monolith-underscan.patch"
}
EOF
    # (--nocheck: niri's test suite takes long and isn't what changed)
    if ! (cd "$build" && makepkg -si --noconfirm --needed --nocheck); then
        echo -e "  ${C_YELLOW}HDMI scaling:${RESET} building $pn with the patch failed; left as it was"
    fi
    rm -rf "$build"
}
