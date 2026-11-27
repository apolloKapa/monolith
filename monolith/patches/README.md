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

`monolith installer` → **niri extras** (minimise buttons, windows tiled when dragged to an edge,
windows across screens while dragged, X11 apps' own buttons) builds niri with niri-minimize.patch,
niri-drag-edges.patch and niri-move-across-monitors.patch, and xwayland-satellite with
xwayland-satellite-wm-buttons.patch; HDMI scaling adds
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

## niri-drag-edges.patch: tiling a window by dragging it to a screen's edge

KDE Plasma's quick tiling, for Monolith's Desktop mode on niri: a floating window dragged to a
screen's left or right edge tiles to that half, to a corner (the outer quarter of an edge) that
quarter, to the top edge it's maximised, with an outline of where it will go once the pointer has
been there a moment; a tiled window dragged away gets its size back. niri tells other programs
nothing while a window is dragged: this patch has it say which edge zone the pointer is in (an IPC
event, `WindowDragEdge`: as the drag starts, when the zone changes, and when the window is let
go). niri doesn't move the window itself; the shell does (core/Desk.qml), so without Desktop mode
nothing changes. Made for niri 26.04; it goes in the same folder as the others:

    sudo cp niri-drag-edges.patch /etc/portage/patches/gui-wm/niri-26.04/
    sudo emerge --oneshot gui-wm/niri

then log out and in.

## xwayland-satellite-wm-buttons.patch: an X11 app's own minimise and maximise buttons on niri

X11 apps (Steam, for one) run on niri through xwayland-satellite, which passed on only full screen:
their own minimise and maximise buttons did nothing (close worked: the app closes its own window).
This patch passes maximise (`_NET_WM_STATE_MAXIMIZED_*`) and minimise (ICCCM's `WM_CHANGE_STATE`
to Iconic) on to the compositor as Wayland's own requests, and writes the maximised state back so
the app's button shows the right way round. With niri-minimize.patch, Monolith's Desktop mode then
minimises the window. Made for xwayland-satellite 0.8.3; the installer's niri extras build it. On
Gentoo:

    sudo mkdir -p /etc/portage/patches/gui-apps/xwayland-satellite-0.8.3
    sudo cp xwayland-satellite-wm-buttons.patch /etc/portage/patches/gui-apps/xwayland-satellite-0.8.3/
    sudo emerge --oneshot gui-apps/xwayland-satellite

then open the app again (niri starts xwayland-satellite when an X11 app needs it; log out and in
to be sure the new one runs).
