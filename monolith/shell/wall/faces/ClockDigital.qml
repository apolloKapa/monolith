import QtQuick
import "../../core"
import "../../ui"

// Digital: the hours and minutes run together in the heaviest weight, filling the widget,
// faintly tinted with the accent.
FaceBase {
    id: f
    clip: true
    Inked {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.06
        text: Qt.formatTime(f.now, "HHmm")
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: height * 0.01
        color: f.hasMain ? f.mainC : Qt.tint(Theme.text, Qt.alpha(f.accentC, 0.14))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        shadowY: 3; shadowStrength: 0.5
    }
}
