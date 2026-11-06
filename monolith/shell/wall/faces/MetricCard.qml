import QtQuick
import "../../core"
import "../../ui"

// A usage card: glass, filling with liquid up to the value (a wave on top that moves when it
// changes); the icon top-left, the number top-right, the name bottom-left.
FaceBase {
    id: f
    readonly property bool small: height < 100 || width < 140
    Metric { id: m; type: f.ctx ? f.ctx.type : "cpu" }
    readonly property real r: Theme.corner(80, small ? 10 : 12)
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    WaveFill { id: fill; anchors.fill: parent; radius: f.r; value: m.value; color: m.color; live: f.live; maxAmp: f.small ? 4 : 5 }
    // over the liquid the text turns dark, like the card is lit from inside
    readonly property bool sunk: m.value > 0.55
    readonly property color ink: sunk ? Theme.m("on_primary", "#1b1b1f") : Theme.text
    Item {
        anchors.fill: parent
        anchors.margins: f.small ? 10 : 12
        Rectangle {
            id: ic
            width: f.small ? 26 : 30; height: width; radius: Math.min(width / 2, Theme.corner(30, 8))
            color: Qt.alpha(f.sunk ? "#000000" : Theme.control, f.sunk ? 0.15 : 0.7)
            Icon { anchors.centerIn: parent; name: m.icon; size: parent.width * 0.58; color: f.ink }
        }
        Text { anchors.right: parent.right; anchors.verticalCenter: ic.verticalCenter; text: m.text; color: f.ink; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.small ? 18 : 24 }
        Column {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            Text { text: m.title; color: Qt.alpha(f.ink, 0.85); font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.small ? 11 : 13 }
            Text { visible: !f.small && m.detail !== ""; text: m.detail; color: Qt.alpha(f.ink, 0.65); font.family: Theme.fontFamily; font.pixelSize: 11 }
        }
    }
}
