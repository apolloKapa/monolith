#!/bin/sh
# Title bars on every window in Hyprland (Desktop mode, core/Desk.qml): builds the hyprbars plugin
# from the official hyprland-plugins source against the Hyprland headers that come with Hyprland,
# into ~/.local/share/monolith/plugins/hyprbars.so. No root. Run it again after Hyprland updates
# (Settings → Desktop → Desktop mode says when). Monolith loads it while Desktop mode is on.
set -e
dest="${XDG_DATA_HOME:-$HOME/.local/share}/monolith/plugins"
src="${XDG_CACHE_HOME:-$HOME/.cache}/monolith/hyprland-plugins"

for t in git pkg-config make; do
    command -v "$t" >/dev/null || { echo "This needs $t (install it, then run this again)."; exit 1; }
done
command -v g++ >/dev/null || command -v clang++ >/dev/null || { echo "This needs a C++ compiler (g++)."; exit 1; }
pkg-config --exists hyprland || { echo "Hyprland's headers aren't installed (they come with the hyprland package on Arch and Gentoo)."; exit 1; }

# the running Hyprland (the plugin must be built for exactly this one)
commit=$(hyprctl version -j 2>/dev/null | sed -n 's/.*"commit": *"\([0-9a-f]*\)".*/\1/p' | head -1)
echo "Hyprland $(pkg-config --modversion hyprland)${commit:+ ($commit)}"

echo "Getting hyprland-plugins…"
if [ -d "$src/.git" ]; then
    git -C "$src" fetch -q origin
    git -C "$src" checkout -q -f origin/main
else
    mkdir -p "$(dirname "$src")"
    git clone -q https://github.com/hyprwm/hyprland-plugins.git "$src"
fi
# the plugins' commit made for this Hyprland, when they list one (hyprpm.toml); else the newest
if [ -n "$commit" ]; then
    pin=$(sed -n "s/.*\[\"$commit\", *\"\([0-9a-f]*\)\"\].*/\1/p" "$src/hyprpm.toml" | head -1)
    if [ -n "$pin" ]; then echo "Using the plugins made for this Hyprland ($pin)"; git -C "$src" checkout -q -f "$pin"; fi
fi

echo "Building hyprbars…"
# Lua's headers (Hyprland's config is Lua): some distros keep them in a folder of their own
# (Gentoo: /usr/include/lua5.4), which the plugin's build doesn't look in
luainc=""
for p in lua5.4 lua-5.4 lua54 lua; do
    luainc=$(pkg-config --cflags-only-I "$p" 2>/dev/null | sed 's/-I//g; s/ *$//') && [ -n "$luainc" ] && break
done
[ -z "$luainc" ] && for d in /usr/include/lua5.4 /usr/include/lua54 /usr/include/lua; do [ -f "$d/lua.h" ] && luainc=$d && break; done
[ -n "$luainc" ] && export CPATH="$luainc${CPATH:+:$CPATH}"
make -C "$src/hyprbars" clean >/dev/null 2>&1 || true
make -C "$src/hyprbars"
mkdir -p "$dest"
cp "$src/hyprbars/hyprbars.so" "$dest/hyprbars.so.new"
mv -f "$dest/hyprbars.so.new" "$dest/hyprbars.so"
# which Hyprland it's for (Monolith only loads it into that one)
printf '%s\n' "${commit:-$(pkg-config --modversion hyprland)}" > "$dest/hyprbars.for"
echo
echo "Done: windows get title bars while Desktop mode is on."
