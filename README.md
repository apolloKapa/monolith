# dotfiles

My Arch Linux setup: [niri](https://github.com/YaLTeR/niri) with a custom [Quickshell](https://quickshell.org) desktop (bar, lock screen, notifications, settings window), a rofi launcher, and helper scripts.

## What's in here

| Path | Contents |
|---|---|
| `config/niri/` | niri config (monitors, binds, window rules, animations) |
| `config/quickshell/` | Quickshell configs: `bar`, `lock`, `notifs`, `settings`, `launcher`, `displays`, `favs` |
| `config/rofi/` | rofi theme and favourites list |
| `config/mako/` | mako config (legacy, notifications now run through `quickshell/notifs`) |
| `config/theme/` | saved theme state for the Themes settings page |
| `config/wallpaper` | current wallpaper setting |
| `bin/` | helper scripts that go in `~/.local/bin` (`launcher`, `applytheme`, `lockscreen`, `snap`, `focuswin`, ...) |
| `packages.txt` | official repo packages |
| `packages-aur.txt` | AUR packages |
| `install.sh` | copies configs and scripts into place |

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

- **Monitors:** `config/niri/config.kdl` has my monitor layout (`DP-1`, `DP-2`, `HDMI-A-1`) hard-coded. On other hardware, run `niri msg outputs` and edit the `output` blocks to match. The Displays page in the settings window (`Mod+I`) can also change them and save the result.
- **Wallpaper:** `setwall` reads wallpapers from `~/Pictures/Wallpapers`. Create that folder and add some images.
- **Nvidia:** my desktop uses the legacy driver for a GTX 1070 (`nvidia-dkms-580xx`, installed through `chwd`). The package list may include drivers that don't suit your GPU. Remove them from `packages.txt` before installing if so.
- **Lock screen:** test it before relying on it. This unlocks itself after 30 seconds:

  ```sh
  env LOCKTEST=30 qs -c lock
  ```

  If it ever locks you out, switch to a TTY with Ctrl+Alt+F3, log in and run `pkill -f "qs -c lock"`.
- **Notifications:** `quickshell/notifs` replaces mako. Only one program can own notifications, so don't run both.

## Key bindings

| Key | Action |
|---|---|
| `Mod+Z` / `Mod+Space` | launcher (rofi) |
| `Mod+C` | terminal (kitty) |
| `Mod+B` / `Mod+E` | browser / file manager |
| `Mod+I` | settings window |
| `Mod+L` | lock screen |
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
cp -r ~/.config/niri ~/.config/quickshell ~/.config/rofi config/
cp ~/.local/bin/<script> bin/
git add . && git commit -m "update" && git push
```

## Troubleshooting

- **`qs: command not found`:** `quickshell` isn't installed. Run `sudo pacman -S quickshell qt6-wayland`.
- **Bar or panels don't appear after login:** start them by hand to see the error, for example `qs -c bar`.
- **Tray menus don't open:** the bar needs `//@ pragma UseQApplication` on the first line of `quickshell/bar/shell.qml`. It's already there.
- **Settings window pages are blank:** run `qs -c settings` in a terminal and open the page. The error prints there.
