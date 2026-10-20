#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
mkdir -p ~/.config ~/.local/bin
cp -r config/* ~/.config/
cp -a bin/* ~/.local/bin/
echo "Restored. Install packages with: sudo pacman -S --needed - < packages.txt"
echo "Then log out and back in."
