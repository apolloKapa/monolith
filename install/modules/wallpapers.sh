#!/usr/bin/env bash
# Wallpapers: pictures copied from a wallpaper repo (default apolloKapa/wallpapers, override with
# WALLPAPER_REPO; Serpantinum's pack if that can't be downloaded), and live wallpapers (videos)
# downloaded from the repo's `live` release into Wallpapers/Live, checked against live/files.tsv.

# installer.sh provides gitx (no password prompts, gh login); plain git when used on its own
declare -f gitx >/dev/null || gitx() { GIT_TERMINAL_PROMPT=0 git "$@"; }

render_wallpaper_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-Installing wallpapers}"
    local bar_width=30
    local percent=0
    if [ "$total" -gt 0 ]; then
        percent=$(( current * 100 / total ))
    fi
    local filled=0
    if [ "$total" -gt 0 ]; then
        filled=$(( current * bar_width / total ))
    fi
    local empty=$(( bar_width - filled ))
    local bar_fill=""
    local bar_empty=""
    if [ "$filled" -gt 0 ]; then
        bar_fill=$(printf "%*s" "$filled" "" | tr ' ' '=')
    fi
    if [ "$empty" -gt 0 ]; then
        bar_empty=$(printf "%*s" "$empty" "" | tr ' ' ' ')
    fi
    printf "\r\e[36m[ INFO ]\e[0m %s \e[32m[%s%s]\e[0m %3d%% (%d/%d)" "$label" "$bar_fill" "$bar_empty" "$percent" "$current" "$total"
}

get_wallpaper_dir() {
    local user_pics=""
    if [ -f "$HOME/.config/user-dirs.dirs" ]; then
        user_pics=$(grep '^XDG_PICTURES_DIR' "$HOME/.config/user-dirs.dirs" 2>/dev/null | cut -d= -f2 | tr -d '"' | sed "s|\$HOME|$HOME|g")
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        if command -v xdg-user-dir &>/dev/null; then
            user_pics="$(xdg-user-dir PICTURES 2>/dev/null || true)"
        fi
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        user_pics="$HOME/Pictures"
    fi
    user_pics="${user_pics%/}"
    echo "$user_pics/Wallpapers"
}

