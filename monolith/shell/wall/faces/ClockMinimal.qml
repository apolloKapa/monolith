import QtQuick
import "../../core"
import "../../ui"

// Minimal: just HH:mm, heavy, filling the widget.
FaceBase {
    id: f
    clip: true
    // Colouring → Gradient: laid over the digits (drawn white)
    layer.enabled: f.gradientOn
    layer.effect: GradientTint { from: f.gradFrom; to: f.gradTo; dir: f.gradVec }
    Inked {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: f.inked(Qt.formatTime(f.now, "HH:mm"), f.mainC, 0)
        textFormat: f.textFormatFor
        font.family: f.fontOr(Theme.fontFamily)
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 10
        font.weight: Font.Black
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        shadowY: 1.5
        color: f.inkColor(f.mainC)
    }
}
