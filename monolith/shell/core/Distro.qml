pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The distribution this is (/etc/os-release) and its logo: a glyph of Symbols Nerd Font (shipped
// with Monolith), drawn in whatever colour it's given, like an icon. Its ID first, then the ones it
// says it's like (CachyOS's own logo, else Arch's), then Tux.
Singleton {
    id: d
    property string osId: ""
    property var like: []
    property string name: ""
    readonly property string fontFamily: "Symbols Nerd Font Mono"
    // ID → glyph (nf-linux-*)
    readonly property var glyphs: ({
        "gentoo": "", "funtoo": "", "calculate": "",
        "arch": "", "archarm": "", "cachyos": "", "endeavouros": "", "manjaro": "",
        "garuda": "", "artix": "", "arcolinux": "", "archcraft": "", "biglinux": "",
        "crystal": "", "hyperbola": "", "parabola": "",
        "debian": "", "raspbian": "", "ubuntu": "", "kubuntu": "", "neon": "",
        "linuxmint": "", "pop": "", "elementary": "", "zorin": "", "kali": "",
        "parrot": "", "deepin": "", "mx": "", "tails": "", "trisquel": "",
        "vanilla": "", "puppy": "",
        "fedora": "", "nobara": "", "rhel": "", "centos": "", "rocky": "",
        "almalinux": "", "qubes": "",
        "opensuse": "", "opensuse-tumbleweed": "", "opensuse-leap": "", "suse": "",
        "nixos": "", "guix": "", "void": "", "alpine": "", "postmarketos": "",
        "slackware": "", "mageia": "", "solus": "", "sabayon": "", "freebsd": ""
    })
    readonly property string tux: ""
    // yours, from /etc/os-release
    readonly property string own: {
        if (glyphs[osId]) return glyphs[osId];
        for (const l of like) if (glyphs[l]) return glyphs[l];
        return tux;
    }
    // every logo there is to pick instead (holding the start button): [key, name, glyph, group],
    // the distributions and other systems, then desktops and window managers
    readonly property var logos: [
        ["almalinux", "AlmaLinux", "\uf31d", "os"],
        ["alpine", "Alpine", "\uf300", "os"],
        ["aosc", "AOSC OS", "\uf301", "os"],
        ["apple", "Apple", "\uf302", "os"],
        ["archcraft", "Archcraft", "\uf345", "os"],
        ["archlabs", "ArchLabs", "\uf31e", "os"],
        ["archlinux", "Arch Linux", "\uf303", "os"],
        ["arcolinux", "ArcoLinux", "\uf346", "os"],
        ["artix", "Artix", "\uf31f", "os"],
        ["biglinux", "BigLinux", "\uf347", "os"],
        ["cachyos", "CachyOS", "\uf385", "os"],
        ["centos", "CentOS", "\uf304", "os"],
        ["coreos", "CoreOS", "\uf305", "os"],
        ["crystal", "Crystal", "\uf348", "os"],
        ["debian", "Debian", "\uf306", "os"],
        ["deepin", "Deepin", "\uf321", "os"],
        ["devuan", "Devuan", "\uf307", "os"],
        ["elementary", "elementary OS", "\uf309", "os"],
        ["endeavour", "EndeavourOS", "\uf322", "os"],
        ["fedora", "Fedora", "\uf30a", "os"],
        ["fedora_inverse", "Fedora (inverted)", "\uf30b", "os"],
        ["freebsd", "FreeBSD", "\uf30c", "os"],
        ["garuda", "Garuda", "\uf337", "os"],
        ["gentoo", "Gentoo", "\uf30d", "os"],
        ["gnu_guix", "GNU Guix", "\uf325", "os"],
        ["hyperbola", "Hyperbola", "\uf33a", "os"],
        ["illumos", "illumos", "\uf326", "os"],
        ["kali_linux", "Kali Linux", "\uf327", "os"],
        ["kde_neon", "KDE neon", "\uf331", "os"],
        ["kubuntu", "Kubuntu", "\uf333", "os"],
        ["kubuntu_inverse", "Kubuntu (inverted)", "\uf334", "os"],
        ["leap", "openSUSE Leap", "\uf37e", "os"],
        ["linuxmint", "Linux Mint", "\uf30e", "os"],
        ["linuxmint_inverse", "Linux Mint (inverted)", "\uf30f", "os"],
        ["locos", "LocOS", "\uf349", "os"],
        ["lxle", "LXLE", "\uf33e", "os"],
        ["mageia", "Mageia", "\uf310", "os"],
        ["mandriva", "Mandriva", "\uf311", "os"],
        ["manjaro", "Manjaro", "\uf312", "os"],
        ["mxlinux", "MX Linux", "\uf33f", "os"],
        ["nixos", "NixOS", "\uf313", "os"],
        ["nobara", "Nobara", "\uf380", "os"],
        ["openbsd", "OpenBSD", "\uf328", "os"],
        ["opensuse", "openSUSE", "\uf314", "os"],
        ["openwrt", "OpenWrt", "\uf382", "os"],
        ["parabola", "Parabola", "\uf340", "os"],
        ["parrot", "Parrot", "\uf329", "os"],
        ["pop_os", "Pop!_OS", "\uf32a", "os"],
        ["postmarketos", "postmarketOS", "\uf374", "os"],
        ["puppy", "Puppy", "\uf341", "os"],
        ["qubesos", "Qubes OS", "\uf342", "os"],
        ["raspberry_pi", "Raspberry Pi OS", "\uf315", "os"],
        ["redhat", "Red Hat", "\uf316", "os"],
        ["rocky_linux", "Rocky Linux", "\uf32b", "os"],
        ["sabayon", "Sabayon", "\uf317", "os"],
        ["slackware", "Slackware", "\uf318", "os"],
        ["slackware_inverse", "Slackware (inverted)", "\uf319", "os"],
        ["solus", "Solus", "\uf32d", "os"],
        ["tails", "Tails", "\uf343", "os"],
        ["trisquel", "Trisquel", "\uf344", "os"],
        ["tumbleweed", "openSUSE Tumbleweed", "\uf37d", "os"],
        ["tux", "Tux", "\uf31a", "os"],
        ["ubuntu", "Ubuntu", "\uf31b", "os"],
        ["ubuntu_inverse", "Ubuntu (inverted)", "\uf31c", "os"],
        ["vanilla", "Vanilla", "\uf366", "os"],
        ["void", "Void", "\uf32e", "os"],
        ["xerolinux", "XeroLinux", "\uf34a", "os"],
        ["zorin", "Zorin", "\uf32f", "os"],
        ["awesome", "awesome", "\uf354", "desktop"],
        ["bspwm", "bspwm", "\uf355", "desktop"],
        ["budgie", "Budgie", "\uf320", "desktop"],
        ["cinnamon", "Cinnamon", "\uf35f", "desktop"],
        ["dwm", "dwm", "\uf356", "desktop"],
        ["enlightenment", "Enlightenment", "\uf357", "desktop"],
        ["fluxbox", "Fluxbox", "\uf358", "desktop"],
        ["gnome", "GNOME", "\uf361", "desktop"],
        ["hyprland", "Hyprland", "\uf359", "desktop"],
        ["i3", "i3", "\uf35a", "desktop"],
        ["jwm", "JWM", "\uf35b", "desktop"],
        ["kde", "KDE", "\uf373", "desktop"],
        ["kde_plasma", "KDE Plasma", "\uf332", "desktop"],
        ["lxde", "LXDE", "\uf363", "desktop"],
        ["lxqt", "LXQt", "\uf364", "desktop"],
        ["mate", "MATE", "\uf365", "desktop"],
        ["qtile", "Qtile", "\uf35c", "desktop"],
        ["river", "river", "\uf381", "desktop"],
        ["sway", "Sway", "\uf35d", "desktop"],
        ["wayland", "Wayland", "\uf367", "desktop"],
        ["xfce", "Xfce", "\uf368", "desktop"],
        ["xmonad", "xmonad", "\uf35e", "desktop"],
        ["xorg", "X.Org", "\uf369", "desktop"]
    ]
    // the one picked (desktop.startLogo), else yours
    readonly property string picked: String(Store.get("desktop.startLogo", "") || "")
    readonly property string glyph: { const l = logos.find(x => x[0] === picked); return l ? l[2] : own; }
    function unquote(v) { return String(v || "").trim().replace(/^["']|["']$/g, ""); }
    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const kv = {};
            for (const line of text().split("\n")) {
                const i = line.indexOf("=");
                if (i > 0) kv[line.slice(0, i).trim()] = d.unquote(line.slice(i + 1));
            }
            d.osId = String(kv.ID || "").toLowerCase();
            d.like = String(kv.ID_LIKE || "").toLowerCase().split(/\s+/).filter(x => x !== "");
            d.name = kv.NAME || kv.PRETTY_NAME || "";
        }
    }
}
