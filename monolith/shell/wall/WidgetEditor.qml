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
    // the grid (Grid in the toolbar): its lines are exactly where widgets snap
    readonly property real grid: Number(Store.get("widgets.gridSize", 40)) || 40

    // hidden while a picture is being chosen (the file dialog opens under this layer)
    visible: (shown || contentItem.opacity > 0.01) && !Pictures.picking
    WlrLayershell.namespace: "monolith-widget-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown && !HubState.authOpen && !Pictures.picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    // the whole editor fades in with a little zoom, and out when it closes (the window is clear
    // underneath, so what's behind shows through the fade)
    color: "transparent"
    Component.onCompleted: { syncSlots(); if (shown) edIn.restart(); else contentItem.opacity = 0; }
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
        source: Wall.still(Wall.pathFor(ed.modelData.name))
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(ed.width / (ed.lockMode ? 2 : 1), ed.height / (ed.lockMode ? 2 : 1))
        visible: !ed.lockMode
    }
    MultiEffect { anchors.fill: parent; source: wp; visible: ed.lockMode; blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.08 }
    Rectangle { anchors.fill: parent; visible: ed.lockMode; color: Qt.alpha(Theme.frame, 0.35) }
    // the grid
    Canvas {
        id: gridLines
        anchors.fill: parent
        visible: ed.snap
        opacity: 0.18
        // drawn again whenever the screen or the grid's size changes (it was drawn once, at whatever size it had then)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: ed; function onGridChanged() { gridLines.requestPaint(); } }
        onPaint: {
            const g = getContext("2d"); g.reset(); g.strokeStyle = "#ffffff"; g.lineWidth = 1;
            for (let x = 0; x <= width; x += ed.grid) { g.beginPath(); g.moveTo(Math.round(x) + 0.5, 0); g.lineTo(Math.round(x) + 0.5, height); g.stroke(); }
            for (let y = 0; y <= height; y += ed.grid) { g.beginPath(); g.moveTo(0, Math.round(y) + 0.5); g.lineTo(width, Math.round(y) + 0.5); g.stroke(); }
        }
    }
    // the lock screen's password pill with the power buttons under it (as big as on the lock
    // screen: 420 × 122): drag it anywhere, it catches on the same lines as the widgets do (Ctrl:
    // freely). Saved as its middle (lock.password); Reset puts it back at the bottom
    Item {
        id: pass
        visible: ed.lockMode && WidgetLayout.passOn(ed.modelData.name)
        width: 420; height: 122
        z: 5
        readonly property var at: WidgetLayout.passAt(ed.modelData.name)
        readonly property bool placed: !!at && typeof at.x === "number" && typeof at.y === "number"
        // (read straight from Store: in onAtChanged the `placed` binding may not have caught up yet)
        function home() {
            const a = WidgetLayout.passAt(ed.modelData.name);
            const ok = !!a;
            x = Math.max(0, Math.min(ed.width - width, ok ? a.x * ed.width - width / 2 : (ed.width - width) / 2));
            y = Math.max(0, Math.min(ed.height - height, ok ? a.y * ed.height - height / 2 : ed.height * 0.92 - height));
        }
        onAtChanged: home()
        Component.onCompleted: home()
        Connections { target: ed; function onWidthChanged() { pass.home(); } function onHeightChanged() { pass.home(); } }
        Rectangle {
            id: passPill
            width: parent.width; height: 64; radius: Theme.corner(48, 8)
            color: Qt.alpha(Theme.frame, 0.85)
            border.width: 2; border.color: passMa.pressed || passMa.containsMouse ? Theme.accent : Qt.alpha(Theme.text, 0.35)
            Row {
                anchors.centerIn: parent; spacing: 10
                Icon { name: "drag_pan"; size: 20; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Password: drag to move"; muted: true; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10
            Repeater {
                model: ["bedtime", "restart_alt", "power_settings_new"]
                Rectangle {
                    required property string modelData
                    width: 44; height: 44; radius: 22
                    color: Qt.alpha(Theme.frame, 0.75)
                    border.width: 1; border.color: Qt.alpha(Theme.text, 0.2)
                    Icon { anchors.centerIn: parent; name: parent.modelData; size: 20; color: Theme.subtext }
                }
            }
        }
        MouseArea {
            id: passMa
            anchors.fill: parent; anchors.margins: -6
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point start
            property point from
            onPressed: mouse => { ed.selected = ""; ed.adding = false; start = mapToItem(ed.contentItem, mouse.x, mouse.y); from = Qt.point(pass.x, pass.y); ed.moving = pass; }
            onCanceled: { ed.moving = null; ed.guides = []; ed.measures = []; }
            onPositionChanged: mouse => {
                if (!pressed) return;
                const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                const at = ed.place(pass, from.x + p.x - start.x, from.y + p.y - start.y, (mouse.modifiers & Qt.ControlModifier) !== 0);
                pass.x = at.x; pass.y = at.y;
            }
            onReleased: {
                ed.moving = null; ed.guides = []; ed.measures = [];
                WidgetLayout.setPassAt(ed.modelData.name, { x: (pass.x + pass.width / 2) / ed.width, y: (pass.y + pass.height / 2) / ed.height });
            }
            // double-click: back to the bottom middle
            onDoubleClicked: WidgetLayout.setPassAt(ed.modelData.name, null)
        }
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
        if (lockMode && pass.visible && self !== pass) out.push({ l: pass.x, t: pass.y, r: pass.x + pass.width, b: pass.y + pass.height });
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
    // a widget's new box while one of its edges / corners is dragged: the moved edges catch on
    // lines (else the grid), the size stays inside the look's limits and shape, the far side stays
    function resizeBox(wrap, b0, edges, dx, dy, free) {
        let l = b0.l, t = b0.t, r = b0.r, b = b0.b;
        const g = [];
        const pick = (h, v) => { if (free) return v; const ln = edgeCatch(h, v, wrap); if (ln >= 0) { g.push(h ? ln : -1 - ln); return ln; } return snapTo(v); };
        if (edges[0]) l = pick(true, Math.max(0, b0.l + dx));
        if (edges[2]) r = pick(true, Math.min(width, b0.r + dx));
        if (edges[1]) t = pick(false, Math.max(0, b0.t + dy));
        if (edges[3]) b = pick(false, Math.min(height, b0.b + dy));
        // the look's limits and shape work on its own (unturned) size
        const it = wrap.modelData;
        const sw = wrap.sideways;
        let w = Math.max(1, r - l), h = Math.max(1, b - t);
        const c = WidgetLayout.clamp(it.type, it.face, sw ? h : w, sw ? w : h);
        w = sw ? c[1] : c[0]; h = sw ? c[0] : c[1];
        // only one direction dragged: the other grows around the middle (a shape that keeps its aspect)
        if (edges[0] && !edges[2]) l = r - w; else if (edges[2] && !edges[0]) r = l + w; else { const m = (l + r) / 2; l = m - w / 2; r = l + w; }
        if (edges[1] && !edges[3]) t = b - h; else if (edges[3] && !edges[1]) b = t + h; else { const m = (t + b) / 2; t = m - h / 2; b = t + h; }
        // inside the screen
        if (l < 0) { r -= l; l = 0; } if (r > width) { l -= r - width; r = width; }
        if (t < 0) { b -= t; t = 0; } if (b > height) { t -= b - height; b = height; }
        const others = otherBoxes(wrap);
        const box = { l: l, t: t, r: r, b: b };
        guides = g.map(v => v >= 0 ? guideFor(true, v, box, others) : guideFor(false, -1 - v, box, others));
        return { l: l, t: t, r: r, b: b };
    }
    // turn a widget to angle `a` about its middle (`c`: that middle on screen, else where it is
    // now), keeping its box on the screen
    function angleTo(id, a, c) {
        const raw = WidgetLayout.items(mode).find(i => i.id === id);
        if (!raw) return;
        const it = WidgetLayout.fitted(raw, height);
        const s = WidgetLayout.size(it);
        const b0 = WidgetLayout.footprint(it);
        if (!c) {
            const x0 = Math.max(0, Math.min(it.x * width, width - b0[0])), y0 = Math.max(0, Math.min(it.y * height, height - b0[1]));
            c = Qt.point(x0 + b0[0] / 2, y0 + b0[1] / 2);
        }
        a = WidgetLayout.normAngle(a);
        const b = WidgetLayout.box(s[0], s[1], a);
        const x = Math.max(0, Math.min(width - b[0], c.x - b[0] / 2)), y = Math.max(0, Math.min(height - b[1], c.y - b[1] / 2));
        WidgetLayout.update(mode, id, { x: x / width, y: y / height, opts: Object.assign({}, raw.opts || {}, { rotation: String(a) }) }, height);
    }
    // a quarter clockwise from where it is
    function turn(wrap) { angleTo(wrap.modelData.id, Math.round(wrap.liveAng / 90) * 90 + 90); }
    // resizing a turned widget: the handle moves its own sides (the drag measured along them),
    // the opposite side stays put on screen
    function resizeTurned(wrap, b0, edges, dx, dy) {
        const r = wrap.liveAng * Math.PI / 180, co = Math.cos(r), si = Math.sin(r);
        const du = dx * co + dy * si, dv = -dx * si + dy * co;
        let w = b0.w + (edges[2] ? du : 0) - (edges[0] ? du : 0);
        let h = b0.h + (edges[3] ? dv : 0) - (edges[1] ? dv : 0);
        const it = wrap.modelData;
        const c = WidgetLayout.clamp(it.type, it.face, Math.max(1, w), Math.max(1, h));
        w = c[0]; h = c[1];
        // the middle moves half as far as the dragged side, along the widget's own axes
        const mu = edges[2] ? (w - b0.w) / 2 : (edges[0] ? -(w - b0.w) / 2 : 0);
        const mv = edges[3] ? (h - b0.h) / 2 : (edges[1] ? -(h - b0.h) / 2 : 0);
        return { w: w, h: h, cx: b0.cx + mu * co - mv * si, cy: b0.cy + mu * si + mv * co };
    }
    function keepOnScreen(wrap) {
        wrap.x = Math.max(0, Math.min(width - wrap.width, wrap.x));
        wrap.y = Math.max(0, Math.min(height - wrap.height, wrap.y));
    }
    // a resized widget's edges catch the same lines
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
    // the picked file is saved straight to the layout (the editor may have closed meanwhile)
    function pickPicture(id, k) {
        const m = mode, key = k || "imagePath";
        Pictures.choose("Choose a picture for the widget", f => {
            if (key.startsWith("store:")) Store.set(key.slice(6), f);
            else WidgetLayout.setOpt(m, id, key, f);
        });
    }
    property bool optsOpen: false
    onSelectedChanged: optsOpen = false
    function setOption(id, k, v) {
        if (k === "rotation") { angleTo(id, Number(v) || 0); return; }
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
    // the widgets, kept in a model that's updated in place: a changed setting (a slider being
    // dragged, a look picked) changes that widget instead of rebuilding them all, which cut a
    // slider's drag off after its first step and closed the settings panel
    ListModel { id: slots }
    function syncSlots() {
        const l = ed.list;
        let same = slots.count === l.length;
        for (let i = 0; same && i < l.length; i++) if (slots.get(i).iid !== l[i].id) same = false;
        if (!same) {
            slots.clear();
            for (const it of l) slots.append({ iid: it.id, json: JSON.stringify(it) });
            return;
        }
        for (let i = 0; i < l.length; i++) {
            const j = JSON.stringify(l[i]);
            if (slots.get(i).json !== j) slots.setProperty(i, "json", j);
        }
    }
    onListChanged: syncSlots()
    Repeater {
        id: widgetsRep
        model: slots
        Item {
            id: wrap
            required property string json
            // (at the size it has on this screen: smaller on a screen shorter than its own)
            readonly property var modelData: WidgetLayout.fitted(JSON.parse(json), ed.height)
            readonly property bool sel: ed.selected === modelData.id
            // its own (upright) size, and its angle: both follow a drag live, the layout on release
            readonly property var sz: WidgetLayout.size(modelData)
            readonly property real ang: WidgetLayout.rot(modelData)
            property real ww: sz[0]
            property real hh: sz[1]
            property real liveAng: ang
            onSzChanged: { ww = sz[0]; hh = sz[1]; }
            onAngChanged: liveAng = ang
            readonly property bool upright: liveAng === 0
            readonly property bool sideways: false
            property bool twisting: false
            // the box it takes on screen (turned): what moves, lines up and stays on the screen
            readonly property var bb: WidgetLayout.box(ww, hh, liveAng)
            width: bb[0]
            height: bb[1]
            // where the layout puts it, set again whenever the layout changes (a drag sets x/y
            // itself while it lasts; bindings broken by a drag left it in the wrong place after a
            // turn, so the bar and the settings flew off with it)
            function home() {
                x = Math.max(0, Math.min(modelData.x * ed.width, ed.width - width));
                y = Math.max(0, Math.min(modelData.y * ed.height, ed.height - height));
            }
            onModelDataChanged: home()
            Component.onCompleted: home()
            Connections { target: ed; function onWidthChanged() { wrap.home(); } function onHeightChanged() { wrap.home(); } }
            z: sel ? 10 : 1

            // the widget itself, turned: its frame, handles and the twist handle turn with it
            Item {
                id: wbody
                anchors.centerIn: parent
                width: wrap.ww
                height: wrap.hh
                rotation: wrap.liveAng
                // a picture dropped on a picture widget becomes its picture
                DropArea {
                    anchors.fill: parent
                    enabled: wrap.modelData.type === "image"
                    onEntered: drag => { drag.accepted = drag.hasUrls; }
                    onDropped: drop => { const f = Pictures.fromDrop(drop.urls); if (f !== "") { ed.selected = wrap.modelData.id; ed.setOption(wrap.modelData.id, "imagePath", f); drop.accept(); } }
                    Rectangle { anchors.fill: parent; anchors.margins: -6; radius: 10; visible: parent.containsDrag; color: Qt.alpha(Theme.accent, 0.18); border.width: 2; border.color: Theme.accent; z: 20 }
                }
                WidgetFace {
                    id: face
                    anchors.fill: parent
                    item: wrap.modelData
                    turn: false
                    editing: true
                    backdrop: ed.lockMode ? null : wp
                    origin: Qt.point(wrap.x + (wrap.width - wrap.ww) / 2, wrap.y + (wrap.height - wrap.hh) / 2)
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
                    onCanceled: { ed.moving = null; ed.guides = []; ed.measures = []; wrap.home(); }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                        const at = ed.place(wrap, from.x + p.x - start.x, from.y + p.y - start.y, (mouse.modifiers & Qt.ControlModifier) !== 0);
                        wrap.x = at.x; wrap.y = at.y;
                    }
                    onReleased: { ed.moving = null; ed.guides = []; ed.measures = []; WidgetLayout.update(ed.mode, wrap.modelData.id, { x: wrap.x / ed.width, y: wrap.y / ed.height }, ed.height); }
                    onDoubleClicked: if (wrap.modelData.type === "image") ed.pickPicture(wrap.modelData.id)
                }
                // resize: from any edge or corner (inside the widget's limits and its look's shape; the
                // opposite side stays put). Upright, edges catch on lines and the grid like a move
                // (Ctrl: freely); turned, they follow the widget's own sides
                Repeater {
                    // [left?, top?, right?, bottom?] edges each handle moves
                    model: [[1, 1, 0, 0], [0, 1, 0, 0], [0, 1, 1, 0], [0, 0, 1, 0], [0, 0, 1, 1], [0, 0, 0, 1], [1, 0, 0, 1], [1, 0, 0, 0]]
                    Rectangle {
                        id: hd
                        required property var modelData
                        readonly property bool corner: (modelData[0] || modelData[2]) && (modelData[1] || modelData[3])
                        readonly property bool horiz: !corner && (modelData[1] || modelData[3])     // a top or bottom edge
                        visible: wrap.sel && !wrap.twisting
                        z: 12
                        width: corner ? 18 : (horiz ? 34 : 10)
                        height: corner ? 18 : (horiz ? 10 : 34)
                        radius: Math.min(width, height) / 2
                        x: (modelData[0] ? -6 : (modelData[2] ? wbody.width + 6 : wbody.width / 2)) - width / 2
                        y: (modelData[1] ? -6 : (modelData[3] ? wbody.height + 6 : wbody.height / 2)) - height / 2
                        color: Theme.accent
                        border.width: 2; border.color: Theme.onAccent
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -7
                            cursorShape: hd.corner ? ((hd.modelData[0] === hd.modelData[1]) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : (hd.horiz ? Qt.SizeVerCursor : Qt.SizeHorCursor)
                            property point start
                            property var box0
                            onPressed: mouse => {
                                start = mapToItem(ed.contentItem, mouse.x, mouse.y);
                                box0 = { l: wrap.x, t: wrap.y, r: wrap.x + wrap.width, b: wrap.y + wrap.height, w: wrap.ww, h: wrap.hh,
                                         cx: wrap.x + wrap.width / 2, cy: wrap.y + wrap.height / 2 };
                                ed.moving = wrap;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                                if (wrap.upright) {
                                    const r = ed.resizeBox(wrap, box0, hd.modelData, p.x - start.x, p.y - start.y, (mouse.modifiers & Qt.ControlModifier) !== 0);
                                    wrap.x = r.l; wrap.y = r.t; wrap.ww = r.r - r.l; wrap.hh = r.b - r.t;
                                } else {
                                    const r = ed.resizeTurned(wrap, box0, hd.modelData, p.x - start.x, p.y - start.y);
                                    wrap.ww = r.w; wrap.hh = r.h;
                                    wrap.x = r.cx - wrap.width / 2; wrap.y = r.cy - wrap.height / 2;
                                }
                            }
                            onCanceled: { ed.moving = null; ed.guides = []; ed.measures = []; wrap.home(); }
                            onReleased: {
                                ed.moving = null; ed.guides = []; ed.measures = [];
                                ed.keepOnScreen(wrap);
                                WidgetLayout.update(ed.mode, wrap.modelData.id, { x: wrap.x / ed.width, y: wrap.y / ed.height, w: Math.round(wrap.ww), h: Math.round(wrap.hh) }, ed.height);
                            }
                        }
                    }
                }
                // twist: drag the round handle off its top-right corner around the middle, as far
                // as you like. It catches on upright, a quarter, half and three quarters (Shift:
                // every 15°; Ctrl: freely); double-click stands it upright again
                Rectangle {
                    id: twist
                    visible: wrap.sel
                    z: 13
                    width: 26; height: 26; radius: 13
                    x: wbody.width + 14 - width / 2
                    y: -14 - height / 2
                    color: twistMa.pressed || twistMa.containsMouse ? Theme.accent : Theme.frame
                    border.width: 2; border.color: Theme.accent
                    Icon { anchors.centerIn: parent; name: "rotate_right"; size: 16; color: twistMa.pressed || twistMa.containsMouse ? Theme.onAccent : Theme.accent }
                    // a thin line to the corner it turns from
                    Rectangle { z: -1; width: 2; height: 14; color: Theme.accent; x: parent.width / 2 - 13; y: parent.height - 3; rotation: 45; transformOrigin: Item.Top; opacity: 0.6 }
                    MouseArea {
                        id: twistMa
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.CrossCursor
                        property real a0: 0
                        property real p0: 0
                        property point c
                        function angleAt(mouse) { const p = mapToItem(ed.contentItem, mouse.x, mouse.y); return Math.atan2(p.y - c.y, p.x - c.x) * 180 / Math.PI; }
                        onPressed: mouse => {
                            ed.selected = wrap.modelData.id; ed.adding = false;
                            c = Qt.point(wrap.x + wrap.width / 2, wrap.y + wrap.height / 2);
                            a0 = wrap.liveAng; p0 = angleAt(mouse);
                            wrap.twisting = true; ed.moving = wrap;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            let a = WidgetLayout.normAngle(a0 + angleAt(mouse) - p0);
                            if (mouse.modifiers & Qt.ShiftModifier) a = Math.round(a / 15) * 15 % 360;
                            else if (!(mouse.modifiers & Qt.ControlModifier)) {
                                const q = Math.round(a / 90) * 90;
                                if (Math.abs(a - q) < 6) a = q % 360;
                            }
                            a = Math.round(a);
                            wrap.liveAng = a;
                            // turning about its middle
                            wrap.x = c.x - wrap.width / 2; wrap.y = c.y - wrap.height / 2;
                        }
                        onCanceled: { wrap.twisting = false; ed.moving = null; wrap.liveAng = wrap.ang; wrap.home(); }
                        onReleased: { wrap.twisting = false; ed.moving = null; ed.angleTo(wrap.modelData.id, wrap.liveAng, Qt.point(c.x, c.y)); }
                        onDoubleClicked: ed.angleTo(wrap.modelData.id, 0)
                    }
                }
            }
            // the angle, while it's being twisted (upright, over its middle)
            Rectangle {
                visible: wrap.twisting
                z: 30
                anchors.centerIn: parent
                width: angL.implicitWidth + 20; height: 30; radius: 15
                color: Theme.accent
                Label { id: angL; anchors.centerIn: parent; text: Math.round(wrap.liveAng) + "°"; strong: true; color: Theme.onAccent }
            }
            // ── where its little bar and its settings go: together, above it when they fit (clear
            // of the editor's toolbar), else under it, else beside it (right, then left), else on
            // the roomier of above and under (the settings scroll). Kept on the screen, and they
            // glide to a new place instead of jumping (they used to flip with no motion and could
            // hang off the screen's sides).
            readonly property bool optsShown: sel && ed.optsOpen
            readonly property real dockGap: 14
            readonly property real topLimit: 104                 // under the toolbar and its hint
            readonly property real bottomLimit: ed.height - 20
            readonly property real barW: wb.implicitWidth + 12
            readonly property real barH: 40
            readonly property real panelW: Math.min(360, ed.width - 24)
            readonly property real panelWant: optCol.implicitHeight + 24
            // (the settings scroll: they need some room, not all of it)
            readonly property real need: barH + (optsShown ? 8 + Math.min(panelWant, 240) : 0)
            readonly property real roomUp: y - dockGap - topLimit
            readonly property real roomDown: bottomLimit - (y + height) - dockGap
            readonly property real sideW: Math.max(barW, optsShown ? panelW : 0)
            readonly property real roomRight: ed.width - 12 - (x + width) - dockGap
            readonly property real roomLeft: x - dockGap - 12
            // (first where all of it fits without scrolling, then where enough of it does)
            readonly property real full: barH + (optsShown ? 8 + panelWant : 0)
            readonly property bool sideFits: bottomLimit - topLimit >= full
            readonly property string dock: roomUp >= full ? "up" : roomDown >= full ? "down"
                : sideFits && roomRight >= sideW ? "right" : sideFits && roomLeft >= sideW ? "left"
                : roomUp >= need ? "up" : roomDown >= need ? "down"
                : roomRight >= sideW ? "right" : roomLeft >= sideW ? "left"
                : (roomUp >= roomDown ? "up" : "down")
            readonly property bool sideDock: dock === "left" || dock === "right"
            // the settings' height: what they want, cut to the room on that side
            readonly property real panelH: {
                const room = dock === "up" ? roomUp : dock === "down" ? roomDown : bottomLimit - topLimit;
                return Math.max(Math.min(panelWant, 160), Math.min(panelWant, room - barH - 8));
            }
            // above, the bar also keeps clear of the twist handle off the top-right corner
            function clampX(lx, w) { return Math.max(12, Math.min(ed.width - 12 - w, x + lx)) - x; }
            readonly property real barX: dock === "right" ? width + dockGap : dock === "left" ? -dockGap - barW : clampX((width - barW) / 2, barW)
            readonly property real panelX: dock === "right" ? width + dockGap : dock === "left" ? -dockGap - panelW : clampX((width - panelW) / 2, panelW)
            readonly property bool overTwist: barX + barW > width / 2 + ww / 2 - 10
            readonly property real sideTop: Math.max(topLimit, Math.min(bottomLimit - barH - (optsShown ? 8 + panelH : 0), y)) - y
            readonly property real barY: dock === "up" ? -(overTwist ? 40 : dockGap) - barH
                : dock === "down" ? height + dockGap : sideTop
            readonly property real panelY: dock === "up" ? barY - 8 - panelH : barY + barH + 8
            // glides while it changes side or is pushed along an edge; follows a drag directly
            readonly property int glideMs: Theme.ms(280)

            // its own little bar: the name, the look, its settings, remove
            Rectangle {
                id: wbar
                opacity: wrap.sel ? 1 : 0
                scale: wrap.sel ? 1 : Theme.popScale
                visible: opacity > 0.01
                transformOrigin: wrap.dock === "up" ? Item.Bottom : wrap.dock === "down" ? Item.Top : wrap.dock === "right" ? Item.Left : Item.Right
                Behavior on opacity { NumberAnimation { duration: wrap.sel ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: wrap.sel ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: wrap.sel ? Theme.enterCurve : Theme.exitCurve } }
                z: 21
                x: wrap.barX
                y: wrap.barY
                Behavior on x { enabled: wrap.sel; NumberAnimation { duration: wrap.glideMs; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: wrap.sel; NumberAnimation { duration: wrap.glideMs; easing.type: Easing.OutCubic } }
                CardShadow {}
                height: wrap.barH; width: wrap.barW
                radius: Theme.corner(32, 4)
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
                    // turn it a quarter clockwise, around its middle
                    // a picture widget: pick its picture (a file dialog; the ≡ options have recent ones)
                    Pressable {
                        visible: wrap.modelData.type === "image"
                        width: visible ? implicitWidth : 0; height: 32
                        implicitWidth: picRow.implicitWidth + 16
                        color: hovered ? Theme.containerHigh : Theme.accentContainer
                        onClicked: ed.pickPicture(wrap.modelData.id)
                        Row { id: picRow; anchors.centerIn: parent; spacing: 4
                            Icon { name: "add_photo_alternate"; size: 18; color: Theme.onAccentContainer; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: "Picture…"; font.pixelSize: Theme.sizeSmall; strong: true; color: Theme.onAccentContainer; anchors.verticalCenter: parent.verticalCenter } }
                    }
                    Pressable {
                        width: 32; height: 32
                        color: hovered ? Theme.containerHigh : "transparent"
                        onClicked: ed.turn(wrap)
                        Icon { anchors.centerIn: parent; name: "rotate_right"; size: 19; color: Theme.text }
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
                opacity: wrap.optsShown ? 1 : 0
                scale: wrap.optsShown ? 1 : Theme.popScale
                visible: opacity > 0.01
                // (see dock above: with its little bar, glides when the place changes)
                transformOrigin: wrap.dock === "up" ? Item.Bottom : wrap.dock === "down" ? Item.Top : wrap.dock === "right" ? Item.TopLeft : Item.TopRight
                Behavior on opacity { NumberAnimation { duration: wrap.optsShown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: wrap.optsShown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: wrap.optsShown ? Theme.enterCurve : Theme.exitCurve } }
                z: 20
                x: wrap.panelX
                y: wrap.panelY
                Behavior on x { enabled: wrap.optsShown; NumberAnimation { duration: wrap.glideMs; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: wrap.optsShown; NumberAnimation { duration: wrap.glideMs; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: wrap.optsShown; NumberAnimation { duration: wrap.glideMs; easing.type: Easing.OutCubic } }
                CardShadow {}
                width: wrap.panelW
                // long lists (the visualiser's) scroll
                height: wrap.panelH
                radius: Theme.corner(60, 10)
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                MouseArea { anchors.fill: parent; onWheel: wheel => wheel.accepted = true }
                Flickable {
                    id: optFlick
                    anchors.fill: parent; anchors.margins: 12
                    contentHeight: optCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    SmoothWheel {}
                Column {
                    id: optCol
                    width: optFlick.width
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
                            // a section's name
                            Label {
                                visible: oc.modelData[2] === "header"
                                topPadding: 6
                                text: oc.modelData[1]; strong: true; color: Theme.accent
                            }
                            Label { visible: oc.modelData[2] !== "toggle" && oc.modelData[2] !== "header"; text: oc.modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall; width: parent.width; wrapMode: Text.Wrap }
                            Dropdown {
                                visible: oc.modelData[2] === "dropdown"
                                width: parent.width; height: 34
                                opts: oc.modelData[2] === "dropdown" ? oc.modelData[4] : []
                                value: String(oc.val)
                                onPicked: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            NumberBox {
                                visible: oc.modelData[2] === "slider"
                                width: parent.width
                                readonly property bool on: oc.modelData[2] === "slider" && !!oc.modelData[4]
                                from: on ? oc.modelData[4][0] : 0; to: on ? oc.modelData[4][1] : 1
                                step: on ? oc.modelData[4][2] : 1
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
                                visible: oc.modelData[2] === "text"
                                width: parent.width
                                text: String(oc.val || "")
                                placeholder: "Type, then Enter"
                                onAccepted: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            // a picture: Choose… (a file dialog in Pictures), your recent pictures to
                            // click, or drop one on the widget; typing a path still works
                            Column {
                                visible: oc.modelData[2] === "file"
                                width: parent.width
                                spacing: 6
                                Component.onCompleted: if (oc.modelData[2] === "file") Pictures.refresh()
                                onVisibleChanged: if (visible) Pictures.refresh()
                                Row {
                                    spacing: 6
                                    Button { text: "Choose…"; icon: "folder_open"; primary: true; height: 34; onClicked: ed.pickPicture(wrap.modelData.id, oc.modelData[0]) }
                                    Button { visible: String(oc.val || "") !== ""; text: "Clear"; height: 34; onClicked: ed.setOption(wrap.modelData.id, oc.modelData[0], "") }
                                }
                                Label { width: parent.width; elide: Text.ElideMiddle; muted: true; font.pixelSize: Theme.sizeTiny + 1; text: String(oc.val || "") !== "" ? String(oc.val).replace(Wall.home, "~") : "Or drop a picture on the widget" }
                                Label { visible: Pictures.recent.length > 0; text: "Recent pictures"; muted: true; font.pixelSize: Theme.sizeTiny + 1 }
                                Flow {
                                    width: parent.width
                                    spacing: 6
                                    Repeater {
                                        model: oc.modelData[2] === "file" ? Pictures.recent.slice(0, 12) : []
                                        Rectangle {
                                            required property string modelData
                                            readonly property bool on: String(oc.val || "") === modelData
                                            width: (parent.width - 3 * 6) / 4; height: width * 0.7
                                            radius: 8
                                            color: Theme.container
                                            border.width: on ? 3 : 0; border.color: Theme.accent
                                            clip: true
                                            Image { anchors.fill: parent; anchors.margins: parent.on ? 3 : 0; source: Wall.url(parent.modelData); sourceSize: Qt.size(160, 112); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ed.setOption(wrap.modelData.id, oc.modelData[0], parent.modelData) }
                                        }
                                    }
                                }
                                Field {
                                    width: parent.width; height: 34
                                    text: ""
                                    placeholder: "…or type a path, then Enter"
                                    onAccepted: v => { if (v.trim() !== "") ed.setOption(wrap.modelData.id, oc.modelData[0], v.trim().replace(/^~/, Wall.home)); }
                                }
                            }
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
        // too wide for the screen (a small or scaled one): shrinks to fit
        scale: Math.min(1, (ed.width - 32) / width)
        transformOrigin: Item.Top
        radius: Theme.corner(40, 6)
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
            // more than one screen, and this layout is per screen: hop to the next one
            Button {
                readonly property var names: Quickshell.screens.map(x => x.name)
                visible: names.length > 1 && (!ed.lockMode || WidgetLayout.lockPerScreen)
                anchors.verticalCenter: parent.verticalCenter
                text: ed.modelData.name; icon: "monitor"
                onClicked: { ed.selected = ""; HubState.editWidgetsOn(ed.mode, names[(names.indexOf(ed.modelData.name) + 1) % names.length]); }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Add widget"; icon: "add"; primary: ed.adding; onClicked: { ed.adding = !ed.adding; ed.presetsOpen = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Presets"; icon: "auto_awesome_mosaic"; primary: ed.presetsOpen; onClicked: { ed.presetsOpen = !ed.presetsOpen; ed.adding = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; icon: ed.snap ? "grid_on" : "grid_off"; primary: ed.snap; onClicked: Store.set("widgets.snap", !ed.snap) }
            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                visible: ed.snap
                width: 104; height: 38
                opts: [["20", "20 px"], ["30", "30 px"], ["40", "40 px"], ["60", "60 px"], ["80", "80 px"]]
                value: String(ed.grid)
                onPicked: v => Store.set("widgets.gridSize", Number(v))
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Distances"; icon: "straighten"; primary: ed.distances; onClicked: Store.set("widgets.distances", !ed.distances) }
            Button {
                id: resetB
                property bool armed: false
                anchors.verticalCenter: parent.verticalCenter
                text: armed ? "Sure?" : "Reset"; icon: "restart_alt"
                onClicked: { if (armed) { WidgetLayout.reset(ed.mode, ed.modelData.name); armed = false; } else { armed = true; disarm.restart(); } }
                Timer { id: disarm; interval: 4000; onTriggered: resetB.armed = false }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Done"; icon: "check"; primary: true; onClicked: ed.done() }
        }
    }
    Label {
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.bottom; anchors.topMargin: 8 + bar.height * (bar.scale - 1) / 2
        // wraps (centred) instead of running off the sides of a narrow screen
        width: Math.min(implicitWidth, ed.width - 48)
        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        text: (ed.lockMode && Quickshell.screens.length > 1 ? (WidgetLayout.lockPerScreen ? "The lock screen of " + ed.modelData.name + " only (the screen button above goes to the next)" : "Every screen shows this lock screen") + (WidgetLayout.passOn(ed.modelData.name) ? "" : "  ·  no password box here (Lock & idle → Password box on)") + "   ·   " : "") +
              (ed.list.length === 0 ? "Nothing here yet: Add widget" : "Drag to move (it lines up with the middle and the other widgets; Ctrl: freely)  ·  an edge or corner to resize  ·  ↻ turns it  ·  Esc when done")
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
        id: addStrip
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
                        onClicked: { ed.selected = WidgetLayout.add(ed.mode, modelData, ed.modelData.name, undefined, undefined, ed.height); ed.adding = false; }
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
                                    const p = mapToItem(addStrip, mouse.x, mouse.y);
                                    // dropped back on the strip: nothing
                                    if (!addStrip.contains(p)) {
                                        ed.selected = WidgetLayout.add(ed.mode, card.modelData, ed.modelData.name, ed.dragPos.x / ed.width, ed.dragPos.y / ed.height, ed.height);
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
