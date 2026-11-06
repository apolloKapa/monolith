import QtQuick
import "../../core"
import "../../ui"

// Battery: a glass bar filling from the left with liquid up to the charge (the wave keeps moving
// while it charges), the icon, the percentage and the time left.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real r: Theme.corner(80, 12)
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    WaveFill { anchors.fill: parent; radius: f.r; horizontal: true; value: b.level; color: b.color; live: f.live; keepMoving: b.charging; maxAmp: b.charging ? 10 : 6.5 }
    readonly property bool sunk: b.level > 0.45
    readonly property color ink: sunk ? "#15161a" : Theme.text
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 16
        spacing: 12
        Icon { anchors.verticalCenter: parent.verticalCenter; name: b.icon; filled: true; size: Math.max(22, Math.min(36, f.height * 0.36)); color: f.sunk ? f.ink : b.color }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: b.present ? Math.round(b.level * 100) + "%" : "No battery found"; color: f.ink; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.max(14, Math.min(24, f.height * 0.26)) }
            Text { text: b.time; color: Qt.alpha(f.ink, 0.8); font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Math.max(9, Math.min(12, f.height * 0.13)) }
        }
    }
}
