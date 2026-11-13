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
        // open menus stay open and are in the picture (a screenshot of a menu is often the point);
        // only when the shot was started from a menu's own button (Capture: Region, Screen…) does
        // that menu get out of the way first
        if (opts.closeHub && HubState.open) { HubState.close(); freezeLater.restart(); } else freezeNow();
    }
    Timer { id: freezeLater; interval: 450; onTriggered: cap.freezeNow() }
    function freezeNow() {
        // every screen at once; the overlay waits for all of them
        // (and yesterday's crops and edits go: they're kept a day for pins and the preview)
        freeze.command = ["sh", "-c", "mkdir -p \"$1\"; find \"$1\" -maxdepth 1 \\( -name 'shot-*' -o -name 'edit-*' \\) -mmin +1440 -delete 2>/dev/null; d=\"$1\"; shift; for o; do grim -t ppm -o \"$o\" \"$d/$o.ppm\" & done; wait", "_", runDir]
            .concat(Quickshell.screens.map(s => s.name));
        freeze.running = true;
    }
    Process {
        id: freeze
        onExited: {
            cap.freezing = false; cap.stamp++; cap.active = true;
            // the focused screen: niri is asked; on Hyprland the shell already knows
            if (Niri.hyprland) { cap.focused = Niri.focusedOutput; if (cap.mode === "screen" && cap.screenName === "") cap.screenName = cap.focused; }
            else focusProc.running = true;
        }
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
    // action: save | copy | edit | pin | text | qr  (photo), or record (video)
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
        Sounds.play("shutter");
        const stamp = Date.now();
        const out = folder + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + "." + format;
        const tmp = runDir + "/shot-" + stamp + ".png";
        const shotScreen = screenName;
        const at = Qt.rect(r.x, r.y, r.width, r.height);
        // the frozen picture is in pixels: scale the selection by its size / the screen's size
        const crop = "SCALE=$(magick identify -format '%w' \"$1\"); " +
            "s=$(awk -v a=\"$SCALE\" -v b=" + scr.width + " 'BEGIN{print a/b}'); " +
            "geo=$(awk -v s=\"$s\" 'BEGIN{printf \"%dx%d+%d+%d\", " + r.width + "*s, " + r.height + "*s, " + r.x + "*s, " + r.y + "*s}'); " +
            "magick \"$1\" -crop \"$geo\" +repage \"$2\" || exit 1; ";
        const args = [frozen(screenName), tmp, out];
        if (action === "save") {
            run(crop + saveScript(), args, code => { if (code === 0) cap.saved(out, shotScreen); });
        } else if (action === "copy") {
            run(crop + "wl-copy --type image/png < \"$2\"", args, code => {
                if (code !== 0) return;
                if (previewOn) showPreview(tmp, shotScreen, false);
                else Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", tmp, "Screenshot copied"]);
            });
        } else if (action === "edit") {
            run(crop, args, code => { if (code === 0) cap.edit(tmp, out); });
        } else if (action === "pin") {
            run(crop, args, code => { if (code === 0) cap.pin(tmp, shotScreen, at); });
        } else {
            const then = {
                text: "t=$(tesseract \"$2\" - -l " + Store.get("capture.ocr", "eng") + " 2>/dev/null); if [ -n \"$(printf '%s' \"$t\" | tr -d '[:space:]')\" ]; then printf '%s' \"$t\" | wl-copy; notify-send -a Monolith 'Text copied' \"$(printf '%s' \"$t\" | head -c 160)\"; else notify-send -a Monolith 'No text found' 'Nothing readable in that area'; fi",
                qr: "q=$(zbarimg -q --raw \"$2\" 2>/dev/null); if [ -n \"$q\" ]; then printf '%s' \"$q\" | wl-copy; notify-send -a Monolith 'QR code copied' \"$(printf '%s' \"$q\" | head -c 160)\"; else notify-send -a Monolith 'No QR code found' 'Pick the code with a bit of space around it'; fi"
            }[action] || "";
            run(crop + then, args, null);
        }
    }

    // ── options (Settings → Screenshots) ──
    // which tools the capture menu shows (Save is always there)
    readonly property var tools: Store.get("capture.tools", ({})) || ({})
    function toolOn(t) { return tools[t] !== false; }
    readonly property string format: Store.get("capture.format", "png")
    readonly property int quality: Number(Store.get("capture.quality", 92))
    readonly property bool copyOnSave: Store.get("capture.copyOnSave", true) !== false
    readonly property bool previewOn: Store.get("capture.preview", true) !== false
    readonly property string editor: Store.get("capture.editor", "builtin")
    // $2: the cropped PNG, $3: where it goes (in the chosen format), copied too when that's on
    function saveScript() {
        return "mkdir -p \"$(dirname \"$3\")\" && " +
            (format === "png" ? "cp \"$2\" \"$3\"" : "magick \"$2\" -quality " + quality + " \"$3\"") +
            (copyOnSave ? " && wl-copy --type image/png < \"$2\"" : "");
    }
    // a file was saved: the preview in the corner, or a notification
    function saved(f, screen) {
        if (previewOn) showPreview(f, screen, true);
        else Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", f, "Screenshot saved", (copyOnSave ? "Copied too. " : "") + "In " + f.replace(/\/[^\/]*$/, "").replace(Quickshell.env("HOME"), "~")]);
    }

    // shell jobs that tell us when they're done
    Component { id: jobC; Process {} }
    Component { id: outC; StdioCollector {} }
    function run(script, args, done) {
        const p = jobC.createObject(cap, { command: ["sh", "-c", script, "_"].concat(args) });
        p.exited.connect(code => { if (done) done(code); p.destroy(); });
        p.running = true;
    }

    // ── the preview: a small card in a corner for a few seconds after a shot (capture/ShotPreview) ──
    property string previewFile: ""
    property string previewScreen: ""
    property bool previewSaved: false      // it's a saved file (Delete removes it), not just copied
    property int previewStamp: 0
    function showPreview(f, screen, isSaved) { previewFile = f; previewScreen = screen || Niri.focusedOutput; previewSaved = isSaved; previewStamp++; }
    function closePreview() { previewFile = ""; }
    function deleteShot(f) { Quickshell.execDetached(["rm", "-f", f]); if (previewFile === f) closePreview(); }
    function openFolder(f) { Quickshell.execDetached(["xdg-open", f.replace(/\/[^\/]*$/, "")]); }
    function copyFile(f) { Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\" || magick \"$1\" png:- | wl-copy --type image/png", "_", f]); }

    // ── the editor (capture/ShotEditor): the built-in one, or satty / swappy ──
    property string editFile: ""           // the picture being edited ("" = closed)
    property string editOut: ""            // where Save puts it
    function edit(f, out) {
        out = out || (folder + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + "." + format);
        if (editor === "satty") Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; exec satty --filename \"$1\" --output-filename \"$2\" --copy-command wl-copy", "_", f, out]);
        else if (editor === "swappy") Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; exec swappy -f \"$1\" -o \"$2\"", "_", f, out]);
        else { editOut = out; editFile = ""; editFile = f; }
    }
    // the editor's picture, flattened to a PNG ($1): saved where it goes (and copied)
    function saveEdited(png, out, then) {
        run(saveScript(), ["", png, out], code => { if (code === 0) { if (then) then(out); else saved(out, Niri.focusedOutput); } });
    }

    // ── pinned shots: stay on top of the windows (capture/Pins) ──
    property var pins: []                  // [{ id, file, screen, x, y, w, h }]
    property int pinSeq: 0
    function pin(f, screen, at) {
        const scr = Quickshell.screens.find(s => s.name === screen) || Quickshell.screens[0];
        if (!scr) return;
        // a file without a place on screen: its own size (in the screen's logical pixels), centred
        if (!at) {
            const p = jobC.createObject(cap, { command: ["magick", "identify", "-format", "%w %h", f] });
            const out = outC.createObject(p);
            p.stdout = out;
            out.streamFinished.connect(() => {
                const wh = out.text.trim().split(" ").map(Number);
                const d = scr.devicePixelRatio || 1;
                if (wh.length === 2 && wh[0] > 0) {
                    const w = wh[0] / d, h = wh[1] / d;
                    cap.pin(f, screen, Qt.rect((scr.width - w) / 2, (scr.height - h) / 2, w, h));
                }
                p.destroy();
            });
            p.running = true;
            return;
        }
        // as big as it was taken and where it was; bigger than 70 % of the screen: shrunk, centred
        const k = Math.min(1, scr.width * 0.7 / at.width, scr.height * 0.7 / at.height);
        const w = Math.max(60, Math.round(at.width * k)), h = Math.max(40, Math.round(at.height * k));
        const x = k === 1 ? Math.round(at.x) : Math.round((scr.width - w) / 2);
        const y = k === 1 ? Math.round(at.y) : Math.round((scr.height - h) / 2);
        pinSeq++;
        pins = pins.concat([{ id: pinSeq, file: f, screen: scr.name, x: x, y: y, w: w, h: h }]);
    }
    function unpin(id) { pins = pins.filter(p => p.id !== id); }
    function movePin(id, x, y) { pins = pins.map(p => p.id === id ? Object.assign({}, p, { x: x, y: y }) : p); }

    // ── a shot after a few seconds (a menu that has to be open, a tooltip): counts down, then starts ──
    property int countdown: 0
    property var delayedOpts: ({})
    function startIn(secs, opts) {
        if (active || freezing || countdown > 0) return;
        if (!(secs > 0)) { start(opts); return; }
        delayedOpts = opts || {};
        if (delayedOpts.closeHub && HubState.open) HubState.close();
        countdown = secs;
        tick.restart();
    }
    Timer {
        id: tick
        interval: 1000; repeat: true
        onTriggered: { cap.countdown--; if (cap.countdown <= 0) { stop(); startSoon.restart(); } }
    }
    // (the countdown's bubble is gone from the screen first)
    Timer { id: startSoon; interval: 250; onTriggered: cap.start(cap.delayedOpts) }
    function cancelCountdown() { tick.stop(); countdown = 0; }

    IpcHandler {
        target: "capture"
        // kind: photo | video; mode: region | screen; edit: Enter opens the editor
        function start(kind: string, mode: string, edit: bool): void { cap.start({ kind: kind || "photo", mode: mode || "region", edit: edit }); }
        function cancel(): void { cap.cancel(); }
        // for scripts: pick an area on a screen, then do an action (save | copy | edit | text | qr | record)
        function select(screen: string, x: int, y: int, w: int, h: int): void { cap.screenName = screen; cap.mode = "region"; cap.sel = Qt.rect(x, y, w, h); }
        function finish(action: string): void { cap.finish(action); }
        // the same after a few seconds
        function delayed(seconds: int, kind: string, mode: string): void { cap.startIn(seconds, { kind: kind || "photo", mode: mode || "region" }); }
        // open a picture in the editor (the built-in one, or the one picked in Settings)
        function editFile(path: string): void { cap.edit(path, ""); }
        function pinFile(path: string): void { cap.pin(path, Niri.focusedOutput, null); }
    }
}
