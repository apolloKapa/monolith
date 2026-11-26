import QtQuick
import "../../core"
import "../../ui"

// Analog: a round pane of glass with three rounded hands standing on its centre, each sweeping
// on to its next position over a second, and an accent dot over where they meet.
FaceBase {
    id: face
    readonly property real side: Math.min(width, height)
    readonly property int h: face.now.getHours() % 12
    readonly property int m: face.now.getMinutes()
    readonly property int s: face.now.getSeconds()
    // each hand: how long and how thick (parts of the dial), its colour and where it points
    readonly property var hands: [
        { len: 0.32, thick: 0.045, ink: face.mainC, deg: h * 30 + m / 2 + s / 120, show: true },
        { len: 0.42, thick: 0.03, ink: face.subC, deg: m * 6 + s / 10, show: true },
        { len: 0.46, thick: 0.015, ink: face.accentC, deg: s * 6, show: face.opt("showSeconds", true) }
    ]
    Item {
        id: dial
        width: face.side
        height: face.side
        anchors.centerIn: parent
        Glass { anchors.fill: parent; ctx: face.ctx; radius: width / 2; dx: (face.width - face.side) / 2; dy: (face.height - face.side) / 2 }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property var spec: face.hands[index]
                visible: spec.show
                width: face.side * spec.thick
                height: face.side * spec.len
                radius: width / 2
                color: spec.ink
                // standing on the centre (on a whole pixel across, as centring does), turned about its foot
                x: Math.round((dial.width - width) / 2)
                y: dial.height / 2 - height
                transformOrigin: Item.Bottom
                rotation: spec.deg
                Behavior on rotation { enabled: face.live; RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise } }
            }
        }
        Rectangle { width: face.side / 20; height: width; radius: width / 2; color: face.accentC; anchors.centerIn: parent }
    }
}
