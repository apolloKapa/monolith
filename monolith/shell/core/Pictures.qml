pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Picking a picture (the picture widget, your avatar…): a file chooser that starts in your
// Pictures folder and shows only images, and your most recent pictures to click instead
// (the newest files in ~/Pictures and its folders, screenshots and wallpapers included).
Singleton {
    id: pics
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Pictures"
    property var recent: []
    function refresh() { if (!scan.running) scan.running = true; }
    Process {
        id: scan
        command: ["sh", "-c", "find \"$1\" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 24 | cut -f2-", "_", pics.dir]
        stdout: StdioCollector { onStreamFinished: pics.recent = text.split("\n").filter(l => l) }
    }
    // a file dialog; `done(path)` gets the picked file (nothing when cancelled). While it's
    // open `picking` is true: the shell's full-screen layers (the widget editor, Settings) step
    // out of the way, since a normal window like this one always opens underneath them
    property bool picking: false
    function choose(title, done) {
        pick(["--title=" + (title || "Choose a picture"), "--filename=" + pics.dir + "/",
              "--file-filter=Pictures | *.png *.jpg *.jpeg *.webp *.gif *.PNG *.JPG *.JPEG *.WEBP *.GIF"], done);
    }
    // any file chooser (zenity's own options: --directory, --multiple, --file-filter=…), with the
    // shell out of its way the same way; `done(text)` gets what zenity printed (nothing: cancelled).
    // Icon and cursor themes, fonts…: launched straight, it opened underneath Settings, unseen
    function pick(zenityArgs, done) {
        if (picking) return;
        picking = true;
        const p = chooserC.createObject(pics, { command: ["sh", "-c",
            "command -v zenity >/dev/null || { notify-send -a Monolith \"Cannot open the file picker\" \"It needs zenity: install it, or run the Monolith installer again\"; exit 1; }; zenity --file-selection \"$@\" 2>/dev/null", "_"].concat(zenityArgs) });
        const out = outC.createObject(p);
        p.stdout = out;
        let file = "";
        out.streamFinished.connect(() => { file = out.text.trim(); });
        let ended = false;
        // (on running going false: also when zenity can't start, so nothing stays hidden)
        p.runningChanged.connect(() => {
            if (p.running || ended) return;
            ended = true;
            Qt.callLater(() => {
                pics.picking = false;
                const f = file || out.text.trim();
                p.destroy();
                if (f !== "" && done) { try { done(f); } catch (e) { console.warn("Pictures: " + e); } }
            });
        });
        p.running = true;
    }
    Component { id: chooserC; Process {} }
    Component { id: outC; StdioCollector {} }
    // a dropped file's URL → its path, if it's a picture
    function fromDrop(urls) {
        for (const u of urls || []) {
            const s = decodeURIComponent(String(u)).replace(/^file:\/\//, "");
            if (/\.(png|jpe?g|webp|gif)$/i.test(s)) return s;
        }
        return "";
    }
}
