#!/bin/sh
# Every icon in Monolith is a glyph of Google's Material Symbols font (Apache 2.0): the Rounded
# set, or the Sharp one in the Cyberpunk style. They aren't packaged everywhere, so this puts one
# in the user's fonts when it's missing.
#   icon-font.sh [Rounded|Sharp]   install that set (default Rounded) if it's missing; exit 0
#                                  when it was already there, 10 when it was just installed (the
#                                  shell restarts to pick it up), 1 when it couldn't be downloaded
set_="${1:-Rounded}"
case "$set_" in Rounded|Sharp) ;; *) exit 1 ;; esac
fc-list 2>/dev/null | grep -q "Material Symbols $set_" && exit 0
dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/monolith"
mkdir -p "$dest"
url="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbols$set_%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
tmp="$dest/.MaterialSymbols$set_.ttf.part"
if curl -fsSL --retry 2 --max-time 120 -o "$tmp" "$url" && [ -s "$tmp" ]; then
    mv "$tmp" "$dest/MaterialSymbols$set_.ttf"
    fc-cache -f "$dest" >/dev/null 2>&1
    exit 10
fi
rm -f "$tmp"
exit 1
