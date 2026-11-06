import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Music, round: a big record (the cover spinning on it, grooves and a layered label in the middle)
// with the visualiser's bars all round it. While music plays, two soft glows breathe with the bass
// and the kick, and the record bounces and leans a little to the beat; click it to play or pause.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property bool active: !!p && p.trackTitle !== ""
    readonly property bool playing: active && p.isPlaying
    readonly property bool cont: f.opt("continuous", false)
    readonly property real half: Math.min(width, height) / 2
    readonly property real ar: half * (cont ? 0.72 : 0.78)              // the record's radius
    readonly property real barMax: (half - ar) * (cont ? 0.96 : 0.92)
    property bool held: false
    // cava runs only while something plays
    readonly property bool want: f.live && f.visible && f.playing
    onWantChanged: { if (want && !held) { Cava.hold(); held = true; } else if (!want && held) { Cava.release(); held = false; } }
    Component.onCompleted: if (want) { Cava.hold(); held = true; }
    Component.onDestruction: if (held) Cava.release()
    readonly property var lv: Cava.bars
    // the sub-bass and the kick, for the glows and the bounce
    readonly property real bass: lv.length > 3 ? Math.min(1, ((lv[0] * 0.5 + lv[1] * 0.35 + lv[2] * 0.15) * 0.6 + (lv[1] * 0.3 + lv[2] * 0.45 + lv[3] * 0.25) * 0.4)) : 0
    readonly property real kick: {
        if (lv.length < 4) return 0;
        const raw = Math.max(lv[0] * 0.5 + lv[1] * 0.35 + lv[2] * 0.15, lv[1] * 0.3 + lv[2] * 0.45 + lv[3] * 0.25);
        return raw > 0.1 ? Math.min(1, Math.pow((raw - 0.1) / 0.9, 1.8) * 1.4) : 0;
    }
    readonly property real bounce: playing ? -kick * ar * 0.02 : 0

    // the glows (only while playing)
    Rectangle {
        anchors.centerIn: parent; anchors.verticalCenterOffset: f.bounce * 0.5
        width: f.ar * 2 + f.barMax * 2; height: width; radius: width / 2
        color: Theme.accent
        opacity: f.playing ? 0.005 + f.bass * 0.035 : 0
        scale: 0.985 + f.bass * 0.0375
        Behavior on opacity { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.centerIn: parent; anchors.verticalCenterOffset: f.bounce * 0.8
        width: f.ar * 2 + f.barMax * 1.35; height: width; radius: width / 2
        color: Theme.accent
        opacity: f.playing ? 0.01 + f.kick * 0.055 : 0
        scale: 0.992 + f.kick * 0.026
        Behavior on opacity { NumberAnimation { duration: Theme.ms(40); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
    }
    // the bars all round
    Repeater {
        model: 64
        Rectangle {
            required property int index
            readonly property real v: {
                if (!f.lv.length) return 0;
                const k = index < 32 ? index : 63 - index;              // the same on both sides
                return f.lv[Math.min(f.lv.length - 1, Math.floor(k / 32 * f.lv.length))] || 0;
            }
            width: Math.max(2.2, 2 * Math.PI * f.ar / 64 * 0.6)
            height: Math.max(2.5, Math.pow(v, 1.08) * f.barMax)
            radius: width / 2
            color: Qt.tint(Theme.text, Qt.alpha(Theme.accent, 0.45 + 0.4 * v))
            opacity: 0.4 + 0.6 * v
            x: f.width / 2 - width / 2
            y: f.height / 2 - f.ar - height
            transform: Rotation { origin.x: width / 2; origin.y: f.ar + height; angle: index * 360 / 64 }
            Behavior on height { NumberAnimation { duration: 70 } }
        }
    }
    // the record
    Item {
        id: disc
        anchors.centerIn: parent
        anchors.verticalCenterOffset: f.bounce
        width: f.ar * 2; height: width
        rotation: f.playing ? (f.bass - 0.3) * 0.9 : 0
        scale: f.playing ? 1 + f.bass * 0.0135 + f.kick * 0.027 : 1
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
        Behavior on rotation { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
        Item {
            anchors.fill: parent
            NumberAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: f.live; paused: !f.playing }
            Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.control }
            Image { id: cov; anchors.fill: parent; source: f.active ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
            MultiEffect {
                anchors.fill: parent; source: cov; maskEnabled: true; maskSource: m
                opacity: f.active && cov.status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutCubic } }
            }
            Rectangle { id: m; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            // nothing playing: a plain dark record with a note
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: Theme.m("surface_container_lowest", "#101014")
                opacity: f.active && cov.status === Image.Ready ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutCubic } }
                Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: -parent.height * 0.24; name: "music_note"; size: parent.width * 0.16; color: Theme.subtext }
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.alpha(Theme.accent, 0.08 + f.kick * 0.08); opacity: f.active && cov.status === Image.Ready ? 1 : 0 }
            // grooves
            Repeater {
                model: [0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.44]
                Rectangle {
                    required property real modelData
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * modelData; height: width; radius: width / 2
                    color: "transparent"; border.width: 1
                    border.color: index % 2 === 0 ? "#ffffff" : "#000000"
                    opacity: (index % 2 === 0 ? 0.035 : 0.06) + f.bass * 0.02
                }
            }
            // the label: dark, a lighter ring, the hole
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.28; height: width; radius: width / 2
                color: Theme.m("surface_container_lowest", "#11111b"); opacity: 0.96
                scale: 1 + f.kick * 0.0135
                border.width: 1.5; border.color: Qt.alpha(Theme.accent, 0.45 + f.kick * 0.4)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.68; height: width; radius: width / 2
                    color: Theme.m("surface_container_highest", Theme.containerHigh)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                    Rectangle { anchors.centerIn: parent; width: parent.width * 0.38; height: width; radius: width / 2; color: "#0d0e15" }
                }
            }
        }
        MouseArea { anchors.fill: parent; enabled: f.live && !!f.p; cursorShape: Qt.PointingHandCursor; onClicked: f.p.togglePlaying() }
    }
}
