#!/usr/bin/env bash
# Portage backend (Gentoo and Gentoo-based systems). The rest of the installer speaks Arch
# package names; portage-map.txt turns them into Gentoo atoms. Everything is built from source:
# no -bin packages, and the two tools Gentoo doesn't package (wooz, wl-gammarelay-rs) are
# compiled into ~/.local.
#
# Overlays: ::guru (niri, quickshell, matugen, ...) and ::librewolf (the browser bind).
# Portage config Monolith writes lives in files named "monolith" / "zz-monolith-autounmask"
# under /etc/portage/package.*, so it's easy to see and to remove.

PORTAGE_MAP_FILE="$PM_MODULES_DIR/portage-map.txt"
PORTAGE_VDB="${PORTAGE_VDB:-/var/db/pkg}"

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig)
PM_EXTRA_PKGS=(gentoolkit)                 # eclean-dist, for Settings -> Software -> Portage
PM_SDDM_EXTRA_PKGS=(xorg-server)           # Gentoo's sddm doesn't pull in an X server for its greeter

declare -gA PORTAGE_MAP=()
while read -r _name _rest; do
    [ -n "$_name" ] && PORTAGE_MAP["$_name"]="$_rest"
done < <(sed -e 's/#.*//' "$PORTAGE_MAP_FILE" | awk 'NF>1{n=$1; $1=""; sub(/^ /,""); print n, $0}')
unset _name _rest

pm_supports_os() {
    grep -qsE '^ID(_LIKE)?="?[^"]*\bgentoo\b' /etc/os-release
}

# Arch name -> atoms ("" when there's nothing to install, "src:x" for a source build)
portage_atoms() {
    local name="$1"
    if [[ -v PORTAGE_MAP["$name"] ]]; then
        local v="${PORTAGE_MAP[$name]}"
        [ "$v" = "-" ] && v=""
        printf '%s' "$v"
    elif [[ "$name" == */* ]]; then
        printf '%s' "$name"            # already an atom
    else
        printf 'unknown:%s' "$name"
    fi
}

portage_atom_installed() {
    local atom="${1%%:*}" cat pn
    cat="${atom%%/*}"; pn="${atom#*/}"
    compgen -G "$PORTAGE_VDB/$cat/$pn-[0-9]*" >/dev/null
}

portage_src_installed() {
    case "$1" in
        wooz) command -v wooz &>/dev/null || [ -x "$HOME/.local/bin/wooz" ] ;;
        wl-gammarelay-rs) command -v wl-gammarelay-rs &>/dev/null || [ -x "$HOME/.local/bin/wl-gammarelay-rs" ] ;;
        *) return 1 ;;
    esac
}

pm_has_pkg() {
    local a
    a="$(portage_atoms "$1")"
    [[ "$a" != unknown:* ]]
}

pm_is_installed() {
    local atoms a
    atoms="$(portage_atoms "$1")"
    case "$atoms" in
        unknown:*) return 1 ;;
        "") return 0 ;;                                   # nothing to install
        src:*) portage_src_installed "${atoms#src:}"; return ;;
    esac
    for a in $atoms; do portage_atom_installed "$a" || return 1; done
    return 0
}

pm_missing_pkgs() {
    local p
    for p in "$@"; do
        pm_is_installed "$p" || echo "$p"
    done
}

# a file we own in /etc/portage/<dir>/; refuses (returns 1) when <dir> is a plain file, which
# we leave alone rather than rewrite someone's config layout
portage_conf_file() {
    local dir="/etc/portage/$1"
    [ -e "$dir" ] && [ ! -d "$dir" ] && return 1
    sudo mkdir -p "$dir"
    echo "$dir/$2"
}

# The LLVM slot the newest installed dev-lang/rust was built against ("" if unknown).
portage_rust_llvm_slot() {
    local d
    d="$(compgen -G "$PORTAGE_VDB/dev-lang/rust-[0-9]*" | sort -V | tail -n 1)"
    [ -n "$d" ] && [ -f "$d/USE" ] || return 0
    tr ' ' '\n' < "$d/USE" | sed -n 's/^llvm_slot_\([0-9]\+\)$/\1/p' | sort -n | tail -n 1
}

