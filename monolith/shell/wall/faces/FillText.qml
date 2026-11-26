import QtQuick
import "../../core"
import "../../ui"

// A single line (or a few words) blown up to fill its look: the font grows until the text meets
// the edges, less a border of `edge` of the shorter side. The clocks and the Text widget use it.
Inked {
    property real edge: 0.05
    anchors.fill: parent
    anchors.margins: Math.min(parent.width, parent.height) * edge
    fontSizeMode: Text.Fit
    font.pixelSize: height
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
