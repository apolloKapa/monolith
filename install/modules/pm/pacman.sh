#!/usr/bin/env bash

PM_BOOTSTRAP_TOOLS=(fzf jq curl git pciutils unzip fontconfig base-devel)

# Nothing Monolith installs needs an extra repository, so pacman.conf is left alone (it used to
# switch multilib on for Steam, which isn't part of the install any more).
pm_prepare_repos() {
    return 0
}

# A mirror can list a package and still not serve it. CachyOS's cdn77 mirror answers 404 for
# every file with a "+" in its name (qt5-base-5.15.19+kde+r97-1.1...), so each of those printed
# "error: failed retrieving file ... The requested URL returned error: 404" before pacman got it
# from the next mirror, once per package the installer installed. So before a download the
# mirrors are asked whether they have the files pacman is about to fetch, and one that doesn't
# is left out for the rest of this run, through a copy of pacman.conf without it. The system's
# pacman.conf and mirrorlists stay as they are.
PM_CONF=""
PM_CONF_ARGS=()
PM_BAD_MIRRORS=()
PM_MIRRORS_FIXED=false

_pm_pacman() {
    sudo pacman "${PM_CONF_ARGS[@]}" "$@"
}

# pacman.conf with its Include files written out in place, without the mirrors in PM_BAD_MIRRORS
_pm_emit_conf() {
    local file="$1" depth="$2" line path inc bad
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$depth" -lt 4 ] && [[ "$line" =~ ^[[:space:]]*Include[[:space:]]*=[[:space:]]*(.*[^[:space:]]) ]]; then
            path="${BASH_REMATCH[1]}"
            while IFS= read -r inc; do
                [ -f "$inc" ] && [ -r "$inc" ] && _pm_emit_conf "$inc" $((depth + 1))
            done < <(compgen -G "$path")
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*Server[[:space:]]*=[[:space:]]*[a-z]+://([^/[:space:]]+) ]]; then
            for bad in "${PM_BAD_MIRRORS[@]}"; do
                [ "$bad" = "${BASH_REMATCH[1]}" ] && continue 2
            done
        fi
        printf '%s\n' "$line"
    done < "$file"
}

# leave these mirrors out from now on; refused (and nothing changes) if that would leave a
# repository with no mirror at all
_pm_drop_mirrors() {
    local before=("${PM_BAD_MIRRORS[@]}") conf repo
    PM_BAD_MIRRORS+=("$@")
    conf="$(mktemp "${TMPDIR:-/tmp}/monolith-pacman.XXXXXX")" || { PM_BAD_MIRRORS=("${before[@]}"); return 1; }
    if _pm_emit_conf /etc/pacman.conf 0 > "$conf" 2>/dev/null && chmod 644 "$conf"; then
        while IFS= read -r repo; do
            [ -n "$(pacman-conf --config "$conf" --repo="$repo" Server 2>/dev/null)" ] && continue
            rm -f "$conf"
            PM_BAD_MIRRORS=("${before[@]}")
            return 1
        done < <(pacman-conf --config "$conf" --repo-list 2>/dev/null)
        [ -n "$PM_CONF" ] && rm -f "$PM_CONF"
        PM_CONF="$conf"
        PM_CONF_ARGS=(--config "$conf")
        return 0
    fi
    rm -f "$conf"
    PM_BAD_MIRRORS=("${before[@]}")
    return 1
}

