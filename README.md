# Monolith

**really good desktop :3**

My Arch Linux desktop: [niri](https://github.com/YaLTeR/niri) running **Monolith**, my [Quickshell](https://quickshell.org) desktop shell, plus my niri config, keybinds and helper scripts.

> **INSPIRED BY SERPANTINUM BY [@ilyamiro](https://github.com/ilyamiro)**
>
> Monolith is a fork of [Serpantinum](https://github.com/ilyamiro/serpantinum) and keeps its licence (AGPL-3.0, see `monolith/LICENSE.md`). The installer is also adapted from Serpantinum's.

---

## Install

One command, on Arch or an Arch-based distro (CachyOS, EndeavourOS, ...), as your normal user:

```sh
curl -fsSL https://raw.githubusercontent.com/kasc0b3r/dotfiles/main/install/get.sh | bash
```

While the repo is **private**, that URL needs a login, so use the GitHub CLI instead:

```sh
gh auth login   # once
gh api "repos/kasc0b3r/dotfiles/contents/install/get.sh?ref=main" -H "Accept: application/vnd.github.raw" | bash
```

Or from a clone: `git clone https://github.com/kasc0b3r/dotfiles && ./dotfiles/install.sh`.

Once it's installed, **`monolith installer`** opens the installer again to update, reinstall or change options. Settings → About → Update does the same.

### What the installer does

It opens a menu (arrow keys or j/k, Enter, q to quit):

| Option | Default | What it is |
|---|---|---|
| Packages overview | | everything it's about to install, and what you already have |
| Apps for the keybinds | ON | what the keybinds/autostart call: librewolf, thunar, mission-center, rofi, steam, wooz, awww, swaylock, swappy, grim/slurp, cliphist, playerctl, brightnessctl, fonts, ... |
| All my apps | OFF | everything in `packages.txt` and `packages-aur.txt` |
| niri config | Monolith config | writes the niri config below (your old one is backed up to `~/.config/niri_backup/`); or "keep mine" |
| Login screen | ON | SDDM theme, with options to replace your current display manager and use Wayland for SDDM |
| Wallpapers | 3 random | 3 random / full pack / none, from the public [shell-wallpapers](https://github.com/ilyamiro/shell-wallpapers) repo |
| Install / Update / Reinstall | | Update keeps your settings; Reinstall starts them fresh |

Then it:

1. installs the packages (official repos via pacman, AUR via yay/paru; it builds yay if you have neither), plus the Iosevka Nerd Font
2. installs the shell into `~/.local/share/monolith` and links `monolith` and `monolithd` into `~/.local/bin`
3. copies the helper scripts (`bin/`) into `~/.local/bin` and the rofi config into `~/.config/rofi`
4. adds `/etc/pam.d/monolith`, so the lock screen can check your password
5. writes the niri config and generates the display and workspace setup from the monitors it finds
6. sets up SDDM and wallpapers, if picked
7. creates `~/.config/monolith/settings.json`. It keeps yours if you already have one, carries over your Serpantinum settings if Serpantinum is installed, or else uses the defaults in `config/monolith/settings.json`
8. enables PipeWire, NetworkManager, power-profiles-daemon and EasyEffects

There's no telemetry in the installer or the shell.

---

## The shell

Everything from Serpantinum, plus Monolith's own changes.

**Bar**: top or side, fill / floating / pill styles, autohide. Modules: workspaces, media, time & date, weather, system info, tray, Wi-Fi, Bluetooth, volume, battery, keyboard layout, system monitor (CPU/RAM/temp/disk), audio visualizer, current window, quick buttons. Editable in Settings → Bar.

**Dock**: pinned and running apps, autohide or smart autohide, any edge.

**Launcher** (`Mod+Z` / `Mod+Space`): tabs for apps (with smart ranking), files and emojis.

**Panels and popups**:

- System panel (`Mod+D`): user card, volume and brightness, toggles (night light, caffeine, Wi-Fi, Bluetooth, airplane), notification centre, lock / suspend / reboot / power off, power profiles
- Notifications: popups, history, do-not-disturb, sounds
- Network (`Mod+N`): Wi-Fi, Bluetooth, Ethernet
- Volume mixer (`Mod+V`)
- Music (`Mod+Alt+M`): player controls, synced lyrics, cover art
- Clipboard history (`Mod+Alt+C`)
- Calendar
- On-screen display for volume, brightness and caps/num lock
- Quick actions: calculator, notes, timer, drawing, system usage, dock

**Wallpapers** (`Mod+Alt+W`): picker with transitions, video wallpapers, and online search (DuckDuckGo, only when you search).

**Desktop widgets**: clock, music, system usage, weather, battery, image, GitHub contributions, user, visualizer. There's a drag-and-drop widget editor.

**Lock screen** (`Mod+L`): password and fingerprint. Layout editor for avatar, user, battery, keyboard layout, notifications and lock status.

**Idle**: dim, screen off, lock and suspend timers, with media/inhibitor awareness.

**Other**: screenshots (region / window / full, with editing), polkit password prompts, blue-light filter, brightness (incl. external monitors via ddcutil), first-launch intro and tutorial, 23 languages.

**Settings** (`Mod+S`):

- Welcome
- General: language, location, weather units, sounds
- Display: monitors, widgets, lock screen
- Theme: 97 colour presets, colours from your wallpaper (matugen), fonts, corner radius, opacity, and the surface style **Blur / Liquid glass / Minimalist**
- Bar: general and modules
- Launcher, Dock, On-screen display, Notifications
- Wellbeing: screen-time stats
- Idle
- About: your system, update button

### What Monolith changes

- **Minimalist style**, next to Blur and Liquid glass in Settings → Theme. Flat opaque panels, square corners, 2px `#555` outlines, white accent with inverted hover, JetBrains Mono. It's my old Quickshell look. The squares and outlines only apply while Minimalist is picked; every other style is exactly as in Serpantinum.
- **Private**:
  - no telemetry
  - no IP geolocation and no reverse geocoding; weather uses the location you set in Settings → General and only sends those coordinates to open-meteo
  - lyrics only from lrclib (NetEase removed)
  - things that still go online only do so when you use them: lyrics, YouTube cover art, the GitHub widget, wallpaper search, the Wi-Fi login-page button
- **Its own look and voice**: Monolith logo, horizon intro ("really good desktop :3"), Lith the sleepy slab mascot (replaces the Pusheen GIFs), own name and paths
- **Installer**: niri-focused, with my keybinds as defaults, generated display/workspace config, Serpantinum settings migration, `monolith installer`
- **Updates** come from this repo (no automatic update checks)

---

## niri config

Serpantinum-style modular config in `~/.config/niri/` (source: `monolith/compositors/niri/`):

| File | Contents |
|---|---|
| `config.kdl` | includes the files below |
| `config/env.kdl` | `prefer-no-csd`, environment variables (qt6ct, Niri session vars) |
| `config/input.kdl` | keyboard (us + gr, Alt+Shift switches), numlock, flat mouse accel, focus follows mouse, Breeze cursor |
| `config/output.kdl` | **generated**: each monitor's current mode, position, scale, rotation; disabled monitors set to `off` |
| `config/workspaces.kdl` | **generated**: workspaces 1 to 10, plus `d2-1` to `d2-10` on a second monitor |
| `config/layout.kdl` | 10px gaps, column presets, 2px white/grey borders, no focus ring, no hot corners, snappy spring animations |
| `config/autostart.kdl` | Steam (silent), clipboard history, awww + setwall, EasyEffects, `monolithd start` |
| `config/keybinds.kdl` | the keybinds below |
| `config/rules.kdl` | rounded window corners, windows open floating, Roblox Studio helper windows hidden, Steam toasts as notifications, kitty default size |

The installer reads displays from the running niri. If you install from a TTY, nothing is pinned and niri picks each monitor's preferred mode; run `monolith installer` from inside niri later to pin the layout. The Display page in Settings can also change monitors live.

## Keybinds

`Mod` is the Super/Windows key. `Mod+Shift+/` shows niri's own list.

**Apps**

| Key | Action |
|---|---|
| `Mod+C` | terminal (kitty) |
| `Mod+B` | browser (LibreWolf) |
| `Mod+E` | files (Thunar) |
| `Mod+Escape` | Mission Center |
| `Mod+Z` / `Mod+Space` | launcher |
| `Mod+Tab` | window switcher (rofi) |
| `Mod+Alt+V` | clipboard history (rofi) |
| `Mod+Alt+S` | pick wallpaper (setwall) |
| `Mod+Ctrl+Z` | zoom (wooz) |

**Monolith**

| Key | Action |
|---|---|
| `Mod+D` | system panel |
| `Mod+S` / `Mod+Alt+H` | settings |
| `Mod+N` | network |
| `Mod+V` | volume mixer |
| `Mod+A` | bar autohide |
| `Mod+Alt+C` | clipboard |
| `Mod+Alt+M` | music |
| `Mod+Alt+W` | wallpapers |
| `Mod+L` / `Mod+Alt+L` | lock |
| `Mod+Ctrl+Alt+L` | swaylock |

**Windows**

| Key | Action |
|---|---|
| `Mod+Q` | close |
| `Mod+Arrows` | focus window in that direction (stays on this monitor) |
| `Mod+H` / `J` / `K` | focus column left / window down / up |
| `Mod+Shift+Arrows` | swap with the window in that direction (`swapwin`) |
| `Mod+Ctrl+Arrows` | snap floating window to that half (`snap`) |
| `Mod+Ctrl+H/J/K/L` | move column / window |
| `Mod+R` | float ↔ tile (tiled at half width) |
| `Mod+T` | tile and maximize |
| `Mod+F` / `Mod+Shift+F` | fullscreen / maximize column |
| `Mod+Ctrl+F` | expand column to available width |
| `Mod+Ctrl+C` | center visible columns |
| `Mod+-` / `Mod+=` | column width -/+ 10% |
| `Mod+Shift+-` / `Mod+Shift+=` | window height -/+ 10% |
| `Mod+Shift+R` / `Mod+Ctrl+Shift+R` / `Mod+Ctrl+R` | preset widths back / preset heights / reset height |
| `Mod+[` / `Mod+]` | consume or expel window left / right |
| `Mod+,` / `Mod+.` | consume into column / expel from column |
| `Mod+W` | tabbed column |
| `Mod+Shift+V` | switch focus floating ↔ tiling |
| `Mod+Home` / `Mod+End` | first / last column (`+Ctrl` moves it) |

**Workspaces and monitors**

| Key | Action |
|---|---|
| `Mod+1` to `Mod+0` | workspace 1 to 10 |
| `Mod+Ctrl+1-0` / `Mod+Shift+1-0` | move column to workspace |
| `Mod+Page Up/Down`, `Mod+U` | workspace up / down (`+Ctrl` moves the column, `Mod+Ctrl+I` up) |
| `Mod+Scroll` | workspace up / down (`+Ctrl` moves the column), sideways scroll = columns |
| `Mod+O` | overview |
| `Mod+Alt+Arrows`, `Mod+Shift+H/J/K/L` | focus monitor |
| `Mod+Shift+Ctrl+Arrows` / `H/J/K/L` | move column to monitor |
| `Mod+Shift+P` | turn monitors off |

**System**

| Key | Action |
|---|---|
| `Print` / `Ctrl+Print` / `Alt+Print` | screenshot region / screen / window |
| `Mod+Shift+S` | region screenshot into swappy |
| media / volume / mic / brightness keys | work as labelled (also on the lock screen) |
| `Mod+M`, `Mod+Shift+E`, `Ctrl+Alt+Delete` | quit niri |

## Commands

| Command | What it does |
|---|---|
| `monolith installer` | open the installer (update, reinstall, change options) |
| `monolithd start` / `stop` / `status` | run / stop the shell |
| `monolith restart` / `kill` | restart / stop the shell |
| `monolith msg toggle <panel>` | open/close `launcher`, `system`, `guide`, `network`, `volume`, `music`, `clipboard`, `wallpaper`, `calendar`, `autohide` |
| `monolith msg workspace <n> [move]` | go to / move to workspace |
| `monolith lock` | lock screen |
| `monolith screenshot [--full] [--edit]` | screenshot |
| `monolith volume raise\|lower\|mute-toggle\|mic-toggle` | volume with on-screen display |
| `monolith brightness raise\|lower` | brightness with on-screen display |
| `monolith reload` | reload the shell |
| `monolith location_manual <lat> <lon> [city]` | set your location for weather |
| `monolith -v ...` | verbose output |

Helper scripts in `bin/` (installed to `~/.local/bin`):

- `focuswin`, `swapwin`, `snap`: window focus, swap and snapping
- `tilehalf`, `maxtoggle`: float/tile and maximize toggles
- `setwall`: wallpaper via awww (`setwall pick` = rofi chooser)
- `launcher`, `favlauncher`, `rofi-apps`, `rofi-favs`: rofi launcher with favourites (Ctrl+S stars an app)
- `gparted-dark`, `osu-wine`, `cosu-launch.sh`, `roblox-studio-mcp`: app launchers

## Repo layout

| Path | Contents |
|---|---|
| `install/` | the installer: `get.sh` (one-command), `install.sh`, `modules/` |
| `install.sh` | runs `install/install.sh` from a clone |
| `monolith/bin/` | `monolith` and `monolithd` |
| `monolith/src/` | the shell: QML (`quickshell/`), scripts, assets (themes, fonts, sounds, languages, shaders) |
| `monolith/compositors/niri/` | the niri config |
| `monolith/sddm/` | the SDDM login theme |
| `config/monolith/settings.json` | default shell settings |
| `config/rofi/`, `config/wallpaper` | rofi theme + favourites, setwall state |
| `bin/` | helper scripts |
| `packages.txt`, `packages-aur.txt` | all my apps (the installer's "All my apps" option) |

Installed files: shell in `~/.local/share/monolith`; settings in `~/.config/monolith`; state, cache and logs in `~/.local/state/monolith`, `~/.cache/monolith` and `$XDG_RUNTIME_DIR/monolith`.

## Updating the repo

Shell or installer changes: edit them here, commit and push, then run `monolith installer` → Update on any machine.

niri config changes: edit `monolith/compositors/niri/config/*.kdl` (or copy them back from `~/.config/niri/config/`). Don't commit `output.kdl` or `workspaces.kdl`; they're generated per machine.

## Troubleshooting

- **Bar or panels don't appear:** run `monolith -v restart` in a terminal to see errors. Logs are in `$XDG_RUNTIME_DIR/monolith/logs`.
- **`qs: command not found`:** `sudo pacman -S quickshell qt6-wayland`.
- **No weather:** set your location in Settings → General. Monolith never detects it automatically.
- **Wrong monitor layout:** run `monolith installer` from inside niri, or edit `~/.config/niri/config/output.kdl`, then `niri validate`.
- **Lock screen won't accept your password:** check `/etc/pam.d/monolith` exists (the installer adds it). If you're ever stuck, switch to a TTY (Ctrl+Alt+F3), log in, and run `monolithd stop`.
- **Serpantinum is installed too:** don't run both at once. The niri config only starts `monolithd`.
- **Nvidia:** my desktop used the legacy GTX 1070 driver (`nvidia-dkms-580xx`). Drop GPU drivers that don't fit from `packages.txt` before choosing "All my apps".
