pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The capture overlay's state and actions. start() freezes every screen (grim, one picture
// per output) and shows the overlay (capture/CaptureOverlay.qml) on them; you pick a region or
// a whole screen; finish(action) crops the frozen picture and saves, copies, edits, reads the
// text from it or scans a QR code. Video records the picked area live (Tasks).
Singleton {
    id: cap
    property bool active: false          // the overlay is up
    property bool freezing: false        // pictures being taken
    property string kind: "photo"        // photo | video
    property string mode: "region"       // region | screen
    property string screenName: ""       // the screen the selection is on
    property rect sel: Qt.rect(0, 0, 0, 0)  // the selection, in that screen's coordinates
    property string preferred: "save"    // what Enter does: save | edit
    // take it as soon as the selection is let go (Settings → Screenshots); the old shell's
    // general.screenshotCaptureOnRelease carries over
    readonly property bool onRelease: Store.get("capture.onRelease", !!(Prefs.raw.general && Prefs.raw.general.screenshotCaptureOnRelease === true)) === true
    readonly property bool hasSel: mode === "screen" ? screenName !== "" : (sel.width >= 4 && sel.height >= 4)

    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-capture"
    // uncompressed (PPM): grim writes it in ~30 ms, a PNG took ~400 ms per screen
    function frozen(name) { return runDir + "/" + name + ".ppm"; }
    property int stamp: 0                // changes with each freeze, so the pictures reload

    // where screenshots go: the folder of niri's screenshot-path, else ~/Pictures/Screenshots
    property string folder: Quickshell.env("HOME") + "/Pictures/Screenshots"
    function readFolder() {
        NiriConf.read(["-|screenshot-path"], v => {
            const p = NiriConf.unquote(v["-|screenshot-path"]);
            if (p !== "") cap.folder = p.replace(/\/[^\/]*$/, "").replace(/^~/, Quickshell.env("HOME"));
        });
    }

    // ── start: freeze, then show ──
    function start(opts) {
        if (active || freezing) return;
        opts = opts || {};
        kind = opts.kind || "photo";
        mode = opts.mode || "region";
        preferred = opts.edit ? "edit" : "save";
        sel = Qt.rect(0, 0, 0, 0);
        screenName = "";
        freezing = true;
        readFolder();
        // an open island closes first, so it isn't in the picture
        if (HubState.open) { HubState.close(); freezeLater.restart(); } else freezeNow();
    }
    Timer { id: freezeLater; interval: 450; onTriggered: cap.freezeNow() }
    function freezeNow() {
        // every screen at once; the overlay waits for all of them
        freeze.command = ["sh", "-c", "mkdir -p \"$1\"; d=\"$1\"; shift; for o; do grim -t ppm -o \"$o\" \"$d/$o.ppm\" & done; wait", "_", runDir]
            .concat(Quickshell.screens.map(s => s.name));
        freeze.running = true;
    }
    Process {
        id: freeze
        onExited: { cap.freezing = false; cap.stamp++; cap.active = true; focusProc.running = true; }
    }
    // in screen mode, the focused screen is picked to start with
    Process {
        id: focusProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector { onStreamFinished: { try { cap.focused = JSON.parse(text).name; } catch (e) {} if (cap.mode === "screen" && cap.screenName === "") cap.screenName = cap.focused; } }
    }
    property string focused: ""

    // the overlay closes after the click or key that closed it has been handled: hiding its
    // windows inside their own event handler destroyed them mid-event and crashed the shell
    property bool closing: false
    function hide() { closing = true; Qt.callLater(() => { cap.active = false; cap.closing = false; }); }
    function cancel() { hide(); sel = Qt.rect(0, 0, 0, 0); }

    // ── finish ──
    // action: save | copy | edit | text | qr  (photo), or record (video)
    function finish(action) {
        if (!hasSel || !active || closing) return;
        const scr = Quickshell.screens.find(s => s.name === screenName);
        if (!scr) return;
        const r = mode === "screen" ? Qt.rect(0, 0, scr.width, scr.height) : sel;
        hide();
        if (kind === "video") {
            // wf-recorder takes the layout's (logical) coordinates
            if (mode === "screen") Tasks.startRecording({ output: screenName });
            else Tasks.startRecording(Math.round(scr.x + r.x) + "," + Math.round(scr.y + r.y) + " " + Math.round(r.width) + "x" + Math.round(r.height));
            return;
        }
        const out = folder + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".png";
        const tmp = runDir + "/shot.png";
        // the frozen picture is in pixels: scale the selection by its size / the screen's size
        const crop = "SCALE=$(magick identify -format '%w' \"$1\"); " +
            "s=$(awk -v a=\"$SCALE\" -v b=" + scr.width + " 'BEGIN{print a/b}'); " +
            "geo=$(awk -v s=\"$s\" 'BEGIN{printf \"%dx%d+%d+%d\", " + r.width + "*s, " + r.height + "*s, " + r.x + "*s, " + r.y + "*s}'); " +
            "magick \"$1\" -crop \"$geo\" +repage \"$2\" || exit 1; ";
        const then = {
            save: "mkdir -p \"$(dirname \"$3\")\" && cp \"$2\" \"$3\" && wl-copy --type image/png < \"$3\" && notify-send -a Monolith -i \"$3\" 'Screenshot saved' \"Copied too. In $(dirname \"$3\")\"",
            copy: "wl-copy --type image/png < \"$2\" && notify-send -a Monolith -i \"$2\" 'Screenshot copied'",
            edit: "mkdir -p \"$(dirname \"$3\")\" && exec satty --filename \"$2\" --output-filename \"$3\" --copy-command wl-copy",
            text: "t=$(tesseract \"$2\" - -l " + Store.get("capture.ocr", "eng") + " 2>/dev/null); if [ -n \"$(printf '%s' \"$t\" | tr -d '[:space:]')\" ]; then printf '%s' \"$t\" | wl-copy; notify-send -a Monolith 'Text copied' \"$(printf '%s' \"$t\" | head -c 160)\"; else notify-send -a Monolith 'No text found' 'Nothing readable in that area'; fi",
            qr: "q=$(zbarimg -q --raw \"$2\" 2>/dev/null); if [ -n \"$q\" ]; then printf '%s' \"$q\" | wl-copy; notify-send -a Monolith 'QR code copied' \"$(printf '%s' \"$q\" | head -c 160)\"; else notify-send -a Monolith 'No QR code found' 'Pick the code with a bit of space around it'; fi"
        }[action] || "";
        Quickshell.execDetached(["sh", "-c", crop + then, "_", frozen(screenName), tmp, out]);
    }

    IpcHandler {
        target: "capture"
        // kind: photo | video; mode: region | screen; edit: Enter opens the editor
        function start(kind: string, mode: string, edit: bool): void { cap.start({ kind: kind || "photo", mode: mode || "region", edit: edit }); }
        function cancel(): void { cap.cancel(); }
        // for scripts: pick an area on a screen, then do an action (save | copy | edit | text | qr | record)
        function select(screen: string, x: int, y: int, w: int, h: int): void { cap.screenName = screen; cap.mode = "region"; cap.sel = Qt.rect(x, y, w, h); }
        function finish(action: string): void { cap.finish(action); }
    }
}
