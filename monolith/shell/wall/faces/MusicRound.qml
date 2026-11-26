import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Music, round: a record with the song's cover printed on it, slowly turning, with grooves and a
// label in the middle, ringed by the visualiser's bars. While music plays, two faint halos swell
// with the low end and the beat, and the record hops and tilts a touch on each hit. Click the
// record to play or pause.
FaceBase {
    id: face
    readonly property var mp: face.player
    readonly property bool hasTrack: !!mp && mp.trackTitle !== ""
    readonly property bool playing: hasTrack && mp.isPlaying
    readonly property bool smoothBars: face.opt("continuous", false)
    readonly property real half: Math.min(width, height) / 2
    readonly property real discR: half * (smoothBars ? 0.72 : 0.78)
    readonly property real barRoom: (half - discR) * (smoothBars ? 0.96 : 0.92)
    readonly property bool hasArt: hasTrack && sleeve.status === Image.Ready

    // the visualiser runs only while this is on screen and something plays
    readonly property bool listening: face.live && face.visible && face.playing
    property bool holding: false
    function listen(on) {
        if (on === holding) return;
        if (on) Cava.hold(); else Cava.release();
        holding = on;
    }
    onListeningChanged: listen(listening)
    Component.onCompleted: listen(listening)
    Component.onDestruction: listen(false)
    readonly property var bands: Cava.bars

    // the lowest bands weighed together: the "sub" (first three) and the "punch" (second to fourth)
    function mix(w, from) { return bands[from] * w[0] + bands[from + 1] * w[1] + bands[from + 2] * w[2]; }
    readonly property real sub: bands.length > 3 ? mix([0.5, 0.35, 0.15], 0) : 0
    readonly property real punch: bands.length > 3 ? mix([0.3, 0.45, 0.25], 1) : 0
    // a steady swell, and a sharper hit that only counts above a floor
    readonly property real low: Math.min(1, sub * 0.6 + punch * 0.4)
    readonly property real hit: {
        const peak = Math.max(sub, punch);
        return bands.length > 3 && peak > 0.1 ? Math.min(1, 1.4 * Math.pow((peak - 0.1) / 0.9, 1.8)) : 0;
    }
    readonly property real hop: playing ? -hit * discR * 0.02 : 0

    // a soft disc of accent behind it all, `size` across: at rest `rest` opaque and `restScale`
    // big, brighter by `gain` and bigger by `swell` as `drive` rises
    component Halo: Rectangle {
        property real size
        property real lift
        property real rest
        property real gain
        property real swell
        property real restScale
        property real drive
        property int fadeMs
        property int growMs
        width: size
        height: size
        radius: size / 2
        anchors.centerIn: parent
        anchors.verticalCenterOffset: lift
        color: Theme.accent
        opacity: face.playing ? rest + drive * gain : 0
        scale: restScale + drive * swell
        Behavior on opacity { NumberAnimation { duration: Theme.ms(fadeMs); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(growMs); easing.type: Easing.OutCubic } }
    }
    Halo { size: face.discR * 2 + face.barRoom * 2; lift: face.hop * 0.5; rest: 0.005; gain: 0.035; swell: 0.0375; restScale: 0.985; drive: face.low; fadeMs: 120; growMs: 160 }
    Halo { size: face.discR * 2 + face.barRoom * 1.35; lift: face.hop * 0.8; rest: 0.01; gain: 0.055; swell: 0.026; restScale: 0.992; drive: face.hit; fadeMs: 40; growMs: 120 }

    // 64 bars standing out from the rim, mirrored left and right
    Repeater {
        model: 64
        Rectangle {
            required property int index
            readonly property real level: {
                if (!face.bands.length) return 0;
                const fold = Math.min(index, 63 - index);
                return face.bands[Math.min(face.bands.length - 1, Math.floor(fold / 32 * face.bands.length))] || 0;
            }
            width: Math.max(2.2, Math.PI * face.discR / 32 * 0.6)
            height: Math.max(2.5, Math.pow(level, 1.08) * face.barRoom)
            radius: width / 2
            x: (face.width - width) / 2
            y: face.height / 2 - face.discR - height
            color: Qt.tint(Theme.text, Qt.alpha(Theme.accent, 0.45 + 0.4 * level))
            opacity: 0.4 + 0.6 * level
            transform: Rotation { origin.x: width / 2; origin.y: face.discR + height; angle: index * 5.625 }
            Behavior on height { NumberAnimation { duration: 70 } }
        }
    }

    Item {
        id: record
        width: face.discR * 2
        height: width
        anchors.centerIn: parent
        anchors.verticalCenterOffset: face.hop
        rotation: face.playing ? (face.low - 0.3) * 0.9 : 0
        scale: face.playing ? 1 + face.low * 0.0135 + face.hit * 0.027 : 1
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
        Behavior on rotation { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
        component Ring: Rectangle { anchors.centerIn: parent; height: width; radius: width / 2 }
        Item {
            anchors.fill: parent
            // a turn every 24 s, holding still while paused
            NumberAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: face.live; paused: running && !face.playing }
            Ring { width: parent.width; color: Theme.control }
            Image { id: sleeve; visible: false; anchors.fill: parent; sourceSize: Qt.size(640, 640); asynchronous: true; fillMode: Image.PreserveAspectCrop; source: face.hasTrack ? (face.mp.trackArtUrl || "") : "" }
            Ring { id: roundCut; width: parent.width; visible: false; antialiasing: true; layer.enabled: true; layer.smooth: true }
            MultiEffect {
                anchors.fill: parent
                source: sleeve
                maskEnabled: true
                maskSource: roundCut
                opacity: face.hasArt ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutCubic } }
            }
            // no cover: a plain dark record with a note above the label
            Ring {
                width: parent.width
                color: Theme.m("surface_container_lowest", "#101014")
                opacity: face.hasArt ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutCubic } }
                Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: -parent.height * 0.24; name: "music_note"; size: parent.width * 0.16; color: Theme.subtext }
            }
            Ring { width: parent.width; color: Qt.alpha(Theme.accent, 0.08 + face.hit * 0.08); opacity: face.hasArt ? 1 : 0 }
            // seven grooves from 92 % in, 8 % apart, light and dark in turn
            Repeater {
                model: 7
                Ring {
                    required property int index
                    readonly property bool light: index % 2 === 0
                    width: parent.width * (0.92 - index * 0.08)
                    color: "transparent"
                    border.width: 1
                    border.color: light ? "#ffffff" : "#000000"
                    opacity: (light ? 0.035 : 0.06) + face.low * 0.02
                }
            }
            // the label: a dark disc with an accent edge, a lighter inner ring, the spindle hole
            Ring {
                width: parent.width * 0.28
                color: Theme.m("surface_container_lowest", "#11111b")
                opacity: 0.96
                scale: 1 + face.hit * 0.0135
                border.width: 1.5
                border.color: Qt.alpha(Theme.accent, 0.45 + face.hit * 0.4)
                Ring {
                    width: parent.width * 0.68
                    color: Theme.m("surface_container_highest", Theme.containerHigh)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    Ring { width: parent.width * 0.38; color: "#0d0e15" }
                }
            }
        }
        MouseArea { anchors.fill: parent; enabled: face.live && !!face.mp; cursorShape: Qt.PointingHandCursor; onClicked: face.mp.togglePlaying() }
    }
}