install_wallpapers() {
    local full_pack="${1:-true}"
    local wallpaper_dir
    wallpaper_dir=$(get_wallpaper_dir)
    # Monolith's own pack; Serpantinum's public one if it can't be downloaded
    local wallpaper_repo="${WALLPAPER_REPO:-https://github.com/apolloKapa/wallpapers.git}"
    local fallback_repo="https://github.com/ilyamiro/shell-wallpapers.git"
    local clone_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/monolith-wallpapers"

    mkdir -p "$wallpaper_dir"

    local sync_success=false
    # a copy of another pack (installs before 2.5.7 used Serpantinum's; the fallback used once)
    # is downloaded again from the right repo: refreshing it kept giving the old pictures
    if [ -d "$clone_dir/.git" ]; then
        local have_url
        have_url=$(git -C "$clone_dir" remote get-url origin 2>/dev/null)
        if [ "${have_url%.git}" != "${wallpaper_repo%.git}" ]; then
            rm -rf "$clone_dir"
        fi
    fi
    if [ -d "$clone_dir/.git" ]; then
        if gitx -C "$clone_dir" fetch --depth 1 origin 2>/dev/null; then
            if git -C "$clone_dir" reset -q --hard FETCH_HEAD 2>/dev/null || \
               git -C "$clone_dir" reset -q --hard origin/HEAD 2>/dev/null || \
               git -C "$clone_dir" reset -q --hard origin/main 2>/dev/null || \
               git -C "$clone_dir" reset -q --hard origin/master 2>/dev/null; then
                sync_success=true
            fi
        fi
    fi

    if [ "$sync_success" != true ]; then
        rm -rf "$clone_dir"
        echo -e "\n\e[36m[ INFO ]\e[0m Cloning wallpapers repository..."
        if ! gitx clone --depth 1 "$wallpaper_repo" "$clone_dir" 2>/dev/null && [ -z "${WALLPAPER_REPO:-}" ]; then
            rm -rf "$clone_dir"
            gitx clone --depth 1 "$fallback_repo" "$clone_dir" 2>/dev/null || true
        fi
    fi

    local src_dir="$clone_dir"
    if [ -d "$clone_dir/images" ]; then
        src_dir="$clone_dir/images"
    fi

    if [ ! -d "$src_dir" ]; then
        echo -e "  ${C_YELLOW}wallpapers:${RESET} couldn't download $wallpaper_repo; put your own in $wallpaper_dir"
        return 0
    fi

    if [ "$full_pack" = true ]; then
        local files=()
        while IFS= read -r f; do
            [[ -n "$f" ]] && files+=("$f")
        done < <(find "$src_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null)

        local total=${#files[@]}
        local count=0 added=0

        if [ "$total" -gt 0 ]; then
            for file in "${files[@]}"; do
                [ -e "$wallpaper_dir/${file##*/}" ] || added=$((added + 1))
                cp "$file" "$wallpaper_dir/" 2>/dev/null || true
                count=$((count + 1))
                render_wallpaper_progress "$count" "$total" "Installing wallpapers"
            done
            echo ""
            echo -e "  wallpapers: $added new, $((total - added)) already there (in $wallpaper_dir)"
        else
            find "$src_dir" -type f ! -name "README.md" ! -name "LICENSE" ! -path "*/.git/*" -exec cp {} "$wallpaper_dir/" \; 2>/dev/null || true
        fi
    else
        if [ -n "$(ls -A "$wallpaper_dir" 2>/dev/null | grep -iE '\.(jpg|jpeg|png|gif|webp)$')" ]; then
            # (it used to skip this silently: the installer seemed to do nothing)
            echo -e "  ${C_YELLOW}wallpapers:${RESET} $wallpaper_dir already has pictures, so no random ones were added. Pick \"full pack\" in the installer's menu to get all of them."
        else
            local random_pics=()
            while IFS= read -r pic; do
                [[ -n "$pic" ]] && random_pics+=("$pic")
            done < <(find "$src_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null | shuf -n 3)

            local total=${#random_pics[@]}
            local count=0

            if [ "$total" -gt 0 ]; then
                for pic in "${random_pics[@]}"; do
                    cp "$pic" "$wallpaper_dir/" 2>/dev/null || true
                    count=$((count + 1))
                    render_wallpaper_progress "$count" "$total" "Installing wallpapers"
                done
                echo ""
            fi
        fi
    fi

    # the full pack gets every live wallpaper, the random pick one of them
    install_live_wallpapers "$clone_dir" "$wallpaper_dir/Live" "$([ "$full_pack" = true ] && echo all || echo 1)"
}

# Live wallpapers: the videos listed in <clone>/live/files.tsv (name, size, sha256), downloaded
# from the repo's `live` release (they're too big for the repository itself). A file that's
# already there with the right size is kept. $3: "all", or how many random ones (only when the
# Live folder has no videos yet).
install_live_wallpapers() {
    local clone_dir="$1" live_dir="$2" want="${3:-all}"
    local list="$clone_dir/live/files.tsv"
    [ -f "$list" ] || return 0
    command -v curl >/dev/null 2>&1 || { echo -e "  ${C_YELLOW}live wallpapers:${RESET} curl is missing, skipped"; return 0; }
    # https://github.com/OWNER/REPO(.git) -> its live release
    local repo_url
    repo_url=$(git -C "$clone_dir" remote get-url origin 2>/dev/null)
    repo_url="${repo_url%.git}"
    local base="${WALLPAPER_LIVE_URL:-$repo_url/releases/download/live}"
    mkdir -p "$live_dir"

    local rows=()
    while IFS=$'\t' read -r name size sum; do
        # names come from the list: no paths, nothing odd
        [[ -n "$name" && "$name" != */* && "$name" != .* && "$size" =~ ^[0-9]+$ && "$sum" =~ ^[0-9a-f]{64}$ ]] || continue
        rows+=("$name"$'\t'"$size"$'\t'"$sum")
    done < "$list"
    [ "${#rows[@]}" -gt 0 ] || return 0
    if [ "$want" != all ]; then
        # a random pick only for a Live folder without videos (an update doesn't add more)
        find "$live_dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) | grep -q . && return 0
        mapfile -t rows < <(printf '%s\n' "${rows[@]}" | shuf -n "$want")
    fi

    local total=${#rows[@]} count=0 failed=0 row name size sum dest
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r name size sum <<< "$row"
        dest="$live_dir/$name"
        count=$((count + 1))
        render_wallpaper_progress "$count" "$total" "Installing live wallpapers"
        if [ -f "$dest" ] && [ "$(stat -c %s "$dest" 2>/dev/null)" = "$size" ]; then
            continue
        fi
        if curl -fsSL --connect-timeout 15 --retry 3 -o "$dest.part" "$base/$name" \
            && [ "$(sha256sum "$dest.part" | cut -d' ' -f1)" = "$sum" ]; then
            mv -f "$dest.part" "$dest"
        else
            rm -f "$dest.part"
            failed=$((failed + 1))
        fi
    done
    echo ""
    [ "$failed" -eq 0 ] || echo -e "  ${C_YELLOW}live wallpapers:${RESET} $failed couldn't be downloaded; try again with the installer's Update"
}
