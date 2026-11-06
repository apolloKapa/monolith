import QtQuick
import "../../core"
import "../../ui"

// Calendar: glass; this month, today on an accent circle.
FaceBase {
    id: f
    readonly property int first: (new Date(f.now.getFullYear(), f.now.getMonth(), 1).getDay() + 6) % 7
    readonly property int days: new Date(f.now.getFullYear(), f.now.getMonth() + 1, 0).getDate()
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 270; dh: 250
        Text { x: 18; y: 14; text: Qt.formatDate(f.now, "MMMM"); color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 18 }
        Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 17; text: Qt.formatDate(f.now, "yyyy"); color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 14 }
        Grid {
            id: g
            x: 14; y: 46
            width: parent.width - 28
            columns: 7
            readonly property real cw: width / 7
            readonly property real ch: (parent.height - y - 12) / 7
            Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; Text { required property string modelData; width: g.cw; height: g.ch; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: modelData; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 11 } }
            Repeater {
                model: f.first + f.days
                Item {
                    required property int index
                    readonly property int day: index - f.first + 1
                    readonly property bool today: day === f.now.getDate()
                    width: g.cw; height: g.ch
                    Rectangle { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2; color: Theme.accent; visible: parent.today }
                    Text { anchors.centerIn: parent; visible: parent.day > 0; text: parent.day; color: parent.today ? Theme.onAccent : Theme.text; font.family: Theme.fontFamily; font.weight: parent.today ? Font.Black : Font.Medium; font.pixelSize: 13 }
                }
            }
        }
    }
}
