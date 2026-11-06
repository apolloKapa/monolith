import QtQuick
import "../../core"
import "../../ui"

// Date, compact: "Fri 6 Nov", filling the widget.
FaceBase {
    id: f
    Inked { anchors.fill: parent; text: Qt.formatDate(f.now, "ddd d MMM"); font.weight: Font.Black; font.pixelSize: height; fontSizeMode: Text.Fit; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter }
}
