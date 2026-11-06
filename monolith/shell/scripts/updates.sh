#!/bin/sh
# Monolith's updater, for Settings → About, the update notification and the bar's update icon.
#   updates.sh check DIR    what's new, one change per line (nothing: up to date). The first line
#                           is "@<version> <commit>" of what GitHub has.
#   updates.sh update DIR   bring it up to date (run in a terminal: it may ask for your password
#                           when a new package is needed), then restart the shell
# DIR is the shell folder. In a git checkout (development) that's git fetch / pull --ff-only.
# Installed by the Monolith installer it compares the installed commit with GitHub's branch
# and updates through the installer (`monolith installer --update`).
dir="$2"
state="${XDG_STATE_HOME:-$HOME/.local/state}/monolith/version"
src="$HOME/.local/share/monolith/install/source.env"
git_auth() {
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
    else GIT_TERMINAL_PROMPT=0 git "$@"; fi
}

# a git checkout: plain git
if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    case "$1" in
        check)
            git -C "$dir" fetch -q 2>/dev/null
            n=$(git -C "$dir" rev-list --count HEAD..@{u} 2>/dev/null)
            [ "${n:-0}" -gt 0 ] && echo "@git $(git -C "$dir" rev-parse --short @{u})" && git -C "$dir" log --format=%s HEAD..@{u} 2>/dev/null
            ;;
        update) git -C "$dir" pull --ff-only && exec "$dir/../bin/monolith" restart ;;
    esac
    exit
fi

REPO_SLUG=apolloKapa/monolith; MONOLITH_BRANCH=main
[ -f "$src" ] && . "$src"
# the branch it follows; one that isn't on GitHub (any more) means main
branch_head() { git_auth ls-remote "https://github.com/$REPO_SLUG.git" "refs/heads/$1" 2>/dev/null | cut -c1-40; }

case "$1" in
    check)
        have=$(sed -n 's/^MONOLITH_COMMIT="\(.*\)"/\1/p' "$state" 2>/dev/null)
        remote=$(branch_head "$MONOLITH_BRANCH")
        if [ -z "$remote" ] && [ "$MONOLITH_BRANCH" != main ]; then MONOLITH_BRANCH=main; remote=$(branch_head main); fi
        [ -z "$remote" ] && exit 2                                   # offline, or GitHub unreachable
        [ -n "$have" ] && [ "$(printf %s "$remote" | cut -c1-${#have})" = "$have" ] && exit 0   # up to date
        # what changed: GitHub's list of commits between yours and the newest
        ver=$(curl -fsSL --max-time 15 "https://raw.githubusercontent.com/$REPO_SLUG/$remote/monolith/version.txt" 2>/dev/null | head -1)
        echo "@${ver:-new} $(printf %s "$remote" | cut -c1-7)"
        if [ -n "$have" ]; then
            curl -fsSL --max-time 20 "https://api.github.com/repos/$REPO_SLUG/compare/$have...$remote" 2>/dev/null \
                | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    for c in d.get("commits", []): print(c["commit"]["message"].split("\n")[0][:200])
except Exception: pass' 2>/dev/null
        fi
        ;;
    update)
        # the installer's update (it uses the new version's own steps), on the branch that exists
        if [ -z "$(branch_head "$MONOLITH_BRANCH")" ] && [ -f "$src" ]; then
            sed -i 's/^MONOLITH_BRANCH=.*/MONOLITH_BRANCH="main"/' "$src"
        fi
        exec "$dir/../bin/monolith" installer --update
        ;;
esac
