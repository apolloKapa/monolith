import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Battery as a (wavy) ring: green while charging, red when low.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real d: Math.min(width, height)
    Item {
        anchors.centerIn: parent
        width: f.d; height: f.d
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1.5; shadowBlur: 0.35; shadowOpacity: 0.55 }
    WaveRing { anchors.fill: parent; value: b.level; color: b.color; wavy: f.opt("sineWave", true); thickness: f.opt("lineThickness", 8); live: f.live }
    Column {
        anchors.centerIn: parent
        spacing: 2
        Icon { visible: f.d >= 72; anchors.horizontalCenter: parent.horizontalCenter; name: b.icon; filled: true; size: f.d * 0.16; color: b.color }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: b.present ? Math.round(b.level * 100) + "%" : "--"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.d * (f.d < 110 ? 0.2 : 0.22) }
        Text { visible: f.d >= 96 && b.charging; anchors.horizontalCenter: parent.horizontalCenter; text: "Charging"; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.DemiBold; font.pixelSize: f.d * 0.095 }
    }
    }
}
