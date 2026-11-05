#!/bin/sh
# The updater's check and update, for Settings → About and the island.
#   updates.sh check DIR    the subjects of the new commits, one per line (nothing: up to date)
#   updates.sh update DIR   bring it up to date
# DIR is the shell folder. In a git checkout (development) that's git fetch / pull --ff-only.
# Installed by the Monolith installer it compares the installed commit with GitHub's and
# updates through the installer (`monolith installer --update`), which restarts the shell.
dir="$2"
state="${XDG_STATE_HOME:-$HOME/.local/state}/monolith/version"
src="$HOME/.local/share/monolith/install/source.env"
git_auth() {
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
    else GIT_TERMINAL_PROMPT=0 git "$@"; fi
}
if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    case "$1" in
        check) git -C "$dir" fetch -q 2>/dev/null; git -C "$dir" log --format=%s HEAD..@{u} 2>/dev/null ;;
        update) git -C "$dir" pull -q --ff-only 2>&1 && exec "$dir/../bin/monolith" restart ;;
    esac
    exit
fi
REPO_SLUG=apolloKapa/monolith; MONOLITH_BRANCH=main
[ -f "$src" ] && . "$src"
case "$1" in
    check)
        have=$(sed -n 's/^MONOLITH_COMMIT="\(.*\)"/\1/p' "$state" 2>/dev/null)
        remote=$(git_auth ls-remote "https://github.com/$REPO_SLUG.git" "refs/heads/$MONOLITH_BRANCH" 2>/dev/null | cut -c1-7)
        [ -n "$have" ] && [ -n "$remote" ] && [ "$have" != "$remote" ] && echo "A new version of Monolith ($remote)"
        ;;
    update)
        # detached: the installer stops and restarts the shell (and this script with it)
        exec setsid "$dir/../bin/monolith" installer --update </dev/null >/dev/null 2>&1
        ;;
esac
