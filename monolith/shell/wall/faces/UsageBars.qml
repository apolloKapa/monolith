import QtQuick
import "../../core"
import "../../ui"

// System usage, bars: glass; CPU, memory, GPU and temperature as filling bars.
FaceBase {
    id: f
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 300; dh: 170
        Column {
            x: 16; y: 14; width: parent.width - 32
            spacing: (parent.height - 28 - 4 * 30) / 3
            Repeater {
                model: [["CPU", Stats.cpu, Math.round(Stats.cpu * 100) + "%"], ["Memory", Stats.mem, Math.round(Stats.mem * 100) + "%"],
                        ["GPU", Stats.gpu, Math.round(Stats.gpu * 100) + "%"], ["Temperature", Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°"]]
                Item {
                    required property var modelData
                    width: parent.width; height: 30
                    Text { text: parent.modelData[0]; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12 }
                    Text { anchors.right: parent.right; text: parent.modelData[2]; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12 }
                    Rectangle { y: 18; width: parent.width; height: 9; radius: 5; color: Qt.alpha(Theme.text, 0.12)
                        Rectangle { height: parent.height; radius: 5; color: Theme.accent; width: Math.max(9, parent.width * parent.parent.modelData[1]); Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } } } }
                }
            }
        }
    }
}
