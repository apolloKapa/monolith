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
    // until one is picked, the first picture in the folder
    readonly property string path: Store.get("wallpaper.path", "") || (images.length > 0 ? images[0] : "")
    readonly property string dir: Store.get("wallpaper.dir", (Prefs.raw.wallpaperDir || (home + "/Pictures/Wallpapers")))
    readonly property string mode: Store.get("theme.mode", "dark")
    property var images: []
    // live wallpapers (videos, GIFs): in the folder or its Live folder (where "Add video…" copies
    // them); the picker shows them on their own tab, pictures on the other
    readonly property string liveDir: dir + "/Live"
    readonly property var live: images.filter(i => isVideo(i) || isAnimated(i))
    readonly property var pictures: images.filter(i => !isVideo(i) && !isAnimated(i))
    // a still of each video (its first second), for the picker's cards
    readonly property string thumbDir: home + "/.cache/monolith/live-thumbs"
    property int thumbsMade: 0          // goes up when new stills are written: cards reload
    function thumb(p) { return thumbDir + "/" + Qt.md5(p) + ".jpg"; }
    function makeThumbs() {
        const vids = images.filter(isVideo);
        if (!vids.length) return;
        thumbProc.command = ["sh", "-c",
            "mkdir -p \"$1\"; shift; for v; do t=\"$(printf %s \"$v\" | md5sum | cut -d' ' -f1)\"; " +
            "[ -s \"$THUMBS/$t.jpg\" ] || ffmpeg -loglevel error -y -ss 1 -i \"$v\" -frames:v 1 -vf scale=640:-2 \"$THUMBS/$t.jpg\" </dev/null " +
            "|| ffmpeg -loglevel error -y -i \"$v\" -frames:v 1 -vf scale=640:-2 \"$THUMBS/$t.jpg\" </dev/null; done",
            "_", thumbDir].concat(vids);
        thumbProc.environment = { "THUMBS": thumbDir };
        thumbProc.running = true;
    }
    Process { id: thumbProc; onExited: wall.thumbsMade++ }

    // small copies of the pictures for the picker's cards (decoding a 4K file for a 640 px card is
    // what made it slow). Made once in the background, the ones around the current wallpaper first
    // (what the picker shows when it opens), four at a time; each card switches to its copy the
    // moment it exists. A picture that can't be shrunk shows itself, full size.
    readonly property string picThumbDir: home + "/.cache/monolith/wall-thumbs"
    function picThumb(p) { return picThumbDir + "/" + Qt.md5(p) + "-960.jpg"; }
    // path -> "ok" | "fail", for the pictures done so far
    property var picThumbs: ({})
    property var pendingThumbs: ({})
    function picThumbState(p) { return picThumbs[p] || ""; }
    function makePicThumbs() {
        const pics = pictures;
        if (!pics.length || picProc.running) return;
        // what the picker shows when it opens first: the start of the grid, and the coverflow
        // around the current wallpaper (both ways); then outward from those
        const at = Math.max(0, pics.indexOf(path));
        const order = pics.map((p, i) => [p, Math.min(i, Math.abs(i - at))])
                          .sort((x, y) => x[1] - y[1]).map(x => x[0]);
        picProc.command = ["sh", "-c",
            "mkdir -p \"$D\" && printf '%s\\0' \"$@\" | xargs -0 -n1 -P4 sh -c '" +
            "v=$1; t=\"$D/$(printf %s \"$v\" | md5sum | cut -d\" \" -f1)-960.jpg\"; " +
            "if [ -s \"$t\" ] && [ \"$t\" -nt \"$v\" ]; then printf \"ok\\t%s\\n\" \"$v\"; " +
            "elif ffmpeg -loglevel error -y -i \"$v\" -frames:v 1 -vf \"scale=min(960\\,iw):-2\" -q:v 4 \"$t.part.jpg\" </dev/null && mv \"$t.part.jpg\" \"$t\"; " +
            "then printf \"ok\\t%s\\n\" \"$v\"; else rm -f \"$t.part.jpg\"; printf \"fail\\t%s\\n\" \"$v\"; fi' _",
            "_"].concat(order);
        picProc.environment = { "D": picThumbDir };
        picProc.running = true;
    }
    Process {
        id: picProc
        stdout: SplitParser {
            onRead: line => {
                const tab = line.indexOf("\t");
                if (tab > 0) { wall.pendingThumbs[line.slice(tab + 1)] = line.slice(0, tab); flushThumbs.start(); }
            }
        }
        onExited: flushThumbs.start()
    }
    // hand the finished ones to the cards in batches (a new object each time, so bindings see it)
    Timer {
        id: flushThumbs
        interval: 60
        onTriggered: {
            const add = wall.pendingThumbs;
            if (!Object.keys(add).length) return;
            wall.pendingThumbs = ({});
            wall.picThumbs = Object.assign({}, wall.picThumbs, add);
        }
    }
    // pick a video or GIF with a file dialog and copy it into the Live folder
    function addLive() { addProc.running = true; }
    Process {
        id: addProc
        command: ["sh", "-c",
            "f=\"$(zenity --file-selection --title='Add a live wallpaper' --file-filter='Videos and GIFs | *.mp4 *.webm *.mkv *.mov *.gif *.MP4 *.WEBM *.MKV *.MOV *.GIF' 2>/dev/null)\" || exit 1; " +
            "mkdir -p \"$1\" && cp -n \"$f\" \"$1/\" && printf '%s/%s' \"$1\" \"$(basename \"$f\")\"", "_", wall.liveDir]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) { wall.pendingAdd = p; wall.rescan(); } } }
    }
    property string pendingAdd: ""      // just added: set it once the scan has found it
    function openLiveDir() { Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "_", liveDir]); }
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
        command: ["sh", "-c", "find \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) | sort", "_", wall.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                wall.images = text.split("\n").filter(l => l);
                wall.makeThumbs();
                wall.makePicThumbs();
                if (wall.pendingAdd && wall.images.indexOf(wall.pendingAdd) !== -1) { wall.set(wall.pendingAdd); wall.pendingAdd = ""; }
                // first start: make a palette for whatever wallpaper there is
                if (!wall.checked) { wall.checked = true; firstPalette.running = true; }
            }
        }
    }
    onDirChanged: rescan()

    function set(p) {
        Store.set("wallpaper.path", p);
        // a picture for every screen again
        Store.set("wallpaper.screens", {});
        makePalette(p);
    }
    // a random other picture from the folder (the bar's shuffle button)
    function shuffle() {
        const pool = images.filter(i => i !== path && !isVideo(i));
        if (pool.length > 0) set(pool[Math.floor(Math.random() * pool.length)]);
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

    property bool checked: false
    Component.onCompleted: rescan()
    Process {
        id: firstPalette
        command: ["test", "-s", wall.paletteFile]
        onExited: code => { if (code !== 0 && wall.path !== "") wall.makePalette(wall.path); }
    }
}
