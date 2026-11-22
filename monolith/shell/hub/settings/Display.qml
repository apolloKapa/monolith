import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Displays: on/off, resolution, refresh rate and scale for each monitor, and (Hyprland) a screen
// mirroring another. Written into niri's output config (niri applies it straight away and keeps
// it), or on Hyprland into Monolith's monitors file.
ColumnLayout {
    id: sec
    spacing: 8
    property var outputs: []
    readonly property string hyprScript: Qt.resolvedUrl("../../scripts/hypr_monitors.py").toString().replace("file://", "")
    // a change to one screen: niri's output config, or on Hyprland Monolith's monitors file
    // (key: mode "WxH@R" / position "x=X y=Y" / scale / off / mirror: a screen's name or "")
    Process { id: hyprSet; onExited: requery.restart() }
    property var hyprQueue: []
    function put(o, key, value) {
        if (!Niri.hyprland) {
            if (key === "off") NiriConf.flag(block(o), "off", value);
            else if (key === "mode") NiriConf.set(block(o), "mode", NiriConf.quote(value));
            else NiriConf.set(block(o), key, value);
            return;
        }
        hyprQueue = hyprQueue.concat([["python3", hyprScript, "set", o.name, key, key === "off" ? (value ? "1" : "0") : String(value)]]);
        hyprNext();
    }
    function hyprNext() { if (hyprSet.running || !hyprQueue.length) return; hyprSet.command = hyprQueue[0]; hyprQueue = hyprQueue.slice(1); hyprSet.running = true; }
    Connections { target: hyprSet; function onRunningChanged() { if (!hyprSet.running) sec.hyprNext(); } }
    Process {
        id: query
        running: true
        // (Hyprland: its screens in niri's shape, scripts/hypr_monitors.py)
        command: Niri.hyprland ? ["python3", sec.hyprScript, "read"] : ["niri", "msg", "-j", "outputs"]
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
        desc: arr.dirty ? "Moved. Apply to keep it (" + (Niri.hyprland ? "Hyprland" : "niri") + " moves the screens at once)" : "Drag a screen: it snaps against the others, lined up with their edges or middles (no gaps, no overlaps)"
        // (only once something has moved: a faded Apply all the time looked broken)
        Row {
            spacing: 6
            visible: arr.dirty
            Button { text: "Reset"; onClicked: arr.reset() }
            Button { text: "Apply"; primary: true; onClicked: arr.apply() }
        }
    }
    SmoothRect {
        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
        id: arr
        Layout.fillWidth: true
        Layout.preferredHeight: 240
        radius: Theme.corner(80, 6)
        color: Theme.container
        clip: true

        // the screens that are on: { name, w, h } in logical pixels, and where each one is
        // (a screen mirroring another has no place of its own)
        readonly property var mons: sec.outputs.filter(o => o.logical && !o.mirror_of).map(o => ({ name: o.name, w: o.logical.width, h: o.logical.height, model: (o.make + " " + o.model).trim() }))
        property var pos: ({})          // name -> [x, y]
        property bool dirty: false
        // where the screen being dragged will land (preview pixels), shown as an outline: null
        // when nothing is being dragged
        property var ghost: null
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
            // [x, y, lined up?]: lined up = its top, bottom or middle level with the other's
            // (side by side), or its left, right or middle (stacked); otherwise anywhere along
            for (const o of others) {
                const [ox, oy] = pos[o.name];
                for (const cy of [oy, oy + o.h - h, oy + (o.h - h) / 2]) { cands.push([ox - w, cy, true]); cands.push([ox + o.w, cy, true]); }
                const fy = clamp(y, oy - h + share, oy + o.h - share);
                cands.push([ox - w, fy, false]); cands.push([ox + o.w, fy, false]);
                for (const cx of [ox, ox + o.w - w, ox + (o.w - w) / 2]) { cands.push([cx, oy - h, true]); cands.push([cx, oy + o.h, true]); }
                const fx = clamp(x, ox - w + share, ox + o.w - share);
                cands.push([fx, oy - h, false]); cands.push([fx, oy + o.h, false]);
            }
            const overlaps = (cx, cy) => others.some(o => { const [ox, oy] = pos[o.name]; return cx < ox + o.w - 0.5 && cx + w > ox + 0.5 && cy < oy + o.h - 0.5 && cy + h > oy + 0.5; });
            const ok = cands.filter(c => !overlaps(c[0], c[1]));
            let best = null, bd = 1e18;
            for (const c of ok) {
                const d = (c[0] - x) * (c[0] - x) + (c[1] - y) * (c[1] - y);
                if (d < bd) { bd = d; best = c; }
            }
            if (!best) return [x, y];
            // close to lined up (within about 8 % of the screen): lined up. It used to stay a
            // little off wherever it was let go, the screens' tops a few pixels apart
            if (!best[2]) {
                const reach = Math.max(60, 0.08 * Math.max(w, h));
                let snap = null, sd = 1e18;
                for (const c of ok) {
                    if (!c[2]) continue;
                    const d = Math.hypot(c[0] - best[0], c[1] - best[1]);
                    if (d < reach && d < sd) { sd = d; snap = c; }
                }
                if (snap) best = snap;
            }
            return [Math.round(best[0]), Math.round(best[1])];
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
            for (const m of mons) if (pos[m.name]) sec.put({ name: m.name }, "position", "x=" + Math.round(pos[m.name][0]) + " y=" + Math.round(pos[m.name][1]));
            dirty = false;
        }

        Repeater {
            model: arr.mons
            SmoothRect {
                smoothing: 0
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
                radius: Theme.rnd(8)
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
                // dragging: it follows the pointer, and snaps onto the nearest spot it can go
                // (against another screen, lined up with its edge or middle) once that's within
                // reach; the outline shows where it lands. Let go: it settles there
                DragHandler {
                    id: drag
                    target: null
                    property point start: Qt.point(0, 0)
                    readonly property real reach: 26      // preview pixels
                    onActiveChanged: {
                        if (active) { start = Qt.point(mon.x, mon.y); mon.x = start.x; mon.y = start.y; return; }
                        arr.ghost = null;
                        arr.moved(mon.modelData.name, mon.x / arr.box.s + arr.box.x0, mon.y / arr.box.s + arr.box.y0);
                        mon.place();
                    }
                    onTranslationChanged: {
                        if (!active) return;
                        const b = arr.box;
                        const rx = start.x + translation.x, ry = start.y + translation.y;
                        const sn = arr.settle(mon.modelData.name, rx / b.s + b.x0, ry / b.s + b.y0);
                        const sx = (sn[0] - b.x0) * b.s, sy = (sn[1] - b.y0) * b.s;
                        const near = Math.hypot(sx - rx, sy - ry) < reach;
                        mon.x = near ? sx : rx;
                        mon.y = near ? sy : ry;
                        arr.ghost = { x: sx, y: sy, w: mon.width, h: mon.height, on: near };
                    }
                }
            }
        }
        // where the dragged screen lands
        SmoothRect {
            smoothing: 0
            visible: !!arr.ghost
            z: 0.5
            x: arr.ghost ? arr.ghost.x : 0
            y: arr.ghost ? arr.ghost.y : 0
            width: arr.ghost ? arr.ghost.w : 0
            height: arr.ghost ? arr.ghost.h : 0
            radius: Theme.rnd(8)
            color: Qt.alpha(Theme.accent, arr.ghost && arr.ghost.on ? 0.16 : 0.08)
            border.width: 2
            border.color: Qt.alpha(Theme.accent, arr.ghost && arr.ghost.on ? 0.9 : 0.45)
        }
        Label { visible: arr.mons.length === 0; anchors.centerIn: parent; text: "No screens found"; muted: true }
    }

    // which display's settings show below
    property string picked: ""
    readonly property string shownName: sec.outputs.some(o => o.name === picked) ? picked : (sec.outputs.length ? (sec.outputs.find(o => o.name === Niri.focusedOutput) || sec.outputs[0]).name : "")
    SettingRow {
        show: sec.outputs.length > 0
        icon: "desktop_windows"; title: "Display"; desc: "The screen to set up"
        Dropdown {
            width: 300; height: 36
            opts: sec.outputs.map(o => [o.name, o.name + "  ·  " + (o.make + " " + o.model).trim()])
            value: sec.shownName
            onPicked: v => sec.picked = v
        }
    }

    Repeater {
        model: sec.outputs
        SmoothRect {
            smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
            id: card
            visible: modelData.name === sec.shownName
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
                    desc: card.on && card.o.mirror_of ? "Showing the same as " + card.o.mirror_of : card.on ? card.cur.width + " × " + card.cur.height + " at " + Math.round(card.cur.refresh_rate / 1000) + " Hz, scale " + (card.o.logical ? card.o.logical.scale : 1) : "Off"
                    Toggle {
                        checked: card.on
                        // never the last screen that's on
                        onToggled: on => { if (on || sec.onCount() > 1) sec.put(card.o, "off", !on); }
                    }
                }
                // every size and rate the screen offers
                SettingRow {
                    show: card.on
                    icon: "aspect_ratio"; title: "Resolution"
                    Dropdown {
                        width: 200; height: 36
                        opts: card.sizes.map(s => [s, s.replace("x", " × ")])
                        value: card.cur ? card.cur.width + "x" + card.cur.height : ""
                        onPicked: v => {
                            const best = card.o.modes.filter(m => m.width + "x" + m.height === v).sort((a, b) => b.refresh_rate - a.refresh_rate)[0];
                            if (best) sec.put(card.o, "mode", sec.modeStr(best));
                        }
                    }
                }
                SettingRow {
                    show: card.on && card.rates.length > 1
                    icon: "speed"; title: "Refresh rate"
                    Dropdown {
                        width: 200; height: 36
                        opts: card.rates.map(m => [String(m.refresh_rate), Math.round(m.refresh_rate / 1000) + " Hz"])
                        value: card.cur ? String(card.cur.refresh_rate) : ""
                        onPicked: v => {
                            const m = card.rates.find(r => String(r.refresh_rate) === v);
                            if (m) sec.put(card.o, "mode", sec.modeStr(m));
                        }
                    }
                }
                SettingRow {
                    show: card.on
                    icon: "zoom_in"; title: "Scale"; desc: "Bigger text and controls on this screen"
                    // any scale, in 5% steps (niri rounds it to what the screen can show sharply)
                    NumberBox {
                        from: 0.5; to: 4; slideTo: 2.5; step: 0.05; decimals: 2; factor: 100; unit: "%"
                        value: card.o.logical ? card.o.logical.scale : 1
                        onMoved: v => scaleLater.go(v)
                        Timer { id: scaleLater; property real v: 1; interval: 700; function go(x) { v = x; restart(); } onTriggered: sec.put(card.o, "scale", v.toFixed(2)) }
                    }
                }
                // HDMI scaling (a TV cutting off the edges): the GPU's underscan, which neither
                // Hyprland nor niri lets anything set on Linux, so this says where it's fixed
                SettingRow {
                    show: card.on && /^HDMI/.test(card.o.name)
                    icon: "fit_screen"; title: "HDMI scaling"
                    desc: "Edges cut off on a TV? The TV is zooming in (overscan), and on Linux only the TV can turn that off (Hyprland and niri can't shrink the picture the way Windows' HDMI scaling does). On the TV: Samsung, Picture Size → Fit to Screen (or 16:9 and Screen Fit); LG, Just Scan; Sony, Display Area → Full Pixel. Renaming the TV's input to \"PC\" also stops it on many TVs."
                }
                // the same picture as another screen (a TV or projector beside your monitor)
                SettingRow {
                    id: mirrorRow
                    readonly property var others: sec.outputs.filter(x => x.name !== card.o.name && x.current_mode !== null && !x.mirror_of)
                    show: others.length > 0 || !!card.o.mirror_of
                    icon: "screen_share"; title: "Mirror"
                    desc: !Niri.hyprland ? "niri can't mirror screens yet" : card.o.mirror_of ? "Shows the same as " + card.o.mirror_of + " (turns on with it)" : "Show the same picture as another screen, say on a TV or projector"
                    Dropdown {
                        visible: Niri.hyprland
                        width: 230; height: 36
                        opts: [["", "Off (its own screen)"]].concat(mirrorRow.others.map(x => [x.name, "Same as " + x.name]))
                        value: card.o.mirror_of || ""
                        onPicked: v => sec.put(card.o, "mirror", v)
                    }
                }
            }
        }
    }
}
