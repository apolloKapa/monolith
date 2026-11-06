import QtQuick
import "../../core"
import "../../ui"

// Stacked: hours over minutes, the minutes in the accent colour.
FaceBase {
    id: f
    clip: true
    Column {
        anchors.centerIn: parent
        spacing: 0
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(f.now, "HH"); font.pixelSize: f.height * 0.5; font.weight: Font.Black; height: f.height * 0.5; verticalAlignment: Text.AlignVCenter; lineHeight: 0.85 }
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(f.now, "mm"); font.pixelSize: f.height * 0.55; font.weight: Font.Black; color: Theme.accent; height: f.height * 0.5; verticalAlignment: Text.AlignVCenter }
    }
}
