import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// The screenshot editor (Settings → Screenshots → Editor: Monolith's own): draw on a shot, then
// save, copy or pin it. Tools: pen, highlighter, line, arrow, box, oval, text, numbered steps,
// pixelate (hides what's under it) and crop. Colours and three widths; undo / redo.
// The picture is edited at its own pixel size (`doc`) and shown scaled to fit; saving grabs
// `doc` at that size, then crops it.
FloatingWindow {
    id: win
    title: "Screenshot editor"
    visible: Capture.editFile !== ""
    implicitWidth: 1280
    implicitHeight: 860
    minimumSize: Qt.size(760, 520)
    color: Theme.m("surface", Theme.frame)
    onVisibleChanged: if (!visible) reset()

    readonly property string file: Capture.editFile
    onFileChanged: reset()
    // shapes: { t: pen | hl | line | arrow | rect | ellipse | text | step | blur, c, s, pts / x y w h / text / n }
    property var shapes: []
    property var past: []
    property var future: []
    property var crop: null                // { x, y, w, h } in the picture's pixels, or null
    property string tool: "arrow"
    property color colour: palette[0]
    property int size: 1                   // 0 thin, 1 medium, 2 thick
    readonly property var palette: ["#ff4d4f", "#ffb020", "#3ddc84", "#3b82f6", "#a855f7", "#ffffff", "#111111"]
    readonly property real lineW: [3, 6, 12][size] * Math.max(1, img.sourceSize.width / 1920)
    property var drawing: null             // the shape being drawn
    property bool busy: false
    function reset() { shapes = []; past = []; future = []; crop = null; drawing = null; editing = -1; }
    function commit(next) { past = past.concat([{ s: shapes, c: crop }]).slice(-100); future = []; shapes = next; }
    function undo() { if (!past.length) return; future = future.concat([{ s: shapes, c: crop }]); const p = past[past.length - 1]; past = past.slice(0, -1); shapes = p.s; crop = p.c; }
    function redo() { if (!future.length) return; past = past.concat([{ s: shapes, c: crop }]); const f = future[future.length - 1]; future = future.slice(0, -1); shapes = f.s; crop = f.c; }
    readonly property int nextStep: shapes.filter(s => s.t === "step").length + 1
    // the text being typed (an index in shapes), -1 when none
    property int editing: -1

    // flatten: grab the picture with its drawing at full size, crop, then do `what` with it
    function flatten(what) {
        if (busy || img.status !== Image.Ready) return;
        keysRoot.forceActiveFocus();       // a text being typed is kept first
        busy = true;
        const tmp = Capture.runDir + "/edit-" + Date.now() + ".png";
        doc.grabToImage(r => {
            if (!r.saveToFile(tmp)) { busy = false; return; }
            const c = crop;
            const script = c ? "magick \"$1\" -crop " + Math.round(c.w) + "x" + Math.round(c.h) + "+" + Math.round(c.x) + "+" + Math.round(c.y) + " +repage \"$1\"" : "true";
            Capture.run(script, [tmp], code => {
                busy = false;
                if (code !== 0) return;
                if (what === "save") { Capture.saveEdited(tmp, Capture.editOut, null); Capture.editFile = ""; }
                else if (what === "copy") { Capture.copyFile(tmp); Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", tmp, "Copied", "The edited screenshot is on the clipboard"]); }
                else if (what === "pin") { Capture.pin(tmp, Niri.focusedOutput, null); Capture.editFile = ""; }
            });
        }, Qt.size(doc.width, doc.height));
    }

    Item {
        id: keysRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (win.editing !== -1) return;
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) { if (win.tool === "crop" && win.crop) { win.commit(win.shapes); win.crop = null; } else Capture.editFile = ""; }
            else if (ctrl && event.key === Qt.Key_Z) { if (event.modifiers & Qt.ShiftModifier) win.redo(); else win.undo(); }
            else if (ctrl && event.key === Qt.Key_Y) win.redo();
            else if (ctrl && event.key === Qt.Key_C) win.flatten("copy");
            else if (ctrl && event.key === Qt.Key_S) win.flatten("save");
            else if (!ctrl) {
                const keys = { p: "pen", h: "hl", l: "line", a: "arrow", r: "rect", o: "ellipse", t: "text", n: "step", b: "blur", c: "crop" };
                const k = event.text.toLowerCase();
                if (keys[k]) win.tool = keys[k]; else return;
            } else return;
            event.accepted = true;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── the toolbar ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: tools.implicitHeight + 16
                radius: Theme.corner(56, 6)
                color: Theme.container
                border.width: Theme.outlineW; border.color: Theme.outlineColor
                Flow {
                    id: tools
                    x: 8; y: 8
                    width: parent.width - 16
                    spacing: 4
                    component ToolB: Pressable {
                        property string icon: ""
                        property string id_: ""
                        property string tip: ""
                        readonly property bool on: win.tool === id_
                        width: 40; height: 40
                        color: on ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
                        onClicked: win.tool = id_
                        Icon { anchors.centerIn: parent; name: parent.icon; size: 20; filled: parent.on; color: parent.on ? Theme.onAccent : Theme.text }
                    }
                    ToolB { icon: "draw"; id_: "pen" }
                    ToolB { icon: "ink_highlighter"; id_: "hl" }
                    ToolB { icon: "horizontal_rule"; id_: "line" }
                    ToolB { icon: "arrow_outward"; id_: "arrow" }
                    ToolB { icon: "crop_square"; id_: "rect" }
                    ToolB { icon: "circle"; id_: "ellipse" }
                    ToolB { icon: "title"; id_: "text" }
                    ToolB { icon: "counter_1"; id_: "step" }
                    ToolB { icon: "blur_on"; id_: "blur" }
                    ToolB { icon: "crop"; id_: "crop" }
                    component Sep: Item { width: 9; height: 40; Rectangle { anchors.centerIn: parent; width: 1; height: 28; color: Theme.ringTrack } }
                    Sep {}
                    Repeater {
                        model: win.palette
                        Pressable {
                            required property string modelData
                            width: 28; height: 28; y: 6
                            radius: 14
                            color: modelData
                            border.width: Qt.colorEqual(win.colour, modelData) ? 3 : 1
                            border.color: Qt.colorEqual(win.colour, modelData) ? Theme.accent : Qt.alpha(Theme.text, 0.3)
                            onClicked: win.colour = modelData
                        }
                    }
                    Sep {}
                    Repeater {
                        model: 3
                        Pressable {
                            required property int index
                            width: 36; height: 40
                            color: win.size === index ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                            onClicked: win.size = index
                            Rectangle { anchors.centerIn: parent; width: [5, 9, 15][parent.index]; height: width; radius: width / 2; color: Theme.text }
                        }
                    }
                }
            }

            // ── the picture ──
            Rectangle {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.corner(80, 6)
                color: Theme.container
                clip: true
                readonly property real k: img.sourceSize.width > 0 ? Math.min(1, (width - 32) / img.sourceSize.width, (height - 32) / img.sourceSize.height) : 1

                Item {
                    id: view
                    width: doc.width * stage.k
                    height: doc.height * stage.k
                    anchors.centerIn: parent

                    // the picture and its drawing at full size (what's saved)
                    Item {
                        id: doc
                        width: img.sourceSize.width
                        height: img.sourceSize.height
                        scale: stage.k
                        transformOrigin: Item.TopLeft
                        Image { id: img; source: win.file !== "" ? Wall.url(win.file) : ""; cache: false; smooth: true }
                        // pixelated areas: the picture under them at a tiny size, blown up blocky
                        Repeater {
                            model: win.shapes.map((s, i) => [s, i]).filter(x => x[0].t === "blur").concat(win.drawing && win.drawing.t === "blur" ? [[win.drawing, -2]] : [])
                            ShaderEffectSource {
                                required property var modelData
                                readonly property var r: win.norm(modelData[0])
                                x: r.x; y: r.y; width: Math.max(1, r.w); height: Math.max(1, r.h)
                                sourceItem: img
                                sourceRect: Qt.rect(r.x, r.y, Math.max(1, r.w), Math.max(1, r.h))
                                textureSize: Qt.size(Math.max(1, r.w / 14), Math.max(1, r.h / 14))
                                smooth: false
                                live: true
                            }
                        }
                        Canvas {
                            id: ink
                            anchors.fill: parent
                            renderStrategy: Canvas.Cooperative
                            onPaint: {
                                const g = getContext("2d");
                                g.reset();
                                for (const s of win.shapes) win.paintShape(g, s);
                                if (win.drawing) win.paintShape(g, win.drawing);
                            }
                            Connections { target: win; function onShapesChanged() { ink.requestPaint(); } function onDrawingChanged() { ink.requestPaint(); } }
                        }
                        // text and numbered steps
                        Repeater {
                            model: win.shapes.map((s, i) => [s, i]).filter(x => x[0].t === "text" || x[0].t === "step")
                            Item {
                                required property var modelData
                                readonly property var sh: modelData[0]
                                readonly property int at: modelData[1]
                                x: sh.x; y: sh.y
                                Rectangle {
                                    visible: parent.sh.t === "step"
                                    width: parent.sh.s * 5; height: width; radius: width / 2
                                    x: -width / 2; y: -height / 2
                                    color: parent.sh.c
                                    border.width: Math.max(2, width / 14); border.color: "white"
                                    Text { anchors.centerIn: parent; text: parent.parent.sh.n || ""; color: Qt.colorEqual(parent.parent.sh.c, "#ffffff") ? "#111111" : "white"; font.pixelSize: parent.width * 0.5; font.bold: true }
                                }
                                TextInput {
                                    id: ti
                                    visible: parent.sh.t === "text"
                                    text: parent.sh.text || ""
                                    color: parent.sh.c
                                    font.pixelSize: parent.sh.s * 4
                                    font.bold: true
                                    readOnly: win.editing !== parent.at
                                    cursorVisible: !readOnly
                                    // the edit is done: kept (or dropped when empty)
                                    function done() {
                                        if (win.editing !== parent.at) return;
                                        const i = parent.at, t = text;
                                        win.editing = -1;
                                        const l = win.shapes.slice();
                                        if (t.trim() === "") l.splice(i, 1); else l[i] = Object.assign({}, l[i], { text: t });
                                        win.shapes = l;
                                    }
                                    Keys.onReturnPressed: keysRoot.forceActiveFocus()
                                    Keys.onEscapePressed: keysRoot.forceActiveFocus()
                                    onActiveFocusChanged: if (!activeFocus) done()
                                    Component.onCompleted: if (win.editing === parent.at) forceActiveFocus()
                                }
                            }
                        }
                    }

                    // the crop: everything outside it darkened (not part of the saved picture)
                    Item {
                        visible: !!win.crop || (win.drawing && win.drawing.t === "crop")
                        anchors.fill: parent
                        readonly property var c: win.drawing && win.drawing.t === "crop" ? win.norm(win.drawing) : (win.crop || { x: 0, y: 0, w: 0, h: 0 })
                        readonly property real k: stage.k
                        readonly property color dim: Qt.rgba(0, 0, 0, 0.55)
                        Rectangle { x: 0; y: 0; width: parent.width; height: parent.c.y * parent.k; color: parent.dim }
                        Rectangle { x: 0; y: (parent.c.y + parent.c.h) * parent.k; width: parent.width; height: parent.height - y; color: parent.dim }
                        Rectangle { x: 0; y: parent.c.y * parent.k; width: parent.c.x * parent.k; height: parent.c.h * parent.k; color: parent.dim }
                        Rectangle { x: (parent.c.x + parent.c.w) * parent.k; y: parent.c.y * parent.k; width: parent.width - x; height: parent.c.h * parent.k; color: parent.dim }
                        Rectangle { x: parent.c.x * parent.k; y: parent.c.y * parent.k; width: parent.c.w * parent.k; height: parent.c.h * parent.k; color: "transparent"; border.width: 2; border.color: Theme.accent }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: win.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                        function pt(m) { return [Math.max(0, Math.min(doc.width, m.x / stage.k)), Math.max(0, Math.min(doc.height, m.y / stage.k))]; }
                        onPressed: mouse => {
                            // typing a text: a click elsewhere finishes it
                            if (win.editing !== -1) { keysRoot.forceActiveFocus(); return; }
                            const p = pt(mouse);
                            const t = win.tool;
                            if (t === "text") {
                                const l = win.shapes.concat([{ t: "text", c: String(win.colour), s: [7, 10, 15][win.size] * Math.max(1, img.sourceSize.width / 1920), x: p[0], y: p[1] - 20, text: "" }]);
                                win.editing = l.length - 1;
                                win.commit(l);
                                return;
                            }
                            if (t === "step") {
                                win.commit(win.shapes.concat([{ t: "step", c: String(win.colour), s: [7, 10, 15][win.size] * Math.max(1, img.sourceSize.width / 1920), x: p[0], y: p[1], n: win.nextStep }]));
                                return;
                            }
                            win.drawing = { t: t, c: String(win.colour), s: t === "hl" ? win.lineW * 3 : win.lineW, pts: p.concat(p) };
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || !win.drawing) return;
                            const p = pt(mouse);
                            const d = Object.assign({}, win.drawing);
                            if (d.t === "pen" || d.t === "hl") d.pts = d.pts.concat(p);
                            else d.pts = [d.pts[0], d.pts[1], p[0], p[1]];
                            win.drawing = d;
                        }
                        onReleased: {
                            const d = win.drawing;
                            win.drawing = null;
                            if (!d) return;
                            const r = win.norm(d);
                            if (d.t !== "pen" && d.t !== "hl" && r.w < 3 && r.h < 3) return;
                            if (d.t === "crop") { win.commit(win.shapes); win.crop = r; return; }
                            win.commit(win.shapes.concat([d]));
                        }
                    }
                }
            }
            // ── undo / redo, the size and keys, and what to do with it ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                component IconB: Pressable {
                    property string icon: ""
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    color: hovered ? Theme.containerHigh : "transparent"
                    Icon { anchors.centerIn: parent; name: parent.icon; size: 20 }
                }
                IconB { icon: "undo"; opacity: win.past.length ? 1 : 0.4; onClicked: win.undo() }
                IconB { icon: "redo"; opacity: win.future.length ? 1 : 0.4; onClicked: win.redo() }
                Label {
                    Layout.fillWidth: true; Layout.leftMargin: 8
                    elide: Text.ElideRight; muted: true; font.pixelSize: Theme.sizeTiny
                    text: (img.sourceSize.width > 0 ? (win.crop ? Math.round(win.crop.w) + " × " + Math.round(win.crop.h) + " (cropped)" : img.sourceSize.width + " × " + img.sourceSize.height) + "   ·   " : "") +
                          "P pen · H highlight · L line · A arrow · R box · O oval · T text · N steps · B pixelate · C crop · Ctrl+Z undo · Ctrl+S save · Ctrl+C copy · Esc close"
                }
                Button { text: "Pin"; icon: "push_pin"; onClicked: win.flatten("pin") }
                Button { text: "Copy"; icon: "content_copy"; onClicked: win.flatten("copy") }
                Button { text: win.busy ? "Saving…" : "Save"; icon: "save"; primary: true; onClicked: win.flatten("save") }
                IconB { icon: "close"; onClicked: Capture.editFile = "" }
            }
        }
    }

    // a two-point shape's box, from its points (either way round)
    function norm(s) {
        const p = s.pts || [0, 0, 0, 0];
        return { x: Math.min(p[0], p[2]), y: Math.min(p[1], p[3]), w: Math.abs(p[2] - p[0]), h: Math.abs(p[3] - p[1]) };
    }
    function paintShape(g, s) {
        if (s.t === "blur" || s.t === "text" || s.t === "step" || s.t === "crop") return;
        const p = s.pts;
        g.lineCap = "round"; g.lineJoin = "round";
        g.lineWidth = s.s;
        g.strokeStyle = s.c;
        g.globalAlpha = s.t === "hl" ? 0.38 : 1;
        g.beginPath();
        if (s.t === "pen" || s.t === "hl") {
            g.moveTo(p[0], p[1]);
            for (let i = 2; i < p.length; i += 2) g.lineTo(p[i], p[i + 1]);
            g.stroke();
        } else if (s.t === "line" || s.t === "arrow") {
            g.moveTo(p[0], p[1]); g.lineTo(p[2], p[3]); g.stroke();
            if (s.t === "arrow") {
                const a = Math.atan2(p[3] - p[1], p[2] - p[0]), L = s.s * 4;
                g.beginPath();
                g.moveTo(p[2], p[3]);
                g.lineTo(p[2] - L * Math.cos(a - 0.45), p[3] - L * Math.sin(a - 0.45));
                g.lineTo(p[2] - L * Math.cos(a + 0.45), p[3] - L * Math.sin(a + 0.45));
                g.closePath();
                g.fillStyle = s.c;
                g.fill();
            }
        } else if (s.t === "rect") {
            const r = norm(s);
            g.strokeRect(r.x, r.y, r.w, r.h);
        } else if (s.t === "ellipse") {
            const r = norm(s);
            g.ellipse(r.x, r.y, r.w, r.h);
            g.stroke();
        }
        g.globalAlpha = 1;
    }
}
