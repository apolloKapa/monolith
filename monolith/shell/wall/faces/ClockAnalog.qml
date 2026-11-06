import QtQuick
import "../../core"
import "../../ui"

// Analog: a round glass dial with three rounded hands that sweep to each second.
FaceBase {
    id: f
    readonly property real d: Math.min(width, height)
    readonly property bool secs: opt("showSeconds", true)
    Item {
        anchors.centerIn: parent
        width: f.d; height: f.d
        Glass { anchors.fill: parent; ctx: f.ctx; radius: width / 2; dx: (f.width - f.d) / 2; dy: (f.height - f.d) / 2 }
        component Hand: Rectangle {
            property real angle: 0
            anchors.bottom: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Bottom
            rotation: angle
            radius: width / 2
            Behavior on rotation { enabled: f.live; RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise } }
        }
        Hand { width: f.d * 0.045; height: f.d * 0.32; color: Theme.text; angle: (f.now.getHours() % 12) * 30 + f.now.getMinutes() * 0.5 + f.now.getSeconds() / 120 }
        Hand { width: f.d * 0.03; height: f.d * 0.42; color: Theme.subtext; angle: f.now.getMinutes() * 6 + f.now.getSeconds() * 0.1 }
        Hand { visible: f.secs; width: f.d * 0.015; height: f.d * 0.46; color: Theme.accent; angle: f.now.getSeconds() * 6 }
        Rectangle { anchors.centerIn: parent; width: f.d * 0.05; height: width; radius: width / 2; color: Theme.accent }
    }
}
