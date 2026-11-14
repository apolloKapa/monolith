import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Animations: how fast things move. The shell's own (menus, the bar, pop-ups), then niri's:
// all of them on or off, their overall speed, a few ready-made sets, and each one on its own
// (a spring: how fast and how bouncy; a timed one: how long and its curve). niri's part is
// written to niri's config, which niri applies at once; "niri's own" removes the line, so niri's
// default is used.
ColumnLayout {
    id: sec
    spacing: 8

    // niri's animations: [config name, title, what it is, niri's default]
    readonly property var kinds: [
        ["window-open", "Window opening", "A new window appearing", "{ duration-ms 150; curve \"ease-out-expo\"; }"],
        ["window-close", "Window closing", "A window going away", "{ duration-ms 150; curve \"ease-out-quad\"; }"],
        ["window-movement", "Windows moving", "Windows sliding to their new places (one closed, moved or added)", "{ spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }"],
        ["window-resize", "Window resizing", "A window growing or shrinking", "{ spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }"],
        ["horizontal-view-movement", "Scrolling the windows", "The row of windows sliding left and right", "{ spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }"],
        ["workspace-switch", "Switching workspaces", "Going up or down to another workspace", "{ spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001; }"],
        ["overview-open-close", "Overview", "The overview zooming out and back in", "{ spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }"],
        ["recent-windows-close", "Recent windows switcher", "niri's window switcher closing", "{ spring damping-ratio=1.0 stiffness=800 epsilon=0.001; }"],
        ["screenshot-ui-open", "niri's screenshot screen", "niri's own screenshot tool opening", "{ duration-ms 200; curve \"ease-out-quad\"; }"],
        ["config-notification-open-close", "Config notice", "The note niri shows when its config has an error", "{ spring damping-ratio=0.6 stiffness=1000 epsilon=0.001; }"],
        ["exit-confirmation-open-close", "Quit dialog", "niri's \"really quit?\" dialog", "{ spring damping-ratio=0.6 stiffness=500 epsilon=0.01; }"]
    ]
    // ready-made sets: one value per animation (null: niri's own)
    function spring(d, s, e) { return "{ spring damping-ratio=" + d + " stiffness=" + s + " epsilon=" + (e || 0.0001) + "; }"; }
    function timed(ms, curve) { return "{ duration-ms " + ms + "; curve \"" + curve + "\"; }"; }
    readonly property var presets: ({
        monolith: { "window-open": timed(180, "ease-out-expo"), "window-close": timed(140, "ease-out-quad"), "window-movement": spring("1.0", 800), "window-resize": spring("1.0", 800), "horizontal-view-movement": spring("1.0", 800), "workspace-switch": spring("1.0", 800), "overview-open-close": spring("1.0", 800), "screenshot-ui-open": timed(200, "ease-out-quad"), "config-notification-open-close": spring("0.6", 1000, 0.001), "exit-confirmation-open-close": spring("0.6", 500, 0.01) },
        snappy: { "window-open": timed(110, "ease-out-expo"), "window-close": timed(90, "ease-out-quad"), "window-movement": spring("1.0", 1500), "window-resize": spring("1.0", 1500), "horizontal-view-movement": spring("1.0", 1500), "workspace-switch": spring("1.0", 1600), "overview-open-close": spring("1.0", 1500), "recent-windows-close": spring("1.0", 1500, 0.001), "screenshot-ui-open": timed(120, "ease-out-quad"), "config-notification-open-close": spring("0.8", 1600, 0.001), "exit-confirmation-open-close": spring("0.8", 900, 0.01) },
        smooth: { "window-open": timed(300, "ease-out-expo"), "window-close": timed(220, "ease-out-cubic"), "window-movement": spring("1.0", 450), "window-resize": spring("1.0", 450), "horizontal-view-movement": spring("1.0", 450), "workspace-switch": spring("1.0", 500), "overview-open-close": spring("1.0", 450), "recent-windows-close": spring("1.0", 450, 0.001), "screenshot-ui-open": timed(280, "ease-out-cubic"), "config-notification-open-close": spring("0.7", 700, 0.001), "exit-confirmation-open-close": spring("0.7", 400, 0.01) },
        bouncy: { "window-open": timed(260, "ease-out-expo"), "window-close": timed(150, "ease-out-quad"), "window-movement": spring("0.65", 700), "window-resize": spring("0.7", 700), "horizontal-view-movement": spring("0.7", 700), "workspace-switch": spring("0.75", 700), "overview-open-close": spring("0.75", 700), "recent-windows-close": spring("0.75", 700, 0.001), "screenshot-ui-open": timed(220, "ease-out-expo"), "config-notification-open-close": spring("0.5", 900, 0.001), "exit-confirmation-open-close": spring("0.5", 500, 0.01) },
        niri: {}
    })

    // what niri's config says now: { "animations|<name>": value or null }
    property var v: ({})
    function reload() { NiriConf.read(["animations|off", "animations|slowdown"].concat(kinds.map(k => "animations|" + k[0])), r => sec.v = r); }
    Component.onCompleted: reload()
    function has(k) { return v[k] !== null && v[k] !== undefined; }

    // one animation's value, read: { mode: "default" | "spring" | "timed" | "off", damping,
    // stiffness, epsilon, ms, curve } (unset: niri's default values, mode "default")
    function parse(name, def) {
        const raw = has("animations|" + name) ? String(v["animations|" + name]) : def;
        const o = { mode: has("animations|" + name) ? "" : "default", damping: 1, stiffness: 800, epsilon: 0.0001, ms: 150, curve: "ease-out-quad" };
        if (/\boff\b/.test(raw)) { if (!o.mode) o.mode = "off"; return o; }
        const sp = raw.match(/spring([^;}]*)/);
        if (sp) {
            if (!o.mode) o.mode = "spring";
            const d = sp[1].match(/damping-ratio=([\d.]+)/), s = sp[1].match(/stiffness=([\d.]+)/), e = sp[1].match(/epsilon=([\d.]+)/);
            if (d) o.damping = Number(d[1]);
            if (s) o.stiffness = Number(s[1]);
            if (e) o.epsilon = Number(e[1]);
            return o;
        }
        if (!o.mode) o.mode = "timed";
        const ms = raw.match(/duration-ms\s+(\d+)/), c = raw.match(/curve\s+"([^"]+)"/);
        if (ms) o.ms = Number(ms[1]);
        if (c) o.curve = c[1];
        return o;
    }
    function write(name, o) {
        const val = o.mode === "off" ? "{ off; }"
            : o.mode === "spring" ? spring(o.damping.toFixed(2), Math.round(o.stiffness), o.epsilon)
            : timed(Math.round(o.ms), o.curve);
        put(name, val);
    }
    // sliders write once, a moment after the last move
    property var pending: ({})
    function put(name, val) {
        const c = Object.assign({}, v); c["animations|" + name] = val; v = c;
        const p = Object.assign({}, pending); p[name] = val; pending = p;
        flush.restart();
    }
    Timer {
        id: flush; interval: 350
        onTriggered: {
            for (const n in sec.pending) {
                if (sec.pending[n] === null) NiriConf.unset("animations", n);
                else NiriConf.set("animations", n, sec.pending[n]);
            }
            sec.pending = {};
        }
    }
    function applyPreset(id) {
        const p = presets[id];
        for (const k of kinds) put(k[0], p[k[0]] !== undefined ? p[k[0]] : null);
    }
    // which ready-made set matches the config now ("" if none: changed by hand)
    readonly property string currentPreset: {
        for (const id in presets) {
            const p = presets[id];
            if (kinds.every(k => {
                const want = p[k[0]] !== undefined ? p[k[0]] : null;
                const have = has("animations|" + k[0]) ? String(v["animations|" + k[0]]) : null;
                return want === null ? have === null : have !== null && have.replace(/\s+/g, " ") === want;
            })) return id;
        }
        return "";
    }

    // ── the shell ──
    SectionHead { text: "The shell (menus, the bar, pop-ups)" }
    // live preview: a pill gliding across a track and back at the shell's speed, with the same
    // timings (Theme.ms) and curves the menus use, so it shows how fast they'll feel. It changes
    // as soon as the speed does; with animations off it sits still in the middle
    SmoothRect {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: Theme.corner(72, 6)
        color: Theme.container
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        readonly property real pad: Theme.inset(radius, 12)
        readonly property real farX: width - pill.width - pad
        SmoothRect {
            id: groove
            x: track.pad; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * track.pad; height: 6
            radius: 3
            color: Theme.control
        }
        // the trail: the part of the groove the pill has covered
        SmoothRect {
            x: track.pad; anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, pill.x + pill.width / 2 - track.pad); height: 6
            radius: 3
            color: Qt.alpha(Theme.accent, 0.35)
            visible: Theme.animOn
        }
        SmoothRect {
            id: pill
            width: 104; height: 44
            anchors.verticalCenter: parent.verticalCenter
            x: track.pad
            radius: Theme.corner(height)
            color: Theme.accent
            Label {
                anchors.centerIn: parent
                text: Theme.animOn ? Number(Store.get("theme.animSpeed", 1)).toFixed(2) + " ×" : "off"
                color: Theme.onAccent; strong: true
            }
        }
        // off: still, in the middle
        states: State {
            when: !Theme.animOn
            PropertyChanges { target: pill; x: (track.width - pill.width) / 2; scale: 1 }
        }
        SequentialAnimation {
            id: glide
            running: Theme.animOn && track.visible && track.width > 0
            loops: Animation.Infinite
            onRunningChanged: if (!running) { pill.scale = 1; if (Theme.animOn) pill.x = track.pad; }
            // across, the way a menu comes in (emphasized, decelerating)
            NumberAnimation { target: pill; property: "x"; to: track.farX; duration: Theme.ms(700); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
            // a little bounce on arrival (the island's spring)
            NumberAnimation { target: pill; property: "scale"; to: 1.1; duration: Theme.ms(120); easing.type: Easing.OutQuad }
            NumberAnimation { target: pill; property: "scale"; to: 1; duration: Theme.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            PauseAnimation { duration: 450 }
            // and back
            NumberAnimation { target: pill; property: "x"; to: track.pad; duration: Theme.ms(700); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
            NumberAnimation { target: pill; property: "scale"; to: 1.1; duration: Theme.ms(120); easing.type: Easing.OutQuad }
            NumberAnimation { target: pill; property: "scale"; to: 1; duration: Theme.ms(320); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            PauseAnimation { duration: 450 }
        }
        // a new speed starts it over at once (instead of finishing the old, slower lap first)
        Connections {
            target: Theme
            function onAnimScaleChanged() { if (glide.running) { glide.stop(); pill.x = track.pad; pill.scale = 1; glide.start(); } }
        }
    }
    SettingRow {
        key: "theme.animations";
        icon: "animation"; title: "Animations"; desc: "Off: the bar, menus and pop-ups appear at once, with no movement"
        Toggle { checked: Theme.animOn; onToggled: on => Store.set("theme.animations", on) }
    }
    SettingRow {
        key: "theme.animSpeed"; def: 1;
        visible: Theme.animOn
        icon: "speed"; title: "Speed"
        desc: { const v = Number(Store.get("theme.animSpeed", 1)); return v === 1 ? "1 × is normal. Higher is faster, lower is slower" : (v > 1 ? "Animations take " + (Math.round(100 / v) / 100) + " × as long as normal (faster)" : "Animations take " + (Math.round(100 / v) / 100) + " × as long as normal (slower)"); }
        NumberBox { from: 0.25; to: 3; step: 0.05; decimals: 2; unit: "×"; value: Number(Store.get("theme.animSpeed", 1)); onMoved: v => Store.set("theme.animSpeed", v) }
    }
    SettingRow {
        key: "theme.effects.unfold"; def: false;
        visible: Theme.animOn
        icon: Theme.fxUnfold ? "unfold_more" : "zoom_out_map"; title: "How menus open"
        desc: Theme.fxUnfold ? "Unfold: a menu opens out of a thin bright line through its middle, and folds back into it" : "Zoom: a menu fades in while growing a little, and shrinks away"
        Segmented { width: 220; opts: [["zoom", "Zoom"], ["unfold", "Unfold"]]; value: Theme.fxUnfold ? "unfold" : "zoom"; onPicked: v => Store.set("theme.effects.unfold", v === "unfold") }
    }

    // ── niri ──
    SectionHead { text: "Windows (niri)"; visible: !Niri.hyprland }
    Label { visible: Niri.hyprland; Layout.fillWidth: true; wrapMode: Text.Wrap; text: "On Hyprland, switching workspaces is in the next tab (Workspace switching); other window animations are in your Hyprland config (hyprland.lua or hyprland.conf)."; muted: true; Layout.leftMargin: 6 }
    SettingRow {
        visible: !Niri.hyprland
        icon: "animation"; title: "Window animations"; desc: "Off: windows, workspaces and the overview move at once"
        Toggle { checked: !sec.has("animations|off"); onToggled: on => { const c = Object.assign({}, sec.v); c["animations|off"] = on ? null : ""; sec.v = c; NiriConf.flag("animations", "off", !on); } }
    }
    SettingRow {
        visible: !Niri.hyprland && !sec.has("animations|off")
        icon: "speed"; title: "Overall speed"
        desc: "Every window animation at once (niri's slowdown is 1 ÷ this). Each one's own speed is below"
        // shown as a speed (higher is faster); niri's slowdown is its inverse
        NumberBox {
            from: 0.1; to: 10; slideTo: 5; step: 0.05; decimals: 2; unit: "×"
            value: { const s = parseFloat(sec.v["animations|slowdown"]); return isNaN(s) || s <= 0 ? 1 : Math.round(100 / s) / 100; }
            onMoved: x => {
                const c = Object.assign({}, sec.v); c["animations|slowdown"] = String(1 / x); sec.v = c;
                slowLater.value = (1 / x).toFixed(3); slowLater.restart();
            }
            Timer { id: slowLater; property string value: "1"; interval: 350; onTriggered: NiriConf.set("animations", "slowdown", value) }
        }
    }
    SettingRow {
        visible: !Niri.hyprland && !sec.has("animations|off")
        icon: "auto_awesome"; title: "Ready-made sets"
        desc: sec.currentPreset === "" ? "Yours: changed one by one below" : ({ monolith: "Monolith's: quick and calm", snappy: "Snappy: short and fast", smooth: "Smooth: slower and gliding", bouncy: "Bouncy: things overshoot a little and settle", niri: "niri's own defaults" })[sec.currentPreset]
        Segmented {
            width: 400
            opts: [["monolith", "Monolith"], ["snappy", "Snappy"], ["smooth", "Smooth"], ["bouncy", "Bouncy"], ["niri", "niri"]]
            value: sec.currentPreset
            onPicked: id => sec.applyPreset(id)
        }
    }

    Repeater {
        model: !Niri.hyprland && !sec.has("animations|off") ? sec.kinds : []
        Rectangle {
            id: card
            required property var modelData
            readonly property string name: modelData[0]
            readonly property var a: sec.parse(name, modelData[3])
            // a change to one part: the rest as it is (from niri's default when it was unset)
            function change(k, val) {
                const o = Object.assign({}, a);
                if (o.mode === "default") o.mode = /spring/.test(modelData[3]) ? "spring" : "timed";
                o[k] = val;
                sec.write(name, o);
            }
            Layout.fillWidth: true
            implicitHeight: col.implicitHeight + 24
            radius: Theme.corner(80, 6)
            color: Theme.container
            Rise {}
            ColumnLayout {
                id: col
                x: 16; y: 12
                width: parent.width - 32
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { text: card.modelData[1]; strong: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Label { text: card.modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    }
                    Segmented {
                        Layout.preferredWidth: 340; Layout.preferredHeight: 40
                        opts: [["default", "niri's own"], ["spring", "Spring"], ["timed", "Timed"], ["off", "Off"]]
                        value: card.a.mode
                        onPicked: m => {
                            if (m === "default") { sec.put(card.name, null); return; }
                            const o = Object.assign({}, card.a); o.mode = m;
                            sec.write(card.name, o);
                        }
                    }
                }
                // a spring: how fast it gets there, and how much it overshoots
                RowLayout {
                    visible: card.a.mode === "spring" || (card.a.mode === "default" && /spring/.test(card.modelData[3]))
                    enabled: card.a.mode !== "default"
                    opacity: enabled ? 1 : 0.5
                    Layout.fillWidth: true
                    spacing: 12
                    Label { text: "Speed"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.preferredWidth: 60 }
                    NumberBox { Layout.fillWidth: true; from: 50; to: 5000; slideTo: 2500; step: 10; value: card.a.stiffness; onMoved: x => card.change("stiffness", x) }
                    Label { text: "Bounce"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.preferredWidth: 60 }
                    // (niri's damping ratio: 1 = none, lower overshoots more)
                    NumberBox { Layout.fillWidth: true; from: 0; to: 90; step: 1; unit: "%"; value: Math.round((1 - card.a.damping) * 100); onMoved: x => card.change("damping", 1 - x / 100) }
                }
                // a timed one: how long, and how it eases
                RowLayout {
                    visible: card.a.mode === "timed" || (card.a.mode === "default" && !/spring/.test(card.modelData[3]))
                    enabled: card.a.mode !== "default"
                    opacity: enabled ? 1 : 0.5
                    Layout.fillWidth: true
                    spacing: 12
                    Label { text: "Length"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.preferredWidth: 60 }
                    NumberBox { Layout.fillWidth: true; from: 10; to: 3000; slideTo: 1000; step: 10; unit: "ms"; value: card.a.ms; onMoved: x => card.change("ms", x) }
                    Label { text: "Curve"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.preferredWidth: 60 }
                    Dropdown {
                        Layout.preferredWidth: 220; Layout.preferredHeight: 36
                        opts: [["ease-out-expo", "Fast, then gentle"], ["ease-out-cubic", "Smooth"], ["ease-out-quad", "Soft"], ["linear", "Even"]]
                        value: card.a.curve
                        onPicked: c => card.change("curve", c)
                    }
                }
            }
        }
    }
}
