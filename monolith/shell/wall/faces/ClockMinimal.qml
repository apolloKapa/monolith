import QtQuick
import "../../core"
import "../../ui"

// Minimal: the time with its colon and nothing else, heavy, filling the widget.
FaceBase {
    id: face
    clip: true
    layer.enabled: face.gradientOn
    layer.effect: GradientTint { from: face.gradFrom; to: face.gradTo; dir: face.gradVec }
    FillText {
        minimumPixelSize: 10
        font.family: face.fontOr(Theme.fontFamily)
        font.weight: Font.Black
        textFormat: face.textFormatFor
        text: face.inked(Qt.formatTime(face.now, "HH:mm"), face.mainC, 0)
        color: face.inkColor(face.mainC)
        shadowY: 1.5
    }
}
