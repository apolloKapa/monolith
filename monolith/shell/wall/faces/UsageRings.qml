import QtQuick
import "../../core"
import "../../ui"

// System usage: glass with CPU, memory and temperature as three wavy rings.
FaceBase {
    id: f
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Row {
        anchors.centerIn: parent
        spacing: f.width * 0.04
        Repeater {
            model: ["cpu", "ram", "temp"]
            Item {
                id: rc
                required property string modelData
                Metric { id: m; type: rc.modelData }
                readonly property real d: Math.min(f.height * 0.82, (f.width - f.width * 0.12) / 3)
                width: d; height: d
                WaveRing { anchors.fill: parent; value: m.value; color: m.color; thickness: 9; live: f.live }
                Column {
                    anchors.centerIn: parent
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: m.text; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: rc.d * 0.22 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: m.title === "Temperature" ? "Temp" : m.title; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.DemiBold; font.pixelSize: rc.d * 0.11 }
                }
            }
        }
    }
}
