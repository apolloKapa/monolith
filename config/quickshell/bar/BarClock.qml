import Quickshell
import QtQuick

Row {
    spacing: 14

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSmall
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm:ss")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontBig
        font.bold: true
    }
}
