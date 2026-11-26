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

## The installer does these for you

`monolith installer` → **niri extras** (minimise buttons, windows across screens while dragged)
builds niri with niri-minimize.patch and niri-move-across-monitors.patch, and HDMI scaling adds
niri-underscan.patch: every niri patch wanted goes into one build (a build with only some would
lose the others), on Gentoo (Portage's user patches, kept for that version) and Arch (Arch's own
PKGBUILD, installed over the same version). Remembered, and an update patches niri again after an
upgrade replaced it. The steps below are the same by hand.

## niri-minimize.patch: minimise buttons on niri

niri has no minimising, and tells apps so: kitty and GTK apps leave their minimise button out of
their title bars. This patch has niri say it can minimise, and pass a window's minimise request on
to the shell (an IPC event, `WindowMinimizeRequested`); Monolith's Desktop mode then minimises the
window the way it does from the taskbar (out of sight, back from its taskbar button). Without
Desktop mode the button does nothing. Made for niri 26.04; it goes beside the underscan patch, in
the same folder. On Gentoo:

    sudo mkdir -p /etc/portage/patches/gui-wm/niri-26.04
    sudo cp niri-minimize.patch /etc/portage/patches/gui-wm/niri-26.04/
    sudo emerge --oneshot gui-wm/niri

then log out and in. Apps opened after that have the button.

## niri-move-across-monitors.patch: dragging a window from one screen to another

niri draws each window on one screen only: a window dragged towards the next screen was cut off
at its own screen's edge, then jumped over whole once the pointer crossed. With this patch a
window being dragged is also drawn on every other screen it reaches over, where it is in the
layout of your screens, so it slides across (not in the overview). Made for niri 26.04; it goes in
the same folder as the others, and they all build together:

    sudo cp niri-move-across-monitors.patch /etc/portage/patches/gui-wm/niri-26.04/
    sudo emerge --oneshot gui-wm/niri

then log out and in.