# LibreWolf has to use the same LLVM as Rust. Its ebuild defaults to the oldest LLVM it supports,
# and when the installed Rust uses a newer one Portage tries to build every older Rust slot back
# to one it can bootstrap. With rust-bin masked that ends in a circular dependency
# (rust-1.90 needs itself). Pin LibreWolf to Rust's LLVM when its ebuild supports it.
portage_librewolf_llvm_line() {
    local slot cpv
    slot="$(portage_rust_llvm_slot)"
    [ -n "$slot" ] || return 0
    cpv="$(portageq best_visible / ebuild www-client/librewolf 2>/dev/null)"
    [ -n "$cpv" ] || return 0
    portageq metadata / ebuild "$cpv" IUSE 2>/dev/null | tr ' ' '\n' | sed 's/^[+-]//' \
        | grep -qx "llvm_slot_$slot" || return 0
    echo "www-client/librewolf LLVM_SLOT: -* $slot"
}

portage_write_conf() {
    local f
    if f="$(portage_conf_file package.use monolith)"; then
        local pipewire_server="media-video/pipewire sound-server pipewire-alsa"
        # someone running PulseAudio's own daemon keeps it: pipewire's sound server would block it
        portage_atom_installed media-sound/pulseaudio-daemon && pipewire_server="#$pipewire_server (pulseaudio-daemon installed)"
        local librewolf_llvm
        librewolf_llvm="$(portage_librewolf_llvm_line)"
        printf '%s\n' \
            "# Written by the Monolith installer. What Monolith's features need from these packages." \
            "# Rewritten on every install and update: put your own lines in another file in this folder." \
            "$pipewire_server" \
            "# setpriv, which Monolith starts its idle/lock, clipboard and file watchers with" \
            "sys-apps/util-linux caps" \
            "gui-wm/niri screencast dbus" \
            "gui-apps/quickshell pipewire mpris pam policykit upower notifications bluetooth networkmanager" \
            "media-gfx/imagemagick jpeg png webp svg" \
            "app-text/tessdata_fast l10n_en" \
            "media-sound/cava pipewire" \
            "# pictures as fastfetch's logo (Settings → Terminal greeting)" \
            "app-misc/fastfetch imagemagick" \
            "dev-qt/qtmultimedia ffmpeg" \
            "# quickshell's crash handler, Thunar's panel bits, LibreWolf's system libvpx" \
            "dev-cpp/cpptrace unwind" \
            "dev-libs/libdbusmenu gtk3" \
            "media-libs/libvpx postproc" \
            ${librewolf_llvm:+"# LibreWolf on the same LLVM as the installed Rust (no old Rust bootstrap chain)"} \
            ${librewolf_llvm:+"$librewolf_llvm"} \
            | sudo tee "$f" >/dev/null
    fi
    # GURU and LibreWolf ebuilds are testing-only (~arch)
    if f="$(portage_conf_file package.accept_keywords monolith)"; then
        local arch; arch="$(portageq envvar ARCH 2>/dev/null || echo amd64)"
        {
            echo "# Written by the Monolith installer: overlay packages Monolith uses (testing keyword only)."
            # map lines only: a comment that mentions "(guru)" isn't a package
            grep -E '^[^#[:space:]]+[[:space:]]+[a-z0-9-]+/[^[:space:]]+.*\((guru|librewolf)\)' "$PORTAGE_MAP_FILE" \
                | awk -v k="~$arch" '{print $2, k}' | sort -u
        } | sudo tee "$f" >/dev/null
    fi
    # autounmask writes into the last file of each folder: give it ours
    local d
    for d in package.use package.accept_keywords package.license; do
        f="$(portage_conf_file "$d" zz-monolith-autounmask)" && sudo touch "$f"
    done
}

portage_enable_repo() {
    local repo="$1" url="$2"
    [ -d "/var/db/repos/$repo" ] && return 0
    echo -e "\n\e[36m[ INFO ]\e[0m Adding the ::$repo overlay"
    sudo eselect repository enable "$repo" 2>/dev/null \
        || sudo eselect repository add "$repo" git "$url"
    sudo emaint sync -r "$repo"
}

pm_prepare_repos() {
    portage_atom_installed app-eselect/eselect-repository \
        || sudo emerge --ask=n --noreplace app-eselect/eselect-repository dev-vcs/git
    portage_enable_repo guru https://github.com/gentoo-mirror/guru.git
    portage_enable_repo librewolf https://codeberg.org/librewolf/gentoo.git
    portage_write_conf
}

portage_emerge() {
    local masks=() d
    for d in package.use package.accept_keywords package.license; do
        masks+=("/etc/portage/$d/zz-monolith-autounmask")
    done
    sudo env CONFIG_PROTECT_MASK="${masks[*]}" \
        emerge --ask=n --noreplace --keep-going --with-bdeps=y \
        --autounmask=y --autounmask-continue=y --autounmask-use=y --autounmask-license=y \
        --autounmask-keep-masks=y "$@"
}

