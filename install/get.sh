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
    # public repo: plain download; private repo: through the GitHub CLI login (gh auth login)
    if ! curl -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install/install.sh" 2>/dev/null; then
        if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
            gh api "repos/${slug}/contents/install/install.sh?ref=${branch}" -H "Accept: application/vnd.github.raw" > "$dir/install/install.sh"
        else
            echo "Couldn't download the installer. If the repo is private, install github-cli and run 'gh auth login' first." >&2
            exit 1
        fi
    fi
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
