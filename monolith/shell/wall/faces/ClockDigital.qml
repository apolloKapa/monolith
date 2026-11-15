import QtQuick
import "../../core"
import "../../ui"

// Digital: the hours and minutes run together in the heaviest weight, filling the widget,
// faintly tinted with the accent.
FaceBase {
    id: f
    clip: true
    // Colouring → Gradient: laid over the digits (drawn white)
    layer.enabled: f.gradientOn
    layer.effect: GradientTint { from: f.gradFrom; to: f.gradTo; dir: f.gradVec }
    Inked {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.06
        readonly property color base: f.hasMain ? f.mainC : Qt.tint(Theme.text, Qt.alpha(f.accentC, 0.14))
        text: f.inked(Qt.formatTime(f.now, "HHmm"), base, 0)
        textFormat: f.textFormatFor
        font.family: f.fontOr(Theme.fontFamily)
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: height * 0.01
        color: f.inkColor(base)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        shadowY: 3; shadowStrength: 0.5
    }
}
