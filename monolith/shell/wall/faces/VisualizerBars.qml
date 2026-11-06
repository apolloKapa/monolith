import QtQuick
import "../../core"
import "../../ui"

// Visualiser: rounded bars across the widget, as many as fit, fading at the edges.
FaceBase {
    id: f
    CavaBars { anchors.fill: parent; live: f.live; preview: !f.live || f.editing; mirror: f.opt("mirror", false) }
}
