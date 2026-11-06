#!/bin/sh
# Every icon in Monolith is a glyph of Google's Material Symbols Rounded font (Apache 2.0). It
# isn't packaged everywhere, so this puts it in the user's fonts when it's missing.
#   icon-font.sh          install it if it's missing; exit 0 when it was already there,
#                         10 when it was just installed (the shell restarts to pick it up),
#                         1 when it couldn't be downloaded
fc-list 2>/dev/null | grep -q "Material Symbols Rounded" && exit 0
dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/monolith"
mkdir -p "$dest"
url='https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'
tmp="$dest/.MaterialSymbolsRounded.ttf.part"
if curl -fsSL --retry 2 --max-time 120 -o "$tmp" "$url" && [ -s "$tmp" ]; then
    mv "$tmp" "$dest/MaterialSymbolsRounded.ttf"
    fc-cache -f "$dest" >/dev/null 2>&1
    exit 10
fi
rm -f "$tmp"
exit 1
