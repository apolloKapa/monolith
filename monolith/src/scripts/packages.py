#!/usr/bin/env python3
"""Settings -> Software -> Pacman / AUR / Flatpak: remove software, and find what installing and
removing it leaves behind.

  packages.py status          JSON: what each check finds (for the Settings pages; quick, no root)
  packages.py clean <check>   runs in a terminal: lists what it found and asks before removing

Checks:
  explicit    repo packages you installed yourself (system ones left out): pick any to remove
  orphans     pacman/AUR packages installed as dependencies that nothing needs any more
  cache       pacman's downloaded packages (keeps the newest 2 of each with paccache)
  aur         AUR packages you installed yourself: pick any to remove
  aurcache    the AUR helper's (yay's/paru's) download and build folders
  flatapps    installed Flatpak apps: pick any to remove, with or without their data
  flatpak     Flatpak runtimes and extensions no installed app uses
  flatdata    data folders in ~/.var/app of Flatpak apps that aren't installed any more
Nothing is removed without a yes.
"""
import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
VAR_APP = os.path.join(HOME, ".var", "app")
PACMAN_CACHE = "/var/cache/pacman/pkg"
AUR_CACHES = [os.path.join(HOME, ".cache", "yay"), os.path.join(HOME, ".cache", "paru", "clone")]


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else ""
    except OSError:
        return ""


def have(cmd):
    return shutil.which(cmd) is not None


def du(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


# ---- what each check finds ----

def orphans():
    """[(name, installed size in bytes)]"""
    names = run(["pacman", "-Qdtq"]).split()
    if not names:
        return []
    sizes, name = {}, None
    for line in run(["pacman", "-Qi", *names]).splitlines():
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip()
        if k == "Name":
            name = v
        elif k == "Installed Size" and name:
            num, _, unit = v.partition(" ")
            mult = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}.get(unit, 1)
            try:
                sizes[name] = int(float(num.replace(",", ".")) * mult)
            except ValueError:
                sizes[name] = 0
    return [(n, sizes.get(n, 0)) for n in names]


# never offered for removal: what boots the PC and runs the desktop. Plus whatever the base
# package pulls in, read from pacman
SYSTEM = {
    "base", "base-devel", "sudo", "pacman", "pacman-contrib", "archlinux-keyring", "grub", "efibootmgr",
    "systemd-boot", "refind", "limine", "os-prober", "mkinitcpio", "dracut", "booster", "btrfs-progs",
    "e2fsprogs", "dosfstools", "xfsprogs", "ntfs-3g", "lvm2", "cryptsetup", "networkmanager", "iwd",
    "dhcpcd", "wpa_supplicant", "openssh", "mesa", "lib32-mesa", "nvidia", "nvidia-open", "nvidia-dkms",
    "nvidia-utils", "lib32-nvidia-utils", "xf86-video-amdgpu", "pipewire", "pipewire-pulse", "pipewire-alsa",
    "pipewire-jack", "wireplumber", "niri", "quickshell", "xwayland-satellite", "sddm", "greetd", "gdm",
    "ly", "lightdm", "xdg-desktop-portal", "xdg-desktop-portal-gnome", "xdg-desktop-portal-gtk",
    "polkit", "dbus", "git", "python", "yay", "paru", "flatpak", "zram-generator", "bluez", "bluez-utils",
}
SYSTEM_PREFIXES = ("linux", "vulkan-", "lib32-vulkan-", "amd-ucode", "intel-ucode", "sof-firmware", "alsa-")


def monolith_deps():
    """what Monolith itself needs: the installer's package lists (install/modules/deps.sh, next to
    src/ in an install, a folder up in the repo)"""
    here = os.path.dirname(os.path.abspath(__file__))
    for rel in ("../../install/modules/deps.sh", "../../../install/modules/deps.sh"):
        try:
            text = open(os.path.normpath(os.path.join(here, rel)), encoding="utf-8").read()
        except OSError:
            continue
        out = set()
        for m in re.finditer(r"(?ms)^(?:REQUIRED_PKGS|KEYBIND_PKGS)=\((.*?)^\)", text):
            for name in re.findall(r'"([^"]+)"', m.group(1)):
                out.update(name.split("|"))
        return out
    return set()


def is_system(name, base_deps):
    if name in SYSTEM or name in base_deps or name.startswith(SYSTEM_PREFIXES):
        return True
    return name.endswith(("-firmware", "-ucode", "-headers")) and name.startswith(("linux", "amd", "intel"))