# the mirrors that say "no such file" (404) for what this pacman operation would download
_pm_mirrors_missing() {
    local urls=() url code num host
    while IFS= read -r url; do
        [[ "$url" == http://* || "$url" == https://* ]] && urls+=("$url")
    done < <(pacman "${PM_CONF_ARGS[@]}" "$@" --print --print-format '%l' 2>/dev/null)
    [ ${#urls[@]} -gt 0 ] || return 0

    # one HEAD request per file, sixteen at a time; a mirror is only blamed when it also answers
    # 404 to a real download of the file's first byte
    local seen=" "
    while read -r code num; do
        [ "$code" = "404" ] && [[ "$num" =~ ^[0-9]+$ ]] || continue
        url="${urls[$num]}"
        host="${url#*://}"; host="${host%%/*}"
        [[ "$seen" == *" $host "* ]] && continue
        seen+="$host "
        code="$(curl -s -g -L -r 0-0 -o /dev/null --connect-timeout 5 -m 15 -w '%{http_code}' "$url" 2>/dev/null)"
        [ "$code" = "404" ] && printf '%s\n' "$host"
    done < <(printf 'url = "%s"\noutput = "/dev/null"\n' "${urls[@]}" \
        | curl -s -g -I -L -Z --parallel-max 16 --connect-timeout 5 -m 15 \
            -w '%{http_code} %{urlnum}\n' -K - 2>/dev/null)
}

# pm_check_mirrors <pacman operation>, e.g. -S --needed foo bar, or -Su
pm_check_mirrors() {
    command -v curl &>/dev/null && command -v pacman-conf &>/dev/null || return 0
    local hosts=() host round
    for round in 1 2 3 4; do
        [ "$PM_MIRRORS_FIXED" = true ] && return 0
        mapfile -t hosts < <(_pm_mirrors_missing "$@")
        [ ${#hosts[@]} -gt 0 ] || return 0
        if _pm_drop_mirrors "${hosts[@]}"; then
            for host in "${hosts[@]}"; do
                echo -e "\e[36m[ INFO ]\e[0m $(t "installer.deps.mirror_skipped" "mirror=$host")"
            done
        else
            # nothing else to download from: pacman goes on with the mirrors as they are
            PM_MIRRORS_FIXED=true
        fi
    done
    return 0
}

# refresh the package lists ($1: -Sy, or -Syy to fetch them again from scratch), then upgrade
# the system and install the rest of the arguments. Refreshing and upgrading are two commands
# only so the mirrors can be checked in between, with the new lists; they always run together,
# because new lists without the upgrade (-Sy then -S) is the partial upgrade Arch warns can
# break the system.
_pm_sync_upgrade() {
    local refresh="$1"
    shift
    _pm_pacman "$refresh" || return 1
    pm_check_mirrors -Su "$@"
    _pm_pacman -Su --noconfirm "$@"
}

# The package lists are refreshed and the system brought up to date once per run, before
# anything is installed: installing from stale lists asks the mirrors for versions they no
# longer have.
PM_SYNCED=false
pm_sync() {
    [ "$PM_SYNCED" = true ] && return 0
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    _pm_sync_upgrade -Sy && PM_SYNCED=true
}

# Called once with everything that's about to be installed: the mirrors are checked for all of
# it in one go (the packages are then installed one at a time).
pm_prepare_downloads() {
    pm_sync || true
    local repo_pkgs=()
    mapfile -t repo_pkgs < <(pacman "${PM_CONF_ARGS[@]}" -Slq 2>/dev/null | grep -Fxf <(printf '%s\n' "$@") | sort -u)
    [ ${#repo_pkgs[@]} -gt 0 ] || return 0
    pm_check_mirrors -S --needed "${repo_pkgs[@]}"
}

# a repo package; a download failing (a mirror behind or ahead of the lists) gets the lists
# fetched again from scratch and one more try, upgrading in the same step
pm_pacman_install() {
    pm_sync || true
    _pm_pacman -S --noconfirm --needed "$@" && return 0
    echo -e "\e[33m[ WARN ]\e[0m pacman couldn't get everything: fetching the package lists again and retrying"
    _pm_sync_upgrade -Syy --needed "$@"
}

pm_bootstrap_install() {
    _pm_sync_upgrade -Sy --needed "$@" && PM_SYNCED=true && return 0
    _pm_sync_upgrade -Syy --needed "$@" && PM_SYNCED=true
}

pm_bootstrap_helper() {
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        local cache_build="${XDG_CACHE_HOME:-"$HOME/.cache"}/monolith-yay-bin"
        rm -rf "$cache_build"
        mkdir -p "$cache_build"
        git clone https://aur.archlinux.org/yay-bin.git "$cache_build"
        (cd "$cache_build" && makepkg -si --noconfirm)
        rm -rf "$cache_build"
    fi
}

pm_full_upgrade() {
    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deps.syncing")"
    _pm_sync_upgrade -Syy && PM_SYNCED=true
}

pm_missing_pkgs() {
    pacman -T "$@" 2>/dev/null || true
}

# is the package in the repos (not the AUR)?
pm_has_pkg() {
    pacman -Si "$1" &>/dev/null
}

pm_is_installed() {
    pacman -Q "$1" &>/dev/null
}

pm_install_pkg() {
    local pkg="$1"
    local safe_jobs="$2"

    # (the lists up to date first: an AUR package's dependencies come from the repos too)
    pm_sync || true
    if pacman -Si "$pkg" &>/dev/null; then
        pm_pacman_install "$pkg"
    elif command -v yay &>/dev/null; then
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" yay "${PM_CONF_ARGS[@]}" -S --noconfirm --needed "$pkg"
    elif command -v paru &>/dev/null; then
        env CARGO_BUILD_JOBS="$safe_jobs" MAKEFLAGS="-j$safe_jobs" paru "${PM_CONF_ARGS[@]}" -S --noconfirm --needed "$pkg"
    else
        pm_pacman_install "$pkg"
    fi
}

pm_upgrade_quickshell() {
    if _pm_sync_upgrade -Sy --needed --ask=4 quickshell && PM_SYNCED=true && quickshell_is_current; then
        return 0
    fi

    local helper
    for helper in yay paru; do
        command -v "$helper" &>/dev/null || continue
        "$helper" "${PM_CONF_ARGS[@]}" -S --noconfirm --needed --ask=4 quickshell-git && quickshell_is_current && return 0
        break
    done
    return 0
}

pm_remove_pkg() {
    sudo pacman -Rns --noconfirm "$1" >/dev/null 2>&1 || true
}

pm_remove_conflicting_pkg() {
    local pkg="$1"
    if pm_is_installed "$pkg"; then
        yay -R --noconfirm "$pkg" 2>/dev/null || sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
    fi
}
