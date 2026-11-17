import QtQuick
import "../../core"
import "../../ui"

// Text, Cyberpunk: your words in Rajdhani with a split signal, as big as fit.
FaceBase {
    id: f
    readonly property string t: String(f.opt("textContent", "Wake up, samurai"))
    CyberCard {
        id: c; ctx: f.ctx; label: String(f.opt("cyberLabel", "Transmission"))
        CyberText { anchors.fill: parent; card: c; text: f.t }
    }
}
