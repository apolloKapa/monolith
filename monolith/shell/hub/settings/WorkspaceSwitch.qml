import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Animations → Workspace switching: how workspaces move when you switch (the style), how it feels
// and how fast, with a little preview that plays it. Hyprland: Monolith's animations file
// (scripts/hypr_anims.py: every style). niri: its workspace-switch animation (niri only slides
// up and down), or off with Monolith's fade over it (island/WorkspaceFade). Glitch, on both:
// the switch is instant and Monolith tears the wallpaper away over it with the Cyberpunk glitch.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/hypr_anims.py").toString().replace("file://", "")
    readonly property var dflt: ({ style: "slidevert", feel: "smooth", speed: "normal" })
    property var s: Object.assign({}, dflt, Store.get("animations.workspaceSwitch", {}) || {})
    // the same numbers the compositor gets (hypr_anims.py)
    readonly property var stiffness: ({ relaxed: 450, normal: 900, fast: 1500, fastest: 2500 })
    readonly property var ratio: ({ smooth: 1.0, bouncy: 0.6 })
    readonly property var styles: Niri.hyprland
        ? [["slidevert", "Slide up and down"], ["slide", "Slide sideways"], ["slidefadevert", "Slide and fade"], ["fade", "Fade"], ["glitch", "Glitch"], ["off", "Off"]]
        : [["slidevert", "Slide up and down"], ["fade", "Fade"], ["glitch", "Glitch"], ["off", "Off"]]

    // Hyprland: what its file says (it may have been set before this page existed)
    Process {
        id: reader
        running: Niri.hyprland
        command: ["python3", sec.script, "read"]
        stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (r.style) sec.s = Object.assign({}, sec.dflt, r); } catch (e) {} } }
    }
    function put(key, v) {
        const c = Object.assign({}, s); c[key] = v; s = c;
        Store.set("animations.workspaceSwitch", c);
        save.restart();
    }
    // written a moment after the last change (the compositor reloads on every save)
    Timer {
        id: save; interval: 300
        onTriggered: Look.applyWorkspaceSwitch(sec.s)
    }

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: "How workspaces move when you switch between them. The preview plays it."
            + (Niri.hyprland ? "" : " niri itself only slides workspaces up and down; Fade is drawn by Monolith (the new workspace fades in over your wallpaper). niri's other animations are in Animation speeds.")
            + " Glitch: the switch is instant and a neon line sweeps down the screen, wiping your wallpaper away over it with a torn edge (the Cyberpunk style picks it)."
    }

    // ── the preview: two little workspaces, switching back and forth with the same spring ──
    SmoothRect {
        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
        id: stage
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        radius: Theme.corner(60, 10)
        color: Theme.m("surface_container_lowest", "#101014")
        border.width: 1; border.color: Qt.alpha(Theme.text, 0.06)
        clip: true
        // 0: the first workspace, 1: the second; moved by a spring (stiffness, damping ratio)
        property real p: 0
        property real v: 0
        property real target: 0
        readonly property bool vert: sec.s.style === "slidevert" || sec.s.style === "slidefadevert"
        readonly property bool fades: sec.s.style === "fade" || sec.s.style === "slidefadevert" || sec.s.style === "slidefade"
        readonly property bool slides: sec.s.style !== "fade" && sec.s.style !== "off" && sec.s.style !== "glitch"
        readonly property bool jumps: sec.s.style === "off" || sec.s.style === "glitch"
        // how far a workspace travels: all the way, or a fifth of it when it fades as it slides
        readonly property real dist: (vert ? height : width) * (fades ? 0.2 : 1)
        Timer {
            interval: 1500; running: stage.visible; repeat: true
            onTriggered: {
                // Glitch: a picture of the workspace going, taken before the switch, glitches away over the new one
                if (sec.s.style === "glitch") { snap.scheduleUpdate(); flip.restart(); return; }
                stage.target = 1 - stage.target; stage.last = Date.now();
                if (sec.s.style === "off") { stage.p = stage.target; stage.v = 0; }
            }
        }
        Timer { id: flip; interval: 60; onTriggered: { stage.target = 1 - stage.target; stage.p = stage.target; stage.v = 0; glitchFx.seed = Math.random() * 97; glitchFx.dir = stage.target > 0.5 ? 1 : -1; glitchAnim.restart(); } }
        // (a timer, not a FrameAnimation: that one never ticked inside this page)
        property real last: 0
        Timer {
            interval: 8; repeat: true
            running: stage.visible && !stage.jumps && (Math.abs(stage.p - stage.target) > 0.0005 || Math.abs(stage.v) > 0.0005)
            onTriggered: {
                const now = Date.now();
                const k = sec.stiffness[sec.s.speed], c = sec.ratio[sec.s.feel] * 2 * Math.sqrt(k);
                // small steps, so a stiff spring stays steady whatever the timing
                let t = Math.min(0.05, (now - stage.last) / 1000);
                stage.last = now;
                while (t > 0) {
                    const dt = Math.min(t, 0.002);
                    stage.v += (-k * (stage.p - stage.target) - c * stage.v) * dt;
                    stage.p += stage.v * dt;
                    t -= dt;
                }
            }
        }
        component Ws: Rectangle {
            id: ws
            property real off: 0
            property real fade: 1
            property color tint: Theme.accent
            property string num: "1"
            x: stage.vert || !stage.slides ? 0 : off
            y: stage.vert && stage.slides ? off : 0
            width: stage.width; height: stage.height
            color: "transparent"
            opacity: stage.fades ? fade : 1
            // a window or two on it
            SmoothRect {
                smoothing: 0
                x: 14; y: 14; width: parent.width * 0.55 - 20; height: parent.height - 28
                radius: 6; color: Qt.alpha(ws.tint, 0.22); border.width: 1; border.color: Qt.alpha(ws.tint, 0.5)
                Row { x: 8; y: 7; spacing: 3; Repeater { model: ["#ff6159", "#ffbd2e", "#28c941"]; Rectangle { required property string modelData; width: 5; height: 5; radius: Theme.chamfer ? 0 : 2.5; color: modelData; opacity: 0.8 } } }
            }
            SmoothRect {
                smoothing: 0
                x: parent.width * 0.55 + 2; y: 14; width: parent.width * 0.45 - 16; height: parent.height - 28
                radius: 6; color: Qt.alpha(ws.tint, 0.12); border.width: 1; border.color: Qt.alpha(ws.tint, 0.3)
            }
            // which workspace it is
            Label { anchors.centerIn: parent; text: ws.num; strong: true; font.pixelSize: 54; color: Qt.alpha(Theme.text, 0.85) }
        }
        // (the second comes in from below / the right, the first goes out the other way)
        Item {
            id: scene
            anchors.fill: parent
            Ws { num: "1"; off: -stage.p * stage.dist; fade: 1 - stage.p; tint: Theme.accent; visible: !(stage.jumps && stage.p > 0.5) }
            Ws { num: "2"; off: (1 - stage.p) * stage.dist; fade: stage.p; tint: Theme.text; visible: !(stage.jumps && stage.p < 0.5) }
        }
        ShaderEffectSource { id: snap; anchors.fill: parent; sourceItem: scene; live: false; visible: false }
        ShaderEffect {
            id: glitchFx
            anchors.fill: parent
            visible: glitchAnim.running
            property var source: snap
            property vector2d itemSize: Qt.vector2d(width, height)
            property real p: 0
            property real seed: 0
            property real dir: 1
            property color red: Theme.danger
            property color cyan: Theme.accent
            fragmentShader: Qt.resolvedUrl("../../ui/shaders/wsglitch.frag.qsb")
            NumberAnimation on p { id: glitchAnim; running: false; from: 0; to: 1; duration: Math.max(1, Theme.fxMs(({ relaxed: 760, normal: 560, fast: 440, fastest: 340 })[sec.s.speed] || 560)); easing.type: Easing.InOutCubic }
        }
        Label {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
            text: "Preview"; muted: true; font.pixelSize: Theme.sizeSmall - 2
        }
    }

    SettingRow {
        Layout.fillWidth: true
        icon: "swap_vert"; title: "Style"; desc: "How the workspaces move"
        Dropdown {
            width: 220; height: 36
            opts: sec.styles
            value: sec.s.style
            onPicked: v => sec.put("style", v)
        }
    }
    SettingRow {
        Layout.fillWidth: true
        visible: sec.s.style !== "off"
        icon: "speed"; title: "Speed"; desc: "How quickly a switch is over"
        Segmented {
            width: 340
            opts: [["relaxed", "Relaxed"], ["normal", "Normal"], ["fast", "Fast"], ["fastest", "Fastest"]]
            value: sec.s.speed
            onPicked: v => sec.put("speed", v)
        }
    }
    SettingRow {
        Layout.fillWidth: true
        // (niri's fade is Monolith's own, a plain ease: no bounce to choose)
        visible: sec.s.style !== "off" && sec.s.style !== "glitch" && !(sec.s.style === "fade" && !Niri.hyprland)
        icon: "waves"; title: "Feel"; desc: sec.s.feel === "bouncy" ? "Goes a little past and settles back" : "Eases in and stops, no bounce"
        Segmented {
            width: 220
            opts: [["smooth", "Smooth"], ["bouncy", "Bouncy"]]
            value: sec.s.feel
            onPicked: v => sec.put("feel", v)
        }
    }
}
