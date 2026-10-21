#!/usr/bin/env bash
# One-command install:
#   curl -fsSL https://raw.githubusercontent.com/kasc0b3r/dotfiles/main/install/get.sh | bash
# Downloads the installer and runs it with your terminal as input (so the menu works when piped).
set -e

main() {
    local slug="${REPO_SLUG:-kasc0b3r/dotfiles}"
    local branch="${MONOLITH_BRANCH:-main}"
    local dir
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    mkdir -p "$dir/install"
    curl -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install/install.sh"
    export REPO_SLUG="$slug" MONOLITH_BRANCH="$branch"
    if [ -t 0 ]; then
        bash "$dir/install/install.sh" "$@"
    elif [ -r /dev/tty ]; then
        bash "$dir/install/install.sh" "$@" < /dev/tty
    else
        bash "$dir/install/install.sh" "$@"
    fi
}

main "$@"
