import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Battery: a glass bar filling from the left with liquid up to the charge (the wave keeps moving
// while it charges), the icon, the percentage and the time left. Where the liquid covers the text
// it turns dark, letter by letter, right at the liquid's edge.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real r: Theme.corner(80, 12)
    readonly property color dark: "#15161a"
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    WaveFill { id: fill; anchors.fill: parent; radius: f.r; horizontal: true; value: b.level; color: b.color; live: f.live; keepMoving: b.charging; maxAmp: b.charging ? 10 : 6.5 }
    component Content: RowLayout {
        property color ink: Theme.text
        property color iconInk: b.color
        anchors.leftMargin: 16; anchors.rightMargin: 16
        spacing: 14
        Icon { Layout.alignment: Qt.AlignVCenter; name: b.icon; filled: true; size: Math.max(22, Math.min(36, f.height * 0.36)); color: parent.iconInk }
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: b.present ? Math.round(fill.level * 100) + "%" : "No battery found"; color: parent.parent.ink; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.max(14, Math.min(24, f.height * 0.26)) }
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: b.time; color: parent.parent.ink === f.dark ? Qt.alpha(f.dark, 0.85) : (b.charging ? "#7bd88f" : Theme.subtext); font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Math.max(9, Math.min(12, f.height * 0.13)) }
        }
    }
    Content { anchors.fill: parent }
    // the dark copy, only over the liquid
    Item {
        visible: b.present && fill.level > 0.001
        width: Math.max(0, Math.min(f.width, f.width * fill.level))
        height: f.height
        clip: true
        Content { width: f.width; height: f.height; anchors.left: parent.left; ink: f.dark; iconInk: f.dark }
    }
}
