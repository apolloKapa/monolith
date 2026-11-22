#!/usr/bin/env bash
# HDMI scaling on Hyprland (Settings → Displays → HDMI scaling): Hyprland's display library,
# aquamarine, rebuilt with Monolith's underscan patch (monolith/patches/aquamarine-underscan.patch),
# so a TV that cuts the edges off can be given a border, as Windows' HDMI scaling does.
#   Gentoo: the patch goes in Portage's user patches for the installed version, and aquamarine is
#           emerged again (it stays patched across rebuilds of that version)
#   Arch:   Arch's own PKGBUILD for the installed version, with the patch added, built with makepkg
#           (its pkgrel gets a ".1", so the repo's same version doesn't replace it; a newer one
#           does, and the next Monolith update builds that one patched again)
# Asked for once in the installer's menu; remembered ($STATE_DIR/hdmi-scaling), and an update
# patches it again when an upgrade replaced it. A patch that doesn't fit a new version is left
# out (aquamarine stays as it is) and Settings says HDMI scaling needs it.

HDMI_STATE_FILE="$HOME/.local/state/monolith/hdmi-scaling"

# the installed aquamarine is a patched one (the library names the file it reads)
hdmi_patched() {
    local lib
    for lib in /usr/lib*/libaquamarine.so.* /usr/local/lib*/libaquamarine.so.*; do
        [ -f "$lib" ] && [ ! -L "$lib" ] && grep -q "aquamarine/underscan" "$lib" 2>/dev/null && return 0
    done
    return 1
}
hdmi_wanted() { [ "$(cat "$HDMI_STATE_FILE" 2>/dev/null)" = on ]; }

install_hdmi_scaling() {
    local root="$1"
    local patch="$root/monolith/patches/aquamarine-underscan.patch"
    mkdir -p "$(dirname "$HDMI_STATE_FILE")"
    echo on > "$HDMI_STATE_FILE"
    if hdmi_patched; then
        echo "  HDMI scaling: Hyprland's display library is patched already"
        return 0
    fi
    [ -f "$patch" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} the patch is missing from this copy of Monolith"; return 0; }
    case "$PM_NAME" in
        portage) _hdmi_gentoo "$patch" ;;
        pacman) _hdmi_arch "$patch" ;;
        *) echo -e "  ${C_YELLOW}HDMI scaling:${RESET} not available on this system yet" ;;
    esac
    hdmi_patched && echo -e "  HDMI scaling: ready after you log out and in again (Settings → Displays → HDMI scaling, on an HDMI screen)"
    return 0
}

_hdmi_gentoo() {
    local patch="$1" pkg ver dir
    pkg=$(ls -d /var/db/pkg/gui-libs/aquamarine-[0-9]* 2>/dev/null | tail -1)
    [ -n "$pkg" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} aquamarine isn't installed"; return 0; }
    ver="${pkg##*/aquamarine-}"
    dir="/etc/portage/patches/gui-libs/aquamarine-$ver"
    echo -e "\n\e[36m[ INFO ]\e[0m Building aquamarine $ver with HDMI scaling"
    sudo mkdir -p "$dir" && sudo cp "$patch" "$dir/aquamarine-underscan.patch" || return 0
    if ! sudo emerge --oneshot --ask=n "=gui-libs/aquamarine-$ver"; then
        # (a patch that doesn't fit this version: taken out again, nothing else changed)
        sudo rm -f "$dir/aquamarine-underscan.patch"
        sudo rmdir "$dir" 2>/dev/null || true
        echo -e "  ${C_YELLOW}HDMI scaling:${RESET} the patch doesn't fit aquamarine $ver; left as it was"
    fi
}

_hdmi_arch() {
    local patch="$1" ver build
    ver=$(pacman -Q aquamarine 2>/dev/null | awk '{print $2}')
    [ -n "$ver" ] || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} aquamarine isn't installed"; return 0; }
    # (our own build of the same version: ".1" on the release; the repo's version, to match)
    ver="${ver%.1}"
    build="${XDG_CACHE_HOME:-"$HOME/.cache"}/monolith-aquamarine"
    rm -rf "$build"
    echo -e "\n\e[36m[ INFO ]\e[0m Building aquamarine $ver with HDMI scaling"
    # Arch's PKGBUILD for exactly that version (its tag), else the newest
    gitx clone -q --depth 1 --branch "$ver" https://gitlab.archlinux.org/archlinux/packaging/packages/aquamarine.git "$build" 2>/dev/null \
        || gitx clone -q --depth 1 https://gitlab.archlinux.org/archlinux/packaging/packages/aquamarine.git "$build" 2>/dev/null \
        || { echo -e "  ${C_YELLOW}HDMI scaling:${RESET} couldn't download Arch's aquamarine package"; return 0; }
    cp "$patch" "$build/monolith-underscan.patch"
    # the patch added to its sources and put in before the build (after Arch's own prepare, if it
    # has one); its release one higher, so pacman keeps it over the repo's same version
    sed -i 's/^prepare()/_arch_prepare()/' "$build/PKGBUILD"
    cat >> "$build/PKGBUILD" <<'EOF'

# ── Monolith: HDMI scaling (underscan) ──
source+=("monolith-underscan.patch")
sha256sums+=('SKIP')
pkgrel="${pkgrel}.1"
prepare() {
	declare -f _arch_prepare >/dev/null && _arch_prepare
	cd "$srcdir/${_archive:-$pkgname-$pkgver}" && patch -Np1 -i "$srcdir/monolith-underscan.patch"
}
EOF
    if ! (cd "$build" && makepkg -si --noconfirm --needed); then
        echo -e "  ${C_YELLOW}HDMI scaling:${RESET} building aquamarine with the patch failed; left as it was"
    fi
    rm -rf "$build"
}
