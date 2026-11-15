import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Lock screen: big bold hours (accent) and minutes, the date in spaced capitals under them.
// Narrow: the hours stack over the minutes.
FaceBase {
    id: f
    readonly property bool stacked: width / height < 1.25
    readonly property string date: Qt.formatDate(f.now, "dddd, d MMMM").toUpperCase()
    // Colouring → Gradient: laid over the digits (drawn white)
    layer.enabled: f.gradientOn
    layer.effect: GradientTint { from: f.gradFrom; to: f.gradTo; dir: f.gradVec }
    component Big: Inked { font.weight: Font.Bold; shadowY: 3; shadowStrength: 0.4 }
    ColumnLayout {
        visible: f.stacked
        anchors.centerIn: parent
        spacing: 8
        scale: Math.min(f.width / Math.max(1, implicitWidth), f.height / Math.max(1, implicitHeight))
        Big { font.family: f.fontOr(Theme.fontFamily); Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: -28; text: f.inked(Qt.formatTime(f.now, "HH"), f.accentC, 0); textFormat: f.textFormatFor; color: f.inkColor(f.accentC); font.pixelSize: 150 }
        Big { font.family: f.fontOr(Theme.fontFamily); Layout.alignment: Qt.AlignHCenter; text: f.inked(Qt.formatTime(f.now, "mm"), Theme.text, 2); textFormat: f.textFormatFor; color: f.inkColor(Theme.text); font.pixelSize: 150 }
        Big { font.family: f.fontOr(Theme.fontFamily); Layout.alignment: Qt.AlignHCenter; text: f.date; color: f.subC; font.pixelSize: 16; font.weight: Font.Medium; font.letterSpacing: 1.4 }
    }
    ColumnLayout {
        visible: !f.stacked
        anchors.centerIn: parent
        spacing: 8
        scale: Math.min(f.width / Math.max(1, implicitWidth), f.height / Math.max(1, implicitHeight))
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Big { font.family: f.fontOr(Theme.fontFamily); text: f.inked(Qt.formatTime(f.now, "HH"), f.accentC, 0); textFormat: f.textFormatFor; color: f.inkColor(f.accentC); font.pixelSize: 120 }
            Big { font.family: f.fontOr(Theme.fontFamily); text: ":"; color: f.inkColor(f.subC); font.pixelSize: 80; Layout.alignment: Qt.AlignVCenter }
            Big { font.family: f.fontOr(Theme.fontFamily); text: f.inked(Qt.formatTime(f.now, "mm"), Theme.text, 2); textFormat: f.textFormatFor; color: f.inkColor(Theme.text); font.pixelSize: 120 }
        }
        Big { font.family: f.fontOr(Theme.fontFamily); Layout.alignment: Qt.AlignHCenter; text: f.date; color: f.subC; font.pixelSize: 16; font.weight: Font.Medium; font.letterSpacing: 1.4 }
    }
}
