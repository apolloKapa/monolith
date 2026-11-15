import QtQuick
import "../../core"
import "../../ui"

// Stacked: hours over minutes, the minutes in the accent colour.
FaceBase {
    id: f
    clip: true
    // Colouring → Gradient: laid over the digits (drawn white)
    layer.enabled: f.gradientOn
    layer.effect: GradientTint { from: f.gradFrom; to: f.gradTo; dir: f.gradVec }
    Column {
        anchors.centerIn: parent
        spacing: 0
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: f.inked(Qt.formatTime(f.now, "HH"), f.mainC, 0); textFormat: f.textFormatFor; font.family: f.fontOr(Theme.fontFamily); font.pixelSize: f.height * 0.5; font.weight: Font.Black; height: f.height * 0.5; verticalAlignment: Text.AlignVCenter; lineHeight: 0.85; color: f.inkColor(f.mainC) }
        Inked { anchors.horizontalCenter: parent.horizontalCenter; text: f.inked(Qt.formatTime(f.now, "mm"), f.accentC, 2); textFormat: f.textFormatFor; font.family: f.fontOr(Theme.fontFamily); font.pixelSize: f.height * 0.55; font.weight: Font.Black; color: f.inkColor(f.accentC); height: f.height * 0.5; verticalAlignment: Text.AlignVCenter }
    }
}
