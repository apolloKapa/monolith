import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// A drawing pad with no edges: draw anywhere, scroll or pinch to zoom in and out as far as you
// like (2 % to 5000 %), drag with the right or middle button (or the hand, or two fingers on a
// touchpad) to move around. Pen, highlighter, line, arrow, rectangle, ellipse and an eraser that
// takes whole strokes; colours, a size, undo / redo. The drawing stays when the panel closes
// (core/Sketch). Save puts all of it in a picture in ~/Pictures and copies it; Copy only copies
// it. The pictures you saved are under the history button (click one to copy it, or open it).
// Pictures go in too: paste one (Ctrl+V), drop image files on the pad, or drag a saved drawing
// in from the history strip; the move tool drags them, resizes them from the corner, Delete
// removes the one picked.
ColumnLayout {
    id: d
    spacing: 8

    property string tool: "pen"         // pen | hl | line | arrow | rect | ellipse | eraser | hand | move
    property color ink: Theme.accent
    property real size: 4
    readonly property bool shape: ["line", "arrow", "rect", "ellipse"].indexOf(tool) !== -1

    // the stroke being drawn (not in the drawing until you let go)
    property var cur: null
    // only the newest part of the pen's line needs drawing while it's drawn: everything after
    // the points already on screen (the mouse can move several times between two paints; drawing
    // only the last piece left gaps, so lines came out dashed)
    property bool partial: false
    property int drawnTo: 0
    // the saved pictures, instead of the colours and size
    property bool showSaved: false
    // the grid (remembered): off | dots | lines (graph paper, a stronger line every fourth), and
    // snapping lines and shapes to it
    readonly property string grid: Store.get("quick.drawGrid", "dots")
    readonly property bool snap: Store.get("quick.drawSnap", false) === true && grid !== "off"
    // the grid's spacing in drawing units at this zoom: 32 at 100 %, halved or doubled as you zoom
    // so the squares stay 16..64 px on screen
    function gridStep(z) {
        let step = 32;
        while (step * z < 16) step *= 2;
        while (step * z > 64) step /= 2;
        return step;
    }
    function snapped(w) {
        if (!snap) return w;
        const st = gridStep(Sketch.z);
        return Qt.point(Math.round(w.x / st) * st, Math.round(w.y / st) * st);
    }

    function toWorld(px, py) { return Qt.point(Sketch.ox + px / Sketch.z, Sketch.oy + py / Sketch.z); }
    function zoomAt(px, py, f) {
        const w = toWorld(px, py);
        const nz = Math.max(Sketch.minZ, Math.min(Sketch.maxZ, Sketch.z * f));
        Sketch.ox = w.x - px / nz; Sketch.oy = w.y - py / nz; Sketch.z = nz;
        Sketch.moved();
    }
    function panBy(dx, dy) { Sketch.ox -= dx / Sketch.z; Sketch.oy -= dy / Sketch.z; Sketch.moved(); }

    // ── pictures ──
    // the one picked with the move tool (its index in the strokes), -1: none
    property int picked: -1
    readonly property var pickedPic: picked >= 0 && picked < Sketch.strokes.length && Sketch.strokes[picked].t === "img" ? Sketch.strokes[picked] : null
    Connections { target: Sketch; function onStrokesChanged() { if (!d.pickedPic) d.picked = -1; } }
    // the topmost picture under a point of the drawing
    function picAt(w) {
        for (let i = Sketch.strokes.length - 1; i >= 0; i--) {
            const s = Sketch.strokes[i];
            if (s.t === "img" && w.x >= s.x && w.x <= s.x + s.w && w.y >= s.y && w.y <= s.y + s.h) return i;
        }
        return -1;
    }
    // the picked picture's handle under a point on the pad: "l" "r" "t" "b" (a side: stretches
    // one way) or two of them for a corner ("rb"…: keeps its shape, or stretches with Shift); ""
    function handleAt(mx, my) {
        const p = pickedPic;
        if (!p) return "";
        const x0 = (p.x - Sketch.ox) * Sketch.z, y0 = (p.y - Sketch.oy) * Sketch.z;
        const x1 = x0 + p.w * Sketch.z, y1 = y0 + p.h * Sketch.z, r = 12;
        const inX = mx > x0 - r && mx < x1 + r, inY = my > y0 - r && my < y1 + r;
        if (!inX || !inY) return "";
        const h = (Math.abs(mx - x0) < r ? "l" : Math.abs(mx - x1) < r ? "r" : "")
                + (Math.abs(my - y0) < r ? "t" : Math.abs(my - y1) < r ? "b" : "");
        // a side handle only near the middle of that side (the rest of the edge moves it)
        if (h === "l" || h === "r") return Math.abs(my - (y0 + y1) / 2) < Math.max(r, (y1 - y0) * 0.25) ? h : "";
        if (h === "t" || h === "b") return Math.abs(mx - (x0 + x1) / 2) < Math.max(r, (x1 - x0) * 0.25) ? h : "";
        return h;
    }
    // the picture's new box when handle g.h is pulled by (dx, dy) in drawing units: the sides
    // it's held by move, the opposite ones stay put; a corner keeps the shape (the way it's
    // pulled furthest) unless `free` (Shift)
    function resized(g, dx, dy, free) {
        const hd = g.h, minS = 8 / Sketch.z;
        let w = g.w + (hd.indexOf("r") !== -1 ? dx : hd.indexOf("l") !== -1 ? -dx : 0);
        let h = g.h0 + (hd.indexOf("b") !== -1 ? dy : hd.indexOf("t") !== -1 ? -dy : 0);
        if (hd.length === 2 && !free) {
            const k = Math.max(w / g.w, h / g.h0);
            w = g.w * k; h = g.h0 * k;
        }
        w = Math.max(minS, w); h = Math.max(minS, h);
        return { w: w, h: h, x: hd.indexOf("l") !== -1 ? g.x + g.w - w : g.x, y: hd.indexOf("t") !== -1 ? g.y + g.h0 - h : g.y };
    }
    function handleCursor(h) {
        return h === "l" || h === "r" ? Qt.SizeHorCursor : h === "t" || h === "b" ? Qt.SizeVerCursor
             : h === "lt" || h === "rb" ? Qt.SizeFDiagCursor : h ? Qt.SizeBDiagCursor : Qt.ArrowCursor;
    }
    // a picture file goes in: copied into the drawing's own folder, then placed (centred on
    // px, py on the pad; at most 60 % of what you see, so a huge photo doesn't swamp the view)
    function addPictureFile(path, px, py) {
        const q = picQueue.slice();
        q.push({ path: path, px: px, py: py });
        picQueue = q;
        if (!copyPic.running) nextPicture();
    }
    property var picQueue: []
    function nextPicture() {
        if (!picQueue.length) return;
        const job = picQueue[0];
        picQueue = picQueue.slice(1);
        copyPic.job = job;
        copyPic.command = ["sh", "-c", "mkdir -p \"$2\" && ext=\"${1##*.}\"; case \"$ext\" in */*|\"$1\") ext=png;; esac; " +
            "dest=\"$2/$(date +%s%N).$ext\"; cp -- \"$1\" \"$dest\" && printf %s \"$dest\"", "_", job.path, Sketch.picDir];
        copyPic.running = true;
    }
    Process {
        id: copyPic
        property var job: null
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f && copyPic.job) d.placePicture(f, copyPic.job.px, copyPic.job.py); } }
        onExited: d.nextPicture()
    }
    // its natural size first (an Image tells), then into the drawing as one undoable change
    function placePicture(file, px, py) { probe.createObject(d, { file: file, px: px, py: py }); }
    Component {
        id: probe
        Image {
            property string file: ""
            property real px: 0
            property real py: 0
            visible: false
            asynchronous: true
            source: file ? Wall.url(file) : ""
            onStatusChanged: {
                if (status === Image.Ready) {
                    const iw = Math.max(1, implicitWidth), ih = Math.max(1, implicitHeight);
                    const k = Math.min(1, pad.width * 0.6 / Sketch.z / iw, pad.height * 0.6 / Sketch.z / ih);
                    const c = d.toWorld(px, py);
                    const pic = { t: "img", f: file, x: c.x - iw * k / 2, y: c.y - ih * k / 2, w: iw * k, h: ih * k };
                    Sketch.commit(Sketch.strokes.concat([pic]));
                    d.picked = Sketch.strokes.length - 1;
                    d.tool = "move";
                    destroy();
                } else if (status === Image.Error) {
                    Quickshell.execDetached(["notify-send", "-a", "Monolith", "Couldn't add that picture", file.replace(/^.*\//, "")]);
                    destroy();
                }
            }
        }
    }
    // Ctrl+V: a copied picture (a browser's, a screenshot), or image files copied in a file manager
    function pastePicture() {
        pasteProc.running = true;
    }
    Process {
        id: pasteProc
        command: ["sh", "-c",
            "types=\"$(wl-paste --list-types 2>/dev/null)\" || exit 1; mkdir -p \"$1\"; " +
            "for t in image/png image/jpeg image/webp image/gif image/bmp; do " +
            "  if printf '%s\\n' \"$types\" | grep -qx \"$t\"; then f=\"$1/$(date +%s%N).${t#image/}\"; wl-paste -n -t \"$t\" > \"$f\" && printf 'file\\t%s\\n' \"$f\"; exit 0; fi; done; " +
            "if printf '%s\\n' \"$types\" | grep -qx 'text/uri-list'; then wl-paste -n -t text/uri-list | tr -d '\\r' | sed -n 's|^file://||p' | while IFS= read -r p; do printf 'path\\t%s\\n' \"$(printf '%b' \"$(printf %s \"$p\" | sed 's/%/\\\\x/g')\")\"; done; fi",
            "_", Sketch.picDir]
        stdout: SplitParser {
            onRead: line => {
                const tab = line.indexOf("\t");
                if (tab < 0) return;
                const kind = line.slice(0, tab), path = line.slice(tab + 1);
                if (kind === "file") d.placePicture(path, pad.width / 2, pad.height / 2);
                else if (/\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path)) d.addPictureFile(path, pad.width / 2, pad.height / 2);
            }
        }
    }
    Shortcut { sequences: [StandardKey.Paste]; onActivated: d.pastePicture() }
    Shortcut { sequences: [StandardKey.Delete, "Backspace"]; enabled: !!d.pickedPic; onActivated: { const i = d.picked; d.picked = -1; Sketch.commit(Sketch.strokes.filter((x, j) => j !== i)); } }
    // the picture button: pick files
    function choosePicture() { chooseProc.running = true; }
    Process {
        id: chooseProc
        command: ["sh", "-c", "zenity --file-selection --multiple --separator='\\n' --title='Add a picture' --file-filter='Pictures | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.PNG *.JPG *.JPEG *.WEBP' 2>/dev/null"]
        stdout: SplitParser { onRead: line => { if (line.trim()) d.addPictureFile(line.trim(), pad.width / 2, pad.height / 2); } }
    }

    // the box round all of it, in drawing coordinates
    function bounds() {
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const s of Sketch.strokes) {
            if (s.t === "img") {
                x0 = Math.min(x0, s.x); y0 = Math.min(y0, s.y);
                x1 = Math.max(x1, s.x + s.w); y1 = Math.max(y1, s.y + s.h);
                continue;
            }
            const m = s.s / 2 + 2;
            for (let i = 0; i < s.pts.length; i += 2) {
                x0 = Math.min(x0, s.pts[i] - m); y0 = Math.min(y0, s.pts[i + 1] - m);
                x1 = Math.max(x1, s.pts[i] + m); y1 = Math.max(y1, s.pts[i + 1] + m);
            }
        }
        return x0 === Infinity ? null : { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
    }
    // see all of it
    function fit() {
        const b = bounds();
        if (!b) { Sketch.ox = 0; Sketch.oy = 0; Sketch.z = 1; Sketch.moved(); return; }
        const z = Math.max(Sketch.minZ, Math.min(Sketch.maxZ, Math.min(pad.width / b.w, pad.height / b.h) * 0.88));
        Sketch.z = z;
        Sketch.ox = b.x + b.w / 2 - pad.width / 2 / z;
        Sketch.oy = b.y + b.h / 2 - pad.height / 2 / z;
        Sketch.moved();
    }

    // ── drawing a stroke ──
    function strokePath(g, s) {
        const p = s.pts;
        if (s.t === "pen" || s.t === "hl") {
            g.beginPath(); g.moveTo(p[0], p[1]);
            for (let i = 2; i < p.length; i += 2) g.lineTo(p[i], p[i + 1]);
            if (p.length === 2) g.lineTo(p[0] + 0.01, p[1]);
            g.stroke();
            return;
        }
        if (p.length < 4) return;
        const x0 = p[0], y0 = p[1], x1 = p[2], y1 = p[3];
        if (s.t === "rect") { g.strokeRect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0)); return; }
        if (s.t === "ellipse") { g.beginPath(); g.ellipse(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0)); g.stroke(); return; }
        g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1);
        if (s.t === "arrow") {
            const a = Math.atan2(y1 - y0, x1 - x0), h = Math.max(10, s.s * 3.5);
            g.moveTo(x1, y1); g.lineTo(x1 - h * Math.cos(a - 0.45), y1 - h * Math.sin(a - 0.45));
            g.moveTo(x1, y1); g.lineTo(x1 - h * Math.cos(a + 0.45), y1 - h * Math.sin(a + 0.45));
        }
        g.stroke();
    }
    function styleFor(g, s) {
        g.strokeStyle = s.c;
        g.globalAlpha = s.t === "hl" ? 0.35 : 1;
        g.lineWidth = s.t === "hl" ? s.s * 3 : s.s;
        g.lineCap = s.t === "hl" ? "butt" : "round";
        g.lineJoin = "round";
    }
    // a picture: drawn once its canvas has loaded it (a Canvas keeps its own image cache);
    // a soft box until then
    function picUrl(s) { return Wall.url(s.f); }
    function drawPic(g, s, cvs) {
        const u = picUrl(s);
        g.globalAlpha = 1;
        if (cvs.isImageLoaded(u)) g.drawImage(u, s.x, s.y, s.w, s.h);
        else {
            if (!cvs.isImageLoading(u)) cvs.loadImage(u);
            if (cvs === cv) picWait.restart();
            g.fillStyle = Qt.alpha(Theme.text, 0.08);
            g.fillRect(s.x, s.y, s.w, s.h);
        }
    }
    function drawOne(g, s, cvs) {
        if (s.t === "img") { drawPic(g, s, cvs); return; }
        styleFor(g, s); strokePath(g, s);
    }
    function paintAll(g, w, h, ox, oy, z, grid, cvs) {
        g.reset();
        g.clearRect(0, 0, w, h);
        // the grid: it moves and scales with the drawing, so you can see where you are
        if (grid && d.grid !== "off") {
            const step = d.gridStep(z);
            if (d.grid === "dots") {
                g.fillStyle = Qt.alpha(Theme.text, 0.45);
                const r = Math.max(2, Math.min(3, z * 2));
                for (let x = Math.floor(ox / step) * step; x < ox + w / z; x += step)
                    for (let y = Math.floor(oy / step) * step; y < oy + h / z; y += step)
                        g.fillRect((x - ox) * z - r / 2, (y - oy) * z - r / 2, r, r);
            } else {
                // thin lines, and a stronger one every fourth (on whole multiples, so they stay
                // put as the spacing halves and doubles)
                const major = step * 4;
                const line = (x0, y0, x1, y1) => { g.moveTo(Math.round(x0) + 0.5, Math.round(y0) + 0.5); g.lineTo(Math.round(x1) + 0.5, Math.round(y1) + 0.5); };
                for (const strong of [false, true]) {
                    g.beginPath();
                    g.lineWidth = 1;
                    g.strokeStyle = Qt.alpha(Theme.text, strong ? 0.22 : 0.1);
                    for (let x = Math.floor(ox / step) * step; x < ox + w / z; x += step) {
                        const isMajor = Math.abs(Math.round(x / major) * major - x) < 1e-6;
                        if (isMajor === strong) line((x - ox) * z, 0, (x - ox) * z, h);
                    }
                    for (let y = Math.floor(oy / step) * step; y < oy + h / z; y += step) {
                        const isMajor = Math.abs(Math.round(y / major) * major - y) < 1e-6;
                        if (isMajor === strong) line(0, (y - oy) * z, w, (y - oy) * z);
                    }
                    g.stroke();
                }
            }
        }
        g.setTransform(z, 0, 0, z, -ox * z, -oy * z);
        for (const s of Sketch.strokes) drawOne(g, s, cvs);
        if (d.cur) { styleFor(g, d.cur); strokePath(g, d.cur); }
    }

    // erasing: the strokes that pass within r of (x, y)
    function near(s, x, y, r) {
        if (s.t === "img") return x >= s.x - r && x <= s.x + s.w + r && y >= s.y - r && y <= s.y + s.h + r;
        const p = s.pts, rr = r + s.s / 2;
        const seg = (ax, ay, bx, by) => {
            const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy;
            const t = l > 0 ? Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / l)) : 0;
            const qx = ax + t * dx - x, qy = ay + t * dy - y;
            return qx * qx + qy * qy <= rr * rr;
        };
        if (s.t === "pen" || s.t === "hl") {
            if (p.length === 2) return seg(p[0], p[1], p[0], p[1]);
            for (let i = 2; i < p.length; i += 2) if (seg(p[i - 2], p[i - 1], p[i], p[i + 1])) return true;
            return false;
        }
        const x0 = p[0], y0 = p[1], x1 = p[2], y1 = p[3];
        if (s.t === "rect") return seg(x0, y0, x1, y0) || seg(x1, y0, x1, y1) || seg(x1, y1, x0, y1) || seg(x0, y1, x0, y0);
        if (s.t === "ellipse") {
            const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, ax = Math.abs(x1 - x0) / 2, ay = Math.abs(y1 - y0) / 2;
            let px = cx + ax, py = cy;
            for (let i = 1; i <= 36; i++) {
                const a = i / 36 * 2 * Math.PI, nx = cx + ax * Math.cos(a), ny = cy + ay * Math.sin(a);
                if (seg(px, py, nx, ny)) return true;
                px = nx; py = ny;
            }
            return false;
        }
        return seg(x0, y0, x1, y1);
    }

    // a small icon button
    component Tb: Pressable {
        property string icon: ""
        property bool on: false
        property string tip: ""
        width: 32; height: 32
        Layout.preferredWidth: 32; Layout.preferredHeight: 32
        radius: Theme.corner(32, -2)
        color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
        opacity: enabled ? 1 : 0.35
        Icon { anchors.centerIn: parent; name: parent.icon; size: 18; filled: parent.on; color: parent.on ? Theme.onAccentContainer : Theme.text }
    }

    // ── the top: name and zoom ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Label { text: "Draw"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
        // the grid: off → dots → lines; snapping lines and shapes to it
        Pressable {
            Layout.preferredWidth: gl.implicitWidth + 38; Layout.preferredHeight: 32
            color: d.grid !== "off" ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
            onClicked: Store.set("quick.drawGrid", ({ off: "dots", dots: "lines", lines: "off" })[d.grid] || "dots")
            Row { anchors.centerIn: parent; spacing: 4
                Icon { name: d.grid === "off" ? "grid_off" : (d.grid === "dots" ? "blur_on" : "grid_on"); size: 17; color: d.grid !== "off" ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: gl; text: ({ off: "No grid", dots: "Dots", lines: "Grid" })[d.grid] || "Dots"; font.pixelSize: Theme.sizeSmall; color: d.grid !== "off" ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
        }
        Pressable {
            visible: d.grid !== "off"
            Layout.preferredWidth: sl2.implicitWidth + 38; Layout.preferredHeight: 32
            color: d.snap ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
            onClicked: Store.set("quick.drawSnap", !d.snap)
            Row { anchors.centerIn: parent; spacing: 4
                Icon { name: "grid_guides"; size: 17; color: d.snap ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: sl2; text: "Snap"; font.pixelSize: Theme.sizeSmall; color: d.snap ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
        }
        Item { Layout.preferredWidth: 6; Layout.preferredHeight: 1 }
        Tb { icon: "zoom_out"; onClicked: d.zoomAt(pad.width / 2, pad.height / 2, 1 / 1.25) }
        Pressable {
            Layout.preferredWidth: zl.implicitWidth + 16; Layout.preferredHeight: 32
            color: hovered ? Theme.containerHigh : "transparent"
            // back to 100 %, keeping the middle where it is
            onClicked: d.zoomAt(pad.width / 2, pad.height / 2, 1 / Sketch.z)
            Label { id: zl; anchors.centerIn: parent; text: (Sketch.z >= 10 ? Math.round(Sketch.z * 100) : Math.round(Sketch.z * 1000) / 10) + " %"; font.pixelSize: Theme.sizeSmall; strong: true }
        }
        Tb { icon: "zoom_in"; onClicked: d.zoomAt(pad.width / 2, pad.height / 2, 1.25) }
        Tb { icon: "fit_screen"; onClicked: d.fit() }
    }

    // ── the pad ──
    Rectangle {
        id: pad
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.corner(80, 4)
        color: Theme.container
        clip: true

        Canvas {
            id: cv
            anchors.fill: parent
            renderStrategy: Canvas.Immediate
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: Sketch; function onRevChanged() { d.partial = false; cv.requestPaint(); } }
            Connections { target: d; function onGridChanged() { d.partial = false; cv.requestPaint(); } }
            Component.onCompleted: requestPaint()
            onImageLoaded: { d.partial = false; requestPaint(); }
            // (Canvas doesn't always say when a later picture has loaded: look again for a moment)
            Timer {
                id: picWait
                interval: 80
                repeat: true
                property int tries: 0
                onRunningChanged: if (running) tries = 0
                onTriggered: {
                    tries++;
                    if (d.picsLoaded(cv) || tries > 60) stop();
                    d.partial = false;
                    cv.requestPaint();
                }
            }
            onPaint: {
                const g = getContext("2d");
                // the pen: just its newest piece on top of what's there
                if (d.partial && d.cur && d.cur.pts.length >= 4) {
                    const p = d.cur.pts, n = p.length;
                    const from = Math.max(0, Math.min(d.drawnTo, n) - 2);
                    g.setTransform(Sketch.z, 0, 0, Sketch.z, -Sketch.ox * Sketch.z, -Sketch.oy * Sketch.z);
                    d.styleFor(g, d.cur);
                    g.beginPath(); g.moveTo(p[from], p[from + 1]);
                    for (let i = from + 2; i < n; i += 2) g.lineTo(p[i], p[i + 1]);
                    g.stroke();
                    d.drawnTo = n;
                    return;
                }
                d.paintAll(g, width, height, Sketch.ox, Sketch.oy, Sketch.z, true, cv);
                if (d.cur) d.drawnTo = d.cur.pts.length;
            }
        }
        // the eraser's ring under the pointer
        Rectangle {
            visible: d.tool === "eraser" && ma.containsMouse
            width: Math.max(12, d.size * 2 * Sketch.z + 8); height: width; radius: width / 2
            x: ma.mouseX - width / 2; y: ma.mouseY - height / 2
            color: "transparent"; border.width: 1.5; border.color: Theme.text
        }
        // the picked picture: its outline and the handles that size and stretch it
        Item {
            id: pickBox
            readonly property var pic: d.tool === "move" ? d.pickedPic : null
            property int rev: Sketch.rev    // (moves with the view and the picture)
            visible: !!pic
            x: pic ? (pic.x - Sketch.ox) * Sketch.z + rev * 0 : 0
            y: pic ? (pic.y - Sketch.oy) * Sketch.z + rev * 0 : 0
            width: pic ? pic.w * Sketch.z + rev * 0 : 0
            height: pic ? pic.h * Sketch.z + rev * 0 : 0
            Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.width: 2; border.color: Theme.accent; radius: 2 }
            // eight handles: the corners (round: keep the shape; Shift stretches) and the sides
            // (bars: stretch it one way)
            Repeater {
                model: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]
                Rectangle {
                    required property var modelData
                    readonly property bool side: modelData[0] === 0.5 || modelData[1] === 0.5
                    width: side ? (modelData[0] === 0.5 ? 22 : 8) : 14
                    height: side ? (modelData[1] === 0.5 ? 22 : 8) : 14
                    radius: side ? 4 : 7
                    x: pickBox.width * modelData[0] - width / 2
                    y: pickBox.height * modelData[1] - height / 2
                    color: Theme.accent; border.width: 2; border.color: Theme.frame
                }
            }
        }
        // image files dropped on the pad (from a file manager, or a saved drawing from the strip below)
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => { drag.accept(Qt.CopyAction); HubState.quickHold = true; }
            onExited: HubState.quickHold = false
            onDropped: drop => {
                HubState.quickHold = false;
                const files = (drop.urls || []).map(u => String(u)).filter(u => u.startsWith("file://"))
                    .map(u => decodeURIComponent(u.slice(7))).filter(f => /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(f));
                files.forEach((f, i) => d.addPictureFile(f, drop.x + i * 24, drop.y + i * 24));
                drop.accept(Qt.CopyAction);
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: drop.containsDrag
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: 2; border.color: Theme.accent
            radius: pad.radius
            Label { anchors.centerIn: parent; text: "Drop to add the picture"; strong: true; color: Theme.accent }
        }
        Label {
            visible: Sketch.strokes.length === 0 && !d.cur
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Draw anywhere\nScroll or pinch to zoom · right-drag or two fingers to move\nPaste (Ctrl+V) or drop pictures in"
            muted: true; font.pixelSize: Theme.sizeSmall
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: panning || d.tool === "hand" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                       : d.tool === "eraser" ? Qt.BlankCursor
                       : d.tool === "move" ? (grab && grab.size ? d.handleCursor(grab.h) : (pressed && grab ? Qt.ClosedHandCursor : d.handleCursor(d.handleAt(mouseX, mouseY))))
                       : Qt.CrossCursor
            property bool panning: false
            property real lx: 0
            property real ly: 0
            property var before: null       // the strokes before an erase (or a picture's move), for undo
            property var grab: null         // the picture being moved or sized
            onPressed: mouse => {
                lx = mouse.x; ly = mouse.y;
                panning = mouse.button !== Qt.LeftButton || d.tool === "hand";
                if (panning) return;
                const w0 = d.toWorld(mouse.x, mouse.y);
                // the move tool: pick the picture under the pointer and drag it (or its corner: size)
                if (d.tool === "move") {
                    const handle = d.handleAt(mouse.x, mouse.y);
                    const i = handle ? d.picked : d.picAt(w0);
                    d.picked = i;
                    if (i < 0) return;
                    before = Sketch.strokes;
                    const work = Sketch.strokes.slice();
                    work[i] = Object.assign({}, work[i]);
                    Sketch.strokes = work;
                    grab = { i: i, size: handle !== "", h: handle, wx: w0.x, wy: w0.y, x: work[i].x, y: work[i].y, w: work[i].w, h0: work[i].h };
                    return;
                }
                if (d.tool === "eraser") { before = Sketch.strokes; erase(w0); return; }
                // (lines and shapes start on the grid when snapping is on)
                const w = d.shape ? d.snapped(w0) : w0;
                d.cur = { t: d.tool, c: String(d.ink), s: d.size, pts: d.shape ? [w.x, w.y, w.x, w.y] : [w.x, w.y] };
                d.partial = false;
                d.drawnTo = 0;
                cv.requestPaint();
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                if (panning) { d.panBy(mouse.x - lx, mouse.y - ly); lx = mouse.x; ly = mouse.y; return; }
                const w0 = d.toWorld(mouse.x, mouse.y);
                if (d.tool === "move") {
                    if (!grab) return;
                    const s = Sketch.strokes[grab.i], dx = w0.x - grab.wx, dy = w0.y - grab.wy;
                    if (grab.size) Object.assign(s, d.resized(grab, dx, dy, !!(mouse.modifiers & Qt.ShiftModifier)));
                    else { s.x = grab.x + dx; s.y = grab.y + dy; }
                    Sketch.rev++;
                    return;
                }
                if (d.tool === "eraser") { erase(w0); return; }
                if (!d.cur) return;
                const w = d.shape ? d.snapped(w0) : w0;
                if (d.shape) {
                    // Shift: straight lines snap to 45°, boxes and ellipses are square / round
                    let x = w.x, y = w.y;
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        const dx = x - d.cur.pts[0], dy = y - d.cur.pts[1];
                        if (d.tool === "line" || d.tool === "arrow") {
                            const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4), l = Math.hypot(dx, dy);
                            x = d.cur.pts[0] + l * Math.cos(a); y = d.cur.pts[1] + l * Math.sin(a);
                        } else {
                            const m = Math.max(Math.abs(dx), Math.abs(dy));
                            x = d.cur.pts[0] + Math.sign(dx || 1) * m; y = d.cur.pts[1] + Math.sign(dy || 1) * m;
                        }
                    }
                    d.cur.pts[2] = x; d.cur.pts[3] = y;
                    d.partial = false;
                } else {
                    // skip points too close together (less to store and draw)
                    const p = d.cur.pts;
                    if (Math.hypot(w.x - p[p.length - 2], w.y - p[p.length - 1]) * Sketch.z < 1.5) return;
                    p.push(w.x, w.y);
                    // the highlighter is see-through: its pieces would overlap darker, so it's redrawn whole
                    d.partial = d.tool === "pen";
                }
                cv.requestPaint();
            }
            onReleased: {
                if (panning) { panning = false; return; }
                if (d.tool === "move") {
                    if (grab && before) { const now = Sketch.strokes; Sketch.strokes = before; Sketch.commit(now); }
                    grab = null; before = null;
                    return;
                }
                if (d.tool === "eraser") {
                    if (before && before !== Sketch.strokes) { const now = Sketch.strokes; Sketch.strokes = before; Sketch.commit(now); }
                    before = null;
                    return;
                }
                if (d.cur) { const s = d.cur; d.cur = null; Sketch.commit(Sketch.strokes.concat([s])); }
            }
            function erase(w) {
                const r = Math.max(d.size, 4 / Sketch.z);
                const keep = Sketch.strokes.filter(s => !d.near(s, w.x, w.y, r));
                if (keep.length !== Sketch.strokes.length) { Sketch.strokes = keep; Sketch.rev++; }
            }
            // a mouse wheel zooms at the pointer; a touchpad's two fingers move around (with Ctrl, they zoom)
            onWheel: wheel => {
                const touch = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
                if (touch && !(wheel.modifiers & Qt.ControlModifier)) d.panBy(wheel.pixelDelta.x, wheel.pixelDelta.y);
                else d.zoomAt(wheel.x, wheel.y, Math.pow(1.0015, touch ? wheel.pixelDelta.y * 2 : wheel.angleDelta.y));
                wheel.accepted = true;
            }
        }
        // a touchpad's pinch zooms too
        PinchHandler {
            target: null
            onScaleChanged: delta => d.zoomAt(centroid.position.x, centroid.position.y, delta)
        }

        // the picture Save makes: all of it, drawn again off-screen at a good size
        Canvas {
            id: exporter
            property string file: ""
            property bool keep: true          // Save: keep the file; Copy: only the clipboard
            property var box: null
            property real k: 1
            visible: file !== ""
            opacity: 0.01
            z: -1
            // (its pictures have to be loaded into this canvas first: it waits for them)
            property bool waiting: false
            onImageLoaded: if (waiting && d.picsLoaded(exporter)) { waiting = false; requestPaint(); }
            Timer { interval: 80; repeat: true; running: exporter.waiting
                onTriggered: if (d.picsLoaded(exporter)) { exporter.waiting = false; exporter.requestPaint(); } }
            onPaint: {
                if (!box) return;
                if (!d.picsLoaded(exporter)) {
                    waiting = true;
                    for (const s of Sketch.strokes) if (s.t === "img" && !isImageLoaded(d.picUrl(s))) loadImage(d.picUrl(s));
                    return;
                }
                const g = getContext("2d");
                g.reset();
                g.fillStyle = Theme.container;
                g.fillRect(0, 0, width, height);
                d.paintAll2(g, box, k, exporter);
            }
            onPainted: {
                if (file === "" || waiting) return;
                const f = file;
                file = "";
                // (Canvas.save() never wrote a file here: the picture goes out as PNG data instead,
                // into a text file that base64 turns into the PNG)
                const url = toDataURL("image/png");
                const comma = url.indexOf(",");
                if (comma < 0) return;
                pngData.path = f + ".b64";
                pngData.setText(url.slice(comma + 1));
                const after = keep ? "wl-copy -t image/png < \"$1\"; notify-send -a Monolith 'Drawing saved' \"$1\""
                                   : "wl-copy -t image/png < \"$1\"; rm -f \"$1\"; notify-send -a Monolith 'Drawing copied'";
                Quickshell.execDetached(["sh", "-c", "base64 -d < \"$1.b64\" > \"$1\" && rm -f \"$1.b64\" && { " + after + "; }", "_", f]);
            }
            FileView { id: pngData; blockWrites: true; printErrors: false }
        }
    }
    // (the background is already filled; the strokes only)
    function paintAll2(g, b, k, cvs) {
        g.setTransform(k, 0, 0, k, -b.x * k + 24, -b.y * k + 24);
        for (const s of Sketch.strokes) drawOne(g, s, cvs);
    }
    function picsLoaded(cvs) { return Sketch.strokes.every(s => s.t !== "img" || cvs.isImageLoaded(picUrl(s))); }
    function savePicture(keep) {
        const b = bounds();
        if (!b) return;
        exporter.keep = keep !== false;
        // twice the size it's drawn at, up to 4096 px on its long side
        const k = Math.min(2, 4000 / Math.max(b.w, b.h));
        exporter.box = b; exporter.k = k;
        exporter.width = Math.ceil(b.w * k) + 48; exporter.height = Math.ceil(b.h * k) + 48;
        exporter.file = exporter.keep ? Quickshell.env("HOME") + "/Pictures/Drawing_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".png"
                                      : (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-drawing-" + Date.now() + ".png";
        exporter.waiting = false;
        exporter.requestPaint();
    }

    // ── tools ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: [["pen", "stylus", "Pen"], ["hl", "ink_highlighter", "Highlighter"], ["line", "horizontal_rule", "Line"], ["arrow", "arrow_right_alt", "Arrow"],
                    ["rect", "crop_square", "Rectangle"], ["ellipse", "circle", "Ellipse"], ["eraser", "ink_eraser", "Eraser"], ["hand", "pan_tool", "Move around"], ["move", "open_with", "Move pictures"], ["pic", "add_photo_alternate", "Add a picture (or paste one, or drop it here)"]]
            Tb {
                required property var modelData
                icon: modelData[1]
                on: d.tool === modelData[0]
                onClicked: { if (modelData[0] === "pic") d.choosePicture(); else d.tool = modelData[0]; }
            }
        }
        Item { Layout.fillWidth: true }
        Tb { icon: "undo"; enabled: Sketch.canUndo; onClicked: Sketch.undo() }
        Tb { icon: "redo"; enabled: Sketch.canRedo; onClicked: Sketch.redo() }
    }
    // ── the pictures you saved (newest first): click to copy, or open ──
    FolderListModel {
        id: saved
        folder: "file://" + Quickshell.env("HOME") + "/Pictures"
        nameFilters: ["Drawing_*.png"]
        showDirs: false
        sortField: FolderListModel.Time
    }
    ListView {
        visible: d.showSaved
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        model: saved
        delegate: Rectangle {
            id: th
            required property string filePath
            required property url fileUrl
            required property string fileName
            width: 120; height: 92
            radius: Theme.corner(80, 4)
            color: Theme.container
            border.width: tm.containsMouse ? 2 : 0; border.color: Theme.accent
            Image { anchors.fill: parent; anchors.margins: 4; source: th.fileUrl; fillMode: Image.PreserveAspectFit; sourceSize.width: 240; asynchronous: true; cache: false }
            // click: copy it; drag it up onto the pad: put it in the drawing
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": String(th.fileUrl) })
            Drag.imageSource: th.fileUrl
            Drag.active: tm.drag.active
            MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                drag.target: dragDummy
                onClicked: Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\" && notify-send -a Monolith 'Drawing copied' \"$1\"", "_", th.filePath]) }
            Item { id: dragDummy }
            Pressable {
                visible: tm.containsMouse || hovered
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
                width: 24; height: 24
                color: Qt.alpha(Theme.frame, 0.85)
                onClicked: Qt.openUrlExternally(th.fileUrl)
                Icon { anchors.centerIn: parent; name: "open_in_new"; size: 14 }
            }
        }
        Label { anchors.centerIn: parent; visible: saved.count === 0; text: "Pictures you save show up here"; muted: true; font.pixelSize: Theme.sizeSmall }
    }

    // ── colours and size ──
    RowLayout {
        visible: !d.showSaved
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: [Theme.accent, Theme.text, Theme.danger, "#ff8a3d", "#f2c230", "#3a9e3a", "#2fb5a8", "#2f6fdb", "#a855f7", "#ec4899", "#ffffff", "#000000"]
            Rectangle {
                required property var modelData
                readonly property bool on: Qt.colorEqual(d.ink, modelData)
                width: 22; height: 22; radius: 11
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                color: modelData
                border.width: on ? 3 : 1
                border.color: on ? Theme.accent : Theme.ringTrack
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { d.ink = parent.modelData; if (d.tool === "eraser" || d.tool === "hand") d.tool = "pen"; } }
            }
        }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Slider {
            Layout.fillWidth: true
            implicitHeight: 34
            icon: "line_weight"
            label: Math.round(d.size) + " px"
            value: (d.size - 1) / 39
            onMoved: v => d.size = Math.round(1 + v * 39)
        }
        // clear: twice to be sure (undo brings it back anyway)
        Pressable {
            id: clearBtn
            property bool armed: false
            // (a layout places by Layout.* sizes: a plain width let "Clear?" slide under the next buttons)
            Layout.preferredWidth: armed ? clr.implicitWidth + 50 : 34
            Layout.preferredHeight: 34
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
            clip: true
            color: armed ? Theme.danger : Theme.control
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: { if (armed) { Sketch.clear(); armed = false; } else { armed = true; disarm.restart(); } }
            Timer { id: disarm; interval: 2500; onTriggered: clearBtn.armed = false }
            Row {
                anchors.centerIn: parent; spacing: 4
                Icon { name: "delete"; size: 18; color: clearBtn.armed ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: clr; visible: clearBtn.armed; text: "Clear?"; font.pixelSize: Theme.sizeSmall; color: Theme.onAccent; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        // copy it (no file kept)
        Pressable {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; color: Theme.control
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: d.savePicture(false)
            Icon { anchors.centerIn: parent; name: "content_copy"; size: 17 }
        }
        Pressable {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; color: Theme.accent; ink: Theme.onAccent
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: d.savePicture(true)
            Icon { anchors.centerIn: parent; name: "save"; size: 18; color: Theme.onAccent }
        }
        // the saved pictures
        Pressable {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34
            color: d.showSaved ? Theme.accentContainer : Theme.control
            onClicked: d.showSaved = !d.showSaved
            Icon { anchors.centerIn: parent; name: "photo_library"; size: 18; color: d.showSaved ? Theme.onAccentContainer : Theme.text }
        }
    }
}