def explicit_packages(source=None):
    """[(name, size, description, from AUR)] of the packages you installed yourself, biggest first;
    source "repo" or "aur" keeps only those"""
    names = run(["pacman", "-Qqe"]).split()
    if not names:
        return []
    aur = set(run(["pacman", "-Qqm"]).split())
    base_deps = set()
    for line in run(["pacman", "-Qi", "base"]).splitlines():
        if line.startswith("Depends On"):
            base_deps = {re.split(r"[<>=]", d)[0] for d in line.split(":", 1)[1].split()}
    info, cur = {}, {}
    for line in run(["pacman", "-Qi", *names]).splitlines():
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip()
        if k == "Name":
            cur = info.setdefault(v, {})
        elif k == "Description":
            cur["desc"] = v
        elif k == "Installed Size":
            num, _, unit = v.partition(" ")
            mult = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}.get(unit, 1)
            try:
                cur["size"] = int(float(num.replace(",", ".")) * mult)
            except ValueError:
                cur["size"] = 0
    base_deps |= monolith_deps()
    out = [(n, info.get(n, {}).get("size", 0), info.get(n, {}).get("desc", ""), n in aur)
           for n in names if not is_system(n, base_deps)]
    if source:
        out = [p for p in out if p[3] == (source == "aur")]
    return sorted(out, key=lambda p: -p[1])


def flatpak_apps():
    return set(run(["flatpak", "list", "--app", "--columns=application"]).split())


def flatpak_installed():
    """[(id, name, size text, installation)] of the installed Flatpak apps"""
    out = []
    for line in run(["flatpak", "list", "--app", "--columns=application,name,size,installation"]).splitlines():
        f = line.split("\t")
        if len(f) >= 4:
            out.append((f[0], f[1], f[2], f[3]))
    return out


