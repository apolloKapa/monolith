import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Music, round: the cover as a spinning record, bars radiating around it, the whole thing
// bouncing to the beat; click it to play or pause.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property bool playing: !!f.p && f.p.isPlaying
    readonly property real d: Math.min(width, height)
    readonly property real ar: d * 0.3                  // the record's radius
    readonly property real barMax: d / 2 - ar - 4
    property bool held: false
    readonly property bool want: f.live && f.visible && f.playing
    onWantChanged: { if (want && !held) { Cava.hold(); held = true; } else if (!want && held) { Cava.release(); held = false; } }
    Component.onDestruction: if (held) Cava.release()
    readonly property var bars: Cava.bars
    readonly property real kick: bars.length ? (bars[0] + bars[1] + bars[2]) / 3 : 0

    // the halo
    Rectangle { anchors.centerIn: parent; width: f.ar * 2 + f.barMax * 1.4; height: width; radius: width / 2; color: Theme.accent; opacity: 0.08 + f.kick * 0.12 }
    // bars all round
    Repeater {
        model: 48
        Rectangle {
            required property int index
            readonly property real v: f.bars.length ? f.bars[Math.floor((index < 24 ? index : 47 - index) / 24 * f.bars.length)] : (f.live ? 0.05 : 0.3)
            width: Math.max(2, f.d * 0.014)
            height: Math.max(3, v * f.barMax)
            radius: width / 2
            color: Theme.accent
            opacity: 0.45 + 0.55 * v
            x: f.width / 2 - width / 2
            y: f.height / 2 - f.ar - 3 - height
            transform: Rotation { origin.x: width / 2; origin.y: f.ar + 3 + height; angle: index * 7.5 }
        }
    }
    // the record
    Item {
        id: rec
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -f.kick * f.d * 0.02
        width: f.ar * 2; height: width
        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.m("surface_container_lowest", "#101014"); border.width: Math.max(2, f.d * 0.012); border.color: f.playing ? Theme.accent : Qt.alpha(Theme.text, 0.25) }
        Item {
            anchors.fill: parent
            RotationAnimation on rotation { from: 0; to: 360; duration: 12000; loops: Animation.Infinite; running: f.live && f.playing }
            Image { id: cov; anchors.fill: parent; anchors.margins: parent.width * 0.06; source: f.p ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
            MultiEffect { anchors.fill: cov; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: m }
            Rectangle { id: m; width: cov.width; height: cov.height; radius: width / 2; visible: false; layer.enabled: true }
            Icon { anchors.centerIn: parent; visible: cov.status !== Image.Ready; name: "music_note"; size: parent.width * 0.3; color: Theme.subtext }
            // grooves and the label hole
            Repeater { model: [0.72, 0.86]; Rectangle { required property real modelData; anchors.centerIn: parent; width: parent.width * modelData; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) } }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.14; height: width; radius: width / 2; color: Theme.m("surface_container_lowest", "#101014"); border.width: 1.5; border.color: Qt.alpha(Theme.accent, 0.5 + f.kick * 0.4) }
        }
        MouseArea { anchors.fill: parent; enabled: !!f.p; cursorShape: Qt.PointingHandCursor; onClicked: f.p.togglePlaying() }
    }
}
