import QtQuick
import "../../core"
import "../../ui"

// Weather, Dot: the temperature in big dots, the condition's icon and words, a red dot marker.
FaceBase {
    id: f
    WeatherTone { id: wt }
    DotCard { id: card; ctx: f.ctx }
    readonly property real pad: Math.min(width, height) * 0.13
    Rectangle { width: Math.max(6, f.height * 0.05); height: width; radius: width / 2; color: card.accent; x: f.pad; y: f.pad }
    Icon {
        name: wt.icon; filled: true; color: card.ink
        size: Math.min(f.width, f.height) * 0.26
        anchors.right: parent.right; anchors.rightMargin: f.pad * 0.8; y: f.pad * 0.7
    }
    DotText {
        id: t
        text: wt.temp
        color: card.ink
        offColor: card.off
        cell: fitCell(f.width * 0.72, (f.height - 2 * f.pad) * 0.5)
        x: f.pad
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: f.height * 0.04
    }
    Text {
        text: wt.words
        color: card.dim
        font.family: Theme.fontFamily; font.pixelSize: Math.max(10, f.height * 0.09); font.weight: Font.DemiBold
        font.letterSpacing: 1; font.capitalization: Font.AllUppercase
        x: f.pad; width: f.width - 2 * f.pad; elide: Text.ElideRight
        anchors.bottom: parent.bottom; anchors.bottomMargin: f.pad * 0.8
    }
}
