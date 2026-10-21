# Monolith

**really good desktop :3**

My Arch Linux desktop: [niri](https://github.com/YaLTeR/niri) running **Monolith**, my [Quickshell](https://quickshell.org) desktop shell, plus my niri config, keybinds and helper scripts.

> **INSPIRED BY SERPANTINUM BY [@ilyamiro](https://github.com/ilyamiro)**
>
> Monolith is a fork of [Serpantinum](https://github.com/ilyamiro/serpantinum) and keeps its licence (AGPL-3.0, see [`LICENSE`](LICENSE)).

---

## Install

One command, on Arch or an Arch-based distro (CachyOS, EndeavourOS, ...), as your normal user:

```sh
curl -fsSL https://raw.githubusercontent.com/apolloKapa/monolith/main/install/get.sh | bash
```

While the repo is **private**, that URL needs a login, so use the GitHub CLI instead:

```sh
gh auth login   # once
gh api "repos/apolloKapa/monolith/contents/install/get.sh?ref=main" -H "Accept: application/vnd.github.raw" | bash
```

Or from a clone: `git clone https://github.com/apolloKapa/monolith && ./monolith/install.sh`.

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
| Wallpapers | 3 random | 3 random / full pack / none, from my [wallpapers](https://github.com/apolloKapa/wallpapers) repo (skipped if it doesn't exist; `WALLPAPER_REPO=` to use another) |
| Install / Update / Reinstall | | Update keeps your settings; Reinstall starts them fresh |

Then it:

1. installs the packages (official repos via pacman, AUR via yay/paru; it builds yay if you have neither), plus the Iosevka Nerd Font
2. **replaces Serpantinum** if it's installed: stops it, moves its files and any compositor config that mentions it (Hyprland, Sway, ...) into `~/serpantinum-backup-<date>/`, points those configs at Monolith, and removes its system-wide bits
3. installs the shell into `~/.local/share/monolith` and links `monolith` and `monolithd` into `~/.local/bin`
4. copies the helper scripts (`bin/`) into `~/.local/bin` and the rofi config into `~/.config/rofi`
5. adds `/etc/pam.d/monolith`, so the lock screen can check your password
6. writes the niri config (old one backed up), generates the display and workspace setup from the monitors it finds, and makes niri the default login session
7. sets up SDDM and wallpapers, if picked
8. creates `~/.config/monolith/settings.json` from the defaults in `config/monolith/settings.json` (an existing one is kept)
9. enables PipeWire, NetworkManager, power-profiles-daemon and EasyEffects
10. **starts Monolith right away** if you run it from inside a desktop session, so no reboot is needed

There's no telemetry in the installer or the shell.

---

## Where to change things

niri reloads its config as soon as you save, so keybind/monitor/layout edits apply right away. The files below are in `~/.config/niri/config/`; the repo copies are in `monolith/compositors/niri/config/` (edit those too if you want the change on every machine).

| What | Where |
|---|---|
| **Keybinds** | `keybinds.kdl` (`Mod+Shift+/` lists them all) |
| **Monitors**: resolution, refresh rate, position, scale, rotation, on/off | `output.kdl` (`niri msg outputs` shows names and modes). Settings → Display changes them live but doesn't save; `monolith installer` regenerates this file from your current setup |
| **Workspaces** (and which monitor they live on) | `workspaces.kdl` |
| **Keyboard layouts, mouse, touchpad, cursor** | `input.kdl` |
| **Apps that start with niri** | `autostart.kdl` |
| **Gaps, column widths, window borders, animations** | `layout.kdl`, or Settings → Theme → Windows / Animations |
| **Window rules** (floating, sizes, rounded corners) | `rules.kdl` |
| **Environment variables** | `env.kdl` |
| **Shell look**: theme, style, font, bar, dock, launcher, notifications, idle | Settings (`Mod+S`), saved in `~/.config/monolith/settings.json` |
| **Wallpapers** | `~/Pictures/Wallpapers`, pick with `Mod+W` |
| **Helper scripts** (focuswin, snap, setwall, ...) | `~/.local/bin` (repo: `bin/`) |

After editing a niri file, `niri validate` tells you if something's wrong.

## The shell

Everything below is built in.

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

**Wallpapers** (`Mod+W`): picker with transitions, video wallpapers, and online search (DuckDuckGo, only when you search).

**Desktop widgets**: clock, music, system usage, weather, battery, image, GitHub contributions, user, visualizer. There's a drag-and-drop widget editor.

**Lock screen** (`Mod+L`): password and fingerprint. Layout editor for avatar, user, battery, keyboard layout, notifications and lock status.

**Idle**: dim, screen off, lock and suspend timers, with media/inhibitor awareness.

**Other**: screenshots (region / window / full, with editing), polkit password prompts, blue-light filter, brightness (incl. external monitors via ddcutil), first-launch intro and tutorial, 23 languages.

**Settings** (`Mod+S`):

- Welcome
- General: language, location, weather units, sounds
- Display: monitors, widgets, lock screen
- Theme: 97 colour presets, colours from your wallpaper (matugen), fonts, corner radius, opacity, and the surface style **Blur / Liquid glass / Minimalist**
- Theme → Animations: animations on/off, Slow / Normal / Fast, fine speed (50–200%), live preview, and the same speed for niri's window animations
- Theme → Windows: niri window borders on/off, width, colours for focused / other / attention windows (theme swatches or any hex), or follow the theme's colours automatically
- Bar: general and modules
- Launcher, Dock, On-screen display, Notifications
- Wellbeing: screen-time stats
- Idle
- About: your system, update button

### What Monolith changes

- **Minimalist style**, next to Blur and Liquid glass in Settings → Theme. Flat opaque panels, square corners, 2px `#555` outlines, white accent with inverted hover, JetBrains Mono. It's my old Quickshell look. The squares and outlines only apply while Minimalist is picked; every other style is unchanged.
- **Private**:
  - no telemetry
  - no IP geolocation and no reverse geocoding; weather uses the location you set in Settings → General and only sends those coordinates to open-meteo
  - lyrics only from lrclib (NetEase removed)
  - things that still go online only do so when you use them: lyrics, YouTube cover art, the GitHub widget, wallpaper search, the Wi-Fi login-page button
- **Its own look and voice**: Monolith logo, horizon intro ("really good desktop :3"), Lith the sleepy slab mascot (replaces the Pusheen GIFs), own name and paths
- **Installer**: niri-focused, with my keybinds as defaults, generated display/workspace config, `monolith installer`
- **Animation controls**: one speed setting for every shell animation (and optionally niri's), or turn them off
- **Updates** come from this repo (no automatic update checks)

---

## niri config

Modular config in `~/.config/niri/` (source: `monolith/compositors/niri/`):

| File | Contents |
|---|---|
| `config.kdl` | includes the files below |
| `config/env.kdl` | `prefer-no-csd`, environment variables (qt6ct, Niri session vars) |
| `config/input.kdl` | keyboard (us + gr, Alt+Shift switches), numlock, flat mouse accel, focus follows mouse, Breeze cursor |
| `config/output.kdl` | **generated**: each monitor's current mode, position, scale, rotation; disabled monitors set to `off` |
| `config/workspaces.kdl` | **generated**: workspaces 1 to 10 on the main monitor, `d2-1` to `d2-10` on a second one, each pinned to its monitor so they return there after it was off |
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
| `Mod+W` / `Mod+Alt+W` | wallpapers |
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
| `Mod+Shift+W` | tabbed column |
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
| `monolith installer --update` | update without the menu (what Settings → About → Update runs) |
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

**Publishing a Monolith update** (shell or installer changes):

1. edit the files under `monolith/` or `install/`
2. bump the version in `monolith/version.txt` (e.g. `1.2.0` → `1.3.0`)
3. commit and push to the branch your machines install from (`monolith` right now; it's in `~/.local/share/monolith/install/source.env`)

Every machine checks once an hour. When the version on GitHub is newer, you get a notification and Settings → About shows **Update available**. **Update** opens a terminal and runs `monolith installer --update`: it refreshes the shell and scripts, installs any new dependencies, keeps your settings, niri config, login screen and wallpapers, and restarts the shell. You can also run `monolith installer --update` yourself any time.

While the repo is private, the update check goes through the GitHub CLI (`gh auth login` once per machine).

**Your own config changes**: niri files live in `monolith/compositors/niri/config/` (don't commit `output.kdl` / `workspaces.kdl`, they're generated per machine); helper scripts in `bin/`.

## Troubleshooting

- **Bar or panels don't appear:** run `monolith -v restart` in a terminal to see errors. Logs are in `$XDG_RUNTIME_DIR/monolith/logs`.
- **`qs: command not found`:** `sudo pacman -S quickshell qt6-wayland`.
- **No weather:** set your location in Settings → General. Monolith never detects it automatically.
- **Wrong monitor layout:** run `monolith installer` from inside niri, or edit `~/.config/niri/config/output.kdl`, then `niri validate`.
- **Lock screen won't accept your password:** check `/etc/pam.d/monolith` exists (the installer adds it). If you're ever stuck, switch to a TTY (Ctrl+Alt+F3), log in, and run `monolithd stop`.
- **Nvidia:** my desktop used the legacy GTX 1070 driver (`nvidia-dkms-580xx`). Drop GPU drivers that don't fit from `packages.txt` before choosing "All my apps".

## Licence

[GNU AGPL-3.0](LICENSE). Monolith is a fork of Serpantinum by @ilyamiro, which is AGPL-3.0 too. You can use, change and share it; if you share a modified version (or run it for others over a network), share its source under the same licence.
