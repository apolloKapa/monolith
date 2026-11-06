import QtQuick
import "../../core"
import "../../ui"

// Minimal: just HH:mm, heavy, filling the widget.
FaceBase {
    id: f
    clip: true
    Inked {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: Qt.formatTime(f.now, "HH:mm")
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 10
        font.weight: Font.Black
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        shadowY: 1.5
    }
}
