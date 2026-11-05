pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper: which image, which folder to pick from, and the palette made from it
// (matugen's Material roles, written to ~/.local/state/monolith/next-palette.json).
Singleton {
    id: wall
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string paletteFile: home + "/.local/state/monolith/next-palette.json"
    // until one is picked here, the wallpaper the current Monolith shows
    readonly property string path: Store.get("wallpaper.path", home + "/.cache/monolith/wallpaper/current_wallpaper.png")
    readonly property string dir: Store.get("wallpaper.dir", (Prefs.raw.wallpaperDir || (home + "/Pictures/Wallpapers")))
    readonly property string mode: Store.get("theme.mode", "dark")
    property var images: []
    // a screen can have its own wallpaper (right-click in the picker); else the shared one
    function pathFor(screen) { return Store.get("wallpaper.screens." + screen.replace(/\./g, "_"), "") || path; }
    function setFor(screen, p) { Store.set("wallpaper.screens." + screen.replace(/\./g, "_"), p); }
    function isVideo(p) { return /\.(mp4|webm|mkv|mov)$/i.test(p); }
    function isAnimated(p) { return /\.gif$/i.test(p); }
    // a file path as a URL ('#', '?' and spaces in names break a plain "file://" + path)
    function url(p) { return p.startsWith("/") ? "file://" + p.split("/").map(encodeURIComponent).join("/") : p; }

    function rescan() { scan.running = true; }
    Process {
        id: scan
        command: ["sh", "-c", "find \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \\) | sort", "_", wall.dir]
        stdout: StdioCollector { onStreamFinished: wall.images = text.split("\n").filter(l => l) }
    }
    onDirChanged: rescan()

    function set(p) {
        Store.set("wallpaper.path", p);
        // a picture for every screen again
        Store.set("wallpaper.screens", {});
        makePalette(p);
    }
    function makePalette(p) {
        // videos: the colours of their first frame
        paletteProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; src=\"$1\"; " +
            "case \"$src\" in *.mp4|*.webm|*.mkv|*.mov|*.MP4|*.WEBM) ffmpeg -loglevel error -y -i \"$src\" -frames:v 1 \"$2.frame.png\" && src=\"$2.frame.png\";; esac; " +
            "matugen image \"$src\" --dry-run -j hex -m \"$3\" --source-color-index 0 > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"",
            "_", p, wall.paletteFile, wall.mode];
        paletteProc.running = true;
    }
    Process { id: paletteProc }
    onModeChanged: if (Store.loaded) makePalette(path)

    // first start: make a palette for whatever wallpaper there is
    Component.onCompleted: { rescan(); firstPalette.running = true; }
    Process {
        id: firstPalette
        command: ["test", "-s", wall.paletteFile]
        onExited: code => { if (code !== 0) wall.makePalette(wall.path); }
    }
}
