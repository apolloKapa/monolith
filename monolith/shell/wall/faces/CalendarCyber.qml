import QtQuick
import "../../core"
import "../../ui"

// Calendar, Cyberpunk: the month as a grid of numbers in Rajdhani, today on a yellow block,
// the weekend dimmer.
FaceBase {
    id: f
    readonly property int first: (new Date(f.now.getFullYear(), f.now.getMonth(), 1).getDay() + 6) % 7
    readonly property int days: new Date(f.now.getFullYear(), f.now.getMonth() + 1, 0).getDate()
    CyberCard {
        id: c; ctx: f.ctx; label: Qt.formatDate(f.now, "MMMM yyyy")
        Grid {
            id: g
            anchors.fill: parent
            columns: 7
            readonly property real cw: width / 7
            readonly property real ch: height / 7
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Text { required property string modelData; width: g.cw; height: g.ch; renderType: Text.CurveRendering; text: modelData; color: c.edge; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: Math.max(8, g.ch * 0.6); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Repeater {
                model: f.first + f.days
                Item {
                    required property int index
                    readonly property int day: index - f.first + 1
                    readonly property bool today: day === f.now.getDate()
                    width: g.cw; height: g.ch
                    Rectangle { anchors.centerIn: parent; visible: parent.today; width: g.cw * 0.86; height: g.ch * 0.86; color: c.neon }
                    Text { anchors.centerIn: parent; visible: parent.day > 0; renderType: Text.CurveRendering; text: parent.day; color: parent.today ? "#0a0a12" : (index % 7 >= 5 ? c.dim : c.ink); font.family: c.fam; font.weight: parent.today ? Font.Bold : Font.DemiBold; font.pixelSize: Math.max(8, g.ch * 0.6) }
                }
            }
        }
    }
}
