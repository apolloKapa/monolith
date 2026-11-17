import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A picture, Cyberpunk: inside the HUD frame with its corners cut, a faint pink and cyan split
// at the edges, and scanlines over it.
FaceBase {
    id: f
    readonly property string path: (f.opt("imagePath", "") || Store.get("widgets.imagePath", "")).replace(/^file:\/\//, "")
    CyberCard {
        id: c; ctx: f.ctx; label: "Visual"
        Item {
            anchors.fill: parent
            clip: true
            Image { id: img; anchors.fill: parent; source: f.path !== "" ? Wall.url(f.path) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; visible: false }
            MultiEffect { anchors.fill: parent; anchors.leftMargin: -2; source: img; colorization: 1; colorizationColor: c.hot; opacity: 0.35 }
            MultiEffect { anchors.fill: parent; anchors.leftMargin: 2; source: img; colorization: 1; colorizationColor: c.edge; opacity: 0.35 }
            MultiEffect { anchors.fill: parent; source: img; saturation: 0.15; contrast: 0.1 }
            Image { anchors.fill: parent; source: "../../ui/scan.png"; fillMode: Image.Tile; smooth: false; opacity: 0.12 }
            Icon { anchors.centerIn: parent; visible: img.status !== Image.Ready; name: "image"; size: Math.min(parent.width, parent.height) * 0.35; color: c.dim }
        }
    }
}
