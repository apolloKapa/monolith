import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Battery, bar: a glass bar with liquid filling it from the left up to the charge (its surface
// keeps rolling while it charges); the battery icon, the percentage and the time left on top.
// Where the liquid reaches, the icon and text turn dark, cut exactly at its edge.
FaceBase {
    id: face
    Battery { id: cell }
    readonly property real corner: Theme.corner(80, 12)
    readonly property color dark: "#15161a"
    Glass { anchors.fill: parent; ctx: face.ctx; radius: face.corner }
    WaveFill {
        id: tank
        anchors.fill: parent
        radius: face.corner
        horizontal: true
        value: cell.level
        color: cell.color
        live: face.live
        keepMoving: cell.charging
        maxAmp: cell.charging ? 10 : 6.5
    }
    // the icon and the two lines, drawn in `tone` (or, unless dark, the usual colours)
    component Readout: RowLayout {
        id: row
        property bool darkened: false
        readonly property color tone: darkened ? face.dark : Theme.text
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 14
        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: cell.icon
            filled: true
            size: Math.max(22, Math.min(36, face.height * 0.36))
            color: row.darkened ? face.dark : cell.color
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                Layout.fillWidth: true
                renderType: Text.CurveRendering
                elide: Text.ElideRight
                text: cell.present ? Math.round(tank.level * 100) + "%" : "No battery found"
                color: row.tone
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: Math.max(14, Math.min(24, face.height * 0.26))
            }
            Text {
                Layout.fillWidth: true
                renderType: Text.CurveRendering
                elide: Text.ElideRight
                text: cell.time
                color: row.darkened ? Qt.alpha(face.dark, 0.85) : (cell.charging ? "#7bd88f" : Theme.subtext)
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Math.max(9, Math.min(12, face.height * 0.13))
            }
        }
    }
    Readout { anchors.fill: parent }
    // the dark copy, cut to the liquid's width
    Item {
        visible: cell.present && tank.level > 0.001
        width: Math.max(0, Math.min(face.width, face.width * tank.level))
        height: face.height
        clip: true
        Readout { darkened: true; width: face.width; height: face.height; anchors.left: parent.left }
    }
}
