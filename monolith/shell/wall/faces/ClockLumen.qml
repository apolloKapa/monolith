import QtQuick
import "../../core"
import "../../ui"

// Lumen: a dark dial where each hand lights up the hour numbers it passes, in its own colour,
// fading as it moves on; the numbers glow outward a little when lit.
FaceBase {
    id: f
    readonly property real d: Math.min(width, height)
    readonly property bool secs: opt("showSeconds", true)
    readonly property color dial: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourC: Theme.m("secondary", Theme.subtext)
    readonly property color minC: Theme.m("primary", Theme.accent)
    readonly property color secC: Theme.m("tertiary", Theme.accent)
    readonly property color numC: Theme.m("on_primary_container", Theme.text)
    property real hourA: 0
    property real minA: 0
    property real secA: 0
    function beam(hand, target, spread) {
        let diff = Math.abs((((hand - target) % 360) + 540) % 360 - 180);
        if (diff >= spread) return 0;
        const c = Math.cos(diff / spread * Math.PI / 2);
        return c * c;
    }
    function tick() {
        const t = new Date(), s = t.getSeconds(), m = t.getMinutes();
        hourA = (t.getHours() % 12) * 30 + m * 0.5 + s / 120;
        minA = m * 6 + s * 0.1;
        secA = (s + t.getMilliseconds() / 1000) * 6;
    }
    Timer { interval: f.secs ? 40 : 1000; running: f.live && f.visible; repeat: true; triggeredOnStart: true; onTriggered: f.tick() }
    Component.onCompleted: tick()

    Rectangle { anchors.centerIn: parent; width: f.d * 0.94; height: width; radius: width / 2; color: Qt.darker(f.dial, 1.6) }
    Repeater {
        model: 12
        Item {
            required property int index
            readonly property int hour: index + 1
            readonly property real ang: (hour % 12) * 30
            readonly property real ih: f.beam(f.hourA, ang, 45)
            readonly property real im: f.beam(f.minA, ang, 40)
            readonly property real isec: f.secs ? f.beam(f.secA, ang, 32) * 0.85 : 0
            readonly property real lit: Math.max(ih, im, isec)
            readonly property color col: isec >= ih && isec >= im ? f.secC : (im >= ih ? f.minC : f.hourC)
            readonly property real dist: f.d * (0.382 + 0.028 * lit)
            width: f.d * 0.11; height: width
            x: f.width / 2 + dist * Math.sin(ang * Math.PI / 180) - width / 2
            y: f.height / 2 - dist * Math.cos(ang * Math.PI / 180) - height / 2
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.92; height: width; radius: width / 2; color: parent.col; opacity: parent.lit * 0.24 }
            Text {
                anchors.centerIn: parent
                text: parent.hour
                font.family: Theme.fontFamily; font.pixelSize: f.d * 0.054; font.weight: Font.Bold
                color: parent.lit > 0.5 ? f.numC : parent.col
                opacity: 0.18 + 0.82 * parent.lit
            }
        }
    }
    component Hand: Item {
        property real angle
        property real len
        property color col
        anchors.centerIn: parent
        rotation: angle
        Rectangle { width: f.d * 0.054; height: parent.len; radius: width / 2; color: parent.col; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: -width / 2 }
    }
    Hand { angle: f.hourA; len: f.d * 0.22; col: f.hourC }
    Hand { angle: f.minA; len: f.d * 0.32; col: f.minC }
    Hand { visible: f.secs; angle: f.secA; len: f.d * 0.38; col: f.secC }
}
