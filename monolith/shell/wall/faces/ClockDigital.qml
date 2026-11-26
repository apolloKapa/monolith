import QtQuick
import "../../core"
import "../../ui"

// Digital: four digits with no colon between them, in the heaviest weight there is, as big as
// the widget lets them be. Unless a Main colour is set they're the text colour with a breath of
// the accent in it.
FaceBase {
    id: face
    clip: true
    readonly property color digitInk: face.hasMain ? face.mainC : Qt.tint(Theme.text, Qt.alpha(face.accentC, 0.14))
    layer.enabled: face.gradientOn
    layer.effect: GradientTint { from: face.gradFrom; to: face.gradTo; dir: face.gradVec }
    FillText {
        edge: 0.06
        minimumPixelSize: 12
        font.family: face.fontOr(Theme.fontFamily)
        font.weight: Font.Black
        font.letterSpacing: height / 100
        textFormat: face.textFormatFor
        text: face.inked(Qt.formatTime(face.now, "HHmm"), face.digitInk, 0)
        color: face.inkColor(face.digitInk)
        shadowY: 3
        shadowStrength: 0.5
    }
}
