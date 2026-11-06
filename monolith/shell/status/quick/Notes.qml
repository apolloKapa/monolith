import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Notes: the same notes as Tools and the desktop widget (a list; open one to write), saved as you type.
ColumnLayout {
    spacing: 8
    Label { text: "Notes"; strong: true; font.pixelSize: Theme.sizeTitle }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.corner(80, 4)
        color: Theme.container
        NotesBoard { anchors.fill: parent; anchors.margins: 12 }
    }
}
