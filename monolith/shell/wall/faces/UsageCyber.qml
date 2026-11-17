import QtQuick
import "../../core"
import "../../ui"

// Usage, Cyberpunk: SYS DIAG. CPU, memory, GPU and temperature as labelled rows of segments.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Sys diag"
        Column {
            anchors.fill: parent
            spacing: (height - 4 * height * 0.2) / 3
            Repeater {
                model: [["CPU", Stats.cpu, Math.round(Stats.cpu * 100) + "%"], ["MEM", Stats.mem, Math.round(Stats.mem * 100) + "%"],
                        ["GPU", Stats.gpu, Math.round(Stats.gpu * 100) + "%"], ["TMP", Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°"]]
                Item {
                    required property var modelData
                    width: parent.width; height: parent.height * 0.2
                    Text { id: k; renderType: Text.CurveRendering; width: parent.width * 0.18; height: parent.height; text: parent.modelData[0]; color: c.neon; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75; verticalAlignment: Text.AlignVCenter }
                    CyberBar { x: k.width; anchors.verticalCenter: parent.verticalCenter; card: c; width: parent.width * 0.6; height: parent.height * 0.45; value: parent.modelData[1]; count: 16 }
                    Text { anchors.right: parent.right; renderType: Text.CurveRendering; height: parent.height; text: parent.modelData[2]; color: c.ink; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }
}
