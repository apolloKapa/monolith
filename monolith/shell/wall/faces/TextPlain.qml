import QtQuick
import "../../core"
import "../../ui"

// Text: your own words, bold, as big as the widget allows (set them in the editor).
FaceBase {
    id: f
    clip: true
    readonly property string t: f.opt("textContent", "")
    Inked {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: f.t.trim() === "" ? "Your text" : f.t
        opacity: f.t.trim() === "" ? 0.4 : 1
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        font.weight: Font.Bold
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        shadowY: 1.5
    }
}
