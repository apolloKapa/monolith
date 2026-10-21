#!/usr/bin/env bash
# usage: ./install.sh [--sddm]
#   copies configs + scripts, installs the Monolith shell into ~/.local/share/monolith
#   --sddm also installs the login screen theme (needs sudo)
set -e
cd "$(dirname "$0")"
mkdir -p ~/.config ~/.local/bin

# configs. Monolith's settings.json is only seeded once: after that the shell owns it
for c in config/*; do
    name="$(basename "$c")"
    case "$name" in
        monolith)
            mkdir -p ~/.config/monolith
            [ -s ~/.config/monolith/settings.json ] || cp config/monolith/settings.json ~/.config/monolith/
            ;;
        *) cp -r "$c" ~/.config/ ;;
    esac
done
cp -a bin/* ~/.local/bin/

# the shell itself
dest=~/.local/share/monolith
rm -rf "$dest"
mkdir -p "$dest"
cp -r monolith/bin monolith/src monolith/version.txt "$dest/"
chmod +x "$dest"/bin/*
find "$dest/src/scripts" -type f -name "*.sh" -exec chmod +x {} +
ln -sf "$dest/bin/monolith" ~/.local/bin/monolith
ln -sf "$dest/bin/monolithd" ~/.local/bin/monolithd

# lock screen password check (PAM service called "monolith")
if [ -d /etc/pam.d ] && [ ! -f /etc/pam.d/monolith ]; then
    base=system-auth; [ -f /etc/pam.d/$base ] || base=login
    pam="auth        include      $base"$'\n'"account     include      $base"$'\n'
    grep -qs pam_fprintd /etc/pam.d/$base || pam="-auth       sufficient   pam_fprintd.so"$'\n'"$pam"
    echo "Adding /etc/pam.d/monolith for the lock screen (sudo)..."
    printf '%s' "$pam" | sudo tee /etc/pam.d/monolith >/dev/null
    sudo chmod 644 /etc/pam.d/monolith
fi

if [ "$1" = "--sddm" ]; then
    sudo mkdir -p /usr/share/sddm/themes/monolith /etc/sddm.conf.d
    sudo cp -r monolith/sddm/themes/material-you/. /usr/share/sddm/themes/monolith/
    printf '[Theme]\nCurrent=monolith\n' | sudo tee /etc/sddm.conf.d/10-monolith.conf >/dev/null
    echo "SDDM theme installed."
fi

echo "Done. Install packages with: sudo pacman -S --needed - < packages.txt"
echo "Then log out and back in (niri starts the shell with 'monolithd start')."
