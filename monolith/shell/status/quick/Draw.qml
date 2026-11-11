import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A drawing pad with no edges: draw anywhere, scroll or pinch to zoom in and out as far as you
// like (2 % to 5000 %), drag with the right or middle button (or the hand, or two fingers on a
// touchpad) to move around. Pen, highlighter, line, arrow, rectangle, ellipse and an eraser that
// takes whole strokes; colours, a size, undo / redo. The drawing stays when the panel closes
// (core/Sketch). Save puts all of it in a picture in ~/Pictures and copies it.
ColumnLayout {
    id: d
    spacing: 8

    property string tool: "pen"         // pen | hl | line | arrow | rect | ellipse | eraser | hand
    property color ink: Theme.accent
    property real size: 4
    readonly property bool shape: ["line", "arrow", "rect", "ellipse"].indexOf(tool) !== -1

    // the stroke being drawn (not in the drawing until you let go)
    property var cur: null
    // only the newest piece of the pen's line needs drawing while it's drawn
    property bool partial: false

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
        // dots that move and scale with the drawing, so you can see where you are
        if (grid) {
            let step = 32;
            while (step * z < 16) step *= 2;
            while (step * z > 64) step /= 2;
            g.fillStyle = Qt.alpha(Theme.text, 0.13);
            const r = Math.max(0.8, Math.min(1.6, z));
            for (let x = Math.floor(ox / step) * step; x < ox + w / z; x += step)
                for (let y = Math.floor(oy / step) * step; y < oy + h / z; y += step)
                    g.fillRect((x - ox) * z - r / 2, (y - oy) * z - r / 2, r, r);
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
            Component.onCompleted: requestPaint()
            onPaint: {
                const g = getContext("2d");
                // the pen: just its newest piece on top of what's there
                if (d.partial && d.cur && d.cur.pts.length >= 4) {
                    const p = d.cur.pts, n = p.length;
                    g.setTransform(Sketch.z, 0, 0, Sketch.z, -Sketch.ox * Sketch.z, -Sketch.oy * Sketch.z);
                    d.styleFor(g, d.cur);
                    g.beginPath(); g.moveTo(p[n - 4], p[n - 3]); g.lineTo(p[n - 2], p[n - 1]); g.stroke();
                    return;
                }
                d.paintAll(g, width, height, Sketch.ox, Sketch.oy, Sketch.z, true);
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
                const w = d.toWorld(mouse.x, mouse.y);
                if (d.tool === "eraser") { before = Sketch.strokes; erase(w); return; }
                d.cur = { t: d.tool, c: String(d.ink), s: d.size, pts: d.shape ? [w.x, w.y, w.x, w.y] : [w.x, w.y] };
                d.partial = false;
                cv.requestPaint();
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                if (panning) { d.panBy(mouse.x - lx, mouse.y - ly); lx = mouse.x; ly = mouse.y; return; }
                const w = d.toWorld(mouse.x, mouse.y);
                if (d.tool === "eraser") { erase(w); return; }
                if (!d.cur) return;
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
                if (save(f)) Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"; notify-send -a Monolith 'Drawing saved' \"$1\"", "_", f]);
            }
        }
    }
    // (the background is already filled; the strokes only)
    function paintAll2(g, b, k) {
        g.setTransform(k, 0, 0, k, -b.x * k + 24, -b.y * k + 24);
        for (const s of Sketch.strokes) { styleFor(g, s); strokePath(g, s); }
    }
    function savePicture() {
        const b = bounds();
        if (!b) return;
        // twice the size it's drawn at, up to 4096 px on its long side
        const k = Math.min(2, 4000 / Math.max(b.w, b.h));
        exporter.box = b; exporter.k = k;
        exporter.width = Math.ceil(b.w * k) + 48; exporter.height = Math.ceil(b.h * k) + 48;
        exporter.file = Quickshell.env("HOME") + "/Pictures/Drawing_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".png";
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
    // ── colours and size ──
    RowLayout {
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
        Pressable {
            width: 34; height: 34; color: Theme.accent; ink: Theme.onAccent
            enabled: Sketch.strokes.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: d.savePicture()
            Icon { anchors.centerIn: parent; name: "save"; size: 18; color: Theme.onAccent }
        }
    }
}
