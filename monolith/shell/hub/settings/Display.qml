import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Displays: on/off, resolution, refresh rate and scale for each monitor. Written into niri's
// output config (niri applies it straight away and keeps it).
ColumnLayout {
    id: sec
    spacing: 8
    property var outputs: []

    Process {
        id: query
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    sec.outputs = Object.keys(d).sort().map(k => d[k]);
                } catch (e) {}
            }
        }
    }
    Timer { id: requery; interval: 1200; onTriggered: query.running = true }
    Connections { target: NiriConf; function onChanged() { requery.restart(); } }

    function block(o) { return "output " + NiriConf.quote(o.name); }
    function modeStr(m) { return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3); }
    function onCount() { return outputs.filter(o => o.current_mode !== null).length; }

    Label { visible: sec.outputs.length === 0; text: "Looking for displays…"; muted: true }

    // ── arrangement: the screens that are on, drawn where they sit; drag one to move it ──
    SettingRow {
        icon: "drag_pan"; title: "Arrangement"
        desc: arr.dirty ? "Moved. Apply to keep it (niri moves the screens at once)" : "Drag a screen; it settles against the others (no gaps, no overlaps)"
        Row {
            spacing: 6
            Button { visible: arr.dirty; text: "Reset"; onClicked: arr.reset() }
            Button { text: "Apply"; primary: true; enabledInput: arr.dirty; opacity: arr.dirty ? 1 : 0.5; onClicked: arr.apply() }
        }
    }
    Rectangle {
        id: arr
        Layout.fillWidth: true
        Layout.preferredHeight: 240
        radius: Theme.corner(80, 6)
        color: Theme.container
        clip: true

        // the screens that are on: { name, w, h } in logical pixels, and where each one is
        readonly property var mons: sec.outputs.filter(o => o.logical).map(o => ({ name: o.name, w: o.logical.width, h: o.logical.height, model: (o.make + " " + o.model).trim() }))
        property var pos: ({})          // name -> [x, y]
        property bool dirty: false
        function reset() {
            const p = {};
            for (const o of sec.outputs) if (o.logical) p[o.name] = [o.logical.x, o.logical.y];
            pos = p; dirty = false;
        }
        Connections { target: sec; function onOutputsChanged() { if (!arr.dirty) arr.reset(); } }

        // the preview's scale and offset: everything fits with a margin
        readonly property var box: {
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
            for (const m of mons) { const p = pos[m.name]; if (!p) continue; x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0] + m.w); y1 = Math.max(y1, p[1] + m.h); }
            if (x0 > x1) return { x0: 0, y0: 0, s: 0.1 };
            const s = Math.min((width - 60) / (x1 - x0), (height - 40) / (y1 - y0));
            return { x0: x0 - ((width - (x1 - x0) * s) / 2) / s, y0: y0 - ((height - (y1 - y0) * s) / 2) / s, s: s };
        }

        // where `name` (w × h) can go near (x, y): touching another screen along at least 200 px
        // of edge, overlapping none; the closest such spot
        function settle(name, x, y) {
            const me = mons.find(m => m.name === name);
            const others = mons.filter(m => m.name !== name && pos[m.name]);
            if (!me || others.length === 0) return [x, y];
            const w = me.w, h = me.h, share = 200;
            const cands = [];
            const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
            for (const o of others) {
                const [ox, oy] = pos[o.name];
                for (const cy of [oy, oy + o.h - h, oy + (o.h - h) / 2, clamp(y, oy - h + share, oy + o.h - share)]) {
                    cands.push([ox - w, cy]); cands.push([ox + o.w, cy]);
                }
                for (const cx of [ox, ox + o.w - w, ox + (o.w - w) / 2, clamp(x, ox - w + share, ox + o.w - share)]) {
                    cands.push([cx, oy - h]); cands.push([cx, oy + o.h]);
                }
            }
            const overlaps = (cx, cy) => others.some(o => { const [ox, oy] = pos[o.name]; return cx < ox + o.w - 0.5 && cx + w > ox + 0.5 && cy < oy + o.h - 0.5 && cy + h > oy + 0.5; });
            let best = [x, y], bd = 1e18;
            for (const [cx, cy] of cands) {
                if (overlaps(cx, cy)) continue;
                const d = (cx - x) * (cx - x) + (cy - y) * (cy - y);
                if (d < bd) { bd = d; best = [Math.round(cx), Math.round(cy)]; }
            }
            return best;
        }
        function moved(name, x, y) {
            const p = Object.assign({}, pos);
            p[name] = settle(name, x, y);
            // the top-left screen at 0,0
            const minX = Math.min(...Object.values(p).map(v => v[0])), minY = Math.min(...Object.values(p).map(v => v[1]));
            for (const k in p) p[k] = [p[k][0] - minX, p[k][1] - minY];
            pos = p; dirty = true;
        }
        function apply() {
            for (const m of mons) if (pos[m.name]) NiriConf.set("output " + NiriConf.quote(m.name), "position", "x=" + Math.round(pos[m.name][0]) + " y=" + Math.round(pos[m.name][1]));
            dirty = false;
        }

        Repeater {
            model: arr.mons
            Rectangle {
                id: mon
                required property var modelData
                readonly property var p: arr.pos[modelData.name] || [0, 0]
                readonly property bool dragging: drag.active
                function place() {
                    x = Qt.binding(() => (mon.p[0] - arr.box.x0) * arr.box.s);
                    y = Qt.binding(() => (mon.p[1] - arr.box.y0) * arr.box.s);
                }
                Component.onCompleted: place()
                width: modelData.w * arr.box.s
                height: modelData.h * arr.box.s
                radius: 8
                color: dragging ? Theme.accentContainer : Theme.containerHigh
                border.width: 2
                border.color: dragging ? Theme.accent : Theme.ringTrack
                z: dragging ? 2 : 1
                Behavior on x { enabled: !mon.dragging; NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                Behavior on y { enabled: !mon.dragging; NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: mon.modelData.name; strong: true }
                    Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: mon.modelData.w + " × " + mon.modelData.h; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: mon.modelData.model; muted: true; font.pixelSize: Theme.sizeSmall - 2; visible: parent.parent.height > 70 }
                }
                DragHandler {
                    id: drag
                    target: mon
                    // the drag sets x/y itself; on release the screen settles and follows the layout again
                    onActiveChanged: if (!active) { arr.moved(mon.modelData.name, mon.x / arr.box.s + arr.box.x0, mon.y / arr.box.s + arr.box.y0); mon.place(); }
                }
            }
        }
        Label { visible: arr.mons.length === 0; anchors.centerIn: parent; text: "No screens found"; muted: true }
    }

    Repeater {
        model: sec.outputs
        Rectangle {
            id: card
            required property var modelData
            readonly property var o: modelData
            readonly property bool on: o.current_mode !== null
            readonly property var cur: on ? o.modes[o.current_mode] : null
            // the resolutions (largest first) and the rates at the current one
            readonly property var sizes: {
                const seen = {}, out = [];
                for (const m of o.modes) { const k = m.width + "x" + m.height; if (!seen[k]) { seen[k] = 1; out.push(k); } }
                return out.sort((a, b) => Number(b.split("x")[0]) * Number(b.split("x")[1]) - Number(a.split("x")[0]) * Number(a.split("x")[1]));
            }
            // the rates at the current size, one per whole Hz (119.88 and 120 are both "120 Hz")
            readonly property var rates: {
                if (!cur) return [];
                const seen = {}, out = [];
                for (const m of o.modes.filter(m => m.width === cur.width && m.height === cur.height).sort((a, b) => b.refresh_rate - a.refresh_rate)) {
                    const hz = Math.round(m.refresh_rate / 1000);
                    if (seen[hz]) continue;
                    seen[hz] = true;
                    out.push(m);
                }
                // the current one is always there
                if (!out.some(m => m.refresh_rate === cur.refresh_rate)) out[out.findIndex(m => Math.round(m.refresh_rate / 1000) === Math.round(cur.refresh_rate / 1000))] = cur;
                return out;
            }
            Layout.fillWidth: true
            implicitHeight: col.implicitHeight + 24
            radius: Theme.corner(80, 8)
            color: Theme.container

            ColumnLayout {
                id: col
                x: 12; y: 12
                width: parent.width - 24
                spacing: 8
                SettingRow {
                    icon: "monitor"; title: card.o.name + "  ·  " + (card.o.make + " " + card.o.model).trim()
                    desc: card.on ? card.cur.width + " × " + card.cur.height + " at " + Math.round(card.cur.refresh_rate / 1000) + " Hz, scale " + (card.o.logical ? card.o.logical.scale : 1) : "Off"
                    Toggle {
                        checked: card.on
                        // never the last screen that's on
                        onToggled: on => { if (on || sec.onCount() > 1) NiriConf.flag(sec.block(card.o), "off", !on); }
                    }
                }
                // every size and rate the screen offers
                SettingRow { visible: card.on; icon: "aspect_ratio"; title: "Resolution" }
                ChipFlow {
                        visible: card.on
                        opts: card.sizes.map(s => [s, s.replace("x", " × ")])
                        value: card.cur ? card.cur.width + "x" + card.cur.height : ""
                        onPicked: v => {
                            const best = card.o.modes.filter(m => m.width + "x" + m.height === v).sort((a, b) => b.refresh_rate - a.refresh_rate)[0];
                            if (best) NiriConf.set(sec.block(card.o), "mode", NiriConf.quote(sec.modeStr(best)));
                        }
                }
                SettingRow { visible: card.on && card.rates.length > 1; icon: "speed"; title: "Refresh rate" }
                ChipFlow {
                        visible: card.on && card.rates.length > 1
                        opts: card.rates.map(m => [String(m.refresh_rate), Math.round(m.refresh_rate / 1000) + " Hz"])
                        value: card.cur ? String(card.cur.refresh_rate) : ""
                        onPicked: v => {
                            const m = card.rates.find(r => String(r.refresh_rate) === v);
                            if (m) NiriConf.set(sec.block(card.o), "mode", NiriConf.quote(sec.modeStr(m)));
                        }
                }
                SettingRow {
                    visible: card.on
                    icon: "zoom_in"; title: "Scale"; desc: "Bigger text and controls on this screen"
                    // any scale, in 5% steps (niri rounds it to what the screen can show sharply)
                    NumberBox {
                        from: 0.5; to: 4; slideTo: 2.5; step: 0.05; decimals: 2; factor: 100; unit: "%"
                        value: card.o.logical ? card.o.logical.scale : 1
                        onMoved: v => scaleLater.go(v)
                        Timer { id: scaleLater; property real v: 1; interval: 700; function go(x) { v = x; restart(); } onTriggered: NiriConf.set(sec.block(card.o), "scale", v.toFixed(2)) }
                    }
                }
            }
        }
    }
}