def size_of(text):
    """"209.7 MB" -> bytes"""
    m = re.match(r"([\d.,]+)\s*([kMGT]?B)", text.replace("\xa0", " "))
    if not m:
        return 0
    return int(float(m.group(1).replace(",", ".")) * {"B": 1, "kB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}[m.group(2)])


def flatpak_leftovers():
    """[(app id, folder, size)]: ~/.var/app folders of apps that aren't installed"""
    if not os.path.isdir(VAR_APP) or not have("flatpak"):
        return []
    installed = flatpak_apps()
    out = []
    for name in sorted(os.listdir(VAR_APP)):
        path = os.path.join(VAR_APP, name)
        if os.path.isdir(path) and not os.path.islink(path) and name not in installed:
            out.append((name, path, du(path)))
    return out


def cache_files():
    """[(path, size)] of pacman cache packages paccache would remove"""
    out = []
    if have("paccache"):
        for args in (["-dk2"], ["-duk0"]):
            for line in run(["paccache", "-v", *args]).splitlines():
                p = line.strip()
                if p.startswith("/") and os.path.isfile(p):
                    out.append((p, os.path.getsize(p)))
    return out


def aur_cache():
    """[(path, size)] of the AUR helpers' download/build folders"""
    out = []
    for d in AUR_CACHES:
        if os.path.isdir(d):
            for name in sorted(os.listdir(d)):
                p = os.path.join(d, name)
                if os.path.isdir(p):
                    out.append((p, du(p)))
    return out


def status():
    st = {"pacman": have("pacman"), "flatpakInstalled": have("flatpak"), "paccache": have("paccache")}
    if st["pacman"]:
        o = orphans()
        st["orphans"] = {"count": len(o), "size": sum(s for _, s in o)}
        e = explicit_packages()
        for key, aur in (("explicit", False), ("aur", True)):
            part = [p for p in e if p[3] == aur]
            st[key] = {"count": len(part), "size": sum(p[1] for p in part)}
        c = cache_files()
        # without paccache, how much can go isn't known: show the whole pacman cache
        st["cache"] = {"count": len(c), "size": sum(s for _, s in c) if st["paccache"] else du(PACMAN_CACHE)}
        a = aur_cache()
        st["aurcache"] = {"count": len(a), "size": sum(s for _, s in a)}
    if st["flatpakInstalled"]:
        f = flatpak_leftovers()
        st["flatdata"] = {"count": len(f), "size": sum(s for *_, s in f)}
        apps = flatpak_installed()
        st["flatapps"] = {"count": len(apps), "size": sum(size_of(a[2]) for a in apps)}
    print(json.dumps(st))


# ---- the terminal side ----

BOLD, DIM, RED, GREEN, RESET = "\033[1m", "\033[2m", "\033[31m", "\033[32m", "\033[0m"


def ask(question):
    try:
        return input(f"\n{BOLD}{question} [y/N] {RESET}").strip().lower() in ("y", "yes")
    except EOFError:
        return False


def title(text):
    print(f"\n{BOLD}{text}{RESET}\n" + "─" * min(len(text), 60))


def pick(lines, preview):
    """the first word of the lines picked: fzf (Tab marks, Enter confirms) or, without it, numbers
    typed in"""
    if have("fzf"):
        r = subprocess.run(["fzf", "--multi", "--reverse", "--height=90%", "--no-sort",
                            "--header=Tab: mark   Enter: remove the marked ones   Esc: cancel",
                            "--prompt=search: ", f"--preview={preview}", "--preview-window=down,40%,wrap"],
                           input="\n".join(lines), stdout=subprocess.PIPE, text=True)
        return [l.split()[0] for l in r.stdout.splitlines() if l.strip()]
    for i, l in enumerate(lines, 1):
        print(f"{i:>4}  {l}")
    try:
        typed = input(f"\n{BOLD}Numbers to remove (e.g. 3 7 12), or Enter for none: {RESET}")
    except EOFError:
        return []
    return [lines[int(t) - 1].split()[0] for t in typed.replace(",", " ").split() if t.isdigit() and 0 < int(t) <= len(lines)]


def pick_packages(pkgs):
    return pick([f"{n:<34} {human(sz):>9}  {d}" for n, sz, d, _ in pkgs], "pacman -Qi {1}")


def clean_aur():
    clean_explicit("aur")


def clean_explicit(source="repo"):
    title("AUR packages" if source == "aur" else "Installed packages")
    print(f"{DIM}The {'AUR ' if source == 'aur' else ''}packages you installed yourself, biggest first. System ones (kernel, drivers,\n"
          f"firmware, login, sound) and what Monolith needs aren't listed, so they can't be removed by mistake.{RESET}")
    pkgs = explicit_packages(source)
    if not pkgs:
        print("\nNone found.")
        return
    picked = pick_packages(pkgs)
    if not picked:
        print("\nNothing picked, nothing removed.")
        return
    print(f"\n{BOLD}Picked:{RESET} " + ", ".join(picked))
    print(f"{DIM}pacman shows everything that would go (their unused dependencies too) and asks once more.\n"
          f"If another package needs one of these, pacman refuses and nothing is removed.{RESET}\n")
    subprocess.run(["sudo", "pacman", "-Rns", *picked])


def clean_orphans():
    title("Orphan packages")
    print(f"{DIM}Installed as dependencies of something you've since removed; nothing needs them now.{RESET}")
    while True:
        found = orphans()
        if not found:
            print(f"\n{GREEN}No orphan packages.{RESET}")
            return
        print()
        for name, size in found:
            print(f"  {name:<40} {DIM}{human(size)}{RESET}")
        print(f"\n{len(found)} package{'s' if len(found) != 1 else ''}, {human(sum(s for _, s in found))}")
        if not ask("Remove them?"):
            print("Left as they are.")
            return
        # -Rns: also their config files and any dependencies only they needed
        r = subprocess.run(["sudo", "pacman", "-Rns", "--noconfirm", *[n for n, _ in found]])
        if r.returncode != 0:
            print(f"{RED}pacman didn't remove them.{RESET}")
            return
        print(f"{GREEN}Removed.{RESET} Checking again: removing packages can leave new orphans...")


def clean_flatapps():
    title("Flatpak apps")
    print(f"{DIM}Your installed Flatpak apps. Their runtimes are left to 'Unused Flatpak runtimes'.{RESET}")
    apps = flatpak_installed()
    if not apps:
        print("\nNo Flatpak apps installed.")
        return
    apps.sort(key=lambda a: -size_of(a[2]))
    picked = pick([f"{i:<44} {sz:>10}  {n}  ({inst})" for i, n, sz, inst in apps], "flatpak info {1}")
    if not picked:
        print("\nNothing picked, nothing removed.")
        return
    print(f"\n{BOLD}Picked:{RESET} " + ", ".join(picked))
    data = ask("Also delete their settings and files (~/.var/app)? No keeps them for a reinstall")
    # flatpak shows what goes and asks once more
    subprocess.run(["flatpak", "uninstall", *(["--delete-data"] if data else []), *picked])


def clean_flatpak():
    title("Unused Flatpak runtimes")
    print(f"{DIM}Runtimes and extensions that no installed Flatpak app uses any more.{RESET}")
    for scope in ("--user", "--system"):
        # flatpak lists them and asks itself
        print(f"\n{BOLD}{'Your' if scope == '--user' else 'System-wide'} Flatpaks{RESET}")
        subprocess.run(["flatpak", "uninstall", scope, "--unused"])


def clean_flatdata():
    title("Leftover Flatpak app data")
    print(f"{DIM}Settings and files in ~/.var/app from Flatpak apps that aren't installed any more.\n"
          f"If you reinstall one of these apps later, it starts fresh.{RESET}")
    found = flatpak_leftovers()
    if not found:
        print(f"\n{GREEN}Nothing left over.{RESET}")
        return
    print()
    for app, _, size in found:
        print(f"  {app:<50} {DIM}{human(size)}{RESET}")
    print(f"\n{len(found)} folder{'s' if len(found) != 1 else ''}, {human(sum(s for *_, s in found))}")
    if ask("Delete all of them?"):
        for _, path, _ in found:
            shutil.rmtree(path, ignore_errors=True)
        print(f"{GREEN}Deleted.{RESET}")
    elif ask("Go through them one by one?"):
        for app, path, size in found:
            if ask(f"Delete {app} ({human(size)})?"):
                shutil.rmtree(path, ignore_errors=True)
                print(f"{GREEN}Deleted.{RESET}")


def clean_cache():
    title("Old package downloads")
    print(f"{DIM}pacman keeps every version it downloads. This keeps the newest 2 of each installed\n"
          f"package (to roll back with) and drops the rest.{RESET}")
    if have("paccache"):
        old = [p for p, _ in cache_files() if p.startswith(PACMAN_CACHE)]
        size = sum(os.path.getsize(p) for p in old if os.path.isfile(p))
        print(f"\npacman cache: {len(old)} old file{'s' if len(old) != 1 else ''}, {human(size)}")
        if old and ask("Remove them?"):
            subprocess.run(["sudo", "paccache", "-rk2"])
            subprocess.run(["sudo", "paccache", "-ruk0"])
    else:
        # without paccache: pacman's own clean, which drops packages that aren't installed any
        # more (and asks first). paccache (pacman-contrib) also trims old versions
        size = du(PACMAN_CACHE)
        print(f"\npacman cache: {human(size)}. {DIM}Install pacman-contrib to also drop old versions of installed packages.{RESET}")
        if size and ask("Clean out packages that aren't installed any more?"):
            subprocess.run(["sudo", "pacman", "-Sc"])


def clean_aurcache():
    title("AUR build folders")
    print(f"{DIM}What yay/paru downloaded and built. Safe to empty: AUR packages are downloaded again\n"
          f"when they update.{RESET}")
    found = False
    for d in AUR_CACHES:
        if os.path.isdir(d):
            found = True
            size = du(d)
            print(f"\n{d}: {human(size)}")
            if size and ask("Empty it?"):
                for name in os.listdir(d):
                    p = os.path.join(d, name)
                    shutil.rmtree(p, ignore_errors=True) if os.path.isdir(p) else os.remove(p)
                print(f"{GREEN}Emptied.{RESET}")
    if not found:
        print(f"\n{GREEN}No AUR helper folders.{RESET}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        status()
        return
    checks = {"explicit": clean_explicit, "orphans": clean_orphans, "cache": clean_cache, "aur": clean_aur,
              "aurcache": clean_aurcache, "flatapps": clean_flatapps, "flatpak": clean_flatpak, "flatdata": clean_flatdata}
    if cmd != "clean" or len(sys.argv) < 3 or sys.argv[2] not in checks:
        raise SystemExit(__doc__)
    try:
        checks[sys.argv[2]]()
    except KeyboardInterrupt:
        print("\nStopped.")
    try:
        input(f"\n{DIM}Press Enter to close{RESET}")
    except (EOFError, KeyboardInterrupt):
        pass


if __name__ == "__main__":
    main()
