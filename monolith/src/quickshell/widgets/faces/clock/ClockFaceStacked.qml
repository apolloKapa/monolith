import QtQuick
import "../../../reusables"
import "../../../"

// Hours above minutes, big and tight: the hours in full text colour, the minutes dimmed.
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 80
    property real minHeight: 120
    property real maxWidth: 800
    property real maxHeight: 1000
    property real minAspect: 0.3
    property real maxAspect: 1.4
    property bool isRound: false

    readonly property real lineH: height / 2

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: -root.lineH * 0.26

        Text {
            text: DateTime.hour
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.lineH * 1.05
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            text: DateTime.minute
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.lineH * 1.05
            font.weight: Font.DemiBold
            color: ThemeBackend.subtext0
            opacity: 0.85
        }
    }
}
