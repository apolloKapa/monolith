#!/usr/bin/env bash
# Builds Monolith's binhost: the packages a Monolith install on Gentoo needs that Gentoo's own
# binhost doesn't have (at the stable versions, with the USE gentoo-install and Monolith set),
# as binary packages any x86-64 machine can install. With them a Gentoo install never compiles.
#
#   build.sh [--minutes N]     run as root inside a stable Gentoo root (a stage3: the workflow in
#                              .github/workflows/binhost.yml, or a chroot of your own) with this
#                              repo somewhere in it. Stops starting new builds after N minutes
#                              (default 300: GitHub's runs end at 6 hours); what's done is kept.
#
# The packages already published are put into PKGDIR first (publish.py --unflatten), so only
# what's new or changed is built. Everything else comes from Gentoo's binhost. When it's done,
# PKGDIR (/var/cache/binpkgs) holds the whole set and its index; publish.py turns that into the
# release's files.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
MINUTES=300
[ "${1:-}" = --minutes ] && MINUTES="$2"

say() { printf '\n\e[36m[ binhost ]\e[0m %s\n' "$*"; }

# ── the configuration: gentoo-install's, stable, generic ────────────────────────────────────────
say "Portage configuration"
cp -r "$HERE/portage/." /etc/portage/
mkdir -p /etc/portage/package.accept_keywords /etc/portage/repos.conf
# the overlays' packages are testing-only, as the installer writes them
{
    grep -E '^[^#[:space:]]+[[:space:]]+[a-z0-9-]+/[^[:space:]]+.*\((guru|librewolf)\)' "$REPO/install/modules/pm/portage-map.txt" \
        | awk '{print $2, "~amd64"}' | sort -u
    echo "www-client/librewolf-bin ~amd64"
} > /etc/portage/package.accept_keywords/monolith
: > /etc/portage/package.accept_keywords/zz-autounmask
: > /etc/portage/package.use/zz-autounmask

# ── the trees: Gentoo's, GURU, LibreWolf's ──────────────────────────────────────────────────────
if [ ! -d /var/db/repos/gentoo/profiles ]; then
    say "Gentoo's tree"
    emerge-webrsync -q || exit 1
fi
cat > /etc/portage/repos.conf/monolith-overlays.conf <<'EOF'
[guru]
location = /var/db/repos/guru
sync-type = git
sync-uri = https://github.com/gentoo-mirror/guru.git

[librewolf]
location = /var/db/repos/librewolf
sync-type = git
sync-uri = https://codeberg.org/librewolf/gentoo.git
EOF
command -v git >/dev/null || emerge --oneshot --getbinpkg --quiet dev-vcs/git
for r in guru librewolf; do
    [ -d "/var/db/repos/$r/profiles" ] || { say "The ::$r overlay"; emaint sync -r "$r" || exit 1; }
done

# ── the build ───────────────────────────────────────────────────────────────────────────────────
# (LibreWolf isn't built: picked as Binary it's the overlay's librewolf-bin, a whole Firefox here)
mapfile -t atoms < <("$HERE/atoms.sh" | grep -vx 'www-client/librewolf')
say "Building what Gentoo's binhost doesn't have (${#atoms[@]} packages asked for; at most $MINUTES minutes)"
timeout --signal=INT "${MINUTES}m" emerge --oneshot --quiet-build=y \
    --autounmask=y --autounmask-continue=y --autounmask-write=y \
    "${atoms[@]}"
code=$?
[ "$code" -eq 124 ] && say "Time's up: what was built is kept, the next run goes on from there"

# ── the index, without what's gone from the tree ────────────────────────────────────────────────
command -v eclean-pkg >/dev/null || emerge --oneshot --getbinpkg --quiet app-portage/gentoolkit
command -v eclean-pkg >/dev/null && eclean-pkg >/dev/null 2>&1
emaint binhost --fix >/dev/null
say "PKGDIR has $(find /var/cache/binpkgs -name '*.gpkg.tar' | wc -l) packages"
exit 0
