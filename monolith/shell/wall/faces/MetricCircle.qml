import QtQuick
import "../../core"
import "../../ui"

// A usage ring: no card, just the (wavy) ring with the icon, the number and the name inside.
FaceBase {
    id: f
    Metric { id: m; type: f.ctx ? f.ctx.type : "cpu" }
    readonly property real d: Math.min(width, height)
    WaveRing { anchors.centerIn: parent; width: f.d; height: f.d; value: m.value; color: m.color; wavy: f.opt("sineWave", true); thickness: f.opt("lineThickness", 8); live: f.live }
    Column {
        anchors.centerIn: parent
        spacing: 2
        Icon { visible: f.d >= 72; anchors.horizontalCenter: parent.horizontalCenter; name: m.icon; size: f.d * 0.16; color: Theme.subtext }
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: m.text; font.weight: Font.Black; font.pixelSize: f.d * (f.d < 110 ? 0.2 : 0.22); shadowY: 1.5 }
        Inked { visible: f.d >= 96; anchors.horizontalCenter: parent.horizontalCenter; text: m.title; color: Theme.subtext; font.weight: Font.DemiBold; font.pixelSize: f.d * 0.095; shadowY: 1 }
    }
}
