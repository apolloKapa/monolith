import QtQuick
import "../../core"
import "../../ui"

// Battery as a (wavy) ring: green while charging, red when low.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real d: Math.min(width, height)
    WaveRing { anchors.centerIn: parent; width: f.d; height: f.d; value: b.level; color: b.color; wavy: f.opt("sineWave", true); thickness: f.opt("lineThickness", 8); live: f.live }
    Column {
        anchors.centerIn: parent
        spacing: 2
        Icon { visible: f.d >= 72; anchors.horizontalCenter: parent.horizontalCenter; name: b.icon; filled: true; size: f.d * 0.16; color: b.color }
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: b.present ? Math.round(b.level * 100) + "%" : "--"; font.weight: Font.Black; font.pixelSize: f.d * 0.22; shadowY: 1.5 }
        Inked { visible: f.d >= 96 && (b.charging || !b.present); anchors.horizontalCenter: parent.horizontalCenter; text: b.charging ? "Charging" : "No battery"; color: Theme.subtext; font.weight: Font.DemiBold; font.pixelSize: f.d * 0.095; shadowY: 1 }
    }
}
