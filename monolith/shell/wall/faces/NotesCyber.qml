import QtQuick
import "../../core"
import "../../ui"

// Notes, Cyberpunk: MEMO. Your notes (the same as Tools and quick access) on the HUD panel.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Memo"
        NotesBoard { anchors.fill: parent; live: f.live; fontSize: Math.max(11, c.u * 0.06) }
    }
}
