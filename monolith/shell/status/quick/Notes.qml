import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Notes: the same notes as Tools and the desktop widget, saved as you type.
ColumnLayout {
    spacing: 8
    Label { text: "Notes"; strong: true; font.pixelSize: Theme.sizeTitle }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.corner(80, 4)
        color: Theme.container
        Flickable {
            SmoothWheel {}
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: nt.implicitHeight
            clip: true
            TextEdit {
                id: nt
                width: parent.width
                text: Store.get("notes.text", "")
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.selected
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
                focus: true
                onTextChanged: save.restart()
                Timer { id: save; interval: 600; onTriggered: if (Store.get("notes.text", "") !== nt.text) Store.set("notes.text", nt.text) }
                Label { visible: nt.text === ""; text: "Write something…"; muted: true }
            }
        }
    }
}
