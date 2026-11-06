import QtQuick
import "../../core"
import "../../ui"

// Date: the weekday big and heavy, the date under it.
FaceBase {
    id: f
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        Inked { width: parent.width; height: f.height * 0.6; text: Qt.formatDate(f.now, "dddd"); font.weight: Font.Black; font.pixelSize: height; fontSizeMode: Text.Fit; verticalAlignment: Text.AlignBottom }
        Inked { width: parent.width; height: f.height * 0.32; text: Qt.formatDate(f.now, "d MMMM yyyy"); color: Theme.subtext; font.weight: Font.Bold; font.pixelSize: height; fontSizeMode: Text.Fit }
    }
}
