import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The widget editor: a full-screen area on one screen where you arrange the desktop's or the
// lock screen's widgets. Drag a widget to move it, its corner to resize it; the bar above it
// has its look (a drop-down) and its settings (⚙); add widgets from the bar at the bottom.
PanelWindow {
    id: ed
    required property var modelData
    screen: modelData
    readonly property string mode: HubState.editWidgets
    readonly property bool shown: mode !== "" && (HubState.editScreen === "" ? modelData === Quickshell.screens[0] : HubState.editScreen === modelData.name)
    readonly property bool lockMode: mode === "lock"
    readonly property var list: shown ? WidgetLayout.on(mode, modelData.name) : []
    property string selected: ""
    property bool adding: false
    readonly property bool snap: Store.get("widgets.snap", true) !== false
    readonly property real grid: 20

    visible: shown || contentItem.opacity > 0.01
    WlrLayershell.namespace: "monolith-widget-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    // the whole editor fades in with a little zoom, and out when it closes (the window is clear
    // underneath, so what's behind shows through the fade)
    color: "transparent"
    Component.onCompleted: { if (shown) edIn.restart(); else contentItem.opacity = 0; }
    ParallelAnimation {
        id: edIn
        NumberAnimation { target: ed.contentItem; property: "opacity"; from: 0; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: ed.contentItem; property: "scale"; from: 1 + (1 - Theme.popScale) / 2; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
    }
    ParallelAnimation {
        id: edOut
        NumberAnimation { target: ed.contentItem; property: "opacity"; to: 0; duration: Theme.popOutMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: ed.contentItem; property: "scale"; to: 1 + (1 - Theme.popScale) / 2; duration: Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
    }
    // opened from a widget's right-click menu: that one starts selected
    onShownChanged: {
        selected = shown ? HubState.editSelect : ""; adding = false; presetsOpen = false;
        HubState.editSelect = "";
        if (shown) keys.forceActiveFocus();
        if (shown) edIn.restart(); else edOut.restart();
    }

    function done() { HubState.editWidgets = ""; }
    function snapTo(v) { return snap ? Math.round(v / grid) * grid : v; }

    // ── what it looks like underneath: the wallpaper (blurred for the lock screen) ──
    Image {
        id: wp
        anchors.fill: parent
        source: Wall.url(Wall.pathFor(ed.modelData.name))
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(ed.width / (ed.lockMode ? 2 : 1), ed.height / (ed.lockMode ? 2 : 1))
        visible: !ed.lockMode
    }
    MultiEffect { anchors.fill: parent; source: wp; visible: ed.lockMode; blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.08 }
    Rectangle { anchors.fill: parent; visible: ed.lockMode; color: Qt.alpha(Theme.frame, 0.35) }
    // the grid
    Canvas {
        anchors.fill: parent
        visible: ed.snap
        opacity: 0.18
        onPaint: {
            const g = getContext("2d"); g.reset(); g.strokeStyle = "#ffffff"; g.lineWidth = 1;
            for (let x = 0; x < width; x += ed.grid * 2) { g.beginPath(); g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, height); g.stroke(); }
            for (let y = 0; y < height; y += ed.grid * 2) { g.beginPath(); g.moveTo(0, y + 0.5); g.lineTo(width, y + 0.5); g.stroke(); }
        }
    }
    // the lock screen's fixed parts, as guides: the password pill and the top island
    Rectangle {
        visible: ed.lockMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08 + 58
        width: 420; height: 64; radius: 32
        color: Qt.alpha(Theme.frame, 0.6)
        border.width: 2; border.color: Qt.alpha(Theme.text, 0.25)
        Label { anchors.centerIn: parent; text: "Password (stays here)"; muted: true }
    }
    // a click on nothing: no selection
    MouseArea { anchors.fill: parent; onClicked: { ed.selected = ""; ed.adding = false; } }

    // ── magnetic alignment (as the old editor had it): while a widget moves, its left edge, middle
    // or right edge (and top, middle, bottom) catches on a line within a few pixels and stays
    // there: the screen's edges, thirds and middle, and every other widget's edges and middle.
    // A thin line shows what it's lined up with. Hold Ctrl to move freely. With Grid on, a widget
    // that isn't lined up with anything snaps to the grid. ──
    readonly property real catchPx: 12
    property var guides: []                       // [{ x, y, w, h }] lines to draw
    function otherBoxes(self) {
        const out = [];
        for (let i = 0; i < widgetsRep.count; i++) {
            const it = widgetsRep.itemAt(i);
            if (!it || it === self) continue;
            out.push({ l: it.x, t: it.y, r: it.x + it.width, b: it.y + it.height });
        }
        return out;
    }
    // the lines along one axis (h: the x axis)
    function linesFor(h, others) {
        const ext = h ? width : height;
        const l = [0, ext / 3, ext / 2, ext * 2 / 3, ext];
        for (const o of others) { const lo = h ? o.l : o.t, hi = h ? o.r : o.b; l.push(lo, (lo + hi) / 2, hi); }
        return l;
    }
    // the best place for a span starting at `raw` and `size` long: { pos, line } (line -1: none)
    function catchAxis(raw, size, lines) {
        let best = { pos: raw, line: -1, diff: catchPx };
        for (const ln of lines) for (const k of [0, size / 2, size]) {
            const d = Math.abs(ln - k - raw);
            if (d < best.diff) best = { pos: ln - k, line: ln, diff: d };
        }
        return best;
    }
    // the guide for a line: along the widgets lined up on it, else across the screen
    function guideFor(h, line, box, others) {
        const on = b => { const lo = h ? b.l : b.t, hi = h ? b.r : b.b; return Math.abs(lo - line) < 0.5 || Math.abs((lo + hi) / 2 - line) < 0.5 || Math.abs(hi - line) < 0.5; };
        let from = h ? box.t : box.l, to = h ? box.b : box.r, linked = false;
        for (const o of others) if (on(o)) { from = Math.min(from, h ? o.t : o.l); to = Math.max(to, h ? o.b : o.r); linked = true; }
        if (!linked) { from = 0; to = h ? height : width; }
        return h ? { x: line - 0.5, y: from, w: 1, h: to - from } : { x: from, y: line - 0.5, w: to - from, h: 1 };
    }
    // equal spacing along one axis (h: x): the widget sits as far from a neighbour as two other
    // widgets are from each other, as far from a screen edge as another widget is from its edge,
    // or halfway between its two neighbours. Returns { pos, diff, refs } (refs: the gaps to label).
    function spaceAxis(h, raw, size, crossLo, crossHi, others, best) {
        const ext = h ? width : height;
        const lo = o => h ? o.l : o.t, hi = o => h ? o.r : o.b;
        const clo = o => h ? o.t : o.l, chi = o => h ? o.b : o.r;
        const crosses = (a, b0, b1) => clo(a) < b1 && chi(a) > b0;
        // the gap between two boxes (a before b) as a segment to label, along the shared stretch
        const seg = (from, to, c0, c1) => ({ h: h, from: from, to: to, cross: (Math.max(c0, 0) + Math.min(c1, h ? height : width)) / 2 });
        const row = others.filter(o => crosses(o, crossLo, crossHi));
        // the gaps already there between widgets that share a row (or column)
        const gaps = [];
        for (const a of others) for (const b of others) {
            if (a === b || !crosses(b, clo(a), chi(a)) || lo(b) < hi(a)) continue;
            const between = others.some(c => c !== a && c !== b && lo(c) >= hi(a) && hi(c) <= lo(b) && crosses(c, clo(a), chi(a)));
            if (!between && lo(b) - hi(a) >= 4) gaps.push({ v: lo(b) - hi(a), s: seg(hi(a), lo(b), Math.max(clo(a), clo(b)), Math.min(chi(a), chi(b))) });
        }
        const offer = (pos, refs) => { const d = Math.abs(pos - raw); if (d < best.diff) best = { pos: pos, diff: d, refs: refs, line: -1 }; };
        for (const o of row) for (const gp of gaps) {
            offer(hi(o) + gp.v, [gp.s, seg(hi(o), hi(o) + gp.v, Math.max(clo(o), crossLo), Math.min(chi(o), crossHi))]);
            offer(lo(o) - gp.v - size, [gp.s, seg(lo(o) - gp.v, lo(o), Math.max(clo(o), crossLo), Math.min(chi(o), crossHi))]);
        }
        // the same margin from a screen edge as another widget
        for (const o of others) {
            const m0 = lo(o), m1 = ext - hi(o);
            if (m0 >= 4) offer(m0, [seg(0, m0, clo(o), chi(o)), seg(0, m0, crossLo, crossHi)]);
            if (m1 >= 4) offer(ext - m1 - size, [seg(hi(o), ext, clo(o), chi(o)), seg(ext - m1, ext, crossLo, crossHi)]);
        }
        // halfway between the nearest neighbours on each side
        const before = row.filter(o => hi(o) <= raw + size / 2).sort((a, b) => hi(b) - hi(a))[0];
        const after = row.filter(o => lo(o) >= raw + size / 2).sort((a, b) => lo(a) - lo(b))[0];
        if (before && after && lo(after) - hi(before) > size) {
            const pos = (hi(before) + lo(after) - size) / 2;
            offer(pos, [seg(hi(before), pos, crossLo, crossHi), seg(pos + size, lo(after), crossLo, crossHi)]);
        }
        return best;
    }
    property var measures: []                     // [{ h, from, to, cross }] equal gaps, labelled
    // where a moved widget lands (and the guides for it)
    function place(self, rx, ry, free) {
        const w = self.width, h = self.height;
        let x = rx, y = ry;
        const g = [], ms = [];
        if (!free) {
            const others = otherBoxes(self);
            let sx = catchAxis(rx, w, linesFor(true, others));
            sx = spaceAxis(true, rx, w, ry, ry + h, others, { pos: sx.pos, diff: sx.diff, line: sx.line, refs: [] });
            x = sx.diff < catchPx ? sx.pos : snapTo(rx);
            let sy = catchAxis(ry, h, linesFor(false, others));
            sy = spaceAxis(false, ry, h, x, x + w, others, { pos: sy.pos, diff: sy.diff, line: sy.line, refs: [] });
            y = sy.diff < catchPx ? sy.pos : snapTo(ry);
            const box = { l: x, t: y, r: x + w, b: y + h };
            if (sx.line >= 0) g.push(guideFor(true, sx.line, box, others));
            if (sy.line >= 0) g.push(guideFor(false, sy.line, box, others));
            for (const r of (sx.refs || []).concat(sy.refs || [])) ms.push(r);
        }
        guides = g;
        measures = ms;
        return Qt.point(Math.max(0, Math.min(width - w, x)), Math.max(0, Math.min(height - h, y)));
    }
    // a resized widget's right and bottom edges catch the same lines
    function edgeCatch(h, edge, self) {
        const others = otherBoxes(self);
        let best = { line: -1, diff: catchPx };
        for (const ln of linesFor(h, others)) { const d = Math.abs(ln - edge); if (d < best.diff) best = { line: ln, diff: d }; }
        return best.line;
    }
    Item {
        z: 85
        anchors.fill: parent
        Repeater {
            model: ed.guides
            Rectangle { required property var modelData; x: modelData.x; y: modelData.y; width: Math.max(1, modelData.w); height: Math.max(1, modelData.h); color: Theme.accent }
        }
        // equal gaps: a line with end caps and the distance
        Repeater {
            model: ed.measures
            Item {
                id: ms
                required property var modelData
                readonly property real len: modelData.to - modelData.from
                x: modelData.h ? modelData.from : modelData.cross
                y: modelData.h ? modelData.cross : modelData.from
                Rectangle { x: ms.modelData.h ? 0 : -0.5; y: ms.modelData.h ? -0.5 : 0; width: ms.modelData.h ? ms.len : 1; height: ms.modelData.h ? 1 : ms.len; color: Theme.accent }
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        width: ms.modelData.h ? 1 : 7; height: ms.modelData.h ? 7 : 1
                        x: ms.modelData.h ? index * ms.len - 0.5 : -3.5
                        y: ms.modelData.h ? -3.5 : index * ms.len - 0.5
                        color: Theme.accent
                    }
                }
                Rectangle {
                    width: ml.implicitWidth + 12; height: 20; radius: 10
                    color: Theme.accent
                    x: ms.modelData.h ? (ms.len - width) / 2 : 6
                    y: ms.modelData.h ? -height - 6 : (ms.len - height) / 2
                    Text { id: ml; anchors.centerIn: parent; text: Math.round(ms.len); color: Theme.onAccent; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                }
            }
        }
    }

    // ── the widgets ──
    property bool optsOpen: false
    onSelectedChanged: optsOpen = false
    function setOption(id, k, v) {
        if (k.startsWith("store:")) Store.set(k.slice(6), v);
        else WidgetLayout.setOpt(mode, id, k, v);
    }
    // what a colour choice looks like (the empty one, "the theme's", as the card colour)
    function swatch(v) {
        const m = { "": Theme.containerHigh, text: Theme.text, accent: Theme.accent, white: "#ffffff", black: "#000000",
            primary: Theme.m("primary", Theme.accent), secondary: Theme.m("secondary", Theme.subtext), tertiary: Theme.m("tertiary", Theme.accent) };
        return m[v] !== undefined ? m[v] : (String(v).startsWith("#") ? v : Theme.containerHigh);
    }
    function optionValue(item, o) { return o[0].startsWith("store:") ? Store.get(o[0].slice(6), o[3]) : WidgetLayout.opt(item, o[0], o[3]); }
    Repeater {
        id: widgetsRep
        model: ed.list
        Item {
            id: wrap
            required property var modelData
            readonly property bool sel: ed.selected === modelData.id
            readonly property var sz: WidgetLayout.size(modelData)
            property real ww: sz[0]
            property real hh: sz[1]
            onSzChanged: { ww = sz[0]; hh = sz[1]; }
            width: ww
            height: hh
            x: Math.max(0, Math.min(modelData.x * ed.width, ed.width - width))
            y: Math.max(0, Math.min(modelData.y * ed.height, ed.height - height))
            z: sel ? 10 : 1
            WidgetFace {
                id: face
                anchors.fill: parent
                item: wrap.modelData
                editing: true
                backdrop: ed.lockMode ? null : wp
                origin: Qt.point(wrap.x, wrap.y)
            }
            // the frame: a soft outline, solid accent when selected
            Rectangle {
                anchors.fill: parent; anchors.margins: -6
                radius: 10
                color: wrap.sel ? Qt.alpha(Theme.accent, 0.08) : "transparent"
                border.width: 2
                border.color: wrap.sel ? Theme.accent : Qt.alpha("#ffffff", 0.35)
            }
            // move: drag anywhere on it
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property point from
                onPressed: mouse => { ed.selected = wrap.modelData.id; ed.adding = false; start = mapToItem(ed.contentItem, mouse.x, mouse.y); from = Qt.point(wrap.x, wrap.y); ed.moving = wrap; }
                onCanceled: { ed.moving = null; ed.guides = []; ed.measures = []; }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                    const at = ed.place(wrap, from.x + p.x - start.x, from.y + p.y - start.y, (mouse.modifiers & Qt.ControlModifier) !== 0);
                    wrap.x = at.x; wrap.y = at.y;
                }
                onReleased: { ed.moving = null; ed.guides = []; ed.measures = []; WidgetLayout.update(ed.mode, wrap.modelData.id, { x: wrap.x / ed.width, y: wrap.y / ed.height }); }
            }
            // resize: the corner handle, freely (inside the widget's limits and its look's shape)
            Rectangle {
                visible: wrap.sel
                x: parent.width - 8; y: parent.height - 8
                width: 22; height: 22; radius: 11
                color: Theme.accent
                border.width: 3; border.color: Theme.onAccent
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.SizeFDiagCursor
                    property point start
                    property real w0
                    property real h0
                    onPressed: mouse => { start = mapToItem(ed.contentItem, mouse.x, mouse.y); w0 = wrap.ww; h0 = wrap.hh; }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                        let w = w0 + p.x - start.x, h = h0 + p.y - start.y;
                        const g = [];
                        if (!(mouse.modifiers & Qt.ControlModifier)) {
                            // the right and bottom edges catch on lines, else the grid
                            const lx = ed.edgeCatch(true, wrap.x + w, wrap), ly = ed.edgeCatch(false, wrap.y + h, wrap);
                            w = lx >= 0 ? lx - wrap.x : ed.snapTo(w);
                            h = ly >= 0 ? ly - wrap.y : ed.snapTo(h);
                            const c0 = WidgetLayout.clamp(wrap.modelData.type, wrap.modelData.face, w, h);
                            const others = ed.otherBoxes(wrap);
                            const box = { l: wrap.x, t: wrap.y, r: wrap.x + c0[0], b: wrap.y + c0[1] };
                            if (lx >= 0 && Math.abs(c0[0] - w) < 0.5) g.push(ed.guideFor(true, lx, box, others));
                            if (ly >= 0 && Math.abs(c0[1] - h) < 0.5) g.push(ed.guideFor(false, ly, box, others));
                        }
                        ed.guides = g;
                        const c = WidgetLayout.clamp(wrap.modelData.type, wrap.modelData.face, w, h);
                        wrap.ww = Math.min(c[0], ed.width - wrap.x);
                        wrap.hh = Math.min(c[1], ed.height - wrap.y);
                    }
                    onCanceled: ed.guides = []
                    onReleased: { ed.guides = []; ed.measures = []; WidgetLayout.update(ed.mode, wrap.modelData.id, { w: Math.round(wrap.ww), h: Math.round(wrap.hh) }); }
                }
            }
            // its own little bar: the name, the look, its settings, remove
            Rectangle {
                id: wbar
                visible: wrap.sel
                anchors.bottom: wrap.y > 70 ? parent.top : undefined
                anchors.top: wrap.y > 70 ? undefined : parent.bottom
                anchors.bottomMargin: 12; anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40; width: wb.implicitWidth + 12
                radius: 20
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                Row {
                    id: wb
                    anchors.centerIn: parent
                    spacing: 2
                    Label { anchors.verticalCenter: parent.verticalCenter; text: WidgetLayout.typeName(wrap.modelData.type); strong: true; font.pixelSize: Theme.sizeSmall + 1; leftPadding: 10; rightPadding: 6 }
                    // its look, as a drop-down (hidden when the widget has just one)
                    Dropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180; height: 32
                        visible: (WidgetLayout.faces[wrap.modelData.type] || []).length > 1
                        opts: WidgetLayout.faces[wrap.modelData.type] || []
                        value: WidgetLayout.faceId(wrap.modelData.type, wrap.modelData.face)
                        onPicked: v => WidgetLayout.setFace(ed.mode, wrap.modelData, v)
                    }
                    Pressable {
                        width: 32; height: 32
                        color: ed.optsOpen ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                        onClicked: ed.optsOpen = !ed.optsOpen
                        Icon { anchors.centerIn: parent; name: "tune"; size: 19; color: ed.optsOpen ? Theme.onAccentContainer : Theme.text }
                    }
                    Rectangle { width: 1; height: 22; color: Theme.ringTrack; anchors.verticalCenter: parent.verticalCenter }
                    Pressable { width: 32; height: 32; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"; onClicked: { WidgetLayout.remove(ed.mode, wrap.modelData.id); ed.selected = ""; } Icon { anchors.centerIn: parent; name: "delete"; size: 19; color: Theme.danger } }
                }
            }
            // its settings: under (or over) its little bar
            Rectangle {
                opacity: (wrap.sel && ed.optsOpen) ? 1 : 0
                scale: (wrap.sel && ed.optsOpen) ? 1 : Theme.popScale
                visible: opacity > 0.01
                transformOrigin: wrap.y > 70 ? Item.Bottom : Item.Top
                Behavior on opacity { NumberAnimation { duration: (wrap.sel && ed.optsOpen) ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: (wrap.sel && ed.optsOpen) ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: (wrap.sel && ed.optsOpen) ? Theme.enterCurve : Theme.exitCurve } }
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                y: wrap.y > 70 ? -12 - 40 - 8 - height : wrap.height + 12 + 40 + 8
                width: 340
                height: optCol.implicitHeight + 24
                radius: Theme.corner(60, 10)
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                MouseArea { anchors.fill: parent }
                Column {
                    id: optCol
                    x: 12; y: 12; width: parent.width - 24
                    spacing: 10
                    Repeater {
                        model: WidgetLayout.optionsFor(wrap.modelData.type, wrap.modelData.face)
                        Column {
                            id: oc
                            required property var modelData
                            readonly property var val: ed.optionValue(wrap.modelData, modelData)
                            width: optCol.width
                            spacing: 4
                            Row {
                                width: parent.width
                                visible: oc.modelData[2] === "toggle"
                                Label { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; text: oc.modelData[1]; wrapMode: Text.Wrap }
                                Toggle { checked: oc.val === true; onToggled: on => ed.setOption(wrap.modelData.id, oc.modelData[0], on) }
                            }
                            Label { visible: oc.modelData[2] !== "toggle"; text: oc.modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall }
                            NumberBox {
                                visible: oc.modelData[2] === "slider"
                                width: parent.width
                                from: oc.modelData[4] ? oc.modelData[4][0] : 0; to: oc.modelData[4] ? oc.modelData[4][1] : 1
                                step: oc.modelData[4] ? oc.modelData[4][2] : 1
                                readonly property bool pct: oc.modelData[0] === "opacity" || oc.modelData[0] === "blurStrength"
                                decimals: pct ? 2 : 0
                                factor: pct ? 100 : 1
                                unit: pct ? "%" : (oc.modelData[0] === "lineThickness" || oc.modelData[0] === "radius" ? "px" : "")
                                // Rounding not set yet: the look's own (shown as the style's corner size)
                                value: oc.modelData[0] === "radius" && Number(oc.val) < 0 ? Math.round(Theme.corner(80, 12)) : Number(oc.val)
                                onMoved: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            Segmented {
                                visible: oc.modelData[2] === "choice"
                                width: parent.width; height: 34
                                opts: oc.modelData[2] === "choice" ? oc.modelData[4] : []
                                value: String(oc.val)
                                onPicked: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            // a colour: the theme's own, a theme colour, or any #rrggbb typed in
                            Flow {
                                visible: oc.modelData[2] === "colour"
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: oc.modelData[2] === "colour" ? WidgetLayout.colourChoices : []
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool on: String(oc.val || "") === modelData[0]
                                        width: 30; height: 30; radius: 15
                                        color: ed.swatch(modelData[0])
                                        border.width: on ? 3 : 1
                                        border.color: on ? Theme.accent : Theme.hairline
                                        Icon { anchors.centerIn: parent; visible: parent.modelData[0] === ""; name: "format_color_reset"; size: 16; color: Theme.subtext }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ed.setOption(wrap.modelData.id, oc.modelData[0], parent.modelData[0]) }
                                    }
                                }
                                Field {
                                    width: 110
                                    text: String(oc.val || "").startsWith("#") ? String(oc.val) : ""
                                    placeholder: "#rrggbb"
                                    onAccepted: v => { v = v.trim(); if (!v.startsWith("#")) v = "#" + v; if (/^#[0-9a-fA-F]{6}$/.test(v)) ed.setOption(wrap.modelData.id, oc.modelData[0], v); }
                                }
                            }
                            Field {
                                visible: oc.modelData[2] === "text" || oc.modelData[2] === "file"
                                width: parent.width
                                text: String(oc.val || "")
                                placeholder: oc.modelData[2] === "file" ? "/path/to/picture.png (Enter)" : "Type, then Enter"
                                onAccepted: v => ed.setOption(wrap.modelData.id, oc.modelData[0], oc.modelData[2] === "file" ? v.trim().replace(/^~/, Wall.home) : v)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the toolbar ──
    Rectangle {
        id: bar
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        height: 52
        width: tb.implicitWidth + 16
        radius: 26
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        Row {
            id: tb
            anchors.centerIn: parent
            spacing: 8
            Icon { name: "dashboard_customize"; size: 22; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { text: "Editing"; strong: true; anchors.verticalCenter: parent.verticalCenter; rightPadding: 4 }
            Segmented {
                width: 240; height: 38
                anchors.verticalCenter: parent.verticalCenter
                opts: [["desktop", "Desktop"], ["lock", "Lock screen"]]
                value: ed.mode
                onPicked: v => { ed.selected = ""; HubState.editWidgets = v; }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Add widget"; icon: "add"; primary: ed.adding; onClicked: { ed.adding = !ed.adding; ed.presetsOpen = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Presets"; icon: "auto_awesome_mosaic"; primary: ed.presetsOpen; onClicked: { ed.presetsOpen = !ed.presetsOpen; ed.adding = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; icon: ed.snap ? "grid_on" : "grid_off"; onClicked: Store.set("widgets.snap", !ed.snap) }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Distances"; icon: "straighten"; primary: ed.distances; onClicked: Store.set("widgets.distances", !ed.distances) }
            Button {
                id: resetB
                property bool armed: false
                anchors.verticalCenter: parent.verticalCenter
                text: armed ? "Sure?" : "Reset"; icon: "restart_alt"
                onClicked: { if (armed) { WidgetLayout.reset(ed.mode); armed = false; } else { armed = true; disarm.restart(); } }
                Timer { id: disarm; interval: 4000; onTriggered: resetB.armed = false }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Done"; icon: "check"; primary: true; onClicked: ed.done() }
        }
    }
    Label {
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.bottom; anchors.topMargin: 8
        text: ed.list.length === 0 ? "Nothing here yet: Add widget" : "Drag to move (it lines up with the middle and the other widgets; Ctrl: freely)  ·  corner to resize  ·  Esc when done"
        color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
        font.pixelSize: Theme.sizeSmall
    }

    // ── adding: every widget as a live preview card along the bottom, by category. Click adds it
    // near the middle; drag it out onto the screen to drop it where you let go. ──
    property string addCat: "all"
    property string dragType: ""                 // a card being dragged out
    property point dragPos: Qt.point(0, 0)        // the ghost's top-left, in the window
    readonly property var dragSize: dragType !== "" ? WidgetLayout.size({ type: dragType, face: "" }) : [0, 0]
    Rectangle {
        id: palette
        opacity: ed.adding ? 1 : 0
        scale: ed.adding ? 1 : Theme.popScale
        visible: opacity > 0.01
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: ed.adding ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: ed.adding ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: ed.adding ? Theme.enterCurve : Theme.exitCurve } }
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: Math.min(parent.width - 60, Math.max(cats.implicitWidth, pal.implicitWidth) + 24)
        height: 214
        radius: Theme.corner(214, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        MouseArea { anchors.fill: parent }       // clicks on the strip don't deselect
        Segmented {
            id: cats
            x: 12; y: 12
            width: Math.min(parent.width - 24, 620); height: 34
            opts: WidgetLayout.categories.map(c => [c[0], c[1]])
            value: ed.addCat
            onPicked: v => ed.addCat = v
        }
        Flickable {
            SmoothWheel { horizontal: true }
            x: 12; y: 56
            width: parent.width - 24; height: parent.height - 68
            contentWidth: pal.implicitWidth
            clip: true
            interactive: ed.dragType === ""
            Row {
                id: pal
                spacing: 8
                Repeater {
                    model: (WidgetLayout.categories.find(c => c[0] === ed.addCat) || WidgetLayout.categories[0])[3]
                    Pressable {
                        id: card
                        required property string modelData
                        readonly property var sz: WidgetLayout.size({ type: modelData, face: "" })
                        width: 150; height: 146
                        color: cardMa.containsMouse ? Theme.control : Theme.containerHigh
                        Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                        onClicked: { ed.selected = WidgetLayout.add(ed.mode, modelData, ed.modelData.name); ed.adding = false; }
                        // a still preview of the widget, scaled into the card
                        Item {
                            id: prev
                            x: 8; y: 8; width: parent.width - 16; height: 100
                            clip: true
                            WidgetFace {
                                live: false
                                item: ({ id: "preview-" + card.modelData, type: card.modelData, face: "", opts: {} })
                                width: card.sz[0]; height: card.sz[1]
                                scale: Math.min(prev.width / card.sz[0], prev.height / card.sz[1], 1)
                                anchors.centerIn: parent
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            spacing: 6
                            Icon { name: WidgetLayout.typeIcon(card.modelData); size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: WidgetLayout.typeName(card.modelData); font.pixelSize: Theme.sizeSmall; strong: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        // drag it out: past a few pixels it becomes a ghost that follows the pointer
                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            property point start
                            property bool dragging: false
                            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); dragging = false; }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                if (!dragging && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 8) { dragging = true; ed.dragType = card.modelData; }
                                if (!dragging) return;
                                const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                                // the new widget lines up with the others like a moved one
                                ed.dragPos = ed.place({ width: ed.dragSize[0], height: ed.dragSize[1] }, p.x - ed.dragSize[0] / 2, p.y - ed.dragSize[1] / 2, (mouse.modifiers & Qt.ControlModifier) !== 0);
                            }
                            onReleased: mouse => {
                                if (dragging) {
                                    const p = mapToItem(palette, mouse.x, mouse.y);
                                    // dropped back on the strip: nothing
                                    if (!palette.contains(p)) {
                                        ed.selected = WidgetLayout.add(ed.mode, card.modelData, ed.modelData.name, ed.dragPos.x / ed.width, ed.dragPos.y / ed.height);
                                        Sounds.play("drop");
                                        ed.adding = false;
                                    }
                                } else card.clicked();
                                dragging = false; ed.dragType = ""; ed.guides = []; ed.measures = [];
                            }
                            onCanceled: { dragging = false; ed.dragType = ""; ed.guides = []; ed.measures = []; }
                        }
                    }
                }
            }
        }
    }
    // the dragged card: the widget itself, see-through, where it will land
    WidgetFace {
        visible: ed.dragType !== ""
        z: 90
        live: false
        opacity: 0.75
        item: ({ id: "ghost", type: ed.dragType || "clock", face: "", opts: {} })
        x: ed.dragPos.x; y: ed.dragPos.y
        width: ed.dragSize[0]; height: ed.dragSize[1]
        Rectangle { anchors.fill: parent; anchors.margins: -6; radius: 10; color: "transparent"; border.width: 2; border.color: Theme.accent }
    }

    // ── distances: while a widget moves, how far it is from each screen edge ──
    readonly property bool distances: Store.get("widgets.distances", false) === true
    property var moving: null                     // the widget being moved (its wrapper)
    Item {
        id: dist
        z: 80
        anchors.fill: parent
        readonly property var r: ed.moving ? Qt.rect(ed.moving.x, ed.moving.y, ed.moving.width, ed.moving.height)
            : (ed.dragType !== "" ? Qt.rect(ed.dragPos.x, ed.dragPos.y, ed.dragSize[0], ed.dragSize[1]) : null)
        visible: ed.distances && r !== null
        component Gap: Item {
            property bool horizontal: true
            property real len: 0
            Rectangle {
                color: Theme.accent
                width: parent.horizontal ? parent.width : 2; height: parent.horizontal ? 2 : parent.height
                anchors.centerIn: parent
            }
            Rectangle {
                visible: parent.len > 30
                anchors.centerIn: parent
                width: gl.implicitWidth + 12; height: 22; radius: 11
                color: Theme.accent
                Text { id: gl; anchors.centerIn: parent; text: Math.round(parent.parent.len) + " px"; color: Theme.onAccent; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
            }
        }
        Gap { visible: !!dist.r; horizontal: true; len: dist.r ? dist.r.x : 0; x: 0; width: len; y: dist.r ? dist.r.y + dist.r.height / 2 - 11 : 0; height: 22 }
        Gap { visible: !!dist.r; horizontal: true; len: dist.r ? ed.width - dist.r.x - dist.r.width : 0; x: dist.r ? dist.r.x + dist.r.width : 0; width: len; y: dist.r ? dist.r.y + dist.r.height / 2 - 11 : 0; height: 22 }
        Gap { visible: !!dist.r; horizontal: false; len: dist.r ? dist.r.y : 0; y: 0; height: len; x: dist.r ? dist.r.x + dist.r.width / 2 - 11 : 0; width: 22 }
        Gap { visible: !!dist.r; horizontal: false; len: dist.r ? ed.height - dist.r.y - dist.r.height : 0; y: dist.r ? dist.r.y + dist.r.height : 0; height: len; x: dist.r ? dist.r.x + dist.r.width / 2 - 11 : 0; width: 22 }
    }

    // ── presets: ready-made arrangements, replacing this screen's widgets ──
    property bool presetsOpen: false
    Rectangle {
        opacity: ed.presetsOpen ? 1 : 0
        scale: ed.presetsOpen ? 1 : Theme.popScale
        visible: opacity > 0.01
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: ed.presetsOpen ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: ed.presetsOpen ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: ed.presetsOpen ? Theme.enterCurve : Theme.exitCurve } }
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: prow.implicitWidth + 24
        height: 132
        radius: Theme.corner(132, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        Row {
            id: prow
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: WidgetLayout.presets
                Pressable {
                    required property var modelData
                    width: 150; height: 108
                    color: Theme.containerHigh
                    onClicked: { WidgetLayout.applyPreset(ed.mode, modelData[0], ed.modelData.name); ed.selected = ""; ed.presetsOpen = false; }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Bubble { anchors.horizontalCenter: parent.horizontalCenter; size: 44; icon: parent.parent.modelData[2] }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[1]; strong: true; font.pixelSize: Theme.sizeSmall }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[3].length + " widgets"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                }
            }
        }
    }

    // keys
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: { if (ed.presetsOpen) ed.presetsOpen = false; else if (ed.adding) ed.adding = false; else if (ed.selected !== "") ed.selected = ""; else ed.done(); }
        Keys.onDeletePressed: if (ed.selected !== "") { WidgetLayout.remove(ed.mode, ed.selected); ed.selected = ""; }
    }
}
