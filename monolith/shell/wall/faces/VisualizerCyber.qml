import QtQuick
import "../../core"
import "../../ui"

// Visualiser, Cyberpunk: SIGNAL. Square bars in cyan fading to pink, on the HUD panel.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Signal"
        CavaBars { anchors.fill: parent; live: f.live; preview: f.editing; roundness: 0; spacing: Math.max(2, c.u * 0.02); minBar: Math.max(4, c.u * 0.03); color: c.edge; color2: c.hot }
    }
}
