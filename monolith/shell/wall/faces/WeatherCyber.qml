import QtQuick
import "../../core"
import "../../ui"

// Weather, Cyberpunk: ATMOS. The temperature big with its split signal, the condition's icon in
// cyan, its words in yellow, and where under it.
FaceBase {
    id: f
    WeatherTone { id: wt }
    CyberCard {
        id: c; ctx: f.ctx; label: "Atmos"
        CyberText { id: t; card: c; width: parent.width * 0.62; height: parent.height * 0.62; text: wt.temp }
        Icon { anchors.right: parent.right; y: 0; name: wt.icon; filled: true; size: Math.min(parent.height * 0.55, parent.width * 0.32); color: c.edge }
        CyberText { anchors.bottom: parent.bottom; anchors.bottomMargin: c.u * 0.12; card: c; width: parent.width; height: c.u * 0.14; ghosts: false; color: c.neon; text: String(wt.words).toUpperCase() }
        CyberText { anchors.bottom: parent.bottom; card: c; width: parent.width; height: c.u * 0.1; ghosts: false; color: c.dim; weight: Font.DemiBold; text: String(Weather.city || "").toUpperCase() }
    }
}
