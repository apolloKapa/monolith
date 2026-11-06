import QtQuick
import "../../core"
import "../../ui"

// Weather, round: a glass pill lying diagonally across a square, the condition's icon in its
// upper end and the temperature in its lower end (both upright).
FaceBase {
    id: f
    WeatherTone { id: wt }
    readonly property real d: Math.min(width, height)
    readonly property real len: d * 0.94
    readonly property real pw: d * 0.54
    Item {
        id: pill
        anchors.centerIn: parent
        width: f.pw; height: f.len
        rotation: 45
        Glass { anchors.fill: parent; ctx: f.ctx; radius: width / 2; dx: (f.width - f.pw) / 2; dy: (f.height - f.len) / 2 }
        // the icon: the upper end
        Item {
            width: f.pw * 0.68; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top; anchors.verticalCenterOffset: f.pw / 2
            rotation: -45
            Icon { anchors.centerIn: parent; name: wt.icon; filled: true; size: parent.height * 0.8; color: wt.color }
        }
        // the temperature: the lower end
        Item {
            id: tbox
            width: f.pw * 0.68; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.bottom; anchors.verticalCenterOffset: -f.pw / 2
            rotation: -45
            Text {
                id: num
                anchors.centerIn: parent
                text: wt.ready ? Math.round(Weather.current.temp) : "--"
                color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: tbox.height * 0.58
            }
            Text {
                anchors.left: num.right; anchors.leftMargin: 1
                anchors.top: num.top; anchors.topMargin: tbox.height * 0.04
                text: "°"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: tbox.height * 0.3
            }
        }
    }
}
