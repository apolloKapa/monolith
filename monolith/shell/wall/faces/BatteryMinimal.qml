import QtQuick
import "../../core"
import "../../ui"

// Battery, Minimal: the percentage in big figures, a thin line under it filled as far as the
// charge, and the time left. No card.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real big: Math.max(16, Math.min(f.height * 0.5, f.width * 0.3))
    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(4, f.height * 0.08)
        width: parent.width - 2 * x
        spacing: Math.max(3, f.height * 0.05)
        Row {
            spacing: f.big * 0.2
            Text {
                renderType: Text.CurveRendering
                text: b.present ? Math.round(b.level * 100) : "—"
                color: f.mainC
                font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.big
            }
            Text {
                renderType: Text.CurveRendering
                anchors.baseline: parent.children[0].baseline
                text: b.present ? "%" : ""
                color: f.subC
                font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: f.big * 0.42
            }
            Icon { visible: b.charging; anchors.verticalCenter: parent.verticalCenter; name: "bolt"; filled: true; size: f.big * 0.5; color: b.color }
        }
        Rectangle {
            width: parent.width; height: Math.max(3, f.height * 0.045)
            radius: Theme.rnd(height / 2)
            color: Qt.alpha(f.mainC, 0.16)
            Rectangle {
                width: Math.max(parent.height, parent.width * b.level); height: parent.height
                visible: b.present
                radius: parent.radius
                color: b.color
                Behavior on width { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutCubic } }
            }
        }
        Text {
            renderType: Text.CurveRendering
            width: parent.width; elide: Text.ElideRight
            visible: f.height > 70
            text: b.time
            color: f.subC
            font.family: Theme.fontFamily; font.pixelSize: Math.max(10, f.big * 0.3)
        }
    }
}