pm_bootstrap_install() {
    local atoms=() p a
    for p in "$@"; do
        a="$(portage_atoms "$p")"
        [[ -z "$a" || "$a" == src:* || "$a" == unknown:* ]] && continue
        atoms+=($a)
    done
    [ ${#atoms[@]} -gt 0 ] && sudo emerge --ask=n --noreplace "${atoms[@]}"
}

# no AUR helper on Gentoo
pm_bootstrap_helper() { return 0; }

# Packages that are already installed don't pick up the USE flags Monolith sets until they're
# rebuilt (util-linux's setpriv, for one, is part of every Gentoo system). Rebuild the installed
# ones whose flags changed; --newuse leaves the rest alone.
pm_apply_use() {
    local f=/etc/portage/package.use/monolith atoms=() a
    [ -f "$f" ] || return 0
    while read -r a _; do
        portage_atom_installed "$a" && atoms+=("$a")
    done < <(sed -e 's/#.*//' "$f" | awk 'NF>1')
    [ ${#atoms[@]} -gt 0 ] || return 0
    echo -e "\e[36m[ INFO ]\e[0m Rebuilding packages whose USE flags Monolith changed (if any)"
    portage_emerge --oneshot --update --newuse "${atoms[@]}" || true
}

pm_full_upgrade() {
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    sudo emaint sync -a || sudo emerge --sync
    # A full @world update can take hours on Gentoo, so it isn't done here: run
    # `sudo emerge -avuDN @world` yourself when you like. Monolith's packages pull in whatever
    # newer dependencies they need.
}

# everything in one emerge: Portage resolves the whole set together, and building in one go is
# much faster than ~90 separate emerges. PM_BATCH_LEFT is what's still missing afterwards.
PM_BATCH_LEFT=()
pm_install_batch() {
    local atoms=() srcs=() p a
    for p in "$@"; do
        a="$(portage_atoms "$p")"
        case "$a" in
            "" | unknown:*) ;;
            src:*) srcs+=("${a#src:}") ;;
            *) atoms+=($a) ;;
        esac
    done
    if [ ${#atoms[@]} -gt 0 ]; then
        echo -e "\e[36m[ INFO ]\e[0m Building ${#atoms[@]} packages from source with Portage. This can take a while.\n"
        portage_emerge "${atoms[@]}" || true
    fi
    for p in "${srcs[@]}"; do portage_build_src "$p" || true; done
    mapfile -t PM_BATCH_LEFT < <(pm_missing_pkgs "$@")
}

pm_install_pkg() {
    local a
    a="$(portage_atoms "$1")"
    case "$a" in
        "") return 0 ;;
        unknown:*) echo "No Gentoo package known for $1"; return 1 ;;
        src:*) portage_build_src "${a#src:}" ;;
        *) portage_emerge $a ;;
    esac
}

# --- the two tools Gentoo has no ebuild for, built from their source into ~/.local ------------
portage_build_src() {
    local name="$1" build
    build="${XDG_CACHE_HOME:-$HOME/.cache}/monolith-src/$name"
    mkdir -p "$HOME/.local/bin"
    case "$name" in
        wooz)
            portage_atom_installed dev-build/meson || sudo emerge --ask=n --noreplace dev-build/meson
            sudo emerge --ask=n --noreplace dev-libs/wayland dev-libs/wayland-protocols >/dev/null || true
            rm -rf "$build"
            git clone --depth 1 https://github.com/negrel/wooz.git "$build" \
                && meson setup "$build/build" "$build" --prefix "$HOME/.local" --buildtype release \
                && ninja -C "$build/build" \
                && ninja -C "$build/build" install
            ;;
        wl-gammarelay-rs)
            command -v cargo &>/dev/null || sudo emerge --ask=n --noreplace virtual/rust
            cargo install --locked --root "$HOME/.local" wl-gammarelay-rs
            ;;
        *) return 1 ;;
    esac
    local rc=$?
    rm -rf "$build"
    return $rc
}

pm_upgrade_quickshell() {
    sudo emerge --ask=n --update --oneshot gui-apps/quickshell && quickshell_is_current
    return 0
}

pm_remove_pkg() {
    local a
    a="$(portage_atoms "$1")"
    [[ -z "$a" || "$a" == src:* || "$a" == unknown:* ]] && return 0
    sudo emerge --ask=n --deselect $a >/dev/null 2>&1 || true
    sudo emerge --ask=n --depclean $a >/dev/null 2>&1 || true
}

# quickshell-git is an AUR name; nothing like it to replace on Gentoo
pm_remove_conflicting_pkg() { return 0; }
