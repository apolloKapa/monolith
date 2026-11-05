# Monolith (next) — feature spec and design

This folder is the from-scratch rewrite of Monolith's shell. It is written from this
spec, not by editing or translating the current shell's files (which are a Serpantinum
derivative). The current shell keeps running until this one covers everything below.

License: GPL-3.0-only (see LICENSE in this folder).

## Design: "Hub"

Monolith stops being a bar with panels hanging off it. It has two things on screen:

1. **Status line** — a thin line across the top of each screen with no panel behind it:
   text and glyphs sit on a soft scrim fading down from the screen edge. Left: time and
   workspaces. Right: tray, system stats, network, sound, battery. Everything in it is a
   shortcut into the hub.
2. **The hub** — one floating card, centred, that holds every surface as a *page*:
   Search, Quick, Notifications, Media, Calendar, Network, Sound, Clipboard, Power…
   Opening a different page doesn't open a new panel: the hub morphs (size, content)
   into it. Pages are tabs along the hub's header, and keyboard-first (type to search
   from any page, Tab / Shift+Tab between pages, Esc closes).

Visual language:
- Tonal layers from the palette (wallpaper colours via the existing matugen output):
  backdrop → card → container → control. No outlines except a hairline on the card.
- Corners from the border-radius setting, concentric (outer = inner + gap).
- Round icon bubbles lead every row and tile; selection is a tonal fill that glides.
- Material motion: emphasized-decelerate in (500 ms), emphasized-accelerate out (200 ms);
  the hub's size change is the main animation. Touch feedback is an ink ripple.
- Font: the user's chosen font (theme setting), never forced.

## Features to cover (everything the current shell does)

Status line / bar
- Workspaces (niri), focused window title, clock + date, weather, system stats
  (CPU, RAM, temp, GPU, disk), media now-playing + visualiser, tray, keyboard layout,
  Wi-Fi, Bluetooth, volume, battery; per-monitor enable; position top/bottom/side;
  autohide; module order and grouping (Settings).

Hub pages
- Search: apps (smart ranking by usage, favourites pinned + reorderable, grid/list),
  files (home search, path browsing), emojis (groups, search), `>` commands in a
  terminal, calculator (copy result), widgets/commands entries.
- Quick: volume + brightness sliders, toggles (Wi-Fi, Bluetooth, airplane, night light,
  stay awake/caffeine, do not disturb, game mode), power profile, lock / suspend /
  reboot / power off / log out, user + settings shortcut, battery card on laptops.
- Notifications: history, groups, actions, images, swipe/clear, DND, mute; popups
  (position setting, sounds, urgency).
- Media: MPRIS player, art, seek, controls, output switch, equaliser + presets,
  balance/audio view, lyrics (synced, picker).
- Calendar: clock, month view, day/year progress, weather (current, hourly, days).
- Network: Wi-Fi list/connect/forget/password, Ethernet, Bluetooth devices/pairing.
- Sound: outputs, inputs, per-app streams, default device, per-device volume/mute.
- Clipboard history (text + images, search, pin, delete).
- Power/session menu.

Other surfaces
- Launcher behaviour (above) also on its own key; emoji picker key.
- Dock (pinned + running apps, previews/menus, autohide, edit mode, app picker).
- OSD (volume, brightness, caps/num lock, keyboard layout, airplane, etc.).
- Lock screen (PAM, fingerprint, layout redactor, widgets, media), idle actions.
- Wallpaper picker (dirs, video wallpapers, matugen colours), desktop widgets
  (clock, calendar, weather, music, notes, github, image, usage, user, battery,
  visualiser) + widget redactor/presets.
- Overview, window switcher, cheatsheet (niri keybinds), dashboard (focus timer, todo).
- Screenshot overlay (region/window/screen, editing, OCR, recording), polkit agent,
  island, quick actions (edge panels: calculator, converter, notes, timer, draw,
  dock, usage), digital wellbeing (stats, limits), first launch, updater, zoom.
- Settings app: every tab of the current one (General, Display, Peripherals, Theme incl.
  styles/presets/fonts/icons/cursors/apps/animations/effects, Bar, Dock, Launcher,
  Software: AppImages/Autostart/Cleanup, Quick actions, OSD, Screenshots,
  Notifications, Idle, Wellbeing, About).

## Stages

1. Core (theme, config, niri, time, audio) + status line + hub host with Search,
   Quick, Calendar, Media pages.  ✓
2. Notifications (server + popups + page), Sound, Network, Clipboard pages; dock; OSD.  ✓
   (still to add from this stage: notification sounds/position, dock menus/edit mode/
   app picker, OSD for brightness/caps/num lock, image previews in Clipboard,
   EQ/lyrics in Media, weather in Calendar, file/emoji search, usage ranking)
3. Lock screen, idle, wallpaper picker, Settings app.  ✓
   (Settings is a hub page; so far: appearance, wallpaper, lock & idle, notifications,
   dock, about. Still to bring over: every other tab of the current Settings app,
   video wallpapers, per-screen wallpapers, lock-screen layouts/widgets, fingerprint
   prompt text, rounded avatar mask)
4. Everything else in the list above; then switch the installer to it.  ← in progress
   Done: weather (status line, Calendar, widget), Windows page (overview + switcher),
   Capture (screenshots, OCR, recording), Keys (niri keybinds cheatsheet), Tools (timer,
   notes, converter), polkit agent, desktop widgets (clock, weather, now playing; move mode),
   Search: usage ranking, `:` emojis (tools/make_emoji.py from Unicode data), `/` `~` files,
   IPC `hub search <text>`.
   Also done: digital wellbeing (screen time, week, limits), media lyrics (LRCLIB) and
   equaliser (EasyEffects preset), video/GIF + per-screen wallpapers, dock menu + own pinned
   list, notification sounds and position, bin/monolith-next (try / back).
   Also done (2026-11-05, second pass): island (recording / timer / updates in the status
   line's middle), first-launch welcome (Settings → welcome), updater (git fetch + ff-only pull,
   Settings → About), zoom (wooz), more widgets (calendar, usage, notes, picture), Settings has
   15 sections (appearance incl. icons/cursor, wallpaper, status line, dock, desktop, search,
   notifications, OSD, displays, keyboard & mouse, lock & idle, screenshots, software =
   startup apps + AppImages, wellbeing, about); niri settings via shell/scripts/niri_conf.py;
   bin/monolith-next answers the current Monolith's keybind verbs, `try` points the keybinds
   at it, `keep` also starts it at login (startup apps included), `back` undoes both.
   Installer: deploys this shell to ~/.local/share/monolith-next (`monolith-next` in
   ~/.local/bin) next to the classic one; its menu has "Shell: new / classic" (fresh installs:
   new; existing installs keep theirs, remembered in ~/.local/state/monolith/shell) and points
   the keybinds and login at the choice (`monolith-next adopt` / `release`). Updates of an
   installed copy go through `monolith installer --update` (shell/scripts/updates.sh).
   Memory: the hub builds pages only on the screen it's open on, each when first opened, and
   lets them go when it closes (idle ~270 MB vs ~416 MB with every page built).
