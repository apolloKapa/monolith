import QtQuick
import "../../core"
import "../../ui"

// Notes: glass; the same note as Tools and quick access, written right here, saved as you type.
FaceBase {
    id: f
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Row { x: 16; y: 14; spacing: 8
        Icon { name: "sticky_note_2"; size: 18; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Notes"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter } }
    Flickable {
        x: 16; y: 46; width: parent.width - 32; height: parent.height - 60
        contentHeight: nt.contentHeight
        clip: true
        TextEdit {
            id: nt
            width: parent.width
            text: Store.get("notes.text", "")
            wrapMode: TextEdit.Wrap
            color: Theme.text
            selectionColor: Theme.selected
            font.family: Theme.fontFamily; font.pixelSize: 14
            readOnly: !f.live
            onTextChanged: if (f.live) save.restart()
            Timer { id: save; interval: 600; onTriggered: if (Store.get("notes.text", "") !== nt.text) Store.set("notes.text", nt.text) }
            Text { visible: nt.text === ""; text: "Write something…"; color: Theme.subtext; font: nt.font }
        }
    }
}
