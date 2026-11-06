import QtQuick
import "../../core"
import "../../ui"

// Visualiser, continuous: one smooth filled shape riding the music.
FaceBase {
    id: f
    CavaBars { anchors.fill: parent; live: f.live; preview: !f.live || f.editing; continuous: true; count: 64; mirror: f.opt("mirror", false) }
}
