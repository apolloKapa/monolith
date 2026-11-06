import QtQuick
import "../../core"
import "../../ui"

// Notes: glass; your notes (the same ones as Tools and quick access), pinned first. Click one
// to read and write it here; + makes a new one.
FaceBase {
    id: f
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Row { x: 16; y: 14; spacing: 8
        Icon { name: "sticky_note_2"; size: 18; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Notes"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter } }
    NotesBoard {
        x: 14; y: 44; width: parent.width - 28; height: parent.height - 56
        live: f.live
        fontSize: 13
    }
}
