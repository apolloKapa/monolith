# Monolith

**really good desktop :3**

My Linux desktop (Arch or Gentoo): [niri](https://github.com/YaLTeR/niri) running **Monolith**, my [Quickshell](https://quickshell.org) desktop shell, plus my niri config, keybinds and helper scripts.

---

## Preview

**Quick**: volume, toggles and power, one of the hub's pages

![Quick](docs/media/quick.jpg)

**Settings**, also in the hub

![Settings](docs/media/settings.jpg)

---

## Install

One command, on Arch or an Arch-based distro (CachyOS, EndeavourOS, ...) or on Gentoo, as your normal user:

```sh
curl -fsSL https://raw.githubusercontent.com/apolloKapa/monolith/main/install/get.sh | bash
```

Once it's installed, **`monolith installer`** opens the installer again to update, reinstall or change options. Settings → About → Update does the same, and the status line shows when there's an update.

### What the installer does

It opens a menu (arrow keys or j/k, Enter, q to quit):

| Option | Default | What it is |
|---|---|---|
| Packages overview | | everything it's about to install, and what you already have |
| Apps for the keybinds | ON | what the keybinds/autostart call: librewolf, thunar, mission-center, steam, wooz, awww, swaylock, swappy, grim/slurp, cliphist, playerctl, brightnessctl, fonts, ... |
| niri config | Monolith config | writes the niri config below (your old one is backed up to `~/.config/niri_backup/`); or "keep mine" |
| Login screen | ON | SDDM theme, with options to replace your current display manager and use Wayland for SDDM |
| Wallpapers | 3 random | 3 random / full pack / none, from my [wallpapers](https://github.com/apolloKapa/wallpapers) repo (skipped if it doesn't exist; `WALLPAPER_REPO=` to use another) |
| Install / Update / Reinstall | | Update keeps your settings; Reinstall starts them fresh |

Then it:

1. installs the packages, plus the Iosevka Nerd Font:
   - **Arch**: official repos via pacman, AUR via yay/paru (it builds yay if you have neither)
   - **Gentoo**: Portage, all built from source. It enables the `::guru` overlay (niri, Quickshell, matugen, ...) and `::librewolf`, and keeps its Portage settings in `/etc/portage/package.use/monolith`, `package.accept_keywords/monolith` and `zz-monolith-autounmask` files. Those `monolith` files are rewritten on every update, so put your own lines in other files. Installed packages whose USE flags Monolith changes are rebuilt (util-linux gets `caps` for `setpriv`), and LibreWolf is pinned to the LLVM your Rust was built with, so it doesn't drag in a chain of older Rust versions. wooz and wl-gammarelay-rs have no ebuild, so they're built from source into `~/.local`. A fresh install syncs Portage but doesn't run a full `@world` update; run `sudo emerge -avuDN @world` yourself when you like.
2. installs the shell into `~/.local/share/monolith` and links `monolith` into `~/.local/bin` (an older install's classic shell and `monolithd` are replaced)
3. puts the bundled icon packs (YAMIS) into `~/.local/share/icons`, keeping any of the same name you added yourself
4. adds `/etc/pam.d/monolith`, so the lock screen can check your password
5. writes the niri config (old one backed up) and generates the display and workspace setup from the monitors it finds
6. sets up SDDM and wallpapers, if picked (the SDDM theme is off by default when you already use another one)
7. creates `~/.config/monolith/settings.json` from the defaults in `config/monolith/settings.json` (an existing one is kept); the shell reads its dock apps, terminal, font and wallpaper folder from it until you change them in Settings
8. enables PipeWire, NetworkManager, power-profiles-daemon and EasyEffects
9. **starts Monolith right away** if you run it from inside niri (from any other session it waits until you log into niri), so no reboot is needed

**Other shells stay as they are.** Monolith is a separate shell with its own files, and it only runs in niri. If Serpantinum (or anything else) is installed, it isn't stopped, moved or edited, and your Hyprland/Sway/other configs aren't touched. fastfetch always gets Monolith's look; the config that was there before is kept as `~/.config/fastfetch/config.jsonc.pre-monolith`. The installer also makes kitty show it when it opens: fish gets `~/.config/fish/conf.d/monolith-fastfetch.fish`, bash/zsh a marked block at the end of `~/.bashrc`/`~/.zshrc` (skipped if your shell already runs fastfetch; remove it and updates won't add it back).

There's no telemetry in the installer or the shell.

---

## Where to change things

niri reloads its config as soon as you save, so keybind/monitor/layout edits apply right away. The files below are in `~/.config/niri/config/`; the repo copies are in `config/niri/config/` (edit those too if you want the change on every machine).

| What | Where |
|---|---|
| **Keybinds** | `keybinds.kdl` (`Mod+Shift+/` lists them all) |
| **Monitors**: resolution, refresh rate, position, scale, rotation, on/off | `output.kdl` (`niri msg outputs` shows names and modes). Settings → Displays sets on/off, resolution, refresh rate and scale here; `monolith installer` regenerates this file from your current setup |
| **Workspaces** (and which monitor they live on) | `workspaces.kdl` |
| **Keyboard layouts, mouse, touchpad, cursor** | `input.kdl`, or Settings → Keyboard & mouse / Appearance |
| **Apps that start with niri** | `autostart.kdl` |
| **Gaps, column widths, window borders, animations** | `layout.kdl` |
| **Window rules** (floating, sizes, rounded corners) | `rules.kdl` |
| **Environment variables** | `env.kdl` |
| **The shell**: colours, corners, font, status line, dock, widgets, notifications, idle, startup apps | Settings (`Mod+S`), saved in `~/.config/monolith/next.json` |
| **Wallpapers** | `~/Pictures/Wallpapers`, pick with `Mod+W` |
| **Helper scripts** (focuswin, snap, ...) | `~/.local/bin` (repo: `bin/`) |

After editing a niri file, `niri validate` tells you if something's wrong.

## The shell

Two things on screen:

- **The status line**: a thin row across the top (or bottom) of each screen, on a soft fade instead of a bar: time, date and weather, workspaces, the focused window, now playing, system stats, tray, network, notifications and volume. Each part opens its page. Its middle is the **island**: while a recording runs or the timer counts down it shows that (click a recording to stop it), and it says when there's an update.
- **The hub**: one floating card that holds every page. Opening another page morphs the card into it instead of opening a new panel. Type on any page to search; Tab / Shift+Tab move between pages, Esc closes.

The pages:

| Page | What's on it |
|---|---|
| Search | apps (the ones you open most come first), `>` a command in the terminal, `:` emojis, `/` or `~` files, a calculator |
| Quick | volume and mic, Wi-Fi, Bluetooth, night light, stay awake, airplane mode, keyboard layout, lock / suspend / log out / reboot / power off |
| Notifications | history, actions, do not disturb |
| Media | the player, synced lyrics (LRCLIB), a 10-band equaliser (EasyEffects) |
| Calendar | the month, the weather now, by hour and by day |
| Sound | outputs, inputs, each app's volume |
| Network | Wi-Fi (connect, forget, passwords), Ethernet, Bluetooth devices |
| Clipboard | text and image history |
| Windows | every window, switch or close |
| Capture | screenshots (region, screen, window), text from a region (OCR), screen recording |
| Tools | timer, notes, unit converter |
| Wellbeing | screen time per app, the week, daily limits |
| Keys | every niri keybind, searchable |
| Wallpaper | pictures and videos (also per screen); the colours come from the wallpaper (matugen) |
| Settings | appearance, wallpaper, status line, dock, desktop widgets, search, notifications, on-screen display, displays, keyboard & mouse, lock & idle, screenshots, software (startup apps, AppImages), wellbeing, about |

Also: the dock (pinned and open apps, right-click menu), notification pop-ups, the on-screen display, desktop widgets (clock, weather, now playing, calendar, system usage, notes, a picture), the lock screen, idle lock and screens off, and a polkit agent. The first start shows a short welcome.

---

## niri config

Modular config in `~/.config/niri/` (source: `config/niri/`):

| File | Contents |
|---|---|
| `config.kdl` | includes the files below |
| `config/env.kdl` | `prefer-no-csd`, environment variables (qt6ct, Niri session vars) |
| `config/input.kdl` | keyboard (your layouts, Alt+Shift switches), numlock, flat mouse accel, focus follows mouse, Breeze cursor |
| `config/output.kdl` | **generated**: each monitor's current mode, position, scale, rotation; disabled monitors set to `off` |
| `config/workspaces.kdl` | **generated**: workspaces 1 to 10 on the main monitor, `d2-1` to `d2-10` on a second one, each pinned to its monitor so they return there after it was off |
| `config/layout.kdl` | 10px gaps, column presets, 2px white/grey borders, no focus ring, no hot corners, snappy spring animations |
| `config/autostart.kdl` | only what Monolith needs: clipboard history + `monolith start --login` (the shell, and your startup apps from Settings → Software). Add your own apps here; when the installer replaces the niri config it keeps the startup apps you had |
| `config/keybinds.kdl` | the keybinds below |
| `config/rules.kdl` | rounded window corners, Steam toasts as notifications |

The installer reads displays from the running niri. If you install from a TTY, nothing is pinned and niri picks each monitor's preferred mode; run `monolith installer` from inside niri later to pin the layout. Settings → Displays can also change resolution, refresh rate and scale, and saves them.

## Keybinds

`Mod` is the Super/Windows key. `Mod+Shift+/` shows niri's own list.

**Apps**

| Key | Action |
|---|---|
| `Mod+C` | terminal (kitty) |
| `Mod+B` | browser (LibreWolf) |
| `Mod+E` | files (Thunar) |
| `Mod+Escape` | Mission Center |
| `Mod+Z` / `Mod+Space` | the hub: search apps, files (`/`, `~`), emojis (`:`), commands (`>`) |
| `Mod+Tab` | windows (switcher and overview) |
| `Mod+Alt+V` | clipboard history |
| `Mod+Ctrl+scroll` | zoom (wooz): up opens it, scroll inside to zoom, down closes it |

**Monolith**

| Key | Action |
|---|---|
| `Mod+D` | Quick (volume, toggles, power) |
| `Mod+S` / `Mod+Alt+H` | Settings |
| `Mod+N` | Network |
| `Mod+V` | Sound |
| `Mod+A` | status line auto-hide |
| `Mod+Alt+C` | Clipboard |
| `Mod+X` / `Mod+Alt+M` | Media |
| `Mod+P` | Keys (every keybind) |
| `Mod+W` / `Mod+Alt+W` | Wallpaper |
| `Mod+L` / `Mod+Alt+L` | lock |
| `Mod+Ctrl+Alt+L` | swaylock |

**Windows**

| Key | Action |
|---|---|
| `Mod+Q` | close |
| `Mod+Arrows` | focus column left/right, window up/down |
| `Mod+H` / `J` / `K` | focus column left / window down / up |
| `Mod+Shift+Arrows` | focus monitor |
| `Mod+Ctrl+Arrows` | move column left/right, window up/down |
| `Mod+Ctrl+H/J/K/L` | move column / window |
| `Mod+R` | float / tile the focused window |
| `Mod+T` | maximize (fills the screen, keeps border and gaps; press again to restore) |
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
| `Print` / `Mod+Shift+S` | screenshot: pick a region (or window) |
| `Shift+Print` | screenshot a region and open it in the editor |
| `Ctrl+Print` / `Mod+Print` | screenshot the whole screen |
| `Alt+Print` | whole screen, then the editor |
| media / volume / mic / brightness keys | work as labelled (also on the lock screen) |
| `Mod+M`, `Mod+Shift+E`, `Ctrl+Alt+Delete` | quit niri |

## Commands

| Command | What it does |
|---|---|
| `monolith installer` | open the installer (update, reinstall, change options) |
| `monolith installer --update` | update without the menu (what Settings → About → Update runs) |
| `monolith start` / `stop` / `restart` | run / stop / restart the shell |
| `monolith msg toggle <page>` | open/close a hub page: `launcher`, `system`, `settings`, `network`, `volume`, `music`, `clipboard`, `wallpaper`, `calendar`, `switcher`, `cheatsheet`, `emoji`, `autohide`, … |
| `monolith settings [section]` | open Settings (e.g. `monolith settings display`) |
| `monolith search <text>` | open Search with text typed (`:smile`, `~/Documents`) |
| `monolith lock` | lock the screen |
| `monolith screenshot [--full] [--edit]` | screenshot |
| `monolith timer <minutes>` / `record [region]` | start a timer / start or stop recording |
| `monolith set <setting> <json>` / `get <setting>` | change or read a setting, e.g. `monolith set status.position '"bottom"'` |
| `monolith migrate` | move an older niri config (the classic shell's `monolithd`) over to this shell |

Helper scripts in `bin/` (installed to `~/.local/bin`):

- `focuswin`, `swapwin`, `snap`, `tilehalf`, `maxtoggle`: desktop-style window focus, swapping, half-screen snapping and maximizing for floating windows (not bound by default since Monolith uses normal niri tiling; bind them in `keybinds.kdl` if you want them)

## Repo layout

| Path | Contents |
|---|---|
| `install/` | the installer: `get.sh` (one-command), `install.sh`, `modules/`, `strings.json` |
| `install.sh` | runs `install/install.sh` from a clone |
| `monolith/bin/monolith` | the command |
| `monolith/shell/` | the shell: `core/` (services), `hub/` (the pages; `hub/settings/` the Settings sections), `status/`, `dock/`, `wall/`, `lock/`, `ui/` (shared parts), `scripts/` |
| `monolith/SPEC.md` | the design and the feature list |
| `monolith/dev/nested.sh` | runs the shell in a nested niri window, for trying changes |
| `config/niri/` | the niri config |
| `sddm/` | the SDDM login theme |
| `config/monolith/settings.json` | default settings |
| `bin/` | helper scripts |
| `docs/media/` | the previews in this README |

Installed files: the shell in `~/.local/share/monolith`; settings in `~/.config/monolith` (`next.json`); state in `~/.local/state/monolith`.

## Updating the repo

**Publishing a Monolith update** (shell or installer changes):

1. edit the files under `monolith/` or `install/`
2. bump the version in `monolith/version.txt`
3. commit and push to the branch your machines install from (it's in `~/.local/share/monolith/install/source.env`)

Every machine checks every few hours. When GitHub has a newer commit, the status line says so and Settings → About shows it; **Update** runs `monolith installer --update`, which refreshes the shell, installs any new dependencies, keeps your settings, niri config, login screen and wallpapers, and restarts the shell.

While the repo is private, the update check goes through the GitHub CLI (`gh auth login` once per machine).

**Your own config changes**: niri files live in `config/niri/config/` (don't commit `output.kdl` / `workspaces.kdl`, they're generated per machine); helper scripts in `bin/`.

## Troubleshooting

- **Nothing on screen:** run `quickshell -p ~/.local/share/monolith/shell/shell.qml` in a terminal to see errors.
- **No weather:** the location comes from your internet connection (city level).
- **Wrong monitor layout:** Settings → Displays, or run `monolith installer` from inside niri, or edit `~/.config/niri/config/output.kdl`, then `niri validate`.
- **Lock screen won't accept your password:** check `/etc/pam.d/monolith` exists (the installer adds it). If you're ever stuck, switch to a TTY (Ctrl+Alt+F3), log in, and run `monolith stop`.

## Licence

Copyright (C) 2026 apolloKapa

**The shell** (`monolith/`) is written from scratch and licensed under the [GNU GPL-3.0](monolith/LICENSE).

Monolith's earlier versions were a fork of [Serpantinum](https://github.com/ilyamiro/serpantinum) by [@ilyamiro](https://github.com/ilyamiro) (GNU AGPL-3.0). That shell is gone; the installer and the rest of this repo grew out of that version and stay under the [GNU AGPL-3.0](LICENSE).

The YAMIS icon pack (`config/icons/YAMIS`, "yet another monochrome icon set") is by [Dirn](https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set), licensed under the GNU GPL-3.0, and ships unchanged.

The login screen theme is based on [Qylock](https://github.com/Darkkal44/qylock) by Darkkal44, licensed under the GNU GPL-3.0.
