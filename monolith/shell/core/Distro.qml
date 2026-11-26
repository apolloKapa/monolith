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
    readonly property string glyph: {
        if (glyphs[osId]) return glyphs[osId];
        for (const l of like) if (glyphs[l]) return glyphs[l];
        return tux;
    }
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
