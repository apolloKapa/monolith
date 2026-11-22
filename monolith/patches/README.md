# Patches for other software

Both patches below give Settings → Displays its HDMI scaling slider: the one for the compositor
you use. The installer builds it for you (its menu: "HDMI scaling for TVs", on Gentoo and Arch);
the steps here are the same by hand.

## aquamarine-underscan.patch: HDMI scaling on Hyprland

A TV that zooms in on its HDMI input (overscan) cuts off the edges of the picture. AMD (and
older Radeon) GPUs can draw the picture smaller with a border ("underscan", what Windows calls
HDMI scaling), but only the compositor may switch it on, and Hyprland's display library,
aquamarine, never does. This patch makes it: it reads the borders from
`~/.config/aquamarine/underscan` (lines of `NAME HBORDER VBORDER` in pixels) whenever a screen's
mode is set. Settings → Displays → HDMI scaling writes that file and turns the screen off and on
to apply it; the slider shows once the patched library is installed.

Made for aquamarine 0.16.0. On Gentoo:

    sudo mkdir -p /etc/portage/patches/gui-libs/aquamarine-0.16.0
    sudo cp aquamarine-underscan.patch /etc/portage/patches/gui-libs/aquamarine-0.16.0/
    sudo emerge --oneshot gui-libs/aquamarine

then log out and in (Hyprland loads the library when it starts). The patch is kept for that
version only: an aquamarine update builds without it (Settings says so again) until the patch is
checked against the new version and copied into its folder.

## niri-underscan.patch: HDMI scaling on niri

The same for niri, which doesn't use aquamarine: niri sets the borders from the same file as a
screen is turned on (Settings turns it off and on to apply a change). Made for niri 26.04. On
Gentoo:

    sudo mkdir -p /etc/portage/patches/gui-wm/niri-26.04
    sudo cp niri-underscan.patch /etc/portage/patches/gui-wm/niri-26.04/
    sudo emerge --oneshot gui-wm/niri

then log out and in. (On Arch the installer adds it to Arch's own PKGBUILD and builds it with
makepkg, for both.)
