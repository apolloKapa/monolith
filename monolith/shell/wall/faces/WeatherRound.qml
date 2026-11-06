import QtQuick
import "../../core"
import "../../ui"

// Weather, round: a tall glass pill, the condition's icon at the top and the temperature at the
// bottom.
FaceBase {
    id: f
    WeatherTone { id: wt }
    readonly property real pw: Math.min(width, height * 0.5)
    readonly property real ph: Math.min(height, pw * 2.1)
    Item {
        anchors.centerIn: parent
        width: f.pw; height: f.ph
        Glass { anchors.fill: parent; ctx: f.ctx; radius: width / 2; dx: (f.width - f.pw) / 2; dy: (f.height - f.ph) / 2 }
        Icon { anchors.horizontalCenter: parent.horizontalCenter; y: f.pw * 0.16; name: wt.icon; filled: true; size: f.pw * 0.62; color: wt.color }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: f.pw * 0.22
            Text { text: wt.ready ? Math.round(Weather.current.temp) : "--"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.pw * 0.38 }
            Text { text: "°"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.pw * 0.2 }
        }
    }
}
