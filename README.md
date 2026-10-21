# dotfiles

My Arch Linux setup: [niri](https://github.com/YaLTeR/niri) running **Monolith**, my desktop shell (really good desktop :3), plus a rofi launcher and helper scripts.

Monolith is built on [Serpantinum](https://github.com/ilyamiro/serpantinum) by @ilyamiro (AGPL-3.0, see `monolith/LICENSE.md`). It keeps every Serpantinum feature (bar, dock, launcher, lock screen, notifications, OSD, clipboard, music, network, widgets, settings guide, blur and liquid glass) and adds:

- **Minimalist** style, next to Blur / Liquid glass in *Settings → Theme*: flat opaque panels, square corners, 2px `#555` outlines, white accent with inverted hover, JetBrains Mono. It's my old Quickshell look. The square corners/outlines only apply while Minimalist is selected; every other style is unchanged.
- Minimalist colour preset (`monolith/src/assets/themes/Minimalist.json`)
- own logo, intro (horizon backdrop), mascot (Lith, the sleepy slab), name and paths (`~/.config/monolith`, `~/.local/share/monolith`)
- **private**: no telemetry (Serpantinum's installer telemetry isn't included), no IP geolocation, no reverse geocoding, lyrics only from lrclib (no NetEase). Weather uses the location you set in *Settings → General* and only sends those coordinates to open-meteo. Things that still go online only do so when you use them: lyrics (track name → lrclib), YouTube cover art, GitHub widget, DuckDuckGo wallpaper search, the captive-portal "Sign in" button.
- update button pulls this repo instead of upstream; automatic update checks are off

## What's in here

| Path | Contents |
|---|---|
| `config/niri/` | niri config (monitors, binds, window rules, animations) |
| `monolith/` | the Monolith shell: `bin/` (`monolith`, `monolithd`), `src/` (QML, scripts, assets), SDDM theme |
| `config/monolith/` | default Monolith settings (only copied if you don't have any yet) |
| `config/rofi/` | rofi theme and favourites list |
| `config/wallpaper` | current wallpaper setting |
| `bin/` | helper scripts that go in `~/.local/bin` (`launcher`, `setwall`, `snap`, `focuswin`, `swapwin`, ...) |
| `packages.txt` | official repo packages |
| `packages-aur.txt` | AUR packages |
| `install.sh` | copies configs and scripts into place and installs Monolith (`--sddm` also installs the login theme) |

## Install

These steps assume a fresh Arch install with a user account, network access and `sudo`.

### 1. Base tools

```sh
sudo pacman -S --needed git base-devel
```

### 2. Clone

```sh
git clone https://github.com/kasc0b3r/dotfiles ~/dotfiles
cd ~/dotfiles
```

The repo is private, so run `gh auth login` first (or clone over SSH).

### 3. Official packages

```sh
sudo pacman -S --needed - < packages.txt
```

If pacman says a package can't be found, it has left the repos since the list was made. Delete that line from `packages.txt` and run the command again.

### 4. AUR helper and AUR packages

`paru` is itself an AUR package, so build it by hand first:

```sh
git clone https://aur.archlinux.org/paru-bin.git ~/paru-bin
cd ~/paru-bin && makepkg -si
cd ~/dotfiles
paru -S --needed - < packages-aur.txt
```

### 5. Copy the configs

```sh
./install.sh
```

This copies `config/*` into `~/.config` and `bin/*` into `~/.local/bin`. It overwrites files with the same name, so back up anything you want to keep first.

Make sure `~/.local/bin` is on your `PATH`. With fish:

```fish
fish_add_path ~/.local/bin
```

### 6. Log in to niri

Log out, then pick **niri** on the login screen (SDDM).

## Things to check after installing

- **Monitors:** `config/niri/config.kdl` has my monitor layout (`DP-1`, `DP-2`, `HDMI-A-1`) hard-coded. On other hardware, run `niri msg outputs` and edit the `output` blocks to match. Monolith's Display settings page can also change them.
- **Wallpaper:** Monolith and `setwall` read wallpapers from `~/Pictures/Wallpapers`. Create that folder and add some images.
- **Nvidia:** my desktop uses the legacy driver for a GTX 1070 (`nvidia-dkms-580xx`, installed through `chwd`). The package list may include drivers that don't suit your GPU. Remove them from `packages.txt` before installing if so.
- **Lock screen:** `install.sh` adds `/etc/pam.d/monolith` so the lock screen can check your password. Test it before relying on it (`monolith lock`). If it ever locks you out, switch to a TTY with Ctrl+Alt+F3, log in and run `monolithd stop`.
- **Serpantinum:** don't run Serpantinum and Monolith at the same time (two bars, two notification daemons). The niri config only starts `monolithd`.

## Key bindings

| Key | Action |
|---|---|
| `Mod+Z` / `Mod+Space` | launcher |
| `Mod+Shift+Z` | favourites (rofi) |
| `Mod+C` | terminal (kitty) |
| `Mod+B` / `Mod+E` | browser / file manager |
| `Mod+D` | system panel |
| `Mod+S` / `Mod+Alt+H` | settings guide |
| `Mod+N` / `Mod+V` | network / volume popups |
| `Mod+A` | bar autohide |
| `Mod+Alt+C` / `Mod+Alt+M` / `Mod+Alt+W` | clipboard / music / wallpaper picker |
| `Mod+L` / `Mod+Alt+L` | lock screen |
| `Mod+Q` | close window |
| `Mod+R` | float / tile toggle |
| `Mod+T` | tile and maximize |
| `Mod+O` | overview |
| `Mod+1` to `Mod+0` | workspaces |

`Mod+Shift+/` shows niri's full hotkey list.

## Updating the repo

After changing your setup, copy the files back in and push:

```sh
cd ~/dotfiles
cp -r ~/.config/niri ~/.config/rofi config/
cp ~/.local/bin/<script> bin/
git add . && git commit -m "update" && git push
```

Shell code lives in `monolith/src`. After editing it, run `./install.sh` and `monolith reload` (your settings in `~/.config/monolith` are left alone).

## Troubleshooting

- **`qs: command not found`:** `quickshell` isn't installed. Run `sudo pacman -S quickshell qt6-wayland`.
- **Bar or panels don't appear after login:** run `monolith -v` in a terminal to see the errors. Logs are also in `$XDG_RUNTIME_DIR/monolith/logs`.
- **Settings look wrong after switching style:** *Settings → Theme* → pick Blur, Liquid glass or Minimalist again. Minimalist also switches the font and colours to the mono preset; you can change them afterwards.
- **No weather:** set your location in *Settings → General* (latitude/longitude). Monolith never detects it automatically.
