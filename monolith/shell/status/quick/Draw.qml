import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../../core"
import "../../ui"

// A drawing pad with no edges: draw anywhere, scroll or pinch to zoom in and out as far as you
// like (2 % to 5000 %), drag with the right or middle button (or the hand, or two fingers on a
// touchpad) to move around. Pen, highlighter, line, arrow, rectangle, ellipse and an eraser that
// takes whole strokes; colours, a size, undo / redo. The drawing stays when the panel closes
// (core/Sketch). Save puts all of it in a picture in ~/Pictures and copies it; Copy only copies
// it. The pictures you saved are under the history button (click one to copy it, or open it).
ColumnLayout {
    id: d
    spacing: 8

    property string tool: "pen"         // pen | hl | line | arrow | rect | ellipse | eraser | hand
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

    // the box round all of it, in drawing coordinates
    function bounds() {
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const s of Sketch.strokes) {
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
    function paintAll(g, w, h, ox, oy, z, grid) {
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
        for (const s of Sketch.strokes) { styleFor(g, s); strokePath(g, s); }
        if (d.cur) { styleFor(g, d.cur); strokePath(g, d.cur); }
    }

    // erasing: the strokes that pass within r of (x, y)
    function near(s, x, y, r) {
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
            width: gl.implicitWidth + 38; height: 32
            color: d.grid !== "off" ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
            onClicked: Store.set("quick.drawGrid", ({ off: "dots", dots: "lines", lines: "off" })[d.grid] || "dots")
            Row { anchors.centerIn: parent; spacing: 4
                Icon { name: d.grid === "off" ? "grid_off" : (d.grid === "dots" ? "blur_on" : "grid_on"); size: 17; color: d.grid !== "off" ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: gl; text: ({ off: "No grid", dots: "Dots", lines: "Grid" })[d.grid] || "Dots"; font.pixelSize: Theme.sizeSmall; color: d.grid !== "off" ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
        }
        Pressable {
            visible: d.grid !== "off"
            width: sl2.implicitWidth + 38; height: 32
            color: d.snap ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
            onClicked: Store.set("quick.drawSnap", !d.snap)
            Row { anchors.centerIn: parent; spacing: 4
                Icon { name: "grid_guides"; size: 17; color: d.snap ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: sl2; text: "Snap"; font.pixelSize: Theme.sizeSmall; color: d.snap ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
        }
        Item { width: 6; height: 1 }
        Tb { icon: "zoom_out"; onClicked: d.zoomAt(pad.width / 2, pad.height / 2, 1 / 1.25) }
        Pressable {
            width: zl.implicitWidth + 16; height: 32
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
                d.paintAll(g, width, height, Sketch.ox, Sketch.oy, Sketch.z, true);
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
        Label {
            visible: Sketch.strokes.length === 0 && !d.cur
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Draw anywhere\nScroll or pinch to zoom · right-drag or two fingers to move"
            muted: true; font.pixelSize: Theme.sizeSmall
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: panning || d.tool === "hand" ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : (d.tool === "eraser" ? Qt.BlankCursor : Qt.CrossCursor)
            property bool panning: false
            property real lx: 0
            property real ly: 0
            property var before: null       // the strokes before an erase, for undo
            onPressed: mouse => {
                lx = mouse.x; ly = mouse.y;
                panning = mouse.button !== Qt.LeftButton || d.tool === "hand";
                if (panning) return;
                const w0 = d.toWorld(mouse.x, mouse.y);
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
            onPaint: {
                if (!box) return;
                const g = getContext("2d");
                g.reset();
                g.fillStyle = Theme.container;
                g.fillRect(0, 0, width, height);
                d.paintAll2(g, box, k);
            }
            onPainted: {
                if (file === "") return;
                const f = file;
                file = "";
                if (!save(f)) return;
                if (keep) Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"; notify-send -a Monolith 'Drawing saved' \"$1\"", "_", f]);
                else Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"; rm -f \"$1\"; notify-send -a Monolith 'Drawing copied'", "_", f]);
            }
        }
    }
    // (the background is already filled; the strokes only)
    function paintAll2(g, b, k) {
        g.setTransform(k, 0, 0, k, -b.x * k + 24, -b.y * k + 24);
        for (const s of Sketch.strokes) { styleFor(g, s); strokePath(g, s); }
    }
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
        exporter.requestPaint();
    }

    // ── tools ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: [["pen", "stylus", "Pen"], ["hl", "ink_highlighter", "Highlighter"], ["line", "horizontal_rule", "Line"], ["arrow", "arrow_right_alt", "Arrow"],
                    ["rect", "crop_square", "Rectangle"], ["ellipse", "circle", "Ellipse"], ["eraser", "ink_eraser", "Eraser"], ["hand", "pan_tool", "Move around"]]
            Tb {
                required property var modelData
                icon: modelData[1]
                on: d.tool === modelData[0]
                onClicked: d.tool = modelData[0]
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
            MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\" && notify-send -a Monolith 'Drawing copied' \"$1\"", "_", th.filePath]) }
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
            width: armed ? clr.implicitWidth + 50 : 34; height: 34
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
            width: 34; height: 34; color: Theme.control
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: d.savePicture(false)
            Icon { anchors.centerIn: parent; name: "content_copy"; size: 17 }
        }
        Pressable {
            width: 34; height: 34; color: Theme.accent; ink: Theme.onAccent
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: d.savePicture(true)
            Icon { anchors.centerIn: parent; name: "save"; size: 18; color: Theme.onAccent }
        }
        // the saved pictures
        Pressable {
            width: 34; height: 34
            color: d.showSaved ? Theme.accentContainer : Theme.control
            onClicked: d.showSaved = !d.showSaved
            Icon { anchors.centerIn: parent; name: "photo_library"; size: 18; color: d.showSaved ? Theme.onAccentContainer : Theme.text }
        }
    }
}
