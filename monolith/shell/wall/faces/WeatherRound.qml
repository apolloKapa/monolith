import QtQuick
import "../../core"
import "../../ui"

// Weather, round: a pill of glass laid corner to corner across the widget, with the condition's
// icon in its upper end and the temperature in its lower one, both standing upright.
FaceBase {
    id: face
    WeatherTone { id: sky }
    readonly property real side: Math.min(width, height)
    readonly property real pillW: side * 0.54
    readonly property real pillH: side * 0.94
    // what sits in each end of the pill: a square 0.68 of the pill's width, centred on where the
    // end rounds off, turned back upright
    component End: Item {
        property bool upper: true
        width: face.pillW * 0.68
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: upper ? parent.top : parent.bottom
        anchors.verticalCenterOffset: (upper ? 1 : -1) * face.pillW / 2
        rotation: -45
    }
    Item {
        width: face.pillW
        height: face.pillH
        anchors.centerIn: parent
        rotation: 45
        Glass { anchors.fill: parent; ctx: face.ctx; radius: width / 2; dx: (face.width - face.pillW) / 2; dy: (face.height - face.pillH) / 2 }
        End {
            upper: true
            Icon { anchors.centerIn: parent; name: sky.icon; filled: true; color: sky.color; size: parent.height * 0.8 }
        }
        End {
            id: low
            upper: false
            Text {
                id: degrees
                anchors.centerIn: parent
                renderType: Text.CurveRendering
                text: sky.ready ? Math.round(Weather.current.temp) : "--"
                color: Theme.text
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: low.height * 0.58
            }
            Text {
                anchors.left: degrees.right
                anchors.leftMargin: 1
                anchors.top: degrees.top
                anchors.topMargin: low.height * 0.04
                renderType: Text.CurveRendering
                text: "°"
                color: Theme.text
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: low.height * 0.3
            }
        }
    }
}
